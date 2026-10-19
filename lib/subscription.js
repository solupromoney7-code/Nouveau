// Statut d'abonnement partagé — utilisé partout où une fonctionnalité doit
// être réservée aux comptes payants ou en essai actif (génération de
// contenu réseaux, tunnels de vente, broadcasts). Centralisé ici pour que
// la définition d'"abonnement actif" ne diverge jamais d'un endroit à l'autre.
export function isSubscriptionActive(author) {
  if (author.lifetimeAccess) return true; // accès à vie offert par le propriétaire
  const trialActive = author.subscriptionStatus === "TRIALING" && author.trialEndsAt && author.trialEndsAt > new Date();
  // Un abonnement payé court jusqu'à currentPeriodEnd (+ 3 jours de grâce).
  const grace = 3 * 24 * 60 * 60 * 1000;
  const paidActive =
    author.subscriptionStatus === "ACTIVE" &&
    (!author.currentPeriodEnd || new Date(author.currentPeriodEnd).getTime() + grace > Date.now());
  return paidActive || trialActive;
}
