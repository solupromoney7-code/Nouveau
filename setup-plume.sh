#!/bin/bash
# Recrée l'intégralité du projet Plume dans le dossier courant.
# Généré automatiquement à partir du code validé — ne pas modifier à la main.
set -e

echo "Création des dossiers..."
mkdir -p "lib"
mkdir -p "pages/api/auth"
mkdir -p "pages/api/authors"
mkdir -p "pages/api/books"
mkdir -p "pages/api/broadcasts"
mkdir -p "pages/api/checkout"
mkdir -p "pages/api/contacts"
mkdir -p "pages/api/content"
mkdir -p "pages/api/cron"
mkdir -p "pages/api/extract-pages"
mkdir -p "pages/api/leads"
mkdir -p "pages/api/payouts"
mkdir -p "pages/api/public"
mkdir -p "pages/api/sales-pages"
mkdir -p "pages/api/sequences"
mkdir -p "pages/api/sequences/steps"
mkdir -p "pages/api/stripe/connect"
mkdir -p "pages/api/subscriptions"
mkdir -p "pages/api/webhooks"
mkdir -p "prisma"

echo "-> .env.example"
cat > '.env.example' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> .gitignore"
cat > '.gitignore' << 'PLUMEFILE_EOF'
node_modules/
.next/
.env
.env.local
.vercel
*.log
PLUMEFILE_EOF

echo "-> README.md"
cat > 'README.md' << 'PLUMEFILE_EOF'
# Plume — Backend

API Next.js (routes API) + Prisma/PostgreSQL, avec :
- **Stripe Connect** (zone Europe) pour la vente de livres,
- **Chariow** (zone Afrique francophone) pour la vente de livres,
- **Chariow** pour l'abonnement à la plateforme (les deux zones),
- **Vraie génération IA** (API Anthropic / Claude) pour la page de vente et le contenu réseaux sociaux.

Correspond au cahier des charges "MVP" et à sa section §5bis (architecture des paiements).

## Important à lire avant de déployer

- Ce code est **fonctionnel dans sa structure** mais ne contient aucune
  vraie clé API. Il ne recevra pas de vrais paiements ni ne générera de
  vrai contenu IA tant que tu n'as pas renseigné tes propres clés.
- **Chariow — un point à vérifier avant la mise en production** : la
  documentation publique de Chariow confirme le checkout (`POST /v1/checkout`)
  et la vérification de vente (`GET /v1/sales`), mais pas le schéma exact de
  création de produit par API. La fonction `createChariowProduct` dans
  `lib/chariow.js` est une implémentation best-effort. Si elle échoue en
  pratique, crée le produit du livre manuellement dans ton dashboard Chariow
  et colle son `product_id` dans `SalesPage.chariowProductId` (via Prisma
  Studio ou une petite requête SQL).
- **Chariow — noms d'événements** : `sale.completed` est confirmé. Les noms
  exacts des événements d'abonnement (échec de paiement, annulation) sont à
  vérifier dans Réglages > Pulses de ton dashboard Chariow — ajuste
  `pages/api/webhooks/chariow.js` en conséquence si les noms diffèrent de
  `subscription.payment_failed` / `subscription.cancelled`.
- L'envoi d'email de l'extrait PDF (`pages/api/leads/capture.js`) n'est pas
  branché — à faire avec un service comme Resend ou SendGrid.
- Aucune clé secrète n'est jamais manipulée côté frontend.

## Stack

