#!/bin/bash
set -e
echo "Ajoute les tunnels de vente WhatsApp"

mkdir -p "$(dirname "prisma/schema.prisma")"
cat > "prisma/schema.prisma" << 'FILE_EOF_MARKER'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum Region {
  AFRIQUE
  EUROPE
}

enum SubscriptionStatus {
  TRIALING
  ACTIVE
  PAST_DUE
  CANCELED
}

enum PayoutStatus {
  PENDING
  PAID
  FAILED
}

model Author {
  id                 String              @id @default(cuid())
  email              String              @unique
  emailVerified      Boolean             @default(false)
  passwordHash       String
  name               String
  region             Region              @default(AFRIQUE)
  createdAt          DateTime            @default(now())

  // Stripe Connect — zone Europe
  stripeAccountId    String?
  stripeOnboarded    Boolean             @default(false)

  // Mobile Money — zone Afrique francophone
  momoOperator       String?
  momoNumber         String?

  // Abonnement à la plateforme (le plan que l'auteur paie, pas le paiement acheteur)
  subscriptionStatus SubscriptionStatus  @default(TRIALING)
  trialEndsAt        DateTime?
  currentPeriodEnd   DateTime?
  stripeCustomerId   String?

  // Vitrine publique listant tous les livres publiés de l'auteur (Ma boutique)
  storeSlug          String?             @unique

  books              Book[]
  leads              Lead[]
  purchases          Purchase[]
  payouts            Payout[]
  emailSequences     EmailSequence[]
  whatsAppSequences  WhatsAppSequence[]
  broadcasts         Broadcast[]
}

model Book {
  id          String        @id @default(cuid())
  authorId    String
  author      Author        @relation(fields: [authorId], references: [id])
  title       String
  fileUrl     String
  createdAt   DateTime      @default(now())

  salesPage   SalesPage?
  extractPage ExtractPage?
  purchases   Purchase[]
  leads       Lead[]
}

model SalesPage {
  id               String   @id @default(cuid())
  bookId           String   @unique
  book             Book     @relation(fields: [bookId], references: [id])
  slug             String   @unique
  problem          String
  why              String
  solution         String
  priceCents       Int
  currency         String
  published        Boolean  @default(false)
  chariowProductId String?  // zone Afrique — produit Chariow provisionné pour ce livre
  createdAt        DateTime @default(now())
}

model ExtractPage {
  id        String   @id @default(cuid())
  bookId    String   @unique
  book      Book     @relation(fields: [bookId], references: [id])
  slug      String   @unique
  videoUrl  String?
  pdfUrl    String?  // fichier PDF de l'extrait, prêt au téléchargement direct
  createdAt DateTime @default(now())
}

model Lead {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  bookId     String?
  book       Book?    @relation(fields: [bookId], references: [id])
  firstName  String
  lastName   String
  email      String
  whatsapp   String
  source     String   // "extrait" | "acheteur"
  createdAt  DateTime @default(now())

  emailSends    EmailSend[]
  whatsAppSends WhatsAppSend[]
}

model Purchase {
  id                   String   @id @default(cuid())
  authorId             String
  author               Author   @relation(fields: [authorId], references: [id])
  bookId               String
  book                 Book     @relation(fields: [bookId], references: [id])
  buyerEmail           String
  buyerName            String
  buyerWhatsapp        String?

  // Adresse de livraison — le livre vendu est un exemplaire papier.
  shippingAddress      String
  shippingCity         String
  shippingPostalCode   String
  shippingCountry      String

  amountCents          Int
  currency             String
  provider             String   // "stripe" | "chariow"
  providerRef          String
  status               String   // "pending" | "paid" | "failed"
  createdAt            DateTime @default(now())

  @@unique([provider, providerRef])
}

// Demande de reversement de l'auteur (solde des ventes -> Mobile Money ou Stripe).
// Engagement produit : traité en moins de 24h (voir dueBy).
model Payout {
  id          String       @id @default(cuid())
  authorId    String
  author      Author       @relation(fields: [authorId], references: [id])
  amountCents Int
  currency    String
  method      String       // "stripe" | "momo"
  status      PayoutStatus @default(PENDING)
  providerRef String?      // id du virement Stripe, ou référence de transfert Chariow
  createdAt   DateTime     @default(now())
  dueBy       DateTime     // createdAt + 24h — SLA de traitement
  processedAt DateTime?
}

