#!/bin/bash
# WhatsApp : "Répondez-moi ici" + lien vers le WhatsApp de l'auteur
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/pages/api/cron/process-emails.js b/pages/api/cron/process-emails.js
index 090aaeb..ec830d5 100644
--- a/pages/api/cron/process-emails.js
+++ b/pages/api/cron/process-emails.js
@@ -20,7 +20,7 @@ import { isSubscriptionActive } from "../../../lib/subscription";
 function withReplyLink(text, authorNumber) {
   const digits = String(authorNumber || "").replace(/\D/g, "");
   const base = String(text || "").slice(0, 900);
-  return digits ? `${base} — Répondre à l'auteur : https://wa.me/${digits}` : base;
+  return digits ? `${base} 👉 Répondez-moi ici : https://wa.me/${digits}` : base;
 }
 
 export default async function handler(req, res) {
diff --git a/pages/dashboard/tunnels.js b/pages/dashboard/tunnels.js
index b71a0a6..95cb7ce 100644
--- a/pages/dashboard/tunnels.js
+++ b/pages/dashboard/tunnels.js
@@ -99,12 +99,17 @@ function SequenceStep({ step, channel, onSave }) {
               onChange={(e) => setBody(e.target.value)}
               onBlur={() => persist({ body })}
               rows={channel === "email" ? 7 : 5}
-              maxLength={channel === "whatsapp" ? 1024 : undefined}
+              maxLength={channel === "whatsapp" ? 900 : undefined}
               className="w-full rounded-lg px-3 py-2 font-body text-sm resize-y"
               style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
             />
             {channel === "whatsapp" && (
-              <p className="font-mono text-[10px] mt-1" style={{ color: colors.mist }}>{body.length} / 1024 caractères</p>
+              <p className="font-mono text-[10px] mt-1" style={{ color: colors.mist }}>{body.length} / 900 caractères</p>
+            )}
+            {channel === "whatsapp" && (
+              <p className="font-body text-xs mt-1.5" style={{ color: colors.forest }}>
+                Ajouté automatiquement à la fin de chaque message : « Répondez-moi ici » + un lien vers votre WhatsApp (celui de Paramètres).
+              </p>
             )}
             <p className="font-mono text-[10px] mt-1.5" style={{ color: colors.mist }}>
               Variables disponibles : {"{{prenom}}"}, {"{{titre}}"}, {"{{auteur}}"}, {"{{lien_achat}}"}, {"{{lien_boutique}}"}
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : lien Répondez-moi ici appliqué"
