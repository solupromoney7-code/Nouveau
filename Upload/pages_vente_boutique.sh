#!/bin/bash
# Page de vente et boutique : même style élégant que la page d extrait
set -e
cd "$(git rev-parse --show-toplevel)"
git apply --whitespace=nowarn <<'PLUME_PATCH_EOF'
diff --git a/pages/boutique/[slug].js b/pages/boutique/[slug].js
index 6423390..48e9414 100644
--- a/pages/boutique/[slug].js
+++ b/pages/boutique/[slug].js
@@ -64,20 +64,28 @@ export default function PublicStorePage({ authorName, books }) {
             Aucun livre disponible pour le moment — revenez bientôt.
           </p>
         ) : (
-          <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6">
+          <div className="grid grid-cols-2 md:grid-cols-3 gap-4 sm:gap-8">
             {books.map((book) => (
               <Link
                 key={book.id}
                 href={`/p/${book.slug}`}
-                className="rounded-2xl p-6 flex flex-col items-center text-center gap-4 transition-transform hover:-translate-y-0.5"
-                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}
+                className="group rounded-3xl p-4 sm:p-6 flex flex-col items-center text-center gap-4 transition-all hover:-translate-y-1"
+                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 20px 40px -24px rgba(28,32,51,0.3)" }}
               >
-                <BookCover title={book.title} author={authorName} imageUrl={book.coverImageUrl} size="lg" />
-                <div>
-                  <p className="font-display text-base mb-1" style={{ color: colors.textPaper }}>{book.title}</p>
+                <div className="w-full flex justify-center py-3 rounded-2xl" style={{ backgroundColor: colors.paperDim }}>
+                  <BookCover title={book.title} author={authorName} imageUrl={book.coverImageUrl} size="lg" />
+                </div>
+                <div className="flex flex-col items-center gap-2">
+                  <p className="font-display text-base sm:text-lg leading-snug" style={{ color: colors.textPaper }}>{book.title}</p>
                   <p className="font-body text-sm font-semibold" style={{ color: colors.goldDark }}>
                     {formatPrice(book.priceCents, book.currency)}
                   </p>
+                  <span
+                    className="font-body text-xs font-semibold px-4 py-2 rounded-full transition-colors"
+                    style={{ backgroundColor: colors.gold, color: colors.ink }}
+                  >
+                    Voir le livre
+                  </span>
                 </div>
               </Link>
             ))}
diff --git a/pages/p/[slug].js b/pages/p/[slug].js
index 8233d4a..8615fb0 100644
--- a/pages/p/[slug].js
+++ b/pages/p/[slug].js
@@ -108,7 +108,7 @@ export default function PublicSalesPage({ page }) {
         <meta name="description" content={page.problem?.slice(0, 150)} />
       </Head>
 
-      <nav className="flex items-center px-5 md:px-10 py-4 max-w-3xl mx-auto">
+      <nav className="flex items-center px-5 md:px-10 py-5 max-w-5xl mx-auto">
         <Link href="/" className="flex items-center gap-2">
           <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
             <BookOpen size={14} color={colors.ink} />
@@ -117,155 +117,162 @@ export default function PublicSalesPage({ page }) {
         </Link>
       </nav>
 
-      <main className="max-w-3xl mx-auto px-5 pb-24">
-        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
-          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
-          <div>
-            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
-              Livre de {page.authorName}
-            </p>
-            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
-              {page.title}
-            </h1>
+      <main className="max-w-5xl mx-auto px-5 md:px-10 pb-20">
+        {/* Titre en haut, centré */}
+        <header className="text-center max-w-2xl mx-auto pt-4 md:pt-8 pb-8 md:pb-12">
+          <p className="font-mono text-[11px] uppercase tracking-[0.25em] mb-3" style={{ color: colors.goldDark }}>
+            Livre de {page.authorName}
+          </p>
+          <h1 className="font-display text-[2rem] sm:text-4xl md:text-5xl leading-[1.1]" style={{ color: colors.textPaper }}>
+            {page.title}
+          </h1>
+          <div className="flex items-center justify-center gap-3 mt-4">
+            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
+            <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>Par {page.authorName}</p>
+            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
           </div>
-        </div>
-
-        <div className="rounded-2xl p-6 md:p-10 space-y-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
-          <section>
-            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Le problème</p>
-            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.problem}</p>
-          </section>
-          <section>
-            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
-            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.why}</p>
-          </section>
-          <section>
-            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>La solution</p>
-            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.solution}</p>
-          </section>
-        </div>
+        </header>
 
