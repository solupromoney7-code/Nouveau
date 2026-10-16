import { handleUpload } from "@vercel/blob/client";
import { verifyToken } from "../../../lib/auth";

// Même principe que /api/books/upload mais pour les images de couverture
// (photo du livre) : upload direct navigateur -> Vercel Blob, limité aux
// formats image et à une taille raisonnable.
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
        if (!["jpg", "jpeg", "png", "webp"].includes(ext)) {
          throw new Error("Format d'image non autorise (JPG, PNG ou WEBP uniquement).");
        }

        return {
          allowedContentTypes: ["image/jpeg", "image/png", "image/webp"],
          maximumSizeInBytes: 10 * 1024 * 1024,
          addRandomSuffix: true,
          tokenPayload: JSON.stringify({ authorId: decoded.authorId }),
        };
      },
      onUploadCompleted: async () => {
        // Volontairement vide : l'enregistrement en base se fait côté
        // client via PATCH /api/books/[id] une fois l'upload termine.
      },
    });

    return res.status(200).json(jsonResponse);
  } catch (error) {
    console.error("Erreur dans /api/books/upload-cover :", error);
    return res
      .status(400)
      .json({ error: error.message || "Erreur inconnue lors de l'upload." });
  }
}
