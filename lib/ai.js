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
