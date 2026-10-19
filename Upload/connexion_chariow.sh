#!/bin/bash
# Connexion Chariow conforme à la documentation officielle (paiements, webhook signé, liaison des produits)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/.env.example b/.env.example
index ef9d93e..30bd4ef 100644
--- a/.env.example
+++ b/.env.example
@@ -15,10 +15,9 @@ STRIPE_WEBHOOK_SECRET="whsec_..."
 # pour LES DEUX zones)
 CHARIOW_API_KEY=""
 CHARIOW_SUBSCRIPTION_PRODUCT_ID=""
-# Secret partagé pour sécuriser le webhook Chariow (aucune signature HMAC
-# officielle confirmée à ce jour) — génère une longue chaîne aléatoire, mets
-# la même valeur ici et dans l'URL configurée côté Chariow :
-# https://ton-domaine.vercel.app/api/webhooks/chariow?secret=CETTE_VALEUR
+# Secret de signature du Pulse Chariow ("whsec_...") : Automatisations >
+# Pulses > ton pulse > Signing secret. URL du pulse :
+# https://ton-domaine.vercel.app/api/webhooks/chariow
 CHARIOW_WEBHOOK_SECRET=""
 # Commission Chariow par vente (0.15 = 15%, baisse à 0.10 à volume selon leur grille)
 CHARIOW_COMMISSION_RATE="0.15"
diff --git a/lib/chariow.js b/lib/chariow.js
index 904e65f..a4996e0 100644
--- a/lib/chariow.js
+++ b/lib/chariow.js
@@ -1,29 +1,24 @@
-// Intégration Chariow — https://chariow.dev
+// Intégration Chariow — documentation officielle : https://chariow.dev
 //
-// Confirmé par la documentation publique de Chariow :
 //   - Base URL : https://api.chariow.com/v1
-//   - Auth : header Authorization: Bearer <clé secrète sk_live_/sk_test_>
-//   - POST /v1/checkout  : crée une session d'achat pour un product_id existant
-//   - GET  /v1/sales?product_slug=...&customer_email=... : vérifie une vente
-//   - Pulses (webhooks) : POST { event, data } vers ton URL. L'événement
-//     "sale.completed" est confirmé par la doc. Les noms exacts des
-//     événements liés à l'abonnement (renouvellement, échec, annulation)
-//     ne sont PAS confirmés — vérifie-les dans Réglages > Pulses de ton
-//     dashboard Chariow et ajuste lib/chariow.js + pages/api/webhooks/chariow.js
-//     en conséquence.
+//   - Auth : header Authorization: Bearer <clé sk_...> (Réglages > Clés API)
+//     Scopes nécessaires : checkout.write, sales.read, products.read
+//   - POST /v1/checkout : crée une session d'achat pour un produit existant.
+//     Le téléphone (numéro + pays ISO) est obligatoire.
+//   - GET  /v1/sales/{id} : relit une vente (statut completed / settled…)
+//   - Pulses (webhooks) : événements "successful.sale", "failed.sale"…,
+//     signés en HMAC-SHA256 (voir pages/api/webhooks/chariow.js).
 //
-// NON confirmé par la documentation publique consultée : le schéma exact de
-// création de produit par API (createChariowProduct ci-dessous). C'est une
-// implémentation best-effort à vérifier sur chariow.dev/api-reference avant
-// mise en production. Si elle échoue, crée le produit manuellement dans le
-// dashboard Chariow et colle son product_id dans SalesPage.chariowProductId.
+// Les produits (un par livre, plus l'abonnement Plume) se créent à la main
+// dans le tableau de bord Chariow : l'API publique ne permet que de les lire.
+// L'identifiant du produit (prd_...) est ensuite relié au livre depuis
+// l'espace Administration > Livres.
 
 const BASE_URL = "https://api.chariow.com/v1";
-const API_KEY = process.env.CHARIOW_API_KEY;
 
 function headers() {
   return {
-    Authorization: `Bearer ${API_KEY}`,
+    Authorization: `Bearer ${process.env.CHARIOW_API_KEY}`,
     "Content-Type": "application/json",
   };
 }
