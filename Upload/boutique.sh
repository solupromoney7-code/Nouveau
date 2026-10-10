#!/bin/bash
set -e
echo "Ajoute la page Ma boutique (vitrine publique)"

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
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/api/authors/store.js")"
cat > "pages/api/authors/store.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

function slugify(value) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

// GET -> état de la vitrine publique (slug + livres éligibles à y figurer)
// PUT -> choisit/modifie le slug de la vitrine (ex: "nom-de-la-boutique")
export default requireAuth(async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const author = await prisma.author.findUnique({
        where: { id: req.authorId },
        select: { storeSlug: true },
      });

      const books = await prisma.book.findMany({
        where: { authorId: req.authorId },
        orderBy: { createdAt: "desc" },
        include: { salesPage: true },
      });

      return res.status(200).json({
        storeSlug: author.storeSlug,
        books: books.map((b) => ({
          id: b.id,
          title: b.title,
          priceCents: b.salesPage?.priceCents ?? null,
          currency: b.salesPage?.currency ?? null,
          published: b.salesPage?.published ?? false,
          salesPageSlug: b.salesPage?.slug ?? null,
        })),
      });
    }

    if (req.method === "PUT") {
      const { storeSlug } = req.body;
      if (!storeSlug || !storeSlug.trim()) {
        return res.status(400).json({ error: "Nom de boutique requis" });
      }
      const clean = slugify(storeSlug);
      if (!clean) {
        return res.status(400).json({ error: "Ce nom de boutique n'est pas valide" });
      }

      const existing = await prisma.author.findUnique({ where: { storeSlug: clean } });
      if (existing && existing.id !== req.authorId) {
        return res.status(409).json({ error: "Ce nom de boutique est déjà pris, essayez-en un autre." });
      }

      await prisma.author.update({ where: { id: req.authorId }, data: { storeSlug: clean } });
      return res.status(200).json({ storeSlug: clean });
    }

    return res.status(405).end();
  } catch (error) {
    console.error("Erreur /api/authors/store :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/boutique/[slug].js")"
cat > "pages/boutique/[slug].js" << 'FILE_EOF_MARKER'
import Head from "next/head";
import Link from "next/link";
import { BookOpen } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover } from "../../components/ui";

