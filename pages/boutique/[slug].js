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
