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
