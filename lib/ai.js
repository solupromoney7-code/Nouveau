import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Modèles Claude actuels utilisés ici (à revérifier sur docs.claude.com si
// tu lis ce code plus tard — les identifiants de modèles évoluent) :
//  - claude-sonnet-5 pour la page de vente (tâche qui demande plus de finesse)
//  - claude-haiku-4-5-20251001 pour le contenu réseaux sociaux (volume élevé
//    — jusqu'à 20 posts/mois/auteur —, on privilégie le coût)
const MODEL_SALES_PAGE = "claude-sonnet-5";
const MODEL_SOCIAL_CONTENT = "claude-haiku-4-5-20251001";

// Récupère et extrait le texte du fichier du livre (stocké sur Vercel Blob).
// Gère le PDF ; à compléter avec un parseur dédié pour l'EPUB si besoin.
async function extractBookText(fileUrl) {
  const res = await fetch(fileUrl);
  const buf = Buffer.from(await res.arrayBuffer());

  if (fileUrl.toLowerCase().includes(".pdf")) {
    const pdfParse = (await import("pdf-parse")).default;
    const parsed = await pdfParse(buf);
    // Borne raisonnable pour tenir dans le prompt sans complexifier avec du chunking.
    return parsed.text.slice(0, 60000);
  }

  return buf.toString("utf-8").slice(0, 60000);
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
