#!/bin/bash
set -e
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
  publisherName: "Ludovic Biaka",
  publisherStatus: "entrepreneur individuel",
  publisherRegistration: "",
  publisherAddress: "Cotonou, Bénin",
  publisherEmail: "plumeeditor@gmail.com",
  publisherPhone: "", // optionnel — laissez vide pour ne pas l'afficher

  // Responsable de la publication (souvent la même personne que l'éditeur)
  publicationDirector: "Ludovic Biaka",

  // Hébergeur du site (technique)
  hostingProvider: "Vercel Inc.",
  hostingProviderInfo: "Informations complètes sur vercel.com/legal",

  // Hébergeur de la base de données
  databaseProvider: "Neon Inc.",

  // Juridiction / droit applicable par défaut
  jurisdiction: "béninois",
};
PLUME_EOF_MARKER
echo "Informations légales mises à jour. Termine."
