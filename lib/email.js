// Envoi d'email transactionnel via Resend — https://resend.com
// Nécessite RESEND_API_KEY et RESEND_FROM_EMAIL (adresse expéditrice
// vérifiée dans ton compte Resend, ex. "Plume <contact@ton-domaine.com>").
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const RESEND_FROM_EMAIL = process.env.RESEND_FROM_EMAIL;

export async function sendExtractEmail({ to, bookTitle, pdfUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Votre extrait de "${bookTitle}"`,
      html: `
        <p>Merci pour votre intérêt !</p>
        <p>Voici votre extrait de <strong>${bookTitle}</strong> :</p>
        <p><a href="${pdfUrl}">Télécharger le PDF</a></p>
      `,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("Échec d'envoi Resend :", err);
    return { sent: false };
  }
  return { sent: true };
}

export async function sendPurchaseConfirmationEmail({ to, bookTitle, amountFormatted, buyerName }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: `Confirmation de votre commande — ${bookTitle}`,
      html: `
        <p>Bonjour ${buyerName || ""},</p>
        <p>Votre commande de <strong>${bookTitle}</strong> (${amountFormatted}) est confirmée.</p>
        <p>L'auteur vous contactera pour organiser la remise ou l'expédition de votre exemplaire.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

// Utilisée par les tunnels de vente automatiques et les envois ponctuels
// (broadcasts). Le corps texte est fourni par l'auteur (ou pré-rempli par
// défaut, voir lib/sequences.js) — on le transforme simplement en
// paragraphes HTML, sans template marketing imposé.
export async function sendMarketingEmail({ to, subject, textBody, replyTo }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const html = textBody
    .split("\n\n")
    .map((p) => `<p>${p.replace(/\n/g, "<br/>")}</p>`)
    .join("\n");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject,
      html,
      ...(replyTo && { reply_to: replyTo }),
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (marketing) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

export async function sendVerificationEmail({ to, verifyUrl }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to,
      subject: "Confirmez votre adresse email — Plume",
      html: `
        <p>Bienvenue sur Plume !</p>
        <p>Confirmez votre adresse email pour activer toutes les fonctionnalités de votre compte (notamment les demandes de reversement) :</p>
        <p><a href="${verifyUrl}">Confirmer mon email</a></p>
        <p>Ce lien expire dans 24h.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (vérification email) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}
