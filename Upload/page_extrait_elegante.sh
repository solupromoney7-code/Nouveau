#!/bin/bash
# Nouvelle page d extrait : titre en haut, couverture à gauche, formulaire à droite
set -e
cd "$(git rev-parse --show-toplevel)"
git apply --whitespace=nowarn <<'PLUME_PATCH_EOF'
diff --git a/pages/e/[slug].js b/pages/e/[slug].js
index ca095c4..286e30b 100644
--- a/pages/e/[slug].js
+++ b/pages/e/[slug].js
@@ -1,7 +1,7 @@
 import { useState } from "react";
 import Head from "next/head";
 import Link from "next/link";
-import { BookOpen, Download, Loader2, Mail } from "lucide-react";
+import { BookOpen, Check, Download, Loader2, Lock } from "lucide-react";
 import { prisma } from "../../lib/db";
 import { colors, BookCover, ErrorBanner } from "../../components/ui";
 import PublicFooter from "../../components/PublicFooter";
@@ -56,6 +56,7 @@ export async function getServerSideProps({ params, req }) {
 export default function PublicExtractPage({ page }) {
   const [submitted, setSubmitted] = useState(false);
   const [pdfUrl, setPdfUrl] = useState("");
+  const [emailSent, setEmailSent] = useState(false);
   const [submitting, setSubmitting] = useState(false);
   const [error, setError] = useState("");
   const [form, setForm] = useState({
@@ -97,6 +98,7 @@ export default function PublicExtractPage({ page }) {
       const data = await res.json();
       if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
       setPdfUrl(data.pdfUrl || "");
+      setEmailSent(Boolean(data.emailSent));
       setSubmitted(true);
     } catch (err) {
       setError(err.message);
@@ -112,7 +114,7 @@ export default function PublicExtractPage({ page }) {
         <meta name="description" content={`Recevez gratuitement un extrait de "${page.title}" par ${page.authorName}.`} />
       </Head>
 
-      <nav className="flex items-center px-5 md:px-10 py-4 max-w-2xl mx-auto">
+      <nav className="flex items-center px-5 md:px-10 py-5 max-w-5xl mx-auto">
         <Link href="/" className="flex items-center gap-2">
           <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
             <BookOpen size={14} color={colors.ink} />
@@ -121,24 +123,160 @@ export default function PublicExtractPage({ page }) {
         </Link>
       </nav>
 
-      <main className="max-w-2xl mx-auto px-5 pb-24">
-        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
-          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
+      <main className="max-w-5xl mx-auto px-5 md:px-10 pb-20">
+        {/* Titre en haut, centré */}
+        <header className="text-center max-w-2xl mx-auto pt-4 md:pt-8 pb-8 md:pb-12">
+          <p className="font-mono text-[11px] uppercase tracking-[0.25em] mb-3" style={{ color: colors.goldDark }}>
+            Extrait gratuit
+          </p>
+          <h1 className="font-display text-[2rem] sm:text-4xl md:text-5xl leading-[1.1]" style={{ color: colors.textPaper }}>
+            {page.title}
+          </h1>
+          <div className="flex items-center justify-center gap-3 mt-4">
+            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
+            <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>Par {page.authorName}</p>
+            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
+          </div>
+        </header>
+
+        {/* Couverture à gauche, formulaire à droite (empilés sur mobile) */}
+        <div className="grid md:grid-cols-2 gap-10 md:gap-14 items-center">
+          <div className="relative flex justify-center">
+            <div
+              aria-hidden="true"
+              className="absolute inset-0 m-auto rounded-full"
+              style={{
+                width: "85%",
+                aspectRatio: "1 / 1",
+                background: "radial-gradient(closest-side, rgba(201,162,39,0.22), rgba(201,162,39,0) 100%)",
+              }}
+            />
+            <div className="relative" style={{ transform: "rotate(-1.5deg)" }}>
+              <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
+            </div>
+          </div>
+
           <div>
-            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
-              Extrait gratuit
-            </p>
-            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
-              {page.title}
-            </h1>
-            <p className="font-body text-sm mt-2" style={{ color: colors.textPaperDim }}>
-              Par {page.authorName}
-            </p>
+            {!submitted ? (
+              <form
+                onSubmit={handleSubmit}
+                className="rounded-3xl p-6 md:p-8 space-y-4"
+                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}
+              >
+                <div>
+                  <h2 className="font-display text-2xl" style={{ color: colors.textPaper }}>
+                    Recevez l’extrait gratuitement
+                  </h2>
+                  <p className="font-body text-sm mt-1.5" style={{ color: colors.textMutedLight }}>
+                    Entrez vos coordonnées : le premier chapitre arrive aussitôt dans votre boîte email.
+                  </p>
+                </div>
+
+                <ErrorBanner message={error} />
+
+                {/* Honeypot anti-bot — invisible pour un humain. */}
+                <input
+                  type="text"
+                  name="hp"
+                  id="hp-field-e"
+                  value={form.hp}
+                  onChange={(e) => update("hp", e.target.value)}
+                  autoComplete="off"
+                  tabIndex={-1}
+                  className="absolute opacity-0 pointer-events-none -z-10"
+                  style={{ left: -9999, width: 1, height: 1 }}
+                  aria-hidden="true"
+                />
+
+                <div className="grid sm:grid-cols-2 gap-3">
+                  <input
+                    type="text" required placeholder="Prénom" autoComplete="given-name"
+                    value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
+                  />
+                  <input
+                    type="text" placeholder="Nom" autoComplete="family-name"
+                    value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
+                  />
+                </div>
+
+                <input
+                  type="email" required placeholder="Votre email" autoComplete="email"
+                  value={form.email} onChange={(e) => update("email", e.target.value)}
+                  className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                  style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
+                />
+
+                <div className="flex gap-2">
+                  <select
+                    value={form.countryCode}
+                    onChange={(e) => update("countryCode", e.target.value)}
+                    className="rounded-xl px-3 py-3.5 font-body text-sm shrink-0 outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
+                  >
+                    {COUNTRY_CODES.map((c) => (
+                      <option key={c.iso} value={c.code}>{c.code}</option>
+                    ))}
+                  </select>
+                  <input
+                    type="tel" required placeholder="Numéro WhatsApp" autoComplete="tel-national"
+                    value={form.whatsappNumber}
+                    onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full min-w-0 outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
+                  />
+                </div>
+
+                <button
+                  type="submit"
+                  disabled={submitting}
+                  className="w-full py-4 rounded-xl font-body font-semibold text-[15px] flex items-center justify-center gap-2 transition-transform hover:-translate-y-0.5"
+                  style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
+                >
+                  {submitting ? <Loader2 size={16} className="animate-spin" /> : <Download size={16} />}
+                  {submitting ? "Envoi…" : "Recevoir mon extrait gratuit"}
+                </button>
+
+                <p className="font-mono text-[10.5px] text-center flex items-center justify-center gap-1.5" style={{ color: colors.textMutedLight }}>
+                  <Lock size={11} /> 100 % gratuit · Vos données restent confidentielles
+                </p>
+              </form>
+            ) : (
+              <div
+                className="rounded-3xl p-8 md:p-10 text-center"
+                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}
+              >
+                <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-5" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
+                  <Check size={24} color={colors.forest} />
+                </div>
+                <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
+                <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
+                  {emailSent
+                    ? "Votre extrait vient de vous être envoyé par email."
+                    : "Votre extrait est prêt."}
+                  {pdfUrl ? " Vous pouvez aussi le télécharger directement :" : ""}
+                </p>
+                {pdfUrl && (
+                  <a
+                    href={pdfUrl}
+                    target="_blank"
+                    rel="noreferrer"
+                    className="inline-flex items-center gap-2 px-7 py-3.5 rounded-xl font-body font-semibold text-sm"
+                    style={{ backgroundColor: colors.gold, color: colors.ink, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
+                  >
+                    <Download size={16} /> Télécharger l’extrait
+                  </a>
+                )}
+              </div>
+            )}
           </div>
         </div>
 
         {page.embedUrl && (
-          <div className="rounded-2xl overflow-hidden mb-6" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
+          <div className="max-w-3xl mx-auto mt-14 rounded-2xl overflow-hidden" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
             <div style={{ position: "relative", paddingTop: "56.25%" }}>
               <iframe
                 src={page.embedUrl}
@@ -150,109 +288,6 @@ export default function PublicExtractPage({ page }) {
             </div>
           </div>
         )}
-
-        {!submitted ? (
-          <form onSubmit={handleSubmit} className="rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
-            <div className="flex items-center gap-2">
-              <Mail size={16} color={colors.goldDark} />
-              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Recevez l’extrait gratuitement</h2>
-            </div>
-            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
-              Laissez vos coordonnées, l’extrait vous sera envoyé par email.
-            </p>
-
-            <ErrorBanner message={error} />
-
-            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
-                neutre pour éviter que Chrome ne le remplisse automatiquement
-                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
-            <input
-              type="text"
-              name="hp"
-              id="hp-field-e"
-              value={form.hp}
-              onChange={(e) => update("hp", e.target.value)}
-              autoComplete="off"
-              tabIndex={-1}
-              className="absolute opacity-0 pointer-events-none -z-10"
-              style={{ left: -9999, width: 1, height: 1 }}
-              aria-hidden="true"
-            />
-
-            <div className="grid sm:grid-cols-2 gap-4">
-              <input
-                type="text" required placeholder="Prénom"
-                value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-              <input
-                type="text" placeholder="Nom"
-                value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-            </div>
-
-            <input
-              type="email" required placeholder="Email"
-              value={form.email} onChange={(e) => update("email", e.target.value)}
-              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-            />
-
-            <div className="flex gap-2">
-              <select
-                value={form.countryCode}
-                onChange={(e) => update("countryCode", e.target.value)}
-                className="rounded-lg px-2 py-2.5 font-body text-sm"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              >
-                {COUNTRY_CODES.map((c) => (
-                  <option key={c.iso} value={c.code}>{c.code}</option>
-                ))}
-              </select>
-              <input
-                type="tel" required placeholder="Numéro WhatsApp"
-                value={form.whatsappNumber}
-                onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-            </div>
-
-            <button
-              type="submit"
-              disabled={submitting}
-              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
-              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
-            >
-              {submitting && <Loader2 size={16} className="animate-spin" />}
-              {submitting ? "Envoi…" : "Recevoir l’extrait"}
-            </button>
-          </form>
-        ) : (
-          <div className="rounded-2xl p-6 md:p-8 text-center" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
-            <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
-              <Mail size={20} color={colors.forest} />
-            </div>
-            <h2 className="font-display text-xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
-            <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
-              Votre extrait vous a été envoyé par email{pdfUrl ? " et est disponible en téléchargement direct ci-dessous." : "."}
-            </p>
-            {pdfUrl && (
-              <a
-                href={pdfUrl}
-                target="_blank"
-                rel="noreferrer"
-                className="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-body font-semibold text-sm"
-                style={{ backgroundColor: colors.gold, color: colors.ink }}
-              >
-                <Download size={16} /> Télécharger l’extrait
-              </a>
-            )}
-          </div>
-        )}
       </main>
       <PublicFooter />
     </div>
PLUME_PATCH_EOF
echo "OK : page extrait mise à jour"
