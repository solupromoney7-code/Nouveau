#!/bin/bash
# WhatsApp : modèle de message accepté par Meta (variable entourée de texte fixe)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/whatsapp.js b/lib/whatsapp.js
index 2e800c6..5878949 100644
--- a/lib/whatsapp.js
+++ b/lib/whatsapp.js
@@ -104,8 +104,10 @@ export async function submitWhatsAppTemplate() {
       components: [
         {
           type: "BODY",
-          text: "{{1}}",
-          example: { body_text: [["Bonjour ! Voici un exemple de message envoyé automatiquement par Plume."]] },
+          // Meta refuse un modèle dont la variable est tout au début ou tout à
+          // la fin : on l'entoure d'une phrase fixe.
+          text: "Message de votre auteur : {{1}}\n\nRépondez STOP pour ne plus recevoir de messages.",
+          example: { body_text: [["Bonjour Marie, c'est Paul, l'auteur de « Mon livre ». Merci d'avoir lu l'extrait !"]] },
         },
       ],
     }),
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : modèle WhatsApp corrigé"
