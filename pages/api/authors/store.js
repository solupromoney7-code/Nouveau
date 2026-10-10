import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

function slugify(value) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

// GET -> état de la vitrine publique (slug + livres éligibles à y figurer)
// PUT -> choisit/modifie le slug de la vitrine (ex: "nom-de-la-boutique")
export default requireAuth(async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const author = await prisma.author.findUnique({
        where: { id: req.authorId },
        select: { storeSlug: true },
      });

      const books = await prisma.book.findMany({
        where: { authorId: req.authorId },
        orderBy: { createdAt: "desc" },
        include: { salesPage: true },
      });

      return res.status(200).json({
        storeSlug: author.storeSlug,
        books: books.map((b) => ({
          id: b.id,
          title: b.title,
          priceCents: b.salesPage?.priceCents ?? null,
          currency: b.salesPage?.currency ?? null,
          published: b.salesPage?.published ?? false,
          salesPageSlug: b.salesPage?.slug ?? null,
        })),
      });
    }

    if (req.method === "PUT") {
      const { storeSlug } = req.body;
      if (!storeSlug || !storeSlug.trim()) {
        return res.status(400).json({ error: "Nom de boutique requis" });
      }
      const clean = slugify(storeSlug);
      if (!clean) {
        return res.status(400).json({ error: "Ce nom de boutique n'est pas valide" });
      }

      const existing = await prisma.author.findUnique({ where: { storeSlug: clean } });
      if (existing && existing.id !== req.authorId) {
        return res.status(409).json({ error: "Ce nom de boutique est déjà pris, essayez-en un autre." });
      }

      await prisma.author.update({ where: { id: req.authorId }, data: { storeSlug: clean } });
      return res.status(200).json({ storeSlug: clean });
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/authors/store :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
