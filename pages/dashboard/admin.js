import { useEffect, useMemo, useState } from "react";
import { Download, Search, ShieldAlert, ShieldCheck, Users, Wallet, BookOpen, Mail, TrendingUp } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

// ---------- Outils d'affichage ----------

function fmtMoney(cents, currency) {
  const amount = (cents || 0) / 100;
  if (currency === "EUR") return `${amount.toFixed(2).replace(".", ",")} €`;
  return `${Math.round(amount).toLocaleString("fr-FR")} FCFA`;
}

function fmtMoneyList(rows) {
  const list = (rows || []).filter((r) => r.amountCents > 0);
  if (list.length === 0) return "—";
  return list.map((r) => fmtMoney(r.amountCents, r.currency)).join(" + ");
}

function fmtDate(d) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("fr-FR", { day: "2-digit", month: "short", year: "numeric" });
}

const SUB_LABELS = {
  TRIALING: { label: "Essai", bg: "rgba(91,127,166,0.18)", fg: "#3E5F85" },
  ACTIVE: { label: "Abonné", bg: "rgba(79,122,92,0.18)", fg: "#2F5A3D" },
  PAST_DUE: { label: "Impayé", bg: "rgba(201,162,39,0.22)", fg: "#7A5E0B" },
  CANCELED: { label: "Annulé", bg: "rgba(122,46,59,0.14)", fg: colors.wine },
};

function Badge({ bg, fg, children }) {
  return (
    <span className="inline-block font-mono text-[10px] px-2 py-0.5 rounded-full whitespace-nowrap" style={{ backgroundColor: bg, color: fg }}>
      {children}
    </span>
  );
}

