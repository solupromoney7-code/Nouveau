// Validations partagées — avant cet audit, aucune route ne vérifiait le
// format des emails ni ne bornait la taille des champs texte libres.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(email) {
  return typeof email === "string" && email.length <= 254 && EMAIL_RE.test(email);
}

// Coupe les champs texte libres à une longueur raisonnable avant stockage —
// évite qu'un formulaire public serve à empiler des Mo de texte en base.
export function clampText(value, maxLength = 2000) {
  if (typeof value !== "string") return "";
  return value.slice(0, maxLength);
}