- **Next.js (Pages Router, API routes)** — nativement compatible Vercel
- **Prisma + PostgreSQL** — utiliser un Postgres serverless comme
  [Neon](https://neon.tech) ou [Supabase](https://supabase.com)
- **Vercel Blob** — stockage des fichiers livres uploadés
- **Stripe** (Connect Express) — vente de livres, zone Europe
- **Chariow** — vente de livres (zone Afrique) + abonnement plateforme (les deux zones)
- **API Anthropic (Claude)** — génération de la page de vente et du contenu réseaux

### Pourquoi Vercel plutôt que Netlify ici

Ce projet est écrit avec les routes API Next.js, natives sur Vercel. Pour
déployer sur Netlify, il faudrait soit adapter le projet avec le plugin
`@netlify/plugin-nextjs`, soit réécrire les routes en Netlify Functions.

## Installation locale

```bash
npm install
cp .env.example .env
# remplir .env avec tes vraies valeurs (voir sections ci-dessous)
npx prisma migrate dev --name init
npm run dev
```

## 1. Base de données

1. Crée un projet sur [neon.tech](https://neon.tech).
2. Copie la `DATABASE_URL` dans `.env`.
3. `npx prisma migrate dev --name init` pour créer les tables.

## 2. API Anthropic (génération IA réelle)

1. Crée une clé sur [console.anthropic.com](https://console.anthropic.com).
2. Renseigne `ANTHROPIC_API_KEY` dans `.env`.
3. La génération de la page de vente (`POST /api/sales-pages`) et du contenu
   réseaux (`POST /api/content/generate`) appellent maintenant réellement
   l'API Claude — voir `lib/ai.js`. Le texte du livre est extrait du PDF
   avec `pdf-parse` avant d'être envoyé au modèle.
4. Pour l'EPUB ou d'autres formats, il faudra ajouter un parseur dédié dans
   `extractBookText` (`lib/ai.js`).

## 3. Stripe Connect (zone Europe — vente de livres)

1. Crée un compte sur [dashboard.stripe.com](https://dashboard.stripe.com).
2. Active **Connect** (mode Express).
3. Récupère `STRIPE_SECRET_KEY` dans Développeurs > Clés API.
4. Ajoute un endpoint webhook vers
   `https://ton-domaine.vercel.app/api/webhooks/stripe`, écoutant :
   - `checkout.session.completed`
   - `account.updated`
5. Copie le secret de signature dans `STRIPE_WEBHOOK_SECRET`.

Flux auteur : le dashboard appelle `POST /api/stripe/connect/onboarding`
(authentifié) puis redirige l'auteur vers l'URL renvoyée.

## 4. Chariow (zone Afrique — vente de livres, + abonnement pour tous)

### 4.1 — Activer la réception d'argent (côté Chariow, une fois)

Avant même de connecter le code, assure-toi que ton compte Chariow peut
réellement encaisser :
1. Active ton **wallet Axa Zara** sur [account.axazara.com](https://account.axazara.com) avec les mêmes identifiants que Chariow. Crée ton code PIN à 5 chiffres (demandé à chaque opération sensible).
2. Complète la **vérification d'identité** (KYC) — obligatoire pour débloquer les retraits.
3. Ajoute ton **numéro Mobile Money** de retrait dans les paramètres Axa Zara. C'est le seul moyen de retrait proposé par Chariow (pas de virement bancaire).
4. Les ventes du jour sont regroupées le lendemain dans "Revenus", puis transférées vers ton wallet Axa Zara sous 72h max, d'où tu peux initier un retrait vers ton Mobile Money.
5. Chariow prélève une commission d'environ **15 % par vente** (10 % à volume) — à garder en tête pour ta marge.

### 4.2 — Connecter le code à ton compte

1. Dans ton dashboard Chariow : **Paramètres → Clés API**, crée une clé (`sk_live_...`) et copie-la.
2. Renseigne `CHARIOW_API_KEY` dans `.env` (et dans Vercel au moment du déploiement).
3. **Produit d'abonnement** : crée un produit "Abonnement Plume" dans ton
   dashboard Chariow, note son `product_id`, et renseigne-le dans
   `CHARIOW_SUBSCRIPTION_PRODUCT_ID`. Un seul produit suffit pour les deux
   zones : le paramètre `payment_currency` (EUR ou XOF selon la région de
   l'auteur) déclenche la conversion automatique côté Chariow.
4. **Produits livres (zone Afrique)** : provisionnés automatiquement à la
   génération de la page de vente (voir avertissement plus haut sur le
   schéma non confirmé — prévoir un fallback manuel : créer le produit du
   livre toi-même dans le dashboard si l'automatique échoue).
5. Dans les réglages **Webhooks / Pulses** de Chariow, configure l'URL de notification :
   `https://ton-domaine.vercel.app/api/webhooks/chariow`
   et active au minimum l'événement de vente complétée.

Flux auteur pour l'abonnement : le dashboard appelle
`POST /api/subscriptions/checkout` (authentifié) puis redirige l'auteur vers
l'URL renvoyée.

**Important** : que ce soit un abonnement ou une vente de livre en Afrique,
l'argent arrive dans TON compte Chariow (celui que tu viens de configurer
en 4.1) — pas directement chez l'auteur. Voir la note sur le reversement
manuel plus bas.

## 5. Resend (emails transactionnels)

1. Crée un compte sur [resend.com](https://resend.com).
2. Vérifie un domaine d'envoi (ou utilise leur domaine de test en développement).
3. Récupère ta clé API et renseigne `RESEND_API_KEY`.
4. Renseigne `RESEND_FROM_EMAIL` avec une adresse expéditrice vérifiée, ex.
   `"Plume <contact@ton-domaine.com>"`.
5. Sans ces deux variables, `lib/email.js` n'envoie rien silencieusement (juste
   un avertissement en log) — l'app continue de fonctionner, mais le PDF
   d'extrait et la confirmation d'achat ne partent pas par email.

## 6. Déploiement sur Vercel

```bash
npm i -g vercel
vercel
```

Ajoute toutes les variables de `.env.example` dans Vercel > Project Settings
> Environment Variables, puis redéploie. Crée `BLOB_READ_WRITE_TOKEN` via
Vercel > Storage > Blob.

## Routes principales

| Route | Méthode | Auth | Description |
|---|---|---|---|
| `/api/auth/signup` | POST | non | Créer un compte auteur (rate limité, anti-bot) |
| `/api/auth/login` | POST | non | Connexion (rate limité) |
| `/api/auth/verify-email` | GET | non | Confirme l'email via le lien reçu |
| `/api/auth/resend-verification` | POST | oui | Renvoie l'email de confirmation |
| `/api/authors/me` | GET | oui | Profil auteur |
| `/api/authors/payment-config` | GET/PUT | oui | Config Mobile Money (info, hors Chariow) |
| `/api/stripe/connect/onboarding` | POST | oui | Lien d'onboarding Stripe (zone Europe) |
| `/api/books/upload` | POST | oui | Upload du fichier livre (Vercel Blob) |
| `/api/sales-pages` | POST | oui | Génère une page de vente (vraie IA) + produit Chariow si zone Afrique |
| `/api/sales-pages/[id]` | GET/PATCH | oui | Lire / éditer une page de vente |
| `/api/extract-pages` | POST | oui | Génère une page d'extrait |
| `/api/leads/capture` | POST | non | Formulaire de capture (page d'extrait publique) |
| `/api/checkout/create` | POST | non | Paiement acheteur d'un livre (Stripe ou Chariow) |
| `/api/subscriptions/checkout` | POST | oui | Paiement de l'abonnement plateforme (Chariow) |
| `/api/webhooks/stripe` | POST | non | Webhook Stripe (vente livre Europe + Connect) |
| `/api/webhooks/chariow` | POST | non | Pulse Chariow (vente livre Afrique + abonnement) |
| `/api/contacts` | GET | oui | Liste "Acheteurs" ou "Extrait" |
| `/api/content/generate` | POST | oui | Génération contenu réseaux (vraie IA, gated abonnement) |
| `/api/payouts/balance` | GET | oui | Solde disponible (Stripe Balance réel en Europe, ledger local en Afrique) |
| `/api/payouts/request` | POST | oui | Demande de reversement — traité sous 24h (`dueBy`) |
| `/api/payouts/history` | GET | oui | Historique des reversements |
| `/api/public/purchase` | GET | non | Détails d'une commande (page de remerciement) |
| `/api/sequences` | GET | oui | Liste les 2 tunnels de l'auteur (créés automatiquement) |
| `/api/sequences/[id]` | PATCH | oui | Active/désactive un tunnel |
| `/api/sequences/steps/[stepId]` | PATCH | oui | Édite le sujet/texte/délai d'une étape |
| `/api/broadcasts` | GET/POST | oui | Historique + envoi immédiat ou programmé à une liste |
| `/api/cron/process-emails` | GET/POST | non (protégée par `CRON_SECRET`) | Fait avancer les tunnels + envoie les broadcasts dus |

## 7. Tunnels de vente automatiques (autorépondeur)

Chaque auteur dispose de 2 tunnels préremplis dès son premier appel à
`GET /api/sequences` — un pour la liste "Extrait" (7 emails sur 15 jours,
pensés pour convertir un lecteur en acheteur : relance, mise en appétit,
histoire personnelle, objection, preuve sociale, urgence douce, dernier
mot), un pour la liste "Acheteurs" (7 emails sur 30 jours, pensés pour
fidéliser : accompagnement, valeur ajoutée, demande d'avis, FAQ,
communauté, bouche-à-oreille, découverte des autres livres). Le contenu par
défaut est dans `lib/sequences.js` ; l'auteur peut éditer le sujet/texte/
délai de chaque étape, mais n'a jamais à partir d'une page blanche.

**Le déclenchement est entièrement automatique, par contact, sans aucune
action de l'auteur** : dès qu'un lead entre dans une liste (capture
d'extrait, ou achat confirmé), son `createdAt` sert de point de départ.
`pages/api/cron/process-emails.js` tourne chaque jour (voir `vercel.json`),
calcule pour CHAQUE contact individuellement si sa prochaine étape est due
(`createdAt + delayDays`), et l'envoie — sans jamais renvoyer deux fois la
même (table `EmailSend`). L'auteur n'a jamais besoin de revenir envoyer un
message à la main pour un nouveau contact ; c'est précisément ce que ce
système est conçu pour éviter.

En plus des tunnels automatiques, `/api/broadcasts` reste disponible pour
un envoi ponctuel ("envoyer maintenant" ou programmé) à toute une liste —
utile pour une annonce ponctuelle, en complément des tunnels.

**Inclus dans l'abonnement, pas à part** : comme la génération de contenu
réseaux, les tunnels de vente et les broadcasts ne fonctionnent que pour un
auteur avec un abonnement actif ou en essai — voir `lib/subscription.js`
(`isSubscriptionActive`), utilisé de façon identique par
`content/generate.js`, `broadcasts/index.js` (à la création) et
`cron/process-emails.js` (à l'envoi réel, y compris pour un broadcast
programmé dont l'abonnement aurait expiré entre-temps). L'auteur peut
toujours consulter et modifier le contenu de ses tunnels sans abonnement
actif — seul l'envoi effectif est réservé aux comptes payants.

**Configuration requise** : génère `CRON_SECRET` (chaîne aléatoire d'au
moins 16 caractères) et renseigne-la à la fois dans `.env` et dans Vercel —
Vercel Cron l'envoie automatiquement en en-tête `Authorization` à chaque
appel, ce qui protège la route de tout déclenchement extérieur.

**Limite du plan Vercel Hobby** : 2 cron jobs max, fréquence minimale d'un
appel par jour — le `vercel.json` fourni (une exécution/jour) reste dans
cette limite.

## Sécurité — état réel après audit

Ce qui suit reflète un audit fait ligne par ligne du code, pas une liste
générique. ✅ = en place et vérifié dans ce code. ⚠️ = à faire avant
d'encaisser du vrai argent en production.

**En place :**
- ✅ Mots de passe hachés avec bcrypt (coût 12), jamais stockés en clair
- ✅ Auth par JWT en header `Authorization`, jamais par cookie — réduit
  nativement le risque CSRF (un site tiers ne peut pas lire ce header)
- ✅ Prisma (requêtes paramétrées) élimine l'injection SQL classique
- ✅ Webhook Stripe vérifié par signature officielle (`stripe.webhooks.constructEvent`)
- ✅ Webhook Chariow protégé par secret partagé dans l'URL (`CHARIOW_WEBHOOK_SECRET`)
- ✅ Ventes Chariow re-vérifiées auprès de leur API avant d'être créditées
  (jamais de confiance aveugle dans le contenu d'un webhook)
- ✅ Aucune clé secrète (Stripe, Chariow, Anthropic, JWT...) n'est jamais
  exposée côté frontend — uniquement utilisées dans du code serveur
- ✅ En-têtes de sécurité HTTP (`next.config.js`) : anti-clickjacking,
  anti-sniffing MIME, HSTS (force HTTPS)
- ✅ Validation de format email + troncature des champs texte libres sur
  les routes publiques (signup, checkout, capture de leads)
- ✅ Upload de livre limité aux PDF/EPUB, 50 Mo max, nom de fichier assaini
- ✅ Cron protégé par `CRON_SECRET` (vérifié par Vercel lui-même)
- ✅ **Rate limiting** (Upstash Redis) sur `auth/login` (10/5min), `auth/signup`
  (5/10min), `leads/capture` (20/10min), `checkout/create` (15/10min),
  `resend-verification` (3/10min) — toutes par IP. Voir `lib/rateLimit.js`.
- ✅ **Vérification d'email** à l'inscription (`emailVerified`) — email envoyé
  via Resend au signup, lien valable 24h (`/api/auth/verify-email`), renvoi
  possible (`/api/auth/resend-verification`). Les demandes de reversement
  (`/api/payouts/request`) sont bloquées tant que l'email n'est pas confirmé
  — c'est le geste à plus fort enjeu (argent réel), donc le seul strictement gated.
- ✅ **Anti-bot à deux couches** (`lib/antibot.js`) sur `signup`, `leads/capture`,
  `checkout/create` : honeypot (actif immédiatement, sans configuration) +
  Cloudflare Turnstile (dès que configuré).

**⚠️ Ces trois protections ont un mode "fail-open" tant qu'elles ne sont
pas configurées** (rate limiting, Turnstile) — l'app continue de fonctionner
sans elles plutôt que de planter, mais elles ne protègent réellement qu'une
fois les clés renseignées :

1. **Upstash** (rate limiting) : crée une base sur [upstash.com](https://upstash.com)
   (gratuit), copie `UPSTASH_REDIS_REST_URL` et `UPSTASH_REDIS_REST_TOKEN`
   depuis l'onglet "REST API" dans `.env` puis Vercel.
2. **Cloudflare Turnstile** (anti-bot) : crée un site sur
   [dash.cloudflare.com](https://dash.cloudflare.com) (section Turnstile,
   gratuit), copie `TURNSTILE_SITE_KEY` (publique, pour le widget frontend)
   et `TURNSTILE_SECRET_KEY` (secrète, serveur uniquement) dans `.env` puis
   Vercel. Le widget lui-même doit être ajouté dans le futur frontend réel
   (voir le prototype pour l'emplacement prévu) — le backend est prêt à le
   vérifier dès qu'un `turnstileToken` est envoyé.
3. **Resend** (déjà configuré si tu as suivi §5) : nécessaire pour que
   l'email de vérification parte réellement.

**Ce qui reste, par ordre de priorité :**

1. Vérifier et sécuriser le schéma de création de produit Chariow (voir
   avertissement plus haut) et les noms exacts des événements Pulses.
2. Scan antivirus/malware sur les fichiers uploadés (`books/upload.js`) —
   on valide le type et la taille, pas le contenu réel du fichier.
3. File d'attente asynchrone pour l'analyse de livres volumineux (les
   fonctions serverless Vercel ont un timeout).
4. `npm audit` régulier sur les dépendances (non fait dans ce projet généré).

**Choix qui restent des décisions produit, pas des failles :**
- Reversement vers l'auteur (zone Afrique) : **manuel**, pas automatisé —
  Chariow ne verse que vers TON propre Mobile Money, jamais vers un tiers.
- Commission Chariow ~15 % (10 % à volume), prélevée automatiquement — à
  intégrer dans ton calcul de marge (voir §0ter Pricing du cahier des charges).

## Ce qui manque encore, hors sécurité

- Tests automatisés
- File d'attente asynchrone pour l'analyse de livres volumineux
PLUMEFILE_EOF

echo "-> lib/ai.js"
cat > 'lib/ai.js' << 'PLUMEFILE_EOF'
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Modèles Claude actuels utilisés ici (à revérifier sur docs.claude.com si
// tu lis ce code plus tard — les identifiants de modèles évoluent) :
//  - claude-sonnet-5 pour la page de vente (tâche qui demande plus de finesse)
//  - claude-haiku-4-5-20251001 pour le contenu réseaux sociaux (volume élevé
//    — jusqu'à 20 posts/mois/auteur —, on privilégie le coût)
const MODEL_SALES_PAGE = "claude-sonnet-5";
const MODEL_SOCIAL_CONTENT = "claude-haiku-4-5-20251001";

// Récupère et extrait le texte du fichier du livre (stocké sur Vercel Blob).
// Gère le PDF ; à compléter avec un parseur dédié pour l'EPUB si besoin.
async function extractBookText(fileUrl) {
  const res = await fetch(fileUrl);
  const buf = Buffer.from(await res.arrayBuffer());

  if (fileUrl.toLowerCase().includes(".pdf")) {
    const pdfParse = (await import("pdf-parse")).default;
    const parsed = await pdfParse(buf);
    // Borne raisonnable pour tenir dans le prompt sans complexifier avec du chunking.
    return parsed.text.slice(0, 60000);
  }

  return buf.toString("utf-8").slice(0, 60000);
}

function parseJsonResponse(message, fallback) {
  const raw = message.content.find((b) => b.type === "text")?.text || "";
  try {
    const cleaned = raw.replace(/```json|```/g, "").trim();
    return JSON.parse(cleaned);
  } catch {
    return fallback;
  }
}

export async function generateSalesPageCopy(book) {
  const text = await extractBookText(book.fileUrl);

  const message = await anthropic.messages.create({
    model: MODEL_SALES_PAGE,
    max_tokens: 1000,
    system:
      "Tu es un copywriter expert en pages de vente pour livres. Tu réponds " +
      "UNIQUEMENT en JSON valide, sans texte autour, avec exactement les clés " +
      "problem, why, solution. Chaque valeur fait 2 à 4 phrases, en français, " +
      "ton direct et concret, sans emphase excessive ni superlatifs vides.",
    messages: [
      {
        role: "user",
        content:
          `Voici le texte (ou un extrait) du livre "${book.title}" :\n\n${text}\n\n` +
          "Génère l'argumentaire de vente en 3 parties : " +
          "1) problem : le ou les problèmes douloureux que vit le lecteur cible ; " +
          "2) why : pourquoi le lecteur cible vit ce problème ; " +
          "3) solution : comment ce livre précis y répond. " +
          'Réponds strictement au format JSON : {"problem": "...", "why": "...", "solution": "..."}',
      },
    ],
  });

  const parsed = parseJsonResponse(message, null);
  if (!parsed) {
    // Si le modèle ne renvoie pas un JSON strictement valide, on ne fait pas
    // échouer la génération : on renvoie le texte brut dans "solution" pour
    // que l'auteur puisse au moins l'éditer manuellement.
    const raw = message.content.find((b) => b.type === "text")?.text || "";
    return { problem: "", why: "", solution: raw };
  }
  return {
    problem: parsed.problem || "",
    why: parsed.why || "",
    solution: parsed.solution || "",
  };
}

export async function generateSocialPosts(book, count = 20) {
  const text = await extractBookText(book.fileUrl);

  const message = await anthropic.messages.create({
    model: MODEL_SOCIAL_CONTENT,
    max_tokens: 2500,
    system:
      "Tu es community manager spécialisé dans la promotion de livres. Tu " +
      'réponds UNIQUEMENT en JSON valide : un tableau d\'objets ' +
      '{"platform": "instagram"|"facebook"|"linkedin", "text": "..."}.',
    messages: [
      {
        role: "user",
        content:
          `Voici le texte (ou un extrait) du livre "${book.title}" :\n\n${text}\n\n` +
          `Génère ${count} publications courtes et variées pour les réseaux sociaux, ` +
          "en français, qui donnent envie de lire ou d'acheter ce livre, sans être répétitives entre elles.",
      },
    ],
  });

  return parseJsonResponse(message, []);
}
PLUMEFILE_EOF

echo "-> lib/antibot.js"
cat > 'lib/antibot.js' << 'PLUMEFILE_EOF'
// Deux couches d'anti-bot, cumulables :
//
// 1. Honeypot — un champ caché nommé "website" dans le formulaire (via CSS
//    display:none, jamais visible pour un humain), que les bots remplissent
//    souvent automatiquement. Aucune dépendance externe, actif immédiatement,
//    sans configuration.
//
// 2. Cloudflare Turnstile — un vrai captcha invisible. Nécessite un compte
//    gratuit sur dash.cloudflare.com/?to=/:account/turnstile (voir README §8).
//    Tant que TURNSTILE_SECRET_KEY n'est pas configuré, cette couche est
//    ignorée (fail-open, comme le rate limiting) — le honeypot reste actif.

export function isHoneypotTriggered(body) {
  return Boolean(body?.website);
}

export async function verifyTurnstile(token, ip) {
  if (!process.env.TURNSTILE_SECRET_KEY) {
    console.warn("TURNSTILE_SECRET_KEY non configuré — vérification Turnstile ignorée (honeypot seul actif).");
    return true;
  }
  if (!token) return false;

  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ secret: process.env.TURNSTILE_SECRET_KEY, response: token, remoteip: ip }),
  });
  const data = await res.json();
  return Boolean(data.success);
}
PLUMEFILE_EOF

echo "-> lib/auth.js"
cat > 'lib/auth.js' << 'PLUMEFILE_EOF'
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

export async function hashPassword(password) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export function signToken(payload, expiresIn = "7d") {
  return jwt.sign(payload, JWT_SECRET, { expiresIn });
}

export function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch {
    return null;
  }
}

// Wrapper pour protéger une route API : req.authorId est injecté si le
// token est valide, sinon la requête est rejetée avec 401.
export function requireAuth(handler) {
  return async (req, res) => {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Non authentifié" });

    const payload = verifyToken(token);
    if (!payload) return res.status(401).json({ error: "Token invalide ou expiré" });

    req.authorId = payload.authorId;
    return handler(req, res);
  };
}
PLUMEFILE_EOF

echo "-> lib/chariow-earnings.js"
cat > 'lib/chariow-earnings.js' << 'PLUMEFILE_EOF'
import { prisma } from "./db";

// Paramètres business — ajustables sans toucher au code.
// CHARIOW_COMMISSION_RATE : commission Chariow par vente (~15%, réductible
// à 10% à volume selon leur grille — mets à jour ici si ton palier change).
// CHARIOW_PAYOUT_MATURITY_DAYS : nombre de jours avant qu'une vente soit
// considérée "disponible". Chariow regroupe les ventes le lendemain puis
// les transfère vers le wallet Axa Zara sous 72h max ; on ajoute une marge
// de sécurité pour ne JAMAIS promettre sous 24h un montant qu'on n'a pas
// encore réellement en main.
const COMMISSION_RATE = Number(process.env.CHARIOW_COMMISSION_RATE || 0.15);
const MATURITY_DAYS = Number(process.env.CHARIOW_PAYOUT_MATURITY_DAYS || 5);

// Calcule le solde d'un auteur zone Afrique : ventes matures (déjà
// réellement disponibles côté plateforme) moins les reversements déjà
// demandés/effectués. Utilisé à la fois par /api/payouts/balance (lecture)
// et /api/payouts/request (validation) pour ne jamais désynchroniser les deux.
export async function computeAfriqueBalance(authorId) {
  const maturityCutoff = new Date(Date.now() - MATURITY_DAYS * 24 * 60 * 60 * 1000);

  const [maturePaidAgg, pendingMaturityAgg, payouts] = await Promise.all([
    prisma.purchase.aggregate({
      where: { authorId, status: "paid", createdAt: { lte: maturityCutoff } },
      _sum: { amountCents: true },
    }),
    prisma.purchase.aggregate({
      where: { authorId, status: "paid", createdAt: { gt: maturityCutoff } },
      _sum: { amountCents: true },
    }),
    prisma.payout.findMany({ where: { authorId, status: { in: ["PENDING", "PAID"] } } }),
  ]);

  const matureGrossCents = maturePaidAgg._sum.amountCents || 0;
  const pendingMaturityGrossCents = pendingMaturityAgg._sum.amountCents || 0;
  const totalGrossCents = matureGrossCents + pendingMaturityGrossCents;

  const net = (grossCents) => Math.round(grossCents * (1 - COMMISSION_RATE));

  const matureNetCents = net(matureGrossCents);
  const pendingMaturityNetCents = net(pendingMaturityGrossCents);
  const totalNetCents = net(totalGrossCents);

  const totalPayoutCents = payouts.reduce((sum, p) => sum + p.amountCents, 0);
  const pendingPayoutCents = payouts.filter((p) => p.status === "PENDING").reduce((sum, p) => sum + p.amountCents, 0);

  return {
    commissionRate: COMMISSION_RATE,
    maturityDays: MATURITY_DAYS,
    totalGrossCents,
    totalNetCents,
    matureNetCents,
    pendingMaturityNetCents,
    totalPayoutCents,
    pendingPayoutCents,
    // Ce qui est réellement demandable maintenant : net des ventes matures,
    // moins ce qui a déjà été reversé ou est en cours de reversement.
    availableCents: Math.max(0, matureNetCents - totalPayoutCents),
    currency: "XOF",
    method: "momo",
  };
}
PLUMEFILE_EOF

echo "-> lib/chariow.js"
cat > 'lib/chariow.js' << 'PLUMEFILE_EOF'
// Intégration Chariow — https://chariow.dev
//
// Confirmé par la documentation publique de Chariow :
//   - Base URL : https://api.chariow.com/v1
//   - Auth : header Authorization: Bearer <clé secrète sk_live_/sk_test_>
//   - POST /v1/checkout  : crée une session d'achat pour un product_id existant
//   - GET  /v1/sales?product_slug=...&customer_email=... : vérifie une vente
//   - Pulses (webhooks) : POST { event, data } vers ton URL. L'événement
//     "sale.completed" est confirmé par la doc. Les noms exacts des
//     événements liés à l'abonnement (renouvellement, échec, annulation)
//     ne sont PAS confirmés — vérifie-les dans Réglages > Pulses de ton
//     dashboard Chariow et ajuste lib/chariow.js + pages/api/webhooks/chariow.js
//     en conséquence.
//
// NON confirmé par la documentation publique consultée : le schéma exact de
// création de produit par API (createChariowProduct ci-dessous). C'est une
// implémentation best-effort à vérifier sur chariow.dev/api-reference avant
// mise en production. Si elle échoue, crée le produit manuellement dans le
// dashboard Chariow et colle son product_id dans SalesPage.chariowProductId.

const BASE_URL = "https://api.chariow.com/v1";
const API_KEY = process.env.CHARIOW_API_KEY;

function headers() {
  return {
    Authorization: `Bearer ${API_KEY}`,
    "Content-Type": "application/json",
  };
}

// Crée une session d'achat et retourne l'URL de paiement Chariow vers
// laquelle rediriger l'acheteur.
export async function initChariowCheckout({
  productId,
  email,
  firstName,
  lastName,
  phoneNumber,
  phoneCountryCode,
  redirectUrl,
  paymentCurrency,
  metadata,
}) {
  const res = await fetch(`${BASE_URL}/checkout`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      product_id: productId,
      email,
      first_name: firstName,
      last_name: lastName,
      ...(phoneNumber && { phone: { number: phoneNumber, country_code: phoneCountryCode || "CI" } }),
      redirect_url: redirectUrl,
      ...(paymentCurrency && { payment_currency: paymentCurrency }),
      ...(metadata && { metadata }),
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Chariow — échec du checkout : ${data.message || res.status}`);
  }
  return data.data; // { step: 'payment'|'completed'|'already_purchased', payment: { checkout_url }, purchase, message }
}

// Reconfirme une vente directement auprès de Chariow plutôt que de faire
// confiance au seul contenu du Pulse — même principe de sécurité que pour
// la vérification CinetPay.
export async function verifyChariowSale({ productSlug, customerEmail }) {
  const params = new URLSearchParams({ product_slug: productSlug, customer_email: customerEmail });
  const res = await fetch(`${BASE_URL}/sales?${params.toString()}`, { headers: headers() });
  const data = await res.json();
  const sales = data?.data || [];
  return sales.find((s) => s.status === "completed") || null;
}

// BEST-EFFORT — schéma non confirmé par la documentation publique. À vérifier
// sur chariow.dev avant utilisation en production.
export async function createChariowProduct({ name, description, priceValue, currency }) {
  const res = await fetch(`${BASE_URL}/products`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      name,
      description,
      price: { value: priceValue, currency },
      type: "digital",
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Chariow — échec de création du produit (schéma à vérifier) : ${data.message || res.status}`);
  }
  return data.data; // { id, name, price: {...}, ... }
}
PLUMEFILE_EOF

echo "-> lib/db.js"
cat > 'lib/db.js' << 'PLUMEFILE_EOF'
import { PrismaClient } from "@prisma/client";

// Évite de recréer une connexion Prisma à chaque hot-reload / invocation
// serverless en dev. En production sur Vercel, chaque fonction reste légère.
const globalForPrisma = globalThis;

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
PLUMEFILE_EOF

echo "-> lib/email.js"
cat > 'lib/email.js' << 'PLUMEFILE_EOF'
// Envoi d'email transactionnel via Resend — https://resend.com
// Nécessite RESEND_API_KEY et RESEND_FROM_EMAIL (adresse expéditrice
// vérifiée dans ton compte Resend, ex. "Plume <contact@ton-domaine.com>").
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const RESEND_FROM_EMAIL = process.env.RESEND_FROM_EMAIL;

export async function sendExtractEmail({ to, bookTitle, pdfUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Votre extrait de "${bookTitle}"`,
      html: `
        <p>Merci pour votre intérêt !</p>
        <p>Voici votre extrait de <strong>${bookTitle}</strong> :</p>
        <p><a href="${pdfUrl}">Télécharger le PDF</a></p>
      `,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("Échec d'envoi Resend :", err);
    return { sent: false };
  }
  return { sent: true };
}

export async function sendPurchaseConfirmationEmail({ to, bookTitle, amountFormatted, buyerName }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Confirmation de votre commande — ${bookTitle}`,
      html: `
        <p>Bonjour ${buyerName || ""},</p>
        <p>Votre commande de <strong>${bookTitle}</strong> (${amountFormatted}) est confirmée.</p>
        <p>L'auteur vous contactera pour organiser la remise ou l'expédition de votre exemplaire.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

// Utilisée par les tunnels de vente automatiques et les envois ponctuels
// (broadcasts). Le corps texte est fourni par l'auteur (ou pré-rempli par
// défaut, voir lib/sequences.js) — on le transforme simplement en
// paragraphes HTML, sans template marketing imposé.
export async function sendMarketingEmail({ to, subject, textBody, replyTo }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const html = textBody
    .split("\n\n")
    .map((p) => `<p>${p.replace(/\n/g, "<br/>")}</p>`)
    .join("\n");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject,
      html,
      ...(replyTo && { reply_to: replyTo }),
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (marketing) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

export async function sendVerificationEmail({ to, verifyUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: "Confirmez votre adresse email — Plume",
      html: `
        <p>Bienvenue sur Plume !</p>
        <p>Confirmez votre adresse email pour activer toutes les fonctionnalités de votre compte (notamment les demandes de reversement) :</p>
        <p><a href="${verifyUrl}">Confirmer mon email</a></p>
        <p>Ce lien expire dans 24h.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (vérification email) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}
PLUMEFILE_EOF

echo "-> lib/rateLimit.js"
cat > 'lib/rateLimit.js' << 'PLUMEFILE_EOF'
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

// Rate limiting basé sur Upstash Redis (compte gratuit sur upstash.com) —
// un compteur en mémoire ne fonctionnerait pas ici : chaque invocation
// serverless Vercel peut démarrer sans mémoire partagée avec la précédente.
//
// Si UPSTASH_REDIS_REST_URL/TOKEN ne sont pas configurés, on n'échoue
// jamais la requête (fail-open) mais on log un avertissement clair — une
// app sans rate limiting reste utilisable ; une app qui plante au démarrage
// sans Upstash ne l'est pas. Configure-les dès que possible (voir README §8).
let redis = null;
if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
  redis = new Redis({
    url: process.env.UPSTASH_REDIS_REST_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN,
  });
}

const limiters = {};

function getLimiter(name, requests, windowSeconds) {
  if (!redis) return null;
  if (!limiters[name]) {
    limiters[name] = new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(requests, `${windowSeconds} s`),
      prefix: `plume:ratelimit:${name}`,
    });
  }
  return limiters[name];
}

export function getClientIp(req) {
  const fwd = req.headers["x-forwarded-for"];
  if (fwd) return fwd.split(",")[0].trim();
  return req.socket?.remoteAddress || "unknown";
}

// À appeler en tout début de handler :
//   const rl = await checkRateLimit(req, res, "login", 10, 300);
//   if (!rl.allowed) return; // la réponse 429 est déjà envoyée par la fonction
export async function checkRateLimit(req, res, name, requests, windowSeconds) {
  const limiter = getLimiter(name, requests, windowSeconds);
  if (!limiter) {
    console.warn(`Rate limiting désactivé (${name}) — configure UPSTASH_REDIS_REST_URL/TOKEN.`);
    return { allowed: true };
  }

  const ip = getClientIp(req);
  const { success, remaining } = await limiter.limit(`${name}:${ip}`);
  if (!success) {
    res.status(429).json({ error: "Trop de requêtes — réessayez dans quelques minutes." });
    return { allowed: false };
  }
  return { allowed: true, remaining };
}
PLUMEFILE_EOF

echo "-> lib/sequences.js"
cat > 'lib/sequences.js' << 'PLUMEFILE_EOF'
// Tunnels de vente par défaut — pré-rédigés pour des auteurs qui ne
// connaissent pas le marketing. Chaque auteur reçoit ces deux séquences
// automatiquement ; il peut ensuite modifier le sujet/texte de chaque étape
// depuis son dashboard (PATCH /api/sequences/steps/[id]), sans jamais avoir
// à partir d'une page blanche.
//
// Structure pensée en 7 étapes pour chaque tunnel (voir la logique en
// commentaire au-dessus de chaque séquence) — quelques étapes contiennent
// un texte entre crochets [...] que l'auteur doit personnaliser (son
// histoire, un vrai témoignage...) car c'est ce qui convertit le mieux ;
// tout le reste est prêt à l'emploi.
//
// Variables disponibles dans subject/body, remplacées à l'envoi (voir
// renderTemplate) : {{prenom}}, {{titre}}, {{auteur}}, {{lien_achat}}, {{lien_boutique}}

export const DEFAULT_SEQUENCES = {
  // Tunnel de CONVERSION — fait passer un lecteur de l'extrait à l'achat.
  // Structure éprouvée en marketing par email : relance → mise en appétit →
  // histoire/connexion → objection → preuve sociale → urgence douce → dernier mot.
  extrait: {
    name: "Tunnel — Lecteurs de l’extrait",
    steps: [
      {
        order: 1,
        delayDays: 1,
        subject: "Avez-vous eu le temps de lire l’extrait ?",
        body: "Bonjour {{prenom}},\n\nJ’espère que l’extrait de « {{titre}} » vous a plu !\n\nSi les premières pages vous ont donné envie d’aller plus loin, le livre complet est disponible ici :\n{{lien_achat}}\n\nÀ bientôt,\n{{auteur}}",
      },
      {
        order: 2,
        delayDays: 3,
        subject: "Ce que vous allez découvrir dans la suite",
        body: "Bonjour {{prenom}},\n\nSans trop en dévoiler, la suite de « {{titre}} » approfondit exactement ce que vous avez commencé à lire dans l’extrait.\n\nDe nombreux lecteurs me disent que c’est là que tout prend son sens.\n\nVous pouvez vous procurer votre exemplaire ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 3,
        delayDays: 5,
        subject: "Pourquoi j’ai écrit « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nJe voulais vous partager quelque chose de plus personnel : pourquoi j’ai décidé d’écrire « {{titre}} ».\n\n[Racontez ici votre histoire, ce qui vous a poussé(e) à écrire ce livre — c’est souvent ce qui donne le plus envie d’acheter.]\n\nSi cette histoire vous parle, le livre est disponible ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 4,
        delayDays: 7,
        subject: "Si vous hésitez encore…",
        body: "Bonjour {{prenom}},\n\nSi vous n’avez pas encore pris « {{titre}} », c’est peut-être parce que vous vous demandez si c’est vraiment pour vous, ou si vous aurez le temps de le lire.\n\nRassurez-vous : [ajoutez ici une réponse courte à l’objection la plus fréquente que vous entendez — ex. « le livre se lit en un week-end » ou « chaque chapitre se lit indépendamment »].\n\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 5,
        delayDays: 9,
        subject: "Ce que d’autres lecteurs en disent",
        body: "Bonjour {{prenom}},\n\n[Ajoutez ici un retour ou un témoignage court d’un lecteur — même une seule phrase marquante suffit.]\n\nSi vous voulez vivre la même expérience, « {{titre}} » est disponible ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 6,
        delayDays: 12,
        subject: "Pourquoi ne pas attendre pour lire « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nOn remet souvent la lecture à plus tard — et « plus tard » n’arrive jamais vraiment.\n\nSi « {{titre}} » vous a intéressé(e), le meilleur moment pour commencer, c’est maintenant :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 7,
        delayDays: 15,
        subject: "Dernier mot avant de vous laisser tranquille",
        body: "Bonjour {{prenom}},\n\nJe ne vous enverrai plus beaucoup de messages à ce sujet — juste un dernier mot.\n\nSi « {{titre}} » vous a intéressé(e), le livre est toujours disponible ici :\n{{lien_achat}}\n\nMerci de m’avoir lu(e) jusqu’ici, quoi qu’il arrive.\n\n{{auteur}}",
      },
    ],
  },

  // Tunnel de FIDÉLISATION — construit la relation sur la durée (30 jours)
  // avec un lecteur qui a déjà acheté : accompagnement → valeur ajoutée →
  // avis → FAQ → communauté → bouche-à-oreille → découverte des autres livres.
  acheteur: {
    name: "Tunnel — Lecteurs qui ont acheté",
    steps: [
      {
        order: 1,
        delayDays: 2,
        subject: "Comment se passe votre lecture ?",
        body: "Bonjour {{prenom}},\n\nMerci encore pour votre achat de « {{titre}} » ! J’espère que la lecture avance bien.\n\nSi vous avez une question, répondez simplement à cet email.\n\n{{auteur}}",
      },
      {
        order: 2,
        delayDays: 5,
        subject: "Un complément à votre lecture",
        body: "Bonjour {{prenom}},\n\nMaintenant que vous avancez dans « {{titre}} », je voulais partager avec vous [une réflexion, une ressource ou un petit bonus lié au livre].\n\nJ’espère que ça enrichira votre lecture.\n\n{{auteur}}",
      },
      {
        order: 3,
        delayDays: 7,
        subject: "Un petit service, si vous avez 2 minutes",
        body: "Bonjour {{prenom}},\n\nSi « {{titre}} » vous plaît, un avis de votre part m’aiderait énormément à toucher d’autres lecteurs.\n\nMerci d’avance,\n{{auteur}}",
      },
      {
        order: 4,
        delayDays: 10,
        subject: "La question qu’on me pose le plus sur « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nBeaucoup de lecteurs me posent la même question sur « {{titre}} » : [ajoutez ici la question et votre réponse].\n\nJ’espère que ça éclaire votre lecture.\n\n{{auteur}}",
      },
      {
        order: 5,
        delayDays: 14,
        subject: "Restons en contact",
        body: "Bonjour {{prenom}},\n\nSi vous voulez suivre mes prochains projets ou échanger avec d’autres lecteurs, [ajoutez ici votre lien réseaux sociaux ou communauté].\n\nÀ bientôt,\n{{auteur}}",
      },
      {
        order: 6,
        delayDays: 21,
        subject: "Connaissez-vous quelqu’un à qui « {{titre}} » pourrait plaire ?",
        body: "Bonjour {{prenom}},\n\nSi « {{titre}} » vous a marqué(e), le plus beau cadeau que vous puissiez me faire, c’est d’en parler autour de vous.\n\nMerci du fond du cœur si vous le faites.\n\n{{auteur}}",
      },
      {
        order: 7,
        delayDays: 30,
        subject: "Pour aller plus loin",
        body: "Bonjour {{prenom}},\n\nJ’espère que « {{titre}} » vous a plu du début à la fin.\n\nSi vous voulez continuer à me lire, retrouvez tous mes livres ici :\n{{lien_boutique}}\n\nMerci de votre confiance,\n{{auteur}}",
      },
    ],
  },
};

export function renderTemplate(template, vars) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] ?? "");
}
PLUMEFILE_EOF

echo "-> lib/stripe.js"
cat > 'lib/stripe.js' << 'PLUMEFILE_EOF'
import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});
PLUMEFILE_EOF

