import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Engagement produit : toute demande de reversement est traitée en moins de
// 24h. dueBy est enregistré pour piloter ce SLA côté opérations. Cet
// engagement reste tenable car on ne valide jamais une demande au-delà du
// solde "disponible" (voir lib/chariow-earnings.js côté Afrique) — on ne
// promet jamais un montant qu'on n'a pas encore réellement reçu.
const SLA_MS = 24 * 60 * 60 * 1000;

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { amountCents } = req.body;
  if (!amountCents || amountCents <= 0) {
    return res.status(400).json({ error: "Montant invalide" });
  }

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (!author.emailVerified) {
    return res.status(403).json({ error: "Confirmez votre adresse email avant de demander un reversement (vérifiez votre boîte mail, ou renvoyez le lien depuis Paramètres)." });
  }
  const dueBy = new Date(Date.now() + SLA_MS);

  // --- Zone Europe : Stripe déclenche un vrai virement vers le compte connecté ---
  if (author.region === "EUROPE") {
    if (!author.stripeAccountId || !author.stripeOnboarded) {
      return res.status(400).json({ error: "Compte Stripe non connecté" });
    }

    const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
    const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
    if (amountCents > available) {
      return res.status(400).json({ error: "Montant supérieur au solde disponible" });
    }

    const currency = (balance.available[0]?.currency || "eur");
    const stripePayout = await stripe.payouts.create(
      { amount: amountCents, currency },
      { stripeAccount: author.stripeAccountId }
    );

    const payout = await prisma.payout.create({
      data: {
        authorId: author.id,
        amountCents,
        currency: currency.toUpperCase(),
        method: "stripe",
        status: stripePayout.status === "paid" ? "PAID" : "PENDING",
        providerRef: stripePayout.id,
        dueBy,
        processedAt: stripePayout.status === "paid" ? new Date() : null,
      },
    });
    return res.status(201).json(payout);
  }

  // --- Zone Afrique : reversement Mobile Money, plafonné au solde réellement mature ---
  if (!author.momoNumber) {
    return res.status(400).json({ error: "Numéro Mobile Money non configuré" });
  }

  const balance = await computeAfriqueBalance(author.id);
  if (amountCents > balance.availableCents) {
    return res.status(400).json({
      error: "Montant supérieur au solde disponible",
      availableCents: balance.availableCents,
      pendingMaturityNetCents: balance.pendingMaturityNetCents,
    });
  }

  // TODO production : Chariow ne propose pas d'API de transfert vers un
  // tiers (seulement un retrait vers TON propre Mobile Money, voir README
  // §4.1) — ce Payout reste donc à traiter manuellement : retire les fonds
  // sur ton Mobile Money puis envoie la part de l'auteur, avant dueBy.
  const payout = await prisma.payout.create({
    data: {
      authorId: author.id,
      amountCents,
      currency: "XOF",
      method: "momo",
      status: "PENDING",
      dueBy,
    },
  });

  return res.status(201).json(payout);
});
