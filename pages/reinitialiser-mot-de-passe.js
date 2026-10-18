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
