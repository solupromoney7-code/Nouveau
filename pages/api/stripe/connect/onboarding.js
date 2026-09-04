import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";
import { stripe } from "../../../../lib/stripe";

// Crée (si besoin) le compte Stripe Connect Express de l'auteur puis
// retourne un lien d'onboarding hébergé par Stripe. Le frontend doit
// rediriger l'auteur vers cette URL — jamais de clé secrète échangée ici.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  let author = await prisma.author.findUnique({ where: { id: req.authorId } });

  if (!author.stripeAccountId) {
    const account = await stripe.accounts.create({
      type: "express",
      email: author.email,
      capabilities: {
        transfers: { requested: true },
        card_payments: { requested: true },
      },
    });
    author = await prisma.author.update({
      where: { id: author.id },
      data: { stripeAccountId: account.id },
    });
  }

  const accountLink = await stripe.accountLinks.create({
    account: author.stripeAccountId,
    refresh_url: `${process.env.APP_URL}/dashboard/paiements?stripe=refresh`,
    return_url: `${process.env.APP_URL}/dashboard/paiements?stripe=retour`,
    type: "account_onboarding",
  });

  return res.status(200).json({ url: accountLink.url });
});
