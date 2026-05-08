// ─── Screens 3: Shopping List + Profile + Account + Login + Create ───
const { TOKENS: T3, FONTS: F3, EyebrowLabel: Eb3, Display: D3, Body: B3,
        PillButton: PB3, Stamp: St3, StateBadge: Sb3, MiniStatusBar: MSB3,
        Photo: P3, Sprig: Sp3, SectionHead: SH3 } = window.SEASON_UI;
const { RECIPES: R3, SHOPPING } = window.SEASON_DATA;

// ════════════════════════════════════════════════════════════════
// SHOPPING LIST
// ════════════════════════════════════════════════════════════════
function ShoppingScreen() {
  return (
    <div style={{ background: T3.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB3 />

      <div style={{ padding: '6px 22px 24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <Eb3 size={9} color={T3.inkMuted}>YOUR LIST · MARKET DAY SAT</Eb3>
            <D3 size={36} style={{ marginTop: 6, fontStyle: 'italic' }}>To Gather</D3>
            <B3 size={13} color={T3.inkMuted} style={{ marginTop: 6, fontFamily: F3.serif, fontStyle: 'italic' }}>8 items across 2 recipes.</B3>
          </div>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 18, color: T3.ink }}>⤴</button>
        </div>
        {/* stats — large editorial */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', marginTop: 24, paddingTop: 20, borderTop: `1px solid ${T3.inset}` }}>
          {[
            { v: '08', l: 'TOTAL ITEMS' },
            { v: '02', l: 'RECIPES' },
            { v: '01', l: 'MANUAL' },
          ].map((s, i) => (
            <div key={i}>
              <div style={{ fontFamily: F3.display, fontSize: 38, color: T3.ink, lineHeight: 1, fontWeight: 400 }}>{s.v}</div>
              <div style={{ fontFamily: F3.mono, fontSize: 9, color: T3.inkMuted, marginTop: 8, letterSpacing: '0.12em' }}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Sections */}
      {SHOPPING.map((sec, si) => (
        <div key={si} style={{ marginBottom: 28 }}>
          <div style={{ padding: '0 22px 14px' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 6 }}>
              <div style={{
                width: 8, height: 8, borderRadius: '50%',
                background: sec.section.startsWith('Other') ? T3.terracotta : T3.sage,
              }}/>
              <Eb3 size={9} color={T3.inkMuted}>RECIPE {String(si + 1).padStart(2, '0')}</Eb3>
            </div>
            <div style={{ fontFamily: F3.display, fontSize: 18, color: T3.ink, fontStyle: 'italic', lineHeight: 1.2 }}>
              {sec.section}
            </div>
          </div>
          <div style={{ padding: '0 22px' }}>
            {sec.items.map((it, i) => {
              const checked = it.state === 'in-fridge';
              return (
                <div key={i} style={{
                  display: 'flex', alignItems: 'center', gap: 14,
                  padding: '16px 0',
                  borderBottom: i < sec.items.length - 1 ? `1px dotted ${T3.inset}` : 'none',
                  opacity: checked ? 0.55 : 1,
                }}>
                  <div style={{
                    width: 22, height: 22, borderRadius: '50%',
                    border: `1.5px solid ${checked ? T3.sage : T3.inkMuted}`,
                    background: checked ? T3.sage : 'transparent',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: '#fff', fontSize: 11, flexShrink: 0,
                  }}>{checked ? '✓' : ''}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{
                      fontFamily: F3.serif, fontSize: 17, color: T3.ink,
                      textDecoration: checked ? 'line-through' : 'none',
                      lineHeight: 1.1,
                    }}>{it.name}</div>
                    <div style={{ fontFamily: F3.mono, fontSize: 10, color: T3.inkMuted, marginTop: 4, letterSpacing: '0.05em' }}>
                      {it.qty}
                    </div>
                  </div>
                  <Sb3 state={it.state}/>
                </div>
              );
            })}
          </div>
        </div>
      ))}

      {/* Footer add btn */}
      <div style={{ padding: '8px 22px 20px' }}>
        <button style={{
          width: '100%', padding: '16px',
          background: 'transparent', border: `1px dashed ${T3.inset}`, borderRadius: 4,
          fontFamily: F3.serif, fontSize: 15, color: T3.inkMuted, fontStyle: 'italic',
          cursor: 'pointer',
        }}>+ Add an item by hand</button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// PROFILE (public — Elena Vance)
// ════════════════════════════════════════════════════════════════
function ProfileScreen() {
  return (
    <div style={{ background: T3.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB3 />
      <div style={{ padding: '6px 16px 12px', display: 'flex', justifyContent: 'space-between' }}>
        <button style={{ background: 'none', border: 'none', fontSize: 20, color: T3.ink, cursor: 'pointer' }}>‹</button>
        <button style={{ background: 'none', border: 'none', fontSize: 14, color: T3.ink, cursor: 'pointer' }}>⤴</button>
      </div>

      {/* Editorial bio block */}
      <div style={{ padding: '16px 22px 28px', textAlign: 'center' }}>
        <div style={{ position: 'relative', width: 110, height: 110, margin: '0 auto' }}>
          <div style={{ width: 110, height: 110, borderRadius: '50%', overflow: 'hidden', background: '#d6cfbe' }}>
            <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=240&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
          </div>
          <div style={{ position: 'absolute', bottom: -4, right: -4 }}>
            <St3 color={T3.terracotta} size={42}>VERIFIED</St3>
          </div>
        </div>
        <D3 size={36} style={{ marginTop: 18, fontStyle: 'italic' }}>Elena Vance</D3>
        <div style={{ fontFamily: F3.serif, fontSize: 14, color: T3.inkMuted, fontStyle: 'italic', marginTop: 4 }}>Chef · Forager · Bologna</div>
        <B3 size={13} style={{ marginTop: 16, fontFamily: F3.serif, fontStyle: 'italic', maxWidth: 280, marginLeft: 'auto', marginRight: 'auto', color: T3.inkSoft }}>
          "I cook what the land gives. Slow, seasonal, and honest. Forty recipes from my garden."
        </B3>
        <div style={{ marginTop: 22 }}>
          <PB3 dark style={{ padding: '12px 36px', fontSize: 13, letterSpacing: '0.06em', textTransform: 'uppercase' }}>Follow</PB3>
        </div>
      </div>

      {/* Stats — editorial table */}
      <div style={{ padding: '0 22px 28px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', borderTop: `1px solid ${T3.inset}`, borderBottom: `1px solid ${T3.inset}` }}>
          {[
            { v: '12.4k', l: 'FOLLOWERS' },
            { v: '84', l: 'RECIPES' },
            { v: '4.9', l: 'RATING' },
          ].map((s, i) => (
            <div key={i} style={{ padding: '20px 0', textAlign: 'center', borderRight: i < 2 ? `1px solid ${T3.inset}` : 'none' }}>
              <div style={{ fontFamily: F3.display, fontSize: 26, color: T3.ink, lineHeight: 1, fontWeight: 400 }}>{s.v}</div>
              <div style={{ fontFamily: F3.mono, fontSize: 9, color: T3.inkMuted, marginTop: 8, letterSpacing: '0.12em' }}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Published — masonry-ish editorial */}
      <SH3 eyebrow="PUBLISHED · 12 RECIPES" title="From Elena's Table" />
      <div style={{ padding: '0 22px' }}>
        {[
          { ...R3[0], match: '5/5', mins: 45, copy: "A seasonal classic, slow-roasted local squash, finished with charred sage." },
          { title: 'Winter Kale & Pomegranate Salad', mins: 15, image: 'https://images.unsplash.com/photo-1607532941433-304659e8198a?w=600&q=80', copy: 'Bitter greens, jeweled fruit, salty pecorino. A late-November lunch.' },
          { title: 'Honey-Glazed Heirloom Roots', mins: 35, image: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=600&q=80', copy: "Carrots, beets, parsnips. The sweetness coaxed out by a long bake." },
        ].map((r, i) => (
          <div key={i} style={{ marginBottom: 28 }}>
            <P3 src={r.image} ratio={1.5} radius={2}>
              {r.match && (
                <div style={{ position: 'absolute', top: 12, left: 12, background: 'rgba(244,241,234,0.92)', padding: '4px 8px', borderRadius: 3 }}>
                  <span style={{ fontFamily: F3.mono, fontSize: 9, letterSpacing: '0.1em', color: T3.terracotta }}>{r.match} MATCH</span>
                </div>
              )}
              <div style={{ position: 'absolute', top: 12, right: 12, background: 'rgba(244,241,234,0.92)', padding: '4px 8px', borderRadius: 3 }}>
                <span style={{ fontFamily: F3.mono, fontSize: 9, letterSpacing: '0.1em', color: T3.ink }}>{r.mins} MIN</span>
              </div>
            </P3>
            <div style={{ marginTop: 14 }}>
              <Eb3 size={9} color={T3.inkMuted}>RECIPE №{String(i + 1).padStart(2, '0')}</Eb3>
              <D3 size={22} style={{ marginTop: 6, fontStyle: 'italic' }}>{r.title}</D3>
              <B3 size={13} style={{ marginTop: 8, fontFamily: F3.serif, color: T3.inkMuted }}>{r.copy}</B3>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// ACCOUNT (private settings)
// ════════════════════════════════════════════════════════════════
function AccountScreen() {
  return (
    <div style={{ background: T3.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB3 />
      <div style={{ padding: '6px 16px 12px', display: 'flex', justifyContent: 'space-between' }}>
        <button style={{ background: 'none', border: 'none', fontSize: 20, color: T3.ink, cursor: 'pointer' }}>⚙</button>
        <button style={{ background: 'none', border: 'none', fontSize: 18, color: T3.ink, cursor: 'pointer' }}>⏻</button>
      </div>

      {/* Hero — small */}
      <div style={{ padding: '8px 22px 20px', textAlign: 'center' }}>
        <div style={{ width: 88, height: 88, borderRadius: '50%', margin: '0 auto', overflow: 'hidden' }}>
          <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
        </div>
        <D3 size={28} style={{ marginTop: 14, fontStyle: 'italic' }}>Elena Vance</D3>
        <div style={{ fontFamily: F3.mono, fontSize: 10, color: T3.inkMuted, marginTop: 4, letterSpacing: '0.1em' }}>@ELENAVANCE</div>
        <div style={{ marginTop: 12, display: 'flex', justifyContent: 'center', gap: 8 }}>
          <div style={{ padding: '5px 12px', borderRadius: 9999, background: '#e8efe0' }}>
            <span style={{ fontFamily: F3.mono, fontSize: 9, color: T3.sage, letterSpacing: '0.1em' }}>SEASONED CHEF</span>
          </div>
          <div style={{ padding: '5px 12px', borderRadius: 9999, background: T3.terracottaSoft }}>
            <span style={{ fontFamily: F3.mono, fontSize: 9, color: T3.terracotta, letterSpacing: '0.1em' }}>LOCAL HARVESTER</span>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div style={{ padding: '0 22px 24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', borderTop: `1px solid ${T3.inset}`, borderBottom: `1px solid ${T3.inset}` }}>
          {[
            { v: '42', l: 'SAVED' },
            { v: '12', l: 'PUBLISHED' },
            { v: '08', l: 'DRAFTS' },
          ].map((s, i) => (
            <div key={i} style={{ padding: '18px 0', textAlign: 'center', borderRight: i < 2 ? `1px solid ${T3.inset}` : 'none' }}>
              <div style={{ fontFamily: F3.display, fontSize: 28, color: T3.ink, lineHeight: 1 }}>{s.v}</div>
              <div style={{ fontFamily: F3.mono, fontSize: 9, color: T3.inkMuted, marginTop: 6, letterSpacing: '0.12em' }}>{s.l}</div>
            </div>
          ))}
        </div>
        <div style={{ textAlign: 'center', marginTop: 14 }}>
          <span style={{ fontFamily: F3.serif, fontSize: 13, color: T3.terracotta, fontStyle: 'italic' }}>View public profile →</span>
        </div>
      </div>

      {/* Library — editorial list */}
      <div style={{ padding: '0 22px 24px' }}>
        <Eb3 color={T3.inkMuted}>MY LIBRARY</Eb3>
        <div style={{ marginTop: 14 }}>
          {[
            { l: 'Saved Recipes', n: 42, g: '◉' },
            { l: 'My Published Recipes', n: 12, g: '◐' },
            { l: 'Drafts', n: 8, g: '◯' },
            { l: 'Archived', n: 0, g: '◌' },
          ].map((r, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 16,
              padding: '18px 0', borderBottom: i < 3 ? `1px dotted ${T3.inset}` : 'none',
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: '50%',
                background: T3.vellumWarm, color: T3.sage,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 14,
              }}>{r.g}</div>
              <div style={{ fontFamily: F3.serif, fontSize: 17, color: T3.ink, flex: 1 }}>{r.l}</div>
              <span style={{ fontFamily: F3.mono, fontSize: 11, color: T3.inkMuted, letterSpacing: '0.05em' }}>{String(r.n).padStart(2, '0')}</span>
              <span style={{ color: T3.inkMuted, fontSize: 14 }}>›</span>
            </div>
          ))}
        </div>
      </div>

      {/* Create */}
      <div style={{ padding: '0 22px 28px' }}>
        <PB3 dark full icon style={{ padding: '16px', fontSize: 13, letterSpacing: '0.06em', textTransform: 'uppercase' }}>+ Create New Recipe</PB3>
      </div>

      {/* Preferences */}
      <div style={{ padding: '0 22px 24px' }}>
        <Eb3 color={T3.inkMuted}>ACCOUNT & PREFERENCES</Eb3>
        <div style={{ marginTop: 14 }}>
          {[
            { l: 'Linked to Apple ID', sub: 'Authentication', v: '' },
            { l: 'Edit Social Links', sub: '', v: '' },
            { l: 'Language Preference', sub: 'English (US)', v: '' },
            { l: 'Nutrition Preferences', sub: 'Vegetarian · High Protein', v: '' },
          ].map((r, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '16px 0', borderBottom: i < 3 ? `1px dotted ${T3.inset}` : 'none',
            }}>
              <div style={{ flex: 1 }}>
                {r.sub && <div style={{ fontFamily: F3.mono, fontSize: 8, color: T3.inkMuted, letterSpacing: '0.12em', marginBottom: 4 }}>{r.sub.toUpperCase()}</div>}
                <div style={{ fontFamily: F3.serif, fontSize: 15, color: T3.ink }}>{r.l}</div>
              </div>
              <span style={{ color: T3.inkMuted, fontSize: 14 }}>›</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '8px 22px 8px', textAlign: 'center' }}>
        <span style={{ fontFamily: F3.serif, fontSize: 14, color: T3.terracotta, fontStyle: 'italic' }}>Log out</span>
      </div>

      <div style={{ padding: '20px 22px 60px', textAlign: 'center' }}>
        <Sp3 size={18} color={T3.inkMuted} style={{ opacity: 0.4, margin: '0 auto 8px', display: 'block' }}/>
        <div style={{ fontFamily: F3.mono, fontSize: 9, color: T3.inkMuted, letterSpacing: '0.18em' }}>
          SEASON · v2.4.1
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// LOGIN
// ════════════════════════════════════════════════════════════════
function LoginScreen() {
  return (
    <div style={{ background: T3.ink, minHeight: '100%', position: 'relative', overflow: 'hidden' }}>
      {/* Hero image — bleed full */}
      <div style={{ position: 'absolute', inset: 0 }}>
        <img src="https://images.unsplash.com/photo-1542838132-92c53300491e?w=900&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover', opacity: 0.55 }}/>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(29,31,28,0.4) 0%, rgba(29,31,28,0.95) 75%)' }}/>
      </div>

      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <MSB3 dark/>

        {/* Top — minimal */}
        <div style={{ padding: '20px 22px 0', textAlign: 'center' }}>
          <Sp3 size={32} color="rgba(255,255,255,0.7)" style={{ margin: '0 auto', display: 'block' }}/>
          <div style={{ fontFamily: F3.display, fontSize: 28, color: '#fff', marginTop: 16, fontStyle: 'italic' }}>Season</div>
          <div style={{ fontFamily: F3.mono, fontSize: 9, color: 'rgba(255,255,255,0.5)', marginTop: 6, letterSpacing: '0.2em' }}>EST. MMXXVI</div>
        </div>

        <div style={{ flex: 1 }}/>

        {/* Bottom — masthead + auth */}
        <div style={{ padding: '0 22px 60px' }}>
          <Eb3 size={9} color="rgba(255,255,255,0.6)">ISSUE 47 · OCTOBER</Eb3>
          <D3 size={42} color="#fff" style={{ marginTop: 12, fontStyle: 'italic' }}>
            Cook with the<br/>
            <span style={{ fontStyle: 'normal' }}>land,</span><br/>
            <span style={{ fontStyle: 'italic' }}>not against it.</span>
          </D3>
          <B3 size={14} color="rgba(255,255,255,0.7)" style={{ marginTop: 16, fontFamily: F3.serif, fontStyle: 'italic', maxWidth: 300 }}>
            A field guide to seasonal cooking — built around what's growing, near you, right now.
          </B3>

          <div style={{ marginTop: 36, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <button style={{
              padding: '16px', borderRadius: 9999, border: 'none',
              background: '#fff', color: T3.ink,
              fontFamily: F3.sans, fontSize: 14, fontWeight: 500,
              cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            }}>
              <span style={{ fontSize: 16 }}></span> Continue with Apple
            </button>
            <button style={{
              padding: '16px', borderRadius: 9999,
              background: 'transparent', border: '1px solid rgba(255,255,255,0.25)', color: '#fff',
              fontFamily: F3.sans, fontSize: 14, fontWeight: 500, cursor: 'pointer',
            }}>Continue with Email</button>
          </div>

          <div style={{ marginTop: 22, textAlign: 'center' }}>
            <span style={{ fontFamily: F3.mono, fontSize: 10, color: 'rgba(255,255,255,0.5)', letterSpacing: '0.1em' }}>
              ALREADY A SUBSCRIBER? <span style={{ color: '#fff', textDecoration: 'underline' }}>SIGN IN</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// CREATE RECIPE
// ════════════════════════════════════════════════════════════════
function CreateScreen() {
  return (
    <div style={{ background: T3.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB3 />
      <div style={{ padding: '6px 16px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <button style={{ background: 'none', border: 'none', fontFamily: F3.sans, fontSize: 14, color: T3.inkMuted, cursor: 'pointer' }}>Cancel</button>
        <Eb3 size={9} color={T3.inkMuted}>NEW DISPATCH · DRAFT</Eb3>
        <button style={{ background: 'none', border: 'none', fontFamily: F3.sans, fontSize: 14, color: T3.terracotta, fontWeight: 500, cursor: 'pointer' }}>Publish</button>
      </div>

      {/* Photo upload */}
      <div style={{ padding: '12px 22px 0' }}>
        <div style={{
          width: '100%', aspectRatio: '4/3', borderRadius: 4,
          background: T3.vellumWarm, border: `1px dashed ${T3.inset}`,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10,
        }}>
          <div style={{ fontFamily: F3.display, fontSize: 28, color: T3.inkMuted, fontStyle: 'italic', opacity: 0.5 }}>+</div>
          <div style={{ fontFamily: F3.serif, fontSize: 14, color: T3.inkMuted, fontStyle: 'italic' }}>Add the hero shot</div>
          <div style={{ fontFamily: F3.mono, fontSize: 9, color: T3.inkMuted, letterSpacing: '0.1em' }}>JPG · 4:3 RECOMMENDED</div>
        </div>
      </div>

      {/* Title input */}
      <div style={{ padding: '28px 22px 8px' }}>
        <Eb3 color={T3.terracotta}>TITLE</Eb3>
        <input
          defaultValue="Untitled draft"
          style={{
            width: '100%', marginTop: 10,
            background: 'transparent', border: 'none', outline: 'none',
            fontFamily: F3.display, fontSize: 32, color: T3.ink, fontStyle: 'italic',
            padding: '8px 0', borderBottom: `1px solid ${T3.inset}`,
            letterSpacing: '-0.02em',
          }}
        />
      </div>

      {/* Description */}
      <div style={{ padding: '20px 22px 8px' }}>
        <Eb3 color={T3.inkMuted}>NOTE / INTRO</Eb3>
        <div style={{
          marginTop: 10, padding: '14px 16px', background: T3.card, borderRadius: 4,
          fontFamily: F3.serif, fontSize: 15, color: T3.inkMuted, fontStyle: 'italic',
          minHeight: 80, lineHeight: 1.5,
        }}>
          Tell the story behind this dish…
        </div>
      </div>

      {/* Meta strip */}
      <div style={{ padding: '20px 22px 8px' }}>
        <Eb3 color={T3.inkMuted}>METADATA</Eb3>
        <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
          {[
            { l: 'TIME', v: '— min' },
            { l: 'SERVES', v: '4' },
            { l: 'SEASON', v: 'Autumn' },
          ].map((f, i) => (
            <div key={i} style={{ background: T3.card, padding: '12px 14px', borderRadius: 4 }}>
              <div style={{ fontFamily: F3.mono, fontSize: 8, color: T3.inkMuted, letterSpacing: '0.1em' }}>{f.l}</div>
              <div style={{ fontFamily: F3.display, fontSize: 18, color: T3.ink, marginTop: 4 }}>{f.v}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Ingredients */}
      <div style={{ padding: '24px 22px 8px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <Eb3 color={T3.terracotta}>INGREDIENTS · 0</Eb3>
          <span style={{ fontFamily: F3.serif, fontSize: 13, color: T3.terracotta, fontStyle: 'italic' }}>+ Add</span>
        </div>
        <div style={{
          marginTop: 14, padding: '32px 14px', background: T3.card, borderRadius: 4,
          textAlign: 'center', border: `1px dashed ${T3.inset}`,
        }}>
          <div style={{ fontFamily: F3.serif, fontSize: 14, color: T3.inkMuted, fontStyle: 'italic' }}>
            Start with what's in season.<br/>Pull from your fridge to autocomplete.
          </div>
        </div>
      </div>

      {/* Steps */}
      <div style={{ padding: '24px 22px 60px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <Eb3 color={T3.terracotta}>METHOD · 0 STEPS</Eb3>
          <span style={{ fontFamily: F3.serif, fontSize: 13, color: T3.terracotta, fontStyle: 'italic' }}>+ Add</span>
        </div>
        <div style={{
          marginTop: 14, padding: '32px 14px', background: T3.card, borderRadius: 4,
          textAlign: 'center', border: `1px dashed ${T3.inset}`,
        }}>
          <div style={{ fontFamily: F3.serif, fontSize: 14, color: T3.inkMuted, fontStyle: 'italic' }}>
            Number the steps. Keep them honest.
          </div>
        </div>
      </div>
    </div>
  );
}

window.SCREENS_C = { ShoppingScreen, ProfileScreen, AccountScreen, LoginScreen, CreateScreen };