@@ -36,60 +31,50 @@ export async function initChariowCheckout({
   firstName,
   lastName,
   phoneNumber,
-  phoneCountryCode,
+  phoneCountryIso,
   redirectUrl,
   paymentCurrency,
   metadata,
+  shipping,
 }) {
+  if (!process.env.CHARIOW_API_KEY) {
+    throw new Error("Chariow n'est pas encore configuré (clé API manquante).");
+  }
+  if (!productId) {
+    throw new Error("Aucun produit Chariow relié.");
+  }
+
   const res = await fetch(`${BASE_URL}/checkout`, {
     method: "POST",
     headers: headers(),
     body: JSON.stringify({
       product_id: productId,
       email,
-      first_name: firstName,
-      last_name: lastName,
-      ...(phoneNumber && { phone: { number: phoneNumber, country_code: phoneCountryCode || "CI" } }),
-      redirect_url: redirectUrl,
+      first_name: String(firstName || "").slice(0, 50),
+      last_name: String(lastName || "").slice(0, 50),
+      phone: { number: String(phoneNumber || "").replace(/\D/g, ""), country_code: phoneCountryIso || "CI" },
+      ...(redirectUrl && { redirect_url: redirectUrl }),
       ...(paymentCurrency && { payment_currency: paymentCurrency }),
-      ...(metadata && { metadata }),
+      ...(metadata && { custom_metadata: metadata }),
+      ...(shipping && { shipping }),
     }),
   });
 
-  const data = await res.json();
+  const data = await res.json().catch(() => ({}));
   if (!res.ok) {
-    throw new Error(`Chariow — échec du checkout : ${data.message || res.status}`);
+    const detail = data?.errors ? ` ${JSON.stringify(data.errors)}` : "";
+    console.error("Chariow — échec du checkout :", res.status, data?.message, detail);
+    throw new Error(`Chariow — échec du checkout : ${data?.message || res.status}`);
   }
-  return data.data; // { step: 'payment'|'completed'|'already_purchased', payment: { checkout_url }, purchase, message }
+  return data.data; // { step: 'payment'|'completed'|'already_purchased', payment: { checkout_url, transaction_id }, purchase: { id, ... }, message }
 }
 
