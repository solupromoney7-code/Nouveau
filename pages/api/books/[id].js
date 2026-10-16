import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Modifie un livre existant (titre affiché, image de couverture). Utilisée
// par les pages "Page de vente" et "Page d'extrait" du tableau de bord.
export default requireAuth(async function handler(req, res) {
  const { id } = req.query;

  try {
    const book = await prisma.book.findUnique({ where: { id } });
    if (!book || book.authorId !== req.authorId) {
      return res.status(404).json({ error: "Livre introuvable" });
    }

    if (req.method === "PATCH") {
      const data = {};

      if (typeof req.body?.title === "string") {
        const title = req.body.title.trim().slice(0, 200);
        if (!title) return res.status(400).json({ error: "Le titre ne peut pas être vide." });
        data.title = title;
      }

      if (typeof req.body?.coverImageUrl === "string") {
        const url = req.body.coverImageUrl.trim();
        if (url && !/^https:\/\/[a-z0-9]+\.public\.blob\.vercel-storage\.com\//.test(url)) {
          return res.status(400).json({ error: "URL d'image invalide" });
        }
        data.coverImageUrl = url || null;
      }

      if (Object.keys(data).length === 0) {
        return res.status(400).json({ error: "Rien à modifier." });
      }

      const updated = await prisma.book.update({ where: { id }, data });
      return res.status(200).json(updated);
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/books/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
