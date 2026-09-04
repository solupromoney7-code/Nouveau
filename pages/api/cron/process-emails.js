import { prisma } from "../../../lib/db";
import { sendMarketingEmail } from "../../../lib/email";
import { renderTemplate } from "../../../lib/sequences";
import { isSubscriptionActive } from "../../../lib/subscription";

// Appelée quotidiennement par Vercel Cron (voir vercel.json). Protégée par
// CRON_SECRET : Vercel ajoute automatiquement l'en-tête Authorization avec
// ce secret pour les routes de cron, donc personne d'autre ne peut la
// déclencher. Fait deux choses :
//   1. Fait avancer chaque tunnel actif : envoie la prochaine étape due à
//      chaque contact qui n'a pas encore reçu cette étape — réservé aux
//      auteurs avec un abonnement actif ou en essai (voir lib/subscription.js),
//      au même titre que la génération de contenu réseaux.
//   2. Envoie les broadcasts programmés dont l'heure est passée (déjà
//      filtrés à la création par la même règle, voir broadcasts/index.js —
//      revérifié ici au cas où l'abonnement aurait expiré entre-temps).
export default async function handler(req, res) {
  const auth = req.headers.authorization || "";
  if (process.env.CRON_SECRET && auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Non autorisé" });
  }

  let sequenceEmailsSent = 0;
  let broadcastsSent = 0;
  let skippedInactiveSubscription = 0;

  // --- 1. Tunnels automatiques ---
  const sequences = await prisma.emailSequence.findMany({
    where: { active: true },
    include: {
      steps: { orderBy: { order: "asc" } },
      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true } },
    },
  });

  for (const sequence of sequences) {
    if (!isSubscriptionActive(sequence.author)) {
      skippedInactiveSubscription += 1;
      continue;
    }

    const leads = await prisma.lead.findMany({
      where: { authorId: sequence.authorId, source: sequence.listSource },
      include: { book: { include: { salesPage: true } } },
    });

    for (const lead of leads) {
      const alreadySent = await prisma.emailSend.findMany({
        where: { leadId: lead.id, sequenceStep: { sequenceId: sequence.id } },
        select: { sequenceStepId: true },
      });
      const sentStepIds = new Set(alreadySent.map((s) => s.sequenceStepId));

      // La prochaine étape à envoyer est la première (dans l'ordre) que ce
      // contact n'a pas encore reçue.
      const nextStep = sequence.steps.find((s) => !sentStepIds.has(s.id));
      if (!nextStep) continue;

      const dueAt = new Date(lead.createdAt.getTime() + nextStep.delayDays * 24 * 60 * 60 * 1000);
      if (dueAt > new Date()) continue;

      const appUrl = process.env.APP_URL || "";
      const vars = {
        prenom: lead.firstName || "",
        titre: lead.book?.title || "",
        auteur: sequence.author.name,
        lien_achat: lead.book?.salesPage ? `${appUrl}/p/${lead.book.salesPage.slug}` : "",
        lien_boutique: `${appUrl}/boutique/${sequence.authorId}`,
      };

      const result = await sendMarketingEmail({
        to: lead.email,
        subject: renderTemplate(nextStep.subject, vars),
        textBody: renderTemplate(nextStep.body, vars),
      });

      if (result.sent) {
        await prisma.emailSend.create({ data: { leadId: lead.id, sequenceStepId: nextStep.id } });
        sequenceEmailsSent += 1;
      }
    }
  }

  // --- 2. Broadcasts programmés ---
  const dueBroadcasts = await prisma.broadcast.findMany({
    where: { status: "scheduled", scheduledAt: { lte: new Date() } },
    include: { author: true },
  });

  for (const broadcast of dueBroadcasts) {
    if (!isSubscriptionActive(broadcast.author)) {
      await prisma.broadcast.update({ where: { id: broadcast.id }, data: { status: "failed" } });
      skippedInactiveSubscription += 1;
      continue;
    }

    const where = { authorId: broadcast.authorId, ...(broadcast.listSource !== "tous" && { source: broadcast.listSource }) };
    const recipients = await prisma.lead.findMany({ where });

    let anyFailed = false;
    for (const lead of recipients) {
      const result = await sendMarketingEmail({
        to: lead.email,
        subject: renderTemplate(broadcast.subject, { prenom: lead.firstName, auteur: broadcast.author.name }),
        textBody: renderTemplate(broadcast.body, { prenom: lead.firstName, auteur: broadcast.author.name }),
        replyTo: broadcast.author.email,
      });
      if (result.sent) broadcastsSent += 1;
      else anyFailed = true;
    }

    await prisma.broadcast.update({
      where: { id: broadcast.id },
      data: { status: anyFailed ? "failed" : "sent", sentAt: new Date() },
    });
  }

  return res.status(200).json({ sequenceEmailsSent, broadcastsSent, skippedInactiveSubscription });
}
