#!/bin/bash
# Abonnement : liste complète des fonctionnalités (hooks, scripts, extrait, tunnels)
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/pages/dashboard/abonnement.js b/pages/dashboard/abonnement.js
index 4aa55d9..4a29989 100644
--- a/pages/dashboard/abonnement.js
+++ b/pages/dashboard/abonnement.js
@@ -7,7 +7,7 @@ import { useAuthGuard } from "../../lib/useAuthGuard";
 import { api } from "../../lib/apiClient";
 import { COUNTRY_CODES } from "../../lib/countryCodes";
 
-const FEATURES = ["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 30 jours"];
+const FEATURES = ["Pages de vente illimitées", "Pages d’extrait avec capture de contacts", "5 hooks et 5 scripts vidéo par chapitre", "20 contenus réseaux / mois", "Tunnels de vente par email", "Essai gratuit 30 jours"];
 
 function daysLeft(date) {
   if (!date) return 0;
diff --git a/pages/index.js b/pages/index.js
index 0708454..0076274 100644
--- a/pages/index.js
+++ b/pages/index.js
@@ -173,7 +173,7 @@ export default function Home() {
                 </p>
                 <p className="font-body text-xs mb-5" style={{ color: colors.textMutedLight }}>Paiement {p.pay}</p>
                 <div className="flex flex-col gap-2">
-                  {["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 30 jours"].map((f) => (
+                  {["Pages de vente illimitées", "Pages d’extrait avec capture de contacts", "5 hooks et 5 scripts vidéo par chapitre", "20 contenus réseaux / mois", "Tunnels de vente par email", "Essai gratuit 30 jours"].map((f) => (
                     <div key={f} className="flex items-center gap-2">
                       <Check size={13} color={colors.sageDark} />
                       <p className="font-body text-xs" style={{ color: colors.textPaper }}>{f}</p>
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : liste des fonctionnalités mise à jour"
