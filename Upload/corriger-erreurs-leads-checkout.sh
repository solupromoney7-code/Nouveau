#!/bin/bash
set -e

mkdir -p "pages/api/leads"
cat > "pages/api/leads/capture.js" << 'FILE_EOF_MARKER'
import { prisma } from "../../../lib/db";
import { sendExtractEmail } from "../../../lib/email";
import { isValidEmail, clampText } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis le formulaire de la page d'extrait
// publique. Protégée par rate limiting, honeypot et (si configuré) Turnstile.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "leads-capture", 20, 600); // 20 / 10 min / IP
    if (!rl.allowed) return;

    if (isHoneypotTriggered(req.body)) {
      console.warn("leads/capture: honeypot déclenché, requête ignorée.", {
        website: req.body?.website,
      });
      return res.status(201).json({ ok: true, pdfUrl: null, emailSent: false });
    }

    const ip = getClientIp(req);
    const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
    if (!turnstileOk) {
      return res.status(400).json({ error: "Vérification anti-bot échouée." });
    }

    const { slug, firstName, lastName, email, whatsapp } = req.body;
    if (!slug || !email || !whatsapp) {
      return res.status(400).json({ error: "Champs requis manquants" });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "Adresse email invalide" });
    }

    const extractPage = await prisma.extractPage.findUnique({
      where: { slug },
      include: { book: true },
    });
    if (!extractPage) return res.status(404).json({ error: "Page introuvable" });

    await prisma.lead.create({
      data: {
        authorId: extractPage.book.authorId,
        bookId: extractPage.bookId,
        firstName: clampText(firstName, 100),
        lastName: clampText(lastName, 100),
        email,
        whatsapp: clampText(whatsapp, 30),
        source: "extrait",
      },
    });

    // Double canal : le lead peut télécharger tout de suite (pdfUrl renvoyé
    // ci-dessous, pour une page de téléchargement direct) ET reçoit le PDF
    // par email.
    let emailSent = false;
    if (extractPage.pdfUrl) {
      const result = await sendExtractEmail({ to: email, bookTitle: extractPage.book.title, pdfUrl: extractPage.pdfUrl });
      emailSent = result.sent;
    }

    return res.status(201).json({ ok: true, pdfUrl: extractPage.pdfUrl || null, emailSent });
  } catch (error) {
    console.error("Erreur /api/leads/capture :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
FILE_EOF_MARKER

mkdir -p "pages/api/checkout"
cat > "pages/api/checkout/create.js" << 'FILE_EOF_MARKER'
import { nanoid } from "nanoid";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { initChariowCheckout } from "../../../lib/chariow";
import { isValidEmail } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis la page de vente publique quand
// l'acheteur clique "Acheter maintenant". Le livre vendu est un exemplaire
// papier : l'adresse de livraison complète est requise avant paiement.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "checkout-create", 15, 600); // 15 / 10 min / IP
    if (!rl.allowed) return;

    if (isHoneypotTriggered(req.body)) {
      console.warn("checkout/create: honeypot déclenché, requête ignorée.", {
        website: req.body?.website,
      });
      return res.status(400).json({ error: "Requête invalide." });
    }

    const ip = getClientIp(req);
    const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
    if (!turnstileOk) {
      return res.status(400).json({ error: "Vérification anti-bot échouée." });
    }

    const {
      slug, buyerName, buyerEmail, buyerWhatsapp,
      shippingAddress, shippingCity, shippingPostalCode, shippingCountry,
    } = req.body;

    if (!slug || !buyerName || !buyerEmail) {
      return res.status(400).json({ error: "Champs acheteur requis manquants" });
    }
    if (!isValidEmail(buyerEmail)) {
      return res.status(400).json({ error: "Adresse email invalide" });
    }
    if (!shippingAddress || !shippingCity || !shippingPostalCode || !shippingCountry) {
      return res.status(400).json({ error: "Adresse de livraison complète requise" });
    }

    const salesPage = await prisma.salesPage.findUnique({
      where: { slug },
      include: { book: { include: { author: true } } },
    });
    if (!salesPage || !salesPage.published) {
      return res.status(404).json({ error: "Page de vente introuvable ou non publiée" });
    }

    const author = salesPage.book.author;
    const transactionId = nanoid();

    const purchase = await prisma.purchase.create({
      data: {
        authorId: author.id,
        bookId: salesPage.bookId,
        buyerEmail,
        buyerName,
        buyerWhatsapp,
        shippingAddress,
        shippingCity,
        shippingPostalCode,
        shippingCountry,
        amountCents: salesPage.priceCents,
        currency: salesPage.currency,
        provider: author.region === "EUROPE" ? "stripe" : "chariow",
        providerRef: transactionId,
        status: "pending",
      },
    });

    // --- Zone Europe : Stripe Checkout + Connect ---
    if (author.region === "EUROPE") {
      if (!author.stripeAccountId || !author.stripeOnboarded) {
        return res.status(400).json({ error: "L'auteur n'a pas encore connecté son compte Stripe" });
      }

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        line_items: [
          {
            price_data: {
              currency: salesPage.currency.toLowerCase(),
              product_data: { name: salesPage.book.title },
              unit_amount: salesPage.priceCents,
            },
            quantity: 1,
          },
        ],
        // Stripe peut aussi collecter l'adresse lui-même (shipping_address_collection) ;
        // on la garde ici pour rester cohérent avec la zone Afrique/Chariow et
        // n'avoir qu'une seule source de vérité (Purchase).
        payment_intent_data: {
          transfer_data: { destination: author.stripeAccountId },
          // application_fee_amount: Math.round(salesPage.priceCents * 0.05), // commission plateforme, optionnelle
        },
        customer_email: buyerEmail,
        metadata: { purchaseId: purchase.id },
        success_url: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
        cancel_url: `${process.env.APP_URL}/p/${slug}?paiement=annule`,
      });

      await prisma.purchase.update({ where: { id: purchase.id }, data: { providerRef: session.id } });
      return res.status(200).json({ url: session.url, purchaseId: purchase.id });
    }

    // --- Zone Afrique francophone : Chariow ---
    if (!salesPage.chariowProductId) {
      return res.status(400).json({
        error: "Produit Chariow non configuré pour ce livre. Renseigne-le manuellement dans le dashboard Chariow si le provisioning automatique a échoué.",
      });
    }

    const result = await initChariowCheckout({
      productId: salesPage.chariowProductId,
      email: buyerEmail,
      firstName: buyerName.split(" ")[0] || buyerName,
      lastName: buyerName.split(" ").slice(1).join(" ") || buyerName,
      phoneNumber: buyerWhatsapp,
      redirectUrl: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
      metadata: { purchaseId: purchase.id },
    });

    if (result.step === "completed") {
      await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
    }

    return res.status(200).json({ url: result.payment?.checkout_url, step: result.step, purchaseId: purchase.id });
  } catch (error) {
    console.error("Erreur /api/checkout/create :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
FILE_EOF_MARKER

echo "Fichiers mis à jour avec succès."
