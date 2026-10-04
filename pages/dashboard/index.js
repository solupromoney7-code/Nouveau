import { useState, useRef } from "react";
import { Sparkles, Upload, Check, Copy, ExternalLink, Loader2, Smartphone, CreditCard } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, BookCover, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api, getToken } from "../../lib/apiClient";

function EditableParagraph({ value, onChange }) {
  const [editing, setEditing] = useState(false);
  if (editing) {
    return (
      <textarea
        autoFocus
        defaultValue={value}
        onBlur={(e) => { onChange(e.target.value); setEditing(false); }}
        className="w-full font-body text-[15px] leading-relaxed bg-transparent border rounded-lg p-2 resize-none"
        style={{ borderColor: colors.gold, color: colors.textPaper, minHeight: 90 }}
      />
    );
  }
  return (
    <p
      onClick={() => setEditing(true)}
      title="Cliquer pour modifier"
      className="font-body text-[15px] leading-relaxed cursor-text rounded-lg p-2 -m-2 hover:bg-black hover:bg-opacity-5 transition-colors"
      style={{ color: colors.textPaperDim }}
    >
      {value}
    </p>
  );
}

export default function DashboardVente() {
  const { author, loading: authLoading } = useAuthGuard();

  const [stage, setStage] = useState("idle"); // idle -> uploading -> generating -> done
  const [fileName, setFileName] = useState("");
  const [error, setError] = useState("");
  const [book, setBook] = useState(null);
  const [salesPage, setSalesPage] = useState(null);
  const [priceInput, setPriceInput] = useState("12");
  const [copied, setCopied] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const fileInputRef = useRef(null);

  const currency = author?.region === "EUROPE" ? "EUR" : "XOF";
  const currencyLabel = currency === "EUR" ? "€" : "FCFA";

  async function handleFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError("");
    setFileName(file.name);
    setStage("uploading");

    try {
      const res = await fetch("/api/books/upload", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${getToken()}`,
          "x-filename": file.name,
          "Content-Type": file.type || "application/octet-stream",
        },
        body: file,
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Échec de l’upload");
      setBook(data);
      setStage("fileReady");
    } catch (err) {
      setError(err.message);
      setStage("idle");
    }
  }

  async function handleGenerate() {
    if (!book) return;
    setError("");
    setStage("generating");
    try {
      const priceCents = Math.round(Number(priceInput) * 100);
      const data = await api("/api/sales-pages", {
        method: "POST",
        body: { bookId: book.id, priceCents, currency },
      });
      setSalesPage(data);
      setStage("done");
    } catch (err) {
      setError(err.message);
      setStage("fileReady");
    }
  }

  async function handlePublish() {
    setPublishing(true);
    try {
      const updated = await api(`/api/sales-pages/${salesPage.id}`, {
        method: "PATCH",
        body: { published: true },
      });
      setSalesPage(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setPublishing(false);
    }
  }

  async function updateField(field, value) {
    setSalesPage((sp) => ({ ...sp, [field]: value }));
    try {
      await api(`/api/sales-pages/${salesPage.id}`, { method: "PATCH", body: { [field]: value } });
    } catch (err) {
      setError(err.message);
    }
  }

  function reset() {
    setStage("idle");
    setFileName("");
    setBook(null);
    setSalesPage(null);
    setError("");
  }

  const publicUrl = salesPage ? `${typeof window !== "undefined" ? window.location.origin : ""}/p/${salesPage.slug}` : "";

  return (
    <DashboardShell active="vente" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Génération IA</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Page de vente</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : (
        <>
          {(stage === "idle" || stage === "uploading" || stage === "fileReady") && (
            <div className="rounded-2xl p-6 md:p-10 max-w-xl" style={{ backgroundColor: colors.paper }}>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Étape 1 sur 2</p>
              <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>Téléchargez votre livre</h2>
              <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
                L’IA lit votre manuscrit et rédige votre page de vente à votre place.
              </p>

              <ErrorBanner message={error} />

              <input ref={fileInputRef} type="file" accept=".pdf,.epub" className="hidden" onChange={handleFile} />
              <label
                onClick={(e) => { if (stage === "uploading") e.preventDefault(); }}
                htmlFor="book-upload-input"
                className="flex flex-col items-center justify-center text-center rounded-xl py-10 px-4 cursor-pointer border-2 border-dashed transition-colors mt-3"
                style={{ borderColor: stage === "fileReady" ? colors.forest : colors.mist }}
                onDrop={(e) => e.preventDefault()}
              >
                <input id="book-upload-input" type="file" accept=".pdf,.epub" className="hidden" onChange={handleFile} />
                {stage === "uploading" ? (
                  <>
                    <Spinner size={24} color={colors.goldDark} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Envoi de {fileName}…</p>
                  </>
                ) : stage === "fileReady" ? (
                  <>
                    <Check size={26} color={colors.forest} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>{fileName}</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>Fichier prêt — cliquez pour changer</p>
                  </>
                ) : (
                  <>
                    <Upload size={26} color={colors.mist} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Cliquez pour choisir un fichier</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>PDF, EPUB — 50 Mo max</p>
                  </>
                )}
              </label>

              {stage === "fileReady" && (
                <div className="mt-4">
                  <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
                    Prix de vente ({currencyLabel})
                  </p>
                  <input
                    type="number"
                    value={priceInput}
                    onChange={(e) => setPriceInput(e.target.value)}
                    className="w-32 rounded-lg px-3 py-2 font-body text-sm"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
                  />
                </div>
              )}

              <button
                disabled={stage !== "fileReady"}
                onClick={handleGenerate}
                className="w-full mt-6 py-3 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
                style={{
                  backgroundColor: colors.gold, color: colors.ink,
                  opacity: stage === "fileReady" ? 1 : 0.4,
                  cursor: stage === "fileReady" ? "pointer" : "not-allowed",
                }}
              >
                <Sparkles size={16} /> Générer ma page de vente
              </button>
            </div>
          )}

          {stage === "generating" && (
            <div className="rounded-2xl p-6 md:p-10 max-w-xl flex flex-col items-center text-center" style={{ backgroundColor: colors.paper }}>
              <Spinner size={28} color={colors.goldDark} />
              <h2 className="font-display text-xl mt-4" style={{ color: colors.textPaper }}>L’IA rédige votre page…</h2>
              <p className="font-body text-sm mt-1" style={{ color: colors.textPaperDim }}>Ça prend quelques secondes.</p>
            </div>
          )}

          {stage === "done" && salesPage && (
            <div className="max-w-3xl">
              <ErrorBanner message={error} />

              <div
                className="flex items-center justify-between gap-3 rounded-xl px-4 py-3 mb-4 mt-3 flex-wrap"
                style={{
                  backgroundColor: salesPage.published ? "rgba(79,122,92,0.15)" : "rgba(201,162,39,0.12)",
                  border: `1px solid ${salesPage.published ? colors.forest : colors.gold}`,
                }}
              >
                <div className="flex items-center gap-2">
                  {salesPage.published ? <Check size={16} color={colors.forest} /> : <Sparkles size={16} color={colors.gold} />}
                  <p className="font-body text-sm" style={{ color: colors.paper }}>
                    {salesPage.published ? "Page publiée" : "Page générée — pas encore publiée"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {salesPage.published && (
                    <>
                      <button
                        onClick={() => { navigator.clipboard?.writeText(publicUrl); setCopied(true); setTimeout(() => setCopied(false), 1500); }}
                        className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                        style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
                      >
                        {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copié" : "Copier le lien"}
                      </button>
                      <a
                        href={`/p/${salesPage.slug}`}
                        target="_blank"
                        rel="noreferrer"
                        className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                        style={{ backgroundColor: colors.gold, color: colors.ink }}
                      >
                        <ExternalLink size={13} /> Voir la page
                      </a>
                    </>
                  )}
                  {!salesPage.published && (
                    <button
                      onClick={handlePublish}
                      disabled={publishing}
                      className="flex items-center gap-1.5 font-body text-xs px-4 py-1.5 rounded-lg font-semibold"
                      style={{ backgroundColor: colors.gold, color: colors.ink }}
                    >
                      {publishing && <Spinner size={12} color={colors.ink} />}
                      {publishing ? "Publication…" : "Publier"}
                    </button>
                  )}
                </div>
              </div>

              <div className="rounded-2xl p-6 md:p-10" style={{ backgroundColor: colors.paper }}>
                <div className="flex flex-col md:flex-row gap-6 md:gap-8">
                  <BookCover title={book?.title || "Votre livre"} author={author?.name || ""} />
                  <div className="flex-1 min-w-0">
                    <h2 className="font-display text-2xl md:text-3xl mb-6" style={{ color: colors.textPaper }}>{book?.title}</h2>

                    <p className="font-mono text-[11px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Le problème</p>
                    <EditableParagraph value={salesPage.problem} onChange={(v) => updateField("problem", v)} />

                    <p className="font-mono text-[11px] uppercase tracking-widest mt-5 mb-1" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
                    <EditableParagraph value={salesPage.why} onChange={(v) => updateField("why", v)} />

                    <p className="font-mono text-[11px] uppercase tracking-widest mt-5 mb-1" style={{ color: colors.goldDark }}>La solution</p>
                    <EditableParagraph value={salesPage.solution} onChange={(v) => updateField("solution", v)} />
                  </div>
                </div>

                <div className="mt-8 pt-6 border-t flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4" style={{ borderColor: colors.paperDim }}>
                  <p className="font-body text-lg font-semibold" style={{ color: colors.textPaper }}>
                    {(salesPage.priceCents / 100).toFixed(2)} {currencyLabel}
                  </p>
                  <div className="flex items-center gap-3 font-mono text-[11px]" style={{ color: colors.mist }}>
                    {currency === "EUR" ? (<><CreditCard size={14} /> Carte bancaire</>) : (<><Smartphone size={14} /> Mobile Money</>)}
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between mt-3">
                <p className="font-mono text-[11px]" style={{ color: colors.mist }}>Cliquez un paragraphe pour le modifier — enregistré automatiquement.</p>
                <button onClick={reset} className="font-mono text-[11px] underline" style={{ color: colors.mist }}>Recommencer</button>
              </div>
            </div>
          )}
        </>
      )}
    </DashboardShell>
  );
}
