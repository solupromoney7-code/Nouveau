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
