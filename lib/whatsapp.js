// Envoi WhatsApp transactionnel/marketing via l'API officielle Meta
// (WhatsApp Cloud API) — https://developers.facebook.com/docs/whatsapp
//
// Pourquoi un "modèle" (template) : WhatsApp interdit d'envoyer un message
// automatique (non déclenché par une réponse récente du contact) sans passer
// par un modèle pré-approuvé par Meta. On utilise donc UN SEUL modèle
// générique, à variable libre — "{{1}}" — approuvé une fois pour toutes
// (voir submitWhatsAppTemplate ci-dessous, déclenché depuis le dashboard).
// Tout le texte que l'auteur personnalise ensuite dans ses tunnels (comme
// pour l'email) part comme valeur de cette variable, sans jamais nécessiter
// une nouvelle approbation Meta.
//
// Nécessite WHATSAPP_ACCESS_TOKEN et WHATSAPP_PHONE_NUMBER_ID (pour
// envoyer), et en plus WHATSAPP_BUSINESS_ACCOUNT_ID (pour soumettre le
// modèle une seule fois). Sans ces variables, les envois sont simplement
// ignorés (fail-open), comme pour lib/email.js.
const ACCESS_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN;
const PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID;
const BUSINESS_ACCOUNT_ID = process.env.WHATSAPP_BUSINESS_ACCOUNT_ID;
const TEMPLATE_NAME = process.env.WHATSAPP_TEMPLATE_NAME || "plume_tunnel_fr";
const TEMPLATE_LANG = process.env.WHATSAPP_TEMPLATE_LANG || "fr";

const GRAPH_VERSION = "v21.0";

function cleanNumber(value) {
  return (value || "").replace(/[^0-9]/g, "");
}

// Meta refuse les retours à la ligne, tabulations et séries d'espaces dans la
// variable d'un modèle : on les remplace par un simple espace.
function cleanParam(text) {
  return String(text || "").replace(/\s+/g, " ").trim().slice(0, 1024);
}

export function isWhatsAppConfigured() {
  return Boolean(ACCESS_TOKEN && PHONE_NUMBER_ID);
}

// Envoie un message WhatsApp via le modèle générique approuvé, avec
// `bodyText` comme unique variable. Retourne { sent: false } silencieusement
// si WhatsApp n'est pas configuré ou si le numéro est invalide — jamais
// d'exception, pour ne jamais faire planter le cron qui traite tous les
// contacts.
export async function sendWhatsAppMessage({ to, bodyText }) {
  if (!isWhatsAppConfigured()) {
    console.warn("WHATSAPP_ACCESS_TOKEN/WHATSAPP_PHONE_NUMBER_ID manquants — message WhatsApp non envoyé (à configurer).");
    return { sent: false };
  }

  const number = cleanNumber(to);
  if (!number) return { sent: false };

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${PHONE_NUMBER_ID}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: number,
      type: "template",
      template: {
        name: TEMPLATE_NAME,
        language: { code: TEMPLATE_LANG },
        components: [
          {
            type: "body",
            parameters: [{ type: "text", text: cleanParam(bodyText) }],
          },
        ],
      },
    }),
  });

  if (!res.ok) {
    console.error("Échec d'envoi WhatsApp :", await res.text());
    return { sent: false };
  }
  return { sent: true };
}

// Soumet UNE FOIS le modèle générique à Meta pour approbation — appelé
// depuis le dashboard (bouton "Soumettre le modèle"), jamais automatiquement,
// car il ne doit être créé qu'une seule fois par compte WhatsApp Business.
// Le statut initial est toujours "PENDING" ; Meta l'approuve généralement en
// quelques minutes à 24h. Si le modèle existe déjà, Meta renvoie une erreur
// explicite que l'on remonte telle quelle (ce n'est pas un échec réel).
export async function submitWhatsAppTemplate() {
  if (!ACCESS_TOKEN || !BUSINESS_ACCOUNT_ID) {
    return { ok: false, error: "WHATSAPP_ACCESS_TOKEN ou WHATSAPP_BUSINESS_ACCOUNT_ID manquant dans les variables Vercel." };
  }

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${BUSINESS_ACCOUNT_ID}/message_templates`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: TEMPLATE_NAME,
      language: TEMPLATE_LANG,
      category: "MARKETING",
      components: [
        {
          type: "BODY",
          text: "{{1}}",
          example: { body_text: [["Bonjour ! Voici un exemple de message envoyé automatiquement par Plume."]] },
        },
      ],
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { ok: false, error: data?.error?.error_user_msg || data?.error?.message || `Erreur ${res.status}` };
  }
  return { ok: true, status: data.status || "PENDING", templateId: data.id };
}

// Vérifie le statut d'approbation du modèle auprès de Meta (APPROVED /
// PENDING / REJECTED) — utilisé par le dashboard pour afficher l'état réel
// sans que l'auteur ait à se connecter lui-même à Meta Business Manager.
export async function getWhatsAppTemplateStatus() {
  if (!ACCESS_TOKEN || !BUSINESS_ACCOUNT_ID) {
    return { configured: false };
  }

  const params = new URLSearchParams({ name: TEMPLATE_NAME });
  const res = await fetch(
    `https://graph.facebook.com/${GRAPH_VERSION}/${BUSINESS_ACCOUNT_ID}/message_templates?${params.toString()}`,
    { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } }
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { configured: true, submitted: false, error: data?.error?.message || `Erreur ${res.status}` };
  }

  const template = (data.data || []).find((t) => t.name === TEMPLATE_NAME);
  if (!template) return { configured: true, submitted: false };
  return { configured: true, submitted: true, status: template.status };
}
