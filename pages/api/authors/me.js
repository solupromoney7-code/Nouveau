import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const author = await prisma.author.findUnique({
    where: { id: req.authorId },
    select: {
      id: true, name: true, email: true, region: true, emailVerified: true,
      subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
      stripeAccountId: true, stripeOnboarded: true,
      momoOperator: true, momoNumber: true,
    },
  });
  return res.status(200).json(author);
});
