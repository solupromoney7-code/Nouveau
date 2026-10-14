#!/bin/bash
set -e
echo "Application des modifications (couvertures de livre, titres, boutique)..."

mkdir -p "components"
cat > "components/ui.js" << 'PLUME_EOF_MARKER'
// Composants visuels partagés — repris du prototype validé, pour que le
// vrai site ait exactement la même identité visuelle.

export const colors = {
  ink: "#1C2033",
  inkDeep: "#14172A",
  paper: "#F7F3E9",
  paperDim: "#EDE6D3",
  gold: "#C9A227",
  goldDark: "#A5821A",
  wine: "#7A2E3B",
  mist: "#9498AC",
  forest: "#4F7A5C",
  textPaper: "#241F17",
  textPaperDim: "#4A4232",
  bgLight: "#FBF9F4",
  bgLightAlt: "#F4F1E9",
  sage: "#6B9080",
  sageDark: "#547567",
  sky: "#5B7FA6",
  textMutedLight: "#70748C",
};

export const inputStyle = {
  backgroundColor: colors.paperDim,
  color: colors.textPaper,
  border: "none",
};

// Couverture de livre. Si une vraie image a été fournie par l'auteur, elle
// est affichée en pleine case (comme une vraie couverture de livre). Sinon,
// une couverture générée (dégradé + titre + auteur) sert de solution de
// repli élégante.
export function BookCover({ title, author, imageUrl, size = "md" }) {
  const dims =
    size === "sm" ? { w: 88, h: 128 } : size === "lg" ? { w: 160, h: 230 } : { w: 120, h: 172 };

  if (imageUrl) {
    return (
      <div
        className="shrink-0 rounded-md overflow-hidden shadow-lg"
        style={{
          width: dims.w,
          height: dims.h,
          border: "1px solid rgba(28,32,51,0.12)",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={imageUrl}
          alt={title}
          className="w-full h-full object-cover"
          style={{ display: "block" }}
        />
      </div>
    );
  }

  return (
    <div
      className="shrink-0 rounded-md flex flex-col justify-between p-3 shadow-lg"
      style={{
        width: dims.w,
        height: dims.h,
        backgroundImage: `linear-gradient(150deg, ${colors.wine}, ${colors.ink})`,
        border: "1px solid rgba(201,162,39,0.35)",
      }}
    >
      <div className="w-6" style={{ height: 2, backgroundColor: colors.gold }} />
      <p className="font-display leading-tight" style={{ color: colors.paper, fontSize: size === "sm" ? 12 : 15 }}>
        {title}
      </p>
      <p className="font-mono uppercase tracking-wide" style={{ color: colors.mist, fontSize: 9 }}>
        {author}
      </p>
    </div>
  );
}

// Champ de texte "cliquer pour modifier" sur une seule ligne — utilisé pour
// le titre du livre dans le tableau de bord.
export function EditableTitle({ value, onChange, onBlurExtra, className, style, placeholder }) {
  return (
    <input
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      className={className}
      style={{
        background: "transparent",
        border: "none",
        outline: "none",
        borderBottom: "1px dashed transparent",
        ...style,
      }}
      onFocus={(e) => { e.target.style.borderBottomColor = colors.gold; }}
      onBlur={(e) => {
        e.target.style.borderBottomColor = "transparent";
        if (onBlurExtra) onBlurExtra();
      }}
    />
  );
}

// Bloc d'erreur réutilisé sur tous les formulaires.
export function ErrorBanner({ message }) {
  if (!message) return null;
  return (
    <div
      className="rounded-lg px-3 py-2.5 font-body text-xs"
      style={{ backgroundColor: "rgba(122,46,59,0.1)", border: `1px solid ${colors.wine}`, color: colors.wine }}
    >
      {message}
    </div>
  );
}

export function Spinner({ size = 16, color }) {
  return (
    <span
      className="inline-block animate-spin rounded-full"
      style={{
        width: size,
        height: size,
        border: `2px solid ${color || colors.gold}`,
        borderTopColor: "transparent",
      }}
    />
  );
}
PLUME_EOF_MARKER

mkdir -p "lib"
cat > "lib/text.js" << 'PLUME_EOF_MARKER'
// Petits utilitaires texte partagés (titres de livres, etc.)

const STOPWORDS = new Set([
  "de", "du", "des", "la", "le", "les", "l", "et", "à", "a", "en", "un", "une",
  "au", "aux", "pour", "sur", "dans", "avec", "ou", "qui", "que", "se", "ce",
  "ses", "son", "sa", "par", "sans",
]);

// Transforme un nom de fichier brut ("5_LANGUAGE_DE_L_AOUR_2") en titre
// lisible ("5 Language de l'Aour 2") : underscores/points/tirets -> espaces,
// casse normalisée, petits mots français en minuscule sauf en tête de titre,
// et un "L" isolé recollé au mot suivant ("L'Amour") plutôt que laissé seul.
export function humanizeTitle(raw) {
  if (!raw) return "";
  const cleaned = String(raw).replace(/[_\-.]+/g, " ").replace(/\s+/g, " ").trim();
  if (!cleaned) return String(raw);

  const words = cleaned.split(" ");
  const result = [];

  for (let i = 0; i < words.length; i++) {
    const w = words[i];
    if (/^[0-9]+$/.test(w)) {
      result.push(w);
      continue;
    }
    const lower = w.toLocaleLowerCase("fr-FR");
    if (lower === "l" && i < words.length - 1 && /^[aeiouéèêàâîïôûh]/i.test(words[i + 1])) {
      const nextLower = words[i + 1].toLocaleLowerCase("fr-FR");
      const nextCap = nextLower.charAt(0).toLocaleUpperCase("fr-FR") + nextLower.slice(1);
      result.push("L’" + nextCap);
      i++;
      continue;
    }
    const isFirst = result.length === 0;
    if (!isFirst && STOPWORDS.has(lower)) {
      result.push(lower);
      continue;
    }
    result.push(lower.charAt(0).toLocaleUpperCase("fr-FR") + lower.slice(1));
  }

  return result.join(" ");
}
PLUME_EOF_MARKER

mkdir -p "pages/api/books"
cat > "pages/api/books/register.js" << 'PLUME_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { humanizeTitle } from "../../../lib/text";

// Finalise l'upload "client" du livre (voir /api/books/upload) : le fichier
// est déjà sur Vercel Blob à ce stade, cette route ne fait qu'enregistrer sa
// référence en base, associée à l'auteur connecté. Appelée directement par
// le navigateur juste après la fin de l'upload.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { url, filename } = req.body || {};
  if (!url || !filename) {
    return res.status(400).json({ error: "url et filename requis" });
  }
  // Vérifie que l'URL pointe bien vers notre propre stockage Vercel Blob,
  // pas vers un fichier arbitraire fourni par le client.
  if (!/^https:\/\/[a-z0-9]+\.public\.blob\.vercel-storage\.com\//.test(url)) {
    return res.status(400).json({ error: "URL de fichier invalide" });
  }

  const cleanName = String(filename).replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 150);
  // Le nom de fichier brut (souvent plein d'underscores/majuscules) est
  // automatiquement mis en forme pour donner un titre présentable par
  // défaut ; l'auteur peut ensuite le modifier depuis le tableau de bord.
  const title = humanizeTitle(cleanName.replace(/\.[^/.]+$/, ""));

  const book = await prisma.book.create({
    data: {
      authorId: req.authorId,
      title,
      fileUrl: url,
    },
  });

  return res.status(201).json(book);
});
PLUME_EOF_MARKER

