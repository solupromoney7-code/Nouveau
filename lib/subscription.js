// Statut d'abonnement partagé — utilisé partout où une fonctionnalité doit
// être réservée aux comptes payants ou en essai actif (génération de
// contenu réseaux, tunnels de vente, broadcasts). Centralisé ici pour que
// la définition d'"abonnement actif" ne diverge jamais d'un endroit à l'autre.
export function isSubscriptionActive(author) {
  const trialActive = author.subscriptionStatus === "TRIALING" && author.trialEndsAt && author.trialEndsAt > new Date();
  return author.subscriptionStatus === "ACTIVE" || trialActive;
}
