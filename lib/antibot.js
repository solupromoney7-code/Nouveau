// Deux couches d'anti-bot, cumulables :
//
// 1. Honeypot — un champ caché nommé "website" dans le formulaire (via CSS
//    display:none, jamais visible pour un humain), que les bots remplissent
//    souvent automatiquement. Aucune dépendance externe, actif immédiatement,
//    sans configuration.
//
// 2. Cloudflare Turnstile — un vrai captcha invisible. Nécessite un compte
//    gratuit sur dash.cloudflare.com/?to=/:account/turnstile (voir README §8).
//    Tant que TURNSTILE_SECRET_KEY n'est pas configuré, cette couche est
//    ignorée (fail-open, comme le rate limiting) — le honeypot reste actif.

export function isHoneypotTriggered(body) {
  return Boolean(body?.website);
}

export async function verifyTurnstile(token, ip) {
  if (!process.env.TURNSTILE_SECRET_KEY) {
    console.warn("TURNSTILE_SECRET_KEY non configuré — vérification Turnstile ignorée (honeypot seul actif).");
    return true;
  }
  if (!token) return false;

  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ secret: process.env.TURNSTILE_SECRET_KEY, response: token, remoteip: ip }),
  });
  const data = await res.json();
  return Boolean(data.success);
}
