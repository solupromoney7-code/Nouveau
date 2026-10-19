import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { prisma } from "./db";

const JWT_SECRET = process.env.JWT_SECRET;

export async function hashPassword(password) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export function signToken(payload, expiresIn = "7d") {
  return jwt.sign(payload, JWT_SECRET, { expiresIn });
}

export function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch {
    return null;
  }
}

// Wrapper pour protéger une route API : req.authorId est injecté si le
// token est valide, sinon la requête est rejetée avec 401.
export function requireAuth(handler) {
  return async (req, res) => {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Non authentifié" });

    const payload = verifyToken(token);
    if (!payload) return res.status(401).json({ error: "Token invalide ou expiré" });

    // Un compte suspendu perd l'accès immédiatement, même avec un token encore valide.
    const account = await prisma.author.findUnique({
      where: { id: payload.authorId },
      select: { suspended: true },
    });
    if (!account) return res.status(401).json({ error: "Compte introuvable" });
    if (account.suspended) {
      return res.status(403).json({ error: "Ce compte est suspendu. Contactez le support.", suspended: true });
    }

    req.authorId = payload.authorId;
    return handler(req, res);
  };
}
