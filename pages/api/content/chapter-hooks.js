import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateChapterHookScripts } from "../../../lib/ai";
import { isSubscriptionActive } from "../../../lib/subscription";

// Lit le livre en entier et génère, pour chaque chapitre, 5 hooks d'accroche
// et 5 scripts vidéo courts — réservé aux comptes avec un abonnement actif
// (voir lib/subscription.js), comme la génération de posts réseaux.
export const config = { maxDuration: 60 };

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const { bookId } = req.body;
    if (!bookId) return res.status(400).json({ error: "bookId requis" });

    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    if (!isSubscriptionActive(author)) {
      return res.status(402).json({ error: "Abonnement inactif — génération de contenu indisponible." });
    }

    const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
    if (!book) return res.status(404).json({ error: "Livre introuvable" });

    const chapters = await generateChapterHookScripts(book);
    return res.status(200).json({ chapters });
  } catch (error) {
    console.error("Erreur /api/content/chapter-hooks :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
