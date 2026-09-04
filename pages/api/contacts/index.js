import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const source = req.query.source === "acheteurs" ? "acheteur" : "extrait";
  const leads = await prisma.lead.findMany({
    where: { authorId: req.authorId, source },
    orderBy: { createdAt: "desc" },
  });
  return res.status(200).json(leads);
});
