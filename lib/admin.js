import { requireAuth } from "./auth";
import { prisma } from "./db";

// Espace propriétaire : réservé aux adresses listées dans la variable
// ADMIN_EMAILS (séparées par des virgules). Par défaut : l'adresse du
// fondateur. Le compte doit aussi avoir son email vérifié.
export function adminEmails() {
  const raw = process.env.ADMIN_EMAILS || "ludovicbiaka@gmail.com";
  return raw.split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
}

export function isAdminAuthor(author) {
  return Boolean(author && author.emailVerified && adminEmails().includes(String(author.email).toLowerCase()));
}

// Protège une route API réservée au propriétaire. Pour tout autre
// utilisateur, la route répond "introuvable" (on ne révèle pas son existence).
export function requireAdmin(handler) {
  return requireAuth(async (req, res) => {
    const author = await prisma.author.findUnique({
      where: { id: req.authorId },
      select: { id: true, email: true, emailVerified: true },
    });
    if (!isAdminAuthor(author)) return res.status(404).json({ error: "Introuvable" });
    req.admin = author;
    return handler(req, res);
  });
}

// Prix des abonnements Plume, pour estimer le revenu mensuel récurrent.
export const PLAN_PRICES = { AFRIQUE_FCFA: 3900, EUROPE_EUR: 5.99 };
