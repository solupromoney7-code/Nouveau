import Link from "next/link";
import { BookOpen } from "lucide-react";
import { colors } from "./ui";

export default function AuthShell({ title, subtitle, children, footer }) {
  return (
    <div className="min-h-screen flex items-center justify-center p-5" style={{ backgroundColor: colors.inkDeep }}>
      <div className="w-full max-w-sm rounded-2xl p-7" style={{ backgroundColor: colors.paper }}>
        <Link href="/" className="flex items-center gap-2 mb-6">
          <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ backgroundColor: colors.gold }}>
            <BookOpen size={14} color={colors.ink} />
          </div>
          <span className="font-display text-base" style={{ color: colors.textPaper }}>Plume</span>
        </Link>
        <h1 className="font-display text-xl mb-1" style={{ color: colors.textPaper }}>{title}</h1>
        <p className="font-body text-sm mb-6" style={{ color: colors.textPaperDim }}>{subtitle}</p>
        <div className="flex flex-col gap-2.5">{children}</div>
        <div className="mt-5 text-center">{footer}</div>
      </div>
    </div>
  );
}
