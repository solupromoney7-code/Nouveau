#!/bin/bash
set -e
echo "Application du pied de page et des pages légales..."

mkdir -p "lib"
cat > "lib/legalInfo.js" << 'PLUME_EOF_MARKER'
// Informations légales de Plume — un seul endroit à modifier.
//
// Remplacez les valeurs entre [crochets] par vos vraies informations avant
// le lancement public du site (c'est une obligation légale en France et
// dans la plupart des pays : un site professionnel doit identifier qui
// l'édite). Tout le reste du site (mentions légales, CGU, CGV,
// confidentialité, pied de page) se met à jour automatiquement.

export const legalInfo = {
  // Nom affiché publiquement (marque)
  siteName: "Plume",

  // Identité de l'éditeur du site. Si vous êtes en nom propre (pas encore
  // d'entreprise enregistrée), indiquez simplement votre nom complet et
  // votre statut ("entrepreneur individuel"). Si vous avez une société,
  // mettez sa raison sociale et son numéro d'immatriculation (SIRET,
  // RCCM...).
  publisherName: "[Votre nom complet ou raison sociale]",
  publisherStatus: "[Statut — ex. entrepreneur individuel / SARL / société]",
  publisherRegistration: "[Numéro d'immatriculation si applicable — SIRET, RCCM...]",
  publisherAddress: "[Adresse postale de l'éditeur]",
  publisherEmail: "[votre-email-de-contact@exemple.com]",
  publisherPhone: "", // optionnel — laissez vide pour ne pas l'afficher

  // Responsable de la publication (souvent la même personne que l'éditeur)
  publicationDirector: "[Nom du directeur de la publication]",

  // Hébergeur du site (technique)
  hostingProvider: "Vercel Inc.",
  hostingProviderInfo: "Informations complètes sur vercel.com/legal",

  // Hébergeur de la base de données
  databaseProvider: "Neon Inc.",

  // Juridiction / droit applicable par défaut
  jurisdiction: "[Pays de droit applicable — ex. France]",
};
PLUME_EOF_MARKER

mkdir -p "components"
cat > "components/LegalLayout.js" << 'PLUME_EOF_MARKER'
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
PLUME_EOF_MARKER

mkdir -p "components"
cat > "components/Footer.js" << 'PLUME_EOF_MARKER'
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
PLUME_EOF_MARKER

mkdir -p "components"
cat > "components/PublicFooter.js" << 'PLUME_EOF_MARKER'
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
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/mentions-legales.js" << 'PLUME_EOF_MARKER'
import LegalLayout from "../components/LegalLayout";
import { legalInfo } from "../lib/legalInfo";