echo "-> lib/subscription.js"
cat > 'lib/subscription.js' << 'PLUMEFILE_EOF'
// Statut d'abonnement partagé — utilisé partout où une fonctionnalité doit
// être réservée aux comptes payants ou en essai actif (génération de
// contenu réseaux, tunnels de vente, broadcasts). Centralisé ici pour que
// la définition d'"abonnement actif" ne diverge jamais d'un endroit à l'autre.
export function isSubscriptionActive(author) {
  const trialActive = author.subscriptionStatus === "TRIALING" && author.trialEndsAt && author.trialEndsAt > new Date();
  return author.subscriptionStatus === "ACTIVE" || trialActive;
}
PLUMEFILE_EOF

echo "-> lib/validate.js"
cat > 'lib/validate.js' << 'PLUMEFILE_EOF'
// Validations partagées — avant cet audit, aucune route ne vérifiait le
// format des emails ni ne bornait la taille des champs texte libres.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(email) {
  return typeof email === "string" && email.length <= 254 && EMAIL_RE.test(email);
}

// Coupe les champs texte libres à une longueur raisonnable avant stockage —
// évite qu'un formulaire public serve à empiler des Mo de texte en base.
export function clampText(value, maxLength = 2000) {
  if (typeof value !== "string") return "";
  return value.slice(0, maxLength);
}
PLUMEFILE_EOF

