// Liste partagée des indicatifs téléphoniques proposés sur les formulaires
// publics (page de vente, page d'extrait). Garder une seule liste ici évite
// que les deux pages divergent avec le temps.
export const COUNTRY_CODES = [
  { iso: "CI", code: "+225", label: "Côte d'Ivoire (+225)" },
  { iso: "SN", code: "+221", label: "Sénégal (+221)" },
  { iso: "BJ", code: "+229", label: "Bénin (+229)" },
  { iso: "TG", code: "+228", label: "Togo (+228)" },
  { iso: "ML", code: "+223", label: "Mali (+223)" },
  { iso: "BF", code: "+226", label: "Burkina Faso (+226)" },
  { iso: "CM", code: "+237", label: "Cameroun (+237)" },
  { iso: "GN", code: "+224", label: "Guinée (+224)" },
  { iso: "FR", code: "+33", label: "France (+33)" },
  { iso: "BE", code: "+32", label: "Belgique (+32)" },
  { iso: "CH", code: "+41", label: "Suisse (+41)" },
  { iso: "CA", code: "+1", label: "Canada (+1)" },
];

export const DEFAULT_COUNTRY_CODE = "+225";

export function codeForCountry(isoCountry) {
  if (!isoCountry) return DEFAULT_COUNTRY_CODE;
  const match = COUNTRY_CODES.find((c) => c.iso === String(isoCountry).toUpperCase());
  return match ? match.code : DEFAULT_COUNTRY_CODE;
}

// Devine l'indicatif à pré-sélectionner à partir du pays du visiteur, que
// Vercel détecte automatiquement et transmet via l'en-tête
// "x-vercel-ip-country" (présent uniquement en production sur Vercel —
// absent en local, d'où le repli silencieux sur la valeur par défaut).
export function getVisitorCountryCode(req) {
  const iso = req?.headers?.["x-vercel-ip-country"];
  return codeForCountry(iso);
}

// Sépare un numéro complet ("+22997000000") en { iso, number } — l'API Chariow
// exige le pays (code ISO) et le numéro séparément.
export function splitPhone(full) {
  const clean = String(full || "").replace(/[^0-9+]/g, "");
  const sorted = [...COUNTRY_CODES].sort((a, b) => b.code.length - a.code.length);
  const match = sorted.find((c) => clean.startsWith(c.code));
  if (match) return { iso: match.iso, number: clean.slice(match.code.length).replace(/\D/g, "") };
  return { iso: "CI", number: clean.replace(/\D/g, "") };
}