-        <div className="sticky bottom-4 mt-6 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
-          <div className="flex items-center gap-3">
-            <p className="font-display text-2xl" style={{ color: colors.paper }}>
-              {priceLabel} {currencyLabel}
-            </p>
-            <div className="flex items-center gap-1.5 font-mono text-[10px]" style={{ color: colors.mist }}>
-              {page.region === "EUROPE" ? <CreditCard size={13} /> : <Smartphone size={13} />}
-              {page.region === "EUROPE" ? "Carte bancaire" : "Mobile Money"}
+        <div className="grid md:grid-cols-[5fr_6fr] gap-10 md:gap-14 items-start">
+          {/* Couverture (reste visible pendant la lecture sur ordinateur) */}
+          <div className="relative flex justify-center md:sticky md:top-8">
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
             </div>
           </div>
-          {!showForm && (
-            <button
-              onClick={() => setShowForm(true)}
-              className="w-full sm:w-auto px-6 py-3 rounded-xl font-body font-semibold text-sm"
-              style={{ backgroundColor: colors.gold, color: colors.ink }}
-            >
-              Acheter maintenant
-            </button>
-          )}
-        </div>
 
-        {showForm && (
-          <form onSubmit={handleSubmit} className="mt-6 rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
-            <div className="flex items-center gap-2">
-              <Truck size={16} color={colors.goldDark} />
-              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
+          <div className="space-y-6 min-w-0">
+            <div className="rounded-3xl p-6 md:p-9 space-y-7" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}>
+              {[
+                ["Le problème", page.problem],
+                ["Pourquoi maintenant", page.why],
+                ["La solution", page.solution],
+              ].map(([label, text]) => (
+                <section key={label} className="pl-4" style={{ borderLeft: `2px solid ${colors.gold}` }}>
+                  <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>{label}</p>
+                  <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{text}</p>
+                </section>
+              ))}
             </div>
-            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
-              Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
-            </p>
 
-            <ErrorBanner message={error} />
+            <div className="sticky bottom-4 z-10 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
+              <div className="flex items-center gap-3">
+                <p className="font-display text-2xl" style={{ color: colors.paper }}>
+                  {priceLabel} {currencyLabel}
+                </p>
+                <div className="flex items-center gap-1.5 font-mono text-[10px]" style={{ color: colors.mist }}>
+                  {page.region === "EUROPE" ? <CreditCard size={13} /> : <Smartphone size={13} />}
+                  {page.region === "EUROPE" ? "Carte bancaire" : "Mobile Money"}
+                </div>
+              </div>
+              {!showForm && (
+                <button
+                  onClick={() => setShowForm(true)}
+                  className="w-full sm:w-auto px-7 py-3.5 rounded-xl font-body font-semibold text-sm transition-transform hover:-translate-y-0.5"
+                  style={{ backgroundColor: colors.gold, color: colors.ink }}
+                >
+                  Acheter maintenant
+                </button>
+              )}
+            </div>
 
-            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
-                neutre pour éviter que Chrome ne le remplisse automatiquement
-                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
-            <input
-              type="text"
-              name="hp"
-              id="hp-field-p"
-              value={form.hp}
-              onChange={(e) => update("hp", e.target.value)}
-              autoComplete="off"
-              tabIndex={-1}
-              className="absolute opacity-0 pointer-events-none -z-10"
-              style={{ left: -9999, width: 1, height: 1 }}
-              aria-hidden="true"
-            />
+            {showForm && (
+              <form onSubmit={handleSubmit} className="rounded-3xl p-6 md:p-8 space-y-4" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}>
+                <div>
+                  <div className="flex items-center gap-2">
+                    <Truck size={16} color={colors.goldDark} />
+                    <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
+                  </div>
+                  <p className="font-body text-xs mt-1.5" style={{ color: colors.textMutedLight }}>
+                    Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
+                  </p>
+                </div>
 
-            <div className="grid sm:grid-cols-2 gap-4">
-              <input
-                type="text" required placeholder="Nom complet"
-                value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-              <input
-                type="email" required placeholder="Email"
-                value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-            </div>
+                <ErrorBanner message={error} />
 
-            <div className="flex gap-2">
-              <select
-                value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
-                className="rounded-lg px-2 py-2.5 font-body text-sm shrink-0"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150 }}
-              >
-                {COUNTRY_CODES.map((c) => (
-                  <option key={c.code} value={c.code}>{c.label}</option>
-                ))}
-              </select>
-              <input
-                type="tel" required placeholder="Numéro WhatsApp"
-                value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full min-w-0"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-            </div>
+                {/* Honeypot anti-bot — invisible pour un humain. */}
+                <input
+                  type="text"
+                  name="hp"
+                  id="hp-field-p"
+                  value={form.hp}
+                  onChange={(e) => update("hp", e.target.value)}
+                  autoComplete="off"
+                  tabIndex={-1}
+                  className="absolute opacity-0 pointer-events-none -z-10"
+                  style={{ left: -9999, width: 1, height: 1 }}
+                  aria-hidden="true"
+                />
 
