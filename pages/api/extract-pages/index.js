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
