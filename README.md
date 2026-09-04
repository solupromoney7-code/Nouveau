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
