import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();
  const payouts = await prisma.payout.findMany({
    where: { authorId: req.authorId },
    orderBy: { createdAt: "desc" },
  });
  return res.status(200).json(payouts);
});
