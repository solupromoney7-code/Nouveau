#!/bin/bash
set -e

mkdir -p "lib"
cat > "lib/ai.js" << 'FILE_EOF_MARKER'
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Modèles Claude actuels utilisés ici (à revérifier sur docs.claude.com si
// tu lis ce code plus tard — les identifiants de modèles évoluent) :
//  - claude-sonnet-5 pour la page de vente (tâche qui demande plus de finesse)
//  - claude-haiku-4-5-20251001 pour le contenu réseaux sociaux (volume élevé
//    — jusqu'à 20 posts/mois/auteur —, on privilégie le coût)
const MODEL_SALES_PAGE = "claude-sonnet-5";
const MODEL_SOCIAL_CONTENT = "claude-haiku-4-5-20251001";
// Hooks/scripts par chapitre : demande plus de finesse créative que les
// posts réseaux sociaux en volume — on garde le modèle le plus capable.
const MODEL_CHAPTER_HOOKS = "claude-sonnet-5";

// Récupère et extrait le texte du fichier du livre (stocké sur Vercel Blob).
// Gère le PDF ; à compléter avec un parseur dédié pour l'EPUB si besoin.
// maxChars borne la taille pour tenir dans le prompt sans complexifier avec
// du chunking — plus généreuse pour l'analyse par chapitre (qui a besoin de
// voir loin dans le livre pour identifier tous les chapitres) que pour les
// tâches qui ne lisent que le début (page de vente, posts réseaux).
async function extractBookText(fileUrl, maxChars = 60000) {
  const res = await fetch(fileUrl);
  const buf = Buffer.from(await res.arrayBuffer());

  if (fileUrl.toLowerCase().includes(".pdf")) {
    const pdfParse = (await import("pdf-parse/lib/pdf-parse.js")).default;
    const parsed = await pdfParse(buf);
    return parsed.text.slice(0, maxChars);
  }

  return buf.toString("utf-8").slice(0, maxChars);
}

function parseJsonResponse(message, fallback) {
  const raw = message.content.find((b) => b.type === "text")?.text || "";
  try {
    const cleaned = raw.replace(/```json|```/g, "").trim();
    return JSON.parse(cleaned);
  } catch {
    return fallback;
  }
}

export async function generateSalesPageCopy(book) {
  const text = await extractBookText(book.fileUrl);

  const message = await anthropic.messages.create({
    model: MODEL_SALES_PAGE,
    max_tokens: 1000,
    system:
      "Tu es un copywriter expert en pages de vente pour livres. Tu réponds " +
      "UNIQUEMENT en JSON valide, sans texte autour, avec exactement les clés " +
      "problem, why, solution. Chaque valeur fait 2 à 4 phrases, en français, " +
      "ton direct et concret, sans emphase excessive ni superlatifs vides.",
    messages: [
      {
        role: "user",
        content:
          `Voici le texte (ou un extrait) du livre "${book.title}" :\n\n${text}\n\n` +
          "Génère l'argumentaire de vente en 3 parties : " +
          "1) problem : le ou les problèmes douloureux que vit le lecteur cible ; " +
          "2) why : pourquoi le lecteur cible vit ce problème ; " +
          "3) solution : comment ce livre précis y répond. " +
          'Réponds strictement au format JSON : {"problem": "...", "why": "...", "solution": "..."}',
      },
    ],
  });

  const parsed = parseJsonResponse(message, null);
  if (!parsed) {
    // Si le modèle ne renvoie pas un JSON strictement valide, on ne fait pas
    // échouer la génération : on renvoie le texte brut dans "solution" pour
    // que l'auteur puisse au moins l'éditer manuellement.
    const raw = message.content.find((b) => b.type === "text")?.text || "";
    return { problem: "", why: "", solution: raw };
  }
  return {
    problem: parsed.problem || "",
    why: parsed.why || "",
    solution: parsed.solution || "",
  };
}

export async function generateSocialPosts(book, count = 20) {
  const text = await extractBookText(book.fileUrl);

  const message = await anthropic.messages.create({
    model: MODEL_SOCIAL_CONTENT,
    max_tokens: 2500,
    system:
      "Tu es community manager spécialisé dans la promotion de livres. Tu " +
      'réponds UNIQUEMENT en JSON valide : un tableau d\'objets ' +
      '{"platform": "instagram"|"facebook"|"linkedin", "text": "..."}.',
    messages: [
      {
        role: "user",
        content:
          `Voici le texte (ou un extrait) du livre "${book.title}" :\n\n${text}\n\n` +
          `Génère ${count} publications courtes et variées pour les réseaux sociaux, ` +
          "en français, qui donnent envie de lire ou d'acheter ce livre, sans être répétitives entre elles.",
      },
    ],
  });

  return parseJsonResponse(message, []);
}

// Garde-fou coût/latence : un livre à rallonge avec 40 chapitres ne doit ni
// faire exploser le coût d'un seul appel, ni risquer un timeout de fonction
// serverless — un seul appel au modèle couvre tout le livre d'un coup
// (plutôt qu'un appel par chapitre), ce qui borne naturellement la durée.
const MAX_CHAPTERS_ANALYZED = 12;

// Pour chaque chapitre du livre : 5 hooks d'accroche (pensés pour les 3
// premières secondes d'une vidéo courte) et 5 scripts vidéo complets prêts
// à tourner. Contenu réservé aux abonnements actifs (voir lib/subscription.js),
// car cette lecture + génération approfondie coûte nettement plus cher en
// tokens qu'un post réseau classique.
export async function generateChapterHookScripts(book) {
  const text = await extractBookText(book.fileUrl, 150000);

  const message = await anthropic.messages.create({
    model: MODEL_CHAPTER_HOOKS,
    max_tokens: 8000,
    system:
      "Tu es un expert en création de contenu vidéo courte (TikTok, Reels, YouTube Shorts) " +
      "pour promouvoir des livres auprès d'un public francophone. Tu lis un livre en entier, " +
      "tu identifies ses chapitres dans l'ordre, et pour chacun tu écris du contenu promotionnel " +
      "percutant basé sur son idée la plus marquante. Tu réponds UNIQUEMENT en JSON valide : un " +
      'tableau d\'objets {"chapter": "titre du chapitre", "hooks": ["...", "...", "...", "...", "..."], ' +
      '"scripts": ["...", "...", "...", "...", "..."]}. ' +
      "Chaque élément de \"hooks\" est une phrase d'accroche de moins de 15 mots, pensée pour capter " +
      "l'attention dans les 3 premières secondes d'une vidéo (question provocante, statistique ou " +
      "affirmation contre-intuitive, mini-histoire qui interrompt le scroll...) — les 5 doivent " +
      "utiliser 5 angles différents, jamais de simples reformulations les unes des autres. " +
      "Chaque élément de \"scripts\" est un script vidéo complet de 30 à 45 secondes (environ 80 à " +
      "120 mots), structuré hook → développement de l'idée → incitation à lire le livre, rédigé pour " +
      "être lu face caméra, en français.",
    messages: [
      {
        role: "user",
        content:
          `Voici le texte du livre "${book.title}" :\n\n${text}\n\n` +
          `Identifie les chapitres de ce livre dans l'ordre. Si le livre en contient plus de ` +
          `${MAX_CHAPTERS_ANALYZED}, concentre-toi sur les ${MAX_CHAPTERS_ANALYZED} premiers. ` +
          "Pour chaque chapitre, génère 5 hooks et 5 scripts vidéo distincts, comme décrit. " +
          "Réponds uniquement avec le tableau JSON, un objet par chapitre, dans l'ordre du livre.",
      },
    ],
  });

  const parsed = parseJsonResponse(message, []);
  if (!Array.isArray(parsed)) return [];

  return parsed
    .filter((c) => c && c.chapter)
    .slice(0, MAX_CHAPTERS_ANALYZED)
    .map((c, i) => ({
      order: i + 1,
      chapter: String(c.chapter),
      hooks: Array.isArray(c.hooks) ? c.hooks.slice(0, 5).map(String) : [],
      scripts: Array.isArray(c.scripts) ? c.scripts.slice(0, 5).map(String) : [],
    }));
}
FILE_EOF_MARKER

mkdir -p "pages/dashboard"
cat > "pages/dashboard/contenu.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import Link from "next/link";
import {
  Sparkles, Video, Copy, Check, ChevronDown, ChevronRight,
  Loader2, Lock, ArrowRight, Instagram, Facebook, Linkedin,
} from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const PLATFORM_ICONS = { instagram: Instagram, facebook: Facebook, linkedin: Linkedin };

function CopyButton({ text }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => { navigator.clipboard?.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 1200); }}
      className="flex items-center gap-1 font-mono text-[10px] px-2 py-1 rounded-md shrink-0"
      style={{ backgroundColor: colors.paperDim, color: colors.textPaperDim }}
    >
      {copied ? <Check size={11} /> : <Copy size={11} />} {copied ? "Copié" : "Copier"}
    </button>
  );
}

