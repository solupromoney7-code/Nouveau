import { prisma } from "../../../lib/db";
import { verifyToken } from "../../../lib/auth";

function htmlPage(title, message) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${title}</title></head>
<body style="font-family: -apple-system, sans-serif; text-align:center; padding: 80px 20px; color:#241F17;">
  <h1>${title}</h1><p>${message}</p>
</body></html>`;
}

// Lien cliqué depuis l'email de vérification. Pas de frontend dédié encore
// (voir README) — on renvoie directement une petite page HTML de confirmation.
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const { token } = req.query;
  const payload = token ? verifyToken(token) : null;

  if (!payload || payload.purpose !== "verify_email") {
    res.setHeader("Content-Type", "text/html");
    return res.status(400).send(htmlPage("Lien invalide ou expiré", "Redemandez un email de confirmation depuis votre espace auteur."));
  }

  await prisma.author.update({ where: { id: payload.authorId }, data: { emailVerified: true } });

  res.setHeader("Content-Type", "text/html");
  return res.status(200).send(htmlPage("Email confirmé ✓", "Vous pouvez fermer cette page et retourner sur Plume."));
}