export async function getServerSideProps({ params }) {
  const author = await prisma.author.findUnique({
    where: { storeSlug: params.slug },
    include: {
      books: {
        include: { salesPage: true },
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!author) return { notFound: true };

  const books = author.books
    .filter((b) => b.salesPage?.published)
    .map((b) => ({
      id: b.id,
      title: b.title,
      slug: b.salesPage.slug,
      priceCents: b.salesPage.priceCents,
      currency: b.salesPage.currency,
    }));

  return {
    props: {
      authorName: author.name,
      books,
    },
  };
}

function formatPrice(cents, currency) {
  const amount = (cents || 0) / 100;
  if (currency === "EUR") return `${amount.toFixed(2)} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

export default function PublicStorePage({ authorName, books }) {
  return (
    <div className="min-h-screen" style={{ backgroundColor: colors.bgLight }}>
      <Head>
        <title>{authorName} — Boutique</title>
      </Head>

      <header className="px-5 pt-12 pb-10 text-center">
        <div className="w-11 h-11 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.gold }}>
          <BookOpen size={18} color={colors.ink} />
        </div>
        <p className="font-mono text-[11px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Boutique</p>
        <h1 className="font-display text-3xl" style={{ color: colors.textPaper }}>{authorName}</h1>
      </header>

      <main className="max-w-4xl mx-auto px-5 pb-20">
        {books.length === 0 ? (
          <p className="font-body text-sm text-center" style={{ color: colors.textMutedLight }}>
            Aucun livre disponible pour le moment — revenez bientôt.
          </p>
        ) : (
          <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6">
            {books.map((book) => (
              <Link
                key={book.id}
                href={`/p/${book.slug}`}
                className="rounded-2xl p-6 flex flex-col items-center text-center gap-4 transition-transform hover:-translate-y-0.5"
                style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}
              >
                <BookCover title={book.title} author={authorName} />
                <div>
                  <p className="font-display text-base mb-1" style={{ color: colors.textPaper }}>{book.title}</p>
                  <p className="font-body text-sm font-semibold" style={{ color: colors.goldDark }}>
                    {formatPrice(book.priceCents, book.currency)}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
FILE_EOF_MARKER

mkdir -p "$(dirname "pages/dashboard/boutique.js")"
cat > "pages/dashboard/boutique.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import Link from "next/link";
import { Store, Copy, Check, ExternalLink, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

function formatPrice(cents, currency) {
  if (cents == null) return "—";
  const amount = cents / 100;
  if (currency === "EUR") return `${amount.toFixed(2)} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

function slugifyPreview(value) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export default function DashboardBoutique() {
  const { author, loading: authLoading } = useAuthGuard();

  const [store, setStore] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [slugInput, setSlugInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");

  const [copied, setCopied] = useState(false);
  const [origin, setOrigin] = useState("");

  useEffect(() => {
    if (typeof window !== "undefined") setOrigin(window.location.origin);
  }, []);

  useEffect(() => {
    if (!author) return;
    api("/api/authors/store")
      .then((data) => {
        setStore(data);
        if (!data.storeSlug && author.name) setSlugInput(slugifyPreview(author.name));
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  async function handleCreateStore(e) {
    e.preventDefault();
    setSaveError("");
    setSaving(true);
    try {
      const data = await api("/api/authors/store", { method: "PUT", body: { storeSlug: slugInput } });
      setStore((s) => ({ ...s, storeSlug: data.storeSlug }));
    } catch (err) {
      setSaveError(err.message);
    } finally {
      setSaving(false);
    }
  }

  function handleCopy() {
    const url = `${origin}/boutique/${store.storeSlug}`;
    navigator.clipboard?.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  const publishedCount = store?.books?.filter((b) => b.published).length || 0;

  return (
    <DashboardShell active="boutique" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Vitrine publique</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Ma boutique</h1>
      </header>

      {authLoading || loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl space-y-6">
          <ErrorBanner message={error} />

          <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
            <div className="flex items-center gap-2 mb-1">
              <Store size={16} color={colors.goldDark} />
              <h2 className="font-display text-lg" style={{ color: colors.textPaper }}>
                {store?.storeSlug ? "Votre boutique" : "Créer votre boutique"}
              </h2>
            </div>

            {!store?.storeSlug ? (
              <>
                <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
                  Une page unique qui liste tous vos livres publiés, à partager en un lien (réseaux sociaux, bio, messages).
                </p>
                <form onSubmit={handleCreateStore} className="space-y-3 max-w-md">
                  <ErrorBanner message={saveError} />
                  <div>
                    <p className="font-mono text-[10px] uppercase tracking-wide mb-1.5" style={{ color: colors.mist }}>
                      Adresse de votre boutique
                    </p>
                    <div className="flex items-center rounded-lg overflow-hidden" style={{ backgroundColor: colors.paperDim }}>
                      <span className="pl-3 font-body text-sm shrink-0" style={{ color: colors.textPaperDim }}>
                        {origin}/boutique/
                      </span>
                      <input
                        value={slugInput}
                        onChange={(e) => setSlugInput(e.target.value)}
                        className="flex-1 min-w-0 px-2 py-2 font-body text-sm bg-transparent"
                        style={{ color: colors.textPaper, border: "none", outline: "none" }}
                      />
                    </div>
                  </div>
                  <button
                    type="submit"
                    disabled={saving}
                    className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
                    style={{ backgroundColor: colors.gold, color: colors.ink, opacity: saving ? 0.6 : 1 }}
                  >
                    {saving && <Loader2 size={14} className="animate-spin" />}
                    {saving ? "Création…" : "Créer ma boutique"}
                  </button>
                </form>
              </>
            ) : (
              <>
                <p className="font-body text-sm mb-3" style={{ color: colors.textPaperDim }}>
                  {publishedCount > 0
                    ? `${publishedCount} livre${publishedCount > 1 ? "s" : ""} publié${publishedCount > 1 ? "s" : ""} visible${publishedCount > 1 ? "s" : ""} sur votre boutique.`
                    : "Aucun livre publié pour l’instant — publiez une page de vente pour qu’elle apparaisse ici."}
                </p>
                <div className="flex items-center gap-2 flex-wrap">
                  <div className="flex items-center rounded-lg overflow-hidden" style={{ backgroundColor: colors.paperDim }}>
                    <span className="px-3 py-2 font-mono text-xs" style={{ color: colors.textPaper }}>
                      {origin}/boutique/{store.storeSlug}
                    </span>
                  </div>
                  <button
                    onClick={handleCopy}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-lg font-body text-xs font-semibold"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
                  >
                    {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copié" : "Copier"}
                  </button>
                  <Link
                    href={`/boutique/${store.storeSlug}`}
                    target="_blank"
                    className="flex items-center gap-1.5 px-3 py-2 rounded-lg font-body text-xs font-semibold"
                    style={{ backgroundColor: colors.gold, color: colors.ink }}
                  >
                    Voir ma boutique <ExternalLink size={13} />
                  </Link>
                </div>
              </>
            )}
          </section>

          {store?.books?.length > 0 && (
            <section className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-4" style={{ color: colors.goldDark }}>
                Vos livres
              </p>
              <div className="space-y-2">
                {store.books.map((b) => (
                  <div key={b.id} className="flex items-center justify-between gap-3 px-3 py-2.5 rounded-lg" style={{ backgroundColor: colors.paperDim }}>
                    <div className="min-w-0">
                      <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{b.title}</p>
                      <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>{formatPrice(b.priceCents, b.currency)}</p>
                    </div>
                    <span
                      className="shrink-0 font-mono text-[10px] px-2 py-1 rounded-full"
                      style={{
                        backgroundColor: b.published ? "rgba(79,122,92,0.12)" : "rgba(122,46,59,0.1)",
                        color: b.published ? colors.forest : colors.wine,
                      }}
                    >
                      {b.published ? "Publié" : "Non publié"}
                    </span>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

echo "Terminé."
