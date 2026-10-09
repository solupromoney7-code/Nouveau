#!/bin/bash
set -e

echo "Mise a jour de pages/api/books/upload.js (ajout de logs d'erreur detailles)..."

mkdir -p pages/api/books

cat > pages/api/books/upload.js << 'EOF'
import { handleUpload } from "@vercel/blob/client";
import { verifyToken } from "../../../lib/auth";

export default async function handler(req, res) {
  try {
    const body = req.body;

    const jsonResponse = await handleUpload({
      body,
      request: req,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        let payload;
        try {
          payload = JSON.parse(clientPayload || "{}");
        } catch (e) {
          throw new Error("Payload client invalide (JSON illisible).");
        }

        const token = payload.token;
        if (!token) {
          throw new Error("Authentification manquante : aucun jeton recu.");
        }

        let decoded;
        try {
          decoded = verifyToken(token);
        } catch (e) {
          throw new Error("Session invalide ou expiree (jeton rejete).");
        }

        if (!decoded || !decoded.authorId) {
          throw new Error("Session invalide ou expiree (jeton sans authorId).");
        }

        const ext = pathname.split(".").pop().toLowerCase();
        if (!["pdf", "epub"].includes(ext)) {
          throw new Error("Format de fichier non autorise (PDF ou EPUB uniquement).");
        }

        return {
          allowedContentTypes: [
            "application/pdf",
            "application/epub+zip",
            "application/octet-stream",
          ],
          maximumSizeInBytes: 50 * 1024 * 1024,
          addRandomSuffix: true,
          tokenPayload: JSON.stringify({ authorId: decoded.authorId }),
        };
      },
      onUploadCompleted: async () => {
        // Volontairement vide : l'enregistrement en base se fait via
        // /api/books/register, appele par le client une fois l'upload termine.
      },
    });

    return res.status(200).json(jsonResponse);
  } catch (error) {
    console.error("Erreur dans /api/books/upload :", error);
    return res
      .status(400)
      .json({ error: error.message || "Erreur inconnue lors de l'upload." });
  }
}
EOF

echo ""
echo "Fichier mis a jour avec succes."
echo "Prochaine etape : git add, commit, pull, push (voir les instructions)."
