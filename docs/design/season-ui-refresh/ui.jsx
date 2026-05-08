// Shared UI primitives for Season redesign
// Color tokens from "Editorial Organicism" design system

const TOKENS = {
  // Surfaces — vellum stack
  vellum: '#f4f1ea',         // warmer than original — paper
  vellumWarm: '#ece7dd',     // section base
  card: '#ffffff',
  inset: '#e3ddd0',
  ink: '#1d1f1c',
  inkSoft: '#3a3d36',
  inkMuted: '#7a7c73',
  // Accents
  sage: '#526048',
  sageDeep: '#3d4a35',
  terracotta: '#a85a3c',
  terracottaSoft: '#f4d8c8',
  ochre: '#c89455',
  // Status
  fresh: '#6a8a4f',
  eatSoon: '#c46a3a',
  pantry: '#9a8b6a',
};

const FONTS = {
  display: '"Cormorant Garamond", "GT Sectra", Georgia, serif',
  serif: '"Cormorant Garamond", Georgia, serif',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", Menlo, monospace',
};

// ────────── Editorial label (ALL CAPS small) ──────────
function EyebrowLabel({ children, color, size = 11, style = {} }) {
  return (
    <div style={{
      fontFamily: FONTS.mono,
      fontSize: size,
      letterSpacing: '0.14em',
      textTransform: 'uppercase',
      color: color || TOKENS.terracotta,
      fontWeight: 500,
      ...style,
    }}>{children}</div>
  );
}

// ────────── Display heading (serif, asymmetric) ──────────
function Display({ children, size = 38, color, leading = 0.95, style = {} }) {
  return (
    <h1 style={{
      fontFamily: FONTS.display,
      fontSize: size,
      lineHeight: leading,
      letterSpacing: '-0.02em',
      fontWeight: 500,
      color: color || TOKENS.ink,
      margin: 0,
      textWrap: 'balance',
      ...style,
    }}>{children}</h1>
  );
}

// ────────── Body text ──────────
function Body({ children, size = 14, color, style = {} }) {
  return (
    <p style={{
      fontFamily: FONTS.sans,
      fontSize: size,
      lineHeight: 1.5,
      color: color || TOKENS.inkSoft,
      margin: 0,
      ...style,
    }}>{children}</p>
  );
}

// ────────── Pill button ──────────
function PillButton({ children, dark = true, full = false, icon, onClick, style = {} }) {
  return (
    <button onClick={onClick} style={{
      background: dark ? `linear-gradient(135deg, ${TOKENS.sage}, ${TOKENS.sageDeep})` : TOKENS.card,
      color: dark ? '#fff' : TOKENS.ink,
      border: 'none',
      borderRadius: 9999,
      padding: '14px 22px',
      fontFamily: FONTS.sans,
      fontSize: 14,
      fontWeight: 500,
      letterSpacing: '0.01em',
      cursor: 'pointer',
      width: full ? '100%' : 'auto',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 8,
      boxShadow: dark ? '0 2px 12px rgba(61,74,53,0.18)' : '0 1px 0 rgba(29,31,28,0.04)',
      ...style,
    }}>
      {children}
      {icon && <span style={{ fontFamily: FONTS.sans, fontWeight: 400 }}>→</span>}
    </button>
  );
}

