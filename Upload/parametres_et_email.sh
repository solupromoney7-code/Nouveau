#!/bin/bash
set -e
echo "Mise à jour : page Paramètres + correction email de confirmation"

mkdir -p "$(dirname "pages/api/auth/resend-verification.js")"
cat > "pages/api/auth/resend-verification.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { signToken } from "../../../lib/auth";
import { sendVerificationEmail } from "../../../lib/email";
import { checkRateLimit } from "../../../lib/rateLimit";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const rl = await checkRateLimit(req, res, "resend-verification", 3, 600); // 3 / 10 min / IP
    if (!rl.allowed) return;

    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    if (author.emailVerified) return res.status(200).json({ ok: true, alreadyVerified: true });

    const verifyToken = signToken({ authorId: author.id, purpose: "verify_email" }, "1d");
    const verifyUrl = `${process.env.APP_URL}/api/auth/verify-email?token=${verifyToken}`;
    const result = await sendVerificationEmail({ to: author.email, verifyUrl });

    return res.status(200).json({ sent: result.sent });
  } catch (error) {
    console.error("Erreur /api/auth/resend-verification :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/authors/payment-config.js")"
cat > "pages/api/authors/payment-config.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// GET  -> retourne l'état de configuration des moyens de paiement de l'auteur
// PUT  -> enregistre le numéro Mobile Money (zone Afrique)
// La connexion Stripe (zone Europe) passe par /api/stripe/connect/onboarding,
// pas par cette route, car elle nécessite une redirection OAuth.
export default requireAuth(async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const author = await prisma.author.findUnique({
        where: { id: req.authorId },
        select: { region: true, stripeAccountId: true, stripeOnboarded: true, momoOperator: true, momoNumber: true },
      });
      return res.status(200).json(author);
    }

    if (req.method === "PUT") {
      const { momoOperator, momoNumber } = req.body;
      if (!momoOperator || !momoNumber) {
        return res.status(400).json({ error: "Opérateur et numéro Mobile Money requis" });
      }
      await prisma.author.update({
        where: { id: req.authorId },
        data: { momoOperator, momoNumber },
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/authors/payment-config :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/stripe/connect/onboarding.js")"
cat > "pages/api/stripe/connect/onboarding.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";
import { stripe } from "../../../../lib/stripe";

// Crée (si besoin) le compte Stripe Connect Express de l'auteur puis
// retourne un lien d'onboarding hébergé par Stripe. Le frontend doit
// rediriger l'auteur vers cette URL — jamais de clé secrète échangée ici.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    let author = await prisma.author.findUnique({ where: { id: req.authorId } });

    if (!author.stripeAccountId) {
      const account = await stripe.accounts.create({
        type: "express",
        email: author.email,
        capabilities: {
          transfers: { requested: true },
          card_payments: { requested: true },
        },
      });
      author = await prisma.author.update({
        where: { id: author.id },
        data: { stripeAccountId: account.id },
      });
    }

    const accountLink = await stripe.accountLinks.create({
      account: author.stripeAccountId,
      refresh_url: `${process.env.APP_URL}/dashboard/paiements?stripe=refresh`,
      return_url: `${process.env.APP_URL}/dashboard/paiements?stripe=retour`,
      type: "account_onboarding",
    });

    return res.status(200).json({ url: accountLink.url });
  } catch (error) {
    console.error("Erreur /api/stripe/connect/onboarding :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/dashboard/parametres.js")"
cat > "pages/dashboard/parametres.js" << 'FILE_EOF_MARKER'
import { useState } from "react";
import { Mail, Check, AlertTriangle, Loader2, Smartphone, CreditCard, ShieldCheck } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const MOMO_OPERATORS = [
  { value: "orange", label: "Orange Money" },
  { value: "mtn", label: "MTN Mobile Money" },
  { value: "moov", label: "Moov Money" },
  { value: "wave", label: "Wave" },
];

function EmailVerificationSection({ author }) {
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null); // { sent: true/false } | { error: "..." }

  async function handleResend() {
    setSending(true);
    setResult(null);
    try {
      const data = await api("/api/auth/resend-verification", { method: "POST" });
      setResult(data);
    } catch (err) {
      setResult({ error: err.message });
    } finally {
      setSending(false);
    }
  }

  const verified = Boolean(author?.emailVerified);

  return (
    <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
      <div className="flex items-center gap-2 mb-1">
        <Mail size={16} color={colors.goldDark} />
        <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Adresse email</h2>
      </div>
      <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>{author?.email}</p>

      {verified ? (
        <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
          <Check size={14} color={colors.forest} />
          <span className="font-body text-sm" style={{ color: colors.forest }}>Email vérifié</span>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="flex items-start gap-2 px-3 py-2.5 rounded-lg" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
            <AlertTriangle size={14} color={colors.goldDark} className="mt-0.5 shrink-0" />
            <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
              Votre email n’est pas encore confirmé. Si vous n’avez rien reçu à l’inscription,
              vérifiez vos spams, puis utilisez le bouton ci-dessous pour renvoyer l’email.
            </p>
          </div>

          <button
            onClick={handleResend}
            disabled={sending}
            className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
            style={{ backgroundColor: colors.gold, color: colors.ink, opacity: sending ? 0.6 : 1 }}
          >
            {sending && <Loader2 size={14} className="animate-spin" />}
            {sending ? "Envoi…" : "Renvoyer l’email de confirmation"}
          </button>

          {result && (
            result.error ? (
              <ErrorBanner message={result.error} />
            ) : result.sent ? (
              <p className="font-body text-xs" style={{ color: colors.forest }}>
                Email envoyé — vérifiez votre boîte de réception (et vos spams) dans les prochaines minutes.
              </p>
            ) : (
              <p className="font-body text-xs" style={{ color: colors.wine }}>
                L’envoi d’emails n’est pas encore activé sur la plateforme. Notre équipe a été informée du problème —
                en attendant, contactez le support si c’est urgent.
              </p>
            )
          )}
        </div>
      )}
    </section>
  );
}

function MomoSection({ author }) {
  const [operator, setOperator] = useState(author?.momoOperator || "");
  const [number, setNumber] = useState(author?.momoNumber || "");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");

  async function handleSave(e) {
    e.preventDefault();
    setError("");
    if (!operator || !number) {
      setError("Choisissez un opérateur et renseignez un numéro.");
      return;
    }
    setSaving(true);
    setSaved(false);
    try {
      await api("/api/authors/payment-config", { method: "PUT", body: { momoOperator: operator, momoNumber: number } });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
      <div className="flex items-center gap-2 mb-1">
        <Smartphone size={16} color={colors.goldDark} />
        <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Moyen d’encaissement</h2>
      </div>
      <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
        Renseignez votre numéro Mobile Money pour recevoir vos reversements.
      </p>

      <form onSubmit={handleSave} className="space-y-3 max-w-sm">
        <ErrorBanner message={error} />
        <div>
          <p className="font-mono text-[10px] uppercase tracking-wide mb-1.5" style={{ color: colors.mist }}>Opérateur</p>
          <select
            value={operator}
            onChange={(e) => setOperator(e.target.value)}
            className="w-full rounded-lg px-3 py-2 font-body text-sm"
            style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
          >
            <option value="">Choisir…</option>
            {MOMO_OPERATORS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div>
          <p className="font-mono text-[10px] uppercase tracking-wide mb-1.5" style={{ color: colors.mist }}>Numéro</p>
          <input
            type="tel"
            value={number}
            onChange={(e) => setNumber(e.target.value)}
            placeholder="+225 07 00 00 00 00"
            className="w-full rounded-lg px-3 py-2 font-body text-sm"
            style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
          />
        </div>
        <div className="flex items-center gap-3">
          <button
            type="submit"
            disabled={saving}
            className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
            style={{ backgroundColor: colors.gold, color: colors.ink, opacity: saving ? 0.6 : 1 }}
          >
            {saving && <Loader2 size={14} className="animate-spin" />}
            {saving ? "Enregistrement…" : "Enregistrer"}
          </button>
          {saved && (
            <span className="flex items-center gap-1 font-body text-xs" style={{ color: colors.forest }}>
              <Check size={13} /> Enregistré
            </span>
          )}
        </div>
      </form>
    </section>
  );
}

function StripeSection({ author }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleConnect() {
    setError("");
    setLoading(true);
    try {
      const data = await api("/api/stripe/connect/onboarding", { method: "POST" });
      window.location.href = data.url;
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  }

  const onboarded = Boolean(author?.stripeOnboarded);

  return (
    <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
      <div className="flex items-center gap-2 mb-1">
        <CreditCard size={16} color={colors.goldDark} />
        <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Moyen d’encaissement</h2>
      </div>
      <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
        Connectez votre compte Stripe pour recevoir vos paiements directement sur votre compte bancaire.
      </p>

      <ErrorBanner message={error} />

      {onboarded ? (
        <div className="flex items-center gap-2 px-3 py-2 rounded-lg w-fit mb-3" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
          <ShieldCheck size={14} color={colors.forest} />
          <span className="font-body text-sm" style={{ color: colors.forest }}>Compte Stripe connecté</span>
        </div>
      ) : null}

      <button
        onClick={handleConnect}
        disabled={loading}
        className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: loading ? 0.6 : 1 }}
      >
        {loading && <Loader2 size={14} className="animate-spin" />}
        {loading ? "Redirection…" : onboarded ? "Gérer mon compte Stripe" : "Connecter Stripe"}
      </button>
    </section>
  );
}

export default function DashboardParametres() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="parametres" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Compte</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Paramètres</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl space-y-6">
          <EmailVerificationSection author={author} />
          {author?.region === "EUROPE" ? <StripeSection author={author} /> : <MomoSection author={author} />}
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

echo "Terminé."
