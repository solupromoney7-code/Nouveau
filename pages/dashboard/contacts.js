import { useEffect, useState } from "react";
import { MessageCircle, Mail, Send, Check, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner, ErrorBanner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const LIST_SOURCE = { acheteurs: "acheteur", extrait: "extrait", tous: "tous" };
const TAB_LABEL = { acheteurs: "Acheteurs", extrait: "Extrait du livre", tous: "Tous" };

function fillTemplate(text, vars) {
  return String(text || "").replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? "");
}

export default function DashboardContacts() {
  const { author, loading: authLoading } = useAuthGuard();
  const [tab, setTab] = useState("acheteurs");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [mode, setMode] = useState(null); // null | "email" | "whatsapp"
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("Bonjour {{prenom}},\n\n");
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null);
  const [waSent, setWaSent] = useState({});

  async function sendEmail() {
    setError("");
    setResult(null);
    if (!subject.trim() || !message.trim()) {
      setError("Renseignez l’objet et le message.");
      return;
    }
    if (!window.confirm(`Envoyer cet email à ${rows.filter((r) => !r.unsubscribed).length} contact(s) (${TAB_LABEL[tab]}) ?`)) return;
    setSending(true);
    try {
      const data = await api("/api/broadcasts", {
        method: "POST",
        body: { listSource: LIST_SOURCE[tab], subject, body: message },
      });
      setResult(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setSending(false);
    }
  }

  function waLink(r) {
    const digits = (r.whatsapp || "").replace(/[^0-9]/g, "");
    const text = fillTemplate(message, { prenom: r.firstName, auteur: author?.name });
    return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
  }

  useEffect(() => {
    if (!author) return;
    setLoading(true);
    api(`/api/contacts?source=${tab}`)
      .then(setRows)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author, tab]);

  return (
    <DashboardShell active="contacts" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>CRM</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Contacts</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-4 md:p-6 max-w-3xl" style={{ backgroundColor: colors.paper }}>
          <div className="flex gap-2 mb-4">
            {["acheteurs", "extrait", "tous"].map((t) => (
              <button
                key={t}
                onClick={() => { setTab(t); setResult(null); setWaSent({}); }}
                className="px-4 py-1.5 rounded-full font-body text-xs font-semibold capitalize"
                style={{
                  backgroundColor: tab === t ? colors.gold : colors.paperDim,
                  color: tab === t ? colors.ink : colors.textPaperDim,
                }}
              >
                {TAB_LABEL[t]}
              </button>
            ))}
          </div>

          <div className="flex flex-wrap gap-2 mb-4">
            <button
              onClick={() => { setMode(mode === "email" ? null : "email"); setResult(null); setError(""); }}
              className="flex items-center gap-2 px-3 py-2 rounded-lg font-body text-xs font-semibold"
              style={{ backgroundColor: mode === "email" ? colors.gold : colors.paperDim, color: mode === "email" ? colors.ink : colors.textPaper }}
            >
              <Mail size={14} /> Écrire à ma liste par email
            </button>
            <button
              onClick={() => { setMode(mode === "whatsapp" ? null : "whatsapp"); setResult(null); setError(""); }}
              className="flex items-center gap-2 px-3 py-2 rounded-lg font-body text-xs font-semibold"
              style={{ backgroundColor: mode === "whatsapp" ? colors.gold : colors.paperDim, color: mode === "whatsapp" ? colors.ink : colors.textPaper }}
            >
              <MessageCircle size={14} /> Écrire à ma liste sur WhatsApp
            </button>
          </div>

          {mode && (
            <div className="rounded-xl p-4 mb-4 space-y-3" style={{ backgroundColor: colors.paperDim }}>
              <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                Liste : <strong>{TAB_LABEL[tab]}</strong> ({rows.length} contact{rows.length > 1 ? "s" : ""}). Écrivez <code>{"{{prenom}}"}</code> pour insérer le prénom de chaque contact.
              </p>
              {mode === "email" && (
                <input
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="Objet de l’email"
                  className="w-full rounded-lg px-3 py-2 font-body text-sm"
                  style={{ backgroundColor: "#FFFFFF", color: colors.textPaper, border: "none" }}
                />
              )}
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                rows={6}
                placeholder="Votre message…"
                className="w-full rounded-lg px-3 py-2 font-body text-sm"
                style={{ backgroundColor: "#FFFFFF", color: colors.textPaper, border: "none" }}
              />
              {mode === "email" ? (
                <div className="flex items-center gap-3">
                  <button
                    onClick={sendEmail}
                    disabled={sending || rows.length === 0}
                    className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
                    style={{ backgroundColor: colors.gold, color: colors.ink, opacity: sending || rows.length === 0 ? 0.6 : 1 }}
                  >
                    {sending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                    {sending ? "Envoi…" : "Envoyer à toute la liste"}
                  </button>
                  {result && (
                    <span className="flex items-center gap-1 font-body text-xs" style={{ color: result.status === "failed" ? "#B3261E" : colors.forest }}>
                      <Check size={13} />
                      {result.status === "failed"
                        ? `Envoi à ${result.recipients} contact(s) : certains emails n’ont pas pu partir.`
                        : `Envoyé à ${result.recipients} contact(s).`}
                    </span>
                  )}
                </div>
              ) : (
                <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                  Cliquez sur « Envoyer » à côté de chaque contact : WhatsApp s’ouvre avec votre message déjà écrit. Vous n’avez plus qu’à valider l’envoi.
                  {Object.keys(waSent).length > 0 && ` ${Object.keys(waSent).length}/${rows.length} ouvert(s).`}
                </p>
              )}
            </div>
          )}

          <ErrorBanner message={error} />

          {loading ? (
            <div className="py-8 flex justify-center"><Spinner color={colors.goldDark} /></div>
          ) : rows.length === 0 ? (
            <p className="font-body text-sm py-8 text-center" style={{ color: colors.textPaperDim }}>
              Aucun contact pour l’instant dans cette liste.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead>
                  <tr className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.mist }}>
                    <th className="pb-2 pr-4">Nom</th>
                    <th className="pb-2 pr-4">WhatsApp</th>
                    <th className="pb-2 pr-4">Email</th>
                    <th className="pb-2">Date</th>
                  </tr>
                </thead>
                <tbody className="font-body text-sm" style={{ color: colors.textPaper }}>
                  {rows.map((r) => {
                    const digits = (r.whatsapp || "").replace(/[^0-9]/g, "");
                    return (
                      <tr key={r.id} className="border-t" style={{ borderColor: colors.paperDim }}>
                        <td className="py-2.5 pr-4 whitespace-nowrap">{r.firstName} {r.lastName}</td>
                        <td className="py-2.5 pr-4 whitespace-nowrap">
                          {digits ? (
                            <a
                              href={mode === "whatsapp" ? waLink(r) : `https://wa.me/${digits}`}
                              target="_blank"
                              rel="noreferrer"
                              onClick={() => mode === "whatsapp" && setWaSent((s) => ({ ...s, [r.id]: true }))}
                              className="inline-flex items-center gap-1.5 px-2 py-1 rounded-lg"
                              style={{ backgroundColor: "rgba(79,122,92,0.12)", color: colors.forest }}
                            >
                              <MessageCircle size={13} /> {mode === "whatsapp" ? (waSent[r.id] ? "Ouvert ✓" : "Envoyer") : r.whatsapp}
                            </a>
                          ) : "—"}
                        </td>
                        <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
                          {r.email}{r.unsubscribed && <span className="ml-2 font-mono text-[10px] uppercase" style={{ color: colors.wine }}>désinscrit</span>}
                        </td>
                        <td className="py-2.5 whitespace-nowrap" style={{ color: colors.textPaperDim }}>
                          {new Date(r.createdAt).toLocaleDateString("fr-FR")}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
