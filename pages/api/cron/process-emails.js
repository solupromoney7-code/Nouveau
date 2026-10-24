import { prisma } from "../../../lib/db";
import { sendMarketingEmail } from "../../../lib/email";
import { sendWhatsAppMessage } from "../../../lib/whatsapp";
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
// Ajoute un lien "répondre à l'auteur" : les messages partent du numéro de
// Plume, mais le lecteur peut ensuite écrire directement à l'auteur.
function withReplyLink(text, authorNumber) {
  const digits = String(authorNumber || "").replace(/\D/g, "");
  const base = String(text || "").slice(0, 900);
  return digits ? `${base} 👉 Répondez-moi ici : https://wa.me/${digits}` : base;
}

// Premier message d'une séquence WhatsApp : le lecteur doit savoir tout de
// suite QUI écrit. Si le texte ne mentionne pas déjà le nom de l'auteur, on
// ajoute en tête « Bonjour <prénom>, c'est <auteur>, l'auteur de « <titre> ». ».
function withAuthorIntro(text, { prenom, auteur, titre }) {
  const body = String(text || "");
  if (!auteur || body.toLowerCase().includes(String(auteur).toLowerCase())) return body;
  const who = titre ? `c’est ${auteur}, l’auteur de « ${titre} ».` : `c’est ${auteur}.`;
  const greeting = prenom ? `Bonjour ${prenom}, ${who}` : `Bonjour, ${who}`;
  // Évite le double « Bonjour Franck, … » si le texte commence déjà ainsi.
  const stripped = prenom
    ? body.replace(new RegExp(`^\\s*Bonjour\\s+${prenom.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*[,!.]?\\s*`, "i"), "")
    : body.replace(/^\s*Bonjour\s*[,!.]?\s*/i, "");
  const rest = stripped.charAt(0).toUpperCase() + stripped.slice(1);
  return `${greeting} ${rest}`.trim();
}

export default async function handler(req, res) {
  const auth = req.headers.authorization || "";
  if (process.env.CRON_SECRET && auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Non autorisé" });
  }

  let sequenceEmailsSent = 0;
  let sequenceWhatsAppSent = 0;
  let broadcastsSent = 0;
  let skippedInactiveSubscription = 0;

  // --- 1. Tunnels automatiques ---
  const sequences = await prisma.emailSequence.findMany({
    where: { active: true },
    include: {
      steps: { orderBy: { order: "asc" } },
      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true } },
    },
  });

  for (const sequence of sequences) {
    if (!isSubscriptionActive(sequence.author)) {
      skippedInactiveSubscription += 1;
      continue;
    }

    const leads = await prisma.lead.findMany({
      where: { authorId: sequence.authorId, source: sequence.listSource, unsubscribed: false },
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
        leadId: lead.id,
      });

      if (result.sent) {
        await prisma.emailSend.create({ data: { leadId: lead.id, sequenceStepId: nextStep.id } });
        sequenceEmailsSent += 1;
      }
    }
  }

  // --- 2. Tunnels automatiques WhatsApp — même logique que les tunnels
  // email ci-dessus, canal séparé (voir lib/whatsapp.js). N'envoie rien si
  // WHATSAPP_ACCESS_TOKEN/WHATSAPP_PHONE_NUMBER_ID ne sont pas configurés
  // (sendWhatsAppMessage renvoie simplement { sent: false }).
  const whatsAppSequences = await prisma.whatsAppSequence.findMany({
    where: { active: true },
    include: {
      steps: { orderBy: { order: "asc" } },
      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true, lifetimeAccess: true, whatsappNumber: true } },
    },
  });

  for (const sequence of whatsAppSequences) {
    if (!isSubscriptionActive(sequence.author)) {
      skippedInactiveSubscription += 1;
      continue;
    }

    const leads = await prisma.lead.findMany({
      where: { authorId: sequence.authorId, source: sequence.listSource, unsubscribed: false },
      include: { book: { include: { salesPage: true } } },
    });

    for (const lead of leads) {
      if (!lead.whatsapp) continue;

      const alreadySent = await prisma.whatsAppSend.findMany({
        where: { leadId: lead.id, sequenceStep: { sequenceId: sequence.id } },
        select: { sequenceStepId: true },
      });
      const sentStepIds = new Set(alreadySent.map((s) => s.sequenceStepId));

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

      let text = renderTemplate(nextStep.body, vars);
      // Premier message de la séquence : se présenter (voir withAuthorIntro).
      if (nextStep.id === sequence.steps[0]?.id) {
        text = withAuthorIntro(text, { prenom: vars.prenom, auteur: vars.auteur, titre: vars.titre });
      }

      const result = await sendWhatsAppMessage({
        to: lead.whatsapp,
        bodyText: withReplyLink(text, sequence.author.whatsappNumber),
      });

      if (result.sent) {
        await prisma.whatsAppSend.create({ data: { leadId: lead.id, sequenceStepId: nextStep.id } });
        sequenceWhatsAppSent += 1;
      }
    }
  }

  // --- 3. Broadcasts programmés ---
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

    const where = { authorId: broadcast.authorId, unsubscribed: false, ...(broadcast.listSource !== "tous" && { source: broadcast.listSource }) };
    const recipients = await prisma.lead.findMany({ where });

    let anyFailed = false;
    for (const lead of recipients) {
      const result = await sendMarketingEmail({
        to: lead.email,
        subject: renderTemplate(broadcast.subject, { prenom: lead.firstName, auteur: broadcast.author.name }),
        textBody: renderTemplate(broadcast.body, { prenom: lead.firstName, auteur: broadcast.author.name }),
        replyTo: broadcast.author.email,
        leadId: lead.id,
      });
      if (result.sent) broadcastsSent += 1;
      else anyFailed = true;
    }

    await prisma.broadcast.update({
      where: { id: broadcast.id },
      data: { status: anyFailed ? "failed" : "sent", sentAt: new Date() },
    });
  }

  return res.status(200).json({ sequenceEmailsSent, sequenceWhatsAppSent, broadcastsSent, skippedInactiveSubscription });
}
