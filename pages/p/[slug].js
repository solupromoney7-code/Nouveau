import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Smartphone, CreditCard, Loader2, Truck } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import PublicFooter from "../../components/PublicFooter";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

export async function getServerSideProps({ params, req }) {
  const salesPage = await prisma.salesPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!salesPage || !salesPage.published || salesPage.book.author.suspended) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: salesPage.book.title,
        coverImageUrl: salesPage.book.coverImageUrl || "",
        authorName: salesPage.book.author.name,
        problem: salesPage.problem,
        why: salesPage.why,
        solution: salesPage.solution,
        priceCents: salesPage.priceCents,
        currency: salesPage.currency,
        region: salesPage.book.author.region,
        slug: salesPage.slug,
        turnstileSiteKey: process.env.TURNSTILE_SITE_KEY || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicSalesPage({ page }) {
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    buyerName: "",
    buyerEmail: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    shippingAddress: "",
    shippingCity: "",
    shippingPostalCode: "",
    shippingCountry: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  const currencyLabel = page.currency === "EUR" ? "€" : page.currency;
  const priceLabel = page.currency === "EUR"
    ? (page.priceCents / 100).toFixed(2)
    : Math.round(page.priceCents / 100).toLocaleString("fr-FR");

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.buyerName || !form.buyerEmail || !form.whatsappNumber || !form.shippingAddress || !form.shippingCity || !form.shippingPostalCode || !form.shippingCountry) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/checkout/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          buyerName: form.buyerName,
          buyerEmail: form.buyerEmail,
          buyerWhatsapp: `${form.countryCode}${form.whatsappNumber}`,
          shippingAddress: form.shippingAddress,
          shippingCity: form.shippingCity,
          shippingPostalCode: form.shippingPostalCode,
          shippingCountry: form.shippingCountry,
          hpField: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error("Paiement indisponible pour le moment. Réessayez dans un instant.");
      }
    } catch (err) {
      setError(err.message);
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`${page.title} — ${page.authorName}`}</title>
        <meta name="description" content={page.problem?.slice(0, 150)} />
      </Head>

      <nav className="flex items-center px-5 md:px-10 py-5 max-w-5xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-5xl mx-auto px-5 md:px-10 pb-20">
        {/* Titre en haut, centré */}
        <header className="text-center max-w-2xl mx-auto pt-4 md:pt-8 pb-8 md:pb-12">
          <p className="font-mono text-[11px] uppercase tracking-[0.25em] mb-3" style={{ color: colors.goldDark }}>
            Livre de {page.authorName}
          </p>
          <h1 className="font-display text-[2rem] sm:text-4xl md:text-5xl leading-[1.1]" style={{ color: colors.textPaper }}>
            {page.title}
          </h1>
          <div className="flex items-center justify-center gap-3 mt-4">
            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
            <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>Par {page.authorName}</p>
            <span className="block h-px w-8" style={{ backgroundColor: colors.gold }} />
          </div>
        </header>

        <div className="grid md:grid-cols-[5fr_6fr] gap-10 md:gap-14 items-start">
          {/* Couverture (reste visible pendant la lecture sur ordinateur) */}
          <div className="relative flex justify-center md:sticky md:top-8">
            <div
              aria-hidden="true"
              className="absolute inset-0 m-auto rounded-full"
              style={{
                width: "85%",
                aspectRatio: "1 / 1",
                background: "radial-gradient(closest-side, rgba(201,162,39,0.22), rgba(201,162,39,0) 100%)",
              }}
            />
            <div className="relative" style={{ transform: "rotate(-1.5deg)" }}>
              <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} size="hero" />
            </div>
          </div>

          <div className="space-y-6 min-w-0">
            <div className="rounded-3xl p-6 md:p-9 space-y-7" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}>
              {[
                ["Le problème", page.problem],
                ["Pourquoi maintenant", page.why],
                ["La solution", page.solution],
              ].map(([label, text]) => (
                <section key={label} className="pl-4" style={{ borderLeft: `2px solid ${colors.gold}` }}>
                  <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>{label}</p>
                  <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{text}</p>
                </section>
              ))}
            </div>

            <div className="sticky bottom-4 z-10 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
              <div className="flex items-center gap-3">
                <p className="font-display text-2xl" style={{ color: colors.paper }}>
                  {priceLabel} {currencyLabel}
                </p>
                <div className="flex items-center gap-1.5 font-mono text-[10px]" style={{ color: colors.mist }}>
                  {page.region === "EUROPE" ? <CreditCard size={13} /> : <Smartphone size={13} />}
                  {page.region === "EUROPE" ? "Carte bancaire" : "Mobile Money"}
                </div>
              </div>
              {!showForm && (
                <button
                  onClick={() => setShowForm(true)}
                  className="w-full sm:w-auto px-7 py-3.5 rounded-xl font-body font-semibold text-sm transition-transform hover:-translate-y-0.5"
                  style={{ backgroundColor: colors.gold, color: colors.ink }}
                >
                  Acheter maintenant
                </button>
              )}
            </div>

            {showForm && (
              <form onSubmit={handleSubmit} className="rounded-3xl p-6 md:p-8 space-y-4" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}>
                <div>
                  <div className="flex items-center gap-2">
                    <Truck size={16} color={colors.goldDark} />
                    <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
                  </div>
                  <p className="font-body text-xs mt-1.5" style={{ color: colors.textMutedLight }}>
                    Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
                  </p>
                </div>

                <ErrorBanner message={error} />

                {/* Honeypot anti-bot — invisible pour un humain. */}
                <input
                  type="text"
                  name="hp"
                  id="hp-field-p"
                  value={form.hp}
                  onChange={(e) => update("hp", e.target.value)}
                  autoComplete="off"
                  tabIndex={-1}
                  className="absolute opacity-0 pointer-events-none -z-10"
                  style={{ left: -9999, width: 1, height: 1 }}
                  aria-hidden="true"
                />

                <div className="grid sm:grid-cols-2 gap-3">
                  <input type="text" required placeholder="Nom complet" autoComplete="name"
                    value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                  <input type="email" required placeholder="Email" autoComplete="email"
                    value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                </div>

                <div className="flex gap-2">
                  <select
                    value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
                    className="rounded-xl px-3 py-3.5 font-body text-sm shrink-0 outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150, "--tw-ring-color": colors.gold }}
                  >
                    {COUNTRY_CODES.map((c) => (
                      <option key={c.code} value={c.code}>{c.label}</option>
                    ))}
                  </select>
                  <input type="tel" required placeholder="Numéro WhatsApp" autoComplete="tel-national"
                    value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full min-w-0 outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                </div>

                <input type="text" required placeholder="Adresse (rue, quartier...)" autoComplete="street-address"
                  value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
                  className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />

                <div className="grid sm:grid-cols-3 gap-3">
                  <input type="text" required placeholder="Ville" autoComplete="address-level2"
                    value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                  <input type="text" required placeholder="Code postal" autoComplete="postal-code"
                    value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                  <input type="text" required placeholder="Pays" autoComplete="country-name"
                    value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }} />
                </div>

                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full py-4 rounded-xl font-body font-semibold text-[15px] flex items-center justify-center gap-2 transition-transform hover:-translate-y-0.5"
                  style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
                >
                  {submitting && <Loader2 size={16} className="animate-spin" />}
                  {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
                </button>
              </form>
            )}
          </div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
