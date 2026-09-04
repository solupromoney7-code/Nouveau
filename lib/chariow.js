// Intégration Chariow — https://chariow.dev
//
// Confirmé par la documentation publique de Chariow :
//   - Base URL : https://api.chariow.com/v1
//   - Auth : header Authorization: Bearer <clé secrète sk_live_/sk_test_>
//   - POST /v1/checkout  : crée une session d'achat pour un product_id existant
//   - GET  /v1/sales?product_slug=...&customer_email=... : vérifie une vente
//   - Pulses (webhooks) : POST { event, data } vers ton URL. L'événement
//     "sale.completed" est confirmé par la doc. Les noms exacts des
//     événements liés à l'abonnement (renouvellement, échec, annulation)
//     ne sont PAS confirmés — vérifie-les dans Réglages > Pulses de ton
//     dashboard Chariow et ajuste lib/chariow.js + pages/api/webhooks/chariow.js
//     en conséquence.
//
// NON confirmé par la documentation publique consultée : le schéma exact de
// création de produit par API (createChariowProduct ci-dessous). C'est une
// implémentation best-effort à vérifier sur chariow.dev/api-reference avant
// mise en production. Si elle échoue, crée le produit manuellement dans le
// dashboard Chariow et colle son product_id dans SalesPage.chariowProductId.

const BASE_URL = "https://api.chariow.com/v1";
const API_KEY = process.env.CHARIOW_API_KEY;

function headers() {
  return {
    Authorization: `Bearer ${API_KEY}`,
    "Content-Type": "application/json",
  };
}

// Crée une session d'achat et retourne l'URL de paiement Chariow vers
// laquelle rediriger l'acheteur.
export async function initChariowCheckout({
  productId,
  email,
  firstName,
  lastName,
  phoneNumber,
  phoneCountryCode,
  redirectUrl,
  paymentCurrency,
  metadata,
}) {
  const res = await fetch(`${BASE_URL}/checkout`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      product_id: productId,
      email,
      first_name: firstName,
      last_name: lastName,
      ...(phoneNumber && { phone: { number: phoneNumber, country_code: phoneCountryCode || "CI" } }),
      redirect_url: redirectUrl,
      ...(paymentCurrency && { payment_currency: paymentCurrency }),
      ...(metadata && { metadata }),
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Chariow — échec du checkout : ${data.message || res.status}`);
  }
  return data.data; // { step: 'payment'|'completed'|'already_purchased', payment: { checkout_url }, purchase, message }
}

// Reconfirme une vente directement auprès de Chariow plutôt que de faire
// confiance au seul contenu du Pulse — même principe de sécurité que pour
// la vérification CinetPay.
export async function verifyChariowSale({ productSlug, customerEmail }) {
  const params = new URLSearchParams({ product_slug: productSlug, customer_email: customerEmail });
  const res = await fetch(`${BASE_URL}/sales?${params.toString()}`, { headers: headers() });
  const data = await res.json();
  const sales = data?.data || [];
  return sales.find((s) => s.status === "completed") || null;
}

// BEST-EFFORT — schéma non confirmé par la documentation publique. À vérifier
// sur chariow.dev avant utilisation en production.
export async function createChariowProduct({ name, description, priceValue, currency }) {
  const res = await fetch(`${BASE_URL}/products`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      name,
      description,
      price: { value: priceValue, currency },
      type: "digital",
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Chariow — échec de création du produit (schéma à vérifier) : ${data.message || res.status}`);
  }
  return data.data; // { id, name, price: {...}, ... }
}
