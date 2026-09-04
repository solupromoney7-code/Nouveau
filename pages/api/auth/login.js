import { prisma } from "../../../lib/db";
import { verifyPassword, signToken } from "../../../lib/auth";
import { checkRateLimit } from "../../../lib/rateLimit";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "login", 10, 300); // 10 tentatives / 5 min / IP
  if (!rl.allowed) return;

  const { email, password } = req.body;
  const author = await prisma.author.findUnique({ where: { email } });
  if (!author) return res.status(401).json({ error: "Identifiants invalides" });

  const valid = await verifyPassword(password, author.passwordHash);
  if (!valid) return res.status(401).json({ error: "Identifiants invalides" });

  const token = signToken({ authorId: author.id });
  return res.status(200).json({
    token,
    author: { id: author.id, name: author.name, email: author.email, region: author.region, emailVerified: author.emailVerified },
  });
}
