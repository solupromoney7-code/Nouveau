// Composants visuels partagés — repris du prototype validé, pour que le
// vrai site ait exactement la même identité visuelle.

export const colors = {
  ink: "#1C2033",
  inkDeep: "#14172A",
  paper: "#F7F3E9",
  paperDim: "#EDE6D3",
  gold: "#C9A227",
  goldDark: "#A5821A",
  wine: "#7A2E3B",
  mist: "#9498AC",
  forest: "#4F7A5C",
  textPaper: "#241F17",
  textPaperDim: "#4A4232",
  bgLight: "#FBF9F4",
  bgLightAlt: "#F4F1E9",
  sage: "#6B9080",
  sageDark: "#547567",
  sky: "#5B7FA6",
  textMutedLight: "#70748C",
};

export const inputStyle = {
  backgroundColor: colors.paperDim,
  color: colors.textPaper,
  border: "none",
};

// Couverture de livre. Si une vraie image a été fournie par l'auteur, elle
// est affichée en pleine case (comme une vraie couverture de livre). Sinon,
// une couverture générée (dégradé + titre + auteur) sert de solution de
// repli élégante.
export function BookCover({ title, author, imageUrl, size = "md" }) {
  // "hero" : grande couverture des pages publiques, qui s'adapte à la largeur
  // de l'écran (grande sur mobile, bien proportionnée sur ordinateur).
  const hero = size === "hero";
  const dims =
    size === "sm" ? { w: 88, h: 128 } : size === "lg" ? { w: 160, h: 230 } : { w: 120, h: 172 };
  const boxStyle = hero
    ? { width: "clamp(190px, 62vw, 240px)", aspectRatio: "5 / 7" }
    : { width: dims.w, height: dims.h };
  const heroShadow = hero ? { boxShadow: "0 24px 48px -16px rgba(28,32,51,0.45), 0 8px 16px -8px rgba(28,32,51,0.25)" } : {};

  if (imageUrl) {
    return (
      <div
        className="shrink-0 rounded-md overflow-hidden shadow-lg"
        style={{
          ...boxStyle,
          ...heroShadow,
          border: "1px solid rgba(28,32,51,0.12)",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={imageUrl}
          alt={title}
          className="w-full h-full object-cover"
          style={{ display: "block" }}
        />
      </div>
    );
  }

  return (
    <div
      className="shrink-0 rounded-md flex flex-col justify-between p-3 shadow-lg"
      style={{
        ...boxStyle,
        ...heroShadow,
        backgroundImage: `linear-gradient(150deg, ${colors.wine}, ${colors.ink})`,
        border: "1px solid rgba(201,162,39,0.35)",
      }}
    >
      <div className="w-6" style={{ height: 2, backgroundColor: colors.gold }} />
      <p className="font-display leading-tight" style={{ color: colors.paper, fontSize: size === "sm" ? 12 : hero ? 20 : 15 }}>
        {title}
      </p>
      <p className="font-mono uppercase tracking-wide" style={{ color: colors.mist, fontSize: 9 }}>
        {author}
      </p>
    </div>
  );
}

// Champ de texte "cliquer pour modifier" sur une seule ligne — utilisé pour
// le titre du livre dans le tableau de bord.
export function EditableTitle({ value, onChange, onBlurExtra, className, style, placeholder }) {
  return (
    <input
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      className={className}
      style={{
        background: "transparent",
        border: "none",
        outline: "none",
        borderBottom: "1px dashed transparent",
        ...style,
      }}
      onFocus={(e) => { e.target.style.borderBottomColor = colors.gold; }}
      onBlur={(e) => {
        e.target.style.borderBottomColor = "transparent";
        if (onBlurExtra) onBlurExtra();
      }}
    />
  );
}

// Bloc d'erreur réutilisé sur tous les formulaires.
export function ErrorBanner({ message }) {
  if (!message) return null;
  return (
    <div
      className="rounded-lg px-3 py-2.5 font-body text-xs"
      style={{ backgroundColor: "rgba(122,46,59,0.1)", border: `1px solid ${colors.wine}`, color: colors.wine }}
    >
      {message}
    </div>
  );
}

export function Spinner({ size = 16, color }) {
  return (
    <span
      className="inline-block animate-spin rounded-full"
      style={{
        width: size,
        height: size,
        border: `2px solid ${color || colors.gold}`,
        borderTopColor: "transparent",
      }}
    />
  );
}