export default function MentionsLegales() {
  return (
    <LegalLayout title="Mentions légales" updated="14 octobre 2026">
      <h2>Éditeur du site</h2>
      <p>
        Le site {legalInfo.siteName} est édité par <strong>{legalInfo.publisherName}</strong>
        {legalInfo.publisherStatus ? `, ${legalInfo.publisherStatus}` : ""}
        {legalInfo.publisherRegistration ? ` (${legalInfo.publisherRegistration})` : ""}.
      </p>
      <ul>
        <li>Adresse : {legalInfo.publisherAddress}</li>
        <li>Email de contact : {legalInfo.publisherEmail}</li>
        {legalInfo.publisherPhone && <li>Téléphone : {legalInfo.publisherPhone}</li>}
        <li>Directeur de la publication : {legalInfo.publicationDirector}</li>
      </ul>

      <h2>Hébergement</h2>
      <p>
        Le site est hébergé par <strong>{legalInfo.hostingProvider}</strong>. {legalInfo.hostingProviderInfo}.
      </p>
      <p>
        La base de données de la plateforme est hébergée par <strong>{legalInfo.databaseProvider}</strong>.
      </p>

      <h2>Activité du site</h2>
      <p>
        {legalInfo.siteName} est une plateforme technique qui permet à des auteurs indépendants de créer des
        pages de vente, des pages d'extrait, du contenu promotionnel et des séquences marketing automatisées
        pour leurs propres livres, et de recevoir les paiements de leurs lecteurs via des prestataires de
        paiement tiers (Stripe pour l'Europe, Chariow pour l'Afrique).
      </p>
      <p>
        {legalInfo.siteName} agit en tant que prestataire technique. Chaque auteur reste seul responsable du
        contenu qu'il publie (textes, livres, visuels, messages envoyés à ses contacts) et des ventes qu'il
        réalise auprès de ses lecteurs. Voir nos{" "}
        <a href="/cgu">Conditions Générales d'Utilisation</a> et nos{" "}
        <a href="/cgv">Conditions Générales de Vente</a> pour le détail des responsabilités de chacun.
      </p>

      <h2>Propriété intellectuelle</h2>
      <p>
        La marque {legalInfo.siteName}, le logo, la structure du site et son design sont la propriété de
        l'éditeur et sont protégés par le droit de la propriété intellectuelle. Toute reproduction non
        autorisée est interdite.
      </p>
      <p>
        Les livres, textes, images de couverture et contenus téléversés par les auteurs restent leur propriété
        exclusive. {legalInfo.siteName} ne revendique aucun droit sur ces contenus, en dehors du droit
        strictement nécessaire à leur hébergement et à leur affichage sur la plateforme pour le compte de
        l'auteur.
      </p>

      <h2>Données personnelles</h2>
      <p>
        Le traitement des données personnelles collectées sur ce site est décrit dans notre{" "}
        <a href="/confidentialite">Politique de confidentialité</a>.
      </p>

      <h2>Droit applicable</h2>
      <p>
        Les présentes mentions légales sont soumises au droit {legalInfo.jurisdiction}. En cas de litige et à
        défaut de résolution amiable, les tribunaux compétents seront ceux du ressort de l'éditeur.
      </p>
    </LegalLayout>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/cgu.js" << 'PLUME_EOF_MARKER'
import LegalLayout from "../components/LegalLayout";
import { legalInfo } from "../lib/legalInfo";

export default function CGU() {
  return (
    <LegalLayout title="Conditions Générales d'Utilisation" updated="14 octobre 2026">
      <h2>1. Objet</h2>
      <p>
        Les présentes Conditions Générales d'Utilisation (« CGU ») encadrent l'accès et l'utilisation de la
        plateforme {legalInfo.siteName}, éditée par {legalInfo.publisherName}. Toute création de compte sur{" "}
        {legalInfo.siteName} implique l'acceptation pleine et entière des présentes CGU.
      </p>

      <h2>2. Description du service</h2>
      <p>{legalInfo.siteName} permet à un auteur indépendant de :</p>
      <ul>
        <li>téléverser un livre et générer automatiquement, à l'aide d'une intelligence artificielle, une page de vente et une page d'extrait gratuit ;</li>
        <li>générer du contenu promotionnel pour les réseaux sociaux à partir de son livre ;</li>
        <li>collecter les coordonnées de ses lecteurs (prospects et acheteurs) et leur envoyer des séquences automatisées par email et par WhatsApp ;</li>
        <li>recevoir le paiement de ses ventes via un prestataire de paiement tiers et demander le versement de ses revenus.</li>
      </ul>

      <h2>3. Création de compte</h2>
      <p>
        L'inscription nécessite de fournir des informations exactes (nom, adresse email, et selon la zone
        géographique, les informations nécessaires au paiement). L'auteur est seul responsable de la
        confidentialité de ses identifiants de connexion et de toute activité réalisée depuis son compte.
      </p>

      <h2>4. Essai gratuit et abonnement</h2>
      <p>
        L'accès aux fonctionnalités payantes de {legalInfo.siteName} est soumis à un abonnement, précédé d'une
        période d'essai gratuit. Les conditions tarifaires, de facturation et de résiliation sont détaillées
        dans nos <a href="/cgv">Conditions Générales de Vente</a>.
      </p>

      <h2>5. Propriété du contenu</h2>
      <p>
        L'auteur demeure propriétaire de l'ensemble du contenu qu'il téléverse ou génère via la plateforme
        (texte du livre, titre, couverture, pages de vente, contenus réseaux sociaux, messages envoyés à ses
        contacts). Le contenu généré par l'intelligence artificielle à partir du livre de l'auteur, pour le
        compte de cet auteur, lui appartient également.
      </p>

      <h2>6. Utilisation acceptable</h2>
      <p>En utilisant {legalInfo.siteName}, l'auteur s'engage à ne pas :</p>
      <ul>
        <li>publier ou vendre un contenu illégal, contrefait, diffamatoire, ou portant atteinte aux droits d'un tiers ;</li>
        <li>utiliser les outils de messagerie (email, WhatsApp) pour envoyer des messages non sollicités à des personnes n'ayant pas consenti à être contactées ;</li>
        <li>tenter de contourner la sécurité de la plateforme ou d'accéder aux données d'un autre auteur ;</li>
        <li>utiliser la plateforme à des fins frauduleuses, notamment pour collecter des paiements sans livrer le contenu promis.</li>
      </ul>
      <p>
        Le non-respect de ces règles peut entraîner la suspension ou la suppression du compte, sans préjudice
        d'éventuelles poursuites.
      </p>

      <h2>7. Rôle de {legalInfo.siteName}</h2>
      <p>
        {legalInfo.siteName} fournit les outils techniques permettant à l'auteur de vendre ses livres et de
        communiquer avec ses lecteurs. {legalInfo.siteName} n'intervient pas dans la rédaction du livre, ne
        relit pas son contenu avant publication, et n'est pas partie au contrat de vente conclu entre l'auteur
        et chaque acheteur. La responsabilité de {legalInfo.siteName} ne saurait être engagée en cas de
        contenu inapproprié publié par un auteur, de litige entre un auteur et un acheteur, ou
        d'indisponibilité ponctuelle des services tiers utilisés par la plateforme (paiement, messagerie,
        hébergement).
      </p>

      <h2>8. Disponibilité du service</h2>
      <p>
        {legalInfo.siteName} met tout en œuvre pour assurer un accès continu à la plateforme, sans pouvoir
        garantir une disponibilité absolue. Des interruptions peuvent survenir pour maintenance ou en raison
        d'incidents indépendants de sa volonté.
      </p>

      <h2>9. Résiliation</h2>
      <p>
        L'auteur peut cesser d'utiliser {legalInfo.siteName} à tout moment en résiliant son abonnement depuis
        son tableau de bord. {legalInfo.siteName} se réserve le droit de suspendre ou supprimer un compte en
        cas de manquement grave aux présentes CGU.
      </p>

      <h2>10. Modification des CGU</h2>
      <p>
        {legalInfo.siteName} peut modifier les présentes CGU à tout moment. Les auteurs seront informés de
        toute modification substantielle. La poursuite de l'utilisation du service après modification vaut
        acceptation des nouvelles CGU.
      </p>

      <h2>11. Droit applicable</h2>
      <p>Les présentes CGU sont soumises au droit {legalInfo.jurisdiction}.</p>

      <h2>12. Contact</h2>
      <p>Pour toute question relative aux présentes CGU : {legalInfo.publisherEmail}.</p>
    </LegalLayout>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/cgv.js" << 'PLUME_EOF_MARKER'
import LegalLayout from "../components/LegalLayout";
import { legalInfo } from "../lib/legalInfo";

export default function CGV() {
  return (
    <LegalLayout title="Conditions Générales de Vente" updated="14 octobre 2026">
      <p>
        Les présentes Conditions Générales de Vente (« CGV ») distinguent deux relations contractuelles
        différentes sur {legalInfo.siteName} : (A) l'abonnement souscrit par un auteur auprès de{" "}
        {legalInfo.siteName}, et (B) la vente d'un livre conclue entre un auteur et son lecteur par
        l'intermédiaire de la plateforme.
      </p>

      <h2>A. Abonnement à la plateforme {legalInfo.siteName}</h2>

      <h2 style={{ marginTop: "1rem" }}>A.1 — Objet</h2>
      <p>
        L'abonnement donne accès aux fonctionnalités de {legalInfo.siteName} : génération de pages de vente et
        d'extrait par IA, génération de contenu réseaux sociaux, tunnels de vente automatisés (email et
        WhatsApp), boutique en ligne, gestion des contacts et des paiements.
      </p>

      <h2 style={{ marginTop: "1rem" }}>A.2 — Prix et paiement</h2>
      <p>
        Le prix de l'abonnement est affiché sur la page d'accueil et dans l'espace « Abonnement » du tableau
        de bord, en fonction de la zone géographique de l'auteur (Europe ou Afrique). Le paiement est traité
        par un prestataire tiers : Stripe pour les auteurs facturés en euros, Chariow pour les auteurs facturés
        en FCFA. {legalInfo.siteName} ne stocke aucune donnée de carte bancaire ou de moyen de paiement.
      </p>

      <h2 style={{ marginTop: "1rem" }}>A.3 — Essai gratuit</h2>
      <p>
        Un essai gratuit est proposé lors de l'inscription. Il donne accès à l'ensemble des fonctionnalités
        pendant la durée indiquée au moment de l'inscription. À l'issue de cette période, l'accès aux
        fonctionnalités payantes est suspendu jusqu'à la souscription d'un abonnement.
      </p>

      <h2 style={{ marginTop: "1rem" }}>A.4 — Durée et résiliation</h2>
      <p>
        L'abonnement est souscrit pour une durée mensuelle, renouvelée automatiquement sauf résiliation par
        l'auteur depuis son tableau de bord, à tout moment, avec effet à la fin de la période déjà payée.
      </p>

      <h2 style={{ marginTop: "1rem" }}>A.5 — Remboursement</h2>
      <p>
        Sauf disposition légale impérative contraire applicable dans le pays de l'auteur, les sommes versées
        au titre d'une période d'abonnement déjà entamée ne sont pas remboursables. L'auteur conserve l'accès
        au service jusqu'à la fin de la période déjà payée en cas de résiliation.
      </p>

      <h2>B. Vente de livres entre l'auteur et ses lecteurs</h2>

      <h2 style={{ marginTop: "1rem" }}>B.1 — Rôle de {legalInfo.siteName}</h2>
      <p>
        Lorsqu'un lecteur achète un livre sur une page de vente hébergée par {legalInfo.siteName}, le contrat
        de vente est conclu directement entre <strong>l'auteur</strong> (vendeur) et le <strong>lecteur</strong>{" "}
        (acheteur). {legalInfo.siteName} agit uniquement comme intermédiaire technique : affichage de la page
        de vente, mise à disposition du formulaire de commande, et acheminement du paiement via Stripe ou
        Chariow jusqu'au solde disponible de l'auteur. {legalInfo.siteName} n'est ni vendeur, ni revendeur des
        livres proposés sur la plateforme.
      </p>

      <h2 style={{ marginTop: "1rem" }}>B.2 — Prix, livraison et garanties</h2>
      <p>
        Le prix de chaque livre, ses modalités de livraison (fichier numérique, lien de téléchargement,
        expédition physique le cas échéant) ainsi que toute garantie ou politique de remboursement associée
        au livre lui-même relèvent de la seule responsabilité de l'auteur qui le vend. Toute réclamation
        relative au contenu d'un livre, à sa non-conformité ou à sa non-livraison doit être adressée
        directement à l'auteur concerné.
      </p>

      <h2 style={{ marginTop: "1rem" }}>B.3 — Paiement</h2>
      <p>
        Le règlement du lecteur est traité par le prestataire de paiement associé à la zone géographique de
        l'auteur (Stripe ou Chariow). {legalInfo.siteName} peut prélever des frais de service sur chaque
        transaction, dont le taux est indiqué dans l'espace « Paiements » du tableau de bord de l'auteur.
      </p>

      <h2 style={{ marginTop: "1rem" }}>B.4 — Litiges entre auteur et acheteur</h2>
      <p>
        {legalInfo.siteName} n'intervient pas dans la résolution des litiges entre un auteur et un acheteur
        relatifs au contenu ou à la livraison d'un livre, mais peut, à sa discrétion, suspendre une page de
        vente en cas de signalement fondé de pratique frauduleuse.
      </p>

      <h2>C. Droit applicable</h2>
      <p>Les présentes CGV sont soumises au droit {legalInfo.jurisdiction}.</p>
      <p>Pour toute question relative aux présentes CGV : {legalInfo.publisherEmail}.</p>
    </LegalLayout>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/confidentialite.js" << 'PLUME_EOF_MARKER'
import LegalLayout from "../components/LegalLayout";
import { legalInfo } from "../lib/legalInfo";

export default function Confidentialite() {
  return (
    <LegalLayout title="Politique de confidentialité" updated="14 octobre 2026">
      <h2>1. Responsable du traitement</h2>
      <p>
        Le responsable du traitement des données personnelles collectées sur {legalInfo.siteName} est{" "}
        {legalInfo.publisherName}, joignable à l'adresse {legalInfo.publisherEmail}.
      </p>

      <h2>2. Données collectées</h2>
      <p>Selon votre usage du site, nous collectons :</p>
      <ul>
        <li><strong>Pour un auteur</strong> : nom, adresse email, mot de passe (chiffré), numéro de téléphone mobile money ou identifiant Stripe Connect, zone géographique, et le contenu qu'il téléverse (livres, images de couverture).</li>
        <li><strong>Pour un lecteur / prospect</strong> : prénom, nom, adresse email, numéro WhatsApp, et pour un acheteur, l'adresse de livraison lorsqu'elle est demandée.</li>
        <li><strong>Données techniques</strong> : adresse IP et pays de connexion (utilisés notamment pour pré-remplir l'indicatif téléphonique et pour la sécurité du site).</li>
      </ul>

      <h2>3. Qui collecte ces données, et pourquoi</h2>
      <p>
        Les coordonnées d'un lecteur sont collectées par l'<strong>auteur</strong> dont il consulte la page de
        vente ou d'extrait, via les outils fournis par {legalInfo.siteName}. L'auteur est responsable de
        traitement vis-à-vis de ses propres contacts : c'est lui qui décide de leur envoyer des messages
        email ou WhatsApp via les tunnels de vente automatisés. {legalInfo.siteName} agit comme sous-traitant
        technique pour le compte de l'auteur sur ces données.
      </p>
      <p>
        {legalInfo.siteName} traite par ailleurs directement les données de ses auteurs (comptes, abonnements,
        paiements de l'abonnement) en tant que responsable de traitement.
      </p>

      <h2>4. Finalités</h2>
      <ul>
        <li>Créer et gérer le compte d'un auteur et son abonnement ;</li>
        <li>Générer les pages de vente, pages d'extrait et contenus promotionnels à l'aide de l'intelligence artificielle ;</li>
        <li>Permettre à l'auteur de contacter ses propres prospects et acheteurs (séquences email et WhatsApp) ;</li>
        <li>Traiter les paiements (abonnement de l'auteur, et achats des lecteurs) via Stripe ou Chariow ;</li>
        <li>Assurer la sécurité de la plateforme et prévenir la fraude.</li>
      </ul>

      <h2>5. Destinataires et sous-traitants</h2>
      <p>Pour fonctionner, {legalInfo.siteName} fait appel aux prestataires suivants, qui peuvent traiter tout ou partie des données décrites ci-dessus :</p>
      <ul>
        <li><strong>Vercel Inc.</strong> — hébergement du site</li>
        <li><strong>Neon Inc.</strong> — hébergement de la base de données</li>
        <li><strong>Stripe</strong> — paiements des auteurs et lecteurs en Europe</li>
        <li><strong>Chariow</strong> — paiements des auteurs et lecteurs en Afrique, et facturation de l'abonnement</li>
        <li><strong>Resend</strong> — envoi des emails transactionnels et des séquences email des auteurs</li>
        <li><strong>Meta / WhatsApp Business Platform</strong> — envoi des messages WhatsApp des auteurs à leurs contacts</li>
        <li><strong>Anthropic</strong> — génération assistée par IA des pages de vente et contenus, à partir du texte du livre fourni par l'auteur</li>
      </ul>
      <p>
        Ces données ne sont ni vendues, ni louées à des tiers à des fins publicitaires.
      </p>

      <h2>6. Transferts hors Union européenne</h2>
      <p>
        Certains de nos prestataires (hébergement, intelligence artificielle, messagerie) sont situés hors de
        l'Union européenne, notamment aux États-Unis. Ces transferts sont encadrés par les garanties prévues
        par ces prestataires (clauses contractuelles types ou mécanismes équivalents).
      </p>

      <h2>7. Durée de conservation</h2>
      <p>
        Les données d'un compte auteur sont conservées pendant toute la durée d'utilisation du service, puis
        supprimées ou anonymisées dans un délai raisonnable après la clôture du compte, sauf obligation légale
        de conservation plus longue (notamment comptable). Les données d'un lecteur sont conservées par
        l'auteur concerné tant qu'il conserve son compte, et supprimées sur demande de ce lecteur adressée à
        l'auteur ou à {legalInfo.siteName}.
      </p>

      <h2>8. Vos droits</h2>
      <p>
        Conformément à la réglementation applicable (notamment le RGPD pour les personnes situées dans l'Union
        européenne), vous disposez d'un droit d'accès, de rectification, d'effacement, de limitation, d'opposition
        et de portabilité sur vos données personnelles. Pour l'exercer :
      </p>
      <ul>
        <li>si vous êtes un <strong>auteur</strong>, directement depuis votre tableau de bord, ou en nous écrivant à {legalInfo.publisherEmail} ;</li>
        <li>si vous êtes un <strong>lecteur</strong> ayant laissé vos coordonnées sur une page de vente ou d'extrait, en contactant directement l'auteur concerné, ou {legalInfo.siteName} à {legalInfo.publisherEmail} qui relaiera votre demande.</li>
      </ul>
      <p>
        Vous disposez également du droit d'introduire une réclamation auprès de l'autorité de protection des
        données compétente dans votre pays.
      </p>

      <h2>9. Cookies et traceurs</h2>
      <p>
        {legalInfo.siteName} utilise uniquement les éléments techniques strictement nécessaires au
        fonctionnement du site (notamment le maintien de votre session de connexion). Nous n'utilisons pas de
        cookies publicitaires ni de traceurs tiers à des fins de suivi marketing.
      </p>

      <h2>10. Sécurité</h2>
      <p>
        {legalInfo.siteName} met en œuvre des mesures techniques raisonnables (chiffrement des mots de passe,
        connexions sécurisées HTTPS) pour protéger les données contre tout accès non autorisé, perte ou
        divulgation.
      </p>

      <h2>11. Contact</h2>
      <p>
        Pour toute question relative à cette politique de confidentialité ou à l'exercice de vos droits :{" "}
        {legalInfo.publisherEmail}.
      </p>
    </LegalLayout>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages"
cat > "pages/index.js" << 'PLUME_EOF_MARKER'
import Link from "next/link";
import { BookOpen, Sparkles, Upload, Wallet, ArrowRight, Check } from "lucide-react";
import { colors, BookCover } from "../components/ui";
import Footer from "../components/Footer";

function MockSalesCard() {
  return (
    <div className="relative w-full max-w-sm">
      <div
        className="absolute rounded-3xl"
        style={{
          inset: "-1.5rem",
          zIndex: -1,
          background: `linear-gradient(135deg, ${colors.gold}33, ${colors.sage}33)`,
          filter: "blur(6px)",
        }}
      />
      <div
        className="rounded-2xl p-5 transition-transform duration-500"
        style={{ backgroundColor: "#FFFFFF", boxShadow: "0 30px 60px -15px rgba(28,32,51,0.25)", transform: "rotate(2deg)" }}
      >
        <div className="flex items-center gap-3 mb-4">
          <BookCover title="Le Pouvoir du Matin" author="Aïssatou Diallo" size="sm" />
          <div className="min-w-0">
            <p className="font-display text-base leading-tight" style={{ color: colors.textPaper }}>Le Pouvoir du Matin</p>
            <p className="font-mono text-[10px] mt-1" style={{ color: colors.textMutedLight }}>votre-site.com/p/le-pouvoir-du-matin</p>
          </div>
        </div>
        <p className="font-mono text-[10px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Le problème</p>
        <p className="font-body text-xs leading-relaxed mb-3" style={{ color: colors.textPaperDim }}>
          Vous vous réveillez déjà fatigué. Vos projets les plus importants attendent depuis des semaines…
        </p>
        <div className="flex items-center justify-between pt-3 border-t" style={{ borderColor: colors.paperDim }}>
          <p className="font-body text-sm font-semibold" style={{ color: colors.textPaper }}>12 €</p>
          <span className="font-body text-xs font-semibold px-3 py-1.5 rounded-lg" style={{ backgroundColor: colors.gold, color: colors.ink }}>
            Acheter maintenant
          </span>
        </div>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen overflow-hidden">
      <nav
        className="sticky top-0 z-40 flex items-center justify-between px-5 md:px-10 py-4 max-w-6xl mx-auto"
        style={{ backdropFilter: "blur(14px)", backgroundColor: "rgba(251,249,244,0.75)", borderBottom: `1px solid ${colors.paperDim}` }}
      >
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={16} color={colors.ink} />
          </div>
          <span className="font-display text-lg" style={{ color: colors.textPaper }}>Plume</span>
        </div>
        <div className="flex items-center gap-2 sm:gap-3">
          <Link href="/connexion" className="font-body text-xs sm:text-sm whitespace-nowrap shrink-0" style={{ color: colors.textMutedLight }}>
            Se connecter
          </Link>
          <Link
            href="/inscription"
            className="font-body text-xs sm:text-sm font-semibold px-3 sm:px-4 py-2 rounded-lg whitespace-nowrap shrink-0"
            style={{ backgroundColor: colors.ink, color: colors.paper }}
          >
            <span className="sm:hidden">Commencer</span>
            <span className="hidden sm:inline">Commencer gratuitement</span>
          </Link>
        </div>
      </nav>

      <section className="relative max-w-6xl mx-auto px-5 pt-14 md:pt-20 pb-20">
        <div
          className="absolute pointer-events-none"
          style={{ top: -60, right: "5%", width: 420, height: 420, borderRadius: "50%", background: colors.gold, opacity: 0.16, filter: "blur(100px)" }}
        />
        <div
          className="absolute pointer-events-none"
          style={{ bottom: -40, left: 0, width: 380, height: 380, borderRadius: "50%", background: colors.sage, opacity: 0.16, filter: "blur(100px)" }}
        />

        <div className="relative grid lg:grid-cols-2 gap-12 items-center">
          <div>
            <span
              className="inline-flex items-center gap-2 font-mono text-[11px] uppercase tracking-widest px-3 py-1.5 rounded-full mb-6"
              style={{ backgroundColor: "#FFFFFF", color: colors.goldDark, border: `1px solid ${colors.paperDim}` }}
            >
              <Sparkles size={12} /> Génération IA en 2 minutes
            </span>
            <h1 className="font-display text-4xl md:text-5xl leading-tight mb-6" style={{ color: colors.textPaper }}>
              Vous savez écrire.<br />On s’occupe de vendre.
            </h1>
            <p className="font-body text-base md:text-lg mb-8 max-w-md" style={{ color: colors.textMutedLight }}>
              Téléchargez votre livre : l’IA génère votre page de vente, votre page d’extrait et votre
              contenu réseaux. Vous encaissez, en carte bancaire ou en Mobile Money.
            </p>
            <div className="flex flex-wrap items-center gap-4">
              <Link
                href="/inscription"
                className="inline-flex items-center gap-2 font-body font-semibold px-6 py-3.5 rounded-xl"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                Créer ma page de vente <ArrowRight size={16} />
              </Link>
              <p className="font-mono text-[11px]" style={{ color: colors.textMutedLight }}>
                Essai gratuit 7 jours — sans engagement
              </p>
            </div>
          </div>

          <div className="flex justify-center lg:justify-end">
            <MockSalesCard />
          </div>
        </div>

        <div className="relative grid grid-cols-3 gap-4 mt-16 max-w-2xl">
          {[
            ["2 min", "pour publier une page", colors.goldDark],
            ["20", "posts réseaux générés / mois", colors.sageDark],
            ["2", "zones de paiement couvertes", colors.sky],
          ].map(([n, l, c]) => (
            <div key={l}>
              <p className="font-display text-2xl md:text-3xl" style={{ color: c }}>{n}</p>
              <p className="font-body text-xs mt-1" style={{ color: colors.textMutedLight }}>{l}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="produit" className="px-5 pb-20" style={{ backgroundColor: colors.bgLightAlt }}>
        <div className="max-w-4xl mx-auto pt-16">
          <p className="font-mono text-[11px] uppercase tracking-widest mb-2 text-center" style={{ color: colors.goldDark }}>
            Comment ça marche
          </p>
          <h2 className="font-display text-2xl md:text-3xl text-center mb-12" style={{ color: colors.textPaper }}>
            Trois étapes, zéro compétence marketing
          </h2>
          <div className="grid sm:grid-cols-3 gap-6">
            {[
              { icon: Upload, title: "Téléchargez", text: "Votre manuscrit, en PDF ou EPUB.", accent: colors.gold, accentBg: "#FBF0DC" },
              { icon: Sparkles, title: "L’IA rédige", text: "Page de vente, page d’extrait, posts réseaux.", accent: colors.sageDark, accentBg: "#E4EEE8" },
              { icon: Wallet, title: "Vous encaissez", text: "Carte bancaire ou Mobile Money, automatiquement.", accent: colors.sky, accentBg: "#E6EDF5" },
            ].map((s, i) => (
              <div key={s.title} className="rounded-2xl p-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
                <div className="w-11 h-11 rounded-full flex items-center justify-center mb-4" style={{ backgroundColor: s.accentBg }}>
                  <s.icon size={18} color={s.accent} />
                </div>
                <p className="font-mono text-[10px] mb-1" style={{ color: colors.textMutedLight }}>Étape {i + 1}</p>
                <p className="font-display text-lg mb-1" style={{ color: colors.textPaper }}>{s.title}</p>
                <p className="font-body text-sm" style={{ color: colors.textMutedLight }}>{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="tarifs" className="max-w-3xl mx-auto px-5 pb-24 pt-20">
        <p className="font-mono text-[11px] uppercase tracking-widest mb-2 text-center" style={{ color: colors.goldDark }}>Tarifs</p>
        <h2 className="font-display text-2xl md:text-3xl text-center mb-10" style={{ color: colors.textPaper }}>
          Un prix simple, deux zones
        </h2>
        <div className="grid sm:grid-cols-2 gap-5">
          {[
            { zone: "Afrique francophone", price: "3 900 FCFA", pay: "Mobile Money", accent: colors.gold },
            { zone: "France / Europe", price: "5,99 €", pay: "Carte bancaire", accent: colors.sky },
          ].map((p) => (
            <div key={p.zone} className="rounded-2xl overflow-hidden" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
              <div style={{ height: 5, backgroundColor: p.accent }} />
              <div className="p-7">
                <p className="font-mono text-[11px] uppercase tracking-wide mb-3" style={{ color: colors.textMutedLight }}>{p.zone}</p>
                <p className="font-display text-3xl mb-1" style={{ color: colors.textPaper }}>
                  {p.price}<span className="font-body text-sm" style={{ color: colors.textMutedLight }}> / mois</span>
                </p>
                <p className="font-body text-xs mb-5" style={{ color: colors.textMutedLight }}>Paiement {p.pay}</p>
                <div className="flex flex-col gap-2">
                  {["Pages de vente illimitées", "20 contenus réseaux / mois", "Essai gratuit 7 jours"].map((f) => (
                    <div key={f} className="flex items-center gap-2">
                      <Check size={13} color={colors.sageDark} />
                      <p className="font-body text-xs" style={{ color: colors.textPaper }}>{f}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <Footer />
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages/p"
cat > "pages/p/[slug].js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Smartphone, CreditCard, Loader2, Truck } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import PublicFooter from "../../components/PublicFooter";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

export async function getServerSideProps({ params, req }) {
  const salesPage = await prisma.salesPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!salesPage || !salesPage.published) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: salesPage.book.title,
        coverImageUrl: salesPage.book.coverImageUrl || "",
        authorName: salesPage.book.author.name,
        problem: salesPage.problem,
        why: salesPage.why,
        solution: salesPage.solution,
        priceCents: salesPage.priceCents,
        currency: salesPage.currency,
        region: salesPage.book.author.region,
        slug: salesPage.slug,
        turnstileSiteKey: process.env.TURNSTILE_SITE_KEY || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicSalesPage({ page }) {
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    buyerName: "",
    buyerEmail: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    shippingAddress: "",
    shippingCity: "",
    shippingPostalCode: "",
    shippingCountry: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  const currencyLabel = page.currency === "EUR" ? "€" : page.currency;
  const priceLabel = page.currency === "EUR"
    ? (page.priceCents / 100).toFixed(2)
    : Math.round(page.priceCents / 100).toLocaleString("fr-FR");

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.buyerName || !form.buyerEmail || !form.whatsappNumber || !form.shippingAddress || !form.shippingCity || !form.shippingPostalCode || !form.shippingCountry) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/checkout/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          buyerName: form.buyerName,
          buyerEmail: form.buyerEmail,
          buyerWhatsapp: `${form.countryCode}${form.whatsappNumber}`,
          shippingAddress: form.shippingAddress,
          shippingCity: form.shippingCity,
          shippingPostalCode: form.shippingPostalCode,
          shippingCountry: form.shippingCountry,
          website: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error("Paiement indisponible pour le moment. Réessayez dans un instant.");
      }
    } catch (err) {
      setError(err.message);
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`${page.title} — ${page.authorName}`}</title>
        <meta name="description" content={page.problem?.slice(0, 150)} />
      </Head>

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-3xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-3xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Livre de {page.authorName}
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
          </div>
        </div>

        <div className="rounded-2xl p-6 md:p-10 space-y-6" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Le problème</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.problem}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.why}</p>
          </section>
          <section>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>La solution</p>
            <p className="font-body text-[15px] leading-relaxed" style={{ color: colors.textPaperDim }}>{page.solution}</p>
          </section>
        </div>

        <div className="sticky bottom-4 mt-6 rounded-2xl p-5 flex flex-col sm:flex-row items-center justify-between gap-4" style={{ backgroundColor: colors.ink, boxShadow: "0 20px 40px -12px rgba(28,32,51,0.4)" }}>
          <div className="flex items-center gap-3">
            <p className="font-display text-2xl" style={{ color: colors.paper }}>
              {priceLabel} {currencyLabel}
            </p>
            <div className="flex items-center gap-1.5 font-mono text-[10px]" style={{ color: colors.mist }}>
              {page.region === "EUROPE" ? <CreditCard size={13} /> : <Smartphone size={13} />}
              {page.region === "EUROPE" ? "Carte bancaire" : "Mobile Money"}
            </div>
          </div>
          {!showForm && (
            <button
              onClick={() => setShowForm(true)}
              className="w-full sm:w-auto px-6 py-3 rounded-xl font-body font-semibold text-sm"
              style={{ backgroundColor: colors.gold, color: colors.ink }}
            >
              Acheter maintenant
            </button>
          )}
        </div>

        {showForm && (
          <form onSubmit={handleSubmit} className="mt-6 rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Truck size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Vos coordonnées de livraison</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Ce livre est un exemplaire papier, expédié directement par {page.authorName}.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
                neutre pour éviter que Chrome ne le remplisse automatiquement
                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
            <input
              type="text"
              name="hp"
              id="hp-field-p"
              value={form.hp}
              onChange={(e) => update("hp", e.target.value)}
              autoComplete="off"
              tabIndex={-1}
              className="absolute opacity-0 pointer-events-none -z-10"
              style={{ left: -9999, width: 1, height: 1 }}
              aria-hidden="true"
            />

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Nom complet"
                value={form.buyerName} onChange={(e) => update("buyerName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="email" required placeholder="Email"
                value={form.buyerEmail} onChange={(e) => update("buyerEmail", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <div className="flex gap-2">
              <select
                value={form.countryCode} onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm shrink-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none", maxWidth: 150 }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.code} value={c.code}>{c.label}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber} onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full min-w-0"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="text" required placeholder="Adresse (rue, quartier...)"
              value={form.shippingAddress} onChange={(e) => update("shippingAddress", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="grid sm:grid-cols-3 gap-4">
              <input
                type="text" required placeholder="Ville"
                value={form.shippingCity} onChange={(e) => update("shippingCity", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Code postal"
                value={form.shippingPostalCode} onChange={(e) => update("shippingPostalCode", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" required placeholder="Pays"
                value={form.shippingCountry} onChange={(e) => update("shippingCountry", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? "Redirection vers le paiement…" : `Payer ${priceLabel} ${currencyLabel}`}
            </button>
          </form>
        )}
      </main>
      <PublicFooter />
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages/e"
cat > "pages/e/[slug].js" << 'PLUME_EOF_MARKER'
import { useState } from "react";
import Head from "next/head";
import Link from "next/link";
import { BookOpen, Download, Loader2, Mail } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover, ErrorBanner } from "../../components/ui";
import PublicFooter from "../../components/PublicFooter";
import { COUNTRY_CODES, getVisitorCountryCode } from "../../lib/countryCodes";

function getEmbedUrl(url) {
  if (!url) return null;
  try {
    const u = new URL(url);
    if (u.hostname.includes("youtu.be")) {
      return `https://www.youtube.com/embed/${u.pathname.slice(1)}`;
    }
    if (u.hostname.includes("youtube.com")) {
      const id = u.searchParams.get("v");
      if (id) return `https://www.youtube.com/embed/${id}`;
      if (u.pathname.startsWith("/embed/")) return url;
    }
    if (u.hostname.includes("vimeo.com")) {
      const id = u.pathname.split("/").filter(Boolean)[0];
      if (id) return `https://player.vimeo.com/video/${id}`;
    }
  } catch {
    return null;
  }
  return null;
}

export async function getServerSideProps({ params, req }) {
  const extractPage = await prisma.extractPage.findUnique({
    where: { slug: params.slug },
    include: { book: { include: { author: true } } },
  });

  if (!extractPage) {
    return { notFound: true };
  }

  return {
    props: {
      page: {
        title: extractPage.book.title,
        coverImageUrl: extractPage.book.coverImageUrl || "",
        authorName: extractPage.book.author.name,
        slug: extractPage.slug,
        embedUrl: getEmbedUrl(extractPage.videoUrl) || "",
        defaultCountryCode: getVisitorCountryCode(req),
      },
    },
  };
}

export default function PublicExtractPage({ page }) {
  const [submitted, setSubmitted] = useState(false);
  const [pdfUrl, setPdfUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    email: "",
    countryCode: page.defaultCountryCode || "+225",
    whatsappNumber: "",
    hp: "", // honeypot — jamais rempli par un humain
  });

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.firstName || !form.email || !form.whatsappNumber) {
      setError("Merci de remplir tous les champs.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/leads/capture", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          slug: page.slug,
          firstName: form.firstName,
          lastName: form.lastName,
          email: form.email,
          whatsapp: `${form.countryCode}${form.whatsappNumber}`,
          website: form.hp,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Une erreur est survenue.");
      setPdfUrl(data.pdfUrl || "");
      setSubmitted(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div style={{ backgroundColor: colors.bgLight }} className="min-h-screen">
      <Head>
        <title>{`Extrait gratuit — ${page.title}`}</title>
        <meta name="description" content={`Recevez gratuitement un extrait de "${page.title}" par ${page.authorName}.`} />
      </Head>

      <nav className="flex items-center px-5 md:px-10 py-4 max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
      </nav>

      <main className="max-w-2xl mx-auto px-5 pb-24">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 py-8 text-center sm:text-left">
          <BookCover title={page.title} author={page.authorName} imageUrl={page.coverImageUrl} />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>
              Extrait gratuit
            </p>
            <h1 className="font-display text-3xl md:text-4xl leading-tight" style={{ color: colors.textPaper }}>
              {page.title}
            </h1>
            <p className="font-body text-sm mt-2" style={{ color: colors.textPaperDim }}>
              Par {page.authorName}
            </p>
          </div>
        </div>

        {page.embedUrl && (
          <div className="rounded-2xl overflow-hidden mb-6" style={{ boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div style={{ position: "relative", paddingTop: "56.25%" }}>
              <iframe
                src={page.embedUrl}
                title={page.title}
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                style={{ position: "absolute", top: 0, left: 0, width: "100%", height: "100%", border: 0 }}
              />
            </div>
          </div>
        )}

        {!submitted ? (
          <form onSubmit={handleSubmit} className="rounded-2xl p-6 md:p-8 space-y-5" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="flex items-center gap-2">
              <Mail size={16} color={colors.goldDark} />
              <h2 className="font-display text-xl" style={{ color: colors.textPaper }}>Recevez l’extrait gratuitement</h2>
            </div>
            <p className="font-body text-xs" style={{ color: colors.textMutedLight }}>
              Laissez vos coordonnées, l’extrait vous sera envoyé par email.
            </p>

            <ErrorBanner message={error} />

            {/* Honeypot anti-bot — invisible pour un humain. Nom volontairement
                neutre pour éviter que Chrome ne le remplisse automatiquement
                avec une adresse enregistrée (ce qui arrivait avec name="website"). */}
            <input
              type="text"
              name="hp"
              id="hp-field-e"
              value={form.hp}
              onChange={(e) => update("hp", e.target.value)}
              autoComplete="off"
              tabIndex={-1}
              className="absolute opacity-0 pointer-events-none -z-10"
              style={{ left: -9999, width: 1, height: 1 }}
              aria-hidden="true"
            />

            <div className="grid sm:grid-cols-2 gap-4">
              <input
                type="text" required placeholder="Prénom"
                value={form.firstName} onChange={(e) => update("firstName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
              <input
                type="text" placeholder="Nom"
                value={form.lastName} onChange={(e) => update("lastName", e.target.value)}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <input
              type="email" required placeholder="Email"
              value={form.email} onChange={(e) => update("email", e.target.value)}
              className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />

            <div className="flex gap-2">
              <select
                value={form.countryCode}
                onChange={(e) => update("countryCode", e.target.value)}
                className="rounded-lg px-2 py-2.5 font-body text-sm"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              >
                {COUNTRY_CODES.map((c) => (
                  <option key={c.iso} value={c.code}>{c.code}</option>
                ))}
              </select>
              <input
                type="tel" required placeholder="Numéro WhatsApp"
                value={form.whatsappNumber}
                onChange={(e) => update("whatsappNumber", e.target.value.replace(/[^0-9]/g, ""))}
                className="rounded-lg px-3 py-2.5 font-body text-sm w-full"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3.5 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
              style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
            >
              {submitting && <Loader2 size={16} className="animate-spin" />}
              {submitting ? "Envoi…" : "Recevoir l’extrait"}
            </button>
          </form>
        ) : (
          <div className="rounded-2xl p-6 md:p-8 text-center" style={{ backgroundColor: "#FFFFFF", boxShadow: "0 8px 24px -12px rgba(28,32,51,0.12)" }}>
            <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: "rgba(79,122,92,0.15)" }}>
              <Mail size={20} color={colors.forest} />
            </div>
            <h2 className="font-display text-xl mb-2" style={{ color: colors.textPaper }}>Merci !</h2>
            <p className="font-body text-sm mb-4" style={{ color: colors.textPaperDim }}>
              Votre extrait vous a été envoyé par email{pdfUrl ? " et est disponible en téléchargement direct ci-dessous." : "."}
            </p>
            {pdfUrl && (
              <a
                href={pdfUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-body font-semibold text-sm"
                style={{ backgroundColor: colors.gold, color: colors.ink }}
              >
                <Download size={16} /> Télécharger l’extrait
              </a>
            )}
          </div>
        )}
      </main>
      <PublicFooter />
    </div>
  );
}
PLUME_EOF_MARKER

mkdir -p "pages/boutique"
cat > "pages/boutique/[slug].js" << 'PLUME_EOF_MARKER'
import Head from "next/head";
import Link from "next/link";
import { BookOpen } from "lucide-react";
import { prisma } from "../../lib/db";
import { colors, BookCover } from "../../components/ui";
import PublicFooter from "../../components/PublicFooter";

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
      coverImageUrl: b.coverImageUrl || "",
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
                <BookCover title={book.title} author={authorName} imageUrl={book.coverImageUrl} size="lg" />
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
      <PublicFooter />
    </div>
  );
}
PLUME_EOF_MARKER

echo "Termine."
