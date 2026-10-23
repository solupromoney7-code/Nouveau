import { nanoid } from "nanoid";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { initChariowCheckout } from "../../../lib/chariow";
import { isValidEmail } from "../../../lib/validate";
import { variantForPriceCents } from "../../../lib/chariowTiers";
import { splitPhone } from "../../../lib/countryCodes";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis la page de vente publique quand
// l'acheteur clique "Acheter maintenant". Le livre vendu est un exemplaire
// papier : l'adresse de livraison complète est requise avant paiement.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "checkout-create", 15, 600); // 15 / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
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
  if (!salesPage || !salesPage.published || salesPage.book.author.suspended) {
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
  // Un seul produit Chariow pour tous les livres ; le prix choisi par l'auteur
  // correspond à une variante de prix. Sans variante connue on refuse plutôt
  // que de facturer un montant erroné.
  const productId = salesPage.chariowProductId || process.env.CHARIOW_BOOK_PRODUCT_ID;
  const priceVariantId = salesPage.chariowProductId ? null : variantForPriceCents(salesPage.priceCents);
  if (!productId || !process.env.CHARIOW_API_KEY || (!salesPage.chariowProductId && !priceVariantId)) {
    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
    return res.status(503).json({
      error: "Le paiement en ligne de ce livre sera disponible très bientôt. Merci de revenir un peu plus tard.",
    });
  }

  const phone = splitPhone(buyerWhatsapp);
  let result;
  try {
    result = await initChariowCheckout({
      productId,
      priceVariantId,
      email: buyerEmail,
      firstName: buyerName.split(" ")[0] || buyerName,
      lastName: buyerName.split(" ").slice(1).join(" ") || buyerName.split(" ")[0],
      phoneNumber: phone.number,
      phoneCountryIso: phone.iso,
      redirectUrl: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
      metadata: { purchaseId: purchase.id },
      shipping: {
        address: shippingAddress,
        city: shippingCity,
        zip: shippingPostalCode,
        country: shippingCountry,
      },
    });
  } catch (err) {
    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
    console.error("Checkout Chariow impossible :", err.message);
    return res.status(502).json({ error: "Le paiement n'a pas pu démarrer. Réessayez dans un instant." });
  }

  // On relie l'achat à la vente Chariow : c'est cet identifiant que le Pulse
  // renverra quand le paiement sera confirmé.
  if (result.purchase?.id) {
    await prisma.purchase.update({ where: { id: purchase.id }, data: { providerRef: result.purchase.id } });
  }

  if (result.step === "completed") {
    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
  }

  return res.status(200).json({ url: result.payment?.checkout_url, step: result.step, purchaseId: purchase.id });
}
