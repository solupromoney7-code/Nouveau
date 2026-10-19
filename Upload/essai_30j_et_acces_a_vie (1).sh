#!/bin/bash
# Essai gratuit de 30 jours + possibilité d'offrir un abonnement à vie
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/components/DashboardShell.js b/components/DashboardShell.js
index 5ff13dd..10dac1b 100644
--- a/components/DashboardShell.js
+++ b/components/DashboardShell.js
@@ -87,7 +87,7 @@ export default function DashboardShell({ active, author, children }) {
           <div className="min-w-0 flex-1">
             <p className="text-sm truncate" style={{ color: colors.paper }}>{author?.name || "…"}</p>
             <p className="font-mono text-[10px]" style={{ color: colors.mist }}>
-              {author?.subscriptionStatus === "TRIALING" ? "Essai gratuit" : author?.subscriptionStatus === "ACTIVE" ? "Abonnement actif" : "Abonnement inactif"}
+              {author?.lifetimeAccess ? "Accès à vie" : author?.subscriptionStatus === "TRIALING" ? "Essai gratuit" : author?.subscriptionStatus === "ACTIVE" ? "Abonnement actif" : "Abonnement inactif"}
             </p>
           </div>
           <button onClick={handleLogout} title="Se déconnecter">
diff --git a/lib/subscription.js b/lib/subscription.js
index a82db74..7eb139b 100644
--- a/lib/subscription.js
+++ b/lib/subscription.js
@@ -3,6 +3,7 @@
 // contenu réseaux, tunnels de vente, broadcasts). Centralisé ici pour que
 // la définition d'"abonnement actif" ne diverge jamais d'un endroit à l'autre.
 export function isSubscriptionActive(author) {
+  if (author.lifetimeAccess) return true; // accès à vie offert par le propriétaire
   const trialActive = author.subscriptionStatus === "TRIALING" && author.trialEndsAt && author.trialEndsAt > new Date();
   return author.subscriptionStatus === "ACTIVE" || trialActive;
 }
diff --git a/pages/api/admin/authors/[id].js b/pages/api/admin/authors/[id].js
index e5705d8..e71a2b9 100644
--- a/pages/api/admin/authors/[id].js
+++ b/pages/api/admin/authors/[id].js
@@ -9,8 +9,20 @@ export default requireAdmin(async function handler(req, res) {
 
   try {
     const { id } = req.query;
+    // Accès à vie : offrir ou retirer (aucun abonnement à payer)
+    if (typeof req.body?.lifetime === "boolean") {
+      const exists = await prisma.author.findUnique({ where: { id }, select: { id: true } });
+      if (!exists) return res.status(404).json({ error: "Auteur introuvable" });
+      const updated = await prisma.author.update({
+        where: { id },
+        data: { lifetimeAccess: req.body.lifetime },
+        select: { id: true, lifetimeAccess: true },
+      });
+      return res.status(200).json(updated);
+    }
+
     if (typeof req.body?.suspended !== "boolean") {
-      return res.status(400).json({ error: "Paramètre « suspended » requis." });
+      return res.status(400).json({ error: "Paramètre « suspended » ou « lifetime » requis." });
     }
 
     const target = await prisma.author.findUnique({
diff --git a/pages/api/admin/authors/index.js b/pages/api/admin/authors/index.js
index 00fea04..bf1c000 100644
--- a/pages/api/admin/authors/index.js
+++ b/pages/api/admin/authors/index.js
@@ -12,7 +12,7 @@ export default requireAdmin(async function handler(req, res) {
         select: {
           id: true, name: true, email: true, emailVerified: true, region: true,
           createdAt: true, subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
-          suspended: true, suspendedAt: true,
+          suspended: true, suspendedAt: true, lifetimeAccess: true,
           _count: { select: { books: true } },
         },
       }),
@@ -36,6 +36,7 @@ export default requireAdmin(async function handler(req, res) {
       subscriptionStatus: a.subscriptionStatus,
       trialEndsAt: a.trialEndsAt,
       currentPeriodEnd: a.currentPeriodEnd,
+      lifetimeAccess: a.lifetimeAccess,
       suspended: a.suspended,
       suspendedAt: a.suspendedAt,
       isAdmin: isAdminAuthor(a),
diff --git a/pages/api/admin/overview.js b/pages/api/admin/overview.js
index 1c71724..f4e89e1 100644
--- a/pages/api/admin/overview.js
+++ b/pages/api/admin/overview.js
@@ -10,12 +10,13 @@ export default requireAdmin(async function handler(req, res) {
 
     const [
       byStatus, suspended, activeByRegion, recentAuthors,
-      leadsBySource, paidAll, paid30, books, salesPublished, extractPages, payoutGroups,
+      lifetimeCount, leadsBySource, paidAll, paid30, books, salesPublished, extractPages, payoutGroups,
     ] = await Promise.all([
       prisma.author.groupBy({ by: ["subscriptionStatus"], _count: { _all: true } }),
       prisma.author.count({ where: { suspended: true } }),
-      prisma.author.groupBy({ by: ["region"], where: { subscriptionStatus: "ACTIVE" }, _count: { _all: true } }),
+      prisma.author.groupBy({ by: ["region"], where: { subscriptionStatus: "ACTIVE", lifetimeAccess: false }, _count: { _all: true } }),
       prisma.author.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
+      prisma.author.count({ where: { lifetimeAccess: true } }),
       prisma.lead.groupBy({ by: ["source"], _count: { _all: true } }),
       prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid" }, _sum: { amountCents: true }, _count: { _all: true } }),
       prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid", createdAt: { gte: since } }, _sum: { amountCents: true }, _count: { _all: true } }),
@@ -55,6 +56,7 @@ export default requireAdmin(async function handler(req, res) {
         pastDue: statusCount.PAST_DUE || 0,
         canceled: statusCount.CANCELED || 0,
         suspended,
+        lifetime: lifetimeCount,
         last30: recentAuthors.length,
       },
       signupsByDay: days,
diff --git a/pages/api/auth/signup.js b/pages/api/auth/signup.js
index f9169de..187afaf 100644
--- a/pages/api/auth/signup.js
+++ b/pages/api/auth/signup.js
@@ -37,7 +37,7 @@ export default async function handler(req, res) {
   if (existing) return res.status(409).json({ error: "Cet email est déjà utilisé" });
 
   const passwordHash = await hashPassword(password);
-  const trialEndsAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // essai gratuit 7 jours
+  const trialEndsAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // essai gratuit 30 jours
 
   const author = await prisma.author.create({
     data: {
diff --git a/pages/api/authors/me.js b/pages/api/authors/me.js
index 190581f..8c7c2f2 100644
--- a/pages/api/authors/me.js
+++ b/pages/api/authors/me.js
@@ -9,7 +9,7 @@ export default requireAuth(async function handler(req, res) {
     where: { id: req.authorId },
     select: {
       id: true, name: true, email: true, region: true, emailVerified: true,
-      subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
+      subscriptionStatus: true, lifetimeAccess: true, trialEndsAt: true, currentPeriodEnd: true,
       stripeAccountId: true, stripeOnboarded: true,
       momoOperator: true, momoNumber: true,
     },
diff --git a/pages/api/cron/process-emails.js b/pages/api/cron/process-emails.js
index 4bf3f14..62961de 100644
--- a/pages/api/cron/process-emails.js
+++ b/pages/api/cron/process-emails.js
@@ -31,7 +31,7 @@ export default async function handler(req, res) {
     where: { active: true },
     include: {
       steps: { orderBy: { order: "asc" } },
-      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true } },
+      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true } },
     },
   });
 
@@ -91,7 +91,7 @@ export default async function handler(req, res) {
     where: { active: true },
     include: {
       steps: { orderBy: { order: "asc" } },
-      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true } },
+      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true } },
     },
   });
 
diff --git a/pages/dashboard/abonnement.js b/pages/dashboard/abonnement.js
index 3fd8195..b70526e 100644
--- a/pages/dashboard/abonnement.js
+++ b/pages/dashboard/abonnement.js
@@ -6,7 +6,7 @@ import { colors, ErrorBanner, Spinner } from "../../components/ui";
 import { useAuthGuard } from "../../lib/useAuthGuard";
 import { api } from "../../lib/apiClient";
 
-const FEATURES = ["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 7 jours"];
+const FEATURES = ["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 30 jours"];
 
 function daysLeft(date) {
   if (!date) return 0;
@@ -17,6 +17,15 @@ function daysLeft(date) {
 function StatusBadge({ author }) {
   const status = author?.subscriptionStatus;
 
+  if (author?.lifetimeAccess) {
+    return (
+      <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
+        <Check size={14} color={colors.forest} />
+        <span className="font-body text-sm" style={{ color: colors.forest }}>Accès à vie — aucun abonnement à payer</span>
+      </div>
+    );
+  }
+
   if (status === "ACTIVE") {
     return (
       <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
@@ -96,8 +105,11 @@ export default function DashboardAbonnement() {
   const isAfrique = author?.region === "AFRIQUE";
   const price = isAfrique ? "3 900 FCFA" : "5,99 €";
   const payMethod = isAfrique ? "Mobile Money" : "Carte bancaire";
-  const active = author?.subscriptionStatus === "ACTIVE";
-  const ctaLabel = active
+  const lifetime = Boolean(author?.lifetimeAccess);
+  const active = author?.subscriptionStatus === "ACTIVE" || lifetime;
+  const ctaLabel = lifetime
+    ? "Accès à vie"
+    : active
     ? "Abonnement actif"
     : author?.subscriptionStatus === "PAST_DUE"
     ? "Régulariser mon paiement"
diff --git a/pages/dashboard/admin.js b/pages/dashboard/admin.js
index 46ed1d2..6b713af 100644
--- a/pages/dashboard/admin.js
+++ b/pages/dashboard/admin.js
@@ -147,7 +147,7 @@ function Overview({ data }) {
         <Stat icon={Users} label="Auteurs inscrits" value={a.total} sub={`+${a.last30} ces 30 jours`} />
         <Stat icon={ShieldCheck} label="Abonnés actifs" value={a.active} sub={`${a.trialing} en essai · ${a.pastDue} impayé · ${a.canceled} annulé`} />
         <Stat icon={TrendingUp} label="Revenu mensuel récurrent" value={mrrText} sub="Abonnements Plume actifs" />
-        <Stat icon={ShieldAlert} label="Comptes suspendus" value={a.suspended} />
+        <Stat icon={ShieldAlert} label="Comptes suspendus" value={a.suspended} sub={`${a.lifetime} accès à vie offerts`} />
         <Stat icon={Wallet} label="Ventes de livres (total)" value={fmtMoneyList(data.sales.total)} sub={`${data.sales.total.reduce((n, s) => n + s.count, 0)} commandes payées`} />
         <Stat icon={Wallet} label="Ventes (30 jours)" value={fmtMoneyList(data.sales.last30)} sub={`${data.sales.last30.reduce((n, s) => n + s.count, 0)} commandes`} />
         <Stat icon={Mail} label="Contacts d’extrait" value={data.contacts.extract} sub={`${data.contacts.buyers} contacts acheteurs`} />
@@ -233,6 +233,24 @@ export default function DashboardAdmin() {
     }
   }
 
+  async function toggleLifetime(a) {
+    const next = !a.lifetimeAccess;
+    const msg = next
+      ? `Offrir un abonnement à vie à ${a.name} (${a.email}) ?\n\nCet auteur aura accès à toutes les fonctionnalités sans jamais payer d’abonnement.`
+      : `Retirer l’accès à vie de ${a.name} ?\n\nSon abonnement redeviendra celui de son compte (essai ou abonnement payant).`;
+    if (!window.confirm(msg)) return;
+    setBusyId(a.id);
+    setError("");
+    try {
+      await api(`/api/admin/authors/${a.id}`, { method: "PATCH", body: { lifetime: next } });
+      await load("authors");
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setBusyId("");
+    }
+  }
+
   const colsAuthors = [
     { label: "Auteur", key: "name", render: (r) => (<><span className="font-semibold">{r.name}</span><br /><span className="text-[11px]" style={{ color: colors.textPaperDim }}>{r.email}</span></>), csv: (r) => r.name },
     { label: "Email", key: "email", render: () => null, csv: (r) => r.email, hidden: true },
@@ -241,10 +259,11 @@ export default function DashboardAdmin() {
     {
       label: "Abonnement", key: "subscriptionStatus",
       render: (r) => {
+        if (r.lifetimeAccess) return <Badge bg="rgba(201,162,39,0.28)" fg="#7A5E0B">À vie</Badge>;
         const s = SUB_LABELS[r.subscriptionStatus] || SUB_LABELS.TRIALING;
         return <Badge bg={s.bg} fg={s.fg}>{s.label}</Badge>;
       },
-      csv: (r) => (SUB_LABELS[r.subscriptionStatus] || {}).label,
+      csv: (r) => (r.lifetimeAccess ? "À vie" : (SUB_LABELS[r.subscriptionStatus] || {}).label),
     },
     { label: "Email vérifié", key: "emailVerified", render: (r) => (r.emailVerified ? "Oui" : "Non"), csv: (r) => (r.emailVerified ? "Oui" : "Non") },
     { label: "Livres", key: "books" },
@@ -334,18 +353,28 @@ export default function DashboardAdmin() {
               searchKeys={["name", "email"]}
               csvName="auteurs-plume.csv"
               empty="Aucun auteur."
-              extra={(r) =>
-                r.isAdmin ? null : (
+              extra={(r) => (
+                <div className="flex items-center justify-end gap-2">
                   <button
                     disabled={busyId === r.id}
-                    onClick={() => toggleSuspend(r)}
+                    onClick={() => toggleLifetime(r)}
                     className="font-body text-xs px-3 py-1.5 rounded-lg"
-                    style={r.suspended ? { backgroundColor: colors.forest, color: colors.paper } : { color: colors.wine, border: `1px solid ${colors.wine}` }}
+                    style={r.lifetimeAccess ? { color: colors.textPaperDim, border: `1px solid ${colors.mist}` } : { backgroundColor: colors.gold, color: colors.ink }}
                   >
-                    {r.suspended ? "Réactiver" : "Suspendre"}
+                    {r.lifetimeAccess ? "Retirer l’accès à vie" : "Offrir à vie"}
                   </button>
-                )
-              }
+                  {!r.isAdmin && (
+                    <button
+                      disabled={busyId === r.id}
+                      onClick={() => toggleSuspend(r)}
+                      className="font-body text-xs px-3 py-1.5 rounded-lg"
+                      style={r.suspended ? { backgroundColor: colors.forest, color: colors.paper } : { color: colors.wine, border: `1px solid ${colors.wine}` }}
+                    >
+                      {r.suspended ? "Réactiver" : "Suspendre"}
+                    </button>
+                  )}
+                </div>
+              )}
             />
           ) : tab === "buyers" ? (
             <DataTable title="Acheteurs" rows={current} columns={colsBuyers} searchKeys={["buyerName", "buyerEmail", "bookTitle", "authorName"]} csvName="acheteurs-plume.csv" empty="Aucun acheteur pour l’instant." />
diff --git a/pages/index.js b/pages/index.js
index 2267db3..b635411 100644
--- a/pages/index.js
+++ b/pages/index.js
@@ -103,7 +103,7 @@ export default function Home() {
                 Créer ma page de vente <ArrowRight size={16} />
               </Link>
               <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
-                Essai gratuit 7 jours — sans engagement
+                Essai gratuit 30 jours — sans engagement
               </p>
             </div>
           </div>
@@ -173,7 +173,7 @@ export default function Home() {
                 </p>
                 <p className="font-body text-xs mb-5" style={{ color: colors.textMutedLight }}>Paiement {p.pay}</p>
                 <div className="flex flex-col gap-2">
-                  {["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 7 jours"].map((f) => (
+                  {["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 30 jours"].map((f) => (
                     <div key={f} className="flex items-center gap-2">
                       <Check size={13} color={colors.sageDark} />
                       <p className="font-body text-xs" style={{ color: colors.textPaper }}>{f}</p>
diff --git a/pages/inscription.js b/pages/inscription.js
index a8dbe68..986751f 100644
--- a/pages/inscription.js
+++ b/pages/inscription.js
@@ -51,7 +51,7 @@ export default function Inscription() {
   return (
     <AuthShell
       title="Créer votre compte"
-      subtitle="7 jours d’essai gratuit, sans carte requise pour découvrir."
+      subtitle="30 jours d’essai gratuit, sans carte requise pour découvrir."
       footer={
         <Link href="/connexion" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
           Déjà un compte ? Se connecter
diff --git a/prisma/schema.prisma b/prisma/schema.prisma
index 0f63928..690a1e5 100644
--- a/prisma/schema.prisma
+++ b/prisma/schema.prisma
@@ -52,6 +52,9 @@ model Author {
   storeSlug          String?             @unique
 
   // Suspension par le propriétaire de la plateforme (espace Administration)
+  // Accès offert à vie par le propriétaire (aucun abonnement à payer)
+  lifetimeAccess     Boolean             @default(false)
+
   suspended          Boolean             @default(false)
   suspendedAt        DateTime?
 
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : ce correctif ne peut pas s'appliquer. Vérifiez que espace_administration.sh a bien été appliqué avant."
  rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : essai de 30 jours et accès à vie ajoutés"
