import { prisma } from "../../../lib/db";
import { verifyLeadToken } from "../../../lib/unsubscribe";

// Route PUBLIQUE — désinscription en un clic (page /desinscription, ou
// en-tête List-Unsubscribe des clients mail). Le jeton signé prouve que le
// lien vient d'un de nos emails.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const leadId = String(req.query.l || "");
  const token = String(req.query.t || "");
  if (!verifyLeadToken(leadId, token)) {
    return res.status(400).json({ error: "Lien invalide ou expiré." });
  }

  await prisma.lead.updateMany({ where: { id: leadId }, data: { unsubscribed: true } });
  return res.status(200).json({ ok: true });
}