// Tunnel de vente automatique ("autorépondeur") : une séquence d'emails
// programmés qui se déclenchent automatiquement pour chaque contact d'une
// liste, selon son ancienneté. Un auteur a exactement 2 séquences : une par
// liste de contacts ("extrait" et "acheteur"), créées automatiquement avec
// un contenu par défaut (voir lib/sequences.js) dès sa première visite de
// l'onglet Contenu réseaux / Tunnels.
model EmailSequence {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  listSource String   // "extrait" | "acheteur"
  name       String
  active     Boolean  @default(true)
  createdAt  DateTime @default(now())

  steps      EmailSequenceStep[]

  @@unique([authorId, listSource])
}

model EmailSequenceStep {
  id         String   @id @default(cuid())
  sequenceId String
  sequence   EmailSequence @relation(fields: [sequenceId], references: [id])
  order      Int
  delayDays  Int      // jours après l'entrée du contact dans la liste
  subject    String
  body       String
  createdAt  DateTime @default(now())

  sends      EmailSend[]

  @@unique([sequenceId, order])
}

// Trace un envoi effectué (empêche de renvoyer deux fois la même étape au
// même contact).
model EmailSend {
  id             String            @id @default(cuid())
  leadId         String
  lead           Lead              @relation(fields: [leadId], references: [id])
  sequenceStepId String
  sequenceStep   EmailSequenceStep @relation(fields: [sequenceStepId], references: [id])
  sentAt         DateTime          @default(now())

  @@unique([leadId, sequenceStepId])
}

// Même principe que EmailSequence / EmailSequenceStep / EmailSend ci-dessus,
// mais pour le canal WhatsApp (voir lib/whatsapp.js). Un auteur a aussi
// exactement 2 séquences WhatsApp (une par liste), créées automatiquement
// avec un contenu par défaut dès sa première visite de l'onglet Tunnels —
// voir lib/whatsappSequences.js.
model WhatsAppSequence {
  id         String   @id @default(cuid())
  authorId   String
  author     Author   @relation(fields: [authorId], references: [id])
  listSource String   // "extrait" | "acheteur"
  name       String
  active     Boolean  @default(true)
  createdAt  DateTime @default(now())

  steps      WhatsAppSequenceStep[]

  @@unique([authorId, listSource])
}

model WhatsAppSequenceStep {
  id         String   @id @default(cuid())
  sequenceId String
  sequence   WhatsAppSequence @relation(fields: [sequenceId], references: [id])
  order      Int
  delayDays  Int      // jours après l'entrée du contact dans la liste
  body       String   // texte libre — envoyé comme variable {{1}} du modèle WhatsApp approuvé
  createdAt  DateTime @default(now())

  sends      WhatsAppSend[]

  @@unique([sequenceId, order])
}

// Trace un envoi WhatsApp effectué (empêche de renvoyer deux fois la même
// étape au même contact) — équivalent de EmailSend pour ce canal.
model WhatsAppSend {
  id             String               @id @default(cuid())
  leadId         String
  lead           Lead                 @relation(fields: [leadId], references: [id])
  sequenceStepId String
  sequenceStep   WhatsAppSequenceStep @relation(fields: [sequenceStepId], references: [id])
  sentAt         DateTime             @default(now())

  @@unique([leadId, sequenceStepId])
}

// Envoi ponctuel (immédiat ou programmé) à toute une liste — le "envoyer un
// mail à tous mes clients" en un clic, en plus des tunnels automatiques.
model Broadcast {
  id          String    @id @default(cuid())
  authorId    String
  author      Author    @relation(fields: [authorId], references: [id])
  listSource  String    // "extrait" | "acheteur" | "tous"
  subject     String
  body        String
  scheduledAt DateTime
  sentAt      DateTime?
  recipients  Int?      // nombre de destinataires au moment de l'envoi
  status      String    @default("scheduled") // "scheduled" | "sent" | "failed"
  createdAt   DateTime  @default(now())
}
FILE_EOF_MARKER

mkdir -p "$(dirname ".env.example")"
cat > ".env.example" << 'FILE_EOF_MARKER'
# Base de données (Neon, Supabase, ou tout Postgres compatible serverless)
DATABASE_URL="postgresql://user:password@host/db?sslmode=require"

# Auth
JWT_SECRET="remplace-moi-par-une-longue-chaine-aleatoire"

# URL publique de l'app (utilisée dans les redirections de paiement)
APP_URL="https://votre-app.vercel.app"

# Stripe (zone Europe — vente de livres + reversements réels via Payouts API)
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."

