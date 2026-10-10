import { useEffect, useState } from "react";
import Link from "next/link";
import { Store, Copy, Check, ExternalLink, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

function formatPrice(cents, currency) {
  if (cents == null) return "—";
  const amount = cents / 100;
  if (currency === "EUR") return `${amount.toFixed(2)} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

function slugifyPreview(value) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default function DashboardBoutique() {
  const { author, loading: authLoading } = useAuthGuard();

  const [store, setStore] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [slugInput, setSlugInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");

  const [copied, setCopied] = useState(false);
  const [origin, setOrigin] = useState("");

  useEffect(() => {
    if (typeof window !== "undefined") setOrigin(window.location.origin);
  }, []);

  useEffect(() => {
    if (!author) return;
    api("/api/authors/store")
      .then((data) => {
        setStore(data);
        if (!data.storeSlug && author.name) setSlugInput(slugifyPreview(author.name));
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  async function handleCreateStore(e) {
    e.preventDefault();
    setSaveError("");
    setSaving(true);
    try {
      const data = await api("/api/authors/store", { method: "PUT", body: { storeSlug: slugInput } });
      setStore((s) => ({ ...s, storeSlug: data.storeSlug }));
    } catch (err) {
      setSaveError(err.message);
    } finally {
      setSaving(false);
    }
  }

  function handleCopy() {
    const url = `${origin}/boutique/${store.storeSlug}`;
    navigator.clipboard?.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  const publishedCount = store?.books?.filter((b) => b.published).length || 0;

  return (
    <DashboardShell active="boutique" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Vitrine publique</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Ma boutique</h1>
      </header>

      {authLoading || loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl space-y-6">
          <ErrorBanner message={error} />

          <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <div className="flex items-center gap-2 mb-1">
              <Store size={16} color={colors.goldDark} />
              <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>
                {store?.storeSlug ? "Votre boutique" : "Créer votre boutique"}
              </h2>
            </div>

            {!store?.storeSlug ? (
              <>
                <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
                  Une page unique qui liste tous vos livres publiés, à partager en un lien (réseaux sociaux, bio, messages).
                </p>
                <form onSubmit={handleCreateStore} className="space-y-3 max-w-md">
                  <ErrorBanner message={saveError} />
                  <div>
                    <p className="font-mono text-[10px] uppercase tracking-wide mb-1.5" style={{ color: colors.mist }}>
                      Adresse de votre boutique
                    </p>
                    <div className="flex items-center rounded-lg overflow-hidden" style={{ backgroundColor: colors.paperDim }}>
                      <span className="pl-3 font-body text-sm shrink-0" style={{ color: colors.textPaperDim }}>
                        {origin}/boutique/
                      </span>
                      <input
                        value={slugInput}
                        onChange={(e) => setSlugInput(e.target.value)}
                        className="flex-1 min-w-0 px-2 py-2 font-body text-sm bg-transparent"
                        style={{ color: colors.textPaper, border: "none", outline: "none" }}
                      />
                    </div>
                  </div>
                  <button
                    type="submit"
                    disabled={saving}
                    className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
                    style={{ backgroundColor: colors.gold, color: colors.ink, opacity: saving ? 0.6 : 1 }}
                  >
                    {saving && <Loader2 size={14} className="animate-spin" />}
                    {saving ? "Création…" : "Créer ma boutique"}
                  </button>
                </form>
              </>
            ) : (
              <>
                <p className="font-body text-sm mb-3" style={{ color: colors.textPaperDim }}>
                  {publishedCount > 0
                    ? `${publishedCount} livre${publishedCount > 1 ? "s" : ""} publié${publishedCount > 1 ? "s" : ""} visible${publishedCount > 1 ? "s" : ""} sur votre boutique.`
                    : "Aucun livre publié pour l’instant — publiez une page de vente pour qu’elle apparaisse ici."}
                </p>
                <div className="flex items-center gap-2 flex-wrap">
                  <div className="flex items-center rounded-lg overflow-hidden" style={{ backgroundColor: colors.paperDim }}>
                    <span className="px-3 py-2 font-mono text-xs" style={{ color: colors.textPaper }}>
                      {origin}/boutique/{store.storeSlug}
                    </span>
                  </div>
                  <button
                    onClick={handleCopy}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-lg font-body text-xs font-semibold"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
                  >
                    {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copié" : "Copier"}
                  </button>
                  <Link
                    href={`/boutique/${store.storeSlug}`}
                    target="_blank"
                    className="flex items-center gap-1.5 px-3 py-2 rounded-lg font-body text-xs font-semibold"
                    style={{ backgroundColor: colors.gold, color: colors.ink }}
                  >
                    Voir ma boutique <ExternalLink size={13} />
                  </Link>
                </div>
              </>
            )}
          </section>

          {store?.books?.length > 0 && (
            <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-4" style={{ color: colors.goldDark }}>
                Vos livres
              </p>
              <div className="space-y-2">
                {store.books.map((b) => (
                  <div key={b.id} className="flex items-center justify-between gap-3 px-3 py-2.5 rounded-lg" style={{ backgroundColor: colors.paperDim }}>
                    <div className="min-w-0">
                      <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{b.title}</p>
                      <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>{formatPrice(b.priceCents, b.currency)}</p>
                    </div>
                    <span
                      className="shrink-0 font-mono text-[10px] px-2 py-1 rounded-full"
                      style={{
                        backgroundColor: b.published ? "rgba(79,122,92,0.12)" : "rgba(122,46,59,0.1)",
                        color: b.published ? colors.forest : colors.wine,
                      }}
                    >
                      {b.published ? "Publié" : "Non publié"}
                    </span>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