echo "-> next.config.js"
cat > 'next.config.js' << 'PLUMEFILE_EOF'
// En-têtes de sécurité HTTP appliqués à toutes les routes. Aucun de ces
// réglages n'existait avant cet audit — Next.js ne les ajoute pas par défaut.
const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" }, // empêche le navigateur de deviner un type MIME dangereux
  { key: "X-Frame-Options", value: "DENY" }, // empêche d'intégrer le site dans une <iframe> (clickjacking)
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" }, // force HTTPS
  { key: "X-DNS-Prefetch-Control", value: "off" },
];

module.exports = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
};
PLUMEFILE_EOF

echo "-> package.json"
cat > 'package.json' << 'PLUMEFILE_EOF'
{
  "name": "plume-backend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "prisma generate && next build",
    "start": "next start",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "postinstall": "prisma generate"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "@prisma/client": "5.17.0",
    "prisma": "5.17.0",
    "bcryptjs": "2.4.3",
    "jsonwebtoken": "9.0.2",
    "stripe": "16.2.0",
    "nanoid": "5.0.7",
    "micro": "10.0.1",
    "@vercel/blob": "0.23.4",
    "@anthropic-ai/sdk": "0.27.3",
    "pdf-parse": "1.1.1",
    "@upstash/ratelimit": "2.0.5",
    "@upstash/redis": "1.34.3"
  },
  "engines": {
    "node": "18.x"
  }
}
PLUMEFILE_EOF

