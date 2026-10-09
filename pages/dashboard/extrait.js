import { useState } from "react";
import { upload } from "@vercel/blob/client";
import { Upload, Check, Copy, ExternalLink, Loader2, FileText, Video } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api, getToken } from "../../lib/apiClient";

export default function DashboardExtrait() {
  const { author, loading: authLoading } = useAuthGuard();

  // idle -> uploadingBook -> (book prêt) -> uploadingPdf -> (pdf prêt) -> saving -> done
  const [stage, setStage] = useState("idle");
  const [bookFileName, setBookFileName] = useState("");
  const [pdfFileName, setPdfFileName] = useState("");
  const [error, setError] = useState("");
  const [book, setBook] = useState(null);
  const [pdfUrl, setPdfUrl] = useState("");
  const [videoUrl, setVideoUrl] = useState("");
  const [extractPage, setExtractPage] = useState(null);
  const [copied, setCopied] = useState(false);

  async function handleBookFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError("");
    setBookFileName(file.name);
    setStage("uploadingBook");

    try {
      const blob = await upload(file.name, file, {
        access: "public",
        handleUploadUrl: "/api/books/upload",
        clientPayload: JSON.stringify({ token: getToken() }),
      });

      const data = await api("/api/books/register", {
        method: "POST",
        body: { url: blob.url, filename: file.name },
      });
      setBook(data);
      setStage("idle");
    } catch (err) {
      setError(err.message || "Échec de l’upload");
      setStage("idle");
    }
  }

  async function handlePdfFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError("");
    setPdfFileName(file.name);
    setStage("uploadingPdf");

    try {
      const blob = await upload(file.name, file, {
        access: "public",
        handleUploadUrl: "/api/books/upload",
        clientPayload: JSON.stringify({ token: getToken() }),
      });
      setPdfUrl(blob.url);
      setStage("idle");
    } catch (err) {
      setError(err.message || "Échec de l’upload");
      setStage("idle");
    }
  }

  async function handleCreate() {
    if (!book || !pdfUrl) return;
    setError("");
    setStage("saving");
    try {
      const data = await api("/api/extract-pages", {
        method: "POST",
        body: { bookId: book.id, pdfUrl, ...(videoUrl && { videoUrl }) },
      });
      setExtractPage(data);
      setStage("done");
    } catch (err) {
      setError(err.message);
      setStage("idle");
    }
  }

  function reset() {
    setStage("idle");
    setBookFileName("");
    setPdfFileName("");
    setBook(null);
    setPdfUrl("");
    setVideoUrl("");
    setExtractPage(null);
    setError("");
  }

  const publicUrl = extractPage
    ? `${typeof window !== "undefined" ? window.location.origin : ""}/e/${extractPage.slug}`
    : "";

  return (
    <DashboardShell active="extrait" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Capture de leads</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Page d’extrait</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : stage === "done" && extractPage ? (
        <div className="max-w-xl">
          <div
            className="flex items-center justify-between gap-3 rounded-xl px-4 py-3 mb-4 flex-wrap"
            style={{ backgroundColor: "rgba(79,122,92,0.15)", border: `1px solid ${colors.forest}` }}
          >
            <div className="flex items-center gap-2">
              <Check size={16} color={colors.forest} />
              <p className="font-body text-sm" style={{ color: colors.paper }}>Page d’extrait créée</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => { navigator.clipboard?.writeText(publicUrl); setCopied(true); setTimeout(() => setCopied(false), 1500); }}
                className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
              >
                {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copié" : "Copier le lien"}
              </button>
              <a
                href={`/e/${extractPage.slug}`}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                <ExternalLink size={13} /> Voir la page
              </a>
            </div>
          </div>
          <button onClick={reset} className="font-body text-xs underline" style={{ color: colors.mist }}>
            Créer une nouvelle page d’extrait
          </button>
        </div>
      ) : (
        <div className="rounded-2xl p-6 md:p-10 max-w-xl" style={{ backgroundColor: colors.paper }}>
          <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
            Étape 1 sur 2
          </p>
          <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>Votre livre</h2>
          <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
            Identifie le livre concerné par cette page d’extrait.
          </p>

          <ErrorBanner message={error} />

          <label
            onClick={(e) => { if (stage === "uploadingBook") e.preventDefault(); }}
            htmlFor="book-upload-input-extrait"
            className="flex flex-col items-center justify-center text-center rounded-xl py-10 px-4 cursor-pointer border-2 border-dashed transition-colors mt-3"
            style={{ borderColor: book ? colors.forest : colors.mist }}
          >
            <input
              id="book-upload-input-extrait"
              type="file"
              accept=".pdf,.epub"
              className="hidden"
              onChange={handleBookFile}
            />
            {stage === "uploadingBook" ? (
              <>
                <Spinner size={24} color={colors.goldDark} />
                <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Envoi de {bookFileName}…</p>
              </>
            ) : book ? (
              <>
                <Check size={26} color={colors.forest} />
                <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>{bookFileName}</p>
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

          {book && (
            <>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-2 mt-8" style={{ color: colors.goldDark }}>
                Étape 2 sur 2
              </p>
              <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>L’extrait à offrir</h2>
              <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
                Le PDF que vos visiteurs recevront gratuitement en échange de leur email.
              </p>

              <label
                onClick={(e) => { if (stage === "uploadingPdf") e.preventDefault(); }}
                htmlFor="pdf-upload-input-extrait"
                className="flex flex-col items-center justify-center text-center rounded-xl py-10 px-4 cursor-pointer border-2 border-dashed transition-colors"
                style={{ borderColor: pdfUrl ? colors.forest : colors.mist }}
              >
                <input
                  id="pdf-upload-input-extrait"
                  type="file"
                  accept=".pdf"
                  className="hidden"
                  onChange={handlePdfFile}
                />
                {stage === "uploadingPdf" ? (
                  <>
                    <Spinner size={24} color={colors.goldDark} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Envoi de {pdfFileName}…</p>
                  </>
                ) : pdfUrl ? (
                  <>
                    <Check size={26} color={colors.forest} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>{pdfFileName}</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>Fichier prêt — cliquez pour changer</p>
                  </>
                ) : (
                  <>
                    <FileText size={26} color={colors.mist} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Cliquez pour choisir votre extrait en PDF</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>PDF uniquement — 50 Mo max</p>
                  </>
                )}
              </label>

              <div className="mt-4">
                <p className="font-mono text-[10px] uppercase tracking-wide mb-1 flex items-center gap-1.5" style={{ color: colors.textPaperDim }}>
                  <Video size={12} /> Lien vidéo (optionnel)
                </p>
                <input
                  type="url"
                  value={videoUrl}
                  onChange={(e) => setVideoUrl(e.target.value)}
                  placeholder="https://youtube.com/..."
                  className="w-full rounded-lg px-3 py-2 font-body text-sm"
                  style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
                />
              </div>

              <button
                disabled={!pdfUrl || stage === "saving"}
                onClick={handleCreate}
                className="w-full mt-6 py-3 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
                style={{
                  backgroundColor: colors.gold, color: colors.ink,
                  opacity: pdfUrl && stage !== "saving" ? 1 : 0.4,
                  cursor: pdfUrl && stage !== "saving" ? "pointer" : "not-allowed",
                }}
              >
                {stage === "saving" ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                {stage === "saving" ? "Création…" : "Créer ma page d’extrait"}
              </button>
            </>
          )}
        </div>
      )}
    </DashboardShell>
  );
}