// ────────── Stamp (round seal — like a market stamp) ──────────
function Stamp({ children, color, size = 56 }) {
  const c = color || TOKENS.terracotta;
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      border: `1.5px solid ${c}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: FONTS.mono, fontSize: 9, color: c,
      letterSpacing: '0.1em', textAlign: 'center', lineHeight: 1.1,
      transform: 'rotate(-6deg)',
      padding: 6, boxSizing: 'border-box',
    }}>{children}</div>
  );
}

// ────────── State badge for ingredients (in-stock / missing / soon) ──────────
function StateBadge({ state }) {
  const config = {
    'in-stock': { c: TOKENS.fresh, bg: '#e8efe0', label: 'IN FRIDGE' },
    'missing': { c: TOKENS.terracotta, bg: TOKENS.terracottaSoft, label: 'MISSING' },
    'pantry': { c: TOKENS.pantry, bg: '#ece7dd', label: 'PANTRY' },
    'fresh': { c: TOKENS.fresh, bg: '#e8efe0', label: 'FRESH' },
    'eat-soon': { c: TOKENS.terracotta, bg: TOKENS.terracottaSoft, label: 'EAT SOON' },
    'in-fridge': { c: TOKENS.fresh, bg: '#e8efe0', label: 'IN FRIDGE' },
  }[state] || { c: TOKENS.inkMuted, bg: '#eee', label: state };
  return (
    <span style={{
      fontFamily: FONTS.mono, fontSize: 9, letterSpacing: '0.12em',
      color: config.c, background: config.bg,
      padding: '4px 8px', borderRadius: 4,
      textTransform: 'uppercase', fontWeight: 500,
      whiteSpace: 'nowrap',
    }}>{config.label}</span>
  );
}

// ────────── Bottom Tab Bar (5 tabs, organic style) ──────────
function TabBar({ active = 'home', onChange }) {
  const tabs = [
    { id: 'home', label: 'Home', glyph: '◐' },
    { id: 'discover', label: 'Discover', glyph: '✦' },
    { id: 'fridge', label: 'Fridge', glyph: '◧' },
    { id: 'list', label: 'List', glyph: '≡' },
    { id: 'profile', label: 'Profile', glyph: '○' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 22, paddingTop: 10,
      background: 'linear-gradient(to top, rgba(244,241,234,0.96) 60%, rgba(244,241,234,0))',
      backdropFilter: 'blur(8px)',
      WebkitBackdropFilter: 'blur(8px)',
      zIndex: 30,
    }}>
      <div style={{
        display: 'flex', justifyContent: 'space-around',
        padding: '0 8px',
      }}>
        {tabs.map(t => {
          const isActive = active === t.id;
          return (
            <button key={t.id} onClick={() => onChange && onChange(t.id)} style={{
              background: 'none', border: 'none', cursor: 'pointer',
              padding: '6px 10px', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 4, position: 'relative',
            }}>
              <div style={{
                fontFamily: FONTS.serif, fontSize: 22,
                color: isActive ? TOKENS.sage : TOKENS.inkMuted,
                lineHeight: 1, fontWeight: 500,
                fontStyle: t.id === 'discover' ? 'italic' : 'normal',
              }}>{t.glyph}</div>
              <div style={{
                fontFamily: FONTS.mono, fontSize: 9,
                letterSpacing: '0.12em', textTransform: 'uppercase',
                color: isActive ? TOKENS.ink : TOKENS.inkMuted,
                fontWeight: isActive ? 500 : 400,
              }}>{t.label}</div>
              {isActive && (
                <div style={{
                  position: 'absolute', top: -4,
                  width: 4, height: 4, borderRadius: '50%',
                  background: TOKENS.terracotta,
                }} />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ────────── Status bar (light, transparent) ──────────
function MiniStatusBar({ dark = false, time = '9:41' }) {
  const c = dark ? '#fff' : TOKENS.ink;
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '16px 28px 6px', position: 'relative', zIndex: 20,
      fontFamily: '-apple-system, system-ui', fontWeight: 600,
      fontSize: 15, color: c,
    }}>
      <span>{time}</span>
      <div style={{ width: 100 }} />
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="16" height="10" viewBox="0 0 16 10"><rect x="0" y="6" width="2.5" height="4" rx="0.5" fill={c}/><rect x="4" y="4" width="2.5" height="6" rx="0.5" fill={c}/><rect x="8" y="2" width="2.5" height="8" rx="0.5" fill={c}/><rect x="12" y="0" width="2.5" height="10" rx="0.5" fill={c}/></svg>
        <svg width="22" height="11" viewBox="0 0 22 11"><rect x="0.5" y="0.5" width="19" height="10" rx="2.5" stroke={c} strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="16" height="7" rx="1.5" fill={c}/></svg>
      </div>
    </div>
  );
}

// ────────── Photo with subtle warm overlay ──────────
function Photo({ src, alt = '', radius = 0, height, ratio, style = {}, children }) {
  return (
    <div style={{
      position: 'relative', overflow: 'hidden',
      borderRadius: radius, width: '100%',
      height: height || (ratio ? 0 : 'auto'),
      paddingBottom: ratio ? `${(1/ratio)*100}%` : 0,
      background: TOKENS.inset,
      ...style,
    }}>
      <img src={src} alt={alt} style={{
        position: ratio ? 'absolute' : 'relative',
        inset: 0, width: '100%', height: ratio ? '100%' : (height || 'auto'),
        objectFit: 'cover', display: 'block',
      }}/>
      {children}
    </div>
  );
}

// ────────── Tiny botanical accent SVG ──────────
function Sprig({ size = 28, color, style = {} }) {
  const c = color || TOKENS.sage;
  return (
    <svg width={size} height={size} viewBox="0 0 28 28" style={style} fill="none">
      <path d="M14 26 C14 14, 14 8, 14 2" stroke={c} strokeWidth="0.8" strokeLinecap="round"/>
      <path d="M14 8 C9 8, 6 5, 6 5" stroke={c} strokeWidth="0.8" strokeLinecap="round"/>
      <path d="M14 12 C19 12, 22 9, 22 9" stroke={c} strokeWidth="0.8" strokeLinecap="round"/>
      <path d="M14 16 C9 16, 6 13, 6 13" stroke={c} strokeWidth="0.8" strokeLinecap="round"/>
      <path d="M14 20 C19 20, 22 17, 22 17" stroke={c} strokeWidth="0.8" strokeLinecap="round"/>
      <ellipse cx="6" cy="5" rx="3" ry="1.2" fill={c} opacity="0.6" transform="rotate(-30 6 5)"/>
      <ellipse cx="22" cy="9" rx="3" ry="1.2" fill={c} opacity="0.6" transform="rotate(30 22 9)"/>
      <ellipse cx="6" cy="13" rx="3" ry="1.2" fill={c} opacity="0.6" transform="rotate(-30 6 13)"/>
      <ellipse cx="22" cy="17" rx="3" ry="1.2" fill={c} opacity="0.6" transform="rotate(30 22 17)"/>
    </svg>
  );
}

// ────────── Section divider with eyebrow + rule ──────────
function SectionHead({ eyebrow, title, action, eyebrowColor }) {
  return (
    <div style={{ padding: '0 22px', marginBottom: 14 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
        <EyebrowLabel color={eyebrowColor}>{eyebrow}</EyebrowLabel>
        <div style={{ flex: 1, height: 1, background: TOKENS.inset, marginBottom: 4 }}/>
        {action && (
          <button style={{
            background: 'none', border: 'none', cursor: 'pointer',
            fontFamily: FONTS.sans, fontSize: 12, color: TOKENS.inkMuted,
            fontStyle: 'italic',
          }}>{action} →</button>
        )}
      </div>
      <Display size={26} style={{ marginTop: 6 }}>{title}</Display>
    </div>
  );
}

window.SEASON_UI = {
  TOKENS, FONTS,
  EyebrowLabel, Display, Body,
  PillButton, Stamp, StateBadge,
  TabBar, MiniStatusBar, Photo, Sprig, SectionHead,
};
