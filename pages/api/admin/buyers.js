import { requireAdmin } from "../../../lib/admin";
import { prisma } from "../../../lib/db";

// Tous les acheteurs (commandes) de la plateforme, tous auteurs confondus.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const purchases = await prisma.purchase.findMany({
      orderBy: { createdAt: "desc" },
      take: 5000,
      include: {
        book: { select: { title: true } },
        author: { select: { id: true, name: true, email: true } },
      },
    });
    return res.status(200).json(
      purchases.map((p) => ({
        id: p.id,
        createdAt: p.createdAt,
        buyerName: p.buyerName,
        buyerEmail: p.buyerEmail,
        buyerWhatsapp: p.buyerWhatsapp || "",
        shippingAddress: p.shippingAddress,
        shippingCity: p.shippingCity,
        shippingPostalCode: p.shippingPostalCode,
        shippingCountry: p.shippingCountry,
        amountCents: p.amountCents,
        currency: p.currency,
        provider: p.provider,
        status: p.status,
        bookTitle: p.book?.title || "",
        authorName: p.author?.name || "",
        authorEmail: p.author?.email || "",
      }))
    );
  } catch (error) {
    console.error("Erreur /api/admin/buyers :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
