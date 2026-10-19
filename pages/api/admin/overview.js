import { requireAdmin, PLAN_PRICES } from "../../../lib/admin";
import { prisma } from "../../../lib/db";

// Chiffres clés de la plateforme, pour le tableau de bord propriétaire.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const since = new Date(Date.now() - 30 * 24 * 3600 * 1000);

    const [
      byStatus, suspended, activeByRegion, recentAuthors,
      leadsBySource, paidAll, paid30, books, salesPublished, extractPages, payoutGroups,
    ] = await Promise.all([
      prisma.author.groupBy({ by: ["subscriptionStatus"], _count: { _all: true } }),
      prisma.author.count({ where: { suspended: true } }),
      prisma.author.groupBy({ by: ["region"], where: { subscriptionStatus: "ACTIVE" }, _count: { _all: true } }),
      prisma.author.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      prisma.lead.groupBy({ by: ["source"], _count: { _all: true } }),
      prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid" }, _sum: { amountCents: true }, _count: { _all: true } }),
      prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid", createdAt: { gte: since } }, _sum: { amountCents: true }, _count: { _all: true } }),
      prisma.book.count(),
      prisma.salesPage.count({ where: { published: true } }),
      prisma.extractPage.count(),
      prisma.payout.groupBy({ by: ["status", "currency"], _sum: { amountCents: true }, _count: { _all: true } }),
    ]);

    const statusCount = Object.fromEntries(byStatus.map((g) => [g.subscriptionStatus, g._count._all]));
    const totalAuthors = byStatus.reduce((n, g) => n + g._count._all, 0);

    // Inscriptions par jour sur 30 jours
    const days = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(Date.now() - i * 24 * 3600 * 1000);
      days.push({ date: d.toISOString().slice(0, 10), count: 0 });
    }
    const idx = Object.fromEntries(days.map((d, i) => [d.date, i]));
    for (const a of recentAuthors) {
      const k = a.createdAt.toISOString().slice(0, 10);
      if (k in idx) days[idx[k]].count += 1;
    }

    const activeAf = activeByRegion.find((g) => g.region === "AFRIQUE")?._count._all || 0;
    const activeEu = activeByRegion.find((g) => g.region === "EUROPE")?._count._all || 0;

    const leadCount = (src) => leadsBySource.find((g) => g.source === src)?._count._all || 0;
    const money = (rows) => rows.map((g) => ({ currency: g.currency, amountCents: g._sum.amountCents || 0, count: g._count._all }));
    const payoutBy = (status) => payoutGroups.filter((g) => g.status === status).map((g) => ({ currency: g.currency, amountCents: g._sum.amountCents || 0, count: g._count._all }));

    return res.status(200).json({
      authors: {
        total: totalAuthors,
        active: statusCount.ACTIVE || 0,
        trialing: statusCount.TRIALING || 0,
        pastDue: statusCount.PAST_DUE || 0,
        canceled: statusCount.CANCELED || 0,
        suspended,
        last30: recentAuthors.length,
      },
      signupsByDay: days,
      subscriptionRevenueMonthly: {
        fcfa: activeAf * PLAN_PRICES.AFRIQUE_FCFA,
        eur: Math.round(activeEu * PLAN_PRICES.EUROPE_EUR * 100) / 100,
      },
      sales: { total: money(paidAll), last30: money(paid30) },
      contacts: { extract: leadCount("extrait"), buyers: leadCount("acheteur") },
      catalog: { books, salesPublished, extractPages },
      payouts: { pending: payoutBy("PENDING"), paid: payoutBy("PAID"), failed: payoutBy("FAILED") },
    });
  } catch (error) {
    console.error("Erreur /api/admin/overview :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