# Chariow (zone Afrique francophone — vente de livres, + abonnement plateforme
# pour LES DEUX zones)
CHARIOW_API_KEY=""
CHARIOW_SUBSCRIPTION_PRODUCT_ID=""
# Secret partagé pour sécuriser le webhook Chariow (aucune signature HMAC
# officielle confirmée à ce jour) — génère une longue chaîne aléatoire, mets
# la même valeur ici et dans l'URL configurée côté Chariow :
# https://ton-domaine.vercel.app/api/webhooks/chariow?secret=CETTE_VALEUR
CHARIOW_WEBHOOK_SECRET=""
# Commission Chariow par vente (0.15 = 15%, baisse à 0.10 à volume selon leur grille)
CHARIOW_COMMISSION_RATE="0.15"
# Délai avant qu'une vente Afrique soit considérée "disponible" au reversement
CHARIOW_PAYOUT_MATURITY_DAYS="5"

# Anthropic (génération IA réelle : page de vente + contenu réseaux sociaux)
ANTHROPIC_API_KEY=""

# Vercel Blob — stockage des fichiers livres uploadés
BLOB_READ_WRITE_TOKEN=""

# Resend — envoi d'email transactionnel (extrait PDF, confirmation d'achat)
RESEND_API_KEY=""
RESEND_FROM_EMAIL="Plume <contact@votre-domaine.com>"

# WhatsApp Cloud API (Meta) — tunnels de vente WhatsApp (voir lib/whatsapp.js)
# Créer une app sur developers.facebook.com > WhatsApp > API Setup :
#   WHATSAPP_ACCESS_TOKEN       = token d'accès permanent (System User, jamais le token temporaire 24h)
#   WHATSAPP_PHONE_NUMBER_ID    = "Phone number ID" affiché dans API Setup
#   WHATSAPP_BUSINESS_ACCOUNT_ID = "WhatsApp Business Account ID" (nécessaire pour soumettre le modèle de message)
# Sans ces variables, les tunnels WhatsApp restent modifiables mais aucun
# message ne part (fail-open, comme Resend). Une fois configurées, soumettre
# le modèle générique depuis le dashboard (Tunnels de vente > WhatsApp >
# "Soumettre le modèle à Meta") — à faire une seule fois.
WHATSAPP_ACCESS_TOKEN=""
WHATSAPP_PHONE_NUMBER_ID=""
WHATSAPP_BUSINESS_ACCOUNT_ID=""
# Optionnel — valeurs par défaut déjà correctes, à changer seulement si le nom
# du modèle doit être différent (ex. plusieurs modèles pour plusieurs langues).
WHATSAPP_TEMPLATE_NAME="plume_tunnel_fr"
WHATSAPP_TEMPLATE_LANG="fr"

# Secret utilisé par Vercel Cron pour appeler /api/cron/process-emails en
# sécurité (Vercel l'ajoute automatiquement dans l'en-tête Authorization
# des appels de cron déclenchés depuis vercel.json — génère une longue
# chaîne aléatoire et mets la MÊME valeur ici et dans Vercel).
CRON_SECRET=""

# Upstash Redis — rate limiting sur les routes publiques (login, signup,
# leads/capture, checkout/create). Compte gratuit sur upstash.com, section
# "REST API" du dashboard Redis. Sans ces deux valeurs, le rate limiting
# est simplement désactivé (fail-open) — l'app reste utilisable.
UPSTASH_REDIS_REST_URL=""
UPSTASH_REDIS_REST_TOKEN=""

# Cloudflare Turnstile — anti-bot invisible sur les formulaires publics.
# Compte gratuit sur dash.cloudflare.com (section Turnstile). TURNSTILE_SITE_KEY
# est publique (utilisée côté frontend pour afficher le widget), SECRET_KEY
# ne doit jamais être exposée. Sans SECRET_KEY, seul le honeypot reste actif.
TURNSTILE_SITE_KEY=""
TURNSTILE_SECRET_KEY=""
FILE_EOF_MARKER

mkdir -p "$(dirname "lib/whatsapp.js")"
cat > "lib/whatsapp.js" << 'FILE_EOF_MARKER'
// Envoi WhatsApp transactionnel/marketing via l'API officielle Meta
// (WhatsApp Cloud API) — https://developers.facebook.com/docs/whatsapp
//
// Pourquoi un "modèle" (template) : WhatsApp interdit d'envoyer un message
// automatique (non déclenché par une réponse récente du contact) sans passer
// par un modèle pré-approuvé par Meta. On utilise donc UN SEUL modèle
// générique, à variable libre — "{{1}}" — approuvé une fois pour toutes
// (voir submitWhatsAppTemplate ci-dessous, déclenché depuis le dashboard).
// Tout le texte que l'auteur personnalise ensuite dans ses tunnels (comme
// pour l'email) part comme valeur de cette variable, sans jamais nécessiter
// une nouvelle approbation Meta.
//
// Nécessite WHATSAPP_ACCESS_TOKEN et WHATSAPP_PHONE_NUMBER_ID (pour
// envoyer), et en plus WHATSAPP_BUSINESS_ACCOUNT_ID (pour soumettre le
// modèle une seule fois). Sans ces variables, les envois sont simplement
// ignorés (fail-open), comme pour lib/email.js.
const ACCESS_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN;
const PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID;
const BUSINESS_ACCOUNT_ID = process.env.WHATSAPP_BUSINESS_ACCOUNT_ID;
const TEMPLATE_NAME = process.env.WHATSAPP_TEMPLATE_NAME || "plume_tunnel_fr";
const TEMPLATE_LANG = process.env.WHATSAPP_TEMPLATE_LANG || "fr";

