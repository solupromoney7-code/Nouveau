#!/bin/bash
# Administration : bouton "Supprimer" pour effacer définitivement un auteur
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/pages/api/admin/authors/[id].js b/pages/api/admin/authors/[id].js
index e71a2b9..d71606b 100644
--- a/pages/api/admin/authors/[id].js
+++ b/pages/api/admin/authors/[id].js
@@ -5,6 +5,7 @@ import { prisma } from "../../../../lib/db";
 // Un compte suspendu ne peut plus se connecter, et ses pages publiques
 // (vente, extrait, boutique) ne sont plus accessibles.
 export default requireAdmin(async function handler(req, res) {
+  if (req.method === "DELETE") return handleDelete(req, res);
   if (req.method !== "PATCH") return res.status(405).end();
 
   try {
@@ -46,3 +47,54 @@ export default requireAdmin(async function handler(req, res) {
     return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
   }
 });
+
+// Suppression DÉFINITIVE d'un compte auteur et de toutes ses données.
+// Garde-fous : jamais un administrateur ni soi-même, l'email doit être
+// retapé pour confirmer, et on refuse si de l'argent est en jeu (vente payée
+// ou reversement) — ces traces comptables doivent être conservées ; on
+// suspend alors le compte à la place.
+async function handleDelete(req, res) {
+  try {
+    const { id } = req.query;
+    const target = await prisma.author.findUnique({ where: { id }, select: { id: true, email: true } });
+    if (!target) return res.status(404).json({ error: "Auteur introuvable" });
+
+    if (target.id === req.admin.id || isAdminAuthor(target)) {
+      return res.status(400).json({ error: "Impossible de supprimer un compte administrateur." });
+    }
+    if (String(req.body?.confirmEmail || "").trim().toLowerCase() !== target.email.toLowerCase()) {
+      return res.status(400).json({ error: "Confirmation incorrecte : retapez l'email exact de l'auteur." });
+    }
+
+    const [paidPurchases, payouts] = await Promise.all([
+      prisma.purchase.count({ where: { authorId: id, status: "paid" } }),
+      prisma.payout.count({ where: { authorId: id } }),
+    ]);
+    if (paidPurchases > 0 || payouts > 0) {
+      return res.status(409).json({
+        error: "Cet auteur a des ventes payées ou des reversements : suppression refusée pour conserver la comptabilité. Suspendez le compte à la place.",
+      });
+    }
+
+    await prisma.$transaction([
+      prisma.emailSend.deleteMany({ where: { lead: { authorId: id } } }),
+      prisma.whatsAppSend.deleteMany({ where: { lead: { authorId: id } } }),
+      prisma.emailSequenceStep.deleteMany({ where: { sequence: { authorId: id } } }),
+      prisma.emailSequence.deleteMany({ where: { authorId: id } }),
+      prisma.whatsAppSequenceStep.deleteMany({ where: { sequence: { authorId: id } } }),
+      prisma.whatsAppSequence.deleteMany({ where: { authorId: id } }),
+      prisma.broadcast.deleteMany({ where: { authorId: id } }),
+      prisma.lead.deleteMany({ where: { authorId: id } }),
+      prisma.purchase.deleteMany({ where: { authorId: id } }),
+      prisma.salesPage.deleteMany({ where: { book: { authorId: id } } }),
+      prisma.extractPage.deleteMany({ where: { book: { authorId: id } } }),
+      prisma.book.deleteMany({ where: { authorId: id } }),
+      prisma.author.delete({ where: { id } }),
+    ]);
+
+    return res.status(200).json({ ok: true });
+  } catch (error) {
+    console.error("Erreur DELETE /api/admin/authors/[id] :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+}
diff --git a/pages/dashboard/admin.js b/pages/dashboard/admin.js
index 4bdb5e1..c7b0b00 100644
--- a/pages/dashboard/admin.js
+++ b/pages/dashboard/admin.js
@@ -262,6 +262,23 @@ export default function DashboardAdmin() {
     }
   }
 
+  async function deleteAuthor(a) {
+    const typed = window.prompt(
+      `SUPPRESSION DÉFINITIVE de ${a.name} (${a.email}).\n\nSes livres, pages, contacts et tunnels seront effacés. Cette action est irréversible.\n\nPour confirmer, retapez son email :`
+    );
+    if (typed === null) return;
+    setBusyId(a.id);
+    setError("");
+    try {
+      await api(`/api/admin/authors/${a.id}`, { method: "DELETE", body: { confirmEmail: typed } });
+      await load("authors");
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setBusyId("");
+    }
+  }
+
   async function toggleLifetime(a) {
     const next = !a.lifetimeAccess;
     const msg = next
@@ -427,6 +444,16 @@ export default function DashboardAdmin() {
                       {r.suspended ? "Réactiver" : "Suspendre"}
                     </button>
                   )}
+                  {!r.isAdmin && (
+                    <button
+                      disabled={busyId === r.id}
+                      onClick={() => deleteAuthor(r)}
+                      className="font-body text-xs px-3 py-1.5 rounded-lg"
+                      style={{ backgroundColor: "#B3261E", color: "#FFFFFF" }}
+                    >
+                      Supprimer
+                    </button>
+                  )}
                 </div>
               )}
             />
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : suppression d'auteur appliquée"
