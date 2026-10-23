#!/bin/bash
# Contacts : envoi groupé par email et sur WhatsApp
set -e
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
cat > "$TMP" <<'PLUME_PATCH_EOF'
diff --git a/pages/api/contacts/index.js b/pages/api/contacts/index.js
index 0a415ac..9dcbcc6 100644
--- a/pages/api/contacts/index.js
+++ b/pages/api/contacts/index.js
@@ -4,9 +4,10 @@ import { prisma } from "../../../lib/db";
 export default requireAuth(async function handler(req, res) {
   if (req.method !== "GET") return res.status(405).end();
 
-  const source = req.query.source === "acheteurs" ? "acheteur" : "extrait";
+  // "tous" renvoie toute la liste (acheteurs + extrait).
+  const source = req.query.source === "acheteurs" ? "acheteur" : req.query.source === "tous" ? null : "extrait";
   const leads = await prisma.lead.findMany({
-    where: { authorId: req.authorId, source },
+    where: { authorId: req.authorId, ...(source && { source }) },
     orderBy: { createdAt: "desc" },
   });
   return res.status(200).json(leads);
diff --git a/pages/dashboard/contacts.js b/pages/dashboard/contacts.js
index 23f8383..2148470 100644
--- a/pages/dashboard/contacts.js
+++ b/pages/dashboard/contacts.js
@@ -1,16 +1,57 @@
 import { useEffect, useState } from "react";
-import { MessageCircle } from "lucide-react";
+import { MessageCircle, Mail, Send, Check, Loader2 } from "lucide-react";
 import DashboardShell from "../../components/DashboardShell";
 import { colors, Spinner, ErrorBanner } from "../../components/ui";
 import { useAuthGuard } from "../../lib/useAuthGuard";
 import { api } from "../../lib/apiClient";
 
+const LIST_SOURCE = { acheteurs: "acheteur", extrait: "extrait", tous: "tous" };
+const TAB_LABEL = { acheteurs: "Acheteurs", extrait: "Extrait du livre", tous: "Tous" };
+
+function fillTemplate(text, vars) {
+  return String(text || "").replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? "");
+}
+
 export default function DashboardContacts() {
   const { author, loading: authLoading } = useAuthGuard();
   const [tab, setTab] = useState("acheteurs");
   const [rows, setRows] = useState([]);
   const [loading, setLoading] = useState(true);
   const [error, setError] = useState("");
+  const [mode, setMode] = useState(null); // null | "email" | "whatsapp"
+  const [subject, setSubject] = useState("");
+  const [message, setMessage] = useState("Bonjour {{prenom}},\n\n");
+  const [sending, setSending] = useState(false);
+  const [result, setResult] = useState(null);
+  const [waSent, setWaSent] = useState({});
+
+  async function sendEmail() {
+    setError("");
+    setResult(null);
+    if (!subject.trim() || !message.trim()) {
+      setError("Renseignez l’objet et le message.");
+      return;
+    }
+    if (!window.confirm(`Envoyer cet email à ${rows.length} contact(s) (${TAB_LABEL[tab]}) ?`)) return;
+    setSending(true);
+    try {
+      const data = await api("/api/broadcasts", {
+        method: "POST",
+        body: { listSource: LIST_SOURCE[tab], subject, body: message },
+      });
+      setResult(data);
+    } catch (err) {
+      setError(err.message);
+    } finally {
+      setSending(false);
+    }
+  }
+
+  function waLink(r) {
+    const digits = (r.whatsapp || "").replace(/[^0-9]/g, "");
+    const text = fillTemplate(message, { prenom: r.firstName, auteur: author?.name });
+    return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
+  }
 
   useEffect(() => {
     if (!author) return;
@@ -33,21 +74,89 @@ export default function DashboardContacts() {
       ) : (
         <div className="rounded-2xl p-4 md:p-6 max-w-3xl" style={{ backgroundColor: colors.paper }}>
           <div className="flex gap-2 mb-4">
-            {["acheteurs", "extrait"].map((t) => (
+            {["acheteurs", "extrait", "tous"].map((t) => (
               <button
                 key={t}
-                onClick={() => setTab(t)}
+                onClick={() => { setTab(t); setResult(null); setWaSent({}); }}
                 className="px-4 py-1.5 rounded-full font-body text-xs font-semibold capitalize"
                 style={{
                   backgroundColor: tab === t ? colors.gold : colors.paperDim,
                   color: tab === t ? colors.ink : colors.textPaperDim,
                 }}
               >
-                {t === "acheteurs" ? "Acheteurs" : "Extrait du livre"}
+                {TAB_LABEL[t]}
               </button>
             ))}
           </div>
 
+          <div className="flex flex-wrap gap-2 mb-4">
+            <button
+              onClick={() => { setMode(mode === "email" ? null : "email"); setResult(null); setError(""); }}
+              className="flex items-center gap-2 px-3 py-2 rounded-lg font-body text-xs font-semibold"
+              style={{ backgroundColor: mode === "email" ? colors.gold : colors.paperDim, color: mode === "email" ? colors.ink : colors.textPaper }}
+            >
+              <Mail size={14} /> Écrire à ma liste par email
+            </button>
+            <button
+              onClick={() => { setMode(mode === "whatsapp" ? null : "whatsapp"); setResult(null); setError(""); }}
+              className="flex items-center gap-2 px-3 py-2 rounded-lg font-body text-xs font-semibold"
+              style={{ backgroundColor: mode === "whatsapp" ? colors.gold : colors.paperDim, color: mode === "whatsapp" ? colors.ink : colors.textPaper }}
+            >
+              <MessageCircle size={14} /> Écrire à ma liste sur WhatsApp
+            </button>
+          </div>
+
+          {mode && (
+            <div className="rounded-xl p-4 mb-4 space-y-3" style={{ backgroundColor: colors.paperDim }}>
+              <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
+                Liste : <strong>{TAB_LABEL[tab]}</strong> ({rows.length} contact{rows.length > 1 ? "s" : ""}). Écrivez <code>{"{{prenom}}"}</code> pour insérer le prénom de chaque contact.
+              </p>
+              {mode === "email" && (
+                <input
+                  value={subject}
+                  onChange={(e) => setSubject(e.target.value)}
+                  placeholder="Objet de l’email"
+                  className="w-full rounded-lg px-3 py-2 font-body text-sm"
+                  style={{ backgroundColor: "#FFFFFF", color: colors.textPaper, border: "none" }}
+                />
+              )}
+              <textarea
+                value={message}
+                onChange={(e) => setMessage(e.target.value)}
+                rows={6}
+                placeholder="Votre message…"
+                className="w-full rounded-lg px-3 py-2 font-body text-sm"
+                style={{ backgroundColor: "#FFFFFF", color: colors.textPaper, border: "none" }}
+              />
+              {mode === "email" ? (
+                <div className="flex items-center gap-3">
+                  <button
+                    onClick={sendEmail}
+                    disabled={sending || rows.length === 0}
+                    className="flex items-center gap-2 px-4 py-2 rounded-lg font-body font-semibold text-sm"
+                    style={{ backgroundColor: colors.gold, color: colors.ink, opacity: sending || rows.length === 0 ? 0.6 : 1 }}
+                  >
+                    {sending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
+                    {sending ? "Envoi…" : "Envoyer à toute la liste"}
+                  </button>
+                  {result && (
+                    <span className="flex items-center gap-1 font-body text-xs" style={{ color: result.status === "failed" ? "#B3261E" : colors.forest }}>
+                      <Check size={13} />
+                      {result.status === "failed"
+                        ? `Envoi à ${result.recipients} contact(s) : certains emails n’ont pas pu partir.`
+                        : `Envoyé à ${result.recipients} contact(s).`}
+                    </span>
+                  )}
+                </div>
+              ) : (
+                <p className="font-body text-xs" style={{ color: colors.textPaperDim }}>
+                  Cliquez sur « Envoyer » à côté de chaque contact : WhatsApp s’ouvre avec votre message déjà écrit. Vous n’avez plus qu’à valider l’envoi.
+                  {Object.keys(waSent).length > 0 && ` ${Object.keys(waSent).length}/${rows.length} ouvert(s).`}
+                </p>
+              )}
+            </div>
+          )}
+
           <ErrorBanner message={error} />
 
           {loading ? (
@@ -76,13 +185,14 @@ export default function DashboardContacts() {
                         <td className="py-2.5 pr-4 whitespace-nowrap">
                           {digits ? (
                             <a
-                              href={`https://wa.me/${digits}`}
+                              href={mode === "whatsapp" ? waLink(r) : `https://wa.me/${digits}`}
                               target="_blank"
                               rel="noreferrer"
+                              onClick={() => mode === "whatsapp" && setWaSent((s) => ({ ...s, [r.id]: true }))}
                               className="inline-flex items-center gap-1.5 px-2 py-1 rounded-lg"
                               style={{ backgroundColor: "rgba(79,122,92,0.12)", color: colors.forest }}
                             >
-                              <MessageCircle size={13} /> {r.whatsapp}
+                              <MessageCircle size={13} /> {mode === "whatsapp" ? (waSent[r.id] ? "Ouvert ✓" : "Envoyer") : r.whatsapp}
                             </a>
                           ) : "—"}
                         </td>
PLUME_PATCH_EOF
if ! git apply --check "$TMP" 2>/dev/null; then
  echo "ERREUR : le correctif ne s'applique pas (déjà appliqué ?)."; rm -f "$TMP"; exit 1
fi
git apply --whitespace=nowarn "$TMP"
rm -f "$TMP"
echo "OK : envoi groupé email + WhatsApp appliqué"
