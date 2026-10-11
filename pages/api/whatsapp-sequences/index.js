import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { DEFAULT_WHATSAPP_SEQUENCES } from "../../../lib/whatsappSequences";
import { getWhatsAppTemplateStatus } from "../../../lib/whatsapp";

// Même logique que /api/sequences (email), pour le canal WhatsApp : crée
// automatiquement les 2 tunnels par défaut au premier appel, complète les
// étapes manquantes d'un tunnel existant, et renvoie en plus l'état
// d'approbation du modèle WhatsApp auprès de Meta (`template`).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    let existing = await prisma.whatsAppSequence.findMany({
      where: { authorId: req.authorId },
      include: { steps: { orderBy: { order: "asc" } } },
    });

    const existingSources = new Set(existing.map((s) => s.listSource));
    const missingSequences = Object.keys(DEFAULT_WHATSAPP_SEQUENCES).filter((src) => !existingSources.has(src));

    for (const listSource of missingSequences) {
      const def = DEFAULT_WHATSAPP_SEQUENCES[listSource];
      await prisma.whatsAppSequence.create({
        data: {
          authorId: req.authorId,
          listSource,
          name: def.name,
          steps: { create: def.steps },
        },
      });
    }

    for (const sequence of existing) {
      const def = DEFAULT_WHATSAPP_SEQUENCES[sequence.listSource];
      if (!def) continue;
      const existingOrders = new Set(sequence.steps.map((s) => s.order));
      const stepsToAdd = def.steps.filter((s) => !existingOrders.has(s.order));
      if (stepsToAdd.length > 0) {
        await prisma.whatsAppSequenceStep.createMany({
          data: stepsToAdd.map((s) => ({ ...s, sequenceId: sequence.id })),
        });
      }
    }

    const result = await prisma.whatsAppSequence.findMany({
      where: { authorId: req.authorId },
      include: { steps: { orderBy: { order: "asc" } } },
    });

    const template = await getWhatsAppTemplateStatus();

    return res.status(200).json({ sequences: result, template });
  } catch (error) {
    console.error("Erreur /api/whatsapp-sequences :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
