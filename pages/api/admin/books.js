import { requireAdmin } from "../../../lib/admin";
import { prisma } from "../../../lib/db";

// Toutes les pages de vente, avec le produit Chariow relié (zone Afrique).
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const pages = await prisma.salesPage.findMany({
      orderBy: { createdAt: "desc" },
      include: { book: { select: { title: true, author: { select: { name: true, email: true, region: true } } } } },
    });
    return res.status(200).json(
      pages.map((p) => ({
        id: p.id,
        slug: p.slug,
        createdAt: p.createdAt,
        published: p.published,
        priceCents: p.priceCents,
        currency: p.currency,
        chariowProductId: p.chariowProductId || "",
        bookTitle: p.book?.title || "",
        authorName: p.book?.author?.name || "",
        authorEmail: p.book?.author?.email || "",
        region: p.book?.author?.region || "AFRIQUE",
      }))
    );
  } catch (error) {
    console.error("Erreur /api/admin/books :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
