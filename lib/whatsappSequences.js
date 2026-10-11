// Tunnels WhatsApp par défaut — même logique que lib/sequences.js (email),
// adaptée au ton plus court et direct de WhatsApp. Chaque auteur reçoit ces
// deux séquences automatiquement, modifiables ensuite dans son dashboard
// (PATCH /api/whatsapp-sequences/steps/[id]).
//
// Variables disponibles dans le texte, remplacées à l'envoi (voir
// renderTemplate, réutilisé depuis lib/sequences.js) :
// {{prenom}}, {{titre}}, {{auteur}}, {{lien_achat}}, {{lien_boutique}}

export const DEFAULT_WHATSAPP_SEQUENCES = {
  extrait: {
    name: "Tunnel WhatsApp — Lecteurs de l’extrait",
    steps: [
      {
        order: 1,
        delayDays: 1,
        body: "Bonjour {{prenom}} 👋 J’espère que l’extrait de « {{titre}} » vous a plu ! Le livre complet est disponible ici : {{lien_achat}}",
      },
      {
        order: 2,
        delayDays: 3,
        body: "Bonjour {{prenom}}, sans trop en dire : la suite de « {{titre}} » va encore plus loin que l’extrait. Beaucoup de lecteurs me disent que c’est là que tout prend son sens 📖 {{lien_achat}}",
      },
      {
        order: 3,
        delayDays: 5,
        body: "Bonjour {{prenom}}, je voulais partager pourquoi j’ai écrit « {{titre}} » : [racontez ici votre histoire en une ou deux phrases]. Si ça vous parle : {{lien_achat}}",
      },
      {
        order: 4,
        delayDays: 7,
        body: "Bonjour {{prenom}}, si vous hésitez encore sur « {{titre}} » : [répondez ici à l’objection la plus fréquente, ex. « ça se lit en un week-end »]. {{lien_achat}}",
      },
      {
        order: 5,
        delayDays: 9,
        body: "Bonjour {{prenom}}, [ajoutez ici un témoignage court d’un lecteur]. Si vous voulez vivre la même expérience : {{lien_achat}}",
      },
      {
        order: 6,
        delayDays: 12,
        body: "Bonjour {{prenom}}, on remet souvent la lecture à plus tard — et « plus tard » n’arrive jamais vraiment 😉 Le bon moment pour « {{titre}} », c’est maintenant : {{lien_achat}}",
      },
      {
        order: 7,
        delayDays: 15,
        body: "Bonjour {{prenom}}, dernier message à ce sujet, promis 🙂 « {{titre}} » reste disponible ici si vous changez d’avis : {{lien_achat}} Merci de m’avoir lu(e) jusqu’ici.",
      },
    ],
  },

  acheteur: {
    name: "Tunnel WhatsApp — Lecteurs qui ont acheté",
    steps: [
      {
        order: 1,
        delayDays: 2,
        body: "Bonjour {{prenom}}, merci encore pour votre achat de « {{titre}} » ! Comment se passe la lecture ? N’hésitez pas à me répondre ici si besoin 🙂",
      },
      {
        order: 2,
        delayDays: 5,
        body: "Bonjour {{prenom}}, maintenant que vous avancez dans « {{titre}} », je voulais partager [une réflexion ou un petit bonus lié au livre]. J’espère que ça enrichira votre lecture !",
      },
      {
        order: 3,
        delayDays: 7,
        body: "Bonjour {{prenom}}, si « {{titre}} » vous plaît, un avis de votre part m’aiderait énormément à toucher d’autres lecteurs 🙏 Merci d’avance !",
      },
      {
        order: 4,
        delayDays: 10,
        body: "Bonjour {{prenom}}, la question qu’on me pose le plus sur « {{titre}} » : [ajoutez ici la question et votre réponse].",
      },
      {
        order: 5,
        delayDays: 14,
        body: "Bonjour {{prenom}}, si vous voulez suivre mes prochains projets : [ajoutez ici votre lien réseaux sociaux ou communauté]. À bientôt !",
      },
      {
        order: 6,
        delayDays: 21,
        body: "Bonjour {{prenom}}, si « {{titre}} » vous a marqué(e), le plus beau cadeau que vous puissiez me faire c’est d’en parler autour de vous 💛 Merci du fond du cœur !",
      },
      {
        order: 7,
        delayDays: 30,
        body: "Bonjour {{prenom}}, j’espère que « {{titre}} » vous a plu du début à la fin. Pour découvrir mes autres livres : {{lien_boutique}} Merci de votre confiance !",
      },
    ],
  },
};
