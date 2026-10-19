import { requireAdmin } from "../../../../lib/admin";
import { prisma } from "../../../../lib/db";

// Relie (ou délie) le produit Chariow d'une page de vente.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();

  try {
    const { id } = req.query;
    const raw = req.body?.chariowProductId;
    if (typeof raw !== "string") return res.status(400).json({ error: "chariowProductId requis" });

    const value = raw.trim();
    if (value && !/^[A-Za-z0-9_-]{3,100}$/.test(value)) {
      return res.status(400).json({ error: "Identifiant de produit invalide (ex. prd_abc123)." });
    }

    const page = await prisma.salesPage.findUnique({ where: { id }, select: { id: true } });
    if (!page) return res.status(404).json({ error: "Page de vente introuvable" });

    const updated = await prisma.salesPage.update({
      where: { id },
      data: { chariowProductId: value || null },
      select: { id: true, chariowProductId: true },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur PATCH /api/admin/sales-pages/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
