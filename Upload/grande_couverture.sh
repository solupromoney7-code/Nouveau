#!/bin/bash
# Grande couverture responsive sur les pages publiques (extrait + vente)
set -e
cd "$(git rev-parse --show-toplevel)"
git apply --whitespace=nowarn <<'PLUME_PATCH_EOF'
diff --git a/components/ui.js b/components/ui.js
index 0840fa8..d5d80e7 100644
--- a/components/ui.js
+++ b/components/ui.js
@@ -32,16 +32,23 @@ export const inputStyle = {
 // une couverture générée (dégradé + titre + auteur) sert de solution de
 // repli élégante.
 export function BookCover({ title, author, imageUrl, size = "md" }) {
+  // "hero" : grande couverture des pages publiques, qui s'adapte à la largeur
+  // de l'écran (grande sur mobile, bien proportionnée sur ordinateur).
+  const hero = size === "hero";
   const dims =
     size === "sm" ? { w: 88, h: 128 } : size === "lg" ? { w: 160, h: 230 } : { w: 120, h: 172 };
+  const boxStyle = hero
+    ? { width: "clamp(190px, 62vw, 240px)", aspectRatio: "5 / 7" }
+    : { width: dims.w, height: dims.h };
+  const heroShadow = hero ? { boxShadow: "0 24px 48px -16px rgba(28,32,51,0.45), 0 8px 16px -8px rgba(28,32,51,0.25)" } : {};
 
   if (imageUrl) {
     return (
       <div
         className="shrink-0 rounded-md overflow-hidden shadow-lg"
         style={{
-          width: dims.w,
-          height: dims.h,
+          ...boxStyle,
+          ...heroShadow,
           border: "1px solid rgba(28,32,51,0.12)",
         }}
       >
@@ -60,14 +67,14 @@ export function BookCover({ title, author, imageUrl, size = "md" }) {
     <div
       className="shrink-0 rounded-md flex flex-col justify-between p-3 shadow-lg"
       style={{
-        width: dims.w,
-        height: dims.h,
+        ...boxStyle,
+        ...heroShadow,
         backgroundImage: `linear-gradient(150deg, ${colors.wine}, ${colors.ink})`,
         border: "1px solid rgba(201,162,39,0.35)",
       }}
     >
       <div className="w-6" style={{ height: 2, backgroundColor: colors.gold }} />
-      <p className="font-display leading-tight" style={{ color: colors.paper, fontSize: size === "sm" ? 12 : 15 }}>
+      <p className="font-display leading-tight" style={{ color: colors.paper, fontSize: size === "sm" ? 12 : hero ? 20 : 15 }}>
         {title}
       </p>
       <p className="font-mono uppercase tracking-wide" style={{ color: colors.mist, fontSize: 9 }}>
diff --git a/pages/e/[slug].js b/pages/e/[slug].js
index 339efcf..ca095c4 100644
--- a/pages/e/[slug].js
+++ b/pages/e/[slug].js
@@ -123,7 +123,7 @@ export default function PublicExtractPage({ page }) {
 
       <main className="max-w-2xl mx-auto px-5 pb-24">
         <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
-          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
+          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
           <div>
             <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
               Extrait gratuit
diff --git a/pages/p/[slug].js b/pages/p/[slug].js
index d468cd8..8233d4a 100644
--- a/pages/p/[slug].js
+++ b/pages/p/[slug].js
@@ -119,7 +119,7 @@ export default function PublicSalesPage({ page }) {
 
       <main className="max-w-3xl mx-auto px-5 pb-24">
         <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
-          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
+          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
           <div>
             <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
               Livre de {page.authorName}
PLUME_PATCH_EOF
echo "OK : couverture agrandie"
