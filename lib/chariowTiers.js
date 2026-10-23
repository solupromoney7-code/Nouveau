// Paliers de prix des livres (zone Afrique, en F CFA).
//
// Chariow ne permet pas de créer un produit par API : on utilise donc UN seul
// produit "Livre papier Plume" (CHARIOW_BOOK_PRODUCT_ID) avec une variante de
// prix par palier. Quand l'auteur choisit son prix, l'acheteur est facturé
// via la variante correspondante.
//
// Pour ajouter un palier : créer la variante dans Chariow (Tarification),
// puis ajouter ici la ligne  prix: "pv_xxxxxxxx".
export const BOOK_PRICE_VARIANTS = {
  2000: "pv_cmz2fo91",
  5000: "pv_k8i2h7en",
  10000: "pv_3wqnq8la",
};

// Liste triée des prix proposés à l'auteur (F CFA).
export const BOOK_PRICE_TIERS = Object.keys(BOOK_PRICE_VARIANTS)
  .map(Number)
  .sort((a, b) => a - b);

// priceCents = prix en F CFA × 100 (convention de l'application).
export function variantForPriceCents(priceCents) {
  return BOOK_PRICE_VARIANTS[Math.round(Number(priceCents) / 100)] || null;
}
