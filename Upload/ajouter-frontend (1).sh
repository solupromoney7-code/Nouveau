#!/bin/bash
# Ajoute les pages visibles du site (accueil, inscription, connexion).
# A lancer dans le Codespace, a la racine du projet.
set -e

echo "Ajout des pages du site..."
mkdir -p "components"
mkdir -p "lib"
mkdir -p "pages"
mkdir -p "styles"

echo "-> package.json"
cat > 'package.json' << 'PLUMEFILE_EOF'
{
  "name": "plume-backend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "prisma generate && next build",
    "start": "next start",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "postinstall": "prisma generate"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "@prisma/client": "5.17.0",
    "prisma": "5.17.0",
    "bcryptjs": "2.4.3",
    "jsonwebtoken": "9.0.2",
    "stripe": "16.2.0",
    "nanoid": "5.0.7",
    "micro": "10.0.1",
    "@vercel/blob": "0.23.4",
    "@anthropic-ai/sdk": "0.27.3",
    "pdf-parse": "1.1.1",
    "@upstash/ratelimit": "2.0.5",
    "@upstash/redis": "1.34.3",
    "lucide-react": "0.427.0",
    "tailwindcss": "3.4.10",
    "postcss": "8.4.41",
    "autoprefixer": "10.4.20"
  },
  "engines": {
    "node": "24.x"
  }
}
PLUMEFILE_EOF

echo "-> tailwind.config.js"
cat > 'tailwind.config.js' << 'PLUMEFILE_EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,jsx}",
    "./components/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ["Fraunces", "Georgia", "serif"],
        body: ["Work Sans", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "monospace"],
      },
      colors: {
        ink: "#1C2033",
        inkdeep: "#14172A",
        paper: "#F7F3E9",
        paperdim: "#EDE6D3",
        gold: "#C9A227",
        golddark: "#A5821A",
        wine: "#7A2E3B",
        mist: "#9498AC",
        forest: "#4F7A5C",
        inktext: "#241F17",
        inktextdim: "#4A4232",
        bglight: "#FBF9F4",
        bglightalt: "#F4F1E9",
        sage: "#6B9080",
        sagedark: "#547567",
        sky: "#5B7FA6",
        mutedlight: "#70748C",
      },
    },
  },
  plugins: [],
};
PLUMEFILE_EOF

echo "-> postcss.config.js"
cat > 'postcss.config.js' << 'PLUMEFILE_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
PLUMEFILE_EOF

echo "-> styles/globals.css"
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
PLUMEFILE_EOF

echo "-> pages/_app.js"
cat > 'pages/_app.js' << 'PLUMEFILE_EOF'
import Head from "next/head";
import "../styles/globals.css";

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        <title>Plume — Vendez votre livre sans savoir vendre</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="description" content="Plateforme de vente pour auteurs indépendants. L'IA génère votre page de vente à partir de votre livre." />
      </Head>
      <Component {...pageProps} />
    </>
  );
}
PLUMEFILE_EOF

echo "-> pages/index.js"
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
        <div className="flex items-center gap-3">
          <Link href="/connexion" className="font-body text-sm" style={{ color: colors.textMutedLight }}>
            Se connecter
          </Link>
          <Link
            href="/inscription"
            className="font-body text-sm font-semibold px-4 py-2 rounded-lg"
            style={{ backgroundColor: colors.ink, color: colors.paper }}
          >
            Commencer gratuitement
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

echo "-> pages/inscription.js"
cat > 'pages/inscription.js' << 'PLUMEFILE_EOF'
import { useState } from "react";
import { useRouter } from "next/router";
import Link from "next/link";
import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api, saveToken } from "../lib/apiClient";

