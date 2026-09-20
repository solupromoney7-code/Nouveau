#!/bin/bash
# Ajoute le tableau de bord auteur (page de vente + 7 sections).
set -e

echo "Ajout du dashboard..."
mkdir -p "components"
mkdir -p "pages/dashboard"

echo "-> components/DashboardShell.js"
cat > 'components/DashboardShell.js' << 'PLUMEFILE_EOF'
import Link from "next/link";
import { useRouter } from "next/router";
import {
  BookOpen, FileText, Users, Store, Settings, CreditCard,
  Sparkles, Wallet, Mail, Lock, LogOut,
} from "lucide-react";
import { colors } from "./ui";
import { clearToken } from "../lib/apiClient";

const NAV_ITEMS = [
  { id: "vente", label: "Page de vente", icon: FileText, href: "/dashboard" },
  { id: "extrait", label: "Page d’extrait", icon: BookOpen, href: "/dashboard/extrait" },
  { id: "contenu", label: "Contenu réseaux", icon: Sparkles, href: "/dashboard/contenu", locked: true },
  { id: "contacts", label: "Contacts", icon: Users, href: "/dashboard/contacts" },
  { id: "tunnels", label: "Tunnels de vente", icon: Mail, href: "/dashboard/tunnels" },
  { id: "boutique", label: "Ma boutique", icon: Store, href: "/dashboard/boutique" },
  { id: "parametres", label: "Paramètres", icon: Settings, href: "/dashboard/parametres" },
  { id: "paiements", label: "Paiements", icon: Wallet, href: "/dashboard/paiements" },
  { id: "abonnement", label: "Abonnement", icon: CreditCard, href: "/dashboard/abonnement" },
];

