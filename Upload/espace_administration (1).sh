#!/bin/bash
# Espace Administration (propriétaire) : auteurs, acheteurs, contacts, reversements, suspension de comptes
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/components/DashboardShell.js b/components/DashboardShell.js
index 2864785..5ff13dd 100644
--- a/components/DashboardShell.js
+++ b/components/DashboardShell.js
@@ -2,7 +2,7 @@ import Link from "next/link";
 import { useRouter } from "next/router";
 import {
   BookOpen, FileText, Users, Store, Settings, CreditCard,
-  Sparkles, Wallet, Mail, Lock, LogOut,
+  Sparkles, Wallet, Mail, Lock, LogOut, ShieldCheck,
 } from "lucide-react";
 import { colors } from "./ui";
 import { clearToken } from "../lib/apiClient";
@@ -19,6 +19,9 @@ const NAV_ITEMS = [
   { id: "abonnement", label: "Abonnement", icon: CreditCard, href: "/dashboard/abonnement" },
 ];
 
+// Visible uniquement pour le propriétaire de la plateforme.
+const ADMIN_ITEM = { id: "admin", label: "Administration", icon: ShieldCheck, href: "/dashboard/admin" };
+
 export default function DashboardShell({ active, author, children }) {
   const router = useRouter();
 
@@ -48,7 +51,7 @@ export default function DashboardShell({ active, author, children }) {
 
         <div className="relative md:static">
           <nav className="flex md:flex-col gap-1 overflow-x-auto md:overflow-visible px-3 pb-3 md:pb-4 no-scrollbar">
-            {NAV_ITEMS.map((item) => {
+            {[...NAV_ITEMS, ...(author?.isAdmin ? [ADMIN_ITEM] : [])].map((item) => {
               const Icon = item.icon;
               const isActive = active === item.id;
               return (
diff --git a/lib/admin.js b/lib/admin.js
new file mode 100644
index 0000000..b02fb64
--- /dev/null
+++ b/lib/admin.js
@@ -0,0 +1,31 @@
+import { requireAuth } from "./auth";
+import { prisma } from "./db";
+
+// Espace propriétaire : réservé aux adresses listées dans la variable
+// ADMIN_EMAILS (séparées par des virgules). Par défaut : l'adresse du
+// fondateur. Le compte doit aussi avoir son email vérifié.
+export function adminEmails() {
+  const raw = process.env.ADMIN_EMAILS || "ludovicbiaka@gmail.com";
+  return raw.split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
+}
+
+export function isAdminAuthor(author) {
+  return Boolean(author && author.emailVerified && adminEmails().includes(String(author.email).toLowerCase()));
+}
+
+// Protège une route API réservée au propriétaire. Pour tout autre
+// utilisateur, la route répond "introuvable" (on ne révèle pas son existence).
+export function requireAdmin(handler) {
+  return requireAuth(async (req, res) => {
+    const author = await prisma.author.findUnique({
+      where: { id: req.authorId },
+      select: { id: true, email: true, emailVerified: true },
+    });
+    if (!isAdminAuthor(author)) return res.status(404).json({ error: "Introuvable" });
+    req.admin = author;
+    return handler(req, res);
+  });
+}
+
+// Prix des abonnements Plume, pour estimer le revenu mensuel récurrent.
+export const PLAN_PRICES = { AFRIQUE_FCFA: 3900, EUROPE_EUR: 5.99 };
diff --git a/lib/auth.js b/lib/auth.js
index 4f991c8..e62f728 100644
--- a/lib/auth.js
+++ b/lib/auth.js
@@ -1,5 +1,6 @@
 import bcrypt from "bcryptjs";
 import jwt from "jsonwebtoken";
+import { prisma } from "./db";
 
 const JWT_SECRET = process.env.JWT_SECRET;
 
@@ -34,6 +35,16 @@ export function requireAuth(handler) {
     const payload = verifyToken(token);
     if (!payload) return res.status(401).json({ error: "Token invalide ou expiré" });
 
+    // Un compte suspendu perd l'accès immédiatement, même avec un token encore valide.
+    const account = await prisma.author.findUnique({
+      where: { id: payload.authorId },
+      select: { suspended: true },
+    });
+    if (!account) return res.status(401).json({ error: "Compte introuvable" });
+    if (account.suspended) {
+      return res.status(403).json({ error: "Ce compte est suspendu. Contactez le support.", suspended: true });
+    }
+
     req.authorId = payload.authorId;
     return handler(req, res);
   };
diff --git a/pages/api/admin/authors/[id].js b/pages/api/admin/authors/[id].js
new file mode 100644
index 0000000..e5705d8
--- /dev/null
+++ b/pages/api/admin/authors/[id].js
@@ -0,0 +1,36 @@
+import { requireAdmin, isAdminAuthor } from "../../../../lib/admin";
+import { prisma } from "../../../../lib/db";
+
+// Suspend ou réactive un compte auteur.
+// Un compte suspendu ne peut plus se connecter, et ses pages publiques
+// (vente, extrait, boutique) ne sont plus accessibles.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "PATCH") return res.status(405).end();
+
+  try {
+    const { id } = req.query;
+    if (typeof req.body?.suspended !== "boolean") {
+      return res.status(400).json({ error: "Paramètre « suspended » requis." });
+    }
+
+    const target = await prisma.author.findUnique({
+      where: { id },
+      select: { id: true, email: true, emailVerified: true },
+    });
+    if (!target) return res.status(404).json({ error: "Auteur introuvable" });
+
+    if (req.body.suspended && (target.id === req.admin.id || isAdminAuthor(target))) {
+      return res.status(400).json({ error: "Impossible de suspendre un compte administrateur." });
+    }
+
+    const updated = await prisma.author.update({
+      where: { id },
+      data: { suspended: req.body.suspended, suspendedAt: req.body.suspended ? new Date() : null },
+      select: { id: true, suspended: true, suspendedAt: true },
+    });
+    return res.status(200).json(updated);
+  } catch (error) {
+    console.error("Erreur PATCH /api/admin/authors/[id] :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/authors/index.js b/pages/api/admin/authors/index.js
new file mode 100644
index 0000000..00fea04
--- /dev/null
+++ b/pages/api/admin/authors/index.js
@@ -0,0 +1,60 @@
+import { requireAdmin, isAdminAuthor } from "../../../../lib/admin";
+import { prisma } from "../../../../lib/db";
+
+// Liste de tous les auteurs avec leur activité et leurs revenus.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const [authors, purchases, leads, payouts] = await Promise.all([
+      prisma.author.findMany({
+        orderBy: { createdAt: "desc" },
+        select: {
+          id: true, name: true, email: true, emailVerified: true, region: true,
+          createdAt: true, subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
+          suspended: true, suspendedAt: true,
+          _count: { select: { books: true } },
+        },
+      }),
+      prisma.purchase.groupBy({
+        by: ["authorId", "currency"],
+        where: { status: "paid" },
+        _sum: { amountCents: true },
+        _count: { _all: true },
+      }),
+      prisma.lead.groupBy({ by: ["authorId", "source"], _count: { _all: true } }),
+      prisma.payout.groupBy({ by: ["authorId", "status", "currency"], _sum: { amountCents: true } }),
+    ]);
+
+    const rows = authors.map((a) => ({
+      id: a.id,
+      name: a.name,
+      email: a.email,
+      emailVerified: a.emailVerified,
+      region: a.region,
+      createdAt: a.createdAt,
+      subscriptionStatus: a.subscriptionStatus,
+      trialEndsAt: a.trialEndsAt,
+      currentPeriodEnd: a.currentPeriodEnd,
+      suspended: a.suspended,
+      suspendedAt: a.suspendedAt,
+      isAdmin: isAdminAuthor(a),
+      books: a._count.books,
+      extractContacts: leads.find((l) => l.authorId === a.id && l.source === "extrait")?._count._all || 0,
+      sales: purchases
+        .filter((p) => p.authorId === a.id)
+        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0, count: p._count._all })),
+      payoutsPaid: payouts
+        .filter((p) => p.authorId === a.id && p.status === "PAID")
+        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0 })),
+      payoutsPending: payouts
+        .filter((p) => p.authorId === a.id && p.status === "PENDING")
+        .map((p) => ({ currency: p.currency, amountCents: p._sum.amountCents || 0 })),
+    }));
+
+    return res.status(200).json(rows);
+  } catch (error) {
+    console.error("Erreur /api/admin/authors :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/buyers.js b/pages/api/admin/buyers.js
new file mode 100644
index 0000000..9c29a4f
--- /dev/null
+++ b/pages/api/admin/buyers.js
@@ -0,0 +1,41 @@
+import { requireAdmin } from "../../../lib/admin";
+import { prisma } from "../../../lib/db";
+
+// Tous les acheteurs (commandes) de la plateforme, tous auteurs confondus.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const purchases = await prisma.purchase.findMany({
+      orderBy: { createdAt: "desc" },
+      take: 5000,
+      include: {
+        book: { select: { title: true } },
+        author: { select: { id: true, name: true, email: true } },
+      },
+    });
+    return res.status(200).json(
+      purchases.map((p) => ({
+        id: p.id,
+        createdAt: p.createdAt,
+        buyerName: p.buyerName,
+        buyerEmail: p.buyerEmail,
+        buyerWhatsapp: p.buyerWhatsapp || "",
+        shippingAddress: p.shippingAddress,
+        shippingCity: p.shippingCity,
+        shippingPostalCode: p.shippingPostalCode,
+        shippingCountry: p.shippingCountry,
+        amountCents: p.amountCents,
+        currency: p.currency,
+        provider: p.provider,
+        status: p.status,
+        bookTitle: p.book?.title || "",
+        authorName: p.author?.name || "",
+        authorEmail: p.author?.email || "",
+      }))
+    );
+  } catch (error) {
+    console.error("Erreur /api/admin/buyers :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/extract-contacts.js b/pages/api/admin/extract-contacts.js
new file mode 100644
index 0000000..58dac3a
--- /dev/null
+++ b/pages/api/admin/extract-contacts.js
@@ -0,0 +1,34 @@
+import { requireAdmin } from "../../../lib/admin";
+import { prisma } from "../../../lib/db";
+
+// Tous les contacts récoltés via les pages d'extrait, tous auteurs confondus.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const leads = await prisma.lead.findMany({
+      where: { source: "extrait" },
+      orderBy: { createdAt: "desc" },
+      take: 5000,
+      include: {
+        book: { select: { title: true } },
+        author: { select: { id: true, name: true } },
+      },
+    });
+    return res.status(200).json(
+      leads.map((l) => ({
+        id: l.id,
+        createdAt: l.createdAt,
+        firstName: l.firstName,
+        lastName: l.lastName,
+        email: l.email,
+        whatsapp: l.whatsapp,
+        bookTitle: l.book?.title || "",
+        authorName: l.author?.name || "",
+      }))
+    );
+  } catch (error) {
+    console.error("Erreur /api/admin/extract-contacts :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/overview.js b/pages/api/admin/overview.js
new file mode 100644
index 0000000..1c71724
--- /dev/null
+++ b/pages/api/admin/overview.js
@@ -0,0 +1,74 @@
+import { requireAdmin, PLAN_PRICES } from "../../../lib/admin";
+import { prisma } from "../../../lib/db";
+
+// Chiffres clés de la plateforme, pour le tableau de bord propriétaire.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const since = new Date(Date.now() - 30 * 24 * 3600 * 1000);
+
+    const [
+      byStatus, suspended, activeByRegion, recentAuthors,
+      leadsBySource, paidAll, paid30, books, salesPublished, extractPages, payoutGroups,
+    ] = await Promise.all([
+      prisma.author.groupBy({ by: ["subscriptionStatus"], _count: { _all: true } }),
+      prisma.author.count({ where: { suspended: true } }),
+      prisma.author.groupBy({ by: ["region"], where: { subscriptionStatus: "ACTIVE" }, _count: { _all: true } }),
+      prisma.author.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
+      prisma.lead.groupBy({ by: ["source"], _count: { _all: true } }),
+      prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid" }, _sum: { amountCents: true }, _count: { _all: true } }),
+      prisma.purchase.groupBy({ by: ["currency"], where: { status: "paid", createdAt: { gte: since } }, _sum: { amountCents: true }, _count: { _all: true } }),
+      prisma.book.count(),
+      prisma.salesPage.count({ where: { published: true } }),
+      prisma.extractPage.count(),
+      prisma.payout.groupBy({ by: ["status", "currency"], _sum: { amountCents: true }, _count: { _all: true } }),
+    ]);
+
+    const statusCount = Object.fromEntries(byStatus.map((g) => [g.subscriptionStatus, g._count._all]));
+    const totalAuthors = byStatus.reduce((n, g) => n + g._count._all, 0);
+
+    // Inscriptions par jour sur 30 jours
+    const days = [];
+    for (let i = 29; i >= 0; i--) {
+      const d = new Date(Date.now() - i * 24 * 3600 * 1000);
+      days.push({ date: d.toISOString().slice(0, 10), count: 0 });
+    }
+    const idx = Object.fromEntries(days.map((d, i) => [d.date, i]));
+    for (const a of recentAuthors) {
+      const k = a.createdAt.toISOString().slice(0, 10);
+      if (k in idx) days[idx[k]].count += 1;
+    }
+
+    const activeAf = activeByRegion.find((g) => g.region === "AFRIQUE")?._count._all || 0;
+    const activeEu = activeByRegion.find((g) => g.region === "EUROPE")?._count._all || 0;
+
+    const leadCount = (src) => leadsBySource.find((g) => g.source === src)?._count._all || 0;
+    const money = (rows) => rows.map((g) => ({ currency: g.currency, amountCents: g._sum.amountCents || 0, count: g._count._all }));
+    const payoutBy = (status) => payoutGroups.filter((g) => g.status === status).map((g) => ({ currency: g.currency, amountCents: g._sum.amountCents || 0, count: g._count._all }));
+
+    return res.status(200).json({
+      authors: {
+        total: totalAuthors,
+        active: statusCount.ACTIVE || 0,
+        trialing: statusCount.TRIALING || 0,
+        pastDue: statusCount.PAST_DUE || 0,
+        canceled: statusCount.CANCELED || 0,
+        suspended,
+        last30: recentAuthors.length,
+      },
+      signupsByDay: days,
+      subscriptionRevenueMonthly: {
+        fcfa: activeAf * PLAN_PRICES.AFRIQUE_FCFA,
+        eur: Math.round(activeEu * PLAN_PRICES.EUROPE_EUR * 100) / 100,
+      },
+      sales: { total: money(paidAll), last30: money(paid30) },
+      contacts: { extract: leadCount("extrait"), buyers: leadCount("acheteur") },
+      catalog: { books, salesPublished, extractPages },
+      payouts: { pending: payoutBy("PENDING"), paid: payoutBy("PAID"), failed: payoutBy("FAILED") },
+    });
+  } catch (error) {
+    console.error("Erreur /api/admin/overview :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/admin/payouts.js b/pages/api/admin/payouts.js
new file mode 100644
index 0000000..35b6eac
--- /dev/null
+++ b/pages/api/admin/payouts.js
@@ -0,0 +1,33 @@
+import { requireAdmin } from "../../../lib/admin";
+import { prisma } from "../../../lib/db";
+
+// Toutes les demandes de reversement des auteurs.
+export default requireAdmin(async function handler(req, res) {
+  if (req.method !== "GET") return res.status(405).end();
+
+  try {
+    const payouts = await prisma.payout.findMany({
+      orderBy: { createdAt: "desc" },
+      take: 2000,
+      include: { author: { select: { id: true, name: true, email: true, momoOperator: true, momoNumber: true } } },
+    });
+    return res.status(200).json(
+      payouts.map((p) => ({
+        id: p.id,
+        createdAt: p.createdAt,
+        dueBy: p.dueBy,
+        processedAt: p.processedAt,
+        amountCents: p.amountCents,
+        currency: p.currency,
+        method: p.method,
+        status: p.status,
+        authorName: p.author?.name || "",
+        authorEmail: p.author?.email || "",
+        momo: p.author?.momoNumber ? `${p.author.momoOperator || ""} ${p.author.momoNumber}`.trim() : "",
+      }))
+    );
+  } catch (error) {
+    console.error("Erreur /api/admin/payouts :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/auth/login.js b/pages/api/auth/login.js
index 50e1ca4..13d92c4 100644
--- a/pages/api/auth/login.js
+++ b/pages/api/auth/login.js
@@ -15,6 +15,10 @@ export default async function handler(req, res) {
   const valid = await verifyPassword(password, author.passwordHash);
   if (!valid) return res.status(401).json({ error: "Identifiants invalides" });
 
+  if (author.suspended) {
+    return res.status(403).json({ error: "Ce compte est suspendu. Contactez le support." });
+  }
+
   const token = signToken({ authorId: author.id });
   return res.status(200).json({
     token,
diff --git a/pages/api/authors/me.js b/pages/api/authors/me.js
index cb6fb7f..190581f 100644
--- a/pages/api/authors/me.js
+++ b/pages/api/authors/me.js
@@ -1,5 +1,6 @@
 import { requireAuth } from "../../../lib/auth";
 import { prisma } from "../../../lib/db";
+import { isAdminAuthor } from "../../../lib/admin";
 
 export default requireAuth(async function handler(req, res) {
   if (req.method !== "GET") return res.status(405).end();
@@ -13,5 +14,5 @@ export default requireAuth(async function handler(req, res) {
       momoOperator: true, momoNumber: true,
     },
   });
-  return res.status(200).json(author);
+  return res.status(200).json({ ...author, isAdmin: isAdminAuthor(author) });
 });
diff --git a/pages/api/checkout/create.js b/pages/api/checkout/create.js
index 637bb24..17059d2 100644
--- a/pages/api/checkout/create.js
+++ b/pages/api/checkout/create.js
@@ -44,7 +44,7 @@ export default async function handler(req, res) {
     where: { slug },
     include: { book: { include: { author: true } } },
   });
-  if (!salesPage || !salesPage.published) {
+  if (!salesPage || !salesPage.published || salesPage.book.author.suspended) {
     return res.status(404).json({ error: "Page de vente introuvable ou non publiée" });
   }
 
diff --git a/pages/api/leads/capture.js b/pages/api/leads/capture.js
index 2bea5e9..e61c2f1 100644
--- a/pages/api/leads/capture.js
+++ b/pages/api/leads/capture.js
@@ -32,9 +32,9 @@ export default async function handler(req, res) {
 
   const extractPage = await prisma.extractPage.findUnique({
     where: { slug },
-    include: { book: true },
+    include: { book: { include: { author: { select: { suspended: true } } } } },
   });
-  if (!extractPage) return res.status(404).json({ error: "Page introuvable" });
+  if (!extractPage || extractPage.book.author?.suspended) return res.status(404).json({ error: "Page introuvable" });
 
   await prisma.lead.create({
     data: {
diff --git a/pages/boutique/[slug].js b/pages/boutique/[slug].js
index 48e9414..1a819c8 100644
--- a/pages/boutique/[slug].js
+++ b/pages/boutique/[slug].js
@@ -16,7 +16,7 @@ export async function getServerSideProps({ params }) {
     },
   });
 
-  if (!author) return { notFound: true };
+  if (!author || author.suspended) return { notFound: true };
 
   const books = author.books
     .filter((b) => b.salesPage?.published)
diff --git a/pages/dashboard/admin.js b/pages/dashboard/admin.js
new file mode 100644
index 0000000..46ed1d2
--- /dev/null
+++ b/pages/dashboard/admin.js
@@ -0,0 +1,361 @@
+import { useEffect, useMemo, useState } from "react";
+import { Download, Search, ShieldAlert, ShieldCheck, Users, Wallet, BookOpen, Mail, TrendingUp } from "lucide-react";
+import DashboardShell from "../../components/DashboardShell";
+import { colors, ErrorBanner, Spinner } from "../../components/ui";
+import { useAuthGuard } from "../../lib/useAuthGuard";
+import { api } from "../../lib/apiClient";
+
+// ---------- Outils d'affichage ----------
+
+function fmtMoney(cents, currency) {
+  const amount = (cents || 0) / 100;
+  if (currency === "EUR") return `${amount.toFixed(2).replace(".", ",")} €`;
+  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
+}
+
+function fmtMoneyList(rows) {
+  const list = (rows || []).filter((r) => r.amountCents > 0);
+  if (list.length === 0) return "—";
+  return list.map((r) => fmtMoney(r.amountCents, r.currency)).join(" + ");
+}
+
+function fmtDate(d) {
+  if (!d) return "—";
+  return new Date(d).toLocaleDateString("fr-FR", { day: "2-digit", month: "short", year: "numeric" });
+}
+
+const SUB_LABELS = {
+  TRIALING: { label: "Essai", bg: "rgba(91,127,166,0.18)", fg: "#3E5F85" },
+  ACTIVE: { label: "Abonné", bg: "rgba(79,122,92,0.18)", fg: "#2F5A3D" },
+  PAST_DUE: { label: "Impayé", bg: "rgba(201,162,39,0.22)", fg: "#7A5E0B" },
+  CANCELED: { label: "Annulé", bg: "rgba(122,46,59,0.14)", fg: colors.wine },
+};
+
+function Badge({ bg, fg, children }) {
+  return (
+    <span className="inline-block font-mono text-[10px] px-2 py-0.5 rounded-full whitespace-nowrap" style={{ backgroundColor: bg, color: fg }}>
+      {children}
+    </span>
+  );
+}
+
+function downloadCsv(filename, columns, rows) {
+  const esc = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
+  const lines = [columns.map((c) => esc(c.label)).join(";")];
+  for (const r of rows) lines.push(columns.map((c) => esc(c.csv ? c.csv(r) : r[c.key])).join(";"));
+  const blob = new Blob(["﻿" + lines.join("\n")], { type: "text/csv;charset=utf-8" });
+  const url = URL.createObjectURL(blob);
+  const a = document.createElement("a");
+  a.href = url;
+  a.download = filename;
+  a.click();
+  URL.revokeObjectURL(url);
+}
+
+// ---------- Tableau générique (recherche + export) ----------
+
+function DataTable({ title, rows, columns, searchKeys, csvName, empty, extra }) {
+  const [q, setQ] = useState("");
+  const filtered = useMemo(() => {
+    const term = q.trim().toLowerCase();
+    if (!term) return rows;
+    return rows.filter((r) => searchKeys.some((k) => String(r[k] ?? "").toLowerCase().includes(term)));
+  }, [rows, q, searchKeys]);
+
+  return (
+    <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
+      <div className="flex flex-col sm:flex-row sm:items-center gap-3 mb-4">
+        <p className="font-display text-lg flex-1" style={{ color: colors.textPaper }}>
+          {title} <span className="font-mono text-xs" style={{ color: colors.textPaperDim }}>({filtered.length})</span>
+        </p>
+        <div className="flex items-center gap-2 rounded-lg px-3 py-2" style={{ backgroundColor: colors.paperDim }}>
+          <Search size={14} color={colors.textPaperDim} />
+          <input
+            value={q}
+            onChange={(e) => setQ(e.target.value)}
+            placeholder="Rechercher…"
+            className="bg-transparent outline-none font-body text-sm w-40"
+            style={{ color: colors.textPaper }}
+          />
+        </div>
+        <button
+          onClick={() => downloadCsv(csvName, columns, filtered)}
+          className="flex items-center justify-center gap-1.5 font-body text-xs px-3 py-2 rounded-lg"
+          style={{ backgroundColor: colors.gold, color: colors.ink }}
+        >
+          <Download size={13} /> Exporter en CSV
+        </button>
+      </div>
+
+      {filtered.length === 0 ? (
+        <p className="font-body text-sm text-center py-8" style={{ color: colors.textPaperDim }}>{empty}</p>
+      ) : (
+        <div className="overflow-x-auto -mx-1">
+          <table className="w-full text-left font-body text-[13px]" style={{ color: colors.textPaper }}>
+            <thead>
+              <tr>
+                {columns.map((c) => (
+                  <th key={c.label} className="font-mono text-[10px] uppercase tracking-wide px-2 py-2 whitespace-nowrap" style={{ color: colors.textPaperDim, borderBottom: `1px solid ${colors.paperDim}` }}>
+                    {c.label}
+                  </th>
+                ))}
+                {extra && <th style={{ borderBottom: `1px solid ${colors.paperDim}` }} />}
+              </tr>
+            </thead>
+            <tbody>
+              {filtered.map((r) => (
+                <tr key={r.id} style={{ borderBottom: `1px solid ${colors.paperDim}`, opacity: r.suspended ? 0.6 : 1 }}>
+                  {columns.map((c) => (
+                    <td key={c.label} className="px-2 py-2.5 align-top whitespace-nowrap">
+                      {c.render ? c.render(r) : r[c.key] || "—"}
+                    </td>
+                  ))}
+                  {extra && <td className="px-2 py-2.5 align-top whitespace-nowrap text-right">{extra(r)}</td>}
+                </tr>
+              ))}
+            </tbody>
+          </table>
+        </div>
+      )}
+    </div>
+  );
+}
+
+// ---------- Vue d'ensemble ----------
+
+function Stat({ icon: Icon, label, value, sub }) {
+  return (
+    <div className="rounded-2xl p-4 md:p-5" style={{ backgroundColor: colors.paper }}>
+      <div className="flex items-center gap-2 mb-2">
+        <Icon size={14} color={colors.goldDark} />
+        <p className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.textPaperDim }}>{label}</p>
+      </div>
+      <p className="font-display text-2xl leading-tight" style={{ color: colors.textPaper }}>{value}</p>
+      {sub && <p className="font-body text-xs mt-1" style={{ color: colors.textPaperDim }}>{sub}</p>}
+    </div>
+  );
+}
+
+function Overview({ data }) {
+  const a = data.authors;
+  const max = Math.max(1, ...data.signupsByDay.map((d) => d.count));
+  const mrr = data.subscriptionRevenueMonthly;
+  const mrrText = [mrr.fcfa > 0 && `${mrr.fcfa.toLocaleString("fr-FR")} FCFA`, mrr.eur > 0 && `${mrr.eur.toFixed(2).replace(".", ",")} €`].filter(Boolean).join(" + ") || "0";
+  return (
+    <div className="space-y-4">
+      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
+        <Stat icon={Users} label="Auteurs inscrits" value={a.total} sub={`+${a.last30} ces 30 jours`} />
+        <Stat icon={ShieldCheck} label="Abonnés actifs" value={a.active} sub={`${a.trialing} en essai · ${a.pastDue} impayé · ${a.canceled} annulé`} />
+        <Stat icon={TrendingUp} label="Revenu mensuel récurrent" value={mrrText} sub="Abonnements Plume actifs" />
+        <Stat icon={ShieldAlert} label="Comptes suspendus" value={a.suspended} />
+        <Stat icon={Wallet} label="Ventes de livres (total)" value={fmtMoneyList(data.sales.total)} sub={`${data.sales.total.reduce((n, s) => n + s.count, 0)} commandes payées`} />
+        <Stat icon={Wallet} label="Ventes (30 jours)" value={fmtMoneyList(data.sales.last30)} sub={`${data.sales.last30.reduce((n, s) => n + s.count, 0)} commandes`} />
+        <Stat icon={Mail} label="Contacts d’extrait" value={data.contacts.extract} sub={`${data.contacts.buyers} contacts acheteurs`} />
+        <Stat icon={BookOpen} label="Livres" value={data.catalog.books} sub={`${data.catalog.salesPublished} en vente · ${data.catalog.extractPages} pages d’extrait`} />
+      </div>
+
+      <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
+        <p className="font-display text-lg mb-4" style={{ color: colors.textPaper }}>Inscriptions d’auteurs — 30 derniers jours</p>
+        <div className="flex items-end gap-1 h-28">
+          {data.signupsByDay.map((d) => (
+            <div key={d.date} className="flex-1 flex flex-col justify-end h-full" title={`${fmtDate(d.date)} : ${d.count}`}>
+              <div style={{ height: `${(d.count / max) * 100}%`, minHeight: d.count ? 4 : 2, backgroundColor: d.count ? colors.gold : colors.paperDim, borderRadius: 3 }} />
+            </div>
+          ))}
+        </div>
+      </div>
+
+      <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
+        <p className="font-display text-lg mb-3" style={{ color: colors.textPaper }}>Reversements aux auteurs</p>
+        <div className="grid sm:grid-cols-3 gap-3 font-body text-sm" style={{ color: colors.textPaper }}>
+          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>En attente</p>{fmtMoneyList(data.payouts.pending)}</div>
+          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>Versés</p>{fmtMoneyList(data.payouts.paid)}</div>
+          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>Échoués</p>{fmtMoneyList(data.payouts.failed)}</div>
+        </div>
+      </div>
+    </div>
+  );
+}
+
+// ---------- Page ----------
+
+const TABS = [
+  { id: "overview", label: "Vue d’ensemble" },
+  { id: "authors", label: "Auteurs" },
+  { id: "buyers", label: "Acheteurs" },
+  { id: "extract", label: "Contacts d’extrait" },
+  { id: "payouts", label: "Reversements" },
+];
+
+export default function DashboardAdmin() {
+  const { author, loading: authLoading } = useAuthGuard();
+  const [tab, setTab] = useState("overview");
+  const [data, setData] = useState({});
+  const [loadingTab, setLoadingTab] = useState(false);
+  const [error, setError] = useState("");
+  const [busyId, setBusyId] = useState("");
+
+  const endpoints = { overview: "/api/admin/overview", authors: "/api/admin/authors", buyers: "/api/admin/buyers", extract: "/api/admin/extract-contacts", payouts: "/api/admin/payouts" };
+
+  async function load(which) {
+    setLoadingTab(true);
+    setError("");
+    try {
+      const res = await api(endpoints[which]);
+      setData((d) => ({ ...d, [which]: res }));
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setLoadingTab(false);
+    }
+  }
+
+  useEffect(() => {
+    if (author?.isAdmin) load(tab);
+    // eslint-disable-next-line react-hooks/exhaustive-deps
+  }, [author, tab]);
+
+  async function toggleSuspend(a) {
+    const next = !a.suspended;
+    const msg = next
+      ? `Suspendre le compte de ${a.name} (${a.email}) ?\n\nL’auteur ne pourra plus se connecter et ses pages publiques (vente, extrait, boutique) seront désactivées. Ses données sont conservées.`
+      : `Réactiver le compte de ${a.name} ?`;
+    if (!window.confirm(msg)) return;
+    setBusyId(a.id);
+    setError("");
+    try {
+      await api(`/api/admin/authors/${a.id}`, { method: "PATCH", body: { suspended: next } });
+      await load("authors");
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setBusyId("");
+    }
+  }
+
+  const colsAuthors = [
+    { label: "Auteur", key: "name", render: (r) => (<><span className="font-semibold">{r.name}</span><br /><span className="text-[11px]" style={{ color: colors.textPaperDim }}>{r.email}</span></>), csv: (r) => r.name },
+    { label: "Email", key: "email", render: () => null, csv: (r) => r.email, hidden: true },
+    { label: "Inscrit le", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
+    { label: "Zone", key: "region", render: (r) => (r.region === "EUROPE" ? "Europe" : "Afrique") },
+    {
+      label: "Abonnement", key: "subscriptionStatus",
+      render: (r) => {
+        const s = SUB_LABELS[r.subscriptionStatus] || SUB_LABELS.TRIALING;
+        return <Badge bg={s.bg} fg={s.fg}>{s.label}</Badge>;
+      },
+      csv: (r) => (SUB_LABELS[r.subscriptionStatus] || {}).label,
+    },
+    { label: "Email vérifié", key: "emailVerified", render: (r) => (r.emailVerified ? "Oui" : "Non"), csv: (r) => (r.emailVerified ? "Oui" : "Non") },
+    { label: "Livres", key: "books" },
+    { label: "Contacts extrait", key: "extractContacts" },
+    { label: "Ventes", key: "sales", render: (r) => `${r.sales.reduce((n, s) => n + s.count, 0)} · ${fmtMoneyList(r.sales)}`, csv: (r) => `${r.sales.reduce((n, s) => n + s.count, 0)} commandes — ${fmtMoneyList(r.sales)}` },
+    { label: "Reversé", key: "payoutsPaid", render: (r) => fmtMoneyList(r.payoutsPaid), csv: (r) => fmtMoneyList(r.payoutsPaid) },
+    { label: "À reverser", key: "payoutsPending", render: (r) => fmtMoneyList(r.payoutsPending), csv: (r) => fmtMoneyList(r.payoutsPending) },
+    {
+      label: "Statut", key: "suspended",
+      render: (r) => (r.suspended ? <Badge bg="rgba(122,46,59,0.14)" fg={colors.wine}>Suspendu</Badge> : r.isAdmin ? <Badge bg="rgba(201,162,39,0.22)" fg="#7A5E0B">Admin</Badge> : <Badge bg="rgba(79,122,92,0.18)" fg="#2F5A3D">Actif</Badge>),
+      csv: (r) => (r.suspended ? "Suspendu" : "Actif"),
+    },
+  ].filter((c) => !c.hidden);
+
+  const colsBuyers = [
+    { label: "Date", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
+    { label: "Acheteur", key: "buyerName" },
+    { label: "Email", key: "buyerEmail" },
+    { label: "WhatsApp", key: "buyerWhatsapp" },
+    { label: "Livre", key: "bookTitle" },
+    { label: "Auteur", key: "authorName" },
+    { label: "Montant", key: "amountCents", render: (r) => fmtMoney(r.amountCents, r.currency), csv: (r) => fmtMoney(r.amountCents, r.currency) },
+    { label: "Statut", key: "status", render: (r) => ({ paid: "Payé", pending: "En attente", failed: "Échoué" }[r.status] || r.status), csv: (r) => r.status },
+    { label: "Livraison", key: "shippingAddress", render: (r) => `${r.shippingAddress}, ${r.shippingPostalCode} ${r.shippingCity}, ${r.shippingCountry}`, csv: (r) => `${r.shippingAddress}, ${r.shippingPostalCode} ${r.shippingCity}, ${r.shippingCountry}` },
+  ];
+
+  const colsExtract = [
+    { label: "Date", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
+    { label: "Prénom", key: "firstName" },
+    { label: "Nom", key: "lastName" },
+    { label: "Email", key: "email" },
+    { label: "WhatsApp", key: "whatsapp" },
+    { label: "Livre", key: "bookTitle" },
+    { label: "Auteur", key: "authorName" },
+  ];
+
+  const colsPayouts = [
+    { label: "Demandé le", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
+    { label: "Auteur", key: "authorName" },
+    { label: "Email", key: "authorEmail" },
+    { label: "Montant", key: "amountCents", render: (r) => fmtMoney(r.amountCents, r.currency), csv: (r) => fmtMoney(r.amountCents, r.currency) },
+    { label: "Méthode", key: "method", render: (r) => (r.method === "momo" ? `Mobile Money ${r.momo}` : "Stripe"), csv: (r) => (r.method === "momo" ? `Mobile Money ${r.momo}` : "Stripe") },
+    { label: "Statut", key: "status", render: (r) => ({ PENDING: "En attente", PAID: "Versé", FAILED: "Échoué" }[r.status] || r.status), csv: (r) => r.status },
+    { label: "Échéance", key: "dueBy", render: (r) => fmtDate(r.dueBy), csv: (r) => fmtDate(r.dueBy) },
+    { label: "Traité le", key: "processedAt", render: (r) => fmtDate(r.processedAt), csv: (r) => fmtDate(r.processedAt) },
+  ];
+
+  const current = data[tab];
+
+  return (
+    <DashboardShell active="admin" author={author}>
+      <header className="mb-6">
+        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Propriétaire</p>
+        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Administration</h1>
+      </header>
+
+      {authLoading ? (
+        <Spinner color={colors.gold} />
+      ) : !author?.isAdmin ? (
+        <p className="font-body text-sm" style={{ color: colors.mist }}>Page introuvable.</p>
+      ) : (
+        <>
+          <div className="flex gap-2 overflow-x-auto no-scrollbar mb-5">
+            {TABS.map((t) => (
+              <button
+                key={t.id}
+                onClick={() => setTab(t.id)}
+                className="font-body text-sm font-semibold px-4 py-2 rounded-full whitespace-nowrap"
+                style={{ backgroundColor: tab === t.id ? colors.gold : colors.paperDim, color: colors.textPaper }}
+              >
+                {t.label}
+              </button>
+            ))}
+          </div>
+
+          <div className="mb-3"><ErrorBanner message={error} /></div>
+
+          {!current && loadingTab ? (
+            <Spinner color={colors.gold} />
+          ) : !current ? null : tab === "overview" ? (
+            <Overview data={current} />
+          ) : tab === "authors" ? (
+            <DataTable
+              title="Auteurs"
+              rows={current}
+              columns={colsAuthors}
+              searchKeys={["name", "email"]}
+              csvName="auteurs-plume.csv"
+              empty="Aucun auteur."
+              extra={(r) =>
+                r.isAdmin ? null : (
+                  <button
+                    disabled={busyId === r.id}
+                    onClick={() => toggleSuspend(r)}
+                    className="font-body text-xs px-3 py-1.5 rounded-lg"
+                    style={r.suspended ? { backgroundColor: colors.forest, color: colors.paper } : { color: colors.wine, border: `1px solid ${colors.wine}` }}
+                  >
+                    {r.suspended ? "Réactiver" : "Suspendre"}
+                  </button>
+                )
+              }
+            />
+          ) : tab === "buyers" ? (
+            <DataTable title="Acheteurs" rows={current} columns={colsBuyers} searchKeys={["buyerName", "buyerEmail", "bookTitle", "authorName"]} csvName="acheteurs-plume.csv" empty="Aucun acheteur pour l’instant." />
+          ) : tab === "extract" ? (
+            <DataTable title="Contacts d’extrait" rows={current} columns={colsExtract} searchKeys={["firstName", "lastName", "email", "bookTitle", "authorName"]} csvName="contacts-extraits-plume.csv" empty="Aucun contact d’extrait pour l’instant." />
+          ) : (
+            <DataTable title="Reversements" rows={current} columns={colsPayouts} searchKeys={["authorName", "authorEmail"]} csvName="reversements-plume.csv" empty="Aucune demande de reversement." />
+          )}
+        </>
+      )}
+    </DashboardShell>
+  );
+}
diff --git a/pages/e/[slug].js b/pages/e/[slug].js
index 286e30b..49b6f57 100644
--- a/pages/e/[slug].js
+++ b/pages/e/[slug].js
@@ -35,7 +35,7 @@ export async function getServerSideProps({ params, req }) {
     include: { book: { include: { author: true } } },
   });
 
-  if (!extractPage) {
+  if (!extractPage || extractPage.book.author.suspended) {
     return { notFound: true };
   }
 
diff --git a/pages/p/[slug].js b/pages/p/[slug].js
index 8615fb0..a762fb5 100644
--- a/pages/p/[slug].js
+++ b/pages/p/[slug].js
@@ -13,7 +13,7 @@ export async function getServerSideProps({ params, req }) {
     include: { book: { include: { author: true } } },
   });
 
-  if (!salesPage || !salesPage.published) {
+  if (!salesPage || !salesPage.published || salesPage.book.author.suspended) {
     return { notFound: true };
   }
 
diff --git a/prisma/schema.prisma b/prisma/schema.prisma
index b3f9d4a..0f63928 100644
--- a/prisma/schema.prisma
+++ b/prisma/schema.prisma
@@ -51,6 +51,10 @@ model Author {
   // Vitrine publique listant tous les livres publiés de l'auteur (Ma boutique)
   storeSlug          String?             @unique
 
+  // Suspension par le propriétaire de la plateforme (espace Administration)
+  suspended          Boolean             @default(false)
+  suspendedAt        DateTime?
+
   books              Book[]
   leads              Lead[]
   purchases          Purchase[]
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : appliquez d'abord les scripts précédents (gerer_extraits.sh, pages_vente_boutique.sh, page_extrait_elegante.sh, grande_couverture.sh, correctif_extrait.sh), puis relancez celui-ci."
  rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : espace Administration ajouté"
