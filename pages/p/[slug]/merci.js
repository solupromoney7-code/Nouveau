import { useEffect, useState } from "react";
import { useRouter } from "next/router";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Check, Loader2, Truck } from "lucide-react";
import { colors } from "../../../components/ui";

export default function MerciPage() {
  const router = useRouter();
  const { purchase: purchaseId } = router.query;

  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!purchaseId) return;
    let attempts = 0;
    let cancelled = false;

    async function poll() {
      try {
        const res = await fetch(`/api/public/purchase?id=${purchaseId}`);
        const result = await res.json();
        if (!res.ok) throw new Error(result.error || "Commande introuvable.");
        if (cancelled) return;
        setData(result);
        // Si le paiement n'est pas encore confirmé (webhook pas encore reçu),
        // on revérifie quelques fois avant d'abandonner.
        if (result.status === "pending" && attempts < 8) {
          attempts += 1;
          setTimeout(poll, 2000);
        }
      } catch (err) {
        if (!cancelled) setError(err.message);
      }
    }
    poll();
    return () => { cancelled = true; };
  }, [purchaseId]);

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen flex flex-col items-center px-5 py-10">
      <Head><title>Merci pour votre commande — Plume</title></Head>

      <Link href="/" className="flex items-center gap-2 mb-10">
        <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
          <BookOpen size={14} color={colors.ink} />
        </div>
        <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
      </Link>

      <div className="w-full max-w-md rounded-2xl p-7 md:p-8 text-center" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
        {error ? (
          <>
            <h1 className="font-display text-xl mb-2" style={{ color: colors.textPaper }}>Commande introuvable</h1>
            <p className="font-body text-sm" style={{ color: colors.textMutedLight }}>{error}</p>
          </>
        ) : !data ? (
          <div className="py-8 flex flex-col items-center gap-3">
            <Loader2 size={24} className="animate-spin" color={colors.goldDark} />
            <p className="font-body text-sm" style={{ color: colors.textMutedLight }}>Vérification de votre paiement…</p>
          </div>
        ) : (
          <>
            <div
              className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-5"
              style={{ backgroundColor: data.status === "paid" ? "rgba(79,122,92,0.15)" : "rgba(201,162,39,0.15)" }}
            >
              {data.status === "paid" ? <Check size={26} color={colors.forest} /> : <Loader2 size={24} className="animate-spin" color={colors.goldDark} />}
            </div>
            <h1 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>
              {data.status === "paid" ? "Merci pour votre commande !" : "Paiement en cours de confirmation…"}
            </h1>
            <p className="font-body text-sm mb-6" style={{ color: colors.textMutedLight }}>
              {data.status === "paid"
                ? `Votre exemplaire de "${data.bookTitle}" sera expédié à l'adresse indiquée.`
                : "Cela ne prend généralement que quelques secondes. Vous pouvez garder cette page ouverte."}
            </p>

            <div className="text-left rounded-xl p-4 space-y-2" style={{ backgroundColor: colors.paperDim }}>
              <div className="flex items-center gap-2 mb-1">
                <Truck size={14} color={colors.goldDark} />
                <p className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.textMutedLight }}>Livraison</p>
              </div>
              <p className="font-body text-sm" style={{ color: colors.textPaper }}>{data.buyerName}</p>
              <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>
                {data.shippingAddress}, {data.shippingCity} {data.shippingPostalCode}, {data.shippingCountry}
              </p>
              <p className="font-mono text-[11px] pt-1" style={{ color: colors.textMutedLight }}>
                {data.currency === "EUR" ? (data.amountCents / 100).toFixed(2) : Math.round(data.amountCents / 100).toLocaleString("fr-FR")} {data.currency} — confirmation envoyée à {data.buyerEmail}
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
