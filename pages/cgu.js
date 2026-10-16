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
