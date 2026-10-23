import { useState } from "react";
import { useRouter } from "next/router";
import { colors } from "../components/ui";

export default function Desinscription() {
  const router = useRouter();
  const { l, t } = router.query;
  const [state, setState] = useState("idle"); // idle | loading | done | error

  async function handleConfirm() {
    setState("loading");
    try {
      const res = await fetch(`/api/public/unsubscribe?l=${encodeURIComponent(l)}&t=${encodeURIComponent(t)}`, { method: "POST" });
      setState(res.ok ? "done" : "error");
    } catch {
      setState("error");
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-4" style={{ backgroundColor: colors.paper }}>
      <div className="w-full max-w-md rounded-2xl p-8 text-center" style={{ backgroundColor: "#FFFFFF" }}>
        <h1 className="font-display text-2xl mb-3" style={{ color: colors.textPaper }}>Désinscription</h1>
        {state === "done" ? (
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>
            C’est fait : vous ne recevrez plus d’emails de cet auteur.
          </p>
        ) : (
          <>
            <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
              Confirmez-vous ne plus vouloir recevoir d’emails de cet auteur ?
            </p>
            {state === "error" && (
              <p className="font-body text-sm mb-3" style={{ color: "#B3261E" }}>Lien invalide ou expiré.</p>
            )}
            <button
              onClick={handleConfirm}
              disabled={state === "loading" || !l || !t}
              className="px-5 py-2.5 rounded-lg font-body font-semibold text-sm"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: state === "loading" ? 0.6 : 1 }}
            >
              {state === "loading" ? "Un instant…" : "Me désinscrire"}
            </button>
          </>
        )}
      </div>
    </main>
  );
}
