import Link from "next/link";
import { ArrowLeft, BookOpen } from "lucide-react";
import { colors } from "./ui";

// Mise en page partagée par toutes les pages légales (mentions légales,
// CGU, CGV, confidentialité) : même en-tête, même typographie sobre et
// lisible, adaptée à un texte long plutôt qu'au reste du site marketing.
export default function LegalLayout({ title, updated, children }) {
  return (
    <div className="min-h-screen" style={{ backgroundColor: colors.bgLight }}>
      <header className="border-b px-5 py-5" style={{ borderColor: colors.paperDim }}>
        <div className="max-w-3xl mx-auto flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
              <BookOpen size={14} color={colors.ink} />
            </div>
            <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
          </Link>
          <Link
            href="/"
            className="flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-wide"
            style={{ color: colors.textMutedLight }}
          >
            <ArrowLeft size={13} /> Retour au site
          </Link>
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-5 py-12 md:py-16">
        <p className="font-mono text-[11px] uppercase tracking-widest mb-3" style={{ color: colors.goldDark }}>
          Document légal
        </p>
        <h1 className="font-display text-3xl md:text-4xl mb-2" style={{ color: colors.textPaper }}>{title}</h1>
        {updated && (
          <p className="font-body text-xs mb-10" style={{ color: colors.textMutedLight }}>
            Dernière mise à jour : {updated}
          </p>
        )}

        <div className="legal-content">{children}</div>
      </main>

      <style jsx global>{`
        .legal-content h2 {
          font-family: var(--font-display, serif);
          font-size: 1.25rem;
          color: ${colors.textPaper};
          margin-top: 2.25rem;
          margin-bottom: 0.75rem;
        }
        .legal-content h2:first-child {
          margin-top: 0;
        }
        .legal-content p,
        .legal-content li {
          font-family: var(--font-body, sans-serif);
          font-size: 0.925rem;
          line-height: 1.7;
          color: ${colors.textPaperDim};
        }
        .legal-content p {
          margin-bottom: 1rem;
        }
        .legal-content ul {
          margin-bottom: 1rem;
          padding-left: 1.25rem;
          list-style: disc;
        }
        .legal-content li {
          margin-bottom: 0.4rem;
        }
        .legal-content strong {
          color: ${colors.textPaper};
        }
        .legal-content a {
          color: ${colors.goldDark};
          text-decoration: underline;
        }
      `}</style>

      <footer className="border-t px-5 py-8 mt-8" style={{ borderColor: colors.paperDim }}>
        <div className="max-w-3xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-3">
          <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
            © {new Date().getFullYear()} Plume. Tous droits réservés.
          </p>
          <div className="flex items-center gap-4 font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
            <Link href="/mentions-legales">Mentions légales</Link>
            <Link href="/cgu">CGU</Link>
            <Link href="/cgv">CGV</Link>
            <Link href="/confidentialite">Confidentialité</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
