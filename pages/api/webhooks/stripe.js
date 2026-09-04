import { buffer } from "micro";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { sendPurchaseConfirmationEmail } from "../../../lib/email";

// Stripe exige le corps brut (non parsé) pour vérifier la signature.
export const config = {
  api: { bodyParser: false },
};

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const sig = req.headers["stripe-signature"];
  const buf = await buffer(req);

  let event;
  try {
    event = stripe.webhooks.constructEvent(buf, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook signature invalide : ${err.message}`);
  }

  // Vente d'un livre payée
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const purchaseId = session.metadata?.purchaseId;
    if (purchaseId) {
      const purchase = await prisma.purchase.update({
        where: { id: purchaseId },
        data: { status: "paid" },
        include: { book: true },
      });
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
        amountFormatted: `${(purchase.amountCents / 100).toFixed(2)} ${purchase.currency}`,
      });
    }
  }

  // Onboarding Stripe Connect de l'auteur terminé / mis à jour
  if (event.type === "account.updated") {
    const account = event.data.object;
    await prisma.author.updateMany({
      where: { stripeAccountId: account.id },
      data: { stripeOnboarded: Boolean(account.charges_enabled && account.details_submitted) },
    });
  }

  // Note : l'abonnement à la plateforme (Plume) est désormais facturé via
  // Chariow pour les deux zones — voir pages/api/subscriptions/checkout.js
  // et pages/api/webhooks/chariow.js. Ce webhook Stripe ne gère plus que la
  // vente de livres (zone Europe) et l'onboarding Stripe Connect.

  return res.status(200).json({ received: true });
}
