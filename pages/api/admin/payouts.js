import { requireAdmin } from "../../../lib/admin";
import { prisma } from "../../../lib/db";

// Toutes les demandes de reversement des auteurs.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const payouts = await prisma.payout.findMany({
      orderBy: { createdAt: "desc" },
      take: 2000,
      include: { author: { select: { id: true, name: true, email: true, momoOperator: true, momoNumber: true } } },
    });
    return res.status(200).json(
      payouts.map((p) => ({
        id: p.id,
        createdAt: p.createdAt,
        dueBy: p.dueBy,
        processedAt: p.processedAt,
        amountCents: p.amountCents,
        currency: p.currency,
        method: p.method,
        status: p.status,
        authorName: p.author?.name || "",
        authorEmail: p.author?.email || "",
        momo: p.author?.momoNumber ? `${p.author.momoOperator || ""} ${p.author.momoNumber}`.trim() : "",
      }))
    );
  } catch (error) {
    console.error("Erreur /api/admin/payouts :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
