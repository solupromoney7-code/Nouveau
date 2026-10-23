#!/bin/bash
# Numéro WhatsApp de l'auteur : demandé à l'inscription, modifiable dans Paramètres,
# et lien "Répondre à l'auteur" ajouté aux messages WhatsApp automatiques
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/whatsapp.js b/lib/whatsapp.js
index a13746a..2e800c6 100644
--- a/lib/whatsapp.js
+++ b/lib/whatsapp.js
@@ -26,6 +26,12 @@ function cleanNumber(value) {
   return (value || "").replace(/[^0-9]/g, "");
 }
 
+// Meta refuse les retours à la ligne, tabulations et séries d'espaces dans la
+// variable d'un modèle : on les remplace par un simple espace.
+function cleanParam(text) {
+  return String(text || "").replace(/\s+/g, " ").trim().slice(0, 1024);
+}
+
 export function isWhatsAppConfigured() {
   return Boolean(ACCESS_TOKEN && PHONE_NUMBER_ID);
 }
@@ -60,7 +66,7 @@ export async function sendWhatsAppMessage({ to, bodyText }) {
         components: [
           {
             type: "body",
-            parameters: [{ type: "text", text: (bodyText || "").slice(0, 1024) }],
+            parameters: [{ type: "text", text: cleanParam(bodyText) }],
           },
         ],
       },
diff --git a/pages/api/auth/signup.js b/pages/api/auth/signup.js
index 187afaf..8ae95c0 100644
--- a/pages/api/auth/signup.js
+++ b/pages/api/auth/signup.js
@@ -22,7 +22,7 @@ export default async function handler(req, res) {
     return res.status(400).json({ error: "Vérification anti-bot échouée." });
   }
 
-  const { email, password, name, region } = req.body;
+  const { email, password, name, region, whatsapp } = req.body;
   if (!email || !password || !name) {
     return res.status(400).json({ error: "Email, mot de passe et nom sont requis" });
   }
@@ -33,6 +33,11 @@ export default async function handler(req, res) {
     return res.status(400).json({ error: "Le mot de passe doit contenir au moins 8 caractères" });
   }
 
+  const whatsappDigits = String(whatsapp || "").replace(/\D/g, "");
+  if (whatsappDigits.length < 8 || whatsappDigits.length > 15) {
+    return res.status(400).json({ error: "Indiquez un numéro WhatsApp valide (avec l'indicatif du pays)." });
+  }
+
   const existing = await prisma.author.findUnique({ where: { email } });
   if (existing) return res.status(409).json({ error: "Cet email est déjà utilisé" });
 
@@ -45,6 +50,7 @@ export default async function handler(req, res) {
       passwordHash,
       name: clampText(name, 120),
       region: region === "EUROPE" ? "EUROPE" : "AFRIQUE",
+      whatsappNumber: `+${whatsappDigits}`,
       trialEndsAt,
     },
   });
diff --git a/pages/api/authors/me.js b/pages/api/authors/me.js
index c500a0d..34dcda5 100644
--- a/pages/api/authors/me.js
+++ b/pages/api/authors/me.js
@@ -10,7 +10,7 @@ export default requireAuth(async function handler(req, res) {
     select: {
       id: true, name: true, email: true, region: true, emailVerified: true,
       subscriptionStatus: true, lifetimeAccess: true, trialEndsAt: true, currentPeriodEnd: true,
-      stripeAccountId: true, stripeOnboarded: true, paymentLink: true,
+      stripeAccountId: true, stripeOnboarded: true, paymentLink: true, whatsappNumber: true,
       momoOperator: true, momoNumber: true,
     },
   });
