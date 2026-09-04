import { PrismaClient } from "@prisma/client";

// Évite de recréer une connexion Prisma à chaque hot-reload / invocation
// serverless en dev. En production sur Vercel, chaque fonction reste légère.
const globalForPrisma = globalThis;

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