-            <input
-              type="text" required placeholder="Adresse (rue, quartier...)"
-              value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
-              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-            />
+                <div className="grid sm:grid-cols-2 gap-3">
+                  <input type="text" required placeholder="Nom complet" autoComplete="name"
+                    value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                  <input type="email" required placeholder="Email" autoComplete="email"
+                    value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                </div>
 
-            <div className="grid sm:grid-cols-3 gap-4">
-              <input
-                type="text" required placeholder="Ville"
-                value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-              <input
-                type="text" required placeholder="Code postal"
-                value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-              <input
-                type="text" required placeholder="Pays"
-                value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
-                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
-                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
-              />
-            </div>
+                <div className="flex gap-2">
+                  <select
+                    value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
+                    className="rounded-xl px-3 py-3.5 font-body text-sm shrink-0 outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150, "--tw-ring-color": colors.gold }}
+                  >
+                    {COUNTRY_CODES.map((c) => (
+                      <option key={c.code} value={c.code}>{c.label}</option>
+                    ))}
+                  </select>
+                  <input type="tel" required placeholder="Numéro WhatsApp" autoComplete="tel-national"
+                    value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full min-w-0 outline-none focus:ring-2"
+                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                </div>
 
-            <button
-              type="submit"
-              disabled={submitting}
-              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
-              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
-            >
-              {submitting && <Loader2 size={16} className="animate-spin" />}
-              {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
-            </button>
-          </form>
-        )}
+                <input type="text" required placeholder="Adresse (rue, quartier...)" autoComplete="street-address"
+                  value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
+                  className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+
+                <div className="grid sm:grid-cols-3 gap-3">
+                  <input type="text" required placeholder="Ville" autoComplete="address-level2"
+                    value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                  <input type="text" required placeholder="Code postal" autoComplete="postal-code"
+                    value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                  <input type="text" required placeholder="Pays" autoComplete="country-name"
+                    value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
+                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
+                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
+                </div>
+
+                <button
+                  type="submit"
+                  disabled={submitting}
+                  className="w-full py-4 rounded-xl font-body font-semibold text-[15px] flex items-center justify-center gap-2 transition-transform hover:-translate-y-0.5"
+                  style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
+                >
+                  {submitting && <Loader2 size={16} className="animate-spin" />}
+                  {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
+                </button>
+              </form>
+            )}
+          </div>
+        </div>
       </main>
       <PublicFooter />
     </div>
PLUME_PATCH_EOF
echo "OK : page de vente et boutique mises à jour"