echo "-> pages/api/auth/login.js"
cat > 'pages/api/auth/login.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";
import { verifyPassword, signToken } from "../../../lib/auth";
import { checkRateLimit } from "../../../lib/rateLimit";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "login", 10, 300); // 10 tentatives / 5 min / IP
  if (!rl.allowed) return;

  const { email, password } = req.body;
  const author = await prisma.author.findUnique({ where: { email } });
  if (!author) return res.status(401).json({ error: "Identifiants invalides" });

  const valid = await verifyPassword(password, author.passwordHash);
  if (!valid) return res.status(401).json({ error: "Identifiants invalides" });

  const token = signToken({ authorId: author.id });
  return res.status(200).json({
    token,
    author: { id: author.id, name: author.name, email: author.email, region: author.region, emailVerified: author.emailVerified },
  });
}
PLUMEFILE_EOF

echo "-> pages/api/auth/resend-verification.js"
cat > 'pages/api/auth/resend-verification.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { signToken } from "../../../lib/auth";
import { sendVerificationEmail } from "../../../lib/email";
import { checkRateLimit } from "../../../lib/rateLimit";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "resend-verification", 3, 600); // 3 / 10 min / IP
  if (!rl.allowed) return;

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (author.emailVerified) return res.status(200).json({ ok: true, alreadyVerified: true });

  const verifyToken = signToken({ authorId: author.id, purpose: "verify_email" }, "1d");
  const verifyUrl = `${process.env.APP_URL}/api/auth/verify-email?token=${verifyToken}`;
  const result = await sendVerificationEmail({ to: author.email, verifyUrl });

  return res.status(200).json({ sent: result.sent });
});
PLUMEFILE_EOF

echo "-> pages/api/auth/signup.js"
cat > 'pages/api/auth/signup.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";
import { hashPassword, signToken } from "../../../lib/auth";
import { isValidEmail, clampText } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";
import { sendVerificationEmail } from "../../../lib/email";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "signup", 5, 600); // 5 inscriptions / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
    // On répond un faux succès pour ne pas indiquer au bot qu'il a été détecté.
    return res.status(201).json({ token: null, author: null });
  }

  const ip = getClientIp(req);
  const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
  if (!turnstileOk) {
    return res.status(400).json({ error: "Vérification anti-bot échouée." });
  }

  const { email, password, name, region } = req.body;
  if (!email || !password || !name) {
    return res.status(400).json({ error: "Email, mot de passe et nom sont requis" });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Adresse email invalide" });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: "Le mot de passe doit contenir au moins 8 caractères" });
  }

  const existing = await prisma.author.findUnique({ where: { email } });
  if (existing) return res.status(409).json({ error: "Cet email est déjà utilisé" });

  const passwordHash = await hashPassword(password);
  const trialEndsAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // essai gratuit 7 jours

  const author = await prisma.author.create({
    data: {
      email,
      passwordHash,
      name: clampText(name, 120),
      region: region === "EUROPE" ? "EUROPE" : "AFRIQUE",
      trialEndsAt,
    },
  });

  // Email de vérification — n'empêche pas la connexion immédiate, mais
  // certaines actions sensibles (reversement) resteront bloquées tant que
  // emailVerified est false (voir pages/api/payouts/request.js).
  const verifyToken = signToken({ authorId: author.id, purpose: "verify_email" }, "1d");
  const verifyUrl = `${process.env.APP_URL}/api/auth/verify-email?token=${verifyToken}`;
  sendVerificationEmail({ to: author.email, verifyUrl }).catch((err) =>
    console.error("Échec envoi email de vérification :", err)
  );

  const token = signToken({ authorId: author.id });
  return res.status(201).json({
    token,
    author: { id: author.id, name: author.name, email: author.email, region: author.region, emailVerified: false },
  });
}
PLUMEFILE_EOF

echo "-> pages/api/auth/verify-email.js"
cat > 'pages/api/auth/verify-email.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";
import { verifyToken } from "../../../lib/auth";

function htmlPage(title, message) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${title}</title></head>
<body style="font-family: -apple-system, sans-serif; text-align:center; padding: 80px 20px; color:#241F17;">
  <h1>${title}</h1><p>${message}</p>
