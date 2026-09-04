import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";

// Édite le sujet/texte/délai d'une étape d'un tunnel — c'est le seul geste
// de personnalisation attendu de l'auteur, le reste est pré-rempli.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { stepId } = req.query;
  const { subject, body, delayDays } = req.body;

  const step = await prisma.emailSequenceStep.findUnique({
    where: { id: stepId },
    include: { sequence: true },
  });
  if (!step || step.sequence.authorId !== req.authorId) {
    return res.status(404).json({ error: "Étape introuvable" });
  }

  const updated = await prisma.emailSequenceStep.update({
    where: { id: stepId },
    data: {
      ...(subject !== undefined && { subject }),
      ...(body !== undefined && { body }),
      ...(delayDays !== undefined && { delayDays: Number(delayDays) }),
    },
  });
  return res.status(200).json(updated);
});
