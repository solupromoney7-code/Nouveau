import { requireAdmin } from "../../../lib/admin";
import { prisma } from "../../../lib/db";

// Tous les contacts récoltés via les pages d'extrait, tous auteurs confondus.
export default requireAdmin(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const leads = await prisma.lead.findMany({
      where: { source: "extrait" },
      orderBy: { createdAt: "desc" },
      take: 5000,
      include: {
        book: { select: { title: true } },
        author: { select: { id: true, name: true } },
      },
    });
    return res.status(200).json(
      leads.map((l) => ({
        id: l.id,
        createdAt: l.createdAt,
        firstName: l.firstName,
        lastName: l.lastName,
        email: l.email,
        whatsapp: l.whatsapp,
        bookTitle: l.book?.title || "",
        authorName: l.author?.name || "",
      }))
    );
  } catch (error) {
    console.error("Erreur /api/admin/extract-contacts :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
