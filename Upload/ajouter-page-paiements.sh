#!/bin/bash
set -e

mkdir -p "pages/dashboard"
cat > "pages/dashboard/paiements.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import Link from "next/link";
import { Wallet, Clock, Check, X, AlertTriangle, ArrowRight, Smartphone, CreditCard } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

function formatMoney(cents, currency) {
  const amount = (cents || 0) / 100;
  if (currency === "EUR") return `${amount.toFixed(2)} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

const STATUS_LABELS = {
  PENDING: { label: "En cours", color: colors.goldDark, bg: "rgba(201,162,39,0.12)" },
  PAID: { label: "Payé", color: colors.forest, bg: "rgba(79,122,92,0.12)" },
  FAILED: { label: "Échoué", color: colors.wine, bg: "rgba(122,46,59,0.1)" },
};

export default function DashboardPaiements() {
  const { author, loading: authLoading } = useAuthGuard();

  const [balance, setBalance] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [requesting, setRequesting] = useState(false);
  const [amountInput, setAmountInput] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [requestError, setRequestError] = useState("");

  useEffect(() => {
    if (!author) return;
    setLoading(true);
    setError("");
    Promise.all([api("/api/payouts/balance"), api("/api/payouts/history")])
      .then(([b, h]) => {
        setBalance(b);
        setHistory(h);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  function openRequestForm() {
    const availableUnit = ((balance?.availableCents || 0) / 100).toFixed(2);
    setAmountInput(availableUnit);
    setRequestError("");
    setRequesting(true);
  }

  async function handleRequestSubmit(e) {
    e.preventDefault();
    setRequestError("");
    const amountCents = Math.round(Number(amountInput) * 100);
    if (!amountCents || amountCents <= 0) {
      setRequestError("Montant invalide.");
      return;
    }
    if (amountCents > (balance?.availableCents || 0)) {
      setRequestError("Ce montant dépasse votre solde disponible.");
      return;
    }
    setSubmitting(true);
    try {
      const payout = await api("/api/payouts/request", { method: "POST", body: { amountCents } });
      setHistory((h) => [payout, ...h]);
      const [b, h] = await Promise.all([api("/api/payouts/balance"), api("/api/payouts/history")]);
      setBalance(b);
      setHistory(h);
      setRequesting(false);
    } catch (err) {
      setRequestError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  const currency = balance?.currency || (author?.region === "EUROPE" ? "EUR" : "XOF");
  const needsSetup = balance && !balance.connected;

  return (
    <DashboardShell active="paiements" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Encaissement</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Paiements</h1>
      </header>

      {authLoading || loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl space-y-6">
          <ErrorBanner message={error} />

          {needsSetup ? (
            <div className="rounded-2xl p-8 text-center" style={{ backgroundColor: colors.paper }}>
              <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
                {author?.region === "EUROPE" ? <CreditCard size={20} color={colors.goldDark} /> : <Smartphone size={20} color={colors.goldDark} />}
              </div>
              <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>
                {author?.region === "EUROPE" ? "Connectez votre compte Stripe" : "Renseignez votre numéro Mobile Money"}
              </h2>
              <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
                {author?.region === "EUROPE"
                  ? "Pour recevoir vos paiements, connectez un compte Stripe depuis Paramètres."
                  : "Pour recevoir vos reversements, renseignez votre numéro Mobile Money depuis Paramètres."}
              </p>
              <Link
                href="/dashboard/parametres"
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                Aller à Paramètres <ArrowRight size={15} />
              </Link>
            </div>
          ) : (
            <div className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
              <div className="flex items-center gap-2 mb-1">
                <Wallet size={16} color={colors.goldDark} />
                <p className="font-mono text-[11px] uppercase tracking-widest" style={{ color: colors.goldDark }}>Solde disponible</p>
              </div>
              <p className="font-display text-4xl mb-1" style={{ color: colors.textPaper }}>
                {formatMoney(balance?.availableCents, currency)}
              </p>
              {balance?.note && (
                <p className="font-body text-xs mb-5" style={{ color: colors.textPaperDim }}>{balance.note}</p>
              )}

              {!requesting ? (
                <button
                  onClick={openRequestForm}
                  disabled={!balance?.availableCents}
                  className="px-5 py-2.5 rounded-xl font-body font-semibold text-sm"
                  style={{
                    backgroundColor: colors.gold, color: colors.ink,
                    opacity: balance?.availableCents ? 1 : 0.4,
                    cursor: balance?.availableCents ? "pointer" : "not-allowed",
                  }}
                >
                  Demander un reversement
                </button>
              ) : (
                <form onSubmit={handleRequestSubmit} className="mt-2 p-4 rounded-xl space-y-3" style={{ backgroundColor: colors.paperDim }}>
                  <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                    Montant à reverser ({currency === "EUR" ? "€" : "FCFA"}) — traité sous 24h.
                  </p>
                  <ErrorBanner message={requestError} />
                  <div className="flex gap-2 flex-wrap">
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={amountInput}
                      onChange={(e) => setAmountInput(e.target.value)}
                      className="rounded-lg px-3 py-2 font-body text-sm w-40"
                      style={{ backgroundColor: "#FFFFFF", color: colors.textPaper, border: "none" }}
                    />
                    <button
                      type="submit"
                      disabled={submitting}
                      className="px-4 py-2 rounded-lg font-body font-semibold text-sm flex items-center gap-2"
                      style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
                    >
                      {submitting && <Spinner size={13} color={colors.ink} />}
                      {submitting ? "Envoi…" : "Confirmer"}
                    </button>
                    <button
                      type="button"
                      onClick={() => setRequesting(false)}
                      className="px-4 py-2 rounded-lg font-body text-sm"
                      style={{ color: colors.textPaperDim }}
                    >
                      Annuler
                    </button>
                  </div>
                </form>
              )}
            </div>
          )}

          <div className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-4" style={{ color: colors.goldDark }}>
              Historique des reversements
            </p>
            {history.length === 0 ? (
              <p className="font-body text-sm py-4 text-center" style={{ color: colors.textPaperDim }}>
                Aucune demande de reversement pour l’instant.
              </p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left">
                  <thead>
                    <tr className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.mist }}>
                      <th className="pb-2 pr-4">Date</th>
                      <th className="pb-2 pr-4">Montant</th>
                      <th className="pb-2 pr-4">Méthode</th>
                      <th className="pb-2">Statut</th>
                    </tr>
                  </thead>
                  <tbody className="font-body text-sm" style={{ color: colors.textPaper }}>
                    {history.map((p) => {
                      const status = STATUS_LABELS[p.status] || STATUS_LABELS.PENDING;
                      return (
                        <tr key={p.id} className="border-t" style={{ borderColor: colors.paperDim }}>
                          <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
                            {new Date(p.createdAt).toLocaleDateString("fr-FR")}
                          </td>
                          <td className="py-2.5 pr-4 whitespace-nowrap">{formatMoney(p.amountCents, p.currency)}</td>
                          <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
                            {p.method === "stripe" ? "Stripe" : "Mobile Money"}
                          </td>
                          <td className="py-2.5 whitespace-nowrap">
                            <span
                              className="inline-flex items-center gap-1.5 px-2 py-1 rounded-lg text-xs"
                              style={{ backgroundColor: status.bg, color: status.color }}
                            >
                              {p.status === "PAID" ? <Check size={12} /> : p.status === "FAILED" ? <X size={12} /> : <Clock size={12} />}
                              {status.label}
                            </span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {!needsSetup && balance?.pendingMaturityNetCents > 0 && (
            <div className="flex items-start gap-2 px-4 py-3 rounded-xl" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
              <AlertTriangle size={14} color={colors.goldDark} className="mt-0.5 shrink-0" />
              <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                {formatMoney(balance.pendingMaturityNetCents, currency)} en attente de maturation — bientôt disponibles.
              </p>
            </div>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

mkdir -p "pages/api/payouts"
cat > "pages/api/payouts/balance.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Solde disponible = ce qu'on peut honnêtement promettre de reverser sous
// 24h. Pour la zone Europe, Stripe distingue déjà nativement available vs
// pending (et ses frais sont déjà déduits du montant retourné). Pour la
// zone Afrique, voir lib/chariow-earnings.js : on ne rend "disponible" que
// les ventes déjà matures (au-delà du délai réel de règlement Chariow), nettes
// de leur commission — jamais un montant qu'on n'a pas encore en main.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const author = await prisma.author.findUnique({ where: { id: req.authorId } });

    if (author.region === "EUROPE") {
      if (!author.stripeAccountId || !author.stripeOnboarded) {
        return res.status(200).json({ availableCents: 0, currency: "EUR", pendingCents: 0, method: "stripe", connected: false });
      }
      const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
      const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
      const pending = balance.pending.reduce((sum, b) => sum + b.amount, 0);
      return res.status(200).json({
        availableCents: available,
        pendingCents: pending,
        currency: (balance.available[0]?.currency || "eur").toUpperCase(),
        method: "stripe",
        connected: true,
        note: "Montant déjà net des frais Stripe.",
      });
    }

    const balance = await computeAfriqueBalance(author.id);
    return res.status(200).json({
      ...balance,
      method: "momo",
      connected: Boolean(author.momoNumber),
      note: `Net des frais de transaction (${Math.round(balance.commissionRate * 100)}%). Une vente devient disponible ${balance.maturityDays} jours après l'achat.`,
    });
  } catch (error) {
    console.error("Erreur /api/payouts/balance :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/payouts"
cat > "pages/api/payouts/history.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();
  try {
    const payouts = await prisma.payout.findMany({
      where: { authorId: req.authorId },
      orderBy: { createdAt: "desc" },
    });
    return res.status(200).json(payouts);
  } catch (error) {
    console.error("Erreur /api/payouts/history :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/payouts"
cat > "pages/api/payouts/request.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Engagement produit : toute demande de reversement est traitée en moins de
// 24h. dueBy est enregistré pour piloter ce SLA côté opérations. Cet
// engagement reste tenable car on ne valide jamais une demande au-delà du
// solde "disponible" (voir lib/chariow-earnings.js côté Afrique) — on ne
// promet jamais un montant qu'on n'a pas encore réellement reçu.
const SLA_MS = 24 * 60 * 60 * 1000;

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const { amountCents } = req.body;
    if (!amountCents || amountCents <= 0) {
      return res.status(400).json({ error: "Montant invalide" });
    }

    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    if (!author.emailVerified) {
      return res.status(403).json({ error: "Confirmez votre adresse email avant de demander un reversement (vérifiez votre boîte mail, ou renvoyez le lien depuis Paramètres)." });
    }
    const dueBy = new Date(Date.now() + SLA_MS);

    // --- Zone Europe : Stripe déclenche un vrai virement vers le compte connecté ---
    if (author.region === "EUROPE") {
      if (!author.stripeAccountId || !author.stripeOnboarded) {
        return res.status(400).json({ error: "Compte Stripe non connecté" });
      }

      const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
      const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
      if (amountCents > available) {
        return res.status(400).json({ error: "Montant supérieur au solde disponible" });
      }

      const currency = (balance.available[0]?.currency || "eur");
      const stripePayout = await stripe.payouts.create(
        { amount: amountCents, currency },
        { stripeAccount: author.stripeAccountId }
      );

      const payout = await prisma.payout.create({
        data: {
          authorId: author.id,
          amountCents,
          currency: currency.toUpperCase(),
          method: "stripe",
          status: stripePayout.status === "paid" ? "PAID" : "PENDING",
          providerRef: stripePayout.id,
          dueBy,
          processedAt: stripePayout.status === "paid" ? new Date() : null,
        },
      });
      return res.status(201).json(payout);
    }

    // --- Zone Afrique : reversement Mobile Money, plafonné au solde réellement mature ---
    if (!author.momoNumber) {
      return res.status(400).json({ error: "Numéro Mobile Money non configuré" });
    }

    const balance = await computeAfriqueBalance(author.id);
    if (amountCents > balance.availableCents) {
      return res.status(400).json({
        error: "Montant supérieur au solde disponible",
        availableCents: balance.availableCents,
        pendingMaturityNetCents: balance.pendingMaturityNetCents,
      });
    }

    // TODO production : Chariow ne propose pas d'API de transfert vers un
    // tiers (seulement un retrait vers TON propre Mobile Money, voir README
    // §4.1) — ce Payout reste donc à traiter manuellement : retire les fonds
    // sur ton Mobile Money puis envoie la part de l'auteur, avant dueBy.
    const payout = await prisma.payout.create({
      data: {
        authorId: author.id,
        amountCents,
        currency: "XOF",
        method: "momo",
        status: "PENDING",
        dueBy,
      },
    });

    return res.status(201).json(payout);
  } catch (error) {
    console.error("Erreur /api/payouts/request :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

echo "Fichiers mis à jour avec succès."
