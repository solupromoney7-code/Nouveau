import Link from "next/link";
import { colors } from "./ui";

// Pied de page léger utilisé sur les pages publiques tournées vers les
// lecteurs (page de vente, page d'extrait, boutique) : juste assez pour
// être en règle (liens légaux visibles là où des données sont collectées)
// sans alourdir une page pensée pour convertir.
export default function PublicFooter() {
  return (
    <footer className="px-5 py-8 mt-4">
      <div className="max-w-3xl mx-auto flex flex-col sm:flex-row items-center justify-center gap-2 sm:gap-4 text-center">
        <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
          © {new Date().getFullYear()} Plume
        </p>
        <span className="hidden sm:inline font-mono text-[11px]" style={{ color: colors.textMutedLight }}>·</span>
        <Link href="/mentions-legales" className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
          Mentions légales
        </Link>
        <span className="hidden sm:inline font-mono text-[11px]" style={{ color: colors.textMutedLight }}>·</span>
        <Link href="/cgv" className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
          CGV
        </Link>
        <span className="hidden sm:inline font-mono text-[11px]" style={{ color: colors.textMutedLight }}>·</span>
        <Link href="/confidentialite" className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
          Confidentialité
        </Link>
      </div>
    </footer>
  );
}
