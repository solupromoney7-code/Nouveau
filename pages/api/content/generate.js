import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSocialPosts } from "../../../lib/ai";
import { isSubscriptionActive } from "../../../lib/subscription";

// Génération de contenu réseaux sociaux — réservée aux comptes avec un
// abonnement actif ou en période d'essai (voir lib/subscription.js).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, count } = req.body;
  if (!bookId) return res.status(400).json({ error: "bookId requis" });

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (!isSubscriptionActive(author)) {
    return res.status(402).json({ error: "Abonnement inactif — génération de contenu indisponible." });
  }

  const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const posts = await generateSocialPosts(book, count || 20);
  return res.status(200).json({ posts });
});
