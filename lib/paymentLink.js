// Lien de paiement fourni par l'auteur (zone Europe) : l'argent va directement
// sur son compte, Plume ne touche jamais les fonds.
const ALLOWED_HOSTS = ["buy.stripe.com", "checkout.stripe.com", "paypal.me", "www.paypal.com", "paypal.com", "pay.sumup.com", "mollie.com", "payment-links.mollie.com"];

// Retourne l'URL nettoyée, ou null si le lien n'est pas acceptable.
export function normalizePaymentLink(raw) {
  try {
    const u = new URL(String(raw || "").trim());
    if (u.protocol !== "https:") return null;
    if (!ALLOWED_HOSTS.includes(u.hostname.toLowerCase())) return null;
    return u.toString();
  } catch {
    return null;
  }
}

// Ajoute l'email de l'acheteur et la référence d'achat (reconnus par les
// liens Stripe ; ignorés sans effet par les autres services).
export function buildPaymentLinkUrl(link, { email, purchaseId }) {
  const u = new URL(link);
  if (u.hostname.endsWith("stripe.com")) {
    if (email) u.searchParams.set("prefilled_email", email);
    if (purchaseId) u.searchParams.set("client_reference_id", purchaseId);
  }
  return u.toString();
}
