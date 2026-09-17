import { useState } from "react";
import { useRouter } from "next/router";
import Link from "next/link";
import { colors, inputStyle, ErrorBanner, Spinner } from "../components/ui";
import AuthShell from "../components/AuthShell";
import { api, saveToken } from "../lib/apiClient";

export default function Inscription() {
  const router = useRouter();
  const [form, setForm] = useState({ name: "", email: "", password: "", region: "AFRIQUE", website: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit() {
    setError("");
    if (!form.name || !form.email || !form.password) {
      setError("Tous les champs sont requis.");
      return;
    }
    if (form.password.length < 8) {
      setError("Le mot de passe doit contenir au moins 8 caractères.");
      return;
    }

    setLoading(true);
    try {
      const data = await api("/api/auth/signup", {
        method: "POST",
        auth: false,
        body: {
          name: form.name,
          email: form.email,
          password: form.password,
          region: form.region,
          website: form.website, // honeypot — doit rester vide
        },
      });
      if (data?.token) {
        saveToken(data.token);
        router.push("/verification-email?email=" + encodeURIComponent(form.email));
      } else {
        setError("Réponse inattendue du serveur. Réessayez.");
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthShell
      title="Créer votre compte"
      subtitle="7 jours d’essai gratuit, sans carte requise pour découvrir."
      footer={
        <Link href="/connexion" className="font-mono text-[11px] underline" style={{ color: colors.textPaperDim }}>
          Déjà un compte ? Se connecter
        </Link>
      }
    >
      {/* Honeypot anti-bot : invisible pour un humain */}
      <input
        type="text"
        name="website"
        tabIndex={-1}
        autoComplete="off"
        value={form.website}
        onChange={(e) => setForm({ ...form, website: e.target.value })}
        style={{ position: "absolute", left: "-9999px", width: 1, height: 1 }}
        aria-hidden="true"
      />

      <ErrorBanner message={error} />

      <input
        placeholder="Nom et prénom"
        value={form.name}
        onChange={(e) => setForm({ ...form, name: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="email"
        placeholder="Email"
        value={form.email}
        onChange={(e) => setForm({ ...form, email: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />
      <input
        type="password"
        placeholder="Mot de passe (8 caractères minimum)"
        value={form.password}
        onChange={(e) => setForm({ ...form, password: e.target.value })}
        className="rounded-lg px-3 py-2.5 font-body text-sm"
        style={inputStyle}
      />

      <div className="flex rounded-full p-1 mt-1" style={{ backgroundColor: colors.paperDim }}>
        {["AFRIQUE", "EUROPE"].map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => setForm({ ...form, region: r })}
            className="flex-1 py-1.5 rounded-full font-body text-xs font-semibold"
            style={{
              backgroundColor: form.region === r ? colors.gold : "transparent",
              color: form.region === r ? colors.ink : colors.textPaperDim,
            }}
          >
            {r === "AFRIQUE" ? "Afrique" : "France / Europe"}
          </button>
        ))}
      </div>

      <button
        onClick={handleSubmit}
        disabled={loading}
        className="py-3 rounded-xl font-body font-semibold text-sm mt-2 flex items-center justify-center gap-2"
        style={{ backgroundColor: colors.gold, color: colors.ink, opacity: loading ? 0.6 : 1 }}
      >
        {loading && <Spinner size={14} color={colors.ink} />}
        {loading ? "Création…" : "Créer mon compte"}
      </button>
    </AuthShell>
  );
}
