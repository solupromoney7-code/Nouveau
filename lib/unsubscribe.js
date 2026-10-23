import crypto from "crypto";

// Lien de désinscription signé : impossible de désinscrire quelqu'un d'autre
// sans connaître le secret du serveur.
function secret() {
  return process.env.JWT_SECRET || "plume-dev-secret";
}

export function signLeadToken(leadId) {
  return crypto.createHmac("sha256", secret()).update(String(leadId)).digest("hex").slice(0, 32);
}

export function verifyLeadToken(leadId, token) {
  if (!leadId || !token) return false;
  const expected = Buffer.from(signLeadToken(leadId));
  const given = Buffer.from(String(token));
  return expected.length === given.length && crypto.timingSafeEqual(expected, given);
}

export function unsubscribeUrl(leadId) {
  const base = process.env.APP_URL || "";
  return `${base}/desinscription?l=${encodeURIComponent(leadId)}&t=${signLeadToken(leadId)}`;
}
