import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Finalise l'upload "client" du livre (voir /api/books/upload) : le fichier
// est déjà sur Vercel Blob à ce stade, cette route ne fait qu'enregistrer sa
// référence en base, associée à l'auteur connecté. Appelée directement par
// le navigateur juste après la fin de l'upload.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { url, filename } = req.body || {};
  if (!url || !filename) {
    return res.status(400).json({ error: "url et filename requis" });
  }
  // Vérifie que l'URL pointe bien vers notre propre stockage Vercel Blob,
  // pas vers un fichier arbitraire fourni par le client.
  if (!/^https:\/\/[a-z0-9]+\.public\.blob\.vercel-storage\.com\//.test(url)) {
    return res.status(400).json({ error: "URL de fichier invalide" });
  }

  const cleanName = String(filename).replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 150);

  const book = await prisma.book.create({
    data: {
      authorId: req.authorId,
      title: cleanName.replace(/\.[^/.]+$/, ""),
      fileUrl: url,
    },
  });

  return res.status(201).json(book);
});
