import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Liste les livres de l'auteur connecté — utilisée partout où l'auteur doit
// choisir "sur quel livre" lancer une action (génération de contenu réseaux,
// hooks par chapitre...).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const books = await prisma.book.findMany({
      where: { authorId: req.authorId },
      orderBy: { createdAt: "desc" },
      select: { id: true, title: true, createdAt: true },
    });
    return res.status(200).json(books);
  } catch (error) {
    console.error("Erreur /api/books :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