const GRAPH_VERSION = "v21.0";

function cleanNumber(value) {
  return (value || "").replace(/[^0-9]/g, "");
}

export function isWhatsAppConfigured() {
  return Boolean(ACCESS_TOKEN && PHONE_NUMBER_ID);
}

// Envoie un message WhatsApp via le modèle générique approuvé, avec
// `bodyText` comme unique variable. Retourne { sent: false } silencieusement
// si WhatsApp n'est pas configuré ou si le numéro est invalide — jamais
// d'exception, pour ne jamais faire planter le cron qui traite tous les
// contacts.
export async function sendWhatsAppMessage({ to, bodyText }) {
  if (!isWhatsAppConfigured()) {
    console.warn("WHATSAPP_ACCESS_TOKEN/WHATSAPP_PHONE_NUMBER_ID manquants — message WhatsApp non envoyé (à configurer).");
    return { sent: false };
  }

  const number = cleanNumber(to);
  if (!number) return { sent: false };

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${PHONE_NUMBER_ID}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: number,
      type: "template",
      template: {
        name: TEMPLATE_NAME,
        language: { code: TEMPLATE_LANG },
        components: [
          {
            type: "body",
            parameters: [{ type: "text", text: (bodyText || "").slice(0, 1024) }],
          },
        ],
      },
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi WhatsApp :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

// Soumet UNE FOIS le modèle générique à Meta pour approbation — appelé
// depuis le dashboard (bouton "Soumettre le modèle"), jamais automatiquement,
// car il ne doit être créé qu'une seule fois par compte WhatsApp Business.
// Le statut initial est toujours "PENDING" ; Meta l'approuve généralement en
// quelques minutes à 24h. Si le modèle existe déjà, Meta renvoie une erreur
// explicite que l'on remonte telle quelle (ce n'est pas un échec réel).
export async function submitWhatsAppTemplate() {
  if (!ACCESS_TOKEN || !BUSINESS_ACCOUNT_ID) {
    return { ok: false, error: "WHATSAPP_ACCESS_TOKEN ou WHATSAPP_BUSINESS_ACCOUNT_ID manquant dans les variables Vercel." };
  }

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${BUSINESS_ACCOUNT_ID}/message_templates`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: TEMPLATE_NAME,
      language: TEMPLATE_LANG,
      category: "MARKETING",
      components: [
        {
          type: "BODY",
          text: "{{1}}",
          example: { body_text: [["Bonjour ! Voici un exemple de message envoyé automatiquement par Plume."]] },
        },
      ],
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { ok: false, error: data?.error?.error_user_msg || data?.error?.message || `Erreur ${res.status}` };
  }
  return { ok: true, status: data.status || "PENDING", templateId: data.id };
}

// Vérifie le statut d'approbation du modèle auprès de Meta (APPROVED /
// PENDING / REJECTED) — utilisé par le dashboard pour afficher l'état réel
// sans que l'auteur ait à se connecter lui-même à Meta Business Manager.
export async function getWhatsAppTemplateStatus() {
  if (!ACCESS_TOKEN || !BUSINESS_ACCOUNT_ID) {
    return { configured: false };
  }

  const params = new URLSearchParams({ name: TEMPLATE_NAME });
  const res = await fetch(
    `https://graph.facebook.com/${GRAPH_VERSION}/${BUSINESS_ACCOUNT_ID}/message_templates?${params.toString()}`,
    { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } }
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { configured: true, submitted: false, error: data?.error?.message || `Erreur ${res.status}` };
  }

  const template = (data.data || []).find((t) => t.name === TEMPLATE_NAME);
  if (!template) return { configured: true, submitted: false };
  return { configured: true, submitted: true, status: template.status };
}
FILE_EOF_MARKER

