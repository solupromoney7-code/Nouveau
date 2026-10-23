import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { initChariowCheckout } from "../../../lib/chariow";
import { splitPhone } from "../../../lib/countryCodes";

// Un seul produit Chariow pour l'abonnement Plume, facturé dans la devise
// de la zone de l'auteur grâce au paramètre payment_currency (conversion
// automatique gérée par Chariow). Crée ce produit une fois dans ton
// dashboard Chariow et renseigne son ID dans CHARIOW_SUBSCRIPTION_PRODUCT_ID.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    const [firstName, ...rest] = author.name.split(" ");

    // Chariow exige un numéro de téléphone pour tout achat.
    const phoneInput = String(req.body?.phone || "").trim();
    const phone = splitPhone(phoneInput);
    if (phone.number.length < 6) {
      return res.status(400).json({ error: "Indiquez votre numéro de téléphone pour continuer." });
    }

    const result = await initChariowCheckout({
      productId: author.region === "EUROPE"
        ? (process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID_EUROPE || process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID)
        : process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
      email: author.email,
      firstName: firstName || author.name,
      lastName: rest.join(" ") || author.name,
      phoneNumber: phone.number,
      phoneCountryIso: phone.iso,
      redirectUrl: `${process.env.APP_URL}/dashboard/abonnement?paiement=retour`,
      paymentCurrency: author.region === "EUROPE" ? "EUR" : "XOF",
      metadata: { authorId: author.id, kind: "subscription" },
    });

    if (result.step === "already_purchased") {
      return res.status(200).json({ status: "already_active" });
    }

    return res.status(200).json({ url: result.payment?.checkout_url });
  } catch (error) {
    console.error("Erreur /api/subscriptions/checkout :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
