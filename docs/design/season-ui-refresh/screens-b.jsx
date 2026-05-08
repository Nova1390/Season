// ─── Screens 2: Ingredient Detail + Search/Discovery + Fridge ───
const { TOKENS: T2, FONTS: F2, EyebrowLabel: Eb2, Display: D2, Body: B2,
        PillButton: PB2, Stamp: St2, StateBadge: Sb2, MiniStatusBar: MSB2,
        Photo: P2, Sprig: Sp2, SectionHead: SH2 } = window.SEASON_UI;
const { RECIPES: R2, PRODUCE: PR2, INGREDIENT, FRIDGE } = window.SEASON_DATA;

// ════════════════════════════════════════════════════════════════
// INGREDIENT DETAIL — Arborio Rice
// ════════════════════════════════════════════════════════════════
function IngredientScreen() {
  const ing = INGREDIENT;
  const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
  return (
    <div style={{ background: T2.vellum, minHeight: '100%', paddingBottom: 110 }}>
      {/* Hero — circular image like a market still life */}
      <div style={{ position: 'relative', background: T2.vellumWarm, paddingBottom: 32 }}>
        <MSB2 />
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 16px 10px' }}>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: T2.ink }}>‹</button>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 14, color: T2.terracotta }}>♥</button>
        </div>
        <div style={{ position: 'relative', width: 240, height: 240, margin: '20px auto 0' }}>
          <P2 src={ing.hero} ratio={1} radius={9999}/>
          <div style={{ position: 'absolute', top: -8, right: -8 }}>
            <St2 color={T2.terracotta}>PERFECT<br/>IN<br/>SEASON</St2>
          </div>
        </div>
        <div style={{ textAlign: 'center', marginTop: 24, padding: '0 22px' }}>
          <Eb2 size={10} color={T2.inkMuted}>{ing.category.toUpperCase()}</Eb2>
          <D2 size={44} style={{ marginTop: 8, fontStyle: 'italic' }}>{ing.en}</D2>
          <div style={{ fontFamily: F2.serif, fontSize: 16, color: T2.inkMuted, fontStyle: 'italic', marginTop: 4 }}>{ing.it}</div>
        </div>
      </div>

      {/* Add to fridge CTA */}
      <div style={{ padding: '24px 22px 8px' }}>
        <PB2 dark full icon style={{ padding: '16px', fontSize: 13, letterSpacing: '0.06em', textTransform: 'uppercase' }}>Add to Fridge</PB2>
      </div>

      {/* About — pull quote */}
      <div style={{ padding: '24px 22px' }}>
        <Eb2 color={T2.terracotta}>NOTES</Eb2>
        <div style={{ marginTop: 12, paddingLeft: 16, borderLeft: `2px solid ${T2.terracotta}` }}>
          <B2 size={16} style={{ fontFamily: F2.serif, fontStyle: 'italic', color: T2.inkSoft, lineHeight: 1.55 }}>
            {ing.intro}
          </B2>
        </div>
      </div>

      {/* Harvest cycle — 12-month strip */}
      <div style={{ padding: '24px 22px', background: T2.vellumWarm, margin: '20px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 16 }}>
          <div>
            <Eb2 color={T2.sage}>HARVEST CYCLE</Eb2>
            <D2 size={22} style={{ marginTop: 4 }}>Peaks Sept – Nov</D2>
          </div>
          <div style={{ fontFamily: F2.mono, fontSize: 10, color: T2.inkMuted, letterSpacing: '0.1em' }}>YOU ARE HERE ↓</div>
        </div>
        {/* Month bars */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 56, marginBottom: 8 }}>
          {months.map((m, i) => {
            const month = i + 1;
            const isPeak = month >= ing.peakMonths.peakStart && month <= ing.peakMonths.peakEnd;
            const isCurrent = month === ing.peakMonths.current;
            const h = isPeak ? 56 : 18;
            return (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  width: '100%', height: h,
                  background: isCurrent ? T2.terracotta : isPeak ? T2.sage : T2.inset,
                  borderRadius: 1,
                }}/>
                <div style={{ fontFamily: F2.mono, fontSize: 9, color: isCurrent ? T2.terracotta : T2.inkMuted, fontWeight: isCurrent ? 600 : 400 }}>{m}</div>
              </div>
            );
          })}
        </div>
        <B2 size={11} color={T2.inkMuted} style={{ marginTop: 14, fontStyle: 'italic' }}>
          Available year-round, but most flavorful post-harvest in October.
        </B2>
      </div>

      {/* Origin & Pairings — two col */}
      <div style={{ padding: '0 22px 32px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <div>
          <Eb2 color={T2.inkMuted} size={9}>ORIGIN</Eb2>
          <div style={{ fontFamily: F2.serif, fontSize: 18, color: T2.ink, marginTop: 8, fontStyle: 'italic' }}>{ing.origin}</div>
        </div>
        <div>
          <Eb2 color={T2.inkMuted} size={9}>PAIRS WITH</Eb2>
          <div style={{ fontFamily: F2.serif, fontSize: 14, color: T2.inkSoft, marginTop: 8, lineHeight: 1.6 }}>
            {ing.pairings.join(', ')}
          </div>
        </div>
      </div>

      {/* What to cook — featured + small grid */}
      <SH2 eyebrow="WHAT TO COOK · 18 RECIPES" title="In the Kitchen With Arborio" action="See all" />
      <div style={{ padding: '0 22px' }}>
        <div style={{ position: 'relative', marginBottom: 22 }}>
          <P2 src={R2[0].image} ratio={1.4} radius={2}>
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.6), transparent 50%)' }}/>
            <div style={{ position: 'absolute', bottom: 14, left: 14, right: 14, color: '#fff' }}>
              <Eb2 size={9} color="rgba(255,255,255,0.7)">FEATURED · 5/5 MATCH</Eb2>
              <div style={{ fontFamily: F2.display, fontSize: 22, marginTop: 6, lineHeight: 1.05, fontStyle: 'italic' }}>
                Charred Sage & Butternut Risotto
              </div>
              <div style={{ fontFamily: F2.mono, fontSize: 9, color: 'rgba(255,255,255,0.7)', marginTop: 8, letterSpacing: '0.1em' }}>45 MIN · INTERMEDIATE</div>
            </div>
          </P2>
        </div>
        {[R2[2], R2[3]].map((r, i) => (
          <div key={i} style={{ display: 'flex', gap: 14, paddingBottom: 18, marginBottom: 18, borderBottom: i < 1 ? `1px solid ${T2.inset}` : 'none' }}>
            <div style={{ width: 76, flexShrink: 0 }}><P2 src={r.image} ratio={1} radius={2}/></div>
            <div style={{ flex: 1 }}>
              <Eb2 size={9} color={T2.terracotta}>{r.match} MATCH</Eb2>
              <div style={{ fontFamily: F2.display, fontSize: 17, color: T2.ink, marginTop: 6, lineHeight: 1.1 }}>{r.title}</div>
              <div style={{ fontFamily: F2.mono, fontSize: 9, color: T2.inkMuted, marginTop: 8, letterSpacing: '0.08em' }}>{r.minutes} MIN</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SEARCH / DISCOVERY
// ════════════════════════════════════════════════════════════════
function SearchScreen() {
  return (
    <div style={{ background: T2.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB2 />

      {/* Header */}
      <div style={{ padding: '6px 22px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <Eb2 size={9} color={T2.inkMuted}>EXPLORE</Eb2>
          <D2 size={36} style={{ marginTop: 6, fontStyle: 'italic' }}>Discovery</D2>
        </div>
        <div style={{ width: 40, height: 40, borderRadius: '50%', overflow: 'hidden' }}>
          <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
        </div>
      </div>

      {/* Search field */}
      <div style={{ padding: '0 22px 8px' }}>
        <div style={{
          background: T2.card, padding: '14px 18px', borderRadius: 4,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <span style={{ color: T2.inkMuted, fontSize: 14 }}>⌕</span>
          <span style={{ fontFamily: F2.serif, fontSize: 16, color: T2.inkMuted, fontStyle: 'italic' }}>What are you craving?</span>
        </div>
      </div>

      {/* Filter chips — editorial */}
      <div style={{ padding: '14px 22px 4px', display: 'flex', gap: 8, overflowX: 'auto', scrollbarWidth: 'none' }}>
        {[
          { l: 'Recipes', active: true },
          { l: 'Ingredients' },
          { l: 'Fridge ready' },
          { l: 'Quick · 30m' },
          { l: 'Vegetarian' },
        ].map((c, i) => (
          <div key={i} style={{
            padding: '8px 14px', borderRadius: 9999, flexShrink: 0,
            background: c.active ? T2.ink : 'transparent',
            border: c.active ? 'none' : `1px solid ${T2.inset}`,
            color: c.active ? T2.vellum : T2.inkSoft,
            fontFamily: F2.sans, fontSize: 12, fontWeight: 500,
          }}>{c.l}</div>
        ))}
      </div>

      {/* PEAK SEASON — circular */}
      <div style={{ marginTop: 28 }}>
        <div style={{ padding: '0 22px', marginBottom: 14, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div>
            <Eb2 color={T2.terracotta}>OCTOBER · WEEK 3</Eb2>
            <D2 size={24} style={{ marginTop: 4 }}>At Peak</D2>
          </div>
          <span style={{ fontFamily: F2.mono, fontSize: 10, color: T2.inkMuted, letterSpacing: '0.1em' }}>AUTUMN</span>
        </div>
        <div style={{ display: 'flex', gap: 12, padding: '0 22px', overflowX: 'auto', scrollbarWidth: 'none' }}>
          {PR2.slice(0, 5).map(p => (
            <div key={p.id} style={{ flexShrink: 0, width: 80, textAlign: 'center' }}>
              <P2 src={p.image} ratio={1} radius={9999} style={{ marginBottom: 8 }}/>
              <div style={{ fontFamily: F2.serif, fontSize: 14, color: T2.ink, fontStyle: 'italic', lineHeight: 1.1 }}>{p.en}</div>
              <div style={{ fontFamily: F2.mono, fontSize: 8, color: T2.inkMuted, marginTop: 4, letterSpacing: '0.1em' }}>{String(p.recipes).padStart(2,'0')} REC</div>
            </div>
          ))}
        </div>
      </div>

      {/* FROM YOUR FRIDGE — feature card */}
      <div style={{ marginTop: 36 }}>
        <SH2 eyebrow="3 OF 5 INGREDIENTS" title="From Your Fridge" />
        <div style={{ padding: '0 22px' }}>
          <div style={{ background: T2.card, borderRadius: 4, overflow: 'hidden' }}>
            <P2 src={R2[5].image} ratio={1.5}>
              <div style={{ position: 'absolute', top: 14, right: 14, background: T2.terracotta, color: '#fff', padding: '6px 10px', borderRadius: 4 }}>
                <span style={{ fontFamily: F2.mono, fontSize: 9, letterSpacing: '0.1em' }}>3/5 INGREDIENTS</span>
              </div>
            </P2>
            <div style={{ padding: '20px' }}>
              <D2 size={22}>Glazed Harvest Bowl</D2>
              <B2 style={{ marginTop: 8 }}>A perfect autumn meal using the kale and parsnip already in your crisper drawer.</B2>
              <div style={{ display: 'flex', gap: 14, marginTop: 14 }}>
                <span style={{ fontFamily: F2.mono, fontSize: 10, color: T2.sage, letterSpacing: '0.08em' }}>◴ 25 MIN</span>
                <span style={{ fontFamily: F2.mono, fontSize: 10, color: T2.terracotta, letterSpacing: '0.08em' }}>★ MEDIUM EFFORT</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* TRENDING */}
      <div style={{ marginTop: 36 }}>
        <SH2 eyebrow="THIS WEEK" title="What Cooks Are Cooking" action="Leaderboard"/>
        <div style={{ padding: '0 22px' }}>
          {[
            { rank: '01', title: 'Crispy Rosemary Smashed Potatoes', author: 'Chef Julianne', score: 8.5, saves: '1.2k', img: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=400&q=80' },
            { rank: '02', title: 'Pear & Walnut Winter Salad', author: 'Green Kitchen', score: 8.2, saves: '850', img: 'https://images.unsplash.com/photo-1505253213348-cd54c92b37cf?w=400&q=80' },
            { rank: '03', title: 'Hard-Crust Garlic Sourdough', author: "Baker's Den", score: 7.9, saves: '2.4k', img: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400&q=80' },
          ].map((r, i) => (
            <div key={i} style={{ display: 'flex', gap: 14, padding: '16px 0', borderBottom: i < 2 ? `1px dotted ${T2.inset}` : 'none', alignItems: 'center' }}>
              <div style={{ fontFamily: F2.display, fontSize: 28, color: T2.terracotta, fontStyle: 'italic', width: 38, lineHeight: 1 }}>{r.rank}</div>
              <div style={{ width: 60, height: 60, flexShrink: 0 }}><P2 src={r.img} ratio={1} radius={2}/></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: F2.display, fontSize: 16, color: T2.ink, lineHeight: 1.15, fontWeight: 500 }}>{r.title}</div>
                <div style={{ fontFamily: F2.mono, fontSize: 9, color: T2.inkMuted, marginTop: 6, letterSpacing: '0.08em' }}>BY {r.author.toUpperCase()} · {r.saves} SAVES</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontFamily: F2.display, fontSize: 18, color: T2.ink }}>{r.score}</div>
                <div style={{ fontFamily: F2.mono, fontSize: 8, color: T2.inkMuted, letterSpacing: '0.1em' }}>SCORE</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// FRIDGE
// ════════════════════════════════════════════════════════════════
function FridgeScreen() {
  return (
    <div style={{ background: T2.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MSB2 />

      {/* Header w/ asymmetric stats */}
      <div style={{ padding: '6px 22px 24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <Eb2 size={9} color={T2.inkMuted}>YOUR HARVEST</Eb2>
            <D2 size={36} style={{ marginTop: 6, fontStyle: 'italic' }}>The Larder</D2>
          </div>
          <button style={{ width: 38, height: 38, borderRadius: '50%', background: T2.ink, color: T2.vellum, border: 'none', fontSize: 20, lineHeight: 1, cursor: 'pointer' }}>+</button>
        </div>
        {/* Stats row, editorial */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', marginTop: 24, paddingTop: 20, borderTop: `1px solid ${T2.inset}` }}>
          {[
            { v: '12', l: 'TOTAL', accent: T2.ink },
            { v: '05', l: 'IN SEASON', accent: T2.sage },
            { v: '03', l: 'EAT SOON', accent: T2.terracotta },
          ].map((s, i) => (
            <div key={i}>
              <div style={{ fontFamily: F2.display, fontSize: 38, color: s.accent, lineHeight: 1, fontWeight: 400 }}>{s.v}</div>
              <div style={{ fontFamily: F2.mono, fontSize: 9, color: T2.inkMuted, marginTop: 8, letterSpacing: '0.12em' }}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Inventory grid — editorial 2-col */}
      <div style={{ padding: '0 22px 24px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 16 }}>
          <Eb2 color={T2.terracotta}>CURRENT STOCK</Eb2>
          <span style={{ fontFamily: F2.serif, fontSize: 12, color: T2.inkMuted, fontStyle: 'italic' }}>by freshness ↓</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          {FRIDGE.map((f, i) => (
            <div key={f.id} style={{ background: T2.card, borderRadius: 4, overflow: 'hidden' }}>
              <div style={{ position: 'relative' }}>
                <P2 src={f.image} ratio={1.1}/>
                <div style={{ position: 'absolute', top: 8, right: 8 }}>
                  <Sb2 state={f.state}/>
                </div>
              </div>
              <div style={{ padding: '12px 12px 14px' }}>
                <div style={{ fontFamily: F2.display, fontSize: 17, color: T2.ink, lineHeight: 1.1, fontWeight: 500 }}>{f.name}</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 6 }}>
                  <span style={{ fontFamily: F2.serif, fontSize: 12, color: T2.inkMuted, fontStyle: 'italic' }}>{f.qty}</span>
                  <span style={{ fontFamily: F2.mono, fontSize: 9, color: f.state === 'eat-soon' ? T2.terracotta : T2.inkMuted, letterSpacing: '0.08em' }}>
                    {f.daysLeft}D
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* OPPORTUNITY card — full bleed */}
      <div style={{ padding: '8px 22px 0' }}>
        <div style={{ position: 'relative', borderRadius: 4, overflow: 'hidden', background: T2.ink }}>
          <P2 src={R2[0].image} ratio={1.4}>
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.85) 30%, rgba(0,0,0,0.2))' }}/>
          </P2>
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: 22, color: '#fff' }}>
            <Eb2 size={9} color="rgba(255,255,255,0.6)">COOKING OPPORTUNITY</Eb2>
            <D2 size={28} color="#fff" style={{ marginTop: 8, fontStyle: 'italic' }}>
              Use 4 of your<br/>items in 15 min
            </D2>
            <div style={{ marginTop: 14, padding: 14, background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(10px)', borderRadius: 4 }}>
              <Eb2 size={9} color="rgba(255,255,255,0.6)">FEATURED RECIPE</Eb2>
              <div style={{ fontFamily: F2.display, fontSize: 18, color: '#fff', marginTop: 4 }}>Kale & Salmon Sauté</div>
              <div style={{ fontFamily: F2.mono, fontSize: 9, color: 'rgba(255,255,255,0.6)', marginTop: 6, letterSpacing: '0.1em' }}>USES 4 OF 6 ITEMS · 15 MIN</div>
            </div>
            <div style={{ marginTop: 14 }}>
              <PB2 dark={false} icon style={{ background: T2.vellum, color: T2.ink, padding: '12px 22px', fontSize: 13 }}>View Recipe</PB2>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.SCREENS_B = { IngredientScreen, SearchScreen, FridgeScreen };
