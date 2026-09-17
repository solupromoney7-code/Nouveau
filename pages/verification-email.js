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
