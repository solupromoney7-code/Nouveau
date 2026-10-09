#!/bin/bash
set -e

mkdir -p "pages/dashboard"
cat > "pages/dashboard/tunnels.js" << 'FILE_EOF_MARKER'
import { useEffect, useState } from "react";
import { Mail, ChevronDown, ChevronRight, Check } from "lucide-react";
import DashboardShell from "../../components/DashboardShell";
import { colors, ErrorBanner, Spinner } from "../../components/ui";
import { useAuthGuard } from "../../lib/useAuthGuard";
import { api } from "../../lib/apiClient";

const TABS = [
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

function SequenceStep({ step, onSave }) {
  const [open, setOpen] = useState(false);
  const [subject, setSubject] = useState(step.subject);
  const [body, setBody] = useState(step.body);
  const [delayDays, setDelayDays] = useState(step.delayDays);
  const [saved, setSaved] = useState(false);

  async function persist(patch) {
    await onSave(step.id, patch);
    setSaved(true);
    setTimeout(() => setSaved(false), 1200);
  }

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
          <p className="font-body text-sm truncate" style={{ color: colors.textPaper }}>{subject}</p>
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
          <div>
            <p className="font-mono text-[10px] uppercase tracking-wide mb-1" style={{ color: colors.textPaperDim }}>Contenu</p>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              onBlur={() => persist({ body })}
              rows={7}
              className="w-full rounded-lg px-3 py-2 font-body text-sm resize-y"
              style={{ backgroundColor: colors.paperDim, color: colors.textPaper, border: "none" }}
            />
            <p className="font-mono text-[10px] mt-1.5" style={{ color: colors.mist }}>
              Variables disponibles : {"{{prenom}}"}, {"{{titre}}"}, {"{{auteur}}"}, {"{{lien_achat}}"}, {"{{lien_boutique}}"}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

export default function DashboardTunnels() {
  const { author, loading: authLoading } = useAuthGuard();
  const [sequences, setSequences] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [tab, setTab] = useState("extrait");
  const [togglingId, setTogglingId] = useState(null);

  useEffect(() => {
    if (!author) return;
    setLoading(true);
    api("/api/sequences")
      .then(setSequences)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [author]);

  async function handleStepSave(stepId, patch) {
    try {
      await api(`/api/sequences/steps/${stepId}`, { method: "PATCH", body: patch });
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleToggleActive(sequence) {
    setTogglingId(sequence.id);
    try {
      const updated = await api(`/api/sequences/${sequence.id}`, { method: "PATCH", body: { active: !sequence.active } });
      setSequences((seqs) => seqs.map((s) => (s.id === updated.id ? { ...s, active: updated.active } : s)));
    } catch (err) {
      setError(err.message);
    } finally {
      setTogglingId(null);
    }
  }

  const current = sequences.find((s) => s.listSource === tab);

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

          <div className="flex gap-2 mb-4 mt-3">
            {TABS.map((t) => (
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
                  <Mail size={16} color={colors.goldDark} className="shrink-0" />
                  <div className="min-w-0">
                    <p className="font-display text-lg truncate" style={{ color: colors.textPaper }}>{current.name}</p>
                    <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
                      {current.steps.length} email{current.steps.length > 1 ? "s" : ""} automatique{current.steps.length > 1 ? "s" : ""} — {current.active ? "actif" : "en pause"}
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
                  <SequenceStep key={step.id} step={step} onSave={handleStepSave} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </DashboardShell>
  );
}
FILE_EOF_MARKER

mkdir -p "pages/api/sequences"
cat > "pages/api/sequences/index.js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";
import { DEFAULT_SEQUENCES } from "../../../lib/sequences";

// Retourne les 2 tunnels de vente de l'auteur (extrait, acheteur), en les
// créant automatiquement avec leur contenu par défaut au premier appel —
// l'auteur n'a jamais de tunnel vide à configurer depuis zéro.
//
// Complète aussi les étapes manquantes d'un tunnel déjà existant (ex. un
// compte créé avant le passage de 3 à 7 étapes par défaut) : seules les
// étapes dont le numéro d'ordre n'existe pas encore sont ajoutées, sans
// jamais toucher aux étapes déjà personnalisées par l'auteur.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).end();

  try {
    let existing = await prisma.emailSequence.findMany({
      where: { authorId: req.authorId },
      include: { steps: { orderBy: { order: "asc" } } },
    });

    const existingSources = new Set(existing.map((s) => s.listSource));
    const missingSequences = Object.keys(DEFAULT_SEQUENCES).filter((src) => !existingSources.has(src));

    for (const listSource of missingSequences) {
      const def = DEFAULT_SEQUENCES[listSource];
      await prisma.emailSequence.create({
        data: {
          authorId: req.authorId,
          listSource,
          name: def.name,
          steps: { create: def.steps },
        },
      });
    }

    // Backfill : pour les tunnels déjà existants, ajoute les étapes par
    // défaut dont l'ordre n'est pas encore présent.
    for (const sequence of existing) {
      const def = DEFAULT_SEQUENCES[sequence.listSource];
      if (!def) continue;
      const existingOrders = new Set(sequence.steps.map((s) => s.order));
      const stepsToAdd = def.steps.filter((s) => !existingOrders.has(s.order));
      if (stepsToAdd.length > 0) {
        await prisma.emailSequenceStep.createMany({
          data: stepsToAdd.map((s) => ({ ...s, sequenceId: sequence.id })),
        });
      }
    }

    const result = await prisma.emailSequence.findMany({
      where: { authorId: req.authorId },
      include: { steps: { orderBy: { order: "asc" } } },
    });

    return res.status(200).json(result);
  } catch (error) {
    console.error("Erreur /api/sequences :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/sequences"
cat > "pages/api/sequences/[id].js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../lib/auth";
import { prisma } from "../../../lib/db";

// Active/désactive un tunnel (l'auteur peut couper l'automatisation sans
// perdre son contenu).
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { id } = req.query;
  const { active } = req.body;

  try {
    const sequence = await prisma.emailSequence.findFirst({ where: { id, authorId: req.authorId } });
    if (!sequence) return res.status(404).json({ error: "Tunnel introuvable" });

    const updated = await prisma.emailSequence.update({
      where: { id },
      data: { active: Boolean(active) },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur /api/sequences/[id] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

mkdir -p "pages/api/sequences/steps"
cat > "pages/api/sequences/steps/[stepId].js" << 'FILE_EOF_MARKER'
import { requireAuth } from "../../../../lib/auth";
import { prisma } from "../../../../lib/db";

// Édite le sujet/texte/délai d'une étape d'un tunnel — c'est le seul geste
// de personnalisation attendu de l'auteur, le reste est pré-rempli.
export default requireAuth(async function handler(req, res) {
  if (req.method !== "PATCH") return res.status(405).end();
  const { stepId } = req.query;
  const { subject, body, delayDays } = req.body;

  try {
    const step = await prisma.emailSequenceStep.findUnique({
      where: { id: stepId },
      include: { sequence: true },
    });
    if (!step || step.sequence.authorId !== req.authorId) {
      return res.status(404).json({ error: "Étape introuvable" });
    }

    const updated = await prisma.emailSequenceStep.update({
      where: { id: stepId },
      data: {
        ...(subject !== undefined && { subject }),
        ...(body !== undefined && { body }),
        ...(delayDays !== undefined && { delayDays: Number(delayDays) }),
      },
    });
    return res.status(200).json(updated);
  } catch (error) {
    console.error("Erreur /api/sequences/steps/[stepId] :", error);
    return res.status(500).json({ error: error.message || "Erreur serveur inattendue." });
  }
});
FILE_EOF_MARKER

echo "Fichiers mis à jour avec succès."
