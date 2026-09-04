// Tunnels de vente par défaut — pré-rédigés pour des auteurs qui ne
// connaissent pas le marketing. Chaque auteur reçoit ces deux séquences
// automatiquement ; il peut ensuite modifier le sujet/texte de chaque étape
// depuis son dashboard (PATCH /api/sequences/steps/[id]), sans jamais avoir
// à partir d'une page blanche.
//
// Structure pensée en 7 étapes pour chaque tunnel (voir la logique en
// commentaire au-dessus de chaque séquence) — quelques étapes contiennent
// un texte entre crochets [...] que l'auteur doit personnaliser (son
// histoire, un vrai témoignage...) car c'est ce qui convertit le mieux ;
// tout le reste est prêt à l'emploi.
//
// Variables disponibles dans subject/body, remplacées à l'envoi (voir
// renderTemplate) : {{prenom}}, {{titre}}, {{auteur}}, {{lien_achat}}, {{lien_boutique}}

export const DEFAULT_SEQUENCES = {
  // Tunnel de CONVERSION — fait passer un lecteur de l'extrait à l'achat.
  // Structure éprouvée en marketing par email : relance → mise en appétit →
  // histoire/connexion → objection → preuve sociale → urgence douce → dernier mot.
  extrait: {
    name: "Tunnel — Lecteurs de l’extrait",
    steps: [
      {
        order: 1,
        delayDays: 1,
        subject: "Avez-vous eu le temps de lire l’extrait ?",
        body: "Bonjour {{prenom}},\n\nJ’espère que l’extrait de « {{titre}} » vous a plu !\n\nSi les premières pages vous ont donné envie d’aller plus loin, le livre complet est disponible ici :\n{{lien_achat}}\n\nÀ bientôt,\n{{auteur}}",
      },
      {
        order: 2,
        delayDays: 3,
        subject: "Ce que vous allez découvrir dans la suite",
        body: "Bonjour {{prenom}},\n\nSans trop en dévoiler, la suite de « {{titre}} » approfondit exactement ce que vous avez commencé à lire dans l’extrait.\n\nDe nombreux lecteurs me disent que c’est là que tout prend son sens.\n\nVous pouvez vous procurer votre exemplaire ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 3,
        delayDays: 5,
        subject: "Pourquoi j’ai écrit « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nJe voulais vous partager quelque chose de plus personnel : pourquoi j’ai décidé d’écrire « {{titre}} ».\n\n[Racontez ici votre histoire, ce qui vous a poussé(e) à écrire ce livre — c’est souvent ce qui donne le plus envie d’acheter.]\n\nSi cette histoire vous parle, le livre est disponible ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 4,
        delayDays: 7,
        subject: "Si vous hésitez encore…",
        body: "Bonjour {{prenom}},\n\nSi vous n’avez pas encore pris « {{titre}} », c’est peut-être parce que vous vous demandez si c’est vraiment pour vous, ou si vous aurez le temps de le lire.\n\nRassurez-vous : [ajoutez ici une réponse courte à l’objection la plus fréquente que vous entendez — ex. « le livre se lit en un week-end » ou « chaque chapitre se lit indépendamment »].\n\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 5,
        delayDays: 9,
        subject: "Ce que d’autres lecteurs en disent",
        body: "Bonjour {{prenom}},\n\n[Ajoutez ici un retour ou un témoignage court d’un lecteur — même une seule phrase marquante suffit.]\n\nSi vous voulez vivre la même expérience, « {{titre}} » est disponible ici :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 6,
        delayDays: 12,
        subject: "Pourquoi ne pas attendre pour lire « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nOn remet souvent la lecture à plus tard — et « plus tard » n’arrive jamais vraiment.\n\nSi « {{titre}} » vous a intéressé(e), le meilleur moment pour commencer, c’est maintenant :\n{{lien_achat}}\n\n{{auteur}}",
      },
      {
        order: 7,
        delayDays: 15,
        subject: "Dernier mot avant de vous laisser tranquille",
        body: "Bonjour {{prenom}},\n\nJe ne vous enverrai plus beaucoup de messages à ce sujet — juste un dernier mot.\n\nSi « {{titre}} » vous a intéressé(e), le livre est toujours disponible ici :\n{{lien_achat}}\n\nMerci de m’avoir lu(e) jusqu’ici, quoi qu’il arrive.\n\n{{auteur}}",
      },
    ],
  },

  // Tunnel de FIDÉLISATION — construit la relation sur la durée (30 jours)
  // avec un lecteur qui a déjà acheté : accompagnement → valeur ajoutée →
  // avis → FAQ → communauté → bouche-à-oreille → découverte des autres livres.
  acheteur: {
    name: "Tunnel — Lecteurs qui ont acheté",
    steps: [
      {
        order: 1,
        delayDays: 2,
        subject: "Comment se passe votre lecture ?",
        body: "Bonjour {{prenom}},\n\nMerci encore pour votre achat de « {{titre}} » ! J’espère que la lecture avance bien.\n\nSi vous avez une question, répondez simplement à cet email.\n\n{{auteur}}",
      },
      {
        order: 2,
        delayDays: 5,
        subject: "Un complément à votre lecture",
        body: "Bonjour {{prenom}},\n\nMaintenant que vous avancez dans « {{titre}} », je voulais partager avec vous [une réflexion, une ressource ou un petit bonus lié au livre].\n\nJ’espère que ça enrichira votre lecture.\n\n{{auteur}}",
      },
      {
        order: 3,
        delayDays: 7,
        subject: "Un petit service, si vous avez 2 minutes",
        body: "Bonjour {{prenom}},\n\nSi « {{titre}} » vous plaît, un avis de votre part m’aiderait énormément à toucher d’autres lecteurs.\n\nMerci d’avance,\n{{auteur}}",
      },
      {
        order: 4,
        delayDays: 10,
        subject: "La question qu’on me pose le plus sur « {{titre}} »",
        body: "Bonjour {{prenom}},\n\nBeaucoup de lecteurs me posent la même question sur « {{titre}} » : [ajoutez ici la question et votre réponse].\n\nJ’espère que ça éclaire votre lecture.\n\n{{auteur}}",
      },
      {
        order: 5,
        delayDays: 14,
        subject: "Restons en contact",
        body: "Bonjour {{prenom}},\n\nSi vous voulez suivre mes prochains projets ou échanger avec d’autres lecteurs, [ajoutez ici votre lien réseaux sociaux ou communauté].\n\nÀ bientôt,\n{{auteur}}",
      },
      {
        order: 6,
        delayDays: 21,
        subject: "Connaissez-vous quelqu’un à qui « {{titre}} » pourrait plaire ?",
        body: "Bonjour {{prenom}},\n\nSi « {{titre}} » vous a marqué(e), le plus beau cadeau que vous puissiez me faire, c’est d’en parler autour de vous.\n\nMerci du fond du cœur si vous le faites.\n\n{{auteur}}",
      },
      {
        order: 7,
        delayDays: 30,
        subject: "Pour aller plus loin",
        body: "Bonjour {{prenom}},\n\nJ’espère que « {{titre}} » vous a plu du début à la fin.\n\nSi vous voulez continuer à me lire, retrouvez tous mes livres ici :\n{{lien_boutique}}\n\nMerci de votre confiance,\n{{auteur}}",
      },
    ],
  },
};

export function renderTemplate(template, vars) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] ?? "");
}
