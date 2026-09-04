import { prisma } from "../../../lib/db";

// Route PUBLIQUE — alimente la page de remerciement (GET /api/public/purchase?id=...)
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();
  const { id } = req.query;
  if (!id) return res.status(400).json({ error: "id requis" });

  const purchase = await prisma.purchase.findUnique({
    where: { id },
    include: { book: true },
  });
  if (!purchase) return res.status(404).json({ error: "Commande introuvable" });

  return res.status(200).json({
    status: purchase.status,
    bookTitle: purchase.book.title,
    buyerName: purchase.buyerName,
    buyerEmail: purchase.buyerEmail,
    amountCents: purchase.amountCents,
    currency: purchase.currency,
    shippingAddress: purchase.shippingAddress,
    shippingCity: purchase.shippingCity,
    shippingPostalCode: purchase.shippingPostalCode,
    shippingCountry: purchase.shippingCountry,
  });
}
