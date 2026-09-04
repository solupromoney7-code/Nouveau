import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// GET  -> retourne l'état de configuration des moyens de paiement de l'auteur
// PUT  -> enregistre le numéro Mobile Money (zone Afrique)
// La connexion Stripe (zone Europe) passe par /api/stripe/connect/onboarding,
// pas par cette route, car elle nécessite une redirection OAuth.
export default requireAuth(async function handler(req, res) {
  if (req.method === "GET") {
    const author = await prisma.author.findUnique({
      where: { id: req.authorId },
      select: { region: true, stripeAccountId: true, stripeOnboarded: true, momoOperator: true, momoNumber: true },
    });
    return res.status(200).json(author);
  }

  if (req.method === "PUT") {
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
});
