// ─── Screens 1: Home + Recipe Detail ───
const { TOKENS, FONTS, EyebrowLabel, Display, Body, PillButton, Stamp,
        StateBadge, TabBar, MiniStatusBar, Photo, Sprig, SectionHead } = window.SEASON_UI;
const { RECIPES, PRODUCE } = window.SEASON_DATA;

// ════════════════════════════════════════════════════════════════
// HOME
// Editorial layout — masthead, asymmetric hero, peak season strip,
// inventory matches as editorial cards with bleed images.
// ════════════════════════════════════════════════════════════════
function HomeScreen() {
  const hero = RECIPES[0];
  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });

  return (
    <div style={{ background: TOKENS.vellum, minHeight: '100%', paddingBottom: 110 }}>
      <MiniStatusBar />

      {/* MASTHEAD */}
      <div style={{ padding: '6px 22px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <EyebrowLabel size={9} color={TOKENS.inkMuted}>{today.toUpperCase()} · WEEK 42</EyebrowLabel>
          <div style={{ fontFamily: FONTS.display, fontSize: 32, fontWeight: 500, color: TOKENS.ink, letterSpacing: '-0.03em', lineHeight: 1, marginTop: 4, fontStyle: 'italic' }}>Season</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Sprig size={20} color={TOKENS.sage} />
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: '#d6cfbe', overflow: 'hidden' }}>
            <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
          </div>
        </div>
      </div>

      {/* HERO — editorial recipe of the day, bleed image */}
      <div style={{ position: 'relative', margin: '0 0 32px', padding: '0 22px' }}>
        <Photo src={hero.image} ratio={1} radius={4} style={{ marginBottom: -56 }}>
          <div style={{
            position: 'absolute', top: 14, left: 14,
            background: 'rgba(244,241,234,0.92)', backdropFilter: 'blur(8px)',
            padding: '6px 10px', borderRadius: 4,
          }}>
            <EyebrowLabel size={9} color={TOKENS.terracotta}>{hero.matchLabel} · {hero.match}</EyebrowLabel>
          </div>
          <div style={{ position: 'absolute', bottom: 14, right: 14 }}>
            <Stamp color={TOKENS.terracotta}>{hero.season}<br/>2026</Stamp>
          </div>
        </Photo>
        {/* asymmetric overlap title card */}
        <div style={{
          background: TOKENS.vellum,
          padding: '18px 18px 16px',
          marginLeft: 14, marginRight: 60,
          position: 'relative',
        }}>
          <EyebrowLabel size={10} color={TOKENS.sage}>TONIGHT'S DISPATCH №47</EyebrowLabel>
          <Display size={32} style={{ marginTop: 8, fontStyle: 'italic' }}>
            Charred Sage<br/>
            <span style={{ fontStyle: 'normal' }}>& Butternut</span><br/>
            <span style={{ fontStyle: 'italic' }}>Risotto</span>
          </Display>
          <div style={{ display: 'flex', gap: 16, marginTop: 14, alignItems: 'center' }}>
            <Body size={12} color={TOKENS.inkMuted}>{hero.minutes} min · {hero.serves} serve · {hero.difficulty}</Body>
          </div>
          <div style={{ marginTop: 16, display: 'flex', gap: 10 }}>
            <PillButton dark icon style={{ padding: '12px 20px', fontSize: 13 }}>Begin</PillButton>
            <PillButton dark={false} style={{ padding: '12px 18px', fontSize: 13, color: TOKENS.ink, background: 'transparent', border: `1px solid ${TOKENS.inset}` }}>Save</PillButton>
          </div>
        </div>
      </div>

      {/* PEAK SEASON STRIP — horizontal, editorial */}
      <div style={{ marginBottom: 36 }}>
        <SectionHead eyebrow="THE HARVEST · OCTOBER" title="At Peak, Right Now" action="Calendar" />
        <div style={{ display: 'flex', gap: 14, padding: '0 22px', overflowX: 'auto', scrollbarWidth: 'none' }}>
          {PRODUCE.slice(0, 5).map(p => (
            <div key={p.id} style={{ flexShrink: 0, width: 96, textAlign: 'center' }}>
              <div style={{ position: 'relative', marginBottom: 10 }}>
                <Photo src={p.image} ratio={1} radius={9999} />
                {p.peak && (
                  <div style={{
                    position: 'absolute', bottom: -2, right: -2,
                    width: 14, height: 14, borderRadius: '50%',
                    background: TOKENS.terracotta, border: `2px solid ${TOKENS.vellum}`,
                  }}/>
                )}
              </div>
              <div style={{ fontFamily: FONTS.serif, fontSize: 16, color: TOKENS.ink, fontWeight: 500, lineHeight: 1.1 }}>{p.en}</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: TOKENS.inkMuted, marginTop: 4, letterSpacing: '0.08em' }}>{String(p.recipes).padStart(2, '0')} RECIPES</div>
            </div>
          ))}
        </div>
      </div>

      {/* FROM YOUR FRIDGE — editorial split layout */}
      <div style={{ marginBottom: 36 }}>
        <SectionHead eyebrow="INVENTORY · 5 ITEMS MATCH" title="Cook From Your Fridge" action="See all" />
        <div style={{ padding: '0 22px' }}>
          {RECIPES.slice(1, 4).map((r, i) => (
            <div key={r.id} style={{
              display: 'flex', gap: 16,
              paddingBottom: 22, marginBottom: 22,
              borderBottom: i < 2 ? `1px solid ${TOKENS.inset}` : 'none',
              alignItems: 'flex-start',
            }}>
              <div style={{ width: 96, flexShrink: 0 }}>
                <Photo src={r.image} ratio={1} radius={2} />
              </div>
              <div style={{ flex: 1, paddingTop: 2 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <EyebrowLabel size={9} color={TOKENS.terracotta}>{r.match} · MATCH</EyebrowLabel>
                </div>
                <div style={{ fontFamily: FONTS.display, fontSize: 20, color: TOKENS.ink, fontWeight: 500, lineHeight: 1.1, marginTop: 6, letterSpacing: '-0.01em' }}>
                  {r.title}
                </div>
                <div style={{ display: 'flex', gap: 10, marginTop: 10, alignItems: 'center' }}>
                  <span style={{ fontFamily: FONTS.mono, fontSize: 10, color: TOKENS.inkMuted, letterSpacing: '0.08em' }}>{String(r.minutes).padStart(2,'0')} MIN</span>
                  <span style={{ width: 3, height: 3, borderRadius: '50%', background: TOKENS.inkMuted }}/>
                  <span style={{ fontFamily: FONTS.serif, fontSize: 12, color: TOKENS.inkSoft, fontStyle: 'italic' }}>{r.tags.join(' · ')}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* WEEKLY DISPATCH — editorial feature, full bleed */}
      <div style={{ marginBottom: 36 }}>
        <SectionHead eyebrow="ESSAY · WEEKLY DISPATCH" title="Mastering the Slow Sunday" />
        <div style={{ padding: '0 22px' }}>
          <Photo src={RECIPES[4].image} ratio={1.7} radius={2}>
            <div style={{
              position: 'absolute', inset: 0,
              background: 'linear-gradient(to top, rgba(29,31,28,0.7), transparent 50%)',
            }}/>
            <div style={{ position: 'absolute', bottom: 16, left: 16, right: 16, color: '#fff' }}>
              <EyebrowLabel size={9} color="rgba(255,255,255,0.7)">7 MIN READ · OCT 19</EyebrowLabel>
              <div style={{ fontFamily: FONTS.display, fontSize: 22, lineHeight: 1.05, marginTop: 8, fontStyle: 'italic' }}>
                "Brunch is the slowest meal of the week.<br/>It deserves your attention."
              </div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: 'rgba(255,255,255,0.7)', marginTop: 10, letterSpacing: '0.1em' }}>— ELENA VANCE</div>
            </div>
          </Photo>
        </div>
      </div>

      {/* COLOPHON / FOOTER */}
      <div style={{ padding: '8px 22px 60px', textAlign: 'center' }}>
        <Sprig size={20} color={TOKENS.inkMuted} style={{ opacity: 0.4, margin: '0 auto 8px', display: 'block' }}/>
        <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: TOKENS.inkMuted, letterSpacing: '0.18em' }}>
          SEASON · ISSUE 47 · AUTUMN MMXXVI
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// RECIPE DETAIL
// ════════════════════════════════════════════════════════════════
function RecipeDetailScreen() {
  const r = RECIPES[0];
  return (
    <div style={{ background: TOKENS.vellum, minHeight: '100%', paddingBottom: 110 }}>
      {/* HERO IMAGE — full bleed top */}
      <div style={{ position: 'relative' }}>
        <Photo src={r.image} ratio={0.95}>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.4) 0%, transparent 30%, transparent 70%, rgba(244,241,234,1) 100%)',
          }}/>
          <MiniStatusBar dark />
          <div style={{ position: 'absolute', top: 50, left: 16, right: 16, display: 'flex', justifyContent: 'space-between' }}>
            <button style={{ width: 38, height: 38, borderRadius: '50%', background: 'rgba(255,255,255,0.85)', backdropFilter: 'blur(10px)', border: 'none', cursor: 'pointer', fontSize: 18, color: TOKENS.ink }}>‹</button>
            <button style={{ width: 38, height: 38, borderRadius: '50%', background: 'rgba(255,255,255,0.85)', backdropFilter: 'blur(10px)', border: 'none', cursor: 'pointer', fontSize: 14, color: TOKENS.terracotta }}>♥</button>
          </div>
          <div style={{ position: 'absolute', top: 100, right: 22 }}>
            <Stamp color={TOKENS.terracotta}>BEST<br/>MATCH<br/>5/5</Stamp>
          </div>
        </Photo>
      </div>

      {/* TITLE — overlap into image */}
      <div style={{ padding: '0 22px', marginTop: -44, position: 'relative' }}>
        <EyebrowLabel color={TOKENS.terracotta}>{r.season} · IN YOUR FRIDGE</EyebrowLabel>
        <Display size={42} style={{ marginTop: 10, fontStyle: 'italic' }}>
          Charred Sage<br/>
          <span style={{ fontStyle: 'normal' }}>& Butternut</span><br/>
          <span style={{ fontStyle: 'italic' }}>Risotto</span>
        </Display>
        <div style={{ marginTop: 18, display: 'flex', gap: 12, alignItems: 'center' }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', background: '#c8c0ad', overflow: 'hidden' }}>
            <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&q=80" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
          </div>
          <div>
            <div style={{ fontFamily: FONTS.serif, fontSize: 14, color: TOKENS.ink, fontStyle: 'italic' }}>by {r.author}</div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: TOKENS.inkMuted, letterSpacing: '0.1em', marginTop: 2 }}>{r.authorRole.toUpperCase()}</div>
          </div>
        </div>

        {/* Editorial intro — italic, indented */}
        <div style={{ marginTop: 22, paddingLeft: 16, borderLeft: `2px solid ${TOKENS.terracotta}` }}>
          <Body size={15} style={{ fontFamily: FONTS.serif, fontStyle: 'italic', color: TOKENS.inkSoft, lineHeight: 1.5 }}>
            {r.intro}
          </Body>
        </div>
      </div>

      {/* META STRIP — large editorial numbers */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 0, padding: '32px 22px', borderTop: `1px solid ${TOKENS.inset}`, borderBottom: `1px solid ${TOKENS.inset}`, marginTop: 28 }}>
        {[
          { v: r.minutes, l: 'MINUTES' },
          { v: r.serves, l: 'SERVES' },
          { v: r.nutrition.kcal, l: 'KCAL' },
          { v: r.match, l: 'MATCH' },
        ].map((m, i) => (
          <div key={i} style={{ textAlign: 'center', borderRight: i < 3 ? `1px solid ${TOKENS.inset}` : 'none', padding: '0 4px' }}>
            <div style={{ fontFamily: FONTS.display, fontSize: 28, color: TOKENS.ink, fontWeight: 400, lineHeight: 1 }}>{m.v}</div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 8, color: TOKENS.inkMuted, letterSpacing: '0.14em', marginTop: 6 }}>{m.l}</div>
          </div>
        ))}
      </div>

      {/* BEGIN CTA */}
      <div style={{ padding: '24px 22px' }}>
        <PillButton dark full icon style={{ padding: '18px', fontSize: 14, letterSpacing: '0.06em', textTransform: 'uppercase' }}>
          Begin Cooking
        </PillButton>
      </div>

      {/* INGREDIENTS */}
      <div style={{ padding: '12px 0 24px' }}>
        <div style={{ padding: '0 22px', marginBottom: 18, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div>
            <EyebrowLabel color={TOKENS.terracotta}>SECTION I</EyebrowLabel>
            <Display size={28} style={{ marginTop: 6 }}>Ingredients</Display>
          </div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: TOKENS.inkMuted, letterSpacing: '0.1em' }}>{r.serves} SERVES</div>
        </div>
        <div style={{ padding: '0 22px' }}>
          {r.ingredients.map((ing, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'baseline', gap: 12,
              padding: '14px 0',
              borderBottom: i < r.ingredients.length - 1 ? `1px dotted ${TOKENS.inset}` : 'none',
            }}>
              <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: TOKENS.inkMuted, width: 22, letterSpacing: '0.05em' }}>{String(i+1).padStart(2,'0')}</div>
              <div style={{ fontFamily: FONTS.serif, fontSize: 17, color: TOKENS.ink, flex: 1 }}>{ing.name}</div>
              <div style={{ fontFamily: FONTS.sans, fontSize: 12, color: TOKENS.inkMuted, marginRight: 8 }}>{ing.qty}</div>
              <StateBadge state={ing.state}/>
            </div>
          ))}
        </div>
      </div>

      {/* METHOD */}
      <div style={{ padding: '12px 0 24px', background: TOKENS.vellumWarm }}>
        <div style={{ padding: '32px 22px 22px' }}>
          <EyebrowLabel color={TOKENS.terracotta}>SECTION II</EyebrowLabel>
          <Display size={28} style={{ marginTop: 6 }}>The Method</Display>
        </div>
        <div style={{ padding: '0 22px 32px' }}>
          {r.method.map((step, i) => (
            <div key={i} style={{ display: 'flex', gap: 16, marginBottom: 28 }}>
              <div style={{
                fontFamily: FONTS.display, fontSize: 36, color: TOKENS.terracotta,
                lineHeight: 1, fontWeight: 400, fontStyle: 'italic', width: 50, flexShrink: 0, paddingTop: 4,
              }}>{step.n}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: FONTS.display, fontSize: 20, color: TOKENS.ink, fontWeight: 500, marginBottom: 6, lineHeight: 1.15 }}>{step.title}</div>
                <Body size={14} color={TOKENS.inkSoft} style={{ lineHeight: 1.55 }}>{step.body}</Body>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* COLOPHON */}
      <div style={{ padding: '20px 22px 60px', textAlign: 'center' }}>
        <Sprig size={20} color={TOKENS.sage} style={{ opacity: 0.5, margin: '0 auto 8px', display: 'block' }}/>
        <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: TOKENS.inkMuted, letterSpacing: '0.18em' }}>RECIPE №47 · LAST COOKED 3 DAYS AGO</div>
      </div>
    </div>
  );
}

window.SCREENS_A = { HomeScreen, RecipeDetailScreen };