</body></html>`;
}

// Lien cliqué depuis l'email de vérification. Pas de frontend dédié encore
// (voir README) — on renvoie directement une petite page HTML de confirmation.
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const { token } = req.query;
  const payload = token ? verifyToken(token) : null;

  if (!payload || payload.purpose !== "verify_email") {
    res.setHeader("Content-Type", "text/html");
    return res.status(400).send(htmlPage("Lien invalide ou expiré", "Redemandez un email de confirmation depuis votre espace auteur."));
  }

  await prisma.author.update({ where: { id: payload.authorId }, data: { emailVerified: true } });

  res.setHeader("Content-Type", "text/html");
  return res.status(200).send(htmlPage("Email confirmé ✓", "Vous pouvez fermer cette page et retourner sur Plume."));
}
PLUMEFILE_EOF

echo "-> pages/api/authors/me.js"
cat > 'pages/api/authors/me.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const author = await prisma.author.findUnique({
    where: { id: req.authorId },
    select: {
      id: true, name: true, email: true, region: true, emailVerified: true,
      subscriptionStatus: true, trialEndsAt: true, currentPeriodEnd: true,
      stripeAccountId: true, stripeOnboarded: true,
      momoOperator: true, momoNumber: true,
    },
  });
  return res.status(200).json(author);
});
PLUMEFILE_EOF

echo "-> pages/api/authors/payment-config.js"
cat > 'pages/api/authors/payment-config.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// GET  -> retourne l'état de configuration des moyens de paiement de l'auteur
// PUT  -> enregistre le numéro Mobile Money (zone Afrique)
// La connexion Stripe (zone Europe) passe par /api/stripe/connect/onboarding,
// pas par cette route, car elle nécessite une redirection OAuth.
export default requireAuth(async function handler(req, res) {
  if (req.method === "GET") {
    const author = await prisma.author.findUnique({
      where: { id: req.authorId },
      select: { region: true, stripeAccountId: true, stripeOnboarded: true, momoOperator: true, momoNumber: true },
    });
    return res.status(200).json(author);
  }

  if (req.method === "PUT") {
    const { momoOperator, momoNumber } = req.body;
    if (!momoOperator || !momoNumber) {
      return res.status(400).json({ error: "Opérateur et numéro Mobile Money requis" });
    }
    await prisma.author.update({
      where: { id: req.authorId },
      data: { momoOperator, momoNumber },
    });
    return res.status(200).json({ ok: true });
  }

  return res.status(405).end();
});
PLUMEFILE_EOF

echo "-> pages/api/books/upload.js"
cat > 'pages/api/books/upload.js' << 'PLUMEFILE_EOF'
import { put } from "@vercel/blob";
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Les fonctions serverless Vercel n'ont pas de disque persistant : le
// fichier du livre est envoyé directement à Vercel Blob (stockage objet),
// pas sauvegardé sur le système de fichiers local.
export const config = {
  api: { bodyParser: false },
};

const ALLOWED_EXTENSIONS = [".pdf", ".epub"];
const MAX_SIZE_BYTES = 50 * 1024 * 1024; // 50 Mo, cohérent avec le prototype

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rawFilename = String(req.headers["x-filename"] || `livre-${Date.now()}.pdf`);
  // On ne garde que des caractères sûrs — un nom de fichier ne doit jamais
  // être utilisé tel quel (chemins, caractères spéciaux).
  const filename = rawFilename.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 150);

  const ext = filename.slice(filename.lastIndexOf(".")).toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return res.status(400).json({ error: "Format non autorisé — seuls PDF et EPUB sont acceptés." });
  }

  const contentLength = Number(req.headers["content-length"] || 0);
  if (contentLength > MAX_SIZE_BYTES) {
    return res.status(413).json({ error: "Fichier trop volumineux (50 Mo max)." });
  }

  const blob = await put(filename, req, {
    access: "public",
    addRandomSuffix: true,
  });

  const book = await prisma.book.create({
    data: {
      authorId: req.authorId,
      title: filename.replace(/\.[^/.]+$/, ""),
      fileUrl: blob.url,
    },
  });

  return res.status(201).json(book);
});
PLUMEFILE_EOF

echo "-> pages/api/broadcasts/index.js"
cat > 'pages/api/broadcasts/index.js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/api/checkout/create.js"
cat > 'pages/api/checkout/create.js' << 'PLUMEFILE_EOF'
import { nanoid } from "nanoid";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { initChariowCheckout } from "../../../lib/chariow";
import { isValidEmail } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis la page de vente publique quand
// l'acheteur clique "Acheter maintenant". Le livre vendu est un exemplaire
// papier : l'adresse de livraison complète est requise avant paiement.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "checkout-create", 15, 600); // 15 / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
    return res.status(400).json({ error: "Requête invalide." });
  }

  const ip = getClientIp(req);
  const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
  if (!turnstileOk) {
    return res.status(400).json({ error: "Vérification anti-bot échouée." });
  }

  const {
    slug, buyerName, buyerEmail, buyerWhatsapp,
    shippingAddress, shippingCity, shippingPostalCode, shippingCountry,
  } = req.body;

  if (!slug || !buyerName || !buyerEmail) {
    return res.status(400).json({ error: "Champs acheteur requis manquants" });
  }
  if (!isValidEmail(buyerEmail)) {
    return res.status(400).json({ error: "Adresse email invalide" });
  }
  if (!shippingAddress || !shippingCity || !shippingPostalCode || !shippingCountry) {
    return res.status(400).json({ error: "Adresse de livraison complète requise" });
  }

  const salesPage = await prisma.salesPage.findUnique({
    where: { slug },
    include: { book: { include: { author: true } } },
  });
  if (!salesPage || !salesPage.published) {
    return res.status(404).json({ error: "Page de vente introuvable ou non publiée" });
  }

  const author = salesPage.book.author;
  const transactionId = nanoid();

  const purchase = await prisma.purchase.create({
    data: {
      authorId: author.id,
      bookId: salesPage.bookId,
      buyerEmail,
      buyerName,
      buyerWhatsapp,
      shippingAddress,
      shippingCity,
      shippingPostalCode,
      shippingCountry,
      amountCents: salesPage.priceCents,
      currency: salesPage.currency,
      provider: author.region === "EUROPE" ? "stripe" : "chariow",
      providerRef: transactionId,
      status: "pending",
    },
  });

  // --- Zone Europe : Stripe Checkout + Connect ---
  if (author.region === "EUROPE") {
    if (!author.stripeAccountId || !author.stripeOnboarded) {
      return res.status(400).json({ error: "L'auteur n'a pas encore connecté son compte Stripe" });
    }

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      line_items: [
        {
          price_data: {
            currency: salesPage.currency.toLowerCase(),
            product_data: { name: salesPage.book.title },
            unit_amount: salesPage.priceCents,
          },
          quantity: 1,
        },
      ],
      // Stripe peut aussi collecter l'adresse lui-même (shipping_address_collection) ;
      // on la garde ici pour rester cohérent avec la zone Afrique/Chariow et
      // n'avoir qu'une seule source de vérité (Purchase).
      payment_intent_data: {
        transfer_data: { destination: author.stripeAccountId },
        // application_fee_amount: Math.round(salesPage.priceCents * 0.05), // commission plateforme, optionnelle
      },
      customer_email: buyerEmail,
      metadata: { purchaseId: purchase.id },
      success_url: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
      cancel_url: `${process.env.APP_URL}/p/${slug}?paiement=annule`,
    });

    await prisma.purchase.update({ where: { id: purchase.id }, data: { providerRef: session.id } });
    return res.status(200).json({ url: session.url, purchaseId: purchase.id });
  }

  // --- Zone Afrique francophone : Chariow ---
  if (!salesPage.chariowProductId) {
    return res.status(400).json({
      error: "Produit Chariow non configuré pour ce livre. Renseigne-le manuellement dans le dashboard Chariow si le provisioning automatique a échoué.",
    });
  }

  const result = await initChariowCheckout({
    productId: salesPage.chariowProductId,
    email: buyerEmail,
    firstName: buyerName.split(" ")[0] || buyerName,
    lastName: buyerName.split(" ").slice(1).join(" ") || buyerName,
    phoneNumber: buyerWhatsapp,
    redirectUrl: `${process.env.APP_URL}/p/${slug}/merci?purchase=${purchase.id}`,
    metadata: { purchaseId: purchase.id },
  });

  if (result.step === "completed") {
    await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
  }

  return res.status(200).json({ url: result.payment?.checkout_url, step: result.step, purchaseId: purchase.id });
}
PLUMEFILE_EOF

echo "-> pages/api/contacts/index.js"
cat > 'pages/api/contacts/index.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const source = req.query.source === "acheteurs" ? "acheteur" : "extrait";
  const leads = await prisma.lead.findMany({
    where: { authorId: req.authorId, source },
    orderBy: { createdAt: "desc" },
  });
  return res.status(200).json(leads);
});
PLUMEFILE_EOF

echo "-> pages/api/content/generate.js"
cat > 'pages/api/content/generate.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSocialPosts } from "../../../lib/ai";
import { isSubscriptionActive } from "../../../lib/subscription";

// Génération de contenu réseaux sociaux — réservée aux comptes avec un
// abonnement actif ou en période d'essai (voir lib/subscription.js).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, count } = req.body;
  if (!bookId) return res.status(400).json({ error: "bookId requis" });

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (!isSubscriptionActive(author)) {
    return res.status(402).json({ error: "Abonnement inactif — génération de contenu indisponible." });
  }

  const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const posts = await generateSocialPosts(book, count || 20);
  return res.status(200).json({ posts });
});
PLUMEFILE_EOF

echo "-> pages/api/cron/process-emails.js"
cat > 'pages/api/cron/process-emails.js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/api/extract-pages/index.js"
cat > 'pages/api/extract-pages/index.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

function slugify(title) {
  return title
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, videoUrl, pdfUrl } = req.body;
  const book = await prisma.book.findFirst({ where: { id: bookId, authorId: req.authorId } });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const slug = `extrait-${slugify(book.title)}-${book.id.slice(-5)}`;

  const extractPage = await prisma.extractPage.upsert({
    where: { bookId: book.id },
    update: { videoUrl, ...(pdfUrl && { pdfUrl }) },
    create: { bookId: book.id, slug, videoUrl, pdfUrl },
  });

  return res.status(201).json(extractPage);
});
PLUMEFILE_EOF

echo "-> pages/api/leads/capture.js"
cat > 'pages/api/leads/capture.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";
import { sendExtractEmail } from "../../../lib/email";
import { isValidEmail, clampText } from "../../../lib/validate";
import { checkRateLimit, getClientIp } from "../../../lib/rateLimit";
import { isHoneypotTriggered, verifyTurnstile } from "../../../lib/antibot";

// Route PUBLIQUE — appelée depuis le formulaire de la page d'extrait
// publique. Protégée par rate limiting, honeypot et (si configuré) Turnstile.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const rl = await checkRateLimit(req, res, "leads-capture", 20, 600); // 20 / 10 min / IP
  if (!rl.allowed) return;

  if (isHoneypotTriggered(req.body)) {
    return res.status(201).json({ ok: true, pdfUrl: null, emailSent: false });
  }

  const ip = getClientIp(req);
  const turnstileOk = await verifyTurnstile(req.body.turnstileToken, ip);
  if (!turnstileOk) {
    return res.status(400).json({ error: "Vérification anti-bot échouée." });
  }

  const { slug, firstName, lastName, email, whatsapp } = req.body;
  if (!slug || !email || !whatsapp) {
    return res.status(400).json({ error: "Champs requis manquants" });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Adresse email invalide" });
  }

  const extractPage = await prisma.extractPage.findUnique({
    where: { slug },
    include: { book: true },
  });
  if (!extractPage) return res.status(404).json({ error: "Page introuvable" });

  await prisma.lead.create({
    data: {
      authorId: extractPage.book.authorId,
      bookId: extractPage.bookId,
      firstName: clampText(firstName, 100),
      lastName: clampText(lastName, 100),
      email,
      whatsapp: clampText(whatsapp, 30),
      source: "extrait",
    },
  });

  // Double canal : le lead peut télécharger tout de suite (pdfUrl renvoyé
  // ci-dessous, pour une page de téléchargement direct) ET reçoit le PDF
  // par email.
  let emailSent = false;
  if (extractPage.pdfUrl) {
    const result = await sendExtractEmail({ to: email, bookTitle: extractPage.book.title, pdfUrl: extractPage.pdfUrl });
    emailSent = result.sent;
  }

  return res.status(201).json({ ok: true, pdfUrl: extractPage.pdfUrl || null, emailSent });
}
PLUMEFILE_EOF

echo "-> pages/api/payouts/balance.js"
cat > 'pages/api/payouts/balance.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Solde disponible = ce qu'on peut honnêtement promettre de reverser sous
// 24h. Pour la zone Europe, Stripe distingue déjà nativement available vs
// pending (et ses frais sont déjà déduits du montant retourné). Pour la
// zone Afrique, voir lib/chariow-earnings.js : on ne rend "disponible" que
// les ventes déjà matures (au-delà du délai réel de règlement Chariow), nettes
// de leur commission — jamais un montant qu'on n'a pas encore en main.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });

  if (author.region === "EUROPE") {
    if (!author.stripeAccountId || !author.stripeOnboarded) {
      return res.status(200).json({ availableCents: 0, currency: "EUR", pendingCents: 0, method: "stripe", connected: false });
    }
    const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
    const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
    const pending = balance.pending.reduce((sum, b) => sum + b.amount, 0);
    return res.status(200).json({
      availableCents: available,
      pendingCents: pending,
      currency: (balance.available[0]?.currency || "eur").toUpperCase(),
      method: "stripe",
      connected: true,
      note: "Montant déjà net des frais Stripe.",
    });
  }

  const balance = await computeAfriqueBalance(author.id);
  return res.status(200).json({
    ...balance,
    method: "momo",
    connected: Boolean(author.momoNumber),
    note: `Net des frais de transaction (${Math.round(balance.commissionRate * 100)}%). Une vente devient disponible ${balance.maturityDays} jours après l'achat.`,
  });
});
PLUMEFILE_EOF

