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
                {author?.region === "EUROPE" ? "Ajoutez votre lien de paiement" : "Renseignez votre numéro Mobile Money"}
              </h2>
              <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
                {author?.region === "EUROPE"
                  ? "Pour recevoir vos paiements, collez votre lien de paiement Stripe depuis Paramètres."
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
