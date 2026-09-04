import { put } from "@vercel/blob";
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Les fonctions serverless Vercel n'ont pas de disque persistant : le
// fichier du livre est envoyé directement à Vercel Blob (stockage objet),
// pas sauvegardé sur le système de fichiers local.
export const config = {
  api: { bodyParser: false },
};

const ALLOWED_EXTENSIONS = [".pdf", ".epub"];
const MAX_SIZE_BYTES = 50 * 1024 * 1024; // 50 Mo, cohérent avec le prototype

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rawFilename = String(req.headers["x-filename"] || `livre-${Date.now()}.pdf`);
  // On ne garde que des caractères sûrs — un nom de fichier ne doit jamais
  // être utilisé tel quel (chemins, caractères spéciaux).
  const filename = rawFilename.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 150);

  const ext = filename.slice(filename.lastIndexOf(".")).toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return res.status(400).json({ error: "Format non autorisé — seuls PDF et EPUB sont acceptés." });
  }

  const contentLength = Number(req.headers["content-length"] || 0);
  if (contentLength > MAX_SIZE_BYTES) {
    return res.status(413).json({ error: "Fichier trop volumineux (50 Mo max)." });
  }

  const blob = await put(filename, req, {
    access: "public",
    addRandomSuffix: true,
  });

  const book = await prisma.book.create({
    data: {
      authorId: req.authorId,
      title: filename.replace(/\.[^/.]+$/, ""),
      fileUrl: blob.url,
    },
  });

  return res.status(201).json(book);
});
