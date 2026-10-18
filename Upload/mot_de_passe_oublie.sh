#!/bin/bash
set -e
echo "Ajout de la récupération de mot de passe..."

mkdir -p "lib"
cat > "lib/email.js" << 'PLUME_EOF_MARKER'
// Envoi d'email transactionnel via Resend — https://resend.com
// Nécessite RESEND_API_KEY et RESEND_FROM_EMAIL (adresse expéditrice
// vérifiée dans ton compte Resend, ex. "Plume <contact@ton-domaine.com>").
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const RESEND_FROM_EMAIL = process.env.RESEND_FROM_EMAIL;

export async function sendExtractEmail({ to, bookTitle, pdfUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Votre extrait de "${bookTitle}"`,
      html: `
        <p>Merci pour votre intérêt !</p>
        <p>Voici votre extrait de <strong>${bookTitle}</strong> :</p>
        <p><a href="${pdfUrl}">Télécharger le PDF</a></p>
      `,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("Échec d'envoi Resend :", err);
    return { sent: false };
  }
  return { sent: true };
}

export async function sendPurchaseConfirmationEmail({ to, bookTitle, amountFormatted, buyerName }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Confirmation de votre commande — ${bookTitle}`,
      html: `
        <p>Bonjour ${buyerName || ""},</p>
        <p>Votre commande de <strong>${bookTitle}</strong> (${amountFormatted}) est confirmée.</p>
        <p>L'auteur vous contactera pour organiser la remise ou l'expédition de votre exemplaire.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

// Utilisée par les tunnels de vente automatiques et les envois ponctuels
// (broadcasts). Le corps texte est fourni par l'auteur (ou pré-rempli par
// défaut, voir lib/sequences.js) — on le transforme simplement en
// paragraphes HTML, sans template marketing imposé.
export async function sendMarketingEmail({ to, subject, textBody, replyTo }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const html = textBody
    .split("\n\n")
    .map((p) => `<p>${p.replace(/\n/g, "<br/>")}</p>`)
    .join("\n");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject,
      html,
      ...(replyTo && { reply_to: replyTo }),
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (marketing) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

export async function sendVerificationEmail({ to, verifyUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: "Confirmez votre adresse email — Plume",
      html: `
        <p>Bienvenue sur Plume !</p>
        <p>Confirmez votre adresse email pour activer toutes les fonctionnalités de votre compte (notamment les demandes de reversement) :</p>
        <p><a href="${verifyUrl}">Confirmer mon email</a></p>
        <p>Ce lien expire dans 24h.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (vérification email) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

export async function sendPasswordResetEmail({ to, resetUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: "Réinitialisation de votre mot de passe — Plume",
      html: `
        <p>Bonjour,</p>
        <p>Vous avez demandé à réinitialiser votre mot de passe sur Plume. Cliquez sur le lien ci-dessous pour en choisir un nouveau :</p>
        <p><a href="${resetUrl}">Choisir un nouveau mot de passe</a></p>
        <p>Ce lien expire dans 1 heure et ne peut être utilisé qu'une seule fois.</p>
        <p>Si vous n'êtes pas à l'origine de cette demande, ignorez simplement cet email : votre mot de passe actuel reste inchangé.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (réinitialisation mot de passe) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/connexion.js" << 'PLUME_EOF_MARKER'
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

      <div className="text-right -mt-1">
        <Link href="/mot-de-passe-oublie" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Mot de passe oublié ?
        </Link>
      </div>

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
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/inscription.js" << 'PLUME_EOF_MARKER'
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
        name="hp"
        id="hp-field-signup"
        tabIndex={-1}
        autoComplete="off"
        value={form.website}
        onChange={(e) => setForm({ ...form, website: e.target.value })}
        style={{ position: "absolute", left: "-9999px", width: 1, height: 1 }}
        aria-hidden="true"
      />

      <ErrorBanner message={error} />

      {error.includes("déjà utilisé") && (
        <p className="font-body text-xs -mt-1 mb-1" style={{ color: colors.textPaperDim }}>
          Vous avez déjà un compte avec cet email.{" "}
          <Link href="/connexion" className="underline font-semibold">Se connecter</Link>
          {" · "}
          <Link href="/mot-de-passe-oublie" className="underline font-semibold">Mot de passe oublié ?</Link>
        </p>
      )}

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
PLUME_EOF_MARKER

mkdir -p "pages/api/auth"
cat > "pages/api/auth/forgot-password.js" << 'PLUME_EOF_MARKER'
import { prisma } from "../../../lib/db";
import { signToken } from "../../../lib/auth";
import { isValidEmail } from "../../../lib/validate";
import { sendPasswordResetEmail } from "../../../lib/email";
import { checkRateLimit } from "../../../lib/rateLimit";

// Demande de réinitialisation du mot de passe. On répond TOUJOURS la même
// chose, que l'email existe ou non : sinon n'importe qui pourrait s'en
// servir pour deviner quelles adresses ont un compte sur Plume.
//
// Le lien contient un jeton signé valable 1 heure. Il embarque aussi un
// extrait de l'ancien mot de passe chiffré : dès que le mot de passe est
// changé, le lien devient automatiquement inutilisable (usage unique).
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "forgot-password", 5, 600); // 5 / 10 min / IP
    if (!rl.allowed) return;

    const email = typeof req.body?.email === "string" ? req.body.email.trim() : "";
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "Adresse email invalide" });
    }

    const author = await prisma.author.findUnique({ where: { email } });
    if (author) {
      const token = signToken(
        { authorId: author.id, purpose: "reset_password", pw: author.passwordHash.slice(-12) },
        "1h"
      );
      const resetUrl = `${process.env.APP_URL}/reinitialiser-mot-de-passe?token=${token}`;
      await sendPasswordResetEmail({ to: author.email, resetUrl });
    }

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("Erreur /api/auth/forgot-password :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
PLUME_EOF_MARKER

mkdir -p "pages/api/auth"
cat > "pages/api/auth/reset-password.js" << 'PLUME_EOF_MARKER'
import { prisma } from "../../../lib/db";
import { hashPassword, verifyToken } from "../../../lib/auth";
import { checkRateLimit } from "../../../lib/rateLimit";

// Enregistre le nouveau mot de passe à partir du lien reçu par email.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "reset-password", 10, 600); // 10 / 10 min / IP
    if (!rl.allowed) return;

    const { token, password } = req.body || {};
    if (typeof password !== "string" || password.length < 8) {
      return res.status(400).json({ error: "Le mot de passe doit contenir au moins 8 caractères" });
    }
    if (password.length > 200) {
      return res.status(400).json({ error: "Mot de passe trop long" });
    }

    const payload = typeof token === "string" ? verifyToken(token) : null;
    const invalid = { error: "Lien invalide ou expiré. Refaites une demande de réinitialisation." };
    if (!payload || payload.purpose !== "reset_password") return res.status(400).json(invalid);

    const author = await prisma.author.findUnique({ where: { id: payload.authorId } });
    // Si le mot de passe a déjà été changé depuis l'envoi du lien, l'extrait
    // ne correspond plus : le lien ne peut servir qu'une seule fois.
    if (!author || author.passwordHash.slice(-12) !== payload.pw) return res.status(400).json(invalid);

    const passwordHash = await hashPassword(password);
    // Cliquer sur le lien reçu par email prouve que l'adresse est bien la
    // sienne : on la marque donc aussi comme confirmée.
    await prisma.author.update({
      where: { id: author.id },
      data: { passwordHash, emailVerified: true },
    });

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("Erreur /api/auth/reset-password :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/mot-de-passe-oublie.js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import Link from "next/link";
import { MailCheck } from "lucide-react";
import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api } from "../lib/apiClient";

export default function MotDePasseOublie() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  async function handleSubmit() {
    setError("");
    if (!email.trim()) {
      setError("Entrez l’adresse email de votre compte.");
      return;
    }
    setLoading(true);
    try {
      await api("/api/auth/forgot-password", { method: "POST", auth: false, body: { email: email.trim() } });
      setDone(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const footer = (
    <Link href="/connexion" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
      Retour à la connexion
    </Link>
  );

  if (done) {
    return (
      <AuthShell title="Vérifiez vos emails" subtitle="Si un compte existe avec cette adresse, un lien de réinitialisation vient d’être envoyé." footer={footer}>
        <div className="flex flex-col items-center text-center gap-3 py-2">
          <div className="w-12 h-12 rounded-full flex items-center justify-center" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
            <MailCheck size={22} color={colors.forest} />
          </div>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>
            Ouvrez l’email et cliquez sur le lien : il est valable 1 heure. Pensez à regarder dans vos spams.
          </p>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      title="Mot de passe oublié"
      subtitle="Entrez l’email de votre compte, nous vous envoyons un lien pour en choisir un nouveau."
      footer={footer}
    >
      <ErrorBanner message={error} />
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
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
        {loading ? "Envoi…" : "Envoyer le lien"}
      </button>
    </AuthShell>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/reinitialiser-mot-de-passe.js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import { useRouter } from "next/router";
import Link from "next/link";
import { CheckCircle2 } from "lucide-react";
import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api } from "../lib/apiClient";

export default function ReinitialiserMotDePasse() {
  const router = useRouter();
  const token = typeof router.query.token === "string" ? router.query.token : "";
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  async function handleSubmit() {
    setError("");
    if (password.length < 8) {
      setError("Le mot de passe doit contenir au moins 8 caractères.");
      return;
    }
    if (password !== confirm) {
      setError("Les deux mots de passe ne sont pas identiques.");
      return;
    }
    setLoading(true);
    try {
      await api("/api/auth/reset-password", { method: "POST", auth: false, body: { token, password } });
      setDone(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  if (done) {
    return (
      <AuthShell
        title="Mot de passe modifié"
        subtitle="Vous pouvez maintenant vous connecter avec votre nouveau mot de passe."
        footer={null}
      >
        <div className="flex flex-col items-center text-center gap-4 py-2">
          <CheckCircle2 size={32} color={colors.forest} />
          <Link
            href="/connexion"
            className="w-full py-3 rounded-xl font-body font-semibold text-sm text-center"
            style={{ backgroundColor: colors.gold, color: colors.ink }}
          >
            Se connecter
          </Link>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      title="Nouveau mot de passe"
      subtitle="Choisissez un mot de passe d’au moins 8 caractères."
      footer={
        <Link href="/mot-de-passe-oublie" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Lien expiré ? Refaire une demande
        </Link>
      }
    >
      <ErrorBanner message={error} />
      <input
        type="password"
        placeholder="Nouveau mot de passe"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="password"
        placeholder="Confirmez le mot de passe"
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && handleSubmit()}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <button
        onClick={handleSubmit}
        disabled={loading || !token}
        className="py-3 rounded-xl font-body font-semibold text-sm mt-2 flex items-center justify-center gap-2"
        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: loading || !token ? 0.6 : 1 }}
      >
        {loading && <Spinner size={14} color={colors.ink} />}
        {loading ? "Enregistrement…" : "Enregistrer le mot de passe"}
      </button>
    </AuthShell>
  );
}
PLUME_EOF_MARKER

echo "Termine."