diff --git a/pages/api/authors/payment-config.js b/pages/api/authors/payment-config.js
index df35d68..ff0604b 100644
--- a/pages/api/authors/payment-config.js
+++ b/pages/api/authors/payment-config.js
@@ -17,6 +17,16 @@ export default requireAuth(async function handler(req, res) {
     }
 
     if (req.method === "PUT") {
+      // Numéro WhatsApp de l'auteur
+      if (req.body && "whatsappNumber" in req.body) {
+        const digits = String(req.body.whatsappNumber || "").replace(/\D/g, "");
+        if (digits.length < 8 || digits.length > 15) {
+          return res.status(400).json({ error: "Numéro WhatsApp invalide (indiquez l'indicatif du pays, ex. +229…)." });
+        }
+        await prisma.author.update({ where: { id: req.authorId }, data: { whatsappNumber: `+${digits}` } });
+        return res.status(200).json({ ok: true, whatsappNumber: `+${digits}` });
+      }
+
       // Zone Europe : lien de paiement de l'auteur
       if (req.body && "paymentLink" in req.body) {
         const raw = String(req.body.paymentLink || "").trim();
diff --git a/pages/api/cron/process-emails.js b/pages/api/cron/process-emails.js
index 64cb3f0..090aaeb 100644
--- a/pages/api/cron/process-emails.js
+++ b/pages/api/cron/process-emails.js
@@ -15,6 +15,14 @@ import { isSubscriptionActive } from "../../../lib/subscription";
 //   2. Envoie les broadcasts programmés dont l'heure est passée (déjà
 //      filtrés à la création par la même règle, voir broadcasts/index.js —
 //      revérifié ici au cas où l'abonnement aurait expiré entre-temps).
+// Ajoute un lien "répondre à l'auteur" : les messages partent du numéro de
+// Plume, mais le lecteur peut ensuite écrire directement à l'auteur.
+function withReplyLink(text, authorNumber) {
+  const digits = String(authorNumber || "").replace(/\D/g, "");
+  const base = String(text || "").slice(0, 900);
+  return digits ? `${base} — Répondre à l'auteur : https://wa.me/${digits}` : base;
+}
+
 export default async function handler(req, res) {
   const auth = req.headers.authorization || "";
   if (process.env.CRON_SECRET && auth !== `Bearer ${process.env.CRON_SECRET}`) {
@@ -92,7 +100,7 @@ export default async function handler(req, res) {
     where: { active: true },
     include: {
       steps: { orderBy: { order: "asc" } },
-      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true } },
+      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true, whatsappNumber: true } },
     },
   });
 
