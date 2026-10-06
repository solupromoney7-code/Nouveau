import { handleUpload } from "@vercel/blob/client";
import { verifyToken } from "../../../lib/auth";

// Génère un jeton d'upload "client" : le fichier du livre part directement
// du navigateur vers Vercel Blob, SANS passer par cette fonction serverless.
// Raison : les fonctions serverless Vercel plafonnent le corps d'une requête
// à 4,5 Mo quel que soit le plan — bien en dessous des 50 Mo qu'on promet à
// l'auteur. Un upload "classique" (fichier envoyé tel quel à l'API) échoue
// donc dès qu'un PDF dépasse ~4 Mo, avec une erreur Vercel générique (pas du
// JSON) que le frontend ne sait pas afficher proprement.
//
// Cette route n'est pas protégée par requireAuth : le navigateur ne peut
// pas lui envoyer d'en-tête personnalisé via le client Vercel Blob, donc le
// jeton JWT de l'auteur est transmis dans clientPayload et vérifié
// manuellement ci-dessous. onUploadCompleted (rappel serveur-à-serveur de
// Vercel une fois l'upload terminé) n'est pas utilisé pour écrire en base :
// il ne fonctionne pas en local, et le navigateur — déjà authentifié —
// enregistre lui-même le livre juste après, via POST /api/books/register.
const ALLOWED_EXTENSIONS = [".pdf", ".epub"];
const MAX_SIZE_BYTES = 50 * 1024 * 1024; // 50 Mo

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const jsonResponse = await handleUpload({
      body: req.body,
      request: req,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        let authorId = null;
        try {
          const parsed = JSON.parse(clientPayload || "{}");
          const tokenPayload = parsed.token && verifyToken(parsed.token);
          authorId = tokenPayload?.authorId || null;
        } catch {
          authorId = null;
        }
        if (!authorId) {
          throw new Error("Non authentifié");
        }

        const ext = pathname.slice(pathname.lastIndexOf(".")).toLowerCase();
        if (!ALLOWED_EXTENSIONS.includes(ext)) {
          throw new Error("Format non autorisé — seuls PDF et EPUB sont acceptés.");
        }

        return {
          allowedContentTypes: ["application/pdf", "application/epub+zip", "application/octet-stream"],
          addRandomSuffix: true,
          maximumSizeInBytes: MAX_SIZE_BYTES,
        };
      },
      onUploadCompleted: async () => {
        // Volontairement vide — voir commentaire en tête de fichier.
      },
    });

    return res.status(200).json(jsonResponse);
  } catch (error) {
    return res.status(400).json({ error: error.message });
  }
}
