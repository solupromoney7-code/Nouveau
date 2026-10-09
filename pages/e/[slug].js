import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Download, Loader2, Mail } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
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
          website: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      setPdfUrl(data.pdfUrl || "");
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

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-2xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Extrait gratuit
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
            <p className="font-body text-sm mt-2" style={{ color: colors.textPaperDim }}>
              Par {page.authorName}
            </p>
          </div>
        </div>

        {page.embedUrl && (
          <div className="rounded-2xl overflow-hidden mb-6" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
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

        {!submitted ? (
          <form onSubmit={handleSubmit} className="rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Mail size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Recevez l’extrait gratuitement</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Laissez vos coordonnées, l’extrait vous sera envoyé par email.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
                neutre pour éviter que Chrome ne le remplisse automatiquement
                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
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

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Prénom"
                value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" placeholder="Nom"
                value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="email" required placeholder="Email"
              value={form.email} onChange={(e) => update("email", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="flex gap-2">
              <select
                value={form.countryCode}
                onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.iso} value={c.code}>{c.code}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber}
                onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
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
              {submitting ? "Envoi…" : "Recevoir l’extrait"}
            </button>
          </form>
        ) : (
          <div className="rounded-2xl p-6 md:p-8 text-center" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
              <Mail size={20} color={colors.forest} />
            </div>
            <h2 className="font-display text-xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
            <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
              Votre extrait vous a été envoyé par email{pdfUrl ? " et est disponible en téléchargement direct ci-dessous." : "."}
            </p>
            {pdfUrl && (
              <a
                href={pdfUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                <Download size={16} /> Télécharger l’extrait
              </a>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