@@ -133,7 +141,7 @@ export default async function handler(req, res) {
 
       const result = await sendWhatsAppMessage({
         to: lead.whatsapp,
-        bodyText: renderTemplate(nextStep.body, vars),
+        bodyText: withReplyLink(renderTemplate(nextStep.body, vars), sequence.author.whatsappNumber),
       });
 
       if (result.sent) {
diff --git a/pages/dashboard/parametres.js b/pages/dashboard/parametres.js
index 110eb84..77d030c 100644
--- a/pages/dashboard/parametres.js
+++ b/pages/dashboard/parametres.js
@@ -284,6 +284,69 @@ function PaymentLinkSection({ author }) {
   );
 }
 
+function WhatsAppNumberSection({ author }) {
+  const [number, setNumber] = useState(author?.whatsappNumber || "");
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
+      const data = await api("/api/authors/payment-config", { method: "PUT", body: { whatsappNumber: number } });
+      setNumber(data.whatsappNumber);
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
+        <Smartphone size={16} color={colors.goldDark} />
+        <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Mon numéro WhatsApp</h2>
+      </div>
+      <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
+        Vos lecteurs pourront vous répondre directement sur ce numéro : un lien « Répondre à l’auteur » est ajouté à vos messages WhatsApp automatiques.
+      </p>
+      <form onSubmit={handleSave} className="space-y-3 max-w-sm">
+        <ErrorBanner message={error} />
+        <input
+          type="tel"
+          value={number}
+          onChange={(e) => setNumber(e.target.value)}
+          placeholder="+229 01 00 00 00 00"
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
 
@@ -299,6 +362,7 @@ export default function DashboardParametres() {
       ) : (
         <div className="max-w-2xl space-y-6">
           <EmailVerificationSection author={author} />
+          <WhatsAppNumberSection author={author} />
           {author?.region === "EUROPE" ? <PaymentLinkSection author={author} /> : <MomoSection author={author} />}
         </div>
       )}
diff --git a/pages/inscription.js b/pages/inscription.js
index 986751f..8384858 100644
--- a/pages/inscription.js
+++ b/pages/inscription.js
@@ -4,10 +4,11 @@ import Link from "next/link";
 import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
 import AuthShell from "../components/AuthShell";
 import { api, saveToken } from "../lib/apiClient";
+import { COUNTRY_CODES, DEFAULT_COUNTRY_CODE } from "../lib/countryCodes";
 
 export default function Inscription() {
   const router = useRouter();
-  const [form, setForm] = useState({ name: "", email: "", password: "", region: "AFRIQUE", website: "" });
+  const [form, setForm] = useState({ name: "", email: "", password: "", region: "AFRIQUE", website: "", phoneCode: DEFAULT_COUNTRY_CODE, phone: "" });
   const [error, setError] = useState("");
   const [loading, setLoading] = useState(false);
 
@@ -21,6 +22,11 @@ export default function Inscription() {
       setError("Le mot de passe doit contenir au moins 8 caractères.");
       return;
     }
+    const phoneDigits = form.phone.replace(/\D/g, "").replace(/^0+/, "");
+    if (phoneDigits.length < 6) {
+      setError("Indiquez votre numéro WhatsApp.");
+      return;
+    }
 
     setLoading(true);
     try {
@@ -32,6 +38,7 @@ export default function Inscription() {
           email: form.email,
           password: form.password,
           region: form.region,
+          whatsapp: `${form.phoneCode}${phoneDigits}`,
           hpField: form.website, // honeypot — doit rester vide
         },
       });
@@ -106,6 +113,26 @@ export default function Inscription() {
         style={inputStyle}
       />
 
+      <div className="flex gap-2">
+        <select
+          value={form.phoneCode}
+          onChange={(e) => setForm({ ...form, phoneCode: e.target.value })}
+          className="rounded-lg px-2 py-2.5 font-body text-sm"
+          style={{ ...inputStyle, width: 110 }}
+          aria-label="Indicatif du pays"
+        >
+          {COUNTRY_CODES.map((c) => <option key={c.iso} value={c.code}>{c.iso} {c.code}</option>)}
+        </select>
+        <input
+          type="tel"
+          placeholder="Votre numéro WhatsApp"
+          value={form.phone}
+          onChange={(e) => setForm({ ...form, phone: e.target.value })}
+          className="rounded-lg px-3 py-2.5 font-body text-sm flex-1 min-w-0"
+          style={inputStyle}
+        />
+      </div>
+
       <div className="flex rounded-full p-1 mt-1" style={{ backgroundColor: colors.paperDim }}>
         {["AFRIQUE", "EUROPE"].map((r) => (
           <button
diff --git a/prisma/schema.prisma b/prisma/schema.prisma
index 6ca3c48..4ad0b4a 100644
--- a/prisma/schema.prisma
+++ b/prisma/schema.prisma
@@ -37,6 +37,7 @@ model Author {
   // Stripe Connect — zone Europe
   stripeAccountId    String?
   stripeOnboarded    Boolean             @default(false)
+  whatsappNumber     String?             // numéro WhatsApp de l'auteur (format international)
   paymentLink        String?             // zone Europe : lien de paiement de l'auteur (Stripe Payment Link, PayPal…)
 
   // Mobile Money — zone Afrique francophone
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?). Avez-vous appliqué desinscription.sh avant ?"; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : numéro WhatsApp de l'auteur appliqué"