export default function DashboardShell({ active, author, children }) {
  const router = useRouter();

  function handleLogout() {
    clearToken();
    router.push("/");
  }

  return (
    <div className="min-h-screen flex flex-col md:flex-row" style={{ backgroundColor: colors.inkDeep }}>
      <aside
        className="shrink-0 md:w-60 md:h-screen md:sticky md:top-0 flex flex-col border-b md:border-b-0 md:border-r"
        style={{ backgroundColor: colors.ink, borderColor: "rgba(255,255,255,0.08)" }}
      >
        <div className="flex items-center gap-2 px-4 py-4 md:py-5">
          <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={16} color={colors.ink} />
          </div>
          <div>
            <p className="font-display text-lg leading-none" style={{ color: colors.paper }}>Plume</p>
            <p className="font-mono text-[10px] tracking-wide" style={{ color: colors.mist }}>ESPACE AUTEUR</p>
          </div>
        </div>

        <nav className="flex md:flex-col gap-1 overflow-x-auto md:overflow-visible px-3 pb-3 md:pb-4">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const isActive = active === item.id;
            return (
              <Link
                key={item.id}
                href={item.href}
                className="flex items-center gap-2 px-3 py-2 rounded-lg whitespace-nowrap text-sm shrink-0 transition-colors"
                style={{
                  backgroundColor: isActive ? "rgba(201,162,39,0.14)" : "transparent",
                  color: isActive ? colors.gold : colors.mist,
                }}
              >
                <Icon size={16} />
                {item.label}
                {item.locked && <Lock size={11} style={{ marginLeft: 2 }} />}
              </Link>
            );
          })}
        </nav>

        <div className="hidden md:flex items-center gap-2 mt-auto px-4 py-4 border-t" style={{ borderColor: "rgba(255,255,255,0.08)" }}>
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center font-body text-xs font-semibold shrink-0"
            style={{ backgroundColor: colors.wine, color: colors.paper }}
          >
            {(author?.name || "?").split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm truncate" style={{ color: colors.paper }}>{author?.name || "…"}</p>
            <p className="font-mono text-[10px]" style={{ color: colors.mist }}>
              {author?.subscriptionStatus === "TRIALING" ? "Essai gratuit" : author?.subscriptionStatus === "ACTIVE" ? "Abonnement actif" : "Abonnement inactif"}
            </p>
          </div>
          <button onClick={handleLogout} title="Se déconnecter">
            <LogOut size={15} color={colors.mist} />
          </button>
        </div>
      </aside>

      <main className="flex-1 min-w-0 p-4 md:p-8 pb-20">{children}</main>
    </div>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/index.js"
cat > 'pages/dashboard/index.js' << 'PLUMEFILE_EOF'
import { useState, useRef } from "react";
import { Sparkles, Upload, Check, Copy, ExternalLink, Loader2, Smartphone, CreditCard } from "lucide-react";
import DashboardShell from "../components/DashboardShell";
import { colors, BookCover, ErrorBanner, Spinner } from "../components/ui";
import { useAuthGuard } from "../lib/useAuthGuard";
import { api, getToken } from "../lib/apiClient";

function EditableParagraph({ value, onChange }) {
  const [editing, setEditing] = useState(false);
  if (editing) {
    return (
      <textarea
        autoFocus
        defaultValue={value}
        onBlur={(e) => { onChange(e.target.value); setEditing(false); }}
        className="w-full font-body text-[15px] leading-relaxed bg-transparent border rounded-lg p-2 resize-none"
        style={{ borderColor: colors.gold, color: colors.textPaper, minHeight: 90 }}
      />
    );
  }
  return (
    <p
      onClick={() => setEditing(true)}
      title="Cliquer pour modifier"
      className="font-body text-[15px] leading-relaxed cursor-text rounded-lg p-2 -m-2 hover:bg-black hover:bg-opacity-5 transition-colors"
      style={{ color: colors.textPaperDim }}
    >
      {value}
    </p>
  );
}

export default function DashboardVente() {
  const { author, loading: authLoading } = useAuthGuard();

  const [stage, setStage] = useState("idle"); // idle -> uploading -> generating -> done
  const [fileName, setFileName] = useState("");
  const [error, setError] = useState("");
  const [book, setBook] = useState(null);
  const [salesPage, setSalesPage] = useState(null);
  const [priceInput, setPriceInput] = useState("12");
  const [copied, setCopied] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const fileInputRef = useRef(null);

  const currency = author?.region === "EUROPE" ? "EUR" : "XOF";
  const currencyLabel = currency === "EUR" ? "€" : "FCFA";

  async function handleFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError("");
    setFileName(file.name);
    setStage("uploading");

    try {
      const res = await fetch("/api/books/upload", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${getToken()}`,
          "x-filename": file.name,
          "Content-Type": file.type || "application/octet-stream",
        },
        body: file,
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Échec de l’upload");
      setBook(data);
      setStage("fileReady");
    } catch (err) {
      setError(err.message);
      setStage("idle");
    }
  }

  async function handleGenerate() {
    if (!book) return;
    setError("");
    setStage("generating");
    try {
      const priceCents = Math.round(Number(priceInput) * 100);
      const data = await api("/api/sales-pages", {
        method: "POST",
        body: { bookId: book.id, priceCents, currency },
      });
      setSalesPage(data);
      setStage("done");
    } catch (err) {
      setError(err.message);
      setStage("fileReady");
    }
  }

  async function handlePublish() {
    setPublishing(true);
    try {
      const updated = await api(`/api/sales-pages/${salesPage.id}`, {
        method: "PATCH",
        body: { published: true },
      });
      setSalesPage(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setPublishing(false);
    }
  }

  async function updateField(field, value) {
    setSalesPage((sp) => ({ ...sp, [field]: value }));
    try {
      await api(`/api/sales-pages/${salesPage.id}`, { method: "PATCH", body: { [field]: value } });
    } catch (err) {
      setError(err.message);
    }
  }

  function reset() {
    setStage("idle");
    setFileName("");
    setBook(null);
    setSalesPage(null);
    setError("");
  }

  const publicUrl = salesPage ? `${typeof window !== "undefined" ? window.location.origin : ""}/p/${salesPage.slug}` : "";

  return (
    <DashboardShell active="vente" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Génération IA</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Page de vente</h1>
      </header>

      {authLoading ? (
        <Spinner color={colors.gold} />
      ) : (
        <>
          {(stage === "idle" || stage === "uploading" || stage === "fileReady") && (
            <div className="rounded-2xl p-6 md:p-10 max-w-xl" style={{ backgroundColor: colors.paper }}>
              <p className="font-mono text-[11px] uppercase tracking-widest mb-2" style={{ color: colors.goldDark }}>Étape 1 sur 2</p>
              <h2 className="font-display text-2xl mb-2" style={{ color: colors.textPaper }}>Téléchargez votre livre</h2>
              <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>
                L’IA lit votre manuscrit et rédige votre page de vente à votre place.
              </p>

              <ErrorBanner message={error} />

              <input ref={fileInputRef} type="file" accept=".pdf,.epub" className="hidden" onChange={handleFile} />
              <label
                onClick={(e) => { if (stage === "uploading") e.preventDefault(); }}
                htmlFor="book-upload-input"
                className="flex flex-col items-center justify-center text-center rounded-xl py-10 px-4 cursor-pointer border-2 border-dashed transition-colors mt-3"
                style={{ borderColor: stage === "fileReady" ? colors.forest : colors.mist }}
                onDrop={(e) => e.preventDefault()}
              >
                <input id="book-upload-input" type="file" accept=".pdf,.epub" className="hidden" onChange={handleFile} />
                {stage === "uploading" ? (
                  <>
                    <Spinner size={24} color={colors.goldDark} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Envoi de {fileName}…</p>
                  </>
                ) : stage === "fileReady" ? (
                  <>
                    <Check size={26} color={colors.forest} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>{fileName}</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>Fichier prêt — cliquez pour changer</p>
                  </>
                ) : (
                  <>
                    <Upload size={26} color={colors.mist} />
                    <p className="font-body text-sm mt-3" style={{ color: colors.textPaper }}>Cliquez pour choisir un fichier</p>
                    <p className="font-mono text-[11px] mt-1" style={{ color: colors.mist }}>PDF, EPUB — 50 Mo max</p>
                  </>
                )}
              </label>

              {stage === "fileReady" && (
                <div className="mt-4">
                  <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
                    Prix de vente ({currencyLabel})
                  </p>
                  <input
                    type="number"
                    value={priceInput}
                    onChange={(e) => setPriceInput(e.target.value)}
                    className="w-32 rounded-lg px-3 py-2 font-body text-sm"
                    style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
                  />
                </div>
              )}

              <button
                disabled={stage !== "fileReady"}
                onClick={handleGenerate}
                className="w-full mt-6 py-3 rounded-xl font-body font-semibold text-sm flex items-center justify-center gap-2"
                style={{
                  backgroundColor: colors.gold, color: colors.ink,
                  opacity: stage === "fileReady" ? 1 : 0.4,
                  cursor: stage === "fileReady" ? "pointer" : "not-allowed",
                }}
              >
                <Sparkles size={16} /> Générer ma page de vente
              </button>
            </div>
          )}

          {stage === "generating" && (
            <div className="rounded-2xl p-6 md:p-10 max-w-xl flex flex-col items-center text-center" style={{ backgroundColor: colors.paper }}>
              <Spinner size={28} color={colors.goldDark} />
              <h2 className="font-display text-xl mt-4" style={{ color: colors.textPaper }}>L’IA rédige votre page…</h2>
              <p className="font-body text-sm mt-1" style={{ color: colors.textPaperDim }}>Ça prend quelques secondes.</p>
            </div>
          )}

          {stage === "done" && salesPage && (
            <div className="max-w-3xl">
              <ErrorBanner message={error} />

              <div
                className="flex items-center justify-between gap-3 rounded-xl px-4 py-3 mb-4 mt-3 flex-wrap"
                style={{
                  backgroundColor: salesPage.published ? "rgba(79,122,92,0.15)" : "rgba(201,162,39,0.12)",
                  border: `1px solid ${salesPage.published ? colors.forest : colors.gold}`,
                }}
              >
                <div className="flex items-center gap-2">
                  {salesPage.published ? <Check size={16} color={colors.forest} /> : <Sparkles size={16} color={colors.gold} />}
                  <p className="font-body text-sm" style={{ color: colors.paper }}>
                    {salesPage.published ? "Page publiée" : "Page générée — pas encore publiée"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {salesPage.published && (
                    <>
                      <button
                        onClick={() => { navigator.clipboard?.writeText(publicUrl); setCopied(true); setTimeout(() => setCopied(false), 1500); }}
                        className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                        style={{ backgroundColor: colors.paperDim, color: colors.textPaper }}
                      >
                        {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copié" : "Copier le lien"}
                      </button>
                      <a
                        href={`/p/${salesPage.slug}`}
                        target="_blank"
                        rel="noreferrer"
                        className="flex items-center gap-1.5 font-body text-xs px-3 py-1.5 rounded-lg"
                        style={{ backgroundColor: colors.gold, color: colors.ink }}
                      >
                        <ExternalLink size={13} /> Voir la page
                      </a>
                    </>
                  )}
                  {!salesPage.published && (
                    <button
                      onClick={handlePublish}
                      disabled={publishing}
                      className="flex items-center gap-1.5 font-body text-xs px-4 py-1.5 rounded-lg font-semibold"
                      style={{ backgroundColor: colors.gold, color: colors.ink }}
                    >
                      {publishing && <Spinner size={12} color={colors.ink} />}
                      {publishing ? "Publication…" : "Publier"}
                    </button>
                  )}
                </div>
              </div>

              <div className="rounded-2xl p-6 md:p-10" style={{ backgroundColor: colors.paper }}>
                <div className="flex flex-col md:flex-row gap-6 md:gap-8">
                  <BookCover title={book?.title || "Votre livre"} author={author?.name || ""} />
                  <div className="flex-1 min-w-0">
                    <h2 className="font-display text-2xl md:text-3xl mb-6" style={{ color: colors.textPaper }}>{book?.title}</h2>

                    <p className="font-mono text-[11px] uppercase tracking-widest mb-1" style={{ color: colors.goldDark }}>Le problème</p>
                    <EditableParagraph value={salesPage.problem} onChange={(v) => updateField("problem", v)} />

                    <p className="font-mono text-[11px] uppercase tracking-widest mt-5 mb-1" style={{ color: colors.goldDark }}>Pourquoi maintenant</p>
                    <EditableParagraph value={salesPage.why} onChange={(v) => updateField("why", v)} />

                    <p className="font-mono text-[11px] uppercase tracking-widest mt-5 mb-1" style={{ color: colors.goldDark }}>La solution</p>
                    <EditableParagraph value={salesPage.solution} onChange={(v) => updateField("solution", v)} />
                  </div>
                </div>

                <div className="mt-8 pt-6 border-t flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4" style={{ borderColor: colors.paperDim }}>
                  <p className="font-body text-lg font-semibold" style={{ color: colors.textPaper }}>
                    {(salesPage.priceCents / 100).toFixed(2)} {currencyLabel}
                  </p>
                  <div className="flex items-center gap-3 font-mono text-[11px]" style={{ color: colors.mist }}>
                    {currency === "EUR" ? (<><CreditCard size={14} /> Carte bancaire</>) : (<><Smartphone size={14} /> Mobile Money</>)}
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between mt-3">
                <p className="font-mono text-[11px]" style={{ color: colors.mist }}>Cliquez un paragraphe pour le modifier — enregistré automatiquement.</p>
                <button onClick={reset} className="font-mono text-[11px] underline" style={{ color: colors.mist }}>Recommencer</button>
              </div>
            </div>
          )}
        </>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/contacts.js"
cat > 'pages/dashboard/contacts.js' << 'PLUMEFILE_EOF'
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
PLUMEFILE_EOF

echo "-> pages/dashboard/extrait.js"
cat > 'pages/dashboard/extrait.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardExtrait() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="extrait" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Capture de leads</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Page d’extrait</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>La génération automatique de votre page d’extrait (capture d’email + envoi du PDF) arrive dans une prochaine étape.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/contenu.js"
cat > 'pages/dashboard/contenu.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardContenu() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="contenu" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Réseaux sociaux</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Contenu généré</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>La génération de contenu réseaux (20 posts/mois) arrive dans une prochaine étape — réservée aux abonnements actifs.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/boutique.js"
cat > 'pages/dashboard/boutique.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardBoutique() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="boutique" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Vitrine publique</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Ma boutique</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>La vitrine publique listant tous vos livres arrive dans une prochaine étape.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/parametres.js"
cat > 'pages/dashboard/parametres.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardParametres() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="parametres" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Compte</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Paramètres</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>La modification de votre profil et la connexion WhatsApp Business arrivent dans une prochaine étape.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/paiements.js"
cat > 'pages/dashboard/paiements.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardPaiements() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="paiements" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Encaissement</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Paiements</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>Le suivi de vos gains et les demandes de reversement arrivent dans une prochaine étape.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo "-> pages/dashboard/tunnels.js"
cat > 'pages/dashboard/tunnels.js' << 'PLUMEFILE_EOF'
import { Clock } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";

export default function DashboardTunnels() {
  const { author, loading } = useAuthGuard();

  return (
    <DashboardShell active="tunnels" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Autorépondeur</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Tunnels de vente</h1>
      </header>

      {loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="rounded-2xl p-8 max-w-lg text-center" style={{ backgroundColor: colors.paper }}>
          <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: colors.paperDim }}>
            <Clock size={20} color={colors.goldDark} />
          </div>
          <h2 className="font-display text-lg mb-2" style={{ color: colors.textPaper }}>Bientôt disponible</h2>
          <p className="font-body text-sm" style={{ color: colors.textPaperDim }}>L’éditeur de vos 2 tunnels de vente automatiques arrive dans une prochaine étape — ils tournent déjà en coulisses.</p>
        </div>
      )}
    </DashboardShell>
  );
}
PLUMEFILE_EOF

echo ""
echo "OK - dashboard ajoute."