echo "-> pages/api/payouts/history.js"
cat > 'pages/api/payouts/history.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();
  const payouts = await prisma.payout.findMany({
    where: { authorId: req.authorId },
    orderBy: { createdAt: "desc" },
  });
  return res.status(200).json(payouts);
});
PLUMEFILE_EOF

echo "-> pages/api/payouts/request.js"
cat > 'pages/api/payouts/request.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { computeAfriqueBalance } from "../../../lib/chariow-earnings";

// Engagement produit : toute demande de reversement est traitée en moins de
// 24h. dueBy est enregistré pour piloter ce SLA côté opérations. Cet
// engagement reste tenable car on ne valide jamais une demande au-delà du
// solde "disponible" (voir lib/chariow-earnings.js côté Afrique) — on ne
// promet jamais un montant qu'on n'a pas encore réellement reçu.
const SLA_MS = 24 * 60 * 60 * 1000;

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { amountCents } = req.body;
  if (!amountCents || amountCents <= 0) {
    return res.status(400).json({ error: "Montant invalide" });
  }

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  if (!author.emailVerified) {
    return res.status(403).json({ error: "Confirmez votre adresse email avant de demander un reversement (vérifiez votre boîte mail, ou renvoyez le lien depuis Paramètres)." });
  }
  const dueBy = new Date(Date.now() + SLA_MS);

  // --- Zone Europe : Stripe déclenche un vrai virement vers le compte connecté ---
  if (author.region === "EUROPE") {
    if (!author.stripeAccountId || !author.stripeOnboarded) {
      return res.status(400).json({ error: "Compte Stripe non connecté" });
    }

    const balance = await stripe.balance.retrieve({ stripeAccount: author.stripeAccountId });
    const available = balance.available.reduce((sum, b) => sum + b.amount, 0);
    if (amountCents > available) {
      return res.status(400).json({ error: "Montant supérieur au solde disponible" });
    }

    const currency = (balance.available[0]?.currency || "eur");
    const stripePayout = await stripe.payouts.create(
      { amount: amountCents, currency },
      { stripeAccount: author.stripeAccountId }
    );

    const payout = await prisma.payout.create({
      data: {
        authorId: author.id,
        amountCents,
        currency: currency.toUpperCase(),
        method: "stripe",
        status: stripePayout.status === "paid" ? "PAID" : "PENDING",
        providerRef: stripePayout.id,
        dueBy,
        processedAt: stripePayout.status === "paid" ? new Date() : null,
      },
    });
    return res.status(201).json(payout);
  }

  // --- Zone Afrique : reversement Mobile Money, plafonné au solde réellement mature ---
  if (!author.momoNumber) {
    return res.status(400).json({ error: "Numéro Mobile Money non configuré" });
  }

  const balance = await computeAfriqueBalance(author.id);
  if (amountCents > balance.availableCents) {
    return res.status(400).json({
      error: "Montant supérieur au solde disponible",
      availableCents: balance.availableCents,
      pendingMaturityNetCents: balance.pendingMaturityNetCents,
    });
  }

  // TODO production : Chariow ne propose pas d'API de transfert vers un
  // tiers (seulement un retrait vers TON propre Mobile Money, voir README
  // §4.1) — ce Payout reste donc à traiter manuellement : retire les fonds
  // sur ton Mobile Money puis envoie la part de l'auteur, avant dueBy.
  const payout = await prisma.payout.create({
    data: {
      authorId: author.id,
      amountCents,
      currency: "XOF",
      method: "momo",
      status: "PENDING",
      dueBy,
    },
  });

  return res.status(201).json(payout);
});
PLUMEFILE_EOF

echo "-> pages/api/public/purchase.js"
cat > 'pages/api/public/purchase.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";

// Route PUBLIQUE — alimente la page de remerciement (GET /api/public/purchase?id=...)
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();
  const { id } = req.query;
  if (!id) return res.status(400).json({ error: "id requis" });

  const purchase = await prisma.purchase.findUnique({
    where: { id },
    include: { book: true },
  });
  if (!purchase) return res.status(404).json({ error: "Commande introuvable" });

  return res.status(200).json({
    status: purchase.status,
    bookTitle: purchase.book.title,
    buyerName: purchase.buyerName,
    buyerEmail: purchase.buyerEmail,
    amountCents: purchase.amountCents,
    currency: purchase.currency,
    shippingAddress: purchase.shippingAddress,
    shippingCity: purchase.shippingCity,
    shippingPostalCode: purchase.shippingPostalCode,
    shippingCountry: purchase.shippingCountry,
  });
}
PLUMEFILE_EOF

echo "-> pages/api/sales-pages/[id].js"
cat > 'pages/api/sales-pages/[id].js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

export default requireAuth(async function handler(req, res) {
  const { id } = req.query;

  const salesPage = await prisma.salesPage.findUnique({
    where: { id },
    include: { book: true },
  });
  if (!salesPage || salesPage.book.authorId !== req.authorId) {
    return res.status(404).json({ error: "Page de vente introuvable" });
  }

  if (req.method === "GET") return res.status(200).json(salesPage);

  if (req.method === "PATCH") {
    const { problem, why, solution, priceCents, published } = req.body;
    const updated = await prisma.salesPage.update({
      where: { id },
      data: {
        ...(problem !== undefined && { problem }),
        ...(why !== undefined && { why }),
        ...(solution !== undefined && { solution }),
        ...(priceCents !== undefined && { priceCents }),
        ...(published !== undefined && { published }),
      },
    });
    return res.status(200).json(updated);
  }

  return res.status(405).end();
});
PLUMEFILE_EOF

echo "-> pages/api/sales-pages/index.js"
cat > 'pages/api/sales-pages/index.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { generateSalesPageCopy } from "../../../lib/ai";
import { createChariowProduct } from "../../../lib/chariow";

function slugify(title) {
  return title
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const { bookId, priceCents, currency } = req.body;
  if (!bookId || !priceCents || !currency) {
    return res.status(400).json({ error: "bookId, priceCents et currency sont requis" });
  }

  const book = await prisma.book.findFirst({
    where: { id: bookId, authorId: req.authorId },
    include: { author: true },
  });
  if (!book) return res.status(404).json({ error: "Livre introuvable" });

  const copy = await generateSalesPageCopy(book);
  const slug = `${slugify(book.title)}-${book.id.slice(-5)}`;

  let salesPage = await prisma.salesPage.upsert({
    where: { bookId: book.id },
    update: { priceCents, currency, ...copy },
    create: { bookId: book.id, slug, priceCents, currency, ...copy },
  });

  // Zone Afrique : provisionne un produit Chariow pour ce livre s'il n'en a
  // pas déjà un, afin que le checkout (POST /api/checkout/create) puisse
  // s'en servir. Best-effort — voir l'avertissement dans lib/chariow.js.
  if (book.author.region === "AFRIQUE" && !salesPage.chariowProductId) {
    try {
      const product = await createChariowProduct({
        name: book.title,
        description: copy.solution?.slice(0, 300) || book.title,
        priceValue: Math.round(priceCents / 100),
        currency,
      });
      salesPage = await prisma.salesPage.update({
        where: { id: salesPage.id },
        data: { chariowProductId: product.id },
      });
    } catch (err) {
      // On ne fait pas échouer la génération de la page pour autant : la
      // page de vente reste utilisable, mais le checkout renverra une
      // erreur explicite tant que chariowProductId n'est pas configuré
      // (manuellement si besoin, voir README).
      console.error("Provisionnement produit Chariow échoué :", err.message);
    }
  }

  return res.status(201).json(salesPage);
});
PLUMEFILE_EOF

