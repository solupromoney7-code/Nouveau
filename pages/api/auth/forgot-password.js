import { prisma } from "../../../lib/db";
import { signToken } from "../../../lib/auth";
import { isValidEmail } from "../../../lib/validate";
import { sendPasswordResetEmail } from "../../../lib/email";
import { checkRateLimit } from "../../../lib/rateLimit";

// Demande de réinitialisation du mot de passe. On répond TOUJOURS la même
// chose, que l'email existe ou non : sinon n'importe qui pourrait s'en
// servir pour deviner quelles adresses ont un compte sur Plume.
//
// Le lien contient un jeton signé valable 1 heure. Il embarque aussi un
// extrait de l'ancien mot de passe chiffré : dès que le mot de passe est
// changé, le lien devient automatiquement inutilisable (usage unique).
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "forgot-password", 5, 600); // 5 / 10 min / IP
    if (!rl.allowed) return;

    const email = typeof req.body?.email === "string" ? req.body.email.trim() : "";
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "Adresse email invalide" });
    }

    const author = await prisma.author.findUnique({ where: { email } });
    if (author) {
      const token = signToken(
        { authorId: author.id, purpose: "reset_password", pw: author.passwordHash.slice(-12) },
        "1h"
      );
      const resetUrl = `${process.env.APP_URL}/reinitialiser-mot-de-passe?token=${token}`;
      await sendPasswordResetEmail({ to: author.email, resetUrl });
    }

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("Erreur /api/auth/forgot-password :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