function downloadCsv(filename, columns, rows) {
  const esc = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const lines = [columns.map((c) => esc(c.label)).join(";")];
  for (const r of rows) lines.push(columns.map((c) => esc(c.csv ? c.csv(r) : r[c.key])).join(";"));
  const blob = new Blob(["﻿" + lines.join("\n")], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// ---------- Tableau générique (recherche + export) ----------

function DataTable({ title, rows, columns, searchKeys, csvName, empty, extra }) {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const term = q.trim().toLowerCase();
    if (!term) return rows;
    return rows.filter((r) => searchKeys.some((k) => String(r[k] ?? "").toLowerCase().includes(term)));
  }, [rows, q, searchKeys]);

  return (
    <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
      <div className="flex flex-col sm:flex-row sm:items-center gap-3 mb-4">
        <p className="font-display text-lg flex-1" style={{ color: colors.textPaper }}>
          {title} <span className="font-mono text-xs" style={{ color: colors.textPaperDim }}>({filtered.length})</span>
        </p>
        <div className="flex items-center gap-2 rounded-lg px-3 py-2" style={{ backgroundColor: colors.paperDim }}>
          <Search size={14} color={colors.textPaperDim} />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Rechercher…"
            className="bg-transparent outline-none font-body text-sm w-40"
            style={{ color: colors.textPaper }}
          />
        </div>
        <button
          onClick={() => downloadCsv(csvName, columns, filtered)}
          className="flex items-center justify-center gap-1.5 font-body text-xs px-3 py-2 rounded-lg"
          style={{ backgroundColor: colors.gold, color: colors.ink }}
        >
          <Download size={13} /> Exporter en CSV
        </button>
      </div>

      {filtered.length === 0 ? (
        <p className="font-body text-sm text-center py-8" style={{ color: colors.textPaperDim }}>{empty}</p>
      ) : (
        <div className="overflow-x-auto -mx-1">
          <table className="w-full text-left font-body text-[13px]" style={{ color: colors.textPaper }}>
            <thead>
              <tr>
                {columns.map((c) => (
                  <th key={c.label} className="font-mono text-[10px] uppercase tracking-wide px-2 py-2 whitespace-nowrap" style={{ color: colors.textPaperDim, borderBottom: `1px solid ${colors.paperDim}` }}>
                    {c.label}
                  </th>
                ))}
                {extra && <th style={{ borderBottom: `1px solid ${colors.paperDim}` }} />}
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id} style={{ borderBottom: `1px solid ${colors.paperDim}`, opacity: r.suspended ? 0.6 : 1 }}>
                  {columns.map((c) => (
                    <td key={c.label} className="px-2 py-2.5 align-top whitespace-nowrap">
                      {c.render ? c.render(r) : r[c.key] || "—"}
                    </td>
                  ))}
                  {extra && <td className="px-2 py-2.5 align-top whitespace-nowrap text-right">{extra(r)}</td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// ---------- Vue d'ensemble ----------

function Stat({ icon: Icon, label, value, sub }) {
  return (
    <div className="rounded-2xl p-4 md:p-5" style={{ backgroundColor: colors.paper }}>
      <div className="flex items-center gap-2 mb-2">
        <Icon size={14} color={colors.goldDark} />
        <p className="font-mono text-[10px] uppercase tracking-wide" style={{ color: colors.textPaperDim }}>{label}</p>
      </div>
      <p className="font-display text-2xl leading-tight" style={{ color: colors.textPaper }}>{value}</p>
      {sub && <p className="font-body text-xs mt-1" style={{ color: colors.textPaperDim }}>{sub}</p>}
    </div>
  );
}

function Overview({ data }) {
  const a = data.authors;
  const max = Math.max(1, ...data.signupsByDay.map((d) => d.count));
  const mrr = data.subscriptionRevenueMonthly;
  const mrrText = [mrr.fcfa > 0 && `${mrr.fcfa.toLocaleString("fr-FR")} FCFA`, mrr.eur > 0 && `${mrr.eur.toFixed(2).replace(".", ",")} €`].filter(Boolean).join(" + ") || "0";
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <Stat icon={Users} label="Auteurs inscrits" value={a.total} sub={`+${a.last30} ces 30 jours`} />
        <Stat icon={ShieldCheck} label="Abonnés actifs" value={a.active} sub={`${a.trialing} en essai · ${a.pastDue} impayé · ${a.canceled} annulé`} />
        <Stat icon={TrendingUp} label="Revenu mensuel récurrent" value={mrrText} sub="Abonnements Plume actifs" />
        <Stat icon={ShieldAlert} label="Comptes suspendus" value={a.suspended} sub={`${a.lifetime} accès à vie offerts`} />
        <Stat icon={Wallet} label="Ventes de livres (total)" value={fmtMoneyList(data.sales.total)} sub={`${data.sales.total.reduce((n, s) => n + s.count, 0)} commandes payées`} />
        <Stat icon={Wallet} label="Ventes (30 jours)" value={fmtMoneyList(data.sales.last30)} sub={`${data.sales.last30.reduce((n, s) => n + s.count, 0)} commandes`} />
        <Stat icon={Mail} label="Contacts d’extrait" value={data.contacts.extract} sub={`${data.contacts.buyers} contacts acheteurs`} />
        <Stat icon={BookOpen} label="Livres" value={data.catalog.books} sub={`${data.catalog.salesPublished} en vente · ${data.catalog.extractPages} pages d’extrait`} />
      </div>

      <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
        <p className="font-display text-lg mb-4" style={{ color: colors.textPaper }}>Inscriptions d’auteurs — 30 derniers jours</p>
        <div className="flex items-end gap-1 h-28">
          {data.signupsByDay.map((d) => (
            <div key={d.date} className="flex-1 flex flex-col justify-end h-full" title={`${fmtDate(d.date)} : ${d.count}`}>
              <div style={{ height: `${(d.count / max) * 100}%`, minHeight: d.count ? 4 : 2, backgroundColor: d.count ? colors.gold : colors.paperDim, borderRadius: 3 }} />
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-2xl p-4 md:p-6" style={{ backgroundColor: colors.paper }}>
        <p className="font-display text-lg mb-3" style={{ color: colors.textPaper }}>Reversements aux auteurs</p>
        <div className="grid sm:grid-cols-3 gap-3 font-body text-sm" style={{ color: colors.textPaper }}>
          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>En attente</p>{fmtMoneyList(data.payouts.pending)}</div>
          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>Versés</p>{fmtMoneyList(data.payouts.paid)}</div>
          <div><p className="font-mono text-[10px] uppercase" style={{ color: colors.textPaperDim }}>Échoués</p>{fmtMoneyList(data.payouts.failed)}</div>
        </div>
      </div>
    </div>
  );
}

// ---------- Page ----------

const TABS = [
  { id: "overview", label: "Vue d’ensemble" },
  { id: "authors", label: "Auteurs" },
  { id: "buyers", label: "Acheteurs" },
  { id: "extract", label: "Contacts d’extrait" },
  { id: "payouts", label: "Reversements" },
];

export default function DashboardAdmin() {
  const { author, loading: authLoading } = useAuthGuard();
  const [tab, setTab] = useState("overview");
  const [data, setData] = useState({});
  const [loadingTab, setLoadingTab] = useState(false);
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState("");

  const endpoints = { overview: "/api/admin/overview", authors: "/api/admin/authors", buyers: "/api/admin/buyers", extract: "/api/admin/extract-contacts", payouts: "/api/admin/payouts" };

  async function load(which) {
    setLoadingTab(true);
    setError("");
    try {
      const res = await api(endpoints[which]);
      setData((d) => ({ ...d, [which]: res }));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingTab(false);
    }
  }

  useEffect(() => {
    if (author?.isAdmin) load(tab);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [author, tab]);

  async function toggleSuspend(a) {
    const next = !a.suspended;
    const msg = next
      ? `Suspendre le compte de ${a.name} (${a.email}) ?\n\nL’auteur ne pourra plus se connecter et ses pages publiques (vente, extrait, boutique) seront désactivées. Ses données sont conservées.`
      : `Réactiver le compte de ${a.name} ?`;
    if (!window.confirm(msg)) return;
    setBusyId(a.id);
    setError("");
    try {
      await api(`/api/admin/authors/${a.id}`, { method: "PATCH", body: { suspended: next } });
      await load("authors");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId("");
    }
  }

  async function toggleLifetime(a) {
    const next = !a.lifetimeAccess;
    const msg = next
      ? `Offrir un abonnement à vie à ${a.name} (${a.email}) ?\n\nCet auteur aura accès à toutes les fonctionnalités sans jamais payer d’abonnement.`
      : `Retirer l’accès à vie de ${a.name} ?\n\nSon abonnement redeviendra celui de son compte (essai ou abonnement payant).`;
    if (!window.confirm(msg)) return;
    setBusyId(a.id);
    setError("");
    try {
      await api(`/api/admin/authors/${a.id}`, { method: "PATCH", body: { lifetime: next } });
      await load("authors");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId("");
    }
  }

  const colsAuthors = [
    { label: "Auteur", key: "name", render: (r) => (<><span className="font-semibold">{r.name}</span><br /><span className="text-[11px]" style={{ color: colors.textPaperDim }}>{r.email}</span></>), csv: (r) => r.name },
    { label: "Email", key: "email", render: () => null, csv: (r) => r.email, hidden: true },
    { label: "Inscrit le", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
    { label: "Zone", key: "region", render: (r) => (r.region === "EUROPE" ? "Europe" : "Afrique") },
    {
      label: "Abonnement", key: "subscriptionStatus",
      render: (r) => {
        if (r.lifetimeAccess) return <Badge bg="rgba(201,162,39,0.28)" fg="#7A5E0B">À vie</Badge>;
        const s = SUB_LABELS[r.subscriptionStatus] || SUB_LABELS.TRIALING;
        return <Badge bg={s.bg} fg={s.fg}>{s.label}</Badge>;
      },
      csv: (r) => (r.lifetimeAccess ? "À vie" : (SUB_LABELS[r.subscriptionStatus] || {}).label),
    },
    { label: "Email vérifié", key: "emailVerified", render: (r) => (r.emailVerified ? "Oui" : "Non"), csv: (r) => (r.emailVerified ? "Oui" : "Non") },
    { label: "Livres", key: "books" },
    { label: "Contacts extrait", key: "extractContacts" },
    { label: "Ventes", key: "sales", render: (r) => `${r.sales.reduce((n, s) => n + s.count, 0)} · ${fmtMoneyList(r.sales)}`, csv: (r) => `${r.sales.reduce((n, s) => n + s.count, 0)} commandes — ${fmtMoneyList(r.sales)}` },
    { label: "Reversé", key: "payoutsPaid", render: (r) => fmtMoneyList(r.payoutsPaid), csv: (r) => fmtMoneyList(r.payoutsPaid) },
    { label: "À reverser", key: "payoutsPending", render: (r) => fmtMoneyList(r.payoutsPending), csv: (r) => fmtMoneyList(r.payoutsPending) },
    {
      label: "Statut", key: "suspended",
      render: (r) => (r.suspended ? <Badge bg="rgba(122,46,59,0.14)" fg={colors.wine}>Suspendu</Badge> : r.isAdmin ? <Badge bg="rgba(201,162,39,0.22)" fg="#7A5E0B">Admin</Badge> : <Badge bg="rgba(79,122,92,0.18)" fg="#2F5A3D">Actif</Badge>),
      csv: (r) => (r.suspended ? "Suspendu" : "Actif"),
    },
  ].filter((c) => !c.hidden);

  const colsBuyers = [
    { label: "Date", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
    { label: "Acheteur", key: "buyerName" },
    { label: "Email", key: "buyerEmail" },
    { label: "WhatsApp", key: "buyerWhatsapp" },
    { label: "Livre", key: "bookTitle" },
    { label: "Auteur", key: "authorName" },
    { label: "Montant", key: "amountCents", render: (r) => fmtMoney(r.amountCents, r.currency), csv: (r) => fmtMoney(r.amountCents, r.currency) },
    { label: "Statut", key: "status", render: (r) => ({ paid: "Payé", pending: "En attente", failed: "Échoué" }[r.status] || r.status), csv: (r) => r.status },
    { label: "Livraison", key: "shippingAddress", render: (r) => `${r.shippingAddress}, ${r.shippingPostalCode} ${r.shippingCity}, ${r.shippingCountry}`, csv: (r) => `${r.shippingAddress}, ${r.shippingPostalCode} ${r.shippingCity}, ${r.shippingCountry}` },
  ];

  const colsExtract = [
    { label: "Date", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
    { label: "Prénom", key: "firstName" },
    { label: "Nom", key: "lastName" },
    { label: "Email", key: "email" },
    { label: "WhatsApp", key: "whatsapp" },
    { label: "Livre", key: "bookTitle" },
    { label: "Auteur", key: "authorName" },
  ];

  const colsPayouts = [
    { label: "Demandé le", key: "createdAt", render: (r) => fmtDate(r.createdAt), csv: (r) => fmtDate(r.createdAt) },
    { label: "Auteur", key: "authorName" },
    { label: "Email", key: "authorEmail" },
    { label: "Montant", key: "amountCents", render: (r) => fmtMoney(r.amountCents, r.currency), csv: (r) => fmtMoney(r.amountCents, r.currency) },
    { label: "Méthode", key: "method", render: (r) => (r.method === "momo" ? `Mobile Money ${r.momo}` : "Stripe"), csv: (r) => (r.method === "momo" ? `Mobile Money ${r.momo}` : "Stripe") },
    { label: "Statut", key: "status", render: (r) => ({ PENDING: "En attente", PAID: "Versé", FAILED: "Échoué" }[r.status] || r.status), csv: (r) => r.status },
    { label: "Échéance", key: "dueBy", render: (r) => fmtDate(r.dueBy), csv: (r) => fmtDate(r.dueBy) },
    { label: "Traité le", key: "processedAt", render: (r) => fmtDate(r.processedAt), csv: (r) => fmtDate(r.processedAt) },
  ];

  const current = data[tab];

  return (
    <DashboardShell active="admin" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Propriétaire</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Administration</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : !author?.isAdmin ? (
        <p className="font-body text-sm" style={{ color: colors.mist }}>Page introuvable.</p>
      ) : (
        <>
          <div className="flex gap-2 overflow-x-auto no-scrollbar mb-5">
            {TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className="font-body text-sm font-semibold px-4 py-2 rounded-full whitespace-nowrap"
                style={{ backgroundColor: tab === t.id ? colors.gold : colors.paperDim, color: colors.textPaper }}
              >
                {t.label}
              </button>
            ))}
          </div>

          <div className="mb-3"><ErrorBanner message={error} /></div>

          {!current && loadingTab ? (
            <Spinner color={colors.gold} />
          ) : !current ? null : tab === "overview" ? (
            <Overview data={current} />
          ) : tab === "authors" ? (
            <DataTable
              title="Auteurs"
              rows={current}
              columns={colsAuthors}
              searchKeys={["name", "email"]}
              csvName="auteurs-plume.csv"
              empty="Aucun auteur."
              extra={(r) => (
                <div className="flex items-center justify-end gap-2">
                  <button
                    disabled={busyId === r.id}
                    onClick={() => toggleLifetime(r)}
                    className="font-body text-xs px-3 py-1.5 rounded-lg"
                    style={r.lifetimeAccess ? { color: colors.textPaperDim, border: `1px solid ${colors.mist}` } : { backgroundColor: colors.gold, color: colors.ink }}
                  >
                    {r.lifetimeAccess ? "Retirer l’accès à vie" : "Offrir à vie"}
                  </button>
                  {!r.isAdmin && (
                    <button
                      disabled={busyId === r.id}
                      onClick={() => toggleSuspend(r)}
                      className="font-body text-xs px-3 py-1.5 rounded-lg"
                      style={r.suspended ? { backgroundColor: colors.forest, color: colors.paper } : { color: colors.wine, border: `1px solid ${colors.wine}` }}
                    >
                      {r.suspended ? "Réactiver" : "Suspendre"}
                    </button>
                  )}
                </div>
              )}
            />
          ) : tab === "buyers" ? (
            <DataTable title="Acheteurs" rows={current} columns={colsBuyers} searchKeys={["buyerName", "buyerEmail", "bookTitle", "authorName"]} csvName="acheteurs-plume.csv" empty="Aucun acheteur pour l’instant." />
          ) : tab === "extract" ? (
            <DataTable title="Contacts d’extrait" rows={current} columns={colsExtract} searchKeys={["firstName", "lastName", "email", "bookTitle", "authorName"]} csvName="contacts-extraits-plume.csv" empty="Aucun contact d’extrait pour l’instant." />
          ) : (
            <DataTable title="Reversements" rows={current} columns={colsPayouts} searchKeys={["authorName", "authorEmail"]} csvName="reversements-plume.csv" empty="Aucune demande de reversement." />
          )}
        </>
      )}
    </DashboardShell>
  );
}
