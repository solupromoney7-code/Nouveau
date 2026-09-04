import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  const { id } = req.query;

  const salesPage = await prisma.salesPage.findUnique({
    where: { id },
    include: { book: true },
  });
  if (!salesPage || salesPage.book.authorId !== req.authorId) {
    return res.status(404).json({ error: "Page de vente introuvable" });
  }

  if (req.method === "GET") return res.status(200).json(salesPage);

  if (req.method === "PATCH") {
    const { problem, why, solution, priceCents, published } = req.body;
    const updated = await prisma.salesPage.update({
      where: { id },
      data: {
        ...(problem !== undefined && { problem }),
        ...(why !== undefined && { why }),
        ...(solution !== undefined && { solution }),
        ...(priceCents !== undefined && { priceCents }),
        ...(published !== undefined && { published }),
      },
    });
    return res.status(200).json(updated);
  }

  return res.status(405).end();
});