echo "-> pages/api/sequences/[id].js"
cat > 'pages/api/sequences/[id].js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/api/sequences/index.js"
cat > 'pages/api/sequences/index.js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/api/sequences/steps/[stepId].js"
cat > 'pages/api/sequences/steps/[stepId].js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/api/stripe/connect/onboarding.js"
cat > 'pages/api/stripe/connect/onboarding.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";
import { stripe } from "../../../../lib/stripe";

// Crée (si besoin) le compte Stripe Connect Express de l'auteur puis
// retourne un lien d'onboarding hébergé par Stripe. Le frontend doit
// rediriger l'auteur vers cette URL — jamais de clé secrète échangée ici.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  let author = await prisma.author.findUnique({ where: { id: req.authorId } });

  if (!author.stripeAccountId) {
    const account = await stripe.accounts.create({
      type: "express",
      email: author.email,
      capabilities: {
        transfers: { requested: true },
        card_payments: { requested: true },
      },
    });
    author = await prisma.author.update({
      where: { id: author.id },
      data: { stripeAccountId: account.id },
    });
  }

  const accountLink = await stripe.accountLinks.create({
    account: author.stripeAccountId,
    refresh_url: `${process.env.APP_URL}/dashboard/paiements?stripe=refresh`,
    return_url: `${process.env.APP_URL}/dashboard/paiements?stripe=retour`,
    type: "account_onboarding",
  });

  return res.status(200).json({ url: accountLink.url });
});
PLUMEFILE_EOF

echo "-> pages/api/subscriptions/checkout.js"
cat > 'pages/api/subscriptions/checkout.js' << 'PLUMEFILE_EOF'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { initChariowCheckout } from "../../../lib/chariow";

// Un seul produit Chariow pour l'abonnement Plume, facturé dans la devise
// de la zone de l'auteur grâce au paramètre payment_currency (conversion
// automatique gérée par Chariow). Crée ce produit une fois dans ton
// dashboard Chariow et renseigne son ID dans CHARIOW_SUBSCRIPTION_PRODUCT_ID.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const author = await prisma.author.findUnique({ where: { id: req.authorId } });
  const [firstName, ...rest] = author.name.split(" ");

  const result = await initChariowCheckout({
    productId: process.env.CHARIOW_SUBSCRIPTION_PRODUCT_ID,
    email: author.email,
    firstName: firstName || author.name,
    lastName: rest.join(" ") || author.name,
    redirectUrl: `${process.env.APP_URL}/dashboard/abonnement?paiement=retour`,
    paymentCurrency: author.region === "EUROPE" ? "EUR" : "XOF",
    metadata: { authorId: author.id, kind: "subscription" },
  });

  if (result.step === "already_purchased") {
    return res.status(200).json({ status: "already_active" });
  }

  return res.status(200).json({ url: result.payment?.checkout_url });
});
PLUMEFILE_EOF

echo "-> pages/api/webhooks/chariow.js"
cat > 'pages/api/webhooks/chariow.js' << 'PLUMEFILE_EOF'
import { prisma } from "../../../lib/db";
import { verifyChariowSale } from "../../../lib/chariow";
import { sendPurchaseConfirmationEmail } from "../../../lib/email";

// Pulse Chariow. "sale.completed" est confirmé par la documentation
// publique. Les noms exacts des événements liés à l'abonnement
// (échec de paiement, annulation) ne sont PAS confirmés — vérifie-les dans
// Réglages > Pulses de ton dashboard Chariow et ajuste les comparaisons
// event === "..." ci-dessous si besoin.
//
// SÉCURITÉ : Chariow ne documente pas de signature HMAC vérifiable pour le
// moment (contrairement à Stripe). En attendant de la confirmer avec leur
// support, on protège cette route par un secret partagé dans l'URL — configure
// dans Chariow l'URL exacte :
//   https://ton-domaine.vercel.app/api/webhooks/chariow?secret=TA_VALEUR
// (la même valeur que CHARIOW_WEBHOOK_SECRET). Sans ce secret, la requête
// est rejetée avant même d'être lue — même le cas "sale.completed", pourtant
// déjà re-vérifié auprès de Chariow, gagne cette couche supplémentaire.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  if (!process.env.CHARIOW_WEBHOOK_SECRET || req.query.secret !== process.env.CHARIOW_WEBHOOK_SECRET) {
    return res.status(401).json({ error: "Non autorisé" });
  }

  const { event, data } = req.body || {};
  if (!event || !data) return res.status(400).json({ error: "Payload invalide" });

  const customerEmail = data.customer?.email;
  const productSlug = data.product?.slug;
  const authorId = data.metadata?.authorId;
  const kind = data.metadata?.kind;

  if (event === "sale.completed") {
    // Reconfirmation serveur-à-serveur avant de faire confiance à la
    // notification — même principe que pour CinetPay/Stripe.
    const confirmed =
      customerEmail && productSlug ? await verifyChariowSale({ productSlug, customerEmail }) : null;

    if (!confirmed) {
      return res.status(200).json({ received: true, ignored: "not_confirmed" });
    }

    if (kind === "subscription" && authorId) {
      // Paiement de l'abonnement à la plateforme.
      await prisma.author.update({
        where: { id: authorId },
        data: {
          subscriptionStatus: "ACTIVE",
          currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });
    } else if (customerEmail) {
      // Achat d'un livre (zone Afrique).
      const purchase = await prisma.purchase.findFirst({
        where: { provider: "chariow", buyerEmail: customerEmail, status: "pending" },
        orderBy: { createdAt: "desc" },
        include: { book: true },
      });
      if (purchase) {
        await prisma.purchase.update({ where: { id: purchase.id }, data: { status: "paid" } });
        await prisma.lead.create({
          data: {
            authorId: purchase.authorId,
            bookId: purchase.bookId,
            firstName: purchase.buyerName,
            lastName: "",
            email: purchase.buyerEmail,
            whatsapp: purchase.buyerWhatsapp || "",
            source: "acheteur",
          },
        });
        await sendPurchaseConfirmationEmail({
          to: purchase.buyerEmail,
          buyerName: purchase.buyerName,
          bookTitle: purchase.book.title,
          amountFormatted: `${purchase.amountCents} ${purchase.currency}`,
        });
      }
    }
  }

  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
  if (event === "subscription.payment_failed" && authorId) {
    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "PAST_DUE" } });
  }

  // À CONFIRMER dans le dashboard Chariow (Réglages > Pulses).
  if (event === "subscription.cancelled" && authorId) {
    await prisma.author.update({ where: { id: authorId }, data: { subscriptionStatus: "CANCELED" } });
  }

  return res.status(200).json({ received: true });
}
PLUMEFILE_EOF

echo "-> pages/api/webhooks/stripe.js"
cat > 'pages/api/webhooks/stripe.js' << 'PLUMEFILE_EOF'
import { buffer } from "micro";
import { prisma } from "../../../lib/db";
import { stripe } from "../../../lib/stripe";
import { sendPurchaseConfirmationEmail } from "../../../lib/email";

// Stripe exige le corps brut (non parsé) pour vérifier la signature.
export const config = {
  api: { bodyParser: false },
};

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const sig = req.headers["stripe-signature"];
  const buf = await buffer(req);

  let event;
  try {
    event = stripe.webhooks.constructEvent(buf, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook signature invalide : ${err.message}`);
  }

  // Vente d'un livre payée
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const purchaseId = session.metadata?.purchaseId;
    if (purchaseId) {
      const purchase = await prisma.purchase.update({
        where: { id: purchaseId },
        data: { status: "paid" },
        include: { book: true },
      });
      await prisma.lead.create({
        data: {
          authorId: purchase.authorId,
          bookId: purchase.bookId,
          firstName: purchase.buyerName,
          lastName: "",
          email: purchase.buyerEmail,
          whatsapp: purchase.buyerWhatsapp || "",
          source: "acheteur",
        },
      });
      await sendPurchaseConfirmationEmail({
        to: purchase.buyerEmail,
        buyerName: purchase.buyerName,
        bookTitle: purchase.book.title,
        amountFormatted: `${(purchase.amountCents / 100).toFixed(2)} ${purchase.currency}`,
      });
    }
  }

  // Onboarding Stripe Connect de l'auteur terminé / mis à jour
  if (event.type === "account.updated") {
    const account = event.data.object;
    await prisma.author.updateMany({
      where: { stripeAccountId: account.id },
      data: { stripeOnboarded: Boolean(account.charges_enabled && account.details_submitted) },
    });
  }

  // Note : l'abonnement à la plateforme (Plume) est désormais facturé via
  // Chariow pour les deux zones — voir pages/api/subscriptions/checkout.js
  // et pages/api/webhooks/chariow.js. Ce webhook Stripe ne gère plus que la
  // vente de livres (zone Europe) et l'onboarding Stripe Connect.

  return res.status(200).json({ received: true });
}
PLUMEFILE_EOF

echo "-> prisma/schema.prisma"
cat > 'prisma/schema.prisma' << 'PLUMEFILE_EOF'
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

  books              Book[]
  leads              Lead[]
  purchases          Purchase[]
  payouts            Payout[]
  emailSequences     EmailSequence[]
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

  emailSends EmailSend[]
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
PLUMEFILE_EOF

echo "-> vercel.json"
cat > 'vercel.json' << 'PLUMEFILE_EOF'
{
  "crons": [
    {
      "path": "/api/cron/process-emails",
      "schedule": "0 8 * * *"
    }
  ]
}
PLUMEFILE_EOF

echo ""
echo "✓ Projet recréé avec succès — " $(find . -type f -not -path "./.git/*" | wc -l) "fichiers."
echo "Prochaine étape : npm install"
