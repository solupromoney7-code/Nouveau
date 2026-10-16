import Link from "next/link";
import { BookOpen } from "lucide-react";
import { colors } from "./ui";

// Pied de page complet de la page d'accueil — inspiré dans son organisation
// (colonnes Produit / Ressources / Légal) de ce que proposent les grandes
// plateformes du secteur, mais avec le contenu, le ton et le style propres
// à Plume.
const columns = [
  {
    heading: "Produit",
    links: [
      { label: "Page de vente IA", href: "/#produit" },
      { label: "Page d'extrait", href: "/#produit" },
      { label: "Tunnels email & WhatsApp", href: "/#produit" },
      { label: "Boutique en ligne", href: "/#produit" },
      { label: "Tarifs", href: "/#tarifs" },
    ],
  },
  {
    heading: "Compte",
    links: [
      { label: "Créer un compte", href: "/inscription" },
      { label: "Se connecter", href: "/connexion" },
    ],
  },
  {
    heading: "Légal",
    links: [
      { label: "Mentions légales", href: "/mentions-legales" },
      { label: "Conditions d'utilisation", href: "/cgu" },
      { label: "Conditions de vente", href: "/cgv" },
      { label: "Confidentialité", href: "/confidentialite" },
    ],
  },
];

export default function Footer() {
  return (
    <footer className="border-t px-5 pt-14 pb-8" style={{ borderColor: colors.paperDim, backgroundColor: colors.bgLightAlt }}>
      <div className="max-w-6xl mx-auto">
        <div className="grid sm:grid-cols-2 md:grid-cols-[1.4fr_1fr_1fr_1fr] gap-10 pb-12">
          <div>
            <div className="flex items-center gap-2 mb-3">
              <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
                <BookOpen size={14} color={colors.ink} />
              </div>
              <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
            </div>
            <p className="font-body text-sm max-w-xs" style={{ color: colors.textMutedLight }}>
              La plateforme qui transforme le manuscrit d'un auteur indépendant en une offre prête à vendre —
              page de vente, extrait, contenus et relances automatiques, sans écrire une ligne de code.
            </p>
          </div>

          {columns.map((col) => (
            <div key={col.heading}>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-4" style={{ color: colors.goldDark }}>
                {col.heading}
              </p>
              <div className="flex flex-col gap-2.5">
                {col.links.map((l) => (
                  <Link
                    key={l.label}
                    href={l.href}
                    className="font-body text-sm"
                    style={{ color: colors.textMutedLight }}
                  >
                    {l.label}
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div
          className="pt-6 border-t flex flex-col sm:flex-row items-center justify-between gap-3"
          style={{ borderColor: colors.paperDim }}
        >
          <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
            © {new Date().getFullYear()} Plume. Tous droits réservés.
          </p>
          <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
            Plateforme de vente pour auteurs indépendants — Afrique francophone, France &amp; Europe
          </p>
        </div>
      </div>
    </footer>
  );
}
