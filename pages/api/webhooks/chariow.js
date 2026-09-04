import { prisma } from "../../../lib/db";
import { verifyChariowSale } from "../../../lib/chariow";
import { sendPurchaseConfirmationEmail } from "../../../lib/email";

// Pulse Chariow. "sale.completed" est confirmé par la documentation
// publique. Les noms exacts des événements liés à l'abonnement
// (échec de paiement, annulation) ne sont PAS confirmés — vérifie-les dans
// Réglages > Pulses de ton dashboard Chariow et ajuste les comparaisons
// event === "..." ci-dessous si besoin.
//
// SÉCURITÉ : Chariow ne documente pas de signature HMAC vérifiable pour le
// moment (contrairement à Stripe). En attendant de la confirmer avec leur
// support, on protège cette route par un secret partagé dans l'URL — configure
// dans Chariow l'URL exacte :
//   https://ton-domaine.vercel.app/api/webhooks/chariow?secret=TA_VALEUR
// (la même valeur que CHARIOW_WEBHOOK_SECRET). Sans ce secret, la requête
// est rejetée avant même d'être lue — même le cas "sale.completed", pourtant
// déjà re-vérifié auprès de Chariow, gagne cette couche supplémentaire.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  if (!process.env.CHARIOW_WEBHOOK_SECRET || req.query.secret !== process.env.CHARIOW_WEBHOOK_SECRET) {
    return res.status(401).json({ error: "Non autorisé" });
  }

  const { event, data } = req.body || {};
  if (!event || !data) return res.status(400).json({ error: "Payload invalide" });

  const customerEmail = data.customer?.email;
  const productSlug = data.product?.slug;
  const authorId = data.metadata?.authorId;
  const kind = data.metadata?.kind;

  if (event === "sale.completed") {
    // Reconfirmation serveur-à-serveur avant de faire confiance à la
    // notification — même principe que pour CinetPay/Stripe.
    const confirmed =
      customerEmail && productSlug ? await verifyChariowSale({ productSlug, customerEmail }) : null;

    if (!confirmed) {
      return res.status(200).json({ received: true, ignored: "not_confirmed" });
    }

    if (kind === "subscription" && authorId) {
      // Paiement de l'abonnement à la plateforme.
      await prisma.author.update({
        where: { id: authorId },
        data: {
          subscriptionStatus: "ACTIVE",
          currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });
    } else if (customerEmail) {
      // Achat d'un livre (zone Afrique).
      const purchase = await prisma.purchase.findFirst({
        where: { provider: "chariow", buyerEmail: customerEmail, status: "pending" },
        orderBy: { createdAt: "desc" },
        include: { book: true },
      });
      if (purchase) {
        await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
        await prisma.lead.create({
          data: {
            authorId: purchase.authorId,
            bookId: purchase.bookId,
            firstName: purchase.buyerName,
            lastName: "",
            email: purchase.buyerEmail,
            whatsapp: purchase.buyerWhatsapp || "",
            source: "acheteur",
          },
        });
        await sendPurchaseConfirmationEmail({
          to: purchase.buyerEmail,
          buyerName: purchase.buyerName,
          bookTitle: purchase.book.title,
          amountFormatted: `${purchase.amountCents} ${purchase.currency}`,
        });
      }
    }
  }

  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
  if (event === "subscription.payment_failed" && authorId) {
    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "PAST_DUE" } });
  }

  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
  if (event === "subscription.cancelled" && authorId) {
    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "CANCELED" } });
  }

  return res.status(200).json({ received: true });
}