mkdir -p "$(dirname "lib/whatsappSequences.js")"
cat > "lib/whatsappSequences.js" << 'FILE_EOF_MARKER'
// Tunnels WhatsApp par défaut — même logique que lib/sequences.js (email),
// adaptée au ton plus court et direct de WhatsApp. Chaque auteur reçoit ces
// deux séquences automatiquement, modifiables ensuite dans son dashboard
// (PATCH /api/whatsapp-sequences/steps/[id]).
//
// Variables disponibles dans le texte, remplacées à l'envoi (voir
// renderTemplate, réutilisé depuis lib/sequences.js) :
// {{prenom}}, {{titre}}, {{auteur}}, {{lien_achat}}, {{lien_boutique}}

export const DEFAULT_WHATSAPP_SEQUENCES = {
  extrait: {
    name: "Tunnel WhatsApp — Lecteurs de l’extrait",
    steps: [
      {
        order: 1,
        delayDays: 1,
        body: "Bonjour {{prenom}} 👋 J’espère que l’extrait de « {{titre}} » vous a plu ! Le livre complet est disponible ici : {{lien_achat}}",
      },
      {
        order: 2,
        delayDays: 3,
        body: "Bonjour {{prenom}}, sans trop en dire : la suite de « {{titre}} » va encore plus loin que l’extrait. Beaucoup de lecteurs me disent que c’est là que tout prend son sens 📖 {{lien_achat}}",
      },
      {
        order: 3,
        delayDays: 5,
        body: "Bonjour {{prenom}}, je voulais partager pourquoi j’ai écrit « {{titre}} » : [racontez ici votre histoire en une ou deux phrases]. Si ça vous parle : {{lien_achat}}",
      },
      {
        order: 4,
        delayDays: 7,
        body: "Bonjour {{prenom}}, si vous hésitez encore sur « {{titre}} » : [répondez ici à l’objection la plus fréquente, ex. « ça se lit en un week-end »]. {{lien_achat}}",
      },
      {
        order: 5,
        delayDays: 9,
        body: "Bonjour {{prenom}}, [ajoutez ici un témoignage court d’un lecteur]. Si vous voulez vivre la même expérience : {{lien_achat}}",
      },
      {
        order: 6,
        delayDays: 12,
        body: "Bonjour {{prenom}}, on remet souvent la lecture à plus tard — et « plus tard » n’arrive jamais vraiment 😉 Le bon moment pour « {{titre}} », c’est maintenant : {{lien_achat}}",
      },
      {
        order: 7,
        delayDays: 15,
        body: "Bonjour {{prenom}}, dernier message à ce sujet, promis 🙂 « {{titre}} » reste disponible ici si vous changez d’avis : {{lien_achat}} Merci de m’avoir lu(e) jusqu’ici.",
      },
    ],
  },

  acheteur: {
    name: "Tunnel WhatsApp — Lecteurs qui ont acheté",
    steps: [
      {
        order: 1,
        delayDays: 2,
        body: "Bonjour {{prenom}}, merci encore pour votre achat de « {{titre}} » ! Comment se passe la lecture ? N’hésitez pas à me répondre ici si besoin 🙂",
      },
      {
        order: 2,
        delayDays: 5,
        body: "Bonjour {{prenom}}, maintenant que vous avancez dans « {{titre}} », je voulais partager [une réflexion ou un petit bonus lié au livre]. J’espère que ça enrichira votre lecture !",
      },
      {
        order: 3,
        delayDays: 7,
        body: "Bonjour {{prenom}}, si « {{titre}} » vous plaît, un avis de votre part m’aiderait énormément à toucher d’autres lecteurs 🙏 Merci d’avance !",
      },
      {
        order: 4,
        delayDays: 10,
        body: "Bonjour {{prenom}}, la question qu’on me pose le plus sur « {{titre}} » : [ajoutez ici la question et votre réponse].",
      },
      {
        order: 5,
        delayDays: 14,
        body: "Bonjour {{prenom}}, si vous voulez suivre mes prochains projets : [ajoutez ici votre lien réseaux sociaux ou communauté]. À bientôt !",
      },
      {
        order: 6,
        delayDays: 21,
        body: "Bonjour {{prenom}}, si « {{titre}} » vous a marqué(e), le plus beau cadeau que vous puissiez me faire c’est d’en parler autour de vous 💛 Merci du fond du cœur !",
      },
      {
        order: 7,
        delayDays: 30,
        body: "Bonjour {{prenom}}, j’espère que « {{titre}} » vous a plu du début à la fin. Pour découvrir mes autres livres : {{lien_boutique}} Merci de votre confiance !",
      },
    ],
  },
};
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/cron/process-emails.js")"
cat > "pages/api/cron/process-emails.js" << 'FILE_EOF_MARKER'
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

  // --- 2. Tunnels automatiques WhatsApp — même logique que les tunnels
  // email ci-dessus, canal séparé (voir lib/whatsapp.js). N'envoie rien si
  // WHATSAPP_ACCESS_TOKEN/WHATSAPP_PHONE_NUMBER_ID ne sont pas configurés
  // (sendWhatsAppMessage renvoie simplement { sent: false }).
  const whatsAppSequences = await prisma.whatsAppSequence.findMany({
    where: { active: true },
    include: {
      steps: { orderBy: { order: "asc" } },
      author: { select: { id: true, name: true, region: true, subscriptionStatus: true, trialEndsAt: true } },
    },
  });

  for (const sequence of whatsAppSequences) {
    if (!isSubscriptionActive(sequence.author)) {
      skippedInactiveSubscription += 1;
      continue;
    }

    const leads = await prisma.lead.findMany({
      where: { authorId: sequence.authorId, source: sequence.listSource },
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

      const result = await sendWhatsAppMessage({
        to: lead.whatsapp,
        bodyText: renderTemplate(nextStep.body, vars),
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

  return res.status(200).json({ sequenceEmailsSent, sequenceWhatsAppSent, broadcastsSent, skippedInactiveSubscription });
}
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/whatsapp/submit-template.js")"
cat > "pages/api/whatsapp/submit-template.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { submitWhatsAppTemplate } from "../../../lib/whatsapp";

// Déclenché depuis le bouton "Soumettre le modèle" du dashboard — soumet UNE
// FOIS le modèle générique WhatsApp à Meta pour approbation. N'importe quel
// auteur connecté peut déclencher cet appel (il n'y a qu'un compte WhatsApp
// Business Plume, partagé par la plateforme — les identifiants viennent des
// variables Vercel, pas d'un compte par auteur).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const result = await submitWhatsAppTemplate();
    if (!result.ok) return res.status(400).json({ error: result.error });
    return res.status(200).json(result);
  } catch (error) {
    console.error("Erreur /api/whatsapp/submit-template :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/whatsapp-sequences/index.js")"
cat > "pages/api/whatsapp-sequences/index.js" << 'FILE_EOF_MARKER'
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
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/whatsapp-sequences/[id].js")"
cat > "pages/api/whatsapp-sequences/[id].js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Active/désactive un tunnel WhatsApp — équivalent de /api/sequences/[id].
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { id } = req.query;
  const { active } = req.body;

  try {
    const sequence = await prisma.whatsAppSequence.findFirst({ where: { id, authorId: req.authorId } });
    if (!sequence) return res.status(404).json({ error: "Tunnel introuvable" });

    const updated = await prisma.whatsAppSequence.update({
      where: { id },
      data: { active: Boolean(active) },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur /api/whatsapp-sequences/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/whatsapp-sequences/steps/[stepId].js")"
cat > "pages/api/whatsapp-sequences/steps/[stepId].js" << 'FILE_EOF_MARKER'
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
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/dashboard/tunnels.js")"
cat > "pages/dashboard/tunnels.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import { Mail, MessageCircle, ChevronDown, ChevronRight, Check, AlertTriangle, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const LIST_TABS = [
  { id: "extrait", label: "Lecteurs de l’extrait" },
  { id: "acheteur", label: "Lecteurs qui ont acheté" },
];

function Toggle({ checked, onChange }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="relative inline-flex items-center rounded-full transition-colors shrink-0"
      style={{ width: 40, height: 22, backgroundColor: checked ? colors.forest : colors.mist }}
    >
      <span
        className="inline-block rounded-full bg-white transition-transform"
        style={{ width: 16, height: 16, transform: `translateX(${checked ? 21 : 3}px)` }}
      />
    </button>
  );
}

// Étape d'un tunnel. `channel` ("email" | "whatsapp") détermine si un champ
// "objet" est affiché (WhatsApp n'a qu'un corps de message).
function SequenceStep({ step, channel, onSave }) {
  const [open, setOpen] = useState(false);
  const [subject, setSubject] = useState(step.subject || "");
  const [body, setBody] = useState(step.body);
  const [delayDays, setDelayDays] = useState(step.delayDays);
  const [saved, setSaved] = useState(false);

  async function persist(patch) {
    await onSave(step.id, patch);
    setSaved(true);
    setTimeout(() => setSaved(false), 1200);
  }

  const headerLabel = channel === "email" ? subject : body;

  return (
    <div className="rounded-xl overflow-hidden" style={{ border: `1px solid ${colors.paperDim}` }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between gap-3 px-4 py-3 text-left"
        style={{ backgroundColor: colors.paperDim }}
      >
        <div className="flex items-center gap-3 min-w-0">
          {open ? <ChevronDown size={15} color={colors.textPaperDim} /> : <ChevronRight size={15} color={colors.textPaperDim} />}
          <span className="font-mono text-[10px] shrink-0 px-2 py-0.5 rounded-full" style={{ backgroundColor: colors.gold, color: colors.ink }}>
            J+{step.delayDays}
          </span>
          <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{headerLabel}</p>
        </div>
        {saved && <Check size={14} color={colors.forest} className="shrink-0" />}
      </button>

      {open && (
        <div className="p-4 space-y-3" style={{ backgroundColor: "#FFFFFF" }}>
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>Délai (jours après l’entrée dans la liste)</p>
            <input
              type="number"
              min="0"
              value={delayDays}
              onChange={(e) => setDelayDays(e.target.value)}
              onBlur={() => persist({ delayDays: Number(delayDays) })}
              className="w-24 rounded-lg px-3 py-2 font-body text-sm"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />
          </div>
          {channel === "email" && (
            <div>
              <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>Objet de l’email</p>
              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                onBlur={() => persist({ subject })}
                className="w-full rounded-lg px-3 py-2 font-body text-sm"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>
          )}
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
              {channel === "email" ? "Contenu" : "Message WhatsApp"}
            </p>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              onBlur={() => persist({ body })}
              rows={channel === "email" ? 7 : 5}
              maxLength={channel === "whatsapp" ? 1024 : undefined}
              className="w-full rounded-lg px-3 py-2 font-body text-sm resize-y"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />
            {channel === "whatsapp" && (
              <p className="font-mono text-[10px] mt-1" style={{ color: colors.mist }}>{body.length} / 1024 caractères</p>
            )}
            <p className="font-mono text-[10px] mt-1.5" style={{ color: colors.mist }}>
              Variables disponibles : {"{{prenom}}"}, {"{{titre}}"}, {"{{auteur}}"}, {"{{lien_achat}}"}, {"{{lien_boutique}}"}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

// Bandeau affiché tant que le modèle WhatsApp générique n'est pas approuvé
// par Meta — avant ça, aucun message WhatsApp automatique ne peut partir.
function WhatsAppTemplateStatus({ template, onSubmit, submitting, submitError }) {
  if (!template || !template.configured) {
    return (
      <div className="flex items-start gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(122,46,59,0.1)" }}>
        <AlertTriangle size={14} color={colors.wine} className="mt-0.5 shrink-0" />
        <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
          WhatsApp n’est pas encore connecté sur la plateforme (variables WHATSAPP_ACCESS_TOKEN /
          WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_BUSINESS_ACCOUNT_ID manquantes côté Vercel). Les tunnels restent
          modifiables, mais aucun message ne partira tant que ce n’est pas configuré.
        </p>
      </div>
    );
  }

  if (!template.submitted) {
    return (
      <div className="flex items-start gap-3 px-4 py-3 rounded-xl mb-4 flex-wrap" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
        <AlertTriangle size={14} color={colors.goldDark} className="mt-0.5 shrink-0" />
        <div className="flex-1 min-w-[200px]">
          <p className="font-body text-xs mb-2" style={{ color: colors.textPaperDim }}>
            Le modèle de message WhatsApp n’a pas encore été soumis à Meta pour approbation — étape unique, à faire une
            seule fois pour toute la plateforme.
          </p>
          <ErrorBanner message={submitError} />
          <button
            onClick={onSubmit}
            disabled={submitting}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg font-body font-semibold text-xs mt-1"
            style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
          >
            {submitting && <Loader2 size={12} className="animate-spin" />}
            {submitting ? "Envoi…" : "Soumettre le modèle à Meta"}
          </button>
        </div>
      </div>
    );
  }

  if (template.status !== "APPROVED") {
    return (
      <div className="flex items-center gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
        <Loader2 size={14} color={colors.goldDark} className="shrink-0" />
        <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
          Modèle soumis à Meta, en attente d’approbation (statut : {template.status || "en cours"}) — généralement
          quelques minutes à 24h. Les messages partiront automatiquement dès l’approbation.
        </p>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
      <Check size={14} color={colors.forest} className="shrink-0" />
      <p className="font-body text-xs" style={{ color: colors.forest }}>Modèle WhatsApp approuvé — les tunnels WhatsApp sont actifs.</p>
    </div>
  );
}

export default function DashboardTunnels() {
  const { author, loading: authLoading } = useAuthGuard();

  const [channel, setChannel] = useState("email");
  const [tab, setTab] = useState("extrait");

  const [emailSequences, setEmailSequences] = useState([]);
  const [waSequences, setWaSequences] = useState([]);
  const [waTemplate, setWaTemplate] = useState(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [togglingId, setTogglingId] = useState(null);

  const [submittingTemplate, setSubmittingTemplate] = useState(false);
  const [templateSubmitError, setTemplateSubmitError] = useState("");

  useEffect(() => {
    if (!author) return;
    setLoading(true);
    setError("");
    Promise.all([api("/api/sequences"), api("/api/whatsapp-sequences")])
      .then(([email, wa]) => {
        setEmailSequences(email);
        setWaSequences(wa.sequences);
        setWaTemplate(wa.template);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  async function handleStepSave(stepId, patch) {
    try {
      const path = channel === "email" ? `/api/sequences/steps/${stepId}` : `/api/whatsapp-sequences/steps/${stepId}`;
      await api(path, { method: "PATCH", body: patch });
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleToggleActive(sequence) {
    setTogglingId(sequence.id);
    try {
      const path = channel === "email" ? `/api/sequences/${sequence.id}` : `/api/whatsapp-sequences/${sequence.id}`;
      const updated = await api(path, { method: "PATCH", body: { active: !sequence.active } });
      const setter = channel === "email" ? setEmailSequences : setWaSequences;
      setter((seqs) => seqs.map((s) => (s.id === updated.id ? { ...s, active: updated.active } : s)));
    } catch (err) {
      setError(err.message);
    } finally {
      setTogglingId(null);
    }
  }

  async function handleSubmitTemplate() {
    setTemplateSubmitError("");
    setSubmittingTemplate(true);
    try {
      await api("/api/whatsapp/submit-template", { method: "POST" });
      const wa = await api("/api/whatsapp-sequences");
      setWaTemplate(wa.template);
    } catch (err) {
      setTemplateSubmitError(err.message);
    } finally {
      setSubmittingTemplate(false);
    }
  }

  const sequences = channel === "email" ? emailSequences : waSequences;
  const current = sequences.find((s) => s.listSource === tab);
  const Icon = channel === "email" ? Mail : MessageCircle;
  const unitLabel = channel === "email" ? "email" : "message";

  return (
    <DashboardShell active="tunnels" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Autorépondeur</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Tunnels de vente</h1>
      </header>

      {authLoading || loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl">
          <ErrorBanner message={error} />

          <div className="flex gap-2 mb-3 mt-3">
            {[{ id: "email", label: "Email", icon: Mail }, { id: "whatsapp", label: "WhatsApp", icon: MessageCircle }].map((c) => (
              <button
                key={c.id}
                onClick={() => setChannel(c.id)}
                className="flex items-center gap-1.5 px-4 py-1.5 rounded-full font-body text-xs font-semibold"
                style={{
                  backgroundColor: channel === c.id ? colors.ink : colors.paper,
                  color: channel === c.id ? colors.paper : colors.textPaperDim,
                }}
              >
                <c.icon size={13} /> {c.label}
              </button>
            ))}
          </div>

          {channel === "whatsapp" && (
            <WhatsAppTemplateStatus
              template={waTemplate}
              onSubmit={handleSubmitTemplate}
              submitting={submittingTemplate}
              submitError={templateSubmitError}
            />
          )}

          <div className="flex gap-2 mb-4">
            {LIST_TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className="px-4 py-1.5 rounded-full font-body text-xs font-semibold"
                style={{
                  backgroundColor: tab === t.id ? colors.gold : colors.paper,
                  color: tab === t.id ? colors.ink : colors.textPaperDim,
                }}
              >
                {t.label}
              </button>
            ))}
          </div>

          {!current ? (
            <p className="font-body text-sm py-8 text-center" style={{ color: colors.mist }}>Tunnel introuvable.</p>
          ) : (
            <div className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
              <div className="flex items-center justify-between gap-3 mb-5 pb-5 border-b" style={{ borderColor: colors.paperDim }}>
                <div className="flex items-center gap-2 min-w-0">
                  <Icon size={16} color={colors.goldDark} className="shrink-0" />
                  <div className="min-w-0">
                    <p className="font-display text-lg truncate" style={{ color: colors.textPaper }}>{current.name}</p>
                    <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                      {current.steps.length} {unitLabel}{current.steps.length > 1 ? "s" : ""} automatique{current.steps.length > 1 ? "s" : ""} — {current.active ? "actif" : "en pause"}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {togglingId === current.id && <Spinner size={13} color={colors.goldDark} />}
                  <Toggle checked={current.active} onChange={() => handleToggleActive(current)} />
                </div>
              </div>

              <div className="space-y-2">
                {current.steps.map((step) => (
                  <SequenceStep key={step.id} step={step} channel={channel} onSave={handleStepSave} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

echo "Termine."
