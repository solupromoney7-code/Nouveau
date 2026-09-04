import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { signToken } from "../../../lib/auth";
import { sendVerificationEmail } from "../../../lib/email";
import { checkRateLimit } from "../../../lib/rateLimit";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "resend-verification", 3, 600); // 3 / 10 min / IP
  if (!rl.allowed) return;

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (author.emailVerified) return res.status(200).json({ ok: true, alreadyVerified: true });

  const verifyToken = signToken({ authorId: author.id, purpose: "verify_email" }, "1d");
  const verifyUrl = `${process.env.APP_URL}/api/auth/verify-email?token=${verifyToken}`;
  const result = await sendVerificationEmail({ to: author.email, verifyUrl });

  return res.status(200).json({ sent: result.sent });
});
