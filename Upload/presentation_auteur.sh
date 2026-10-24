#!/bin/bash
# WhatsApp : le premier message de chaque tunnel présente l'auteur
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/whatsappSequences.js b/lib/whatsappSequences.js
index 8a7ebfb..22ac986 100644
--- a/lib/whatsappSequences.js
+++ b/lib/whatsappSequences.js
@@ -14,7 +14,7 @@ export const DEFAULT_WHATSAPP_SEQUENCES = {
       {
         order: 1,
         delayDays: 1,
-        body: "Bonjour {{prenom}} 👋 J’espère que l’extrait de « {{titre}} » vous a plu ! Le livre complet est disponible ici : {{lien_achat}}",
+        body: "Bonjour {{prenom}}, c’est {{auteur}}, l’auteur de « {{titre}} » 👋 Merci d’avoir lu l’extrait, j’espère qu’il vous a plu ! Le livre complet est disponible ici : {{lien_achat}}",
       },
       {
         order: 2,
@@ -55,7 +55,7 @@ export const DEFAULT_WHATSAPP_SEQUENCES = {
       {
         order: 1,
         delayDays: 2,
-        body: "Bonjour {{prenom}}, merci encore pour votre achat de « {{titre}} » ! Comment se passe la lecture ? N’hésitez pas à me répondre ici si besoin 🙂",
+        body: "Bonjour {{prenom}}, c’est {{auteur}}, l’auteur de « {{titre}} ». Merci encore pour votre achat ! Comment se passe la lecture ? N’hésitez pas à me répondre ici si besoin 🙂",
       },
       {
         order: 2,
diff --git a/pages/api/cron/process-emails.js b/pages/api/cron/process-emails.js
index ec830d5..88d871b 100644
--- a/pages/api/cron/process-emails.js
+++ b/pages/api/cron/process-emails.js
@@ -23,6 +23,22 @@ function withReplyLink(text, authorNumber) {
   return digits ? `${base} 👉 Répondez-moi ici : https://wa.me/${digits}` : base;
 }
 
+// Premier message d'une séquence WhatsApp : le lecteur doit savoir tout de
+// suite QUI écrit. Si le texte ne mentionne pas déjà le nom de l'auteur, on
+// ajoute en tête « Bonjour <prénom>, c'est <auteur>, l'auteur de « <titre> ». ».
+function withAuthorIntro(text, { prenom, auteur, titre }) {
+  const body = String(text || "");
+  if (!auteur || body.toLowerCase().includes(String(auteur).toLowerCase())) return body;
+  const who = titre ? `c’est ${auteur}, l’auteur de « ${titre} ».` : `c’est ${auteur}.`;
+  const greeting = prenom ? `Bonjour ${prenom}, ${who}` : `Bonjour, ${who}`;
+  // Évite le double « Bonjour Franck, … » si le texte commence déjà ainsi.
+  const stripped = prenom
+    ? body.replace(new RegExp(`^\\s*Bonjour\\s+${prenom.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*[,!.]?\\s*`, "i"), "")
+    : body.replace(/^\s*Bonjour\s*[,!.]?\s*/i, "");
+  const rest = stripped.charAt(0).toUpperCase() + stripped.slice(1);
+  return `${greeting} ${rest}`.trim();
+}
+
 export default async function handler(req, res) {
   const auth = req.headers.authorization || "";
   if (process.env.CRON_SECRET && auth !== `Bearer ${process.env.CRON_SECRET}`) {
@@ -139,9 +155,15 @@ export default async function handler(req, res) {
         lien_boutique: `${appUrl}/boutique/${sequence.authorId}`,
       };
 
+      let text = renderTemplate(nextStep.body, vars);
+      // Premier message de la séquence : se présenter (voir withAuthorIntro).
+      if (nextStep.id === sequence.steps[0]?.id) {
+        text = withAuthorIntro(text, { prenom: vars.prenom, auteur: vars.auteur, titre: vars.titre });
+      }
+
       const result = await sendWhatsAppMessage({
         to: lead.whatsapp,
-        bodyText: withReplyLink(renderTemplate(nextStep.body, vars), sequence.author.whatsappNumber),
+        bodyText: withReplyLink(text, sequence.author.whatsappNumber),
       });
 
       if (result.sent) {
diff --git a/pages/dashboard/tunnels.js b/pages/dashboard/tunnels.js
index 95cb7ce..e0e5a92 100644
--- a/pages/dashboard/tunnels.js
+++ b/pages/dashboard/tunnels.js
@@ -108,7 +108,7 @@ function SequenceStep({ step, channel, onSave }) {
             )}
             {channel === "whatsapp" && (
               <p className="font-body text-xs mt-1.5" style={{ color: colors.forest }}>
-                Ajouté automatiquement à la fin de chaque message : « Répondez-moi ici » + un lien vers votre WhatsApp (celui de Paramètres).
+                Ajouté automatiquement : à la fin de chaque message, « Répondez-moi ici » + un lien vers votre WhatsApp (celui de Paramètres) ; et au tout premier message, votre présentation (« c’est [votre nom], l’auteur de [titre] ») si elle n’y figure pas déjà.
               </p>
             )}
             <p className="font-mono text-[10px] mt-1.5" style={{ color: colors.mist }}>
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ? ou repondez_moi_ici.sh manquant)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : présentation de l'auteur dans le premier message WhatsApp"
