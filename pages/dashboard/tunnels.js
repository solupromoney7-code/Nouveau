import { useEffect, useState } from "react";
import { Mail, MessageCircle, ChevronDown, ChevronRight, Check, AlertTriangle, Loader2 } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const LIST_TABS = [
  { id: "extrait", label: "Lecteurs de l’extrait" },
  { id: "acheteur", label: "Lecteurs qui ont acheté" },
];

function Toggle({ checked, onChange }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="relative inline-flex items-center rounded-full transition-colors shrink-0"
      style={{ width: 40, height: 22, backgroundColor: checked ? colors.forest : colors.mist }}
    >
      <span
        className="inline-block rounded-full bg-white transition-transform"
        style={{ width: 16, height: 16, transform: `translateX(${checked ? 21 : 3}px)` }}
      />
    </button>
  );
}

// Étape d'un tunnel. `channel` ("email" | "whatsapp") détermine si un champ
// "objet" est affiché (WhatsApp n'a qu'un corps de message).
function SequenceStep({ step, channel, onSave }) {
  const [open, setOpen] = useState(false);
  const [subject, setSubject] = useState(step.subject || "");
  const [body, setBody] = useState(step.body);
  const [delayDays, setDelayDays] = useState(step.delayDays);
  const [saved, setSaved] = useState(false);

  async function persist(patch) {
    await onSave(step.id, patch);
    setSaved(true);
    setTimeout(() => setSaved(false), 1200);
  }

  const headerLabel = channel === "email" ? subject : body;

  return (
    <div className="rounded-xl overflow-hidden" style={{ border: `1px solid ${colors.paperDim}` }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between gap-3 px-4 py-3 text-left"
        style={{ backgroundColor: colors.paperDim }}
      >
        <div className="flex items-center gap-3 min-w-0">
          {open ? <ChevronDown size={15} color={colors.textPaperDim} /> : <ChevronRight size={15} color={colors.textPaperDim} />}
          <span className="font-mono text-[10px] shrink-0 px-2 py-0.5 rounded-full" style={{ backgroundColor: colors.gold, color: colors.ink }}>
            J+{step.delayDays}
          </span>
          <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{headerLabel}</p>
        </div>
        {saved && <Check size={14} color={colors.forest} className="shrink-0" />}
      </button>

      {open && (
        <div className="p-4 space-y-3" style={{ backgroundColor: "#FFFFFF" }}>
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>Délai (jours après l’entrée dans la liste)</p>
            <input
              type="number"
              min="0"
              value={delayDays}
              onChange={(e) => setDelayDays(e.target.value)}
              onBlur={() => persist({ delayDays: Number(delayDays) })}
              className="w-24 rounded-lg px-3 py-2 font-body text-sm"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />
          </div>
          {channel === "email" && (
            <div>
              <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>Objet de l’email</p>
              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                onBlur={() => persist({ subject })}
                className="w-full rounded-lg px-3 py-2 font-body text-sm"
                style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
              />
            </div>
          )}
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>
              {channel === "email" ? "Contenu" : "Message WhatsApp"}
            </p>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              onBlur={() => persist({ body })}
              rows={channel === "email" ? 7 : 5}
              maxLength={channel === "whatsapp" ? 900 : undefined}
              className="w-full rounded-lg px-3 py-2 font-body text-sm resize-y"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />
            {channel === "whatsapp" && (
              <p className="font-mono text-[10px] mt-1" style={{ color: colors.mist }}>{body.length} / 900 caractères</p>
            )}
            {channel === "whatsapp" && (
              <p className="font-body text-xs mt-1.5" style={{ color: colors.forest }}>
                Ajouté automatiquement à la fin de chaque message : « Répondez-moi ici » + un lien vers votre WhatsApp (celui de Paramètres).
              </p>
            )}
            <p className="font-mono text-[10px] mt-1.5" style={{ color: colors.mist }}>
              Variables disponibles : {"{{prenom}}"}, {"{{titre}}"}, {"{{auteur}}"}, {"{{lien_achat}}"}, {"{{lien_boutique}}"}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

// Bandeau affiché tant que le modèle WhatsApp générique n'est pas approuvé
// par Meta — avant ça, aucun message WhatsApp automatique ne peut partir.
function WhatsAppTemplateStatus({ template, onSubmit, submitting, submitError }) {
  if (!template || !template.configured) {
    return (
      <div className="flex items-start gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(122,46,59,0.1)" }}>
        <AlertTriangle size={14} color={colors.wine} className="mt-0.5 shrink-0" />
        <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
          WhatsApp n’est pas encore connecté sur la plateforme (variables WHATSAPP_ACCESS_TOKEN /
          WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_BUSINESS_ACCOUNT_ID manquantes côté Vercel). Les tunnels restent
          modifiables, mais aucun message ne partira tant que ce n’est pas configuré.
        </p>
      </div>
    );
  }

  if (!template.submitted) {
    return (
      <div className="flex items-start gap-3 px-4 py-3 rounded-xl mb-4 flex-wrap" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
        <AlertTriangle size={14} color={colors.goldDark} className="mt-0.5 shrink-0" />
        <div className="flex-1 min-w-[200px]">
          <p className="font-body text-xs mb-2" style={{ color: colors.textPaperDim }}>
            Le modèle de message WhatsApp n’a pas encore été soumis à Meta pour approbation — étape unique, à faire une
            seule fois pour toute la plateforme.
          </p>
          <ErrorBanner message={submitError} />
          <button
            onClick={onSubmit}
            disabled={submitting}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg font-body font-semibold text-xs mt-1"
            style={{ backgroundColor: colors.gold, color: colors.ink, opacity: submitting ? 0.6 : 1 }}
          >
            {submitting && <Loader2 size={12} className="animate-spin" />}
            {submitting ? "Envoi…" : "Soumettre le modèle à Meta"}
          </button>
        </div>
      </div>
    );
  }

  if (template.status !== "APPROVED") {
    return (
      <div className="flex items-center gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(201,162,39,0.1)" }}>
        <Loader2 size={14} color={colors.goldDark} className="shrink-0" />
        <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
          Modèle soumis à Meta, en attente d’approbation (statut : {template.status || "en cours"}) — généralement
          quelques minutes à 24h. Les messages partiront automatiquement dès l’approbation.
        </p>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 px-4 py-3 rounded-xl mb-4" style={{ backgroundColor: "rgba(79,122,92,0.12)" }}>
      <Check size={14} color={colors.forest} className="shrink-0" />
      <p className="font-body text-xs" style={{ color: colors.forest }}>Modèle WhatsApp approuvé — les tunnels WhatsApp sont actifs.</p>
    </div>
  );
}

export default function DashboardTunnels() {
  const { author, loading: authLoading } = useAuthGuard();

  const [channel, setChannel] = useState("email");
  const [tab, setTab] = useState("extrait");

  const [emailSequences, setEmailSequences] = useState([]);
  const [waSequences, setWaSequences] = useState([]);
  const [waTemplate, setWaTemplate] = useState(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [togglingId, setTogglingId] = useState(null);

  const [submittingTemplate, setSubmittingTemplate] = useState(false);
  const [templateSubmitError, setTemplateSubmitError] = useState("");

  useEffect(() => {
    if (!author) return;
    setLoading(true);
    setError("");
    Promise.all([api("/api/sequences"), api("/api/whatsapp-sequences")])
      .then(([email, wa]) => {
        setEmailSequences(email);
        setWaSequences(wa.sequences);
        setWaTemplate(wa.template);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  async function handleStepSave(stepId, patch) {
    try {
      const path = channel === "email" ? `/api/sequences/steps/${stepId}` : `/api/whatsapp-sequences/steps/${stepId}`;
      await api(path, { method: "PATCH", body: patch });
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleToggleActive(sequence) {
    setTogglingId(sequence.id);
    try {
      const path = channel === "email" ? `/api/sequences/${sequence.id}` : `/api/whatsapp-sequences/${sequence.id}`;
      const updated = await api(path, { method: "PATCH", body: { active: !sequence.active } });
      const setter = channel === "email" ? setEmailSequences : setWaSequences;
      setter((seqs) => seqs.map((s) => (s.id === updated.id ? { ...s, active: updated.active } : s)));
    } catch (err) {
      setError(err.message);
    } finally {
      setTogglingId(null);
    }
  }

  async function handleSubmitTemplate() {
    setTemplateSubmitError("");
    setSubmittingTemplate(true);
    try {
      await api("/api/whatsapp/submit-template", { method: "POST" });
      const wa = await api("/api/whatsapp-sequences");
      setWaTemplate(wa.template);
    } catch (err) {
      setTemplateSubmitError(err.message);
    } finally {
      setSubmittingTemplate(false);
    }
  }

  const sequences = channel === "email" ? emailSequences : waSequences;
  const current = sequences.find((s) => s.listSource === tab);
  const Icon = channel === "email" ? Mail : MessageCircle;
  const unitLabel = channel === "email" ? "email" : "message";

  return (
    <DashboardShell active="tunnels" author={author}>
      <header className="mb-6">
        <p className="font-mono text-[11px] tracking-widest uppercase" style={{ color: colors.gold }}>Autorépondeur</p>
        <h1 className="font-display text-2xl md:text-3xl" style={{ color: colors.paper }}>Tunnels de vente</h1>
      </header>

      {authLoading || loading ? (
        <Spinner color={colors.gold} />
      ) : (
        <div className="max-w-2xl">
          <ErrorBanner message={error} />

          <div className="flex gap-2 mb-3 mt-3">
            {[{ id: "email", label: "Email", icon: Mail }, { id: "whatsapp", label: "WhatsApp", icon: MessageCircle }].map((c) => (
              <button
                key={c.id}
                onClick={() => setChannel(c.id)}
                className="flex items-center gap-1.5 px-4 py-1.5 rounded-full font-body text-xs font-semibold"
                style={{
                  backgroundColor: channel === c.id ? colors.ink : colors.paper,
                  color: channel === c.id ? colors.paper : colors.textPaperDim,
                }}
              >
                <c.icon size={13} /> {c.label}
              </button>
            ))}
          </div>

          {channel === "whatsapp" && (
            <WhatsAppTemplateStatus
              template={waTemplate}
              onSubmit={handleSubmitTemplate}
              submitting={submittingTemplate}
              submitError={templateSubmitError}
            />
          )}

          <div className="flex gap-2 mb-4">
            {LIST_TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className="px-4 py-1.5 rounded-full font-body text-xs font-semibold"
                style={{
                  backgroundColor: tab === t.id ? colors.gold : colors.paper,
                  color: tab === t.id ? colors.ink : colors.textPaperDim,
                }}
              >
                {t.label}
              </button>
            ))}
          </div>

          {!current ? (
            <p className="font-body text-sm py-8 text-center" style={{ color: colors.mist }}>Tunnel introuvable.</p>
          ) : (
            <div className="rounded-2xl p-6 md:p-8" style={{ backgroundColor: colors.paper }}>
              <div className="flex items-center justify-between gap-3 mb-5 pb-5 border-b" style={{ borderColor: colors.paperDim }}>
                <div className="flex items-center gap-2 min-w-0">
                  <Icon size={16} color={colors.goldDark} className="shrink-0" />
                  <div className="min-w-0">
                    <p className="font-display text-lg truncate" style={{ color: colors.textPaper }}>{current.name}</p>
                    <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                      {current.steps.length} {unitLabel}{current.steps.length > 1 ? "s" : ""} automatique{current.steps.length > 1 ? "s" : ""} — {current.active ? "actif" : "en pause"}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {togglingId === current.id && <Spinner size={13} color={colors.goldDark} />}
                  <Toggle checked={current.active} onChange={() => handleToggleActive(current)} />
                </div>
              </div>

              <div className="space-y-2">
                {current.steps.map((step) => (
                  <SequenceStep key={step.id} step={step} channel={channel} onSave={handleStepSave} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
