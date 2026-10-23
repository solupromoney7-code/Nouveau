#!/bin/bash
# Met à jour les paliers de prix Chariow (3 900 / 5 900 / 7 900 / 9 900 / 15 900)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/lib/chariowTiers.js b/lib/chariowTiers.js
index 718c61f..bed8629 100644
--- a/lib/chariowTiers.js
+++ b/lib/chariowTiers.js
@@ -8,9 +8,11 @@
 // Pour ajouter un palier : créer la variante dans Chariow (Tarification),
 // puis ajouter ici la ligne  prix: "pv_xxxxxxxx".
 export const BOOK_PRICE_VARIANTS = {
-  2000: "pv_cmz2fo91",
-  5000: "pv_k8i2h7en",
-  10000: "pv_3wqnq8la",
+  3900: "pv_cmz2fo91",
+  5900: "pv_k8i2h7en",
+  7900: "pv_g78hzsan",
+  9900: "pv_pte4cigj",
+  15900: "pv_bb4li4ym",
 };
 
 // Liste triée des prix proposés à l'auteur (F CFA).
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : paliers de prix mis à jour"
