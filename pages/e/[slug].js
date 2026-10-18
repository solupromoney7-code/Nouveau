import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Check, Download, Loader2, Lock } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import PublicFooter from "../../components/PublicFooter";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

function getEmbedUrl(url) {
  if (!url) return null;
  try {
    const u = new URL(url);
    if (u.hostname.includes("youtu.be")) {
      return `https://www.youtube.com/embed/${u.pathname.slice(1)}`;
    }
    if (u.hostname.includes("youtube.com")) {
      const id = u.searchParams.get("v");
      if (id) return `https://www.youtube.com/embed/${id}`;
      if (u.pathname.startsWith("/embed/")) return url;
    }
    if (u.hostname.includes("vimeo.com")) {
      const id = u.pathname.split("/").filter(Boolean)[0];
      if (id) return `https://player.vimeo.com/video/${id}`;
    }
  } catch {
    return null;
  }
  return null;
}

export async function getServerSideProps({ params, req }) {
  const extractPage = await prisma.extractPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!extractPage) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: extractPage.book.title,
        coverImageUrl: extractPage.book.coverImageUrl || "",
        authorName: extractPage.book.author.name,
        slug: extractPage.slug,
        embedUrl: getEmbedUrl(extractPage.videoUrl) || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicExtractPage({ page }) {
  const [submitted, setSubmitted] = useState(false);
  const [pdfUrl, setPdfUrl] = useState("");
  const [emailSent, setEmailSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    email: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.firstName || !form.email || !form.whatsappNumber) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/leads/capture", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          firstName: form.firstName,
          lastName: form.lastName,
          email: form.email,
          whatsapp: `${form.countryCode}${form.whatsappNumber}`,
          hpField: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      setPdfUrl(data.pdfUrl || "");
      setEmailSent(Boolean(data.emailSent));
      setSubmitted(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`Extrait gratuit — ${page.title}`}</title>
        <meta name="description" content={`Recevez gratuitement un extrait de "${page.title}" par ${page.authorName}.`} />
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
            Extrait gratuit
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

        {/* Couverture à gauche, formulaire à droite (empilés sur mobile) */}
        <div className="grid md:grid-cols-2 gap-10 md:gap-14 items-center">
          <div className="relative flex justify-center">
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

          <div>
            {!submitted ? (
              <form
                onSubmit={handleSubmit}
                className="rounded-3xl p-6 md:p-8 space-y-4"
                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}
              >
                <div>
                  <h2 className="font-display text-2xl" style={{ color: colors.textPaper }}>
                    Recevez l’extrait gratuitement
                  </h2>
                  <p className="font-body text-sm mt-1.5" style={{ color: colors.textMutedLight }}>
                    Entrez vos coordonnées : le premier chapitre arrive aussitôt dans votre boîte email.
                  </p>
                </div>

                <ErrorBanner message={error} />

                {/* Honeypot anti-bot — invisible pour un humain. */}
                <input
                  type="text"
                  name="hp"
                  id="hp-field-e"
                  value={form.hp}
                  onChange={(e) => update("hp", e.target.value)}
                  autoComplete="off"
                  tabIndex={-1}
                  className="absolute opacity-0 pointer-events-none -z-10"
                  style={{ left: -9999, width: 1, height: 1 }}
                  aria-hidden="true"
                />

                <div className="grid sm:grid-cols-2 gap-3">
                  <input
                    type="text" required placeholder="Prénom" autoComplete="given-name"
                    value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
                  />
                  <input
                    type="text" placeholder="Nom" autoComplete="family-name"
                    value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
                  />
                </div>

                <input
                  type="email" required placeholder="Votre email" autoComplete="email"
                  value={form.email} onChange={(e) => update("email", e.target.value)}
                  className="rounded-xl px-4 py-3.5 font-body text-sm w-full outline-none focus:ring-2"
                  style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
                />

                <div className="flex gap-2">
                  <select
                    value={form.countryCode}
                    onChange={(e) => update("countryCode", e.target.value)}
                    className="rounded-xl px-3 py-3.5 font-body text-sm shrink-0 outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
                  >
                    {COUNTRY_CODES.map((c) => (
                      <option key={c.iso} value={c.code}>{c.code}</option>
                    ))}
                  </select>
                  <input
                    type="tel" required placeholder="Numéro WhatsApp" autoComplete="tel-national"
                    value={form.whatsappNumber}
                    onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                    className="rounded-xl px-4 py-3.5 font-body text-sm w-full min-w-0 outline-none focus:ring-2"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", "--tw-ring-color": colors.gold }}
                  />
                </div>

                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full py-4 rounded-xl font-body font-semibold text-[15px] flex items-center justify-center gap-2 transition-transform hover:-translate-y-0.5"
                  style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
                >
                  {submitting ? <Loader2 size={16} className="animate-spin" /> : <Download size={16} />}
                  {submitting ? "Envoi…" : "Recevoir mon extrait gratuit"}
                </button>

                <p className="font-mono text-[10.5px] text-center flex items-center justify-center gap-1.5" style={{ color: colors.textMutedLight }}>
                  <Lock size={11} /> 100 % gratuit · Vos données restent confidentielles
                </p>
              </form>
            ) : (
              <div
                className="rounded-3xl p-8 md:p-10 text-center"
                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 24px 48px -24px rgba(28,32,51,0.25)" }}
              >
                <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-5" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
                  <Check size={24} color={colors.forest} />
                </div>
                <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
                <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
                  {emailSent
                    ? "Votre extrait vient de vous être envoyé par email."
                    : "Votre extrait est prêt."}
                  {pdfUrl ? " Vous pouvez aussi le télécharger directement :" : ""}
                </p>
                {pdfUrl && (
                  <a
                    href={pdfUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-2 px-7 py-3.5 rounded-xl font-body font-semibold text-sm"
                    style={{ backgroundColor: colors.gold, color: colors.ink, boxShadow: "0 12px 24px -12px rgba(201,162,39,0.8)" }}
                  >
                    <Download size={16} /> Télécharger l’extrait
                  </a>
                )}
              </div>
            )}
          </div>
        </div>

        {page.embedUrl && (
          <div className="max-w-3xl mx-auto mt-14 rounded-2xl overflow-hidden" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div style={{ position: "relative", paddingTop: "56.25%" }}>
              <iframe
                src={page.embedUrl}
                title={page.title}
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                style={{ position: "absolute", top: 0, left: 0, width: "100%", height: "100%", border: 0 }}
              />
            </div>
          </div>
        )}
      </main>
      <PublicFooter />
    </div>
  );
}
