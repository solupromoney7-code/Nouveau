import { prisma } from "../../../lib/db";
import { hashPassword, verifyToken } from "../../../lib/auth";
import { checkRateLimit } from "../../../lib/rateLimit";

// Enregistre le nouveau mot de passe à partir du lien reçu par email.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "reset-password", 10, 600); // 10 / 10 min / IP
    if (!rl.allowed) return;

    const { token, password } = req.body || {};
    if (typeof password !== "string" || password.length < 8) {
      return res.status(400).json({ error: "Le mot de passe doit contenir au moins 8 caractères" });
    }
    if (password.length > 200) {
      return res.status(400).json({ error: "Mot de passe trop long" });
    }

    const payload = typeof token === "string" ? verifyToken(token) : null;
    const invalid = { error: "Lien invalide ou expiré. Refaites une demande de réinitialisation." };
    if (!payload || payload.purpose !== "reset_password") return res.status(400).json(invalid);

    const author = await prisma.author.findUnique({ where: { id: payload.authorId } });
    // Si le mot de passe a déjà été changé depuis l'envoi du lien, l'extrait
    // ne correspond plus : le lien ne peut servir qu'une seule fois.
    if (!author || author.passwordHash.slice(-12) !== payload.pw) return res.status(400).json(invalid);

    const passwordHash = await hashPassword(password);
    // Cliquer sur le lien reçu par email prouve que l'adresse est bien la
    // sienne : on la marque donc aussi comme confirmée.
    await prisma.author.update({
      where: { id: author.id },
      data: { passwordHash, emailVerified: true },
    });

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("Erreur /api/auth/reset-password :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
