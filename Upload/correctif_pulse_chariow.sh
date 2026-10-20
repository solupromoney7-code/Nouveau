#!/bin/bash
# Correctif : le Pulse Chariow accepte les deux écritures du nom d'événement
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/pages/api/webhooks/chariow.js b/pages/api/webhooks/chariow.js
index 848c455..554460a 100644
--- a/pages/api/webhooks/chariow.js
+++ b/pages/api/webhooks/chariow.js
@@ -58,7 +58,9 @@ export default async function handler(req, res) {
     return res.status(400).json({ error: "Payload invalide" });
   }
 
-  const event = payload.event || req.headers["x-pulse-event"];
+  // Chariow écrit les événements "successful.sale" (documentation) ou
+  // "successful_sale" (tableau de bord) : on accepte les deux.
+  const event = String(payload.event || req.headers["x-pulse-event"] || "").replace(/_/g, ".");
   const sale = payload.sale || {};
   const productId = payload.product?.id;
   const customerEmail = (payload.customer?.email || "").toLowerCase();
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : appliquez d'abord connexion_chariow.sh, puis relancez celui-ci."
  rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : correctif appliqué"