-// Reconfirme une vente directement auprès de Chariow plutôt que de faire
-// confiance au seul contenu du Pulse — même principe de sécurité que pour
-// la vérification CinetPay.
-export async function verifyChariowSale({ productSlug, customerEmail }) {
-  const params = new URLSearchParams({ product_slug: productSlug, customer_email: customerEmail });
-  const res = await fetch(`${BASE_URL}/sales?${params.toString()}`, { headers: headers() });
-  const data = await res.json();
-  const sales = data?.data || [];
-  return sales.find((s) => s.status === "completed") || null;
-}
-
-// BEST-EFFORT — schéma non confirmé par la documentation publique. À vérifier
-// sur chariow.dev avant utilisation en production.
-export async function createChariowProduct({ name, description, priceValue, currency }) {
-  const res = await fetch(`${BASE_URL}/products`, {
-    method: "POST",
-    headers: headers(),
-    body: JSON.stringify({
-      name,
-      description,
-      price: { value: priceValue, currency },
-      type: "digital",
-    }),
-  });
-  const data = await res.json();
-  if (!res.ok) {
-    throw new Error(`Chariow — échec de création du produit (schéma à vérifier) : ${data.message || res.status}`);
-  }
-  return data.data; // { id, name, price: {...}, ... }
+// Relit une vente directement chez Chariow (reconfirmation serveur-à-serveur).
+// Retourne l'objet vente, ou null si elle est introuvable.
+export async function getChariowSale(saleId) {
+  const res = await fetch(`${BASE_URL}/sales/${encodeURIComponent(saleId)}`, { headers: headers() });
+  if (res.status === 404) return null;
+  const data = await res.json().catch(() => ({}));
+  if (!res.ok) throw new Error(`Chariow — lecture de la vente impossible : ${data?.message || res.status}`);
+  return data.data || null;
 }
diff --git a/lib/countryCodes.js b/lib/countryCodes.js
index e36dc60..a4ab4d8 100644
--- a/lib/countryCodes.js
+++ b/lib/countryCodes.js
@@ -32,3 +32,13 @@ export function getVisitorCountryCode(req) {
   const iso = req?.headers?.["x-vercel-ip-country"];
   return codeForCountry(iso);
 }
+
+// Sépare un numéro complet ("+22997000000") en { iso, number } — l'API Chariow
+// exige le pays (code ISO) et le numéro séparément.
+export function splitPhone(full) {
+  const clean = String(full || "").replace(/[^0-9+]/g, "");
+  const sorted = [...COUNTRY_CODES].sort((a, b) => b.code.length - a.code.length);
+  const match = sorted.find((c) => clean.startsWith(c.code));
+  if (match) return { iso: match.iso, number: clean.slice(match.code.length).replace(/\D/g, "") };
+  return { iso: "CI", number: clean.replace(/\D/g, "") };
+}
diff --git a/lib/subscription.js b/lib/subscription.js
index 7eb139b..edc3539 100644
--- a/lib/subscription.js
+++ b/lib/subscription.js
@@ -5,5 +5,10 @@
 export function isSubscriptionActive(author) {
   if (author.lifetimeAccess) return true; // accès à vie offert par le propriétaire
   const trialActive = author.subscriptionStatus === "TRIALING" && author.trialEndsAt && author.trialEndsAt > new Date();
-  return author.subscriptionStatus === "ACTIVE" || trialActive;
+  // Un abonnement payé court jusqu'à currentPeriodEnd (+ 3 jours de grâce).
+  const grace = 3 * 24 * 60 * 60 * 1000;
+  const paidActive =
+    author.subscriptionStatus === "ACTIVE" &&
+    (!author.currentPeriodEnd || new Date(author.currentPeriodEnd).getTime() + grace > Date.now());
+  return paidActive || trialActive;
 }
diff --git a/pages/api/admin/books.js b/pages/api/admin/books.js
new file mode 100644
index 0000000..f79316f
--- /dev/null
+++ b/pages/api/admin/books.js
@@ -0,0 +1,32 @@
+import { requireAdmin } from "../../../lib/admin";
+import { prisma } from "../../../lib/db";
+
+// Toutes les pages de vente, avec le produit Chariow relié (zone Afrique).
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const pages = await prisma.salesPage.findMany({
+      orderBy: { createdAt: "desc" },
+      include: { book: { select: { title: true, author: { select: { name: true, email: true, region: true } } } } },
+    });
+    return res.status(200).json(
+      pages.map((p) => ({
+        id: p.id,
+        slug: p.slug,
+        createdAt: p.createdAt,
+        published: p.published,
+        priceCents: p.priceCents,
+        currency: p.currency,
+        chariowProductId: p.chariowProductId || "",
+        bookTitle: p.book?.title || "",
+        authorName: p.book?.author?.name || "",
+        authorEmail: p.book?.author?.email || "",
+        region: p.book?.author?.region || "AFRIQUE",
+      }))
+    );
+  } catch (error) {
+    console.error("Erreur /api/admin/books :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/sales-pages/[id].js b/pages/api/admin/sales-pages/[id].js
new file mode 100644
index 0000000..9d51692
--- /dev/null
+++ b/pages/api/admin/sales-pages/[id].js
@@ -0,0 +1,31 @@
+import { requireAdmin } from "../../../../lib/admin";
+import { prisma } from "../../../../lib/db";
+
+// Relie (ou délie) le produit Chariow d'une page de vente.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "PATCH") return res.status(405).end();
+
+  try {
+    const { id } = req.query;
+    const raw = req.body?.chariowProductId;
+    if (typeof raw !== "string") return res.status(400).json({ error: "chariowProductId requis" });
+
+    const value = raw.trim();
+    if (value && !/^[A-Za-z0-9_-]{3,100}$/.test(value)) {
+      return res.status(400).json({ error: "Identifiant de produit invalide (ex. prd_abc123)." });
+    }
+
+    const page = await prisma.salesPage.findUnique({ where: { id }, select: { id: true } });
+    if (!page) return res.status(404).json({ error: "Page de vente introuvable" });
+
+    const updated = await prisma.salesPage.update({
+      where: { id },
+      data: { chariowProductId: value || null },
+      select: { id: true, chariowProductId: true },
+    });
+    return res.status(200).json(updated);
+  } catch (error) {
+    console.error("Erreur PATCH /api/admin/sales-pages/[id] :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/checkout/create.js b/pages/api/checkout/create.js
index 17059d2..8610a5d 100644
--- a/pages/api/checkout/create.js
+++ b/pages/api/checkout/create.js
@@ -3,6 +3,7 @@ import { prisma } from "../../../lib/db";
 import { stripe } from "../../../lib/stripe";
 import { initChariowCheckout } from "../../../lib/chariow";
 import { isValidEmail } from "../../../lib/validate";
+import { splitPhone } from "../../../lib/countryCodes";
 import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
 import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";
 
@@ -106,21 +107,43 @@ export default async function handler(req, res) {
   }
 
   // --- Zone Afrique francophone : Chariow ---
-  if (!salesPage.chariowProductId) {
-    return res.status(400).json({
-      error: "Produit Chariow non configuré pour ce livre. Renseigne-le manuellement dans le dashboard Chariow si le provisioning automatique a échoué.",
+  if (!salesPage.chariowProductId || !process.env.CHARIOW_API_KEY) {
+    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
+    return res.status(503).json({
+      error: "Le paiement en ligne de ce livre sera disponible très bientôt. Merci de revenir un peu plus tard.",
     });
   }
 
-  const result = await initChariowCheckout({
-    productId: salesPage.chariowProductId,
-    email: buyerEmail,
-    firstName: buyerName.split(" ")[0] || buyerName,
-    lastName: buyerName.split(" ").slice(1).join(" ") || buyerName,
-    phoneNumber: buyerWhatsapp,
-    redirectUrl: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
-    metadata: { purchaseId: purchase.id },
-  });
+  const phone = splitPhone(buyerWhatsapp);
+  let result;
+  try {
+    result = await initChariowCheckout({
+      productId: salesPage.chariowProductId,
+      email: buyerEmail,
+      firstName: buyerName.split(" ")[0] || buyerName,
+      lastName: buyerName.split(" ").slice(1).join(" ") || buyerName.split(" ")[0],
+      phoneNumber: phone.number,
+      phoneCountryIso: phone.iso,
+      redirectUrl: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
+      metadata: { purchaseId: purchase.id },
+      shipping: {
+        address: shippingAddress,
+        city: shippingCity,
+        zip: shippingPostalCode,
+        country: shippingCountry,
+      },
+    });
+  } catch (err) {
+    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "failed" } });
+    console.error("Checkout Chariow impossible :", err.message);
+    return res.status(502).json({ error: "Le paiement n'a pas pu démarrer. Réessayez dans un instant." });
+  }
+
+  // On relie l'achat à la vente Chariow : c'est cet identifiant que le Pulse
+  // renverra quand le paiement sera confirmé.
+  if (result.purchase?.id) {
+    await prisma.purchase.update({ where: { id: purchase.id }, data: { providerRef: result.purchase.id } });
+  }
 
   if (result.step === "completed") {
     await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
diff --git a/pages/api/sales-pages/index.js b/pages/api/sales-pages/index.js
index 929c799..3ee3b67 100644
--- a/pages/api/sales-pages/index.js
+++ b/pages/api/sales-pages/index.js
@@ -1,7 +1,6 @@
 import { requireAuth } from "../../../lib/auth";
 import { prisma } from "../../../lib/db";
 import { generateSalesPageCopy } from "../../../lib/ai";
-import { createChariowProduct } from "../../../lib/chariow";
 
 function slugify(title) {
   return title
@@ -36,29 +35,9 @@ export default requireAuth(async function handler(req, res) {
       create: { bookId: book.id, slug, priceCents, currency, ...copy },
     });
 
-    // Zone Afrique : provisionne un produit Chariow pour ce livre s'il n'en a
-    // pas deja un, afin que le checkout (POST /api/checkout/create) puisse
-    // s'en servir. Best-effort - voir l'avertissement dans lib/chariow.js.
-    if (book.author.region === "AFRIQUE" && !salesPage.chariowProductId) {
-      try {
-        const product = await createChariowProduct({
-          name: book.title,
-          description: copy.solution?.slice(0, 300) || book.title,
-          priceValue: Math.round(priceCents / 100),
-          currency,
-        });
-        salesPage = await prisma.salesPage.update({
-          where: { id: salesPage.id },
-          data: { chariowProductId: product.id },
-        });
-      } catch (err) {
-        // On ne fait pas echouer la generation de la page pour autant : la
-        // page de vente reste utilisable, mais le checkout renverra une
-        // erreur explicite tant que chariowProductId n'est pas configure
-        // (manuellement si besoin, voir README).
-        console.error("Provisionnement produit Chariow echoue :", err.message);
-      }
-    }
+    // Zone Afrique : le produit Chariow de ce livre est créé à la main dans
+    // le tableau de bord Chariow, puis relié depuis l'espace Administration
+    // > Livres (l'API publique de Chariow ne permet pas de créer des produits).
 
     return res.status(201).json(salesPage);
   } catch (error) {
diff --git a/pages/api/subscriptions/checkout.js b/pages/api/subscriptions/checkout.js
index 6a03633..aae6286 100644
--- a/pages/api/subscriptions/checkout.js
+++ b/pages/api/subscriptions/checkout.js
@@ -1,6 +1,7 @@
 import { requireAuth } from "../../../lib/auth";
 import { prisma } from "../../../lib/db";
 import { initChariowCheckout } from "../../../lib/chariow";
+import { splitPhone } from "../../../lib/countryCodes";
 
 // Un seul produit Chariow pour l'abonnement Plume, facturé dans la devise
 // de la zone de l'auteur grâce au paramètre payment_currency (conversion
@@ -13,11 +14,20 @@ export default requireAuth(async function handler(req, res) {
     const author = await prisma.author.findUnique({ where: { id: req.authorId } });
     const [firstName, ...rest] = author.name.split(" ");
 
+    // Chariow exige un numéro de téléphone pour tout achat.
+    const phoneInput = String(req.body?.phone || "").trim();
+    const phone = splitPhone(phoneInput);
+    if (phone.number.length < 6) {
+      return res.status(400).json({ error: "Indiquez votre numéro de téléphone pour continuer." });
+    }
+
     const result = await initChariowCheckout({
       productId: process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
       email: author.email,
       firstName: firstName || author.name,
       lastName: rest.join(" ") || author.name,
+      phoneNumber: phone.number,
+      phoneCountryIso: phone.iso,
       redirectUrl: `${process.env.APP_URL}/dashboard/abonnement?paiement=retour`,
       paymentCurrency: author.region === "EUROPE" ? "EUR" : "XOF",
       metadata: { authorId: author.id, kind: "subscription" },
diff --git a/pages/api/webhooks/chariow.js b/pages/api/webhooks/chariow.js
index ac9a3ec..848c455 100644
--- a/pages/api/webhooks/chariow.js
+++ b/pages/api/webhooks/chariow.js
@@ -1,63 +1,118 @@
+import crypto from "crypto";
 import { prisma } from "../../../lib/db";
-import { verifyChariowSale } from "../../../lib/chariow";
+import { getChariowSale } from "../../../lib/chariow";
 import { sendPurchaseConfirmationEmail } from "../../../lib/email";
 
-// Pulse Chariow. "sale.completed" est confirmé par la documentation
-// publique. Les noms exacts des événements liés à l'abonnement
-// (échec de paiement, annulation) ne sont PAS confirmés — vérifie-les dans
-// Réglages > Pulses de ton dashboard Chariow et ajuste les comparaisons
-// event === "..." ci-dessous si besoin.
+// Pulse Chariow (webhook). Configuration côté Chariow :
+//   Automatisations > Pulses > Créer un pulse
+//   URL   : https://VOTRE-SITE/api/webhooks/chariow
+//   Événements : "Vente réussie" (successful.sale) et "Vente échouée" (failed.sale)
+// Puis copier le "Signing secret" (whsec_...) du pulse dans la variable
+// d'environnement CHARIOW_WEBHOOK_SECRET.
 //
-// SÉCURITÉ : Chariow ne documente pas de signature HMAC vérifiable pour le
-// moment (contrairement à Stripe). En attendant de la confirmer avec leur
-// support, on protège cette route par un secret partagé dans l'URL — configure
-// dans Chariow l'URL exacte :
-//   https://ton-domaine.vercel.app/api/webhooks/chariow?secret=TA_VALEUR
-// (la même valeur que CHARIOW_WEBHOOK_SECRET). Sans ce secret, la requête
-// est rejetée avant même d'être lue — même le cas "sale.completed", pourtant
-// déjà re-vérifié auprès de Chariow, gagne cette couche supplémentaire.
+// Sécurité : chaque requête est signée (en-tête x-chariow-signature =
+// "sha256=" + HMAC-SHA256 du corps brut avec le secret du pulse). On vérifie
+// cette signature sur le corps BRUT avant de lire quoi que ce soit.
+export const config = { api: { bodyParser: false } };
+
+function readRawBody(req) {
+  return new Promise((resolve, reject) => {
+    const chunks = [];
+    req.on("data", (c) => chunks.push(c));
+    req.on("end", () => resolve(Buffer.concat(chunks)));
+    req.on("error", reject);
+  });
+}
+
+function signatureIsValid(rawBody, header, secret) {
+  if (!header || !secret) return false;
+  const expected = "sha256=" + crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
+  const a = Buffer.from(expected);
+  const b = Buffer.from(String(header));
+  return a.length === b.length && crypto.timingSafeEqual(a, b);
+}
+
+function formatAmount(cents, currency) {
+  const amount = (cents || 0) / 100;
+  return currency === "EUR" ? `${amount.toFixed(2)} €` : `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
+}
+
 export default async function handler(req, res) {
   if (req.method !== "POST") return res.status(405).end();
 
-  if (!process.env.CHARIOW_WEBHOOK_SECRET || req.query.secret !== process.env.CHARIOW_WEBHOOK_SECRET) {
-    return res.status(401).json({ error: "Non autorisé" });
+  const secret = process.env.CHARIOW_WEBHOOK_SECRET;
+  if (!secret) {
+    console.error("CHARIOW_WEBHOOK_SECRET manquant — Pulse Chariow rejeté.");
+    return res.status(500).json({ error: "Webhook non configuré" });
   }
 
-  const { event, data } = req.body || {};
-  if (!event || !data) return res.status(400).json({ error: "Payload invalide" });
+  const raw = await readRawBody(req);
+  if (!signatureIsValid(raw, req.headers["x-chariow-signature"], secret)) {
+    return res.status(401).json({ error: "Signature invalide" });
+  }
 
-  const customerEmail = data.customer?.email;
-  const productSlug = data.product?.slug;
-  const authorId = data.metadata?.authorId;
-  const kind = data.metadata?.kind;
+  let payload;
+  try {
+    payload = JSON.parse(raw.toString("utf8"));
+  } catch {
+    return res.status(400).json({ error: "Payload invalide" });
+  }
 
-  if (event === "sale.completed") {
-    // Reconfirmation serveur-à-serveur avant de faire confiance à la
-    // notification — même principe que pour CinetPay/Stripe.
-    const confirmed =
-      customerEmail && productSlug ? await verifyChariowSale({ productSlug, customerEmail }) : null;
+  const event = payload.event || req.headers["x-pulse-event"];
+  const sale = payload.sale || {};
+  const productId = payload.product?.id;
+  const customerEmail = (payload.customer?.email || "").toLowerCase();
 
-    if (!confirmed) {
-      return res.status(200).json({ received: true, ignored: "not_confirmed" });
-    }
+  try {
+    if (event === "successful.sale") {
+      // Reconfirmation auprès de Chariow (défense en profondeur). Si la
+      // lecture échoue pour une raison technique, la signature valide suffit.
+      try {
+        const confirmed = sale.id ? await getChariowSale(sale.id) : null;
+        if (confirmed && !["completed", "settled"].includes(confirmed.status)) {
+          return res.status(200).json({ received: true, ignored: "not_completed" });
+        }
+      } catch (err) {
+        console.error("Reconfirmation Chariow impossible :", err.message);
+      }
 
-    if (kind === "subscription" && authorId) {
-      // Paiement de l'abonnement à la plateforme.
-      await prisma.author.update({
-        where: { id: authorId },
-        data: {
-          subscriptionStatus: "ACTIVE",
-          currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
-        },
-      });
-    } else if (customerEmail) {
-      // Achat d'un livre (zone Afrique).
-      const purchase = await prisma.purchase.findFirst({
-        where: { provider: "chariow", buyerEmail: customerEmail, status: "pending" },
-        orderBy: { createdAt: "desc" },
-        include: { book: true },
-      });
-      if (purchase) {
+      // --- Abonnement Plume ---
+      if (productId && productId === process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID) {
+        const authorId = sale.custom_metadata?.authorId;
+        const author = authorId
+          ? await prisma.author.findUnique({ where: { id: authorId } })
+          : customerEmail
+          ? await prisma.author.findFirst({ where: { email: { equals: customerEmail, mode: "insensitive" } } })
+          : null;
+        if (author) {
+          // Date de fin calculée à partir du paiement : rejouer le même Pulse
+          // ne prolonge donc jamais l'abonnement une deuxième fois.
+          const paidAt = sale.completed_at ? new Date(sale.completed_at) : new Date();
+          const end = new Date(paidAt.getTime() + 30 * 24 * 60 * 60 * 1000);
+          await prisma.author.update({
+            where: { id: author.id },
+            data: {
+              subscriptionStatus: "ACTIVE",
+              currentPeriodEnd: author.currentPeriodEnd && author.currentPeriodEnd > end ? author.currentPeriodEnd : end,
+            },
+          });
+        }
+        return res.status(200).json({ received: true });
+      }
+
+      // --- Achat d'un livre ---
+      let purchase = sale.id
+        ? await prisma.purchase.findFirst({ where: { provider: "chariow", providerRef: sale.id }, include: { book: true } })
+        : null;
+      if (!purchase && customerEmail) {
+        purchase = await prisma.purchase.findFirst({
+          where: { provider: "chariow", buyerEmail: { equals: customerEmail, mode: "insensitive" }, status: "pending" },
+          orderBy: { createdAt: "desc" },
+          include: { book: true },
+        });
+      }
+
+      if (purchase && purchase.status !== "paid") {
         await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
         await prisma.lead.create({
           data: {
@@ -74,20 +129,20 @@ export default async function handler(req, res) {
           to: purchase.buyerEmail,
           buyerName: purchase.buyerName,
           bookTitle: purchase.book.title,
-          amountFormatted: `${purchase.amountCents} ${purchase.currency}`,
+          amountFormatted: formatAmount(purchase.amountCents, purchase.currency),
         });
       }
     }
-  }
-
-  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
-  if (event === "subscription.payment_failed" && authorId) {
-    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "PAST_DUE" } });
-  }
 
-  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
-  if (event === "subscription.cancelled" && authorId) {
-    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "CANCELED" } });
+    if (event === "failed.sale" && sale.id) {
+      await prisma.purchase.updateMany({
+        where: { provider: "chariow", providerRef: sale.id, status: "pending" },
+        data: { status: "failed" },
+      });
+    }
+  } catch (error) {
+    console.error("Erreur Pulse Chariow :", error);
+    return res.status(500).json({ error: "Erreur de traitement" });
   }
 
   return res.status(200).json({ received: true });
diff --git a/pages/dashboard/abonnement.js b/pages/dashboard/abonnement.js
index b70526e..9ddebf6 100644
--- a/pages/dashboard/abonnement.js
+++ b/pages/dashboard/abonnement.js
@@ -5,6 +5,7 @@ import DashboardShell from "../../components/DashboardShell";
 import { colors, ErrorBanner, Spinner } from "../../components/ui";
 import { useAuthGuard } from "../../lib/useAuthGuard";
 import { api } from "../../lib/apiClient";
+import { COUNTRY_CODES } from "../../lib/countryCodes";
 
 const FEATURES = ["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 30 jours"];
 
@@ -71,6 +72,8 @@ export default function DashboardAbonnement() {
   const { author, setAuthor, loading: authLoading } = useAuthGuard();
 
   const [subscribing, setSubscribing] = useState(false);
+  const [phoneCode, setPhoneCode] = useState("+229");
+  const [phoneNumber, setPhoneNumber] = useState("");
   const [error, setError] = useState("");
   const [info, setInfo] = useState("");
 
@@ -87,7 +90,12 @@ export default function DashboardAbonnement() {
     setError("");
     setSubscribing(true);
     try {
-      const data = await api("/api/subscriptions/checkout", { method: "POST" });
+      if (!author?.lifetimeAccess && phoneNumber.replace(/\D/g, "").length < 6) {
+        setError("Indiquez votre numéro de téléphone pour continuer.");
+        setSubscribing(false);
+        return;
+      }
+      const data = await api("/api/subscriptions/checkout", { method: "POST", body: { phone: `${phoneCode}${phoneNumber}` } });
       if (data.status === "already_active") {
         const refreshed = await api("/api/authors/me");
         setAuthor(refreshed);
@@ -157,6 +165,34 @@ export default function DashboardAbonnement() {
 
               <ErrorBanner message={error} />
 
+              {!active && (
+                <div className="mt-3">
+                  <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
+                    Votre numéro de téléphone (requis pour le paiement)
+                  </p>
+                  <div className="flex gap-2 max-w-sm">
+                    <select
+                      value={phoneCode}
+                      onChange={(e) => setPhoneCode(e.target.value)}
+                      className="rounded-lg px-2 py-2.5 font-body text-sm"
+                      style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
+                    >
+                      {COUNTRY_CODES.map((c) => (
+                        <option key={c.iso} value={c.code}>{c.code}</option>
+                      ))}
+                    </select>
+                    <input
+                      type="tel"
+                      value={phoneNumber}
+                      onChange={(e) => setPhoneNumber(e.target.value.replace(/[^0-9]/g, ""))}
+                      placeholder="Numéro"
+                      className="rounded-lg px-3 py-2.5 font-body text-sm w-full min-w-0"
+                      style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
+                    />
+                  </div>
+                </div>
+              )}
+
               <button
                 onClick={handleSubscribe}
                 disabled={subscribing || active}
diff --git a/pages/dashboard/admin.js b/pages/dashboard/admin.js
index 6b713af..4bdb5e1 100644
--- a/pages/dashboard/admin.js
+++ b/pages/dashboard/admin.js
@@ -177,6 +177,34 @@ function Overview({ data }) {
   );
 }
 
+// ---------- Livres & produits Chariow ----------
+
+function ProductLinkCell({ row, onSave }) {
+  const [value, setValue] = useState(row.chariowProductId);
+  const [saving, setSaving] = useState(false);
+  const dirty = value.trim() !== row.chariowProductId;
+  if (row.region === "EUROPE") return <span style={{ color: colors.textPaperDim }}>Stripe (automatique)</span>;
+  return (
+    <div className="flex items-center gap-2">
+      <input
+        value={value}
+        onChange={(e) => setValue(e.target.value)}
+        placeholder="prd_..."
+        className="rounded-lg px-2 py-1.5 font-mono text-[12px] w-40 outline-none"
+        style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
+      />
+      <button
+        disabled={!dirty || saving}
+        onClick={async () => { setSaving(true); await onSave(row, value.trim()); setSaving(false); }}
+        className="font-body text-xs px-3 py-1.5 rounded-lg"
+        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: dirty ? 1 : 0.35 }}
+      >
+        {saving ? "…" : "Enregistrer"}
+      </button>
+    </div>
+  );
+}
+
 // ---------- Page ----------
 
 const TABS = [
@@ -185,6 +213,7 @@ const TABS = [
   { id: "buyers", label: "Acheteurs" },
   { id: "extract", label: "Contacts d’extrait" },
   { id: "payouts", label: "Reversements" },
+  { id: "books", label: "Livres & Chariow" },
 ];
 
 export default function DashboardAdmin() {
@@ -195,7 +224,7 @@ export default function DashboardAdmin() {
   const [error, setError] = useState("");
   const [busyId, setBusyId] = useState("");
 
-  const endpoints = { overview: "/api/admin/overview", authors: "/api/admin/authors", buyers: "/api/admin/buyers", extract: "/api/admin/extract-contacts", payouts: "/api/admin/payouts" };
+  const endpoints = { overview: "/api/admin/overview", authors: "/api/admin/authors", buyers: "/api/admin/buyers", extract: "/api/admin/extract-contacts", payouts: "/api/admin/payouts", books: "/api/admin/books" };
 
   async function load(which) {
     setLoadingTab(true);
@@ -311,6 +340,31 @@ export default function DashboardAdmin() {
     { label: "Traité le", key: "processedAt", render: (r) => fmtDate(r.processedAt), csv: (r) => fmtDate(r.processedAt) },
   ];
 
+  async function saveProductLink(row, value) {
+    setError("");
+    try {
+      await api(`/api/admin/sales-pages/${row.id}`, { method: "PATCH", body: { chariowProductId: value } });
+      await load("books");
+    } catch (err) {
+      setError(err.message);
+    }
+  }
+
+  const colsBooks = [
+    { label: "Livre", key: "bookTitle" },
+    { label: "Auteur", key: "authorName" },
+    { label: "Zone", key: "region", render: (r) => (r.region === "EUROPE" ? "Europe" : "Afrique"), csv: (r) => r.region },
+    { label: "Prix à créer dans Chariow", key: "priceCents", render: (r) => fmtMoney(r.priceCents, r.currency), csv: (r) => fmtMoney(r.priceCents, r.currency) },
+    { label: "Publiée", key: "published", render: (r) => (r.published ? "Oui" : "Non"), csv: (r) => (r.published ? "Oui" : "Non") },
+    {
+      label: "État", key: "chariowProductId",
+      render: (r) => r.region === "EUROPE" ? "—" : r.chariowProductId
+        ? <Badge bg="rgba(79,122,92,0.18)" fg="#2F5A3D">Relié</Badge>
+        : <Badge bg="rgba(201,162,39,0.28)" fg="#7A5E0B">À relier</Badge>,
+      csv: (r) => (r.chariowProductId ? "Relié" : "À relier"),
+    },
+  ];
+
   const current = data[tab];
 
   return (
@@ -380,6 +434,16 @@ export default function DashboardAdmin() {
             <DataTable title="Acheteurs" rows={current} columns={colsBuyers} searchKeys={["buyerName", "buyerEmail", "bookTitle", "authorName"]} csvName="acheteurs-plume.csv" empty="Aucun acheteur pour l’instant." />
           ) : tab === "extract" ? (
             <DataTable title="Contacts d’extrait" rows={current} columns={colsExtract} searchKeys={["firstName", "lastName", "email", "bookTitle", "authorName"]} csvName="contacts-extraits-plume.csv" empty="Aucun contact d’extrait pour l’instant." />
+          ) : tab === "books" ? (
+            <DataTable
+              title="Livres & produits Chariow"
+              rows={current}
+              columns={colsBooks}
+              searchKeys={["bookTitle", "authorName", "chariowProductId"]}
+              csvName="livres-plume.csv"
+              empty="Aucune page de vente pour l’instant."
+              extra={(r) => <ProductLinkCell key={r.id + r.chariowProductId} row={r} onSave={saveProductLink} />}
+            />
           ) : (
             <DataTable title="Reversements" rows={current} columns={colsPayouts} searchKeys={["authorName", "authorEmail"]} csvName="reversements-plume.csv" empty="Aucune demande de reversement." />
           )}
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : ce correctif ne peut pas s'appliquer. Vérifiez que essai_30j_et_acces_a_vie.sh a bien été appliqué avant."
  rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : connexion Chariow mise à jour"
