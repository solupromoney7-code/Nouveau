import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { normalizePaymentLink } from "../../../lib/paymentLink";

// GET  -> retourne l'état de configuration des moyens de paiement de l'auteur
// PUT  -> enregistre le numéro Mobile Money (zone Afrique)
// La connexion Stripe (zone Europe) passe par /api/stripe/connect/onboarding,
// pas par cette route, car elle nécessite une redirection OAuth.
export default requireAuth(async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const author = await prisma.author.findUnique({
        where: { id: req.authorId },
        select: { region: true, stripeAccountId: true, stripeOnboarded: true, paymentLink: true, momoOperator: true, momoNumber: true },
      });
      return res.status(200).json(author);
    }

    if (req.method === "PUT") {
      // Zone Europe : lien de paiement de l'auteur
      if (req.body && "paymentLink" in req.body) {
        const raw = String(req.body.paymentLink || "").trim();
        if (!raw) {
          await prisma.author.update({ where: { id: req.authorId }, data: { paymentLink: null } });
          return res.status(200).json({ ok: true, paymentLink: null });
        }
        const link = normalizePaymentLink(raw);
        if (!link) {
          return res.status(400).json({ error: "Lien non reconnu. Collez un lien de paiement Stripe (https://buy.stripe.com/…) ou PayPal." });
        }
        await prisma.author.update({ where: { id: req.authorId }, data: { paymentLink: link } });
        return res.status(200).json({ ok: true, paymentLink: link });
      }

      const { momoOperator, momoNumber } = req.body;
      if (!momoOperator || !momoNumber) {
        return res.status(400).json({ error: "Opérateur et numéro Mobile Money requis" });
      }
      await prisma.author.update({
        where: { id: req.authorId },
        data: { momoOperator, momoNumber },
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/authors/payment-config :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
