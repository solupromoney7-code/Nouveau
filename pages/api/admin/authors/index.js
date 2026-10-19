import { requireAdmin, isAdminAuthor } from "../../../../lib/admin";
import { prisma } from "../../../../lib/db";

// Liste de tous les auteurs avec leur activité et leurs revenus.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const [authors, purchases, leads, payouts] = await Promise.all([
      prisma.author.findMany({
        orderBy: { createdAt: "desc" },
        select: {
          id: true, name: true, email: true, emailVerified: true, region: true,
          createdAt: true, subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
          suspended: true, suspendedAt: true, lifetimeAccess: true,
          _count: { select: { books: true } },
        },
      }),
      prisma.purchase.groupBy({
        by: ["authorId", "currency"],
        where: { status: "paid" },
        _sum: { amountCents: true },
        _count: { _all: true },
      }),
      prisma.lead.groupBy({ by: ["authorId", "source"], _count: { _all: true } }),
      prisma.payout.groupBy({ by: ["authorId", "status", "currency"], _sum: { amountCents: true } }),
    ]);

    const rows = authors.map((a) => ({
      id: a.id,
      name: a.name,
      email: a.email,
      emailVerified: a.emailVerified,
      region: a.region,
      createdAt: a.createdAt,
      subscriptionStatus: a.subscriptionStatus,
      trialEndsAt: a.trialEndsAt,
      currentPeriodEnd: a.currentPeriodEnd,
      lifetimeAccess: a.lifetimeAccess,
      suspended: a.suspended,
      suspendedAt: a.suspendedAt,
      isAdmin: isAdminAuthor(a),
      books: a._count.books,
      extractContacts: leads.find((l) => l.authorId === a.id && l.source === "extrait")?._count._all || 0,
      sales: purchases
        .filter((p) => p.authorId === a.id)
        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0, count: p._count._all })),
      payoutsPaid: payouts
        .filter((p) => p.authorId === a.id && p.status === "PAID")
        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0 })),
      payoutsPending: payouts
        .filter((p) => p.authorId === a.id && p.status === "PENDING")
        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0 })),
    }));

    return res.status(200).json(rows);
  } catch (error) {
    console.error("Erreur /api/admin/authors :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
