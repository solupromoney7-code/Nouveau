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
