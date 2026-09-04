import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSalesPageCopy } from "../../../lib/ai";
import { createChariowProduct } from "../../../lib/chariow";

function slugify(title) {
  return title
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, priceCents, currency } = req.body;
  if (!bookId || !priceCents || !currency) {
    return res.status(400).json({ error: "bookId, priceCents et currency sont requis" });
  }

  const book = await prisma.book.findFirst({
    where: { id: bookId, authorId: req.authorId },
    include: { author: true },
  });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const copy = await generateSalesPageCopy(book);
  const slug = `${slugify(book.title)}-${book.id.slice(-5)}`;

  let salesPage = await prisma.salesPage.upsert({
    where: { bookId: book.id },
    update: { priceCents, currency, ...copy },
    create: { bookId: book.id, slug, priceCents, currency, ...copy },
  });

  // Zone Afrique : provisionne un produit Chariow pour ce livre s'il n'en a
  // pas déjà un, afin que le checkout (POST /api/checkout/create) puisse
  // s'en servir. Best-effort — voir l'avertissement dans lib/chariow.js.
  if (book.author.region === "AFRIQUE" && !salesPage.chariowProductId) {
    try {
      const product = await createChariowProduct({
        name: book.title,
        description: copy.solution?.slice(0, 300) || book.title,
        priceValue: Math.round(priceCents / 100),
        currency,
      });
      salesPage = await prisma.salesPage.update({
        where: { id: salesPage.id },
        data: { chariowProductId: product.id },
      });
    } catch (err) {
      // On ne fait pas échouer la génération de la page pour autant : la
      // page de vente reste utilisable, mais le checkout renverra une
      // erreur explicite tant que chariowProductId n'est pas configuré
      // (manuellement si besoin, voir README).
      console.error("Provisionnement produit Chariow échoué :", err.message);
    }
  }

  return res.status(201).json(salesPage);
});
