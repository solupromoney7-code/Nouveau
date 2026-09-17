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
