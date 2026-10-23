#!/bin/bash
# Paiement automatique des livres via Chariow (un produit, un prix par variante)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/chariow.js b/lib/chariow.js
index a4996e0..7bdd8db 100644
--- a/lib/chariow.js
+++ b/lib/chariow.js
@@ -27,6 +27,7 @@ function headers() {
 // laquelle rediriger l'acheteur.
 export async function initChariowCheckout({
   productId,
+  priceVariantId,
   email,
   firstName,
   lastName,
@@ -49,6 +50,7 @@ export async function initChariowCheckout({
     headers: headers(),
     body: JSON.stringify({
       product_id: productId,
+      ...(priceVariantId && { price_variant_id: priceVariantId }),
       email,
       first_name: String(firstName || "").slice(0, 50),
       last_name: String(lastName || "").slice(0, 50),
diff --git a/lib/chariowTiers.js b/lib/chariowTiers.js
new file mode 100644
index 0000000..718c61f
--- /dev/null
+++ b/lib/chariowTiers.js
@@ -0,0 +1,24 @@
+// Paliers de prix des livres (zone Afrique, en F CFA).
+//
+// Chariow ne permet pas de créer un produit par API : on utilise donc UN seul
+// produit "Livre papier Plume" (CHARIOW_BOOK_PRODUCT_ID) avec une variante de
+// prix par palier. Quand l'auteur choisit son prix, l'acheteur est facturé
+// via la variante correspondante.
+//
+// Pour ajouter un palier : créer la variante dans Chariow (Tarification),
+// puis ajouter ici la ligne  prix: "pv_xxxxxxxx".
+export const BOOK_PRICE_VARIANTS = {
+  2000: "pv_cmz2fo91",
+  5000: "pv_k8i2h7en",
+  10000: "pv_3wqnq8la",
+};
+
+// Liste triée des prix proposés à l'auteur (F CFA).
+export const BOOK_PRICE_TIERS = Object.keys(BOOK_PRICE_VARIANTS)
+  .map(Number)
+  .sort((a, b) => a - b);
+
+// priceCents = prix en F CFA × 100 (convention de l'application).
+export function variantForPriceCents(priceCents) {
+  return BOOK_PRICE_VARIANTS[Math.round(Number(priceCents) / 100)] || null;
+}
diff --git a/pages/api/checkout/create.js b/pages/api/checkout/create.js
index 8610a5d..c7f52b1 100644
--- a/pages/api/checkout/create.js
+++ b/pages/api/checkout/create.js
@@ -3,6 +3,7 @@ import { prisma } from "../../../lib/db";
 import { stripe } from "../../../lib/stripe";
 import { initChariowCheckout } from "../../../lib/chariow";
 import { isValidEmail } from "../../../lib/validate";
+import { variantForPriceCents } from "../../../lib/chariowTiers";
 import { splitPhone } from "../../../lib/countryCodes";
 import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
 import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";
@@ -107,7 +108,12 @@ export default async function handler(req, res) {
   }
 
   // --- Zone Afrique francophone : Chariow ---
-  if (!salesPage.chariowProductId || !process.env.CHARIOW_API_KEY) {
+  // Un seul produit Chariow pour tous les livres ; le prix choisi par l'auteur
+  // correspond à une variante de prix. Sans variante connue on refuse plutôt
+  // que de facturer un montant erroné.
+  const productId = salesPage.chariowProductId || process.env.CHARIOW_BOOK_PRODUCT_ID;
+  const priceVariantId = salesPage.chariowProductId ? null : variantForPriceCents(salesPage.priceCents);
+  if (!productId || !process.env.CHARIOW_API_KEY || (!salesPage.chariowProductId && !priceVariantId)) {
     await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
     return res.status(503).json({
       error: "Le paiement en ligne de ce livre sera disponible très bientôt. Merci de revenir un peu plus tard.",
@@ -118,7 +124,8 @@ export default async function handler(req, res) {
   let result;
   try {
     result = await initChariowCheckout({
-      productId: salesPage.chariowProductId,
+      productId,
+      priceVariantId,
       email: buyerEmail,
       firstName: buyerName.split(" ")[0] || buyerName,
       lastName: buyerName.split(" ").slice(1).join(" ") || buyerName.split(" ")[0],
diff --git a/pages/api/sales-pages/index.js b/pages/api/sales-pages/index.js
index 3ee3b67..346c7a0 100644
--- a/pages/api/sales-pages/index.js
+++ b/pages/api/sales-pages/index.js
@@ -1,6 +1,7 @@
 import { requireAuth } from "../../../lib/auth";
 import { prisma } from "../../../lib/db";
 import { generateSalesPageCopy } from "../../../lib/ai";
+import { BOOK_PRICE_TIERS } from "../../../lib/chariowTiers";
 
 function slugify(title) {
   return title
@@ -19,6 +20,10 @@ export default requireAuth(async function handler(req, res) {
     return res.status(400).json({ error: "bookId, priceCents et currency sont requis" });
   }
 
+  if (currency === "XOF" && !BOOK_PRICE_TIERS.includes(Math.round(Number(priceCents) / 100))) {
+    return res.status(400).json({ error: "Ce prix n'est pas proposé. Choisissez l'un des prix de la liste." });
+  }
+
   try {
     const book = await prisma.book.findFirst({
       where: { id: bookId, authorId: req.authorId },
diff --git a/pages/dashboard/index.js b/pages/dashboard/index.js
index ea63f09..ab54826 100644
--- a/pages/dashboard/index.js
+++ b/pages/dashboard/index.js
@@ -5,6 +5,7 @@ import DashboardShell from "../../components/DashboardShell";
 import { colors, BookCover, EditableTitle, ErrorBanner, Spinner } from "../../components/ui";
 import { useAuthGuard } from "../../lib/useAuthGuard";
 import { api, getToken } from "../../lib/apiClient";
+import { BOOK_PRICE_TIERS } from "../../lib/chariowTiers";
 
 // Bouton discret posé sur la couverture pour en changer l'image — réutilisé
 // sur la page de vente et la page d'extrait.
@@ -62,7 +63,7 @@ export default function DashboardVente() {
   const [error, setError] = useState("");
   const [book, setBook] = useState(null);
   const [salesPage, setSalesPage] = useState(null);
-  const [priceInput, setPriceInput] = useState("12");
+  const [priceInput, setPriceInput] = useState(String(BOOK_PRICE_TIERS[0]));
   const [copied, setCopied] = useState(false);
   const [publishing, setPublishing] = useState(false);
   const [coverUploading, setCoverUploading] = useState(false);
@@ -252,13 +253,26 @@ export default function DashboardVente() {
                   <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
                     Prix de vente ({currencyLabel})
                   </p>
-                  <input
-                    type="number"
-                    value={priceInput}
-                    onChange={(e) => setPriceInput(e.target.value)}
-                    className="w-32 rounded-lg px-3 py-2 font-body text-sm"
-                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-                  />
+                  {currency === "XOF" ? (
+                    <select
+                      value={priceInput}
+                      onChange={(e) => setPriceInput(e.target.value)}
+                      className="w-40 rounded-lg px-3 py-2 font-body text-sm"
+                      style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
+                    >
+                      {BOOK_PRICE_TIERS.map((p) => (
+                        <option key={p} value={p}>{p.toLocaleString("fr-FR")} FCFA</option>
+                      ))}
+                    </select>
+                  ) : (
+                    <input
+                      type="number"
+                      value={priceInput}
+                      onChange={(e) => setPriceInput(e.target.value)}
+                      className="w-32 rounded-lg px-3 py-2 font-body text-sm"
+                      style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
+                    />
+                  )}
                 </div>
               )}
 
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : paliers de prix appliqués"
