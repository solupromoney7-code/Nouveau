import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

// Rate limiting basé sur Upstash Redis (compte gratuit sur upstash.com) —
// un compteur en mémoire ne fonctionnerait pas ici : chaque invocation
// serverless Vercel peut démarrer sans mémoire partagée avec la précédente.
//
// Si UPSTASH_REDIS_REST_URL/TOKEN ne sont pas configurés, on n'échoue
// jamais la requête (fail-open) mais on log un avertissement clair — une
// app sans rate limiting reste utilisable ; une app qui plante au démarrage
// sans Upstash ne l'est pas. Configure-les dès que possible (voir README §8).
let redis = null;
if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
  redis = new Redis({
    url: process.env.UPSTASH_REDIS_REST_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN,
  });
}

const limiters = {};

function getLimiter(name, requests, windowSeconds) {
  if (!redis) return null;
  if (!limiters[name]) {
    limiters[name] = new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(requests, `${windowSeconds} s`),
      prefix: `plume:ratelimit:${name}`,
    });
  }
  return limiters[name];
}

export function getClientIp(req) {
  const fwd = req.headers["x-forwarded-for"];
  if (fwd) return fwd.split(",")[0].trim();
  return req.socket?.remoteAddress || "unknown";
}

// À appeler en tout début de handler :
//   const rl = await checkRateLimit(req, res, "login", 10, 300);
//   if (!rl.allowed) return; // la réponse 429 est déjà envoyée par la fonction
export async function checkRateLimit(req, res, name, requests, windowSeconds) {
  const limiter = getLimiter(name, requests, windowSeconds);
  if (!limiter) {
    console.warn(`Rate limiting désactivé (${name}) — configure UPSTASH_REDIS_REST_URL/TOKEN.`);
    return { allowed: true };
  }

  const ip = getClientIp(req);
  const { success, remaining } = await limiter.limit(`${name}:${ip}`);
  if (!success) {
    res.status(429).json({ error: "Trop de requêtes — réessayez dans quelques minutes." });
    return { allowed: false };
  }
  return { allowed: true, remaining };
}
