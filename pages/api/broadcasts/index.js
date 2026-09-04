import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { sendMarketingEmail } from "../../../lib/email";
import { renderTemplate } from "../../../lib/sequences";
import { isSubscriptionActive } from "../../../lib/subscription";

// GET  -> historique des envois de l'auteur (toujours consultable)
// POST -> crée un envoi. Réservé aux comptes avec un abonnement actif ou en
// essai — comme la génération de contenu réseaux et les tunnels de vente
// (voir lib/subscription.js). Si scheduledAt est absent ou déjà passé,
// envoie immédiatement. Sinon reste "scheduled" et sera traité par
// /api/cron/process-emails.
export default requireAuth(async function handler(req, res) {
  if (req.method === "GET") {
    const broadcasts = await prisma.broadcast.findMany({
      where: { authorId: req.authorId },
      orderBy: { createdAt: "desc" },
    });
    return res.status(200).json(broadcasts);
  }

  if (req.method !== "POST") return res.status(405).end();

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (!isSubscriptionActive(author)) {
    return res.status(402).json({ error: "Abonnement inactif — envoi à une liste indisponible." });
  }

  const { listSource, subject, body, scheduledAt } = req.body;
  if (!listSource || !subject || !body) {
    return res.status(400).json({ error: "listSource, subject et body sont requis" });
  }

  const when = scheduledAt ? new Date(scheduledAt) : new Date();

  const where = { authorId: req.authorId, ...(listSource !== "tous" && { source: listSource }) };
  const recipients = await prisma.lead.findMany({ where });

  const broadcast = await prisma.broadcast.create({
    data: {
      authorId: req.authorId,
      listSource,
      subject,
      body,
      scheduledAt: when,
      recipients: recipients.length,
      status: "scheduled",
    },
  });

  // Envoi immédiat si l'heure programmée est déjà passée/absente.
  if (when <= new Date()) {
    let anyFailed = false;
    for (const lead of recipients) {
      const result = await sendMarketingEmail({
        to: lead.email,
        subject: renderTemplate(subject, { prenom: lead.firstName, auteur: author.name }),
        textBody: renderTemplate(body, { prenom: lead.firstName, auteur: author.name }),
        replyTo: author.email,
      });
      if (!result.sent) anyFailed = true;
    }
    const updated = await prisma.broadcast.update({
      where: { id: broadcast.id },
      data: { status: anyFailed ? "failed" : "sent", sentAt: new Date() },
    });
    return res.status(201).json(updated);
  }

  return res.status(201).json(broadcast);
});
