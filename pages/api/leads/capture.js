import { prisma } from "../../../lib/db";
import { sendExtractEmail } from "../../../lib/email";
import { isValidEmail, clampText } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis le formulaire de la page d'extrait
// publique. Protégée par rate limiting, honeypot et (si configuré) Turnstile.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "leads-capture", 20, 600); // 20 / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
    return res.status(201).json({ ok: true, pdfUrl: null, emailSent: false });
  }

  const ip = getClientIp(req);
  const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
  if (!turnstileOk) {
    return res.status(400).json({ error: "Vérification anti-bot échouée." });
  }

  const { slug, firstName, lastName, email, whatsapp } = req.body;
  if (!slug || !email || !whatsapp) {
    return res.status(400).json({ error: "Champs requis manquants" });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Adresse email invalide" });
  }

  const extractPage = await prisma.extractPage.findUnique({
    where: { slug },
    include: { book: true },
  });
  if (!extractPage) return res.status(404).json({ error: "Page introuvable" });

  await prisma.lead.create({
    data: {
      authorId: extractPage.book.authorId,
      bookId: extractPage.bookId,
      firstName: clampText(firstName, 100),
      lastName: clampText(lastName, 100),
      email,
      whatsapp: clampText(whatsapp, 30),
      source: "extrait",
    },
  });

  // Double canal : le lead peut télécharger tout de suite (pdfUrl renvoyé
  // ci-dessous, pour une page de téléchargement direct) ET reçoit le PDF
  // par email.
  let emailSent = false;
  if (extractPage.pdfUrl) {
    const result = await sendExtractEmail({ to: email, bookTitle: extractPage.book.title, pdfUrl: extractPage.pdfUrl });
    emailSent = result.sent;
  }

  return res.status(201).json({ ok: true, pdfUrl: extractPage.pdfUrl || null, emailSent });
}
