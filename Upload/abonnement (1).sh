#!/bin/bash
set -e
echo "Ajoute la page Abonnement"

mkdir -p "$(dirname "pages/api/subscriptions/checkout.js")"
cat > "pages/api/subscriptions/checkout.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { initChariowCheckout } from "../../../lib/chariow";

// Un seul produit Chariow pour l'abonnement Plume, facturé dans la devise
// de la zone de l'auteur grâce au paramètre payment_currency (conversion
// automatique gérée par Chariow). Crée ce produit une fois dans ton
// dashboard Chariow et renseigne son ID dans CHARIOW_SUBSCRIPTION_PRODUCT_ID.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    const [firstName, ...rest] = author.name.split(" ");

    const result = await initChariowCheckout({
      productId: process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
      email: author.email,
      firstName: firstName || author.name,
      lastName: rest.join(" ") || author.name,
      redirectUrl: `${process.env.APP_URL}/dashboard/abonnement?paiement=retour`,
      paymentCurrency: author.region === "EUROPE" ? "EUR" : "XOF",
      metadata: { authorId: author.id, kind: "subscription" },
    });

    if (result.step === "already_purchased") {
      return res.status(200).json({ status: "already_active" });
    }

    return res.status(200).json({ url: result.payment?.checkout_url });
  } catch (error) {
    console.error("Erreur /api/subscriptions/checkout :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

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
  const price = isAfrique ? "3 000 FCFA" : "15 €";
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

echo "Terminé."
