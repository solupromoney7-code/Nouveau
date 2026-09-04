import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { DEFAULT_SEQUENCES } from "../../../lib/sequences";

// Retourne les 2 tunnels de vente de l'auteur (extrait, acheteur), en les
// créant automatiquement avec leur contenu par défaut au premier appel —
// l'auteur n'a jamais de tunnel vide à configurer depuis zéro.
//
// Complète aussi les étapes manquantes d'un tunnel déjà existant (ex. un
// compte créé avant le passage de 3 à 7 étapes par défaut) : seules les
// étapes dont le numéro d'ordre n'existe pas encore sont ajoutées, sans
// jamais toucher aux étapes déjà personnalisées par l'auteur.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  let existing = await prisma.emailSequence.findMany({
    where: { authorId: req.authorId },
    include: { steps: { orderBy: { order: "asc" } } },
  });

  const existingSources = new Set(existing.map((s) => s.listSource));
  const missingSequences = Object.keys(DEFAULT_SEQUENCES).filter((src) => !existingSources.has(src));

  for (const listSource of missingSequences) {
    const def = DEFAULT_SEQUENCES[listSource];
    await prisma.emailSequence.create({
      data: {
        authorId: req.authorId,
        listSource,
        name: def.name,
        steps: { create: def.steps },
      },
    });
  }

  // Backfill : pour les tunnels déjà existants, ajoute les étapes par
  // défaut dont l'ordre n'est pas encore présent.
  for (const sequence of existing) {
    const def = DEFAULT_SEQUENCES[sequence.listSource];
    if (!def) continue;
    const existingOrders = new Set(sequence.steps.map((s) => s.order));
    const stepsToAdd = def.steps.filter((s) => !existingOrders.has(s.order));
    if (stepsToAdd.length > 0) {
      await prisma.emailSequenceStep.createMany({
        data: stepsToAdd.map((s) => ({ ...s, sequenceId: sequence.id })),
      });
    }
  }

  const result = await prisma.emailSequence.findMany({
    where: { authorId: req.authorId },
    include: { steps: { orderBy: { order: "asc" } } },
  });

  return res.status(200).json(result);
});
