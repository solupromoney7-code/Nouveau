import { useEffect, useState } from "react";
import { MessageCircle } from "lucide-react";
import DashboardShell from "../components/DashboardShell";
import { colors, Spinner, ErrorBanner } from "../components/ui";
import { useAuthGuard } from "../lib/useAuthGuard";
import { api } from "../lib/apiClient";

export default function DashboardContacts() {
  const { author, loading: authLoading } = useAuthGuard();
  const [tab, setTab] = useState("acheteurs");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

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
            {["acheteurs", "extrait"].map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className="px-4 py-1.5 rounded-full font-body text-xs font-semibold capitalize"
                style={{
                  backgroundColor: tab === t ? colors.gold : colors.paperDim,
                  color: tab === t ? colors.ink : colors.textPaperDim,
                }}
              >
                {t === "acheteurs" ? "Acheteurs" : "Extrait du livre"}
              </button>
            ))}
          </div>

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
                              href={`https://wa.me/${digits}`}
                              target="_blank"
                              rel="noreferrer"
                              className="inline-flex items-center gap-1.5 px-2 py-1 rounded-lg"
                              style={{ backgroundColor: "rgba(79,122,92,0.12)", color: colors.forest }}
                            >
                              <MessageCircle size={13} /> {r.whatsapp}
                            </a>
                          ) : "—"}
                        </td>
                        <td className="py-2.5 pr-4 whitespace-nowrap" style={{ color: colors.textPaperDim }}>{r.email}</td>
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