export default function Inscription() {
  const router = useRouter();
  const [form, setForm] = useState({ name: "", email: "", password: "", region: "AFRIQUE", website: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit() {
    setError("");
    if (!form.name || !form.email || !form.password) {
      setError("Tous les champs sont requis.");
      return;
    }
    if (form.password.length < 8) {
      setError("Le mot de passe doit contenir au moins 8 caractères.");
      return;
    }

    setLoading(true);
    try {
      const data = await api("/api/auth/signup", {
        method: "POST",
        auth: false,
        body: {
          name: form.name,
          email: form.email,
          password: form.password,
          region: form.region,
          website: form.website, // honeypot — doit rester vide
        },
      });
      if (data?.token) {
        saveToken(data.token);
        router.push("/verification-email?email=" + encodeURIComponent(form.email));
      } else {
        setError("Réponse inattendue du serveur. Réessayez.");
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthShell
      title="Créer votre compte"
      subtitle="7 jours d’essai gratuit, sans carte requise pour découvrir."
      footer={
        <Link href="/connexion" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Déjà un compte ? Se connecter
        </Link>
      }
    >
      {/* Honeypot anti-bot : invisible pour un humain */}
      <input
        type="text"
        name="website"
        tabIndex={-1}
        autoComplete="off"
        value={form.website}
        onChange={(e) => setForm({ ...form, website: e.target.value })}
        style={{ position: "absolute", left: "-9999px", width: 1, height: 1 }}
        aria-hidden="true"
      />

      <ErrorBanner message={error} />

      <input
        placeholder="Nom et prénom"
        value={form.name}
        onChange={(e) => setForm({ ...form, name: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="email"
        placeholder="Email"
        value={form.email}
        onChange={(e) => setForm({ ...form, email: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="password"
        placeholder="Mot de passe (8 caractères minimum)"
        value={form.password}
        onChange={(e) => setForm({ ...form, password: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />

      <div className="flex rounded-full p-1 mt-1" style={{ backgroundColor: colors.paperDim }}>
        {["AFRIQUE", "EUROPE"].map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => setForm({ ...form, region: r })}
            className="flex-1 py-1.5 rounded-full font-body text-xs font-semibold"
            style={{
              backgroundColor: form.region === r ? colors.gold : "transparent",
              color: form.region === r ? colors.ink : colors.textPaperDim,
            }}
          >
            {r === "AFRIQUE" ? "Afrique" : "France / Europe"}
          </button>
        ))}
      </div>

      <button
        onClick={handleSubmit}
        disabled={loading}
        className="py-3 rounded-xl font-body font-semibold text-sm mt-2 flex items-center justify-center gap-2"
        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: loading ? 0.6 : 1 }}
      >
        {loading && <Spinner size={14} color={colors.ink} />}
        {loading ? "Création…" : "Créer mon compte"}
      </button>
    </AuthShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/connexion.js"
cat > 'pages/connexion.js' << 'PLUMEFILE_EOF'
import { useState } from "react";
import { useRouter } from "next/router";
import Link from "next/link";
import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api, saveToken } from "../lib/apiClient";

export default function Connexion() {
  const router = useRouter();
  const [form, setForm] = useState({ email: "", password: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit() {
    setError("");
    if (!form.email || !form.password) {
      setError("Email et mot de passe requis.");
      return;
    }

    setLoading(true);
    try {
      const data = await api("/api/auth/login", { method: "POST", auth: false, body: form });
      saveToken(data.token);
      router.push("/dashboard");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthShell
      title="Bon retour"
      subtitle="Connectez-vous à votre espace auteur."
      footer={
        <Link href="/inscription" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Pas de compte ? Créer un compte gratuitement
        </Link>
      }
    >
      <ErrorBanner message={error} />

      <input
        type="email"
        placeholder="Email"
        value={form.email}
        onChange={(e) => setForm({ ...form, email: e.target.value })}
        onKeyDown={(e) => e.key === "Enter" && handleSubmit()}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="password"
        placeholder="Mot de passe"
        value={form.password}
        onChange={(e) => setForm({ ...form, password: e.target.value })}
        onKeyDown={(e) => e.key === "Enter" && handleSubmit()}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />

      <button
        onClick={handleSubmit}
        disabled={loading}
        className="py-3 rounded-xl font-body font-semibold text-sm mt-2 flex items-center justify-center gap-2"
        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: loading ? 0.6 : 1 }}
      >
        {loading && <Spinner size={14} color={colors.ink} />}
        {loading ? "Connexion…" : "Se connecter"}
      </button>
    </AuthShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/verification-email.js"
cat > 'pages/verification-email.js' << 'PLUMEFILE_EOF'
import { useState } from "react";
import { useRouter } from "next/router";
import Link from "next/link";
import { Mail } from "lucide-react";
import { colors, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api } from "../lib/apiClient";

export default function VerificationEmail() {
  const router = useRouter();
  const email = router.query.email || "votre adresse email";
  const [status, setStatus] = useState("idle"); // idle | sending | sent | error

  async function resend() {
    setStatus("sending");
    try {
      await api("/api/auth/resend-verification", { method: "POST" });
      setStatus("sent");
      setTimeout(() => setStatus("idle"), 3000);
    } catch {
      setStatus("error");
      setTimeout(() => setStatus("idle"), 3000);
    }
  }

  return (
    <AuthShell
      title="Vérifiez votre boîte mail"
      subtitle={`Un lien de confirmation a été envoyé à ${email}.`}
      footer={
        <Link href="/connexion" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Retour à la connexion
        </Link>
      }
    >
      <div
        className="rounded-xl px-4 py-3 flex items-start gap-2.5 mb-1"
        style={{ backgroundColor: "rgba(201,162,39,0.12)", border: "1px solid rgba(201,162,39,0.4)" }}
      >
        <Mail size={16} color={colors.goldDark} className="mt-0.5 shrink-0" />
        <p className="font-body text-xs leading-relaxed" style={{ color: colors.textPaper }}>
          Vous pouvez déjà explorer votre espace, mais la demande de reversement restera bloquée
          tant que l’email n’est pas confirmé.
        </p>
      </div>

      <Link
        href="/dashboard"
        className="py-3 rounded-xl font-body font-semibold text-sm text-center"
        style={{ backgroundColor: colors.gold, color: colors.ink }}
      >
        Continuer vers mon espace
      </Link>

      <button
        onClick={resend}
        disabled={status === "sending"}
        className="py-2.5 rounded-xl font-body text-sm flex items-center justify-center gap-2"
        style={{ border: `1px solid ${colors.textPaperDim}`, color: colors.textPaper }}
      >
        {status === "sending" && <Spinner size={13} color={colors.textPaper} />}
        {status === "sent" ? "Email renvoyé ✓" : status === "error" ? "Échec de l’envoi" : status === "sending" ? "Envoi…" : "Renvoyer l’email"}
      </button>
    </AuthShell>
  );
}
PLUMEFILE_EOF

echo "-> lib/apiClient.js"
cat > 'lib/apiClient.js' << 'PLUMEFILE_EOF'
// Connecteur entre les pages (navigateur) et les routes API du même site.
// Les pages et l'API tournent dans la même application Next.js, donc on
// appelle simplement /api/... sans avoir besoin d'URL absolue.

const TOKEN_KEY = "plume_token";

export function saveToken(token) {
  if (typeof window !== "undefined") window.localStorage.setItem(TOKEN_KEY, token);
}

export function getToken() {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

export function clearToken() {
  if (typeof window !== "undefined") window.localStorage.removeItem(TOKEN_KEY);
}

// Appel API générique. Ajoute automatiquement le token d'authentification
// s'il existe, et remonte une erreur lisible plutôt qu'un objet brut.
export async function api(path, { method = "GET", body, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (auth) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(path, {
    method,
    headers,
    ...(body && { body: JSON.stringify(body) }),
  });

  let data = null;
  try {
    data = await res.json();
  } catch {
    // Certaines réponses (204, HTML) n'ont pas de JSON — ce n'est pas une erreur en soi.
  }

  if (!res.ok) {
    const message = data?.error || `Erreur ${res.status}`;
    const error = new Error(message);
    error.status = res.status;
    error.data = data;
    throw error;
  }

  return data;
}
PLUMEFILE_EOF

echo "-> lib/useAuthGuard.js"
cat > 'lib/useAuthGuard.js' << 'PLUMEFILE_EOF'
import { useEffect, useState } from "react";
import { useRouter } from "next/router";
import { api, getToken, clearToken } from "./apiClient";

// Protège une page réservée aux auteurs connectés : redirige vers /connexion
// si aucun token valide, et retourne le profil une fois chargé.
export function useAuthGuard() {
  const router = useRouter();
  const [author, setAuthor] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/connexion");
      return;
    }
    api("/api/authors/me")
      .then((data) => {
        setAuthor(data);
        setLoading(false);
      })
      .catch(() => {
        clearToken();
        router.replace("/connexion");
      });
  }, [router]);

  return { author, setAuthor, loading };
}
PLUMEFILE_EOF

echo "-> components/ui.js"
cat > 'components/ui.js' << 'PLUMEFILE_EOF'
// Composants visuels partagés — repris du prototype validé, pour que le
// vrai site ait exactement la même identité visuelle.

export const colors = {
  ink: "#1C2033",
  inkDeep: "#14172A",
  paper: "#F7F3E9",
  paperDim: "#EDE6D3",
  gold: "#C9A227",
  goldDark: "#A5821A",
  wine: "#7A2E3B",
  mist: "#9498AC",
  forest: "#4F7A5C",
  textPaper: "#241F17",
  textPaperDim: "#4A4232",
  bgLight: "#FBF9F4",
  bgLightAlt: "#F4F1E9",
  sage: "#6B9080",
  sageDark: "#547567",
  sky: "#5B7FA6",
  textMutedLight: "#70748C",
};

export const inputStyle = {
  backgroundColor: colors.paperDim,
  color: colors.textPaper,
  border: "none",
};

export function BookCover({ title, author, size = "md" }) {
  const dims = size === "sm" ? { w: 88, h: 128 } : { w: 120, h: 172 };
  return (
    <div
      className="shrink-0 rounded-md flex flex-col justify-between p-3 shadow-lg"
      style={{
        width: dims.w,
        height: dims.h,
        backgroundImage: `linear-gradient(150deg, ${colors.wine}, ${colors.ink})`,
        border: "1px solid rgba(201,162,39,0.35)",
      }}
    >
      <div className="w-6" style={{ height: 2, backgroundColor: colors.gold }} />
      <p className="font-display leading-tight" style={{ color: colors.paper, fontSize: size === "sm" ? 12 : 15 }}>
        {title}
      </p>
      <p className="font-mono uppercase tracking-wide" style={{ color: colors.mist, fontSize: 9 }}>
        {author}
      </p>
    </div>
  );
}

// Bloc d'erreur réutilisé sur tous les formulaires.
export function ErrorBanner({ message }) {
  if (!message) return null;
  return (
    <div
      className="rounded-lg px-3 py-2.5 font-body text-xs"
      style={{ backgroundColor: "rgba(122,46,59,0.1)", border: `1px solid ${colors.wine}`, color: colors.wine }}
    >
      {message}
    </div>
  );
}

export function Spinner({ size = 16, color }) {
  return (
    <span
      className="inline-block animate-spin rounded-full"
      style={{
        width: size,
        height: size,
        border: `2px solid ${color || colors.gold}`,
        borderTopColor: "transparent",
      }}
    />
  );
}
PLUMEFILE_EOF

echo "-> components/AuthShell.js"
cat > 'components/AuthShell.js' << 'PLUMEFILE_EOF'
import Link from "next/link";
import { BookOpen } from "lucide-react";
import { colors } from "./ui";

export default function AuthShell({ title, subtitle, children, footer }) {
  return (
    <div className="min-h-screen flex items-center justify-center p-5" style={{ backgroundColor: colors.inkDeep }}>
      <div className="w-full max-w-sm rounded-2xl p-7" style={{ backgroundColor: colors.paper }}>
        <Link href="/" className="flex items-center gap-2 mb-6">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
        <h1 className="font-display text-xl mb-1" style={{ color: colors.textPaper }}>{title}</h1>
        <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>{subtitle}</p>
        <div className="flex flex-col gap-2.5">{children}</div>
        <div className="mt-5 text-center">{footer}</div>
      </div>
    </div>
  );
}
PLUMEFILE_EOF

echo ""
echo "OK - pages ajoutees. Etape suivante : npm install"
