import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSalesPageCopy } from "../../../lib/ai";

function slugify(title) {
  return title
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, priceCents, currency } = req.body;
  if (!bookId || !priceCents || !currency) {
    return res.status(400).json({ error: "bookId, priceCents et currency sont requis" });
  }

  try {
    const book = await prisma.book.findFirst({
      where: { id: bookId, authorId: req.authorId },
      include: { author: true },
    });
    if (!book) return res.status(404).json({ error: "Livre introuvable" });

    const copy = await generateSalesPageCopy(book);
    const slug = `${slugify(book.title)}-${book.id.slice(-5)}`;

    let salesPage = await prisma.salesPage.upsert({
      where: { bookId: book.id },
      update: { priceCents, currency, ...copy },
      create: { bookId: book.id, slug, priceCents, currency, ...copy },
    });

    // Zone Afrique : le produit Chariow de ce livre est créé à la main dans
    // le tableau de bord Chariow, puis relié depuis l'espace Administration
    // > Livres (l'API publique de Chariow ne permet pas de créer des produits).

    return res.status(201).json(salesPage);
  } catch (error) {
    // Avant ce correctif, une erreur ici provoquait un crash silencieux
    // (page d'erreur HTML generique de Next.js), sans aucun detail cote
    // client ni log exploitable. On capture et on journalise maintenant
    // explicitement pour pouvoir diagnostiquer.
    console.error("Erreur dans /api/sales-pages :", error);
    return res.status(500).json({
      error: error.message || "Erreur inconnue lors de la generation de la page de vente.",
    });
  }
});
