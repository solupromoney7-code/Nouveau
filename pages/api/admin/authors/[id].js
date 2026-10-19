import { requireAdmin, isAdminAuthor } from "../../../../lib/admin";
import { prisma } from "../../../../lib/db";

// Suspend ou réactive un compte auteur.
// Un compte suspendu ne peut plus se connecter, et ses pages publiques
// (vente, extrait, boutique) ne sont plus accessibles.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();

  try {
    const { id } = req.query;
    // Accès à vie : offrir ou retirer (aucun abonnement à payer)
    if (typeof req.body?.lifetime === "boolean") {
      const exists = await prisma.author.findUnique({ where: { id }, select: { id: true } });
      if (!exists) return res.status(404).json({ error: "Auteur introuvable" });
      const updated = await prisma.author.update({
        where: { id },
        data: { lifetimeAccess: req.body.lifetime },
        select: { id: true, lifetimeAccess: true },
      });
      return res.status(200).json(updated);
    }

    if (typeof req.body?.suspended !== "boolean") {
      return res.status(400).json({ error: "Paramètre « suspended » ou « lifetime » requis." });
    }

    const target = await prisma.author.findUnique({
      where: { id },
      select: { id: true, email: true, emailVerified: true },
    });
    if (!target) return res.status(404).json({ error: "Auteur introuvable" });

    if (req.body.suspended && (target.id === req.admin.id || isAdminAuthor(target))) {
      return res.status(400).json({ error: "Impossible de suspendre un compte administrateur." });
    }

    const updated = await prisma.author.update({
      where: { id },
      data: { suspended: req.body.suspended, suspendedAt: req.body.suspended ? new Date() : null },
      select: { id: true, suspended: true, suspendedAt: true },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur PATCH /api/admin/authors/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
