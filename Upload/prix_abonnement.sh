#!/bin/bash
set -e
echo "Met a jour les prix affiches de l'abonnement"

mkdir -p "$(dirname "pages/dashboard/abonnement.js")"
cat > "pages/dashboard/abonnement.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import { useRouter } from "next/router";
import { CreditCard, Check, Clock, AlertTriangle, XCircle, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const FEATURES = ["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 7 jours"];

function daysLeft(date) {
  if (!date) return 0;
  const ms = new Date(date).getTime() - Date.now();
  return Math.max(0, Math.ceil(ms / (24 * 60 * 60 * 1000)));
}

function StatusBadge({ author }) {
  const status = author?.subscriptionStatus;

  if (status === "ACTIVE") {
    return (
      <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
        <Check size={14} color={colors.forest} />
        <span className="font-body text-sm" style={{ color: colors.forest }}>
          Abonnement actif — renouvellement le {author?.currentPeriodEnd ? new Date(author.currentPeriodEnd).toLocaleDateString("fr-FR") : "—"}
        </span>
      </div>
    );
  }

  if (status === "TRIALING") {
    const left = daysLeft(author?.trialEndsAt);
    return (
      <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(201,162,39,0.12)" }}>
        <Clock size={14} color={colors.goldDark} />
        <span className="font-body text-sm" style={{ color: colors.goldDark }}>
          Essai gratuit — {left} jour{left > 1 ? "s" : ""} restant{left > 1 ? "s" : ""}
        </span>
      </div>
    );
  }

  if (status === "PAST_DUE") {
    return (
      <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(122,46,59,0.1)" }}>
        <AlertTriangle size={14} color={colors.wine} />
        <span className="font-body text-sm" style={{ color: colors.wine }}>Dernier paiement échoué — réglez votre abonnement</span>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(122,46,59,0.1)" }}>
      <XCircle size={14} color={colors.wine} />
      <span className="font-body text-sm" style={{ color: colors.wine }}>Abonnement inactif</span>
    </div>
  );
}

export default function DashboardAbonnement() {
  const router = useRouter();
  const { author, setAuthor, loading: authLoading } = useAuthGuard();

  const [subscribing, setSubscribing] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");

  useEffect(() => {
    if (!author || !router.query.paiement) return;
    api("/api/authors/me")
      .then(setAuthor)
      .catch(() => {});
    setInfo("Merci ! Nous vérifions votre paiement — votre statut se met à jour dans quelques instants.");
    router.replace("/dashboard/abonnement", undefined, { shallow: true });
  }, [author, router.query.paiement]); // eslint-disable-line react-hooks/exhaustive-deps

  async function handleSubscribe() {
    setError("");
    setSubscribing(true);
    try {
      const data = await api("/api/subscriptions/checkout", { method: "POST" });
      if (data.status === "already_active") {
        const refreshed = await api("/api/authors/me");
        setAuthor(refreshed);
        setInfo("Votre abonnement est déjà actif.");
        setSubscribing(false);
        return;
      }
      window.location.href = data.url;
    } catch (err) {
      setError(err.message);
      setSubscribing(false);
    }
  }

  const isAfrique = author?.region === "AFRIQUE";
  const price = isAfrique ? "3 900 FCFA" : "5,99 €";
  const payMethod = isAfrique ? "Mobile Money" : "Carte bancaire";
  const active = author?.subscriptionStatus === "ACTIVE";
  const ctaLabel = active
    ? "Abonnement actif"
    : author?.subscriptionStatus === "PAST_DUE"
    ? "Régulariser mon paiement"
    : "S’abonner maintenant";

  return (
    <DashboardShell active="abonnement" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Compte</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Abonnement</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl space-y-6">
          <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <div className="flex items-center gap-2 mb-3">
              <CreditCard size={16} color={colors.goldDark} />
              <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Votre statut</h2>
            </div>
            <StatusBadge author={author} />
            {info && <p className="font-body text-xs mt-3" style={{ color: colors.textPaperDim }}>{info}</p>}
          </section>

          <section className="rounded-2xl overflow-hidden" style={{ backgroundColor: "#FFFFFF" }}>
            <div style={{ height: 5, backgroundColor: isAfrique ? colors.gold : colors.sky }} />
            <div className="p-7">
              <p className="font-mono text-[11px] uppercase tracking-wide mb-3" style={{ color: colors.textMutedLight || colors.textPaperDim }}>
                {isAfrique ? "Afrique francophone" : "France / Europe"}
              </p>
              <p className="font-display text-3xl mb-1" style={{ color: colors.textPaper }}>
                {price}<span className="font-body text-sm" style={{ color: colors.textPaperDim }}> / mois</span>
              </p>
              <p className="font-body text-xs mb-5" style={{ color: colors.textPaperDim }}>Paiement {payMethod}</p>

              <div className="flex flex-col gap-2 mb-6">
                {FEATURES.map((f) => (
                  <div key={f} className="flex items-center gap-2">
                    <Check size={13} color={colors.sageDark || colors.forest} />
                    <p className="font-body text-sm" style={{ color: colors.textPaper }}>{f}</p>
                  </div>
                ))}
              </div>

              <ErrorBanner message={error} />

              <button
                onClick={handleSubscribe}
                disabled={subscribing || active}
                className="flex items-center gap-2 px-5 py-2.5 rounded-xl font-body font-semibold text-sm mt-3"
                style={{
                  backgroundColor: active ? colors.paperDim : colors.gold,
                  color: active ? colors.textPaperDim : colors.ink,
                  opacity: subscribing ? 0.6 : 1,
                  cursor: active ? "default" : "pointer",
                }}
              >
                {subscribing && <Loader2 size={14} className="animate-spin" />}
                {subscribing ? "Redirection…" : ctaLabel}
              </button>
            </div>
          </section>
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/index.js")"
cat > "pages/index.js" << 'FILE_EOF_MARKER'
import Link from "next/link";
import { BookOpen, Sparkles, Upload, Wallet, ArrowRight, Check } from "lucide-react";
import { colors, BookCover } from "../components/ui";

function MockSalesCard() {
  return (
    <div className="relative w-full max-w-sm">
      <div
        className="absolute rounded-3xl"
        style={{
          inset: "-1.5rem",
          zIndex: -1,
          background: `linear-gradient(135deg, ${colors.gold}33, ${colors.sage}33)`,
          filter: "blur(6px)",
        }}
      />
      <div
        className="rounded-2xl p-5 transition-transform duration-500"
        style={{ backgroundColor: "#FFFFFF", boxShadow: "0 30px 60px -15px rgba(28,32,51,0.25)", transform: "rotate(2deg)" }}
      >
        <div className="flex items-center gap-3 mb-4">
          <BookCover title="Le Pouvoir du Matin" author="Aïssatou Diallo" size="sm" />
          <div className="min-w-0">
            <p className="font-display text-base leading-tight" style={{ color: colors.textPaper }}>Le Pouvoir du Matin</p>
            <p className="font-mono text-[10px] mt-1" style={{ color: colors.textMutedLight }}>votre-site.com/p/le-pouvoir-du-matin</p>
          </div>
        </div>
        <p className="font-mono text-[10px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Le problème</p>
        <p className="font-body text-xs leading-relaxed mb-3" style={{ color: colors.textPaperDim }}>
          Vous vous réveillez déjà fatigué. Vos projets les plus importants attendent depuis des semaines…
        </p>
        <div className="flex items-center justify-between pt-3 border-t" style={{ borderColor: colors.paperDim }}>
          <p className="font-body text-sm font-semibold" style={{ color: colors.textPaper }}>12 €</p>
          <span className="font-body text-xs font-semibold px-3 py-1.5 rounded-lg" style={{ backgroundColor: colors.gold, color: colors.ink }}>
            Acheter maintenant
          </span>
        </div>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen overflow-hidden">
      <nav
        className="sticky top-0 z-40 flex items-center justify-between px-5 md:px-10 py-4 max-w-6xl mx-auto"
        style={{ backdropFilter: "blur(14px)", backgroundColor: "rgba(251,249,244,0.75)", borderBottom: `1px solid ${colors.paperDim}` }}
      >
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={16} color={colors.ink} />
          </div>
          <span className="font-display text-lg" style={{ color: colors.textPaper }}>Plume</span>
        </div>
        <div className="flex items-center gap-2 sm:gap-3">
          <Link href="/connexion" className="font-body text-xs sm:text-sm whitespace-nowrap shrink-0" style={{ color: colors.textMutedLight }}>
            Se connecter
          </Link>
          <Link
            href="/inscription"
            className="font-body text-xs sm:text-sm font-semibold px-3 sm:px-4 py-2 rounded-lg whitespace-nowrap shrink-0"
            style={{ backgroundColor: colors.ink, color: colors.paper }}
          >
            <span className="sm:hidden">Commencer</span>
            <span className="hidden sm:inline">Commencer gratuitement</span>
          </Link>
        </div>
      </nav>

      <section className="relative max-w-6xl mx-auto px-5 pt-14 md:pt-20 pb-20">
        <div
          className="absolute pointer-events-none"
          style={{ top: -60, right: "5%", width: 420, height: 420, borderRadius: "50%", background: colors.gold, opacity: 0.16, filter: "blur(100px)" }}
        />
        <div
          className="absolute pointer-events-none"
          style={{ bottom: -40, left: 0, width: 380, height: 380, borderRadius: "50%", background: colors.sage, opacity: 0.16, filter: "blur(100px)" }}
        />

        <div className="relative grid lg:grid-cols-2 gap-12 items-center">
          <div>
            <span
              className="inline-flex items-center gap-2 font-mono text-[11px] uppercase tracking-widest px-3 py-1.5 rounded-full mb-6"
              style={{ backgroundColor: "#FFFFFF", color: colors.goldDark, border: `1px solid ${colors.paperDim}` }}
            >
              <Sparkles size={12} /> Génération IA en 2 minutes
            </span>
            <h1 className="font-display text-4xl md:text-5xl leading-tight mb-6" style={{ color: colors.textPaper }}>
              Vous savez écrire.<br />On s’occupe de vendre.
            </h1>
            <p className="font-body text-base md:text-lg mb-8 max-w-md" style={{ color: colors.textMutedLight }}>
              Téléchargez votre livre : l’IA génère votre page de vente, votre page d’extrait et votre
              contenu réseaux. Vous encaissez, en carte bancaire ou en Mobile Money.
            </p>
            <div className="flex flex-wrap items-center gap-4">
              <Link
                href="/inscription"
                className="inline-flex items-center gap-2 font-body font-semibold px-6 py-3.5 rounded-xl"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                Créer ma page de vente <ArrowRight size={16} />
              </Link>
              <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
                Essai gratuit 7 jours — sans engagement
              </p>
            </div>
          </div>

          <div className="flex justify-center lg:justify-end">
            <MockSalesCard />
          </div>
        </div>

        <div className="relative grid grid-cols-3 gap-4 mt-16 max-w-2xl">
          {[
            ["2 min", "pour publier une page", colors.goldDark],
            ["20", "posts réseaux générés / mois", colors.sageDark],
            ["2", "zones de paiement couvertes", colors.sky],
          ].map(([n, l, c]) => (
            <div key={l}>
              <p className="font-display text-2xl md:text-3xl" style={{ color: c }}>{n}</p>
              <p className="font-body text-xs mt-1" style={{ color: colors.textMutedLight }}>{l}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="px-5 pb-20" style={{ backgroundColor: colors.bgLightAlt }}>
        <div className="max-w-4xl mx-auto pt-16">
          <p className="font-mono text-[11px] uppercase tracking-widest mb-2 text-center" style={{ color: colors.goldDark }}>
            Comment ça marche
          </p>
          <h2 className="font-display text-2xl md:text-3xl text-center mb-12" style={{ color: colors.textPaper }}>
            Trois étapes, zéro compétence marketing
          </h2>
          <div className="grid sm:grid-cols-3 gap-6">
            {[
              { icon: Upload, title: "Téléchargez", text: "Votre manuscrit, en PDF ou EPUB.", accent: colors.gold, accentBg: "#FBF0DC" },
              { icon: Sparkles, title: "L’IA rédige", text: "Page de vente, page d’extrait, posts réseaux.", accent: colors.sageDark, accentBg: "#E4EEE8" },
              { icon: Wallet, title: "Vous encaissez", text: "Carte bancaire ou Mobile Money, automatiquement.", accent: colors.sky, accentBg: "#E6EDF5" },
            ].map((s, i) => (
              <div key={s.title} className="rounded-2xl p-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
                <div className="w-11 h-11 rounded-full flex items-center justify-center mb-4" style={{ backgroundColor: s.accentBg }}>
                  <s.icon size={18} color={s.accent} />
                </div>
                <p className="font-mono text-[10px] mb-1" style={{ color: colors.textMutedLight }}>Étape {i + 1}</p>
                <p className="font-display text-lg mb-1" style={{ color: colors.textPaper }}>{s.title}</p>
                <p className="font-body text-sm" style={{ color: colors.textMutedLight }}>{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="max-w-3xl mx-auto px-5 pb-24 pt-20">
        <p className="font-mono text-[11px] uppercase tracking-widest mb-2 text-center" style={{ color: colors.goldDark }}>Tarifs</p>
        <h2 className="font-display text-2xl md:text-3xl text-center mb-10" style={{ color: colors.textPaper }}>
          Un prix simple, deux zones
        </h2>
        <div className="grid sm:grid-cols-2 gap-5">
          {[
            { zone: "Afrique francophone", price: "3 900 FCFA", pay: "Mobile Money", accent: colors.gold },
            { zone: "France / Europe", price: "5,99 €", pay: "Carte bancaire", accent: colors.sky },
          ].map((p) => (
            <div key={p.zone} className="rounded-2xl overflow-hidden" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
              <div style={{ height: 5, backgroundColor: p.accent }} />
              <div className="p-7">
                <p className="font-mono text-[11px] uppercase tracking-wide mb-3" style={{ color: colors.textMutedLight }}>{p.zone}</p>
                <p className="font-display text-3xl mb-1" style={{ color: colors.textPaper }}>
                  {p.price}<span className="font-body text-sm" style={{ color: colors.textMutedLight }}> / mois</span>
                </p>
                <p className="font-body text-xs mb-5" style={{ color: colors.textMutedLight }}>Paiement {p.pay}</p>
                <div className="flex flex-col gap-2">
                  {["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 7 jours"].map((f) => (
                    <div key={f} className="flex items-center gap-2">
                      <Check size={13} color={colors.sageDark} />
                      <p className="font-body text-xs" style={{ color: colors.textPaper }}>{f}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <footer className="border-t px-5 py-8" style={{ borderColor: colors.paperDim }}>
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
              <BookOpen size={12} color={colors.ink} />
            </div>
            <span className="font-display text-sm" style={{ color: colors.textPaper }}>Plume</span>
          </div>
          <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
            Plateforme de vente pour auteurs indépendants
          </p>
        </div>
      </footer>
    </div>
  );
}
FILE_EOF_MARKER

echo "Termine."
