import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Supprime une page d'extrait (le lien public cesse de fonctionner).
// Le livre et les contacts déjà récoltés sont conservés.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "DELETE") return res.status(405).end();

  try {
    const { id } = req.query;
    const page = await prisma.extractPage.findUnique({ where: { id }, include: { book: true } });
    if (!page || page.book.authorId !== req.authorId) {
      return res.status(404).json({ error: "Page d'extrait introuvable" });
    }
    await prisma.extractPage.delete({ where: { id } });
    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("Erreur DELETE /api/extract-pages/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
