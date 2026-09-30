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
