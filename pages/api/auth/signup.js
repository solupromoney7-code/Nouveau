import { prisma } from "../../../lib/db";
import { hashPassword, signToken } from "../../../lib/auth";
import { isValidEmail, clampText } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";
import { sendVerificationEmail } from "../../../lib/email";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "signup", 5, 600); // 5 inscriptions / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
    // On répond un faux succès pour ne pas indiquer au bot qu'il a été détecté.
    return res.status(201).json({ token: null, author: null });
  }

  const ip = getClientIp(req);
  const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
  if (!turnstileOk) {
    return res.status(400).json({ error: "Vérification anti-bot échouée." });
  }

  const { email, password, name, region } = req.body;
  if (!email || !password || !name) {
    return res.status(400).json({ error: "Email, mot de passe et nom sont requis" });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Adresse email invalide" });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: "Le mot de passe doit contenir au moins 8 caractères" });
  }

  const existing = await prisma.author.findUnique({ where: { email } });
  if (existing) return res.status(409).json({ error: "Cet email est déjà utilisé" });

  const passwordHash = await hashPassword(password);
  const trialEndsAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // essai gratuit 7 jours

  const author = await prisma.author.create({
    data: {
      email,
      passwordHash,
      name: clampText(name, 120),
      region: region === "EUROPE" ? "EUROPE" : "AFRIQUE",
      trialEndsAt,
    },
  });

  // Email de vérification — n'empêche pas la connexion immédiate, mais
  // certaines actions sensibles (reversement) resteront bloquées tant que
  // emailVerified est false (voir pages/api/payouts/request.js).
  const verifyToken = signToken({ authorId: author.id, purpose: "verify_email" }, "1d");
  const verifyUrl = `${process.env.APP_URL}/api/auth/verify-email?token=${verifyToken}`;
  sendVerificationEmail({ to: author.email, verifyUrl }).catch((err) =>
    console.error("Échec envoi email de vérification :", err)
  );

  const token = signToken({ authorId: author.id });
  return res.status(201).json({
    token,
    author: { id: author.id, name: author.name, email: author.email, region: author.region, emailVerified: false },
  });
}