mkdir -p "pages/api/books"
cat > "pages/api/books/[id].js" << 'PLUME_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Modifie un livre existant (titre affiché, image de couverture). Utilisée
// par les pages "Page de vente" et "Page d'extrait" du tableau de bord.
export default requireAuth(async function handler(req, res) {
  const { id } = req.query;

  try {
    const book = await prisma.book.findUnique({ where: { id } });
    if (!book || book.authorId !== req.authorId) {
      return res.status(404).json({ error: "Livre introuvable" });
    }

    if (req.method === "PATCH") {
      const data = {};

      if (typeof req.body?.title === "string") {
        const title = req.body.title.trim().slice(0, 200);
        if (!title) return res.status(400).json({ error: "Le titre ne peut pas être vide." });
        data.title = title;
      }

      if (typeof req.body?.coverImageUrl === "string") {
        const url = req.body.coverImageUrl.trim();
        if (url && !/^https:\/\/[a-z0-9]+\.public\.blob\.vercel-storage\.com\//.test(url)) {
          return res.status(400).json({ error: "URL d'image invalide" });
        }
        data.coverImageUrl = url || null;
      }

      if (Object.keys(data).length === 0) {
        return res.status(400).json({ error: "Rien à modifier." });
      }

      const updated = await prisma.book.update({ where: { id }, data });
      return res.status(200).json(updated);
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/books/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
PLUME_EOF_MARKER

mkdir -p "pages/api/books"
cat > "pages/api/books/upload-cover.js" << 'PLUME_EOF_MARKER'
import { handleUpload } from "@vercel/blob/client";
import { verifyToken } from "../../../lib/auth";

// Même principe que /api/books/upload mais pour les images de couverture
// (photo du livre) : upload direct navigateur -> Vercel Blob, limité aux
// formats image et à une taille raisonnable.
export default async function handler(req, res) {
  try {
    const body = req.body;

    const jsonResponse = await handleUpload({
      body,
      request: req,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        let payload;
        try {
          payload = JSON.parse(clientPayload || "{}");
        } catch (e) {
          throw new Error("Payload client invalide (JSON illisible).");
        }

        const token = payload.token;
        if (!token) {
          throw new Error("Authentification manquante : aucun jeton recu.");
        }

        let decoded;
        try {
          decoded = verifyToken(token);
        } catch (e) {
          throw new Error("Session invalide ou expiree (jeton rejete).");
        }

        if (!decoded || !decoded.authorId) {
          throw new Error("Session invalide ou expiree (jeton sans authorId).");
        }

        const ext = pathname.split(".").pop().toLowerCase();
        if (!["jpg", "jpeg", "png", "webp"].includes(ext)) {
          throw new Error("Format d'image non autorise (JPG, PNG ou WEBP uniquement).");
        }

        return {
          allowedContentTypes: ["image/jpeg", "image/png", "image/webp"],
          maximumSizeInBytes: 10 * 1024 * 1024,
          addRandomSuffix: true,
          tokenPayload: JSON.stringify({ authorId: decoded.authorId }),
        };
      },
      onUploadCompleted: async () => {
        // Volontairement vide : l'enregistrement en base se fait côté
        // client via PATCH /api/books/[id] une fois l'upload termine.
      },
    });

    return res.status(200).json(jsonResponse);
  } catch (error) {
    console.error("Erreur dans /api/books/upload-cover :", error);
    return res
      .status(400)
      .json({ error: error.message || "Erreur inconnue lors de l'upload." });
  }
}
PLUME_EOF_MARKER

mkdir -p "pages/boutique"
cat > "pages/boutique/[slug].js" << 'PLUME_EOF_MARKER'
import Head from "next/head";
import Link from "next/link";
import { BookOpen } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover } from "../../components/ui";

export async function getServerSideProps({ params }) {
  const author = await prisma.author.findUnique({
    where: { storeSlug: params.slug },
    include: {
      books: {
        include: { salesPage: true },
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!author) return { notFound: true };

  const books = author.books
    .filter((b) => b.salesPage?.published)
    .map((b) => ({
      id: b.id,
      title: b.title,
      coverImageUrl: b.coverImageUrl || "",
      slug: b.salesPage.slug,
      priceCents: b.salesPage.priceCents,
      currency: b.salesPage.currency,
    }));

  return {
    props: {
      authorName: author.name,
      books,
    },
  };
}

function formatPrice(cents, currency) {
  const amount = (cents || 0) / 100;
  if (currency === "EUR") return `${amount.toFixed(2)} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

export default function PublicStorePage({ authorName, books }) {
  return (
    <div className="min-h-screen" style={{ backgroundColor: colors.bgLight }}>
      <Head>
        <title>{authorName} — Boutique</title>
      </Head>

      <header className="px-5 pt-12 pb-10 text-center">
        <div className="w-11 h-11 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.gold }}>
          <BookOpen size={18} color={colors.ink} />
        </div>
        <p className="font-mono text-[11px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Boutique</p>
        <h1 className="font-display text-3xl" style={{ color: colors.textPaper }}>{authorName}</h1>
      </header>

      <main className="max-w-4xl mx-auto px-5 pb-20">
        {books.length === 0 ? (
          <p className="font-body text-sm text-center" style={{ color: colors.textMutedLight }}>
            Aucun livre disponible pour le moment — revenez bientôt.
          </p>
        ) : (
          <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6">
            {books.map((book) => (
              <Link
                key={book.id}
                href={`/p/${book.slug}`}
                className="rounded-2xl p-6 flex flex-col items-center text-center gap-4 transition-transform hover:-translate-y-0.5"
                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}
              >
                <BookCover title={book.title} author={authorName} imageUrl={book.coverImageUrl} size="lg" />
                <div>
                  <p className="font-display text-base mb-1" style={{ color: colors.textPaper }}>{book.title}</p>
                  <p className="font-body text-sm font-semibold" style={{ color: colors.goldDark }}>
                    {formatPrice(book.priceCents, book.currency)}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages/dashboard"
cat > "pages/dashboard/extrait.js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import { upload } from "@vercel/blob/client";
import { Upload, Check, Copy, ExternalLink, Loader2, FileText, Video, ImagePlus, Pencil } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, BookCover, EditableTitle, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api, getToken } from "../../lib/apiClient";

// Bouton discret posé sur la couverture pour en changer l'image.
function CoverUploadButton({ uploading, onFile }) {
  return (
    <label
      htmlFor="cover-upload-input-extrait"
      title="Changer la photo de couverture"
      className="absolute bottom-1.5 right-1.5 flex items-center justify-center rounded-full cursor-pointer transition-opacity"
      style={{ width: 28, height: 28, backgroundColor: colors.gold, color: colors.ink, opacity: uploading ? 0.6 : 0.95 }}
    >
      <input
        id="cover-upload-input-extrait"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="hidden"
        disabled={uploading}
        onChange={onFile}
      />
      {uploading ? <Loader2 size={13} className="animate-spin" /> : <ImagePlus size={13} />}
    </label>
  );
}

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
  const [coverUploading, setCoverUploading] = useState(false);
  const [titleSaving, setTitleSaving] = useState(false);

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

  async function handleCoverFile(e) {
    const file = e.target.files?.[0];
    if (!file || !book) return;
    setError("");
    setCoverUploading(true);
    try {
      const blob = await upload(file.name, file, {
        access: "public",
        handleUploadUrl: "/api/books/upload-cover",
        clientPayload: JSON.stringify({ token: getToken() }),
      });
      const updated = await api(`/api/books/${book.id}`, {
        method: "PATCH",
        body: { coverImageUrl: blob.url },
      });
      setBook(updated);
    } catch (err) {
      setError(err.message || "Échec de l’envoi de l’image");
    } finally {
      setCoverUploading(false);
    }
  }

  function handleTitleChange(value) {
    setBook((b) => ({ ...b, title: value }));
  }

  async function handleTitleSave() {
    if (!book) return;
    setTitleSaving(true);
    try {
      const updated = await api(`/api/books/${book.id}`, {
        method: "PATCH",
        body: { title: book.title },
      });
      setBook(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setTitleSaving(false);
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
            <div className="flex items-center gap-4 mt-6">
              <div className="relative shrink-0">
                <BookCover title={book.title} author={author?.name || ""} imageUrl={book.coverImageUrl} size="sm" />
                <CoverUploadButton uploading={coverUploading} onFile={handleCoverFile} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
                  Titre affiché
                </p>
                <div className="flex items-center gap-2">
                  <EditableTitle
                    value={book.title}
                    onChange={handleTitleChange}
                    onBlurExtra={handleTitleSave}
                    className="font-display text-lg flex-1 min-w-0"
                    style={{ color: colors.textPaper }}
                  />
                  {titleSaving ? <Spinner size={13} color={colors.goldDark} /> : <Pencil size={13} color={colors.mist} />}
                </div>
              </div>
            </div>
          )}

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

PLUME_EOF_MARKER

mkdir -p "pages/dashboard"
cat > "pages/dashboard/index.js" << 'PLUME_EOF_MARKER'
import { useState, useRef } from "react";
import { upload } from "@vercel/blob/client";
import { Sparkles, Upload, Check, Copy, ExternalLink, Loader2, Smartphone, CreditCard, ImagePlus, Pencil } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, BookCover, EditableTitle, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api, getToken } from "../../lib/apiClient";

// Bouton discret posé sur la couverture pour en changer l'image — réutilisé
// sur la page de vente et la page d'extrait.
function CoverUploadButton({ uploading, onFile }) {
  return (
    <label
      htmlFor="cover-upload-input"
      title="Changer la photo de couverture"
      className="absolute bottom-1.5 right-1.5 flex items-center justify-center rounded-full cursor-pointer transition-opacity"
      style={{ width: 28, height: 28, backgroundColor: colors.gold, color: colors.ink, opacity: uploading ? 0.6 : 0.95 }}
    >
      <input
        id="cover-upload-input"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="hidden"
        disabled={uploading}
        onChange={onFile}
      />
      {uploading ? <Loader2 size={13} className="animate-spin" /> : <ImagePlus size={13} />}
    </label>
  );
}

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
  const [coverUploading, setCoverUploading] = useState(false);
  const [titleSaving, setTitleSaving] = useState(false);
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
      // Upload direct navigateur -> Vercel Blob (contourne la limite de
      // 4,5 Mo des fonctions serverless Vercel). Le jeton JWT de l'auteur
      // est transmis via clientPayload, vérifié côté serveur dans
      // /api/books/upload avant d'autoriser l'upload.
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
      setStage("fileReady");
    } catch (err) {
      setError(err.message || "Échec de l’upload");
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

  async function handleCoverFile(e) {
    const file = e.target.files?.[0];
    if (!file || !book) return;
    setError("");
    setCoverUploading(true);
    try {
      const blob = await upload(file.name, file, {
        access: "public",
        handleUploadUrl: "/api/books/upload-cover",
        clientPayload: JSON.stringify({ token: getToken() }),
      });
      const updated = await api(`/api/books/${book.id}`, {
        method: "PATCH",
        body: { coverImageUrl: blob.url },
      });
      setBook(updated);
    } catch (err) {
      setError(err.message || "Échec de l’envoi de l’image");
    } finally {
      setCoverUploading(false);
    }
  }

  async function handleTitleChange(value) {
    setBook((b) => ({ ...b, title: value }));
  }

  async function handleTitleSave() {
    if (!book) return;
    setTitleSaving(true);
    try {
      const updated = await api(`/api/books/${book.id}`, {
        method: "PATCH",
        body: { title: book.title },
      });
      setBook(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setTitleSaving(false);
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
                  <div className="relative shrink-0 mx-auto md:mx-0">
                    <BookCover title={book?.title || "Votre livre"} author={author?.name || ""} imageUrl={book?.coverImageUrl} />
                    <CoverUploadButton uploading={coverUploading} onFile={handleCoverFile} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-6">
                      <EditableTitle
                        value={book?.title || ""}
                        onChange={handleTitleChange}
                        onBlurExtra={handleTitleSave}
                        className="font-display text-2xl md:text-3xl flex-1 min-w-0"
                        style={{ color: colors.textPaper }}
                      />
                      {titleSaving ? <Spinner size={14} color={colors.goldDark} /> : <Pencil size={14} color={colors.mist} />}
                    </div>

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
PLUME_EOF_MARKER

mkdir -p "pages/e"
cat > "pages/e/[slug].js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Download, Loader2, Mail } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

function getEmbedUrl(url) {
  if (!url) return null;
  try {
    const u = new URL(url);
    if (u.hostname.includes("youtu.be")) {
      return `https://www.youtube.com/embed/${u.pathname.slice(1)}`;
    }
    if (u.hostname.includes("youtube.com")) {
      const id = u.searchParams.get("v");
      if (id) return `https://www.youtube.com/embed/${id}`;
      if (u.pathname.startsWith("/embed/")) return url;
    }
    if (u.hostname.includes("vimeo.com")) {
      const id = u.pathname.split("/").filter(Boolean)[0];
      if (id) return `https://player.vimeo.com/video/${id}`;
    }
  } catch {
    return null;
  }
  return null;
}

export async function getServerSideProps({ params, req }) {
  const extractPage = await prisma.extractPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!extractPage) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: extractPage.book.title,
        coverImageUrl: extractPage.book.coverImageUrl || "",
        authorName: extractPage.book.author.name,
        slug: extractPage.slug,
        embedUrl: getEmbedUrl(extractPage.videoUrl) || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicExtractPage({ page }) {
  const [submitted, setSubmitted] = useState(false);
  const [pdfUrl, setPdfUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    email: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.firstName || !form.email || !form.whatsappNumber) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/leads/capture", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          firstName: form.firstName,
          lastName: form.lastName,
          email: form.email,
          whatsapp: `${form.countryCode}${form.whatsappNumber}`,
          website: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      setPdfUrl(data.pdfUrl || "");
      setSubmitted(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`Extrait gratuit — ${page.title}`}</title>
        <meta name="description" content={`Recevez gratuitement un extrait de "${page.title}" par ${page.authorName}.`} />
      </Head>

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-2xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Extrait gratuit
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
            <p className="font-body text-sm mt-2" style={{ color: colors.textPaperDim }}>
              Par {page.authorName}
            </p>
          </div>
        </div>

        {page.embedUrl && (
          <div className="rounded-2xl overflow-hidden mb-6" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div style={{ position: "relative", paddingTop: "56.25%" }}>
              <iframe
                src={page.embedUrl}
                title={page.title}
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                style={{ position: "absolute", top: 0, left: 0, width: "100%", height: "100%", border: 0 }}
              />
            </div>
          </div>
        )}

        {!submitted ? (
          <form onSubmit={handleSubmit} className="rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Mail size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Recevez l’extrait gratuitement</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Laissez vos coordonnées, l’extrait vous sera envoyé par email.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
                neutre pour éviter que Chrome ne le remplisse automatiquement
                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
            <input
              type="text"
              name="hp"
              id="hp-field-e"
              value={form.hp}
              onChange={(e) => update("hp", e.target.value)}
              autoComplete="off"
              tabIndex={-1}
              className="absolute opacity-0 pointer-events-none -z-10"
              style={{ left: -9999, width: 1, height: 1 }}
              aria-hidden="true"
            />

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Prénom"
                value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" placeholder="Nom"
                value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="email" required placeholder="Email"
              value={form.email} onChange={(e) => update("email", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="flex gap-2">
              <select
                value={form.countryCode}
                onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.iso} value={c.code}>{c.code}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber}
                onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? "Envoi…" : "Recevoir l’extrait"}
            </button>
          </form>
        ) : (
          <div className="rounded-2xl p-6 md:p-8 text-center" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
              <Mail size={20} color={colors.forest} />
            </div>
            <h2 className="font-display text-xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
            <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
              Votre extrait vous a été envoyé par email{pdfUrl ? " et est disponible en téléchargement direct ci-dessous." : "."}
            </p>
            {pdfUrl && (
              <a
                href={pdfUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                <Download size={16} /> Télécharger l’extrait
              </a>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages/p"
cat > "pages/p/[slug].js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Smartphone, CreditCard, Loader2, Truck } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

export async function getServerSideProps({ params, req }) {
  const salesPage = await prisma.salesPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!salesPage || !salesPage.published) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: salesPage.book.title,
        coverImageUrl: salesPage.book.coverImageUrl || "",
        authorName: salesPage.book.author.name,
        problem: salesPage.problem,
        why: salesPage.why,
        solution: salesPage.solution,
        priceCents: salesPage.priceCents,
        currency: salesPage.currency,
        region: salesPage.book.author.region,
        slug: salesPage.slug,
        turnstileSiteKey: process.env.TURNSTILE_SITE_KEY || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicSalesPage({ page }) {
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    buyerName: "",
    buyerEmail: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    shippingAddress: "",
    shippingCity: "",
    shippingPostalCode: "",
    shippingCountry: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  const currencyLabel = page.currency === "EUR" ? "€" : page.currency;
  const priceLabel = page.currency === "EUR"
    ? (page.priceCents / 100).toFixed(2)
    : Math.round(page.priceCents / 100).toLocaleString("fr-FR");

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.buyerName || !form.buyerEmail || !form.whatsappNumber || !form.shippingAddress || !form.shippingCity || !form.shippingPostalCode || !form.shippingCountry) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/checkout/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          buyerName: form.buyerName,
          buyerEmail: form.buyerEmail,
          buyerWhatsapp: `${form.countryCode}${form.whatsappNumber}`,
          shippingAddress: form.shippingAddress,
          shippingCity: form.shippingCity,
          shippingPostalCode: form.shippingPostalCode,
          shippingCountry: form.shippingCountry,
          website: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error("Paiement indisponible pour le moment. Réessayez dans un instant.");
      }
    } catch (err) {
      setError(err.message);
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`${page.title} — ${page.authorName}`}</title>
        <meta name="description" content={page.problem?.slice(0, 150)} />
      </Head>

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-3xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-3xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Livre de {page.authorName}
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
          </div>
        </div>

        <div className="rounded-2xl p-6 md:p-10 space-y-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Le problème</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.problem}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.why}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>La solution</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.solution}</p>
          </section>
        </div>

        <div className="sticky bottom-4 mt-6 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
          <div className="flex items-center gap-3">
            <p className="font-display text-2xl" style={{ color: colors.paper }}>
              {priceLabel} {currencyLabel}
            </p>
            <div className="flex items-center gap-1.5 font-mono text-[10px]" style={{ color: colors.mist }}>
              {page.region === "EUROPE" ? <CreditCard size={13} /> : <Smartphone size={13} />}
              {page.region === "EUROPE" ? "Carte bancaire" : "Mobile Money"}
            </div>
          </div>
          {!showForm && (
            <button
              onClick={() => setShowForm(true)}
              className="w-full sm:w-auto px-6 py-3 rounded-xl font-body font-semibold text-sm"
              style={{ backgroundColor: colors.gold, color: colors.ink }}
            >
              Acheter maintenant
            </button>
          )}
        </div>

        {showForm && (
          <form onSubmit={handleSubmit} className="mt-6 rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Truck size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
                neutre pour éviter que Chrome ne le remplisse automatiquement
                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
            <input
              type="text"
              name="hp"
              id="hp-field-p"
              value={form.hp}
              onChange={(e) => update("hp", e.target.value)}
              autoComplete="off"
              tabIndex={-1}
              className="absolute opacity-0 pointer-events-none -z-10"
              style={{ left: -9999, width: 1, height: 1 }}
              aria-hidden="true"
            />

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Nom complet"
                value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="email" required placeholder="Email"
                value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <div className="flex gap-2">
              <select
                value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm shrink-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150 }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.code} value={c.code}>{c.label}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full min-w-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="text" required placeholder="Adresse (rue, quartier...)"
              value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="grid sm:grid-cols-3 gap-4">
              <input
                type="text" required placeholder="Ville"
                value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Code postal"
                value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Pays"
                value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
            </button>
          </form>
        )}
      </main>
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "prisma"
cat > "prisma/schema.prisma" << 'PLUME_EOF_MARKER'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum Region {
  AFRIQUE
  EUROPE
}

enum SubscriptionStatus {
  TRIALING
  ACTIVE
  PAST_DUE
  CANCELED
}

enum PayoutStatus {
  PENDING
  PAID
  FAILED
}

model Author {
  id                 String              @id @default(cuid())
  email              String              @unique
  emailVerified      Boolean             @default(false)
  passwordHash       String
  name               String
  region             Region              @default(AFRIQUE)
  createdAt          DateTime            @default(now())

  // Stripe Connect — zone Europe
  stripeAccountId    String?
  stripeOnboarded    Boolean             @default(false)

  // Mobile Money — zone Afrique francophone
  momoOperator       String?
  momoNumber         String?

  // Abonnement à la plateforme (le plan que l'auteur paie, pas le paiement acheteur)
  subscriptionStatus SubscriptionStatus  @default(TRIALING)
  trialEndsAt        DateTime?
  currentPeriodEnd   DateTime?
  stripeCustomerId   String?

  // Vitrine publique listant tous les livres publiés de l'auteur (Ma boutique)
  storeSlug          String?             @unique

  books              Book[]
  leads              Lead[]
  purchases          Purchase[]
  payouts            Payout[]
  emailSequences     EmailSequence[]
  whatsAppSequences  WhatsAppSequence[]
  broadcasts         Broadcast[]
}

model Book {
  id            String        @id @default(cuid())
  authorId      String
  author        Author        @relation(fields: [authorId], references: [id])
  title         String
  fileUrl       String
  coverImageUrl String?
  createdAt     DateTime      @default(now())

  salesPage   SalesPage?
  extractPage ExtractPage?
  purchases   Purchase[]
  leads       Lead[]
}

model SalesPage {
  id               String   @id @default(cuid())
  bookId           String   @unique
  book             Book     @relation(fields: [bookId], references: [id])
  slug             String   @unique
  problem          String
  why              String
  solution         String
  priceCents       Int
  currency         String
  published        Boolean  @default(false)
  chariowProductId String?  // zone Afrique — produit Chariow provisionné pour ce livre
  createdAt        DateTime @default(now())
}

model ExtractPage {
  id        String   @id @default(cuid())
  bookId    String   @unique
  book      Book     @relation(fields: [bookId], references: [id])
  slug      String   @unique
  videoUrl  String?
  pdfUrl    String?  // fichier PDF de l'extrait, prêt au téléchargement direct
  createdAt DateTime @default(now())
}

model Lead {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  bookId     String?
  book       Book?    @relation(fields: [bookId], references: [id])
  firstName  String
  lastName   String
  email      String
  whatsapp   String
  source     String   // "extrait" | "acheteur"
  createdAt  DateTime @default(now())

  emailSends    EmailSend[]
  whatsAppSends WhatsAppSend[]
}

model Purchase {
  id                   String   @id @default(cuid())
  authorId             String
  author               Author   @relation(fields: [authorId], references: [id])
  bookId               String
  book                 Book     @relation(fields: [bookId], references: [id])
  buyerEmail           String
  buyerName            String
  buyerWhatsapp        String?

  // Adresse de livraison — le livre vendu est un exemplaire papier.
  shippingAddress      String
  shippingCity         String
  shippingPostalCode   String
  shippingCountry      String

  amountCents          Int
  currency             String
  provider             String   // "stripe" | "chariow"
  providerRef          String
  status               String   // "pending" | "paid" | "failed"
  createdAt            DateTime @default(now())

  @@unique([provider, providerRef])
}

// Demande de reversement de l'auteur (solde des ventes -> Mobile Money ou Stripe).
// Engagement produit : traité en moins de 24h (voir dueBy).
model Payout {
  id          String       @id @default(cuid())
  authorId    String
  author      Author       @relation(fields: [authorId], references: [id])
  amountCents Int
  currency    String
  method      String       // "stripe" | "momo"
  status      PayoutStatus @default(PENDING)
  providerRef String?      // id du virement Stripe, ou référence de transfert Chariow
  createdAt   DateTime     @default(now())
  dueBy       DateTime     // createdAt + 24h — SLA de traitement
  processedAt DateTime?
}

// Tunnel de vente automatique ("autorépondeur") : une séquence d'emails
// programmés qui se déclenchent automatiquement pour chaque contact d'une
// liste, selon son ancienneté. Un auteur a exactement 2 séquences : une par
// liste de contacts ("extrait" et "acheteur"), créées automatiquement avec
// un contenu par défaut (voir lib/sequences.js) dès sa première visite de
// l'onglet Contenu réseaux / Tunnels.
model EmailSequence {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  listSource String   // "extrait" | "acheteur"
  name       String
  active     Boolean  @default(true)
  createdAt  DateTime @default(now())

  steps      EmailSequenceStep[]

  @@unique([authorId, listSource])
}

model EmailSequenceStep {
  id         String   @id @default(cuid())
  sequenceId String
  sequence   EmailSequence @relation(fields: [sequenceId], references: [id])
  order      Int
  delayDays  Int      // jours après l'entrée du contact dans la liste
  subject    String
  body       String
  createdAt  DateTime @default(now())

  sends      EmailSend[]

  @@unique([sequenceId, order])
}

// Trace un envoi effectué (empêche de renvoyer deux fois la même étape au
// même contact).
model EmailSend {
  id             String            @id @default(cuid())
  leadId         String
  lead           Lead              @relation(fields: [leadId], references: [id])
  sequenceStepId String
  sequenceStep   EmailSequenceStep @relation(fields: [sequenceStepId], references: [id])
  sentAt         DateTime          @default(now())

  @@unique([leadId, sequenceStepId])
}

// Même principe que EmailSequence / EmailSequenceStep / EmailSend ci-dessus,
// mais pour le canal WhatsApp (voir lib/whatsapp.js). Un auteur a aussi
// exactement 2 séquences WhatsApp (une par liste), créées automatiquement
// avec un contenu par défaut dès sa première visite de l'onglet Tunnels —
// voir lib/whatsappSequences.js.
model WhatsAppSequence {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  listSource String   // "extrait" | "acheteur"
  name       String
  active     Boolean  @default(true)
  createdAt  DateTime @default(now())

  steps      WhatsAppSequenceStep[]

  @@unique([authorId, listSource])
}

model WhatsAppSequenceStep {
  id         String   @id @default(cuid())
  sequenceId String
  sequence   WhatsAppSequence @relation(fields: [sequenceId], references: [id])
  order      Int
  delayDays  Int      // jours après l'entrée du contact dans la liste
  body       String   // texte libre — envoyé comme variable {{1}} du modèle WhatsApp approuvé
  createdAt  DateTime @default(now())

  sends      WhatsAppSend[]

  @@unique([sequenceId, order])
}

// Trace un envoi WhatsApp effectué (empêche de renvoyer deux fois la même
// étape au même contact) — équivalent de EmailSend pour ce canal.
model WhatsAppSend {
  id             String               @id @default(cuid())
  leadId         String
  lead           Lead                 @relation(fields: [leadId], references: [id])
  sequenceStepId String
  sequenceStep   WhatsAppSequenceStep @relation(fields: [sequenceStepId], references: [id])
  sentAt         DateTime             @default(now())

  @@unique([leadId, sequenceStepId])
}

// Envoi ponctuel (immédiat ou programmé) à toute une liste — le "envoyer un
// mail à tous mes clients" en un clic, en plus des tunnels automatiques.
model Broadcast {
  id          String    @id @default(cuid())
  authorId    String
  author      Author    @relation(fields: [authorId], references: [id])
  listSource  String    // "extrait" | "acheteur" | "tous"
  subject     String
  body        String
  scheduledAt DateTime
  sentAt      DateTime?
  recipients  Int?      // nombre de destinataires au moment de l'envoi
  status      String    @default("scheduled") // "scheduled" | "sent" | "failed"
  createdAt   DateTime  @default(now())
}
PLUME_EOF_MARKER

echo "Termine."
