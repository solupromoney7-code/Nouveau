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
