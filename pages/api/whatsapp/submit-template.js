import { requireAuth } from "../../../lib/auth";
import { submitWhatsAppTemplate } from "../../../lib/whatsapp";

// Déclenché depuis le bouton "Soumettre le modèle" du dashboard — soumet UNE
// FOIS le modèle générique WhatsApp à Meta pour approbation. N'importe quel
// auteur connecté peut déclencher cet appel (il n'y a qu'un compte WhatsApp
// Business Plume, partagé par la plateforme — les identifiants viennent des
// variables Vercel, pas d'un compte par auteur).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  try {
    const result = await submitWhatsAppTemplate();
    if (!result.ok) return res.status(400).json({ error: result.error });
    return res.status(200).json(result);
  } catch (error) {
    console.error("Erreur /api/whatsapp/submit-template :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
