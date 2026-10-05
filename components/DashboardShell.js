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
          <div className="min-w-0 flex-1">
            <p className="font-display text-lg leading-none" style={{ color: colors.paper }}>Plume</p>
            <p className="font-mono text-[10px] tracking-wide" style={{ color: colors.mist }}>ESPACE AUTEUR</p>
          </div>
          <button onClick={handleLogout} title="Se déconnecter" className="shrink-0 p-2 -m-2 md:hidden">
            <LogOut size={16} color={colors.mist} />
          </button>
        </div>

        <div className="relative md:static">
          <nav className="flex md:flex-col gap-1 overflow-x-auto md:overflow-visible px-3 pb-3 md:pb-4 no-scrollbar">
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
          <div
            className="pointer-events-none absolute top-0 right-0 h-full w-8 md:hidden"
            style={{ background: `linear-gradient(to right, transparent, ${colors.ink})` }}
          />
        </div>

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
