#!/bin/bash
# Désinscription des emails (lien dans chaque email + page publique)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/email.js b/lib/email.js
index ed4a06d..8b5f24f 100644
--- a/lib/email.js
+++ b/lib/email.js
@@ -1,6 +1,8 @@
 // Envoi d'email transactionnel via Resend — https://resend.com
 // Nécessite RESEND_API_KEY et RESEND_FROM_EMAIL (adresse expéditrice
 // vérifiée dans ton compte Resend, ex. "Plume <contact@ton-domaine.com>").
+import { unsubscribeUrl } from "./unsubscribe";
+
 const RESEND_API_KEY = process.env.RESEND_API_KEY;
 const RESEND_FROM_EMAIL = process.env.RESEND_FROM_EMAIL;
 
@@ -71,17 +73,23 @@ export async function sendPurchaseConfirmationEmail({ to, bookTitle, amountForma
 // (broadcasts). Le corps texte est fourni par l'auteur (ou pré-rempli par
 // défaut, voir lib/sequences.js) — on le transforme simplement en
 // paragraphes HTML, sans template marketing imposé.
-export async function sendMarketingEmail({ to, subject, textBody, replyTo }) {
+export async function sendMarketingEmail({ to, subject, textBody, replyTo, leadId }) {
   if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
     console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
     return { sent: false };
   }
 
-  const html = textBody
+  let html = textBody
     .split("\n\n")
     .map((p) => `<p>${p.replace(/\n/g, "<br/>")}</p>`)
     .join("\n");
 
+  // Lien de désinscription (obligatoire pour les emails marketing).
+  const unsubUrl = leadId ? unsubscribeUrl(leadId) : null;
+  if (unsubUrl) {
+    html += `\n<p style="font-size:12px;color:#888">Vous ne souhaitez plus recevoir ces emails ? <a href="${unsubUrl}">Se désinscrire</a></p>`;
+  }
+
   const res = await fetch("https://api.resend.com/emails", {
     method: "POST",
     headers: {
@@ -94,6 +102,12 @@ export async function sendMarketingEmail({ to, subject, textBody, replyTo }) {
       subject,
       html,
       ...(replyTo && { reply_to: replyTo }),
+      ...(unsubUrl && {
+        headers: {
+          "List-Unsubscribe": `<${unsubUrl.replace("/desinscription?", "/api/public/unsubscribe?")}>`,
+          "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
+        },
+      }),
     }),
   });
 
diff --git a/lib/unsubscribe.js b/lib/unsubscribe.js
new file mode 100644
index 0000000..87e7a6e
--- /dev/null
+++ b/lib/unsubscribe.js
@@ -0,0 +1,23 @@
+import crypto from "crypto";
+
+// Lien de désinscription signé : impossible de désinscrire quelqu'un d'autre
+// sans connaître le secret du serveur.
+function secret() {
+  return process.env.JWT_SECRET || "plume-dev-secret";
+}
+
+export function signLeadToken(leadId) {
+  return crypto.createHmac("sha256", secret()).update(String(leadId)).digest("hex").slice(0, 32);
+}
+
+export function verifyLeadToken(leadId, token) {
+  if (!leadId || !token) return false;
+  const expected = Buffer.from(signLeadToken(leadId));
+  const given = Buffer.from(String(token));
+  return expected.length === given.length && crypto.timingSafeEqual(expected, given);
+}
+
+export function unsubscribeUrl(leadId) {
+  const base = process.env.APP_URL || "";
+  return `${base}/desinscription?l=${encodeURIComponent(leadId)}&t=${signLeadToken(leadId)}`;
+}
diff --git a/pages/api/broadcasts/index.js b/pages/api/broadcasts/index.js
index 81e1084..7368aba 100644
--- a/pages/api/broadcasts/index.js
+++ b/pages/api/broadcasts/index.js
@@ -33,7 +33,7 @@ export default requireAuth(async function handler(req, res) {
 
   const when = scheduledAt ? new Date(scheduledAt) : new Date();
 
-  const where = { authorId: req.authorId, ...(listSource !== "tous" && { source: listSource }) };
+  const where = { authorId: req.authorId, unsubscribed: false, ...(listSource !== "tous" && { source: listSource }) };
   const recipients = await prisma.lead.findMany({ where });
 
   const broadcast = await prisma.broadcast.create({
@@ -57,6 +57,7 @@ export default requireAuth(async function handler(req, res) {
         subject: renderTemplate(subject, { prenom: lead.firstName, auteur: author.name }),
         textBody: renderTemplate(body, { prenom: lead.firstName, auteur: author.name }),
         replyTo: author.email,
+        leadId: lead.id,
       });
       if (!result.sent) anyFailed = true;
     }
diff --git a/pages/api/cron/process-emails.js b/pages/api/cron/process-emails.js
index 62961de..64cb3f0 100644
--- a/pages/api/cron/process-emails.js
+++ b/pages/api/cron/process-emails.js
@@ -42,7 +42,7 @@ export default async function handler(req, res) {
     }
 
     const leads = await prisma.lead.findMany({
-      where: { authorId: sequence.authorId, source: sequence.listSource },
+      where: { authorId: sequence.authorId, source: sequence.listSource, unsubscribed: false },
       include: { book: { include: { salesPage: true } } },
     });
 
@@ -74,6 +74,7 @@ export default async function handler(req, res) {
         to: lead.email,
         subject: renderTemplate(nextStep.subject, vars),
         textBody: renderTemplate(nextStep.body, vars),
+        leadId: lead.id,
       });
 
       if (result.sent) {
@@ -102,7 +103,7 @@ export default async function handler(req, res) {
     }
 
     const leads = await prisma.lead.findMany({
-      where: { authorId: sequence.authorId, source: sequence.listSource },
+      where: { authorId: sequence.authorId, source: sequence.listSource, unsubscribed: false },
       include: { book: { include: { salesPage: true } } },
     });
 
@@ -155,7 +156,7 @@ export default async function handler(req, res) {
       continue;
     }
 
-    const where = { authorId: broadcast.authorId, ...(broadcast.listSource !== "tous" && { source: broadcast.listSource }) };
+    const where = { authorId: broadcast.authorId, unsubscribed: false, ...(broadcast.listSource !== "tous" && { source: broadcast.listSource }) };
     const recipients = await prisma.lead.findMany({ where });
 
     let anyFailed = false;
@@ -165,6 +166,7 @@ export default async function handler(req, res) {
         subject: renderTemplate(broadcast.subject, { prenom: lead.firstName, auteur: broadcast.author.name }),
         textBody: renderTemplate(broadcast.body, { prenom: lead.firstName, auteur: broadcast.author.name }),
         replyTo: broadcast.author.email,
+        leadId: lead.id,
       });
       if (result.sent) broadcastsSent += 1;
       else anyFailed = true;
diff --git a/pages/api/public/unsubscribe.js b/pages/api/public/unsubscribe.js
new file mode 100644
index 0000000..29d51f5
--- /dev/null
+++ b/pages/api/public/unsubscribe.js
@@ -0,0 +1,18 @@
+import { prisma } from "../../../lib/db";
+import { verifyLeadToken } from "../../../lib/unsubscribe";
+
+// Route PUBLIQUE — désinscription en un clic (page /desinscription, ou
+// en-tête List-Unsubscribe des clients mail). Le jeton signé prouve que le
+// lien vient d'un de nos emails.
+export default async function handler(req, res) {
+  if (req.method !== "POST") return res.status(405).end();
+
+  const leadId = String(req.query.l || "");
+  const token = String(req.query.t || "");
+  if (!verifyLeadToken(leadId, token)) {
+    return res.status(400).json({ error: "Lien invalide ou expiré." });
+  }
+
+  await prisma.lead.updateMany({ where: { id: leadId }, data: { unsubscribed: true } });
+  return res.status(200).json({ ok: true });
+}
diff --git a/pages/dashboard/contacts.js b/pages/dashboard/contacts.js
index 2148470..fbead66 100644
--- a/pages/dashboard/contacts.js
+++ b/pages/dashboard/contacts.js
@@ -32,7 +32,7 @@ export default function DashboardContacts() {
       setError("Renseignez l’objet et le message.");
       return;
     }
-    if (!window.confirm(`Envoyer cet email à ${rows.length} contact(s) (${TAB_LABEL[tab]}) ?`)) return;
+    if (!window.confirm(`Envoyer cet email à ${rows.filter((r) => !r.unsubscribed).length} contact(s) (${TAB_LABEL[tab]}) ?`)) return;
     setSending(true);
     try {
       const data = await api("/api/broadcasts", {
@@ -196,7 +196,9 @@ export default function DashboardContacts() {
                             </a>
                           ) : "—"}
                         </td>
-                        <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>{r.email}</td>
+                        <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
+                          {r.email}{r.unsubscribed && <span className="ml-2 font-mono text-[10px] uppercase" style={{ color: colors.wine }}>désinscrit</span>}
+                        </td>
                         <td className="py-2.5 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
                           {new Date(r.createdAt).toLocaleDateString("fr-FR")}
                         </td>
diff --git a/pages/desinscription.js b/pages/desinscription.js
new file mode 100644
index 0000000..fa1cb21
--- /dev/null
+++ b/pages/desinscription.js
@@ -0,0 +1,49 @@
+import { useState } from "react";
+import { useRouter } from "next/router";
+import { colors } from "../components/ui";
+
+export default function Desinscription() {
+  const router = useRouter();
+  const { l, t } = router.query;
+  const [state, setState] = useState("idle"); // idle | loading | done | error
+
+  async function handleConfirm() {
+    setState("loading");
+    try {
+      const res = await fetch(`/api/public/unsubscribe?l=${encodeURIComponent(l)}&t=${encodeURIComponent(t)}`, { method: "POST" });
+      setState(res.ok ? "done" : "error");
+    } catch {
+      setState("error");
+    }
+  }
+
+  return (
+    <main className="min-h-screen flex items-center justify-center px-4" style={{ backgroundColor: colors.paper }}>
+      <div className="w-full max-w-md rounded-2xl p-8 text-center" style={{ backgroundColor: "#FFFFFF" }}>
+        <h1 className="font-display text-2xl mb-3" style={{ color: colors.textPaper }}>Désinscription</h1>
+        {state === "done" ? (
+          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>
+            C’est fait : vous ne recevrez plus d’emails de cet auteur.
+          </p>
+        ) : (
+          <>
+            <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
+              Confirmez-vous ne plus vouloir recevoir d’emails de cet auteur ?
+            </p>
+            {state === "error" && (
+              <p className="font-body text-sm mb-3" style={{ color: "#B3261E" }}>Lien invalide ou expiré.</p>
+            )}
+            <button
+              onClick={handleConfirm}
+              disabled={state === "loading" || !l || !t}
+              className="px-5 py-2.5 rounded-lg font-body font-semibold text-sm"
+              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: state === "loading" ? 0.6 : 1 }}
+            >
+              {state === "loading" ? "Un instant…" : "Me désinscrire"}
+            </button>
+          </>
+        )}
+      </div>
+    </main>
+  );
+}
diff --git a/prisma/schema.prisma b/prisma/schema.prisma
index ba00811..6ca3c48 100644
--- a/prisma/schema.prisma
+++ b/prisma/schema.prisma
@@ -119,6 +119,7 @@ model Lead {
   email      String
   whatsapp   String
   source     String   // "extrait" | "acheteur"
+  unsubscribed Boolean @default(false) // désinscrit des emails
   createdAt  DateTime @default(now())
 
   emailSends    EmailSend[]
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : lien de désinscription appliqué"
