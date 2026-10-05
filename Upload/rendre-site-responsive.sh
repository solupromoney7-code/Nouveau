#!/bin/bash
set -e
echo "Mise a jour des fichiers pour un site responsive (mobile + ordinateur)..."

mkdir -p "$(dirname 'pages/index.js')"
cat > 'pages/index.js' << 'PLUMEFILE_EOF'
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
            { zone: "Afrique francophone", price: "3 000 FCFA", pay: "Mobile Money", accent: colors.gold },
            { zone: "France / Europe", price: "15 €", pay: "Carte bancaire", accent: colors.sky },
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
PLUMEFILE_EOF

mkdir -p "$(dirname 'components/DashboardShell.js')"
cat > 'components/DashboardShell.js' << 'PLUMEFILE_EOF'
import Link from "next/link";
import { useRouter } from "next/router";
import {
  BookOpen, FileText, Users, Store, Settings, CreditCard,
  Sparkles, Wallet, Mail, Lock, LogOut,
} from "lucide-react";
import { colors } from "./ui";
import { clearToken } from "../lib/apiClient";

const NAV_ITEMS = [
  { id: "vente", label: "Page de vente", icon: FileText, href: "/dashboard" },
  { id: "extrait", label: "Page d’extrait", icon: BookOpen, href: "/dashboard/extrait" },
  { id: "contenu", label: "Contenu réseaux", icon: Sparkles, href: "/dashboard/contenu", locked: true },
  { id: "contacts", label: "Contacts", icon: Users, href: "/dashboard/contacts" },
  { id: "tunnels", label: "Tunnels de vente", icon: Mail, href: "/dashboard/tunnels" },
  { id: "boutique", label: "Ma boutique", icon: Store, href: "/dashboard/boutique" },
  { id: "parametres", label: "Paramètres", icon: Settings, href: "/dashboard/parametres" },
  { id: "paiements", label: "Paiements", icon: Wallet, href: "/dashboard/paiements" },
  { id: "abonnement", label: "Abonnement", icon: CreditCard, href: "/dashboard/abonnement" },
];

export default function DashboardShell({ active, author, children }) {
  const router = useRouter();

  function handleLogout() {
    clearToken();
    router.push("/");
  }

  return (
    <div className="min-h-screen flex flex-col md:flex-row" style={{ backgroundColor: colors.inkDeep }}>
      <aside
        className="shrink-0 md:w-60 md:h-screen md:sticky md:top-0 flex flex-col border-b md:border-b-0 md:border-r"
        style={{ backgroundColor: colors.ink, borderColor: "rgba(255,255,255,0.08)" }}
      >
        <div className="flex items-center gap-2 px-4 py-4 md:py-5">
          <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={16} color={colors.ink} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-display text-lg leading-none" style={{ color: colors.paper }}>Plume</p>
            <p className="font-mono text-[10px] tracking-wide" style={{ color: colors.mist }}>ESPACE AUTEUR</p>
          </div>
          <button onClick={handleLogout} title="Se déconnecter" className="shrink-0 p-2 -m-2 md:hidden">
            <LogOut size={16} color={colors.mist} />
          </button>
        </div>

        <div className="relative md:static">
          <nav className="flex md:flex-col gap-1 overflow-x-auto md:overflow-visible px-3 pb-3 md:pb-4 no-scrollbar">
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              const isActive = active === item.id;
              return (
                <Link
                  key={item.id}
                  href={item.href}
                  className="flex items-center gap-2 px-3 py-2 rounded-lg whitespace-nowrap text-sm shrink-0 transition-colors"
                  style={{
                    backgroundColor: isActive ? "rgba(201,162,39,0.14)" : "transparent",
                    color: isActive ? colors.gold : colors.mist,
                  }}
                >
                  <Icon size={16} />
                  {item.label}
                  {item.locked && <Lock size={11} style={{ marginLeft: 2 }} />}
                </Link>
              );
            })}
          </nav>
          <div
            className="pointer-events-none absolute top-0 right-0 h-full w-8 md:hidden"
            style={{ background: `linear-gradient(to right, transparent, ${colors.ink})` }}
          />
        </div>

        <div className="hidden md:flex items-center gap-2 mt-auto px-4 py-4 border-t" style={{ borderColor: "rgba(255,255,255,0.08)" }}>
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center font-body text-xs font-semibold shrink-0"
            style={{ backgroundColor: colors.wine, color: colors.paper }}
          >
            {(author?.name || "?").split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm truncate" style={{ color: colors.paper }}>{author?.name || "…"}</p>
            <p className="font-mono text-[10px]" style={{ color: colors.mist }}>
              {author?.subscriptionStatus === "TRIALING" ? "Essai gratuit" : author?.subscriptionStatus === "ACTIVE" ? "Abonnement actif" : "Abonnement inactif"}
            </p>
          </div>
          <button onClick={handleLogout} title="Se déconnecter">
            <LogOut size={15} color={colors.mist} />
          </button>
        </div>
      </aside>

      <main className="flex-1 min-w-0 p-4 md:p-8 pb-20">{children}</main>
    </div>
  );
}
PLUMEFILE_EOF

mkdir -p "$(dirname 'styles/globals.css')"
cat > 'styles/globals.css' << 'PLUMEFILE_EOF'
@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&family=Work+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

html, body, #__next {
  min-height: 100%;
}

body {
  font-family: 'Work Sans', system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
.animate-fade-up { animation: fadeUp 0.5s ease forwards; }

/* Scroll horizontal discret pour la nav mobile du dashboard (le scroll
   reste actif, seule la barre visible est masquée). */
.no-scrollbar::-webkit-scrollbar { display: none; }
.no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }

/* Evite tout débordement horizontal accidentel sur mobile. */
html, body { overflow-x: hidden; }
PLUMEFILE_EOF

echo "Termine. Fichiers mis a jour :"
echo "  - pages/index.js"
echo "  - components/DashboardShell.js"
echo "  - styles/globals.css"
