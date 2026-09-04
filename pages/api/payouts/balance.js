import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Solde disponible = ce qu'on peut honnêtement promettre de reverser sous
// 24h. Pour la zone Europe, Stripe distingue déjà nativement available vs
// pending (et ses frais sont déjà déduits du montant retourné). Pour la
// zone Afrique, voir lib/chariow-earnings.js : on ne rend "disponible" que
// les ventes déjà matures (au-delà du délai réel de règlement Chariow), nettes
// de leur commission — jamais un montant qu'on n'a pas encore en main.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });

  if (author.region === "EUROPE") {
    if (!author.stripeAccountId || !author.stripeOnboarded) {
      return res.status(200).json({ availableCents: 0, currency: "EUR", pendingCents: 0, method: "stripe", connected: false });
    }
    const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
    const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
    const pending = balance.pending.reduce((sum, b) => sum + b.amount, 0);
    return res.status(200).json({
      availableCents: available,
      pendingCents: pending,
      currency: (balance.available[0]?.currency || "eur").toUpperCase(),
      method: "stripe",
      connected: true,
      note: "Montant déjà net des frais Stripe.",
    });
  }

  const balance = await computeAfriqueBalance(author.id);
  return res.status(200).json({
    ...balance,
    method: "momo",
    connected: Boolean(author.momoNumber),
    note: `Net des frais de transaction (${Math.round(balance.commissionRate * 100)}%). Une vente devient disponible ${balance.maturityDays} jours après l'achat.`,
  });
});
