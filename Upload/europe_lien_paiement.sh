#!/bin/bash
# Europe : lien de paiement de l'auteur + abonnement à 9 €
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/paymentLink.js b/lib/paymentLink.js
new file mode 100644
index 0000000..e3be372
--- /dev/null
+++ b/lib/paymentLink.js
@@ -0,0 +1,26 @@
+// Lien de paiement fourni par l'auteur (zone Europe) : l'argent va directement
+// sur son compte, Plume ne touche jamais les fonds.
+const ALLOWED_HOSTS = ["buy.stripe.com", "checkout.stripe.com", "paypal.me", "www.paypal.com", "paypal.com", "pay.sumup.com", "mollie.com", "payment-links.mollie.com"];
+
+// Retourne l'URL nettoyée, ou null si le lien n'est pas acceptable.
+export function normalizePaymentLink(raw) {
+  try {
+    const u = new URL(String(raw || "").trim());
+    if (u.protocol !== "https:") return null;
+    if (!ALLOWED_HOSTS.includes(u.hostname.toLowerCase())) return null;
+    return u.toString();
+  } catch {
+    return null;
+  }
+}
+
+// Ajoute l'email de l'acheteur et la référence d'achat (reconnus par les
+// liens Stripe ; ignorés sans effet par les autres services).
+export function buildPaymentLinkUrl(link, { email, purchaseId }) {
+  const u = new URL(link);
+  if (u.hostname.endsWith("stripe.com")) {
+    if (email) u.searchParams.set("prefilled_email", email);
+    if (purchaseId) u.searchParams.set("client_reference_id", purchaseId);
+  }
+  return u.toString();
+}
diff --git a/pages/api/authors/me.js b/pages/api/authors/me.js
index 8c7c2f2..c500a0d 100644
--- a/pages/api/authors/me.js
+++ b/pages/api/authors/me.js
@@ -10,7 +10,7 @@ export default requireAuth(async function handler(req, res) {
     select: {
       id: true, name: true, email: true, region: true, emailVerified: true,
       subscriptionStatus: true, lifetimeAccess: true, trialEndsAt: true, currentPeriodEnd: true,
-      stripeAccountId: true, stripeOnboarded: true,
+      stripeAccountId: true, stripeOnboarded: true, paymentLink: true,
       momoOperator: true, momoNumber: true,
     },
   });
diff --git a/pages/api/authors/payment-config.js b/pages/api/authors/payment-config.js
index 7d95373..df35d68 100644
--- a/pages/api/authors/payment-config.js
+++ b/pages/api/authors/payment-config.js
@@ -1,5 +1,6 @@
 import { requireAuth } from "../../../lib/auth";
 import { prisma } from "../../../lib/db";
+import { normalizePaymentLink } from "../../../lib/paymentLink";
 
 // GET  -> retourne l'état de configuration des moyens de paiement de l'auteur
 // PUT  -> enregistre le numéro Mobile Money (zone Afrique)
