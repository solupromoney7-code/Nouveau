import crypto from "crypto";
import { prisma } from "../../../lib/db";
import { getChariowSale } from "../../../lib/chariow";
import { sendPurchaseConfirmationEmail } from "../../../lib/email";

// Pulse Chariow (webhook). Configuration côté Chariow :
//   Automatisations > Pulses > Créer un pulse
//   URL   : https://VOTRE-SITE/api/webhooks/chariow
//   Événements : "Vente réussie" (successful.sale) et "Vente échouée" (failed.sale)
// Puis copier le "Signing secret" (whsec_...) du pulse dans la variable
// d'environnement CHARIOW_WEBHOOK_SECRET.
//
// Sécurité : chaque requête est signée (en-tête x-chariow-signature =
// "sha256=" + HMAC-SHA256 du corps brut avec le secret du pulse). On vérifie
// cette signature sur le corps BRUT avant de lire quoi que ce soit.
export const config = { api: { bodyParser: false } };

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function signatureIsValid(rawBody, header, secret) {
  if (!header || !secret) return false;
  const expected = "sha256=" + crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
  const a = Buffer.from(expected);
  const b = Buffer.from(String(header));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function formatAmount(cents, currency) {
  const amount = (cents || 0) / 100;
  return currency === "EUR" ? `${amount.toFixed(2)} €` : `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const secret = process.env.CHARIOW_WEBHOOK_SECRET;
  if (!secret) {
    console.error("CHARIOW_WEBHOOK_SECRET manquant — Pulse Chariow rejeté.");
    return res.status(500).json({ error: "Webhook non configuré" });
  }

  const raw = await readRawBody(req);
  if (!signatureIsValid(raw, req.headers["x-chariow-signature"], secret)) {
    return res.status(401).json({ error: "Signature invalide" });
  }

  let payload;
  try {
    payload = JSON.parse(raw.toString("utf8"));
  } catch {
    return res.status(400).json({ error: "Payload invalide" });
  }

  // Chariow écrit les événements "successful.sale" (documentation) ou
  // "successful_sale" (tableau de bord) : on accepte les deux.
  const event = String(payload.event || req.headers["x-pulse-event"] || "").replace(/_/g, ".");
  const sale = payload.sale || {};
  const productId = payload.product?.id;
  const customerEmail = (payload.customer?.email || "").toLowerCase();

  try {
    if (event === "successful.sale") {
      // Reconfirmation auprès de Chariow (défense en profondeur). Si la
      // lecture échoue pour une raison technique, la signature valide suffit.
      try {
        const confirmed = sale.id ? await getChariowSale(sale.id) : null;
        if (confirmed && !["completed", "settled"].includes(confirmed.status)) {
          return res.status(200).json({ received: true, ignored: "not_completed" });
        }
      } catch (err) {
        console.error("Reconfirmation Chariow impossible :", err.message);
      }

      // --- Abonnement Plume ---
      if (productId && productId === process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID) {
        const authorId = sale.custom_metadata?.authorId;
        const author = authorId
          ? await prisma.author.findUnique({ where: { id: authorId } })
          : customerEmail
          ? await prisma.author.findFirst({ where: { email: { equals: customerEmail, mode: "insensitive" } } })
          : null;
        if (author) {
          // Date de fin calculée à partir du paiement : rejouer le même Pulse
          // ne prolonge donc jamais l'abonnement une deuxième fois.
          const paidAt = sale.completed_at ? new Date(sale.completed_at) : new Date();
          const end = new Date(paidAt.getTime() + 30 * 24 * 60 * 60 * 1000);
          await prisma.author.update({
            where: { id: author.id },
            data: {
              subscriptionStatus: "ACTIVE",
              currentPeriodEnd: author.currentPeriodEnd && author.currentPeriodEnd > end ? author.currentPeriodEnd : end,
            },
          });
        }
        return res.status(200).json({ received: true });
      }

      // --- Achat d'un livre ---
      let purchase = sale.id
        ? await prisma.purchase.findFirst({ where: { provider: "chariow", providerRef: sale.id }, include: { book: true } })
        : null;
      if (!purchase && customerEmail) {
        purchase = await prisma.purchase.findFirst({
          where: { provider: "chariow", buyerEmail: { equals: customerEmail, mode: "insensitive" }, status: "pending" },
          orderBy: { createdAt: "desc" },
          include: { book: true },
        });
      }

      if (purchase && purchase.status !== "paid") {
        await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
        await prisma.lead.create({
          data: {
            authorId: purchase.authorId,
            bookId: purchase.bookId,
            firstName: purchase.buyerName,
            lastName: "",
            email: purchase.buyerEmail,
            whatsapp: purchase.buyerWhatsapp || "",
            source: "acheteur",
          },
        });
        await sendPurchaseConfirmationEmail({
          to: purchase.buyerEmail,
          buyerName: purchase.buyerName,
          bookTitle: purchase.book.title,
          amountFormatted: formatAmount(purchase.amountCents, purchase.currency),
        });
      }
    }

    if (event === "failed.sale" && sale.id) {
      await prisma.purchase.updateMany({
        where: { provider: "chariow", providerRef: sale.id, status: "pending" },
        data: { status: "failed" },
      });
    }
  } catch (error) {
    console.error("Erreur Pulse Chariow :", error);
    return res.status(500).json({ error: "Erreur de traitement" });
  }

  return res.status(200).json({ received: true });
}
