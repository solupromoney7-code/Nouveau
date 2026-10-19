#!/bin/bash
# Liste des pages d extrait + suppression des liens et des livres
set -e
cd "$(git rev-parse --show-toplevel)"
git apply --whitespace=nowarn <<'PLUME_PATCH_EOF'
diff --git a/pages/api/books/[id].js b/pages/api/books/[id].js
index 9eb1e44..a50a734 100644
--- a/pages/api/books/[id].js
+++ b/pages/api/books/[id].js
@@ -37,6 +37,26 @@ export default requireAuth(async function handler(req, res) {
       return res.status(200).json(updated);
     }
 
+    // Suppression d'un livre : retire aussi ses pages (extrait et vente).
+    // Les contacts récoltés sont conservés (simplement détachés du livre).
+    // Un livre déjà acheté ne peut pas être supprimé : l'historique des
+    // ventes et des reversements doit rester intact.
+    if (req.method === "DELETE") {
+      const purchases = await prisma.purchase.count({ where: { bookId: id } });
+      if (purchases > 0) {
+        return res.status(409).json({
+          error: "Ce livre a déjà été acheté : il ne peut pas être supprimé. Vous pouvez supprimer sa page d'extrait ou la dépublier.",
+        });
+      }
+      await prisma.$transaction([
+        prisma.lead.updateMany({ where: { bookId: id }, data: { bookId: null } }),
+        prisma.extractPage.deleteMany({ where: { bookId: id } }),
+        prisma.salesPage.deleteMany({ where: { bookId: id } }),
+        prisma.book.delete({ where: { id } }),
+      ]);
+      return res.status(200).json({ ok: true });
+    }
+
     return res.status(405).end();
   } catch (error) {
     console.error("Erreur /api/books/[id] :", error);
diff --git a/pages/api/extract-pages/[id].js b/pages/api/extract-pages/[id].js
new file mode 100644
index 0000000..7eef6be
--- /dev/null
+++ b/pages/api/extract-pages/[id].js
@@ -0,0 +1,21 @@
+import { requireAuth } from "../../../lib/auth";
+import { prisma } from "../../../lib/db";
+
+// Supprime une page d'extrait (le lien public cesse de fonctionner).
+// Le livre et les contacts déjà récoltés sont conservés.
+export default requireAuth(async function handler(req, res) {
+  if (req.method !== "DELETE") return res.status(405).end();
+
+  try {
+    const { id } = req.query;
+    const page = await prisma.extractPage.findUnique({ where: { id }, include: { book: true } });
+    if (!page || page.book.authorId !== req.authorId) {
+      return res.status(404).json({ error: "Page d'extrait introuvable" });
+    }
+    await prisma.extractPage.delete({ where: { id } });
+    return res.status(200).json({ ok: true });
+  } catch (error) {
+    console.error("Erreur DELETE /api/extract-pages/[id] :", error);
+    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
+  }
+});
diff --git a/pages/api/extract-pages/index.js b/pages/api/extract-pages/index.js
index dbc079d..c234e39 100644
--- a/pages/api/extract-pages/index.js
+++ b/pages/api/extract-pages/index.js
@@ -11,6 +11,30 @@ function slugify(title) {
 }
 
 export default requireAuth(async function handler(req, res) {
+  // Liste des pages d'extrait de l'auteur (avec le livre et le nombre de contacts)
+  if (req.method === "GET") {
+    const pages = await prisma.extractPage.findMany({
+      where: { book: { authorId: req.authorId } },
+      orderBy: { createdAt: "desc" },
+      include: { book: { select: { id: true, title: true, coverImageUrl: true } } },
+    });
+    const counts = await prisma.lead.groupBy({
+      by: ["bookId"],
+      where: { authorId: req.authorId, source: "extrait", bookId: { in: pages.map((x) => x.bookId) } },
+      _count: { _all: true },
+    });
+    const byBook = Object.fromEntries(counts.map((c) => [c.bookId, c._count._all]));
+    return res.status(200).json(
+      pages.map((x) => ({
+        id: x.id,
+        slug: x.slug,
+        createdAt: x.createdAt,
+        book: x.book,
+        leadCount: byBook[x.bookId] || 0,
+      }))
+    );
+  }
+
   if (req.method !== "POST") return res.status(405).end();
 
   const { bookId, videoUrl, pdfUrl } = req.body;
diff --git a/pages/dashboard/extrait.js b/pages/dashboard/extrait.js
index 8236bd2..b818661 100644
--- a/pages/dashboard/extrait.js
+++ b/pages/dashboard/extrait.js
@@ -1,6 +1,6 @@
-import { useState } from "react";
+import { useEffect, useState } from "react";
 import { upload } from "@vercel/blob/client";
-import { Upload, Check, Copy, ExternalLink, Loader2, FileText, Video, ImagePlus, Pencil } from "lucide-react";
+import { Upload, Check, Copy, ExternalLink, Loader2, FileText, Video, ImagePlus, Pencil, Trash2, Plus, Users } from "lucide-react";
 import DashboardShell from "../../components/DashboardShell";
 import { colors, BookCover, EditableTitle, ErrorBanner, Spinner } from "../../components/ui";
 import { useAuthGuard } from "../../lib/useAuthGuard";
@@ -28,6 +28,87 @@ function CoverUploadButton({ uploading, onFile }) {
   );
 }
 
+// Liste des pages d'extrait déjà créées : lien à copier / ouvrir, et
+// suppression du lien ou du livre.
+function ExtractPagesList({ pages, authorName, busyId, onDeletePage, onDeleteBook }) {
+  const [copiedId, setCopiedId] = useState("");
+  const origin = typeof window !== "undefined" ? window.location.origin : "";
+
+  return (
+    <section className="mb-8 max-w-3xl">
+      <p className="font-mono text-[11px] uppercase tracking-widest mb-3" style={{ color: colors.gold }}>
+        Vos pages d’extrait ({pages.length})
+      </p>
+      <div className="space-y-3">
+        {pages.map((pg) => {
+          const url = `${origin}/e/${pg.slug}`;
+          const busy = busyId === pg.id;
+          return (
+            <div
+              key={pg.id}
+              className="rounded-2xl p-4 flex flex-col sm:flex-row gap-4"
+              style={{ backgroundColor: colors.paper, opacity: busy ? 0.5 : 1 }}
+            >
+              <div className="shrink-0 self-start">
+                <BookCover title={pg.book.title} author={authorName} imageUrl={pg.book.coverImageUrl} size="sm" />
+              </div>
+              <div className="flex-1 min-w-0">
+                <p className="font-display text-lg leading-snug" style={{ color: colors.textPaper }}>{pg.book.title}</p>
+                <p className="font-mono text-[11px] mt-1 flex items-center gap-1.5" style={{ color: colors.textPaperDim }}>
+                  <Users size={12} /> {pg.leadCount} contact{pg.leadCount > 1 ? "s" : ""} récolté{pg.leadCount > 1 ? "s" : ""}
+                </p>
+                <div
+                  className="mt-3 rounded-lg px-3 py-2 font-mono text-[11px] truncate"
+                  style={{ backgroundColor: colors.paperDim, color: colors.textPaperDim }}
+                >
+                  {url}
+                </div>
+                <div className="flex flex-wrap items-center gap-2 mt-3">
+                  <button
+                    onClick={() => { navigator.clipboard?.writeText(url); setCopiedId(pg.id); setTimeout(() => setCopiedId(""), 1500); }}
+                    className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
+                  >
+                    {copiedId === pg.id ? <Check size={13} /> : <Copy size={13} />} {copiedId === pg.id ? "Copié" : "Copier le lien"}
+                  </button>
+                  <a
+                    href={`/e/${pg.slug}`}
+                    target="_blank"
+                    rel="noreferrer"
+                    className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
+                    style={{ backgroundColor: colors.gold, color: colors.ink }}
+                  >
+                    <ExternalLink size={13} /> Voir la page
+                  </a>
+                  <span className="flex-1" />
+                  <button
+                    disabled={busy}
+                    onClick={() => onDeletePage(pg)}
+                    className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
+                    style={{ color: colors.wine, border: `1px solid ${colors.wine}` }}
+                    title="Le lien ne fonctionnera plus. Le livre et vos contacts sont conservés."
+                  >
+                    <Trash2 size={13} /> Supprimer le lien
+                  </button>
+                  <button
+                    disabled={busy}
+                    onClick={() => onDeleteBook(pg)}
+                    className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
+                    style={{ backgroundColor: colors.wine, color: colors.paper }}
+                    title="Supprime le livre et ses pages."
+                  >
+                    <Trash2 size={13} /> Supprimer le livre
+                  </button>
+                </div>
+              </div>
+            </div>
+          );
+        })}
+      </div>
+    </section>
+  );
+}
+
 export default function DashboardExtrait() {
   const { author, loading: authLoading } = useAuthGuard();
 
@@ -43,6 +124,54 @@ export default function DashboardExtrait() {
   const [copied, setCopied] = useState(false);
   const [coverUploading, setCoverUploading] = useState(false);
   const [titleSaving, setTitleSaving] = useState(false);
+  const [pages, setPages] = useState([]);
+  const [pagesLoaded, setPagesLoaded] = useState(false);
+  const [creating, setCreating] = useState(false);
+  const [busyId, setBusyId] = useState("");
+
+  async function loadPages() {
+    try {
+      const data = await api("/api/extract-pages");
+      setPages(Array.isArray(data) ? data : []);
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setPagesLoaded(true);
+    }
+  }
+
+  useEffect(() => {
+    if (author) loadPages();
+    // eslint-disable-next-line react-hooks/exhaustive-deps
+  }, [author]);
+
+  async function handleDeletePage(pg) {
+    if (!window.confirm(`Supprimer le lien d’extrait de « ${pg.book.title} » ?\n\nLe lien ne fonctionnera plus. Le livre et vos contacts sont conservés.`)) return;
+    setError("");
+    setBusyId(pg.id);
+    try {
+      await api(`/api/extract-pages/${pg.id}`, { method: "DELETE" });
+      await loadPages();
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setBusyId("");
+    }
+  }
+
+  async function handleDeleteBook(pg) {
+    if (!window.confirm(`Supprimer définitivement le livre « ${pg.book.title} » et ses pages ?\n\nVos contacts déjà récoltés sont conservés.`)) return;
+    setError("");
+    setBusyId(pg.id);
+    try {
+      await api(`/api/books/${pg.book.id}`, { method: "DELETE" });
+      await loadPages();
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setBusyId("");
+    }
+  }
 
   async function handleBookFile(e) {
     const file = e.target.files?.[0];
@@ -102,6 +231,7 @@ export default function DashboardExtrait() {
       });
       setExtractPage(data);
       setStage("done");
+      loadPages();
     } catch (err) {
       setError(err.message);
       setStage("idle");
@@ -160,6 +290,12 @@ export default function DashboardExtrait() {
     setVideoUrl("");
     setExtractPage(null);
     setError("");
+    setCreating(false);
+  }
+
+  function startNew() {
+    reset();
+    setCreating(true);
   }
 
   const publicUrl = extractPage
@@ -173,9 +309,23 @@ export default function DashboardExtrait() {
         <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Page d’extrait</h1>
       </header>
 
-      {authLoading ? (
+      {authLoading || !pagesLoaded ? (
         <Spinner color={colors.gold} />
-      ) : stage === "done" && extractPage ? (
+      ) : (
+      <>
+      {pages.length > 0 && (
+        <>
+          {!creating && <ErrorBanner message={error} />}
+          <ExtractPagesList
+            pages={pages}
+            authorName={author?.name || ""}
+            busyId={busyId}
+            onDeletePage={handleDeletePage}
+            onDeleteBook={handleDeleteBook}
+          />
+        </>
+      )}
+      {stage === "done" && extractPage ? (
         <div className="max-w-xl">
           <div
             className="flex items-center justify-between gap-3 rounded-xl px-4 py-3 mb-4 flex-wrap"
@@ -204,12 +354,25 @@ export default function DashboardExtrait() {
               </a>
             </div>
           </div>
-          <button onClick={reset} className="font-body text-xs underline" style={{ color: colors.mist }}>
+          <button onClick={startNew} className="font-body text-xs underline" style={{ color: colors.mist }}>
             Créer une nouvelle page d’extrait
           </button>
         </div>
+      ) : pages.length > 0 && !creating ? (
+        <button
+          onClick={startNew}
+          className="flex items-center gap-2 px-5 py-3 rounded-xl font-body font-semibold text-sm"
+          style={{ backgroundColor: colors.gold, color: colors.ink }}
+        >
+          <Plus size={16} /> Nouvelle page d’extrait
+        </button>
       ) : (
         <div className="rounded-2xl p-6 md:p-10 max-w-xl" style={{ backgroundColor: colors.paper }}>
+          {pages.length > 0 && (
+            <button onClick={reset} className="font-body text-xs underline mb-4 block" style={{ color: colors.textPaperDim }}>
+              ← Retour à mes pages
+            </button>
+          )}
           <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
             Étape 1 sur 2
           </p>
@@ -351,6 +514,8 @@ export default function DashboardExtrait() {
           )}
         </div>
       )}
+      </>
+      )}
     </DashboardShell>
   );
 }
PLUME_PATCH_EOF
echo "OK : gestion des pages d extrait ajoutée"