@@ -10,12 +11,27 @@ export default requireAuth(async function handler(req, res) {
     if (req.method === "GET") {
       const author = await prisma.author.findUnique({
         where: { id: req.authorId },
-        select: { region: true, stripeAccountId: true, stripeOnboarded: true, momoOperator: true, momoNumber: true },
+        select: { region: true, stripeAccountId: true, stripeOnboarded: true, paymentLink: true, momoOperator: true, momoNumber: true },
       });
       return res.status(200).json(author);
     }
 
     if (req.method === "PUT") {
+      // Zone Europe : lien de paiement de l'auteur
+      if (req.body && "paymentLink" in req.body) {
+        const raw = String(req.body.paymentLink || "").trim();
+        if (!raw) {
+          await prisma.author.update({ where: { id: req.authorId }, data: { paymentLink: null } });
+          return res.status(200).json({ ok: true, paymentLink: null });
+        }
+        const link = normalizePaymentLink(raw);
+        if (!link) {
+          return res.status(400).json({ error: "Lien non reconnu. Collez un lien de paiement Stripe (https://buy.stripe.com/…) ou PayPal." });
+        }
+        await prisma.author.update({ where: { id: req.authorId }, data: { paymentLink: link } });
+        return res.status(200).json({ ok: true, paymentLink: link });
+      }
+
       const { momoOperator, momoNumber } = req.body;
       if (!momoOperator || !momoNumber) {
         return res.status(400).json({ error: "Opérateur et numéro Mobile Money requis" });
diff --git a/pages/api/checkout/create.js b/pages/api/checkout/create.js
index c7f52b1..5f6c05e 100644
--- a/pages/api/checkout/create.js
+++ b/pages/api/checkout/create.js
@@ -3,6 +3,7 @@ import { prisma } from "../../../lib/db";
 import { stripe } from "../../../lib/stripe";
 import { initChariowCheckout } from "../../../lib/chariow";
 import { isValidEmail } from "../../../lib/validate";
+import { buildPaymentLinkUrl } from "../../../lib/paymentLink";
 import { variantForPriceCents } from "../../../lib/chariowTiers";
 import { splitPhone } from "../../../lib/countryCodes";
 import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
@@ -74,8 +75,20 @@ export default async function handler(req, res) {
 
   // --- Zone Europe : Stripe Checkout + Connect ---
   if (author.region === "EUROPE") {
+    // Cas principal : l'auteur a collé son propre lien de paiement. L'argent
+    // arrive directement chez lui ; la vente reste "en attente" côté Plume
+    // (pas de confirmation automatique).
+    if (author.paymentLink) {
+      await prisma.purchase.update({ where: { id: purchase.id }, data: { provider: "lien_auteur" } });
+      return res.status(200).json({
+        url: buildPaymentLinkUrl(author.paymentLink, { email: buyerEmail, purchaseId: purchase.id }),
+        purchaseId: purchase.id,
+      });
+    }
+
     if (!author.stripeAccountId || !author.stripeOnboarded) {
-      return res.status(400).json({ error: "L'auteur n'a pas encore connecté son compte Stripe" });
+      await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
+      return res.status(400).json({ error: "Le paiement en ligne de ce livre n'est pas encore disponible." });
     }
 
     const session = await stripe.checkout.sessions.create({
diff --git a/pages/api/subscriptions/checkout.js b/pages/api/subscriptions/checkout.js
index aae6286..e346cad 100644
--- a/pages/api/subscriptions/checkout.js
+++ b/pages/api/subscriptions/checkout.js
@@ -22,7 +22,9 @@ export default requireAuth(async function handler(req, res) {
     }
 
     const result = await initChariowCheckout({
-      productId: process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
+      productId: author.region === "EUROPE"
+        ? (process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID_EUROPE || process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID)
+        : process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
       email: author.email,
       firstName: firstName || author.name,
       lastName: rest.join(" ") || author.name,
diff --git a/pages/api/webhooks/chariow.js b/pages/api/webhooks/chariow.js
index 554460a..8d0162c 100644
--- a/pages/api/webhooks/chariow.js
+++ b/pages/api/webhooks/chariow.js
@@ -79,7 +79,7 @@ export default async function handler(req, res) {
       }
 
       // --- Abonnement Plume ---
-      if (productId && productId === process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID) {
+      if (productId && [process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID, process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID_EUROPE].filter(Boolean).includes(productId)) {
         const authorId = sale.custom_metadata?.authorId;
         const author = authorId
           ? await prisma.author.findUnique({ where: { id: authorId } })
diff --git a/pages/dashboard/abonnement.js b/pages/dashboard/abonnement.js
index 9ddebf6..4aa55d9 100644
--- a/pages/dashboard/abonnement.js
+++ b/pages/dashboard/abonnement.js
@@ -111,7 +111,7 @@ export default function DashboardAbonnement() {
   }
 
   const isAfrique = author?.region === "AFRIQUE";
-  const price = isAfrique ? "3 900 FCFA" : "5,99 €";
+  const price = isAfrique ? "3 900 FCFA" : "9 €";
   const payMethod = isAfrique ? "Mobile Money" : "Carte bancaire";
   const lifetime = Boolean(author?.lifetimeAccess);
   const active = author?.subscriptionStatus === "ACTIVE" || lifetime;
diff --git a/pages/dashboard/paiements.js b/pages/dashboard/paiements.js
index e945b33..e5fec9c 100644
--- a/pages/dashboard/paiements.js
+++ b/pages/dashboard/paiements.js
@@ -100,11 +100,11 @@ export default function DashboardPaiements() {
                 {author?.region === "EUROPE" ? <CreditCard size={20} color={colors.goldDark} /> : <Smartphone size={20} color={colors.goldDark} />}
               </div>
               <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>
-                {author?.region === "EUROPE" ? "Connectez votre compte Stripe" : "Renseignez votre numéro Mobile Money"}
+                {author?.region === "EUROPE" ? "Ajoutez votre lien de paiement" : "Renseignez votre numéro Mobile Money"}
               </h2>
               <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
                 {author?.region === "EUROPE"
-                  ? "Pour recevoir vos paiements, connectez un compte Stripe depuis Paramètres."
+                  ? "Pour recevoir vos paiements, collez votre lien de paiement Stripe depuis Paramètres."
                   : "Pour recevoir vos reversements, renseignez votre numéro Mobile Money depuis Paramètres."}
               </p>
               <Link
diff --git a/pages/dashboard/parametres.js b/pages/dashboard/parametres.js
index 2eb6700..110eb84 100644
--- a/pages/dashboard/parametres.js
+++ b/pages/dashboard/parametres.js
@@ -217,6 +217,73 @@ function StripeSection({ author }) {
   );
 }
 
+function PaymentLinkSection({ author }) {
+  const [link, setLink] = useState(author?.paymentLink || "");
+  const [saving, setSaving] = useState(false);
+  const [saved, setSaved] = useState(false);
+  const [error, setError] = useState("");
+
+  async function handleSave(e) {
+    e.preventDefault();
+    setError("");
+    setSaving(true);
+    setSaved(false);
+    try {
+      const data = await api("/api/authors/payment-config", { method: "PUT", body: { paymentLink: link } });
+      setLink(data.paymentLink || "");
+      setSaved(true);
+      setTimeout(() => setSaved(false), 2500);
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setSaving(false);
+    }
+  }
+
+  return (
+    <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
+      <div className="flex items-center gap-2 mb-1">
+        <CreditCard size={16} color={colors.goldDark} />
+        <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Moyen d’encaissement</h2>
+      </div>
+      <p className="font-body text-sm mb-2" style={{ color: colors.textPaperDim }}>
+        Collez le lien de paiement de votre propre compte Stripe (ou PayPal). Vos acheteurs paient directement chez vous : l’argent arrive sur votre compte bancaire, Plume n’y touche jamais.
+      </p>
+      <p className="font-body text-xs mb-4" style={{ color: colors.textPaperDim }}>
+        Dans Stripe : Produits → Liens de paiement → Créer. Mettez le prix de votre livre, activez la collecte de l’adresse de livraison, puis copiez le lien (https://buy.stripe.com/…).
+      </p>
+
+      <form onSubmit={handleSave} className="space-y-3 max-w-lg">
+        <ErrorBanner message={error} />
+        <input
+          type="url"
+          value={link}
+          onChange={(e) => setLink(e.target.value)}
+          placeholder="https://buy.stripe.com/..."
+          className="w-full rounded-lg px-3 py-2 font-body text-sm"
+          style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
+        />
+        <div className="flex items-center gap-3">
+          <button
+            type="submit"
+            disabled={saving}
+            className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
+            style={{ backgroundColor: colors.gold, color: colors.ink, opacity: saving ? 0.6 : 1 }}
+          >
+            {saving && <Loader2 size={14} className="animate-spin" />}
+            {saving ? "Enregistrement…" : "Enregistrer"}
+          </button>
+          {saved && (
+            <span className="flex items-center gap-1 font-body text-xs" style={{ color: colors.forest }}>
+              <Check size={13} /> Enregistré
+            </span>
+          )}
+        </div>
+      </form>
+    </section>
+  );
+}
+
 export default function DashboardParametres() {
   const { author, loading } = useAuthGuard();
 
@@ -232,7 +299,7 @@ export default function DashboardParametres() {
       ) : (
         <div className="max-w-2xl space-y-6">
           <EmailVerificationSection author={author} />
-          {author?.region === "EUROPE" ? <StripeSection author={author} /> : <MomoSection author={author} />}
+          {author?.region === "EUROPE" ? <PaymentLinkSection author={author} /> : <MomoSection author={author} />}
         </div>
       )}
     </DashboardShell>
diff --git a/pages/index.js b/pages/index.js
index b635411..0708454 100644
--- a/pages/index.js
+++ b/pages/index.js
@@ -162,7 +162,7 @@ export default function Home() {
         <div className="grid sm:grid-cols-2 gap-5">
           {[
             { zone: "Afrique francophone", price: "3 900 FCFA", pay: "Mobile Money", accent: colors.gold },
-            { zone: "France / Europe", price: "5,99 €", pay: "Carte bancaire", accent: colors.sky },
+            { zone: "France / Europe", price: "9 €", pay: "Carte bancaire", accent: colors.sky },
           ].map((p) => (
             <div key={p.zone} className="rounded-2xl overflow-hidden" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
               <div style={{ height: 5, backgroundColor: p.accent }} />
diff --git a/prisma/schema.prisma b/prisma/schema.prisma
index 690a1e5..ba00811 100644
--- a/prisma/schema.prisma
+++ b/prisma/schema.prisma
@@ -37,6 +37,7 @@ model Author {
   // Stripe Connect — zone Europe
   stripeAccountId    String?
   stripeOnboarded    Boolean             @default(false)
+  paymentLink        String?             // zone Europe : lien de paiement de l'auteur (Stripe Payment Link, PayPal…)
 
   // Mobile Money — zone Afrique francophone
   momoOperator       String?
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : Europe (lien de paiement + abonnement 9 EUR) appliqué"
