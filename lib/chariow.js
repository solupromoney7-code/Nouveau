// Intégration Chariow — documentation officielle : https://chariow.dev
//
//   - Base URL : https://api.chariow.com/v1
//   - Auth : header Authorization: Bearer <clé sk_...> (Réglages > Clés API)
//     Scopes nécessaires : checkout.write, sales.read, products.read
//   - POST /v1/checkout : crée une session d'achat pour un produit existant.
//     Le téléphone (numéro + pays ISO) est obligatoire.
//   - GET  /v1/sales/{id} : relit une vente (statut completed / settled…)
//   - Pulses (webhooks) : événements "successful.sale", "failed.sale"…,
//     signés en HMAC-SHA256 (voir pages/api/webhooks/chariow.js).
//
// Les produits (un par livre, plus l'abonnement Plume) se créent à la main
// dans le tableau de bord Chariow : l'API publique ne permet que de les lire.
// L'identifiant du produit (prd_...) est ensuite relié au livre depuis
// l'espace Administration > Livres.

const BASE_URL = "https://api.chariow.com/v1";

function headers() {
  return {
    Authorization: `Bearer ${process.env.CHARIOW_API_KEY}`,
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
  phoneCountryIso,
  redirectUrl,
  paymentCurrency,
  metadata,
  shipping,
}) {
  if (!process.env.CHARIOW_API_KEY) {
    throw new Error("Chariow n'est pas encore configuré (clé API manquante).");
  }
  if (!productId) {
    throw new Error("Aucun produit Chariow relié.");
  }

  const res = await fetch(`${BASE_URL}/checkout`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      product_id: productId,
      email,
      first_name: String(firstName || "").slice(0, 50),
      last_name: String(lastName || "").slice(0, 50),
      phone: { number: String(phoneNumber || "").replace(/\D/g, ""), country_code: phoneCountryIso || "CI" },
      ...(redirectUrl && { redirect_url: redirectUrl }),
      ...(paymentCurrency && { payment_currency: paymentCurrency }),
      ...(metadata && { custom_metadata: metadata }),
      ...(shipping && { shipping }),
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = data?.errors ? ` ${JSON.stringify(data.errors)}` : "";
    console.error("Chariow — échec du checkout :", res.status, data?.message, detail);
    throw new Error(`Chariow — échec du checkout : ${data?.message || res.status}`);
  }
  return data.data; // { step: 'payment'|'completed'|'already_purchased', payment: { checkout_url, transaction_id }, purchase: { id, ... }, message }
}

// Relit une vente directement chez Chariow (reconfirmation serveur-à-serveur).
// Retourne l'objet vente, ou null si elle est introuvable.
export async function getChariowSale(saleId) {
  const res = await fetch(`${BASE_URL}/sales/${encodeURIComponent(saleId)}`, { headers: headers() });
  if (res.status === 404) return null;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`Chariow — lecture de la vente impossible : ${data?.message || res.status}`);
  return data.data || null;
}
