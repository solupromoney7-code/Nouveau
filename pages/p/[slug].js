import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Smartphone, CreditCard, Loader2, Truck } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";

const COUNTRY_CODES = [
  { code: "+225", label: "Côte d'Ivoire (+225)" },
  { code: "+221", label: "Sénégal (+221)" },
  { code: "+229", label: "Bénin (+229)" },
  { code: "+228", label: "Togo (+228)" },
  { code: "+223", label: "Mali (+223)" },
  { code: "+226", label: "Burkina Faso (+226)" },
  { code: "+237", label: "Cameroun (+237)" },
  { code: "+224", label: "Guinée (+224)" },
  { code: "+33", label: "France (+33)" },
  { code: "+32", label: "Belgique (+32)" },
  { code: "+41", label: "Suisse (+41)" },
  { code: "+1", label: "Canada (+1)" },
];

export async function getServerSideProps({ params }) {
  const salesPage = await prisma.salesPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!salesPage || !salesPage.published) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: salesPage.book.title,
        authorName: salesPage.book.author.name,
        problem: salesPage.problem,
        why: salesPage.why,
        solution: salesPage.solution,
        priceCents: salesPage.priceCents,
        currency: salesPage.currency,
        region: salesPage.book.author.region,
        slug: salesPage.slug,
        turnstileSiteKey: process.env.TURNSTILE_SITE_KEY || "",
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
    countryCode: "+225",
    whatsappNumber: "",
    shippingAddress: "",
    shippingCity: "",
    shippingPostalCode: "",
    shippingCountry: "",
    website: "", // honeypot — jamais rempli par un humain
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
          website: form.website,
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

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-3xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-3xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Livre de {page.authorName}
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
          </div>
        </div>

        <div className="rounded-2xl p-6 md:p-10 space-y-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Le problème</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.problem}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.why}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>La solution</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.solution}</p>
          </section>
        </div>

        <div className="sticky bottom-4 mt-6 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
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
              className="w-full sm:w-auto px-6 py-3 rounded-xl font-body font-semibold text-sm"
              style={{ backgroundColor: colors.gold, color: colors.ink }}
            >
              Acheter maintenant
            </button>
          )}
        </div>

        {showForm && (
          <form onSubmit={handleSubmit} className="mt-6 rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Truck size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain */}
            <input
              type="text"
              name="website"
              value={form.website}
              onChange={(e) => update("website", e.target.value)}
              autoComplete="off"
              tabIndex={-1}
              className="absolute opacity-0 pointer-events-none -z-10"
              style={{ left: -9999, width: 1, height: 1 }}
              aria-hidden="true"
            />

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Nom complet"
                value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="email" required placeholder="Email"
                value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <div className="flex gap-2">
              <select
                value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm shrink-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150 }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.code} value={c.code}>{c.label}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full min-w-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="text" required placeholder="Adresse (rue, quartier...)"
              value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="grid sm:grid-cols-3 gap-4">
              <input
                type="text" required placeholder="Ville"
                value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Code postal"
                value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Pays"
                value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
            </button>
          </form>
        )}
      </main>
    </div>
  );
}
