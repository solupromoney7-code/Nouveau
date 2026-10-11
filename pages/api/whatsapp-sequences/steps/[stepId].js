import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";

// Édite le texte/délai d'une étape d'un tunnel WhatsApp — équivalent de
// /api/sequences/steps/[stepId] (pas de "subject" ici, WhatsApp n'a qu'un
// corps de message).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { stepId } = req.query;
  const { body, delayDays } = req.body;

  try {
    const step = await prisma.whatsAppSequenceStep.findUnique({
      where: { id: stepId },
      include: { sequence: true },
    });
    if (!step || step.sequence.authorId !== req.authorId) {
      return res.status(404).json({ error: "Étape introuvable" });
    }

    const updated = await prisma.whatsAppSequenceStep.update({
      where: { id: stepId },
      data: {
        ...(body !== undefined && { body }),
        ...(delayDays !== undefined && { delayDays: Number(delayDays) }),
      },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur /api/whatsapp-sequences/steps/[stepId] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
