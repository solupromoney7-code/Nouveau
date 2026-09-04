import { prisma } from "./db";

// Paramètres business — ajustables sans toucher au code.
// CHARIOW_COMMISSION_RATE : commission Chariow par vente (~15%, réductible
// à 10% à volume selon leur grille — mets à jour ici si ton palier change).
// CHARIOW_PAYOUT_MATURITY_DAYS : nombre de jours avant qu'une vente soit
// considérée "disponible". Chariow regroupe les ventes le lendemain puis
// les transfère vers le wallet Axa Zara sous 72h max ; on ajoute une marge
// de sécurité pour ne JAMAIS promettre sous 24h un montant qu'on n'a pas
// encore réellement en main.
const COMMISSION_RATE = Number(process.env.CHARIOW_COMMISSION_RATE || 0.15);
const MATURITY_DAYS = Number(process.env.CHARIOW_PAYOUT_MATURITY_DAYS || 5);

// Calcule le solde d'un auteur zone Afrique : ventes matures (déjà
// réellement disponibles côté plateforme) moins les reversements déjà
// demandés/effectués. Utilisé à la fois par /api/payouts/balance (lecture)
// et /api/payouts/request (validation) pour ne jamais désynchroniser les deux.
export async function computeAfriqueBalance(authorId) {
  const maturityCutoff = new Date(Date.now() - MATURITY_DAYS * 24 * 60 * 60 * 1000);

  const [maturePaidAgg, pendingMaturityAgg, payouts] = await Promise.all([
    prisma.purchase.aggregate({
      where: { authorId, status: "paid", createdAt: { lte: maturityCutoff } },
      _sum: { amountCents: true },
    }),
    prisma.purchase.aggregate({
      where: { authorId, status: "paid", createdAt: { gt: maturityCutoff } },
      _sum: { amountCents: true },
    }),
    prisma.payout.findMany({ where: { authorId, status: { in: ["PENDING", "PAID"] } } }),
  ]);

  const matureGrossCents = maturePaidAgg._sum.amountCents || 0;
  const pendingMaturityGrossCents = pendingMaturityAgg._sum.amountCents || 0;
  const totalGrossCents = matureGrossCents + pendingMaturityGrossCents;

  const net = (grossCents) => Math.round(grossCents * (1 - COMMISSION_RATE));

  const matureNetCents = net(matureGrossCents);
  const pendingMaturityNetCents = net(pendingMaturityGrossCents);
  const totalNetCents = net(totalGrossCents);

  const totalPayoutCents = payouts.reduce((sum, p) => sum + p.amountCents, 0);
  const pendingPayoutCents = payouts.filter((p) => p.status === "PENDING").reduce((sum, p) => sum + p.amountCents, 0);

  return {
    commissionRate: COMMISSION_RATE,
    maturityDays: MATURITY_DAYS,
    totalGrossCents,
    totalNetCents,
    matureNetCents,
    pendingMaturityNetCents,
    totalPayoutCents,
    pendingPayoutCents,
    // Ce qui est réellement demandable maintenant : net des ventes matures,
    // moins ce qui a déjà été reversé ou est en cours de reversement.
    availableCents: Math.max(0, matureNetCents - totalPayoutCents),
    currency: "XOF",
    method: "momo",
  };
}
