import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

function slugify(title) {
  return title
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default requireAuth(async function handler(req, res) {
  // Liste des pages d'extrait de l'auteur (avec le livre et le nombre de contacts)
  if (req.method === "GET") {
    const pages = await prisma.extractPage.findMany({
      where: { book: { authorId: req.authorId } },
      orderBy: { createdAt: "desc" },
      include: { book: { select: { id: true, title: true, coverImageUrl: true } } },
    });
    const counts = await prisma.lead.groupBy({
      by: ["bookId"],
      where: { authorId: req.authorId, source: "extrait", bookId: { in: pages.map((x) => x.bookId) } },
      _count: { _all: true },
    });
    const byBook = Object.fromEntries(counts.map((c) => [c.bookId, c._count._all]));
    return res.status(200).json(
      pages.map((x) => ({
        id: x.id,
        slug: x.slug,
        createdAt: x.createdAt,
        book: x.book,
        leadCount: byBook[x.bookId] || 0,
      }))
    );
  }

  if (req.method !== "POST") return res.status(405).end();

  const { bookId, videoUrl, pdfUrl } = req.body;
  const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const slug = `extrait-${slugify(book.title)}-${book.id.slice(-5)}`;

  const extractPage = await prisma.extractPage.upsert({
    where: { bookId: book.id },
    update: { videoUrl, ...(pdfUrl && { pdfUrl }) },
    create: { bookId: book.id, slug, videoUrl, pdfUrl },
  });

  return res.status(201).json(extractPage);
});