function UpsellCard() {
  return (
    <div className="rounded-2xl p-8 text-center" style={{ backgroundColor: colors.paper }}>
      <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
        <Lock size={20} color={colors.goldDark} />
      </div>
      <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Fonctionnalité réservée aux abonnés</h2>
      <p className="font-body text-sm mb-5" style={{ color: colors.textPaperDim }}>
        La génération de contenu réseaux est incluse dans l’abonnement Plume.
      </p>
      <Link
        href="/dashboard/abonnement"
        className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-body font-semibold text-sm"
        style={{ backgroundColor: colors.gold, color: colors.ink }}
      >
        Voir l’abonnement <ArrowRight size={15} />
      </Link>
    </div>
  );
}

function ChapterCard({ chapter }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="rounded-xl overflow-hidden" style={{ border: `1px solid ${colors.paperDim}` }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center gap-3 px-4 py-3 text-left"
        style={{ backgroundColor: colors.paperDim }}
      >
        {open ? <ChevronDown size={15} color={colors.textPaperDim} /> : <ChevronRight size={15} color={colors.textPaperDim} />}
        <span className="font-mono text-[10px] shrink-0 px-2 py-0.5 rounded-full" style={{ backgroundColor: colors.gold, color: colors.ink }}>
          Ch. {chapter.order}
        </span>
        <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{chapter.chapter}</p>
      </button>

      {open && (
        <div className="p-4 space-y-5" style={{ backgroundColor: "#FFFFFF" }}>
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-2" style={{ color: colors.goldDark }}>
              5 hooks (3 premières secondes)
            </p>
            <div className="space-y-2">
              {chapter.hooks.map((h, i) => (
                <div key={i} className="flex items-start justify-between gap-2 px-3 py-2 rounded-lg" style={{ backgroundColor: colors.paperDim }}>
                  <p className="font-body text-sm" style={{ color: colors.textPaper }}>{h}</p>
                  <CopyButton text={h} />
                </div>
              ))}
            </div>
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-2" style={{ color: colors.goldDark }}>
              5 scripts vidéo
            </p>
            <div className="space-y-2">
              {chapter.scripts.map((s, i) => (
                <div key={i} className="px-3 py-2.5 rounded-lg" style={{ backgroundColor: colors.paperDim }}>
                  <div className="flex items-start justify-between gap-2 mb-1">
                    <p className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.textPaperDim }}>Script {i + 1}</p>
                    <CopyButton text={s} />
                  </div>
                  <p className="font-body text-sm whitespace-pre-line" style={{ color: colors.textPaper }}>{s}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default function DashboardContenu() {
  const { author, loading: authLoading } = useAuthGuard();

  const [books, setBooks] = useState([]);
  const [booksLoading, setBooksLoading] = useState(true);
  const [bookId, setBookId] = useState("");

  const [posts, setPosts] = useState(null);
  const [postsLoading, setPostsLoading] = useState(false);
  const [postsError, setPostsError] = useState("");
  const [postsLocked, setPostsLocked] = useState(false);

  const [chapters, setChapters] = useState(null);
  const [chaptersLoading, setChaptersLoading] = useState(false);
  const [chaptersError, setChaptersError] = useState("");
  const [chaptersLocked, setChaptersLocked] = useState(false);

  useEffect(() => {
    if (!author) return;
    api("/api/books")
      .then((data) => {
        setBooks(data);
        if (data.length > 0) setBookId(data[0].id);
      })
      .finally(() => setBooksLoading(false));
  }, [author]);

  async function handleGeneratePosts() {
    setPostsError("");
    setPostsLocked(false);
    setPostsLoading(true);
    try {
      const data = await api("/api/content/generate", { method: "POST", body: { bookId, count: 20 } });
      setPosts(data.posts);
    } catch (err) {
      if (err.status === 402) setPostsLocked(true);
      else setPostsError(err.message);
    } finally {
      setPostsLoading(false);
    }
  }

  async function handleGenerateChapters() {
    setChaptersError("");
    setChaptersLocked(false);
    setChaptersLoading(true);
    try {
      const data = await api("/api/content/chapter-hooks", { method: "POST", body: { bookId } });
      setChapters(data.chapters);
    } catch (err) {
      if (err.status === 402) setChaptersLocked(true);
      else setChaptersError(err.message);
    } finally {
      setChaptersLoading(false);
    }
  }

  return (
    <DashboardShell active="contenu" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Réseaux sociaux</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Contenu généré</h1>
      </header>

      {authLoading || booksLoading ? (
        <Spinner color={colors.gold} />
      ) : books.length === 0 ? (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>
            Téléversez d’abord un livre depuis <Link href="/dashboard" className="underline">Page de vente</Link> ou{" "}
            <Link href="/dashboard/extrait" className="underline">Page d’extrait</Link> pour générer du contenu.
          </p>
        </div>
      ) : (
        <div className="max-w-2xl space-y-8">
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1.5" style={{ color: colors.mist }}>Livre</p>
            <select
              value={bookId}
              onChange={(e) => { setBookId(e.target.value); setPosts(null); setChapters(null); }}
              className="rounded-lg px-3 py-2 font-body text-sm"
              style={{ backgroundColor: colors.paper, color: colors.textPaper, border: "none" }}
            >
              {books.map((b) => <option key={b.id} value={b.id}>{b.title}</option>)}
            </select>
          </div>

          {/* --- Posts réseaux sociaux --- */}
          <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <div className="flex items-center justify-between gap-3 flex-wrap mb-1">
              <div className="flex items-center gap-2">
                <Sparkles size={16} color={colors.goldDark} />
                <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Posts réseaux sociaux</h2>
              </div>
              <button
                onClick={handleGeneratePosts}
                disabled={postsLoading}
                className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink, opacity: postsLoading ? 0.6 : 1 }}
              >
                {postsLoading && <Loader2 size={14} className="animate-spin" />}
                {postsLoading ? "Génération…" : "Générer 20 posts"}
              </button>
            </div>
            <p className="font-body text-xs mb-4" style={{ color: colors.textPaperDim }}>
              20 publications courtes et variées pour Instagram, Facebook et LinkedIn, générées à partir de votre livre.
            </p>

            <ErrorBanner message={postsError} />
            {postsLocked && <UpsellCard />}

            {posts && posts.length > 0 && (
              <div className="space-y-2 mt-3">
                {posts.map((p, i) => {
                  const Icon = PLATFORM_ICONS[p.platform] || Sparkles;
                  return (
                    <div key={i} className="flex items-start justify-between gap-3 px-3 py-2.5 rounded-lg" style={{ backgroundColor: colors.paperDim }}>
                      <div className="flex items-start gap-2 min-w-0">
                        <Icon size={14} color={colors.goldDark} className="shrink-0 mt-0.5" />
                        <p className="font-body text-sm" style={{ color: colors.textPaper }}>{p.text}</p>
                      </div>
                      <CopyButton text={p.text} />
                    </div>
                  );
                })}
              </div>
            )}
          </section>

          {/* --- Hooks & scripts vidéo par chapitre --- */}
          <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <div className="flex items-center justify-between gap-3 flex-wrap mb-1">
              <div className="flex items-center gap-2">
                <Video size={16} color={colors.goldDark} />
                <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>Hooks &amp; scripts vidéo par chapitre</h2>
              </div>
              <button
                onClick={handleGenerateChapters}
                disabled={chaptersLoading}
                className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink, opacity: chaptersLoading ? 0.6 : 1 }}
              >
                {chaptersLoading && <Loader2 size={14} className="animate-spin" />}
                {chaptersLoading ? "Lecture du livre…" : "Analyser le livre"}
              </button>
            </div>
            <p className="font-body text-xs mb-4" style={{ color: colors.textPaperDim }}>
              L’IA lit votre livre chapitre par chapitre et génère, pour chacun, 5 hooks d’accroche
              (pensés pour les 3 premières secondes d’une vidéo) et 5 scripts vidéo courts prêts à tourner.
              Cela peut prendre une minute sur un livre long.
            </p>

            <ErrorBanner message={chaptersError} />
            {chaptersLocked && <UpsellCard />}

            {chapters && chapters.length > 0 && (
              <div className="space-y-2 mt-3">
                {chapters.map((c) => <ChapterCard key={c.order} chapter={c} />)}
              </div>
            )}
          </section>
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

mkdir -p "pages/api/books"
cat > "pages/api/books/index.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Liste les livres de l'auteur connecté — utilisée partout où l'auteur doit
// choisir "sur quel livre" lancer une action (génération de contenu réseaux,
// hooks par chapitre...).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    const books = await prisma.book.findMany({
      where: { authorId: req.authorId },
      orderBy: { createdAt: "desc" },
      select: { id: true, title: true, createdAt: true },
    });
    return res.status(200).json(books);
  } catch (error) {
    console.error("Erreur /api/books :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/content"
cat > "pages/api/content/generate.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSocialPosts } from "../../../lib/ai";
import { isSubscriptionActive } from "../../../lib/subscription";

// Génération de contenu réseaux sociaux — réservée aux comptes avec un
// abonnement actif ou en période d'essai (voir lib/subscription.js).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const { bookId, count } = req.body;
    if (!bookId) return res.status(400).json({ error: "bookId requis" });

    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    if (!isSubscriptionActive(author)) {
      return res.status(402).json({ error: "Abonnement inactif — génération de contenu indisponible." });
    }

    const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
    if (!book) return res.status(404).json({ error: "Livre introuvable" });

    const posts = await generateSocialPosts(book, count || 20);
    return res.status(200).json({ posts });
  } catch (error) {
    console.error("Erreur /api/content/generate :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/content"
cat > "pages/api/content/chapter-hooks.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateChapterHookScripts } from "../../../lib/ai";
import { isSubscriptionActive } from "../../../lib/subscription";

// Lit le livre en entier et génère, pour chaque chapitre, 5 hooks d'accroche
// et 5 scripts vidéo courts — réservé aux comptes avec un abonnement actif
// (voir lib/subscription.js), comme la génération de posts réseaux.
export const config = { maxDuration: 60 };

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const { bookId } = req.body;
    if (!bookId) return res.status(400).json({ error: "bookId requis" });

    const author = await prisma.author.findUnique({ where: { id: req.authorId } });
    if (!isSubscriptionActive(author)) {
      return res.status(402).json({ error: "Abonnement inactif — génération de contenu indisponible." });
    }

    const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
    if (!book) return res.status(404).json({ error: "Livre introuvable" });

    const chapters = await generateChapterHookScripts(book);
    return res.status(200).json({ chapters });
  } catch (error) {
    console.error("Erreur /api/content/chapter-hooks :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

echo "Fichiers mis à jour avec succès."
