// Envoi d'email transactionnel via Resend — https://resend.com
// Nécessite RESEND_API_KEY et RESEND_FROM_EMAIL (adresse expéditrice
// vérifiée dans ton compte Resend, ex. "Plume <contact@ton-domaine.com>").
import { unsubscribeUrl } from "./unsubscribe";

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
export async function sendMarketingEmail({ to, subject, textBody, replyTo, leadId }) {
  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.warn("RESEND_API_KEY/RESEND_FROM_EMAIL manquants — email non envoyé (à configurer).");
    return { sent: false };
  }

  let html = textBody
    .split("\n\n")
    .map((p) => `<p>${p.replace(/\n/g, "<br/>")}</p>`)
    .join("\n");

  // Lien de désinscription (obligatoire pour les emails marketing).
  const unsubUrl = leadId ? unsubscribeUrl(leadId) : null;
  if (unsubUrl) {
    html += `\n<p style="font-size:12px;color:#888">Vous ne souhaitez plus recevoir ces emails ? <a href="${unsubUrl}">Se désinscrire</a></p>`;
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
      subject,
      html,
      ...(replyTo && { reply_to: replyTo }),
      ...(unsubUrl && {
        headers: {
          "List-Unsubscribe": `<${unsubUrl.replace("/desinscription?", "/api/public/unsubscribe?")}>`,
          "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        },
      }),
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

export async function sendPasswordResetEmail({ to, resetUrl }) {
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
      subject: "Réinitialisation de votre mot de passe — Plume",
      html: `
        <p>Bonjour,</p>
        <p>Vous avez demandé à réinitialiser votre mot de passe sur Plume. Cliquez sur le lien ci-dessous pour en choisir un nouveau :</p>
        <p><a href="${resetUrl}">Choisir un nouveau mot de passe</a></p>
        <p>Ce lien expire dans 1 heure et ne peut être utilisé qu'une seule fois.</p>
        <p>Si vous n'êtes pas à l'origine de cette demande, ignorez simplement cet email : votre mot de passe actuel reste inchangé.</p>
      `,
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi Resend (réinitialisation mot de passe) :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}
