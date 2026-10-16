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
