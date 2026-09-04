import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Active/désactive un tunnel (l'auteur peut couper l'automatisation sans
// perdre son contenu).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { id } = req.query;
  const { active } = req.body;

  const sequence = await prisma.emailSequence.findFirst({ where: { id, authorId: req.authorId } });
  if (!sequence) return res.status(404).json({ error: "Tunnel introuvable" });

  const updated = await prisma.emailSequence.update({
    where: { id },
    data: { active: Boolean(active) },
  });
  return res.status(200).json(updated);
});
