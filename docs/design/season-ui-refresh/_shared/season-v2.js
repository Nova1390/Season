/* ============================================================
   SEASON — Shared shell + primitives v2
   Used across home / detail / today / search / account prototypes.
   ============================================================ */

// ---------- DOM helpers ----------
const $ = (sel, root) => (root || document).querySelector(sel);
const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

// ---------- Language (IT default) ----------
let LANG = 'it';
let DICT = { it: {}, en: {} };
function t(key, vars) {
  const raw = (DICT[LANG] || {})[key] ?? (DICT.en || {})[key] ?? key;
  if (!vars) return raw;
  return raw.replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? '');
}
function registerDict(dict) {
  DICT.it = { ...DICT.it, ...(dict.it || {}) };
  DICT.en = { ...DICT.en, ...(dict.en || {}) };
}
function applyI18N() {
  $$('[data-i18n]').forEach(el => {
    const key = el.dataset.i18n;
    const val = t(key);
    if (el.dataset.i18nHtml === '1') el.innerHTML = val;
    else el.textContent = val;
  });
  if (typeof window.onLangChange === 'function') window.onLangChange(LANG);
}

// ---------- Creators (shared across views) ----------
const CREATORS = {
  elena:  { name: 'Elena Vanzi',    av: '../_assets/av_elena.png',  following: true,  followers: '12,3k', recipes: 47 },
  marco:  { name: 'Marco Rizzi',    av: '../_assets/av_marco.png',  following: true,  followers: '4,8k',  recipes: 22 },
  sara:   { name: 'Sara Conte',     av: '../_assets/av_sara.png',   following: true,  followers: '9,1k',  recipes: 34 },
  chiara: { name: 'Chiara Bellini', av: '../_assets/av_chiara.png', following: false, followers: '2,4k',  recipes: 18 },
  luca:   { name: 'Luca Neri',      av: '../_assets/av_luca.png',   following: false, followers: '6,7k',  recipes: 29 },
};
function creatorBio(c) {
  const followers = LANG === 'en' ? c.followers.replace(',', '.') : c.followers;
  return LANG === 'it'
    ? `${followers} follower · ${c.recipes} ricette`
    : `${followers} followers · ${c.recipes} recipes`;
}

// ---------- Icons (strokes match app SF Symbols) ----------
const SVG = {
  // flame.fill (crispy)
  flame: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="currentColor" aria-hidden="true"><path d="M12 2c0 4-4 5-4 9a4 4 0 1 0 8 0c0-1.5-1-2.5-1-4 2 1 3 3 3 5a6 6 0 1 1-12 0c0-4 4-6 6-10z"/></svg>`,
  // bookmark (save)
  bookmark: (w = 18, h = 18) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-4.5L5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>`,
  bookmarkFill: (w = 18, h = 18) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="currentColor"><path d="M19 21l-7-4.5L5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>`,
  // cart (shopping)
  cart: (w = 18, h = 18) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M3 3h2l2.5 12h12l2-8H6"/></svg>`,
  cartPlus: (w = 18, h = 18) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M3 3h2l2.5 12h12l2-8H6"/><line x1="17" y1="4" x2="17" y2="10"/><line x1="14" y1="7" x2="20" y2="7"/></svg>`,
  bell: (w = 20, h = 20) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8z"/><path d="M10 20a2 2 0 0 0 4 0"/></svg>`,
  back: (w = 20, h = 20) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15,6 9,12 15,18"/></svg>`,
  share: (w = 20, h = 20) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="5" r="2.5"/><circle cx="18" cy="19" r="2.5"/><line x1="8" y1="11" x2="16" y2="6"/><line x1="8" y1="13" x2="16" y2="18"/></svg>`,
  arrowRight: (w = 16, h = 16) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12,5 19,12 12,19"/></svg>`,
  search: (w = 24, h = 24) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><line x1="16.5" y1="16.5" x2="21" y2="21"/></svg>`,
  leaf: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M11 20a7 7 0 0 1-7-7V4h9a7 7 0 0 1 7 7v2a7 7 0 0 1-7 7z"/><line x1="4" y1="4" x2="20" y2="20"/></svg>`,
  sun: (w = 24, h = 24) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4.2"/><line x1="12" y1="2.6" x2="12" y2="5"/><line x1="12" y1="19" x2="12" y2="21.4"/><line x1="2.6" y1="12" x2="5" y2="12"/><line x1="19" y1="12" x2="21.4" y2="12"/><line x1="5.6" y1="5.6" x2="7.3" y2="7.3"/><line x1="16.7" y1="16.7" x2="18.4" y2="18.4"/><line x1="5.6" y1="18.4" x2="7.3" y2="16.7"/><line x1="16.7" y1="7.3" x2="18.4" y2="5.6"/></svg>`,
  home: (w = 24, h = 24) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor"><path d="M3 11l9-8 9 8v9a2 2 0 0 1-2 2h-4a1 1 0 0 1-1-1v-5a1 1 0 0 0-1-1h-2a1 1 0 0 0-1 1v5a1 1 0 0 1-1 1H5a2 2 0 0 1-2-2z"/></svg>`,
  profile: (w = 24, h = 24) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>`,
  plus: (w = 22, h = 22) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>`,
  check: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="5,12 10,17 19,7"/></svg>`,
  chevron: (w = 16, h = 16) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="9,6 15,12 9,18"/></svg>`,
  minus: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>`,
  clock: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12,7 12,12 15,14"/></svg>`,
  bolt: (w = 14, h = 14) => `<svg viewBox="0 0 24 24" width="${w}" height="${h}" fill="currentColor"><path d="M13 2L4 14h6l-1 8 9-12h-6l1-8z"/></svg>`,
};

function crispyPillHTML({ count, size = 'md', activeIds }) {
  // activeIds: Set<string> of crispied items; count bound to the caller
  const cls = `crispy-pill crispy-pill--${size}`;
  return `<button class="${cls}" data-crispy-count="${count}">${SVG.flame(size === 'lg' ? 16 : 14)}<span class="crispy-pill__count">${count}</span>${size === 'lg' ? `<span class="crispy-pill__word" data-i18n="crispy-word">crispy</span>` : ''}</button>`;
}

// ---------- Toast ----------
let _toastTimeout = null;
function toast(msg) {
  const el = $('#toast');
  if (!el) return;
  el.innerHTML = `${SVG.flame(14)}<span>${msg}</span>`;
  el.classList.add('is-visible');
  clearTimeout(_toastTimeout);
  _toastTimeout = setTimeout(() => el.classList.remove('is-visible'), 1700);
}

// ---------- Tab bar markup (identical across views) ----------
function tabBarHTML(activeKey) {
  const tabs = [
    { key: 'home',     labelKey: 'tab-home',     label: 'Home',   icon: SVG.home(24, 24) },
    { key: 'discover', labelKey: 'tab-discover', label: 'Scopri', icon: SVG.search(24, 24) },
    { key: 'create',   labelKey: 'tab-create',   label: 'Crea',   icon: SVG.plus(22, 22), create: true },
    { key: 'today',    labelKey: 'tab-today',    label: 'Oggi',   icon: SVG.sun(24, 24) },
    { key: 'profile',  labelKey: 'tab-profile',  label: 'Io',     icon: SVG.profile(24, 24) },
  ];
  return `
    <nav class="tabbar" role="navigation" aria-label="Tab principale">
      ${tabs.map(tab => {
        if (tab.create) {
          return `
            <button class="tab tab--create" data-tab="${tab.key}" aria-label="Crea ricetta">
              <span class="tab__pad">${tab.icon}</span>
              <span class="tab__label" data-i18n="${tab.labelKey}">${tab.label}</span>
            </button>`;
        }
        const active = tab.key === activeKey ? 'is-active' : '';
        return `
          <button class="tab ${active}" data-tab="${tab.key}">
            <span class="tab__icon">${tab.icon}</span>
            <span class="tab__label" data-i18n="${tab.labelKey}">${tab.label}</span>
          </button>`;
      }).join('')}
    </nav>
  `;
}

function wireTabBar(onNavigate) {
  $$('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const key = tab.dataset.tab;
      if (key === 'create') {
        toast(LANG === 'it' ? 'Apro Crea ricetta…' : 'Opening Create recipe…');
        return;
      }
      $$('.tab').forEach(x => { if (x.dataset.tab !== 'create') x.classList.remove('is-active'); });
      tab.classList.add('is-active');
      if (onNavigate) onNavigate(key);
    });
  });
}

// ---------- Status bar + device frame scaffold ----------
function statusBarHTML() {
  return `
    <div class="statusbar">
      <span>9:41</span>
      <div class="statusbar__icons">
        <svg width="18" height="12" viewBox="0 0 18 12"><rect x="0.5" y="4.5" width="3" height="3" rx="0.6" fill="currentColor"/><rect x="5.5" y="2.5" width="3" height="5" rx="0.6" fill="currentColor"/><rect x="10.5" y="0.5" width="3" height="7" rx="0.6" fill="currentColor"/><rect x="15.5" y="0.5" width="3" height="7" rx="0.6" fill="currentColor" opacity="0.4"/></svg>
        <svg width="18" height="12" viewBox="0 0 18 12"><path d="M9 9c-3 0-6-1-7-2 3-4 11-4 14 0-1 1-4 2-7 2z" fill="currentColor" opacity="0.4"/><path d="M9 9c-2 0-4-1-5-2 2-3 8-3 10 0-1 1-3 2-5 2z" fill="currentColor" opacity="0.6"/><circle cx="9" cy="9" r="1.3" fill="currentColor"/></svg>
        <svg width="25" height="12" viewBox="0 0 25 12"><rect x="0.5" y="0.5" width="22" height="11" rx="2.5" fill="none" stroke="currentColor" stroke-width="1" opacity="0.4"/><rect x="2" y="2" width="17" height="8" rx="1.4" fill="currentColor"/><rect x="23" y="4" width="1.5" height="4" rx="0.5" fill="currentColor" opacity="0.4"/></svg>
      </div>
    </div>
  `;
}

// ---------- Crispy toggle on any .crispy-pill ----------
function wireCrispyPills(scope) {
  const state = { crispied: new Set() };
  $$('.crispy-pill', scope).forEach(btn => {
    btn.addEventListener('click', e => {
      e.preventDefault(); e.stopPropagation();
      const id = btn.dataset.id || 'x';
      const countEl = btn.querySelector('.crispy-pill__count');
      const current = countEl ? parseInt(countEl.textContent, 10) || 0 : 0;
      if (state.crispied.has(id)) {
        state.crispied.delete(id);
        btn.classList.remove('is-crispied');
        if (countEl) countEl.textContent = Math.max(0, current - 1);
        toast(t('toast-uncrispied'));
      } else {
        state.crispied.add(id);
        btn.classList.add('is-crispied');
        if (countEl) countEl.textContent = current + 1;
        toast(t('toast-crispied'));
      }
    });
  });
  return state;
}

// ---------- Shared base i18n (view files add their own keys) ----------
registerDict({
  it: {
    'tab-home': 'Home',
    'tab-discover': 'Scopri',
    'tab-create': 'Crea',
    'tab-today': 'Oggi',
    'tab-profile': 'Io',
    'follow': 'Segui',
    'following': 'Segui già',
    'crispy-word': 'crispy',
    'toast-crispied': 'Crispata!',
    'toast-uncrispied': 'Crispy tolto',
    'toast-followed': 'Ora segui {name}',
    'toast-unfollowed': 'Non segui più {name}',
    'toast-saved': 'Salvata',
    'toast-unsaved': 'Rimossa dai salvati',
    'toast-added-list': 'Aggiunta alla lista',
    'min': 'min',
    'serves': 'porzioni',
    'see-all': 'Vedi tutti',
  },
  en: {
    'tab-home': 'Home',
    'tab-discover': 'Discover',
    'tab-create': 'Create',
    'tab-today': 'Today',
    'tab-profile': 'Me',
    'follow': 'Follow',
    'following': 'Following',
    'crispy-word': 'crispy',
    'toast-crispied': 'Crispied!',
    'toast-uncrispied': 'Crispy removed',
    'toast-followed': 'Now following {name}',
    'toast-unfollowed': 'Unfollowed {name}',
    'toast-saved': 'Saved',
    'toast-unsaved': 'Removed from saved',
    'toast-added-list': 'Added to list',
    'min': 'min',
    'serves': 'serves',
    'see-all': 'See all',
  },
});

// Expose globals
window.Season = {
  $, $$, LANG, t, registerDict, applyI18N,
  CREATORS, creatorBio, SVG, crispyPillHTML,
  toast, tabBarHTML, wireTabBar, statusBarHTML, wireCrispyPills,
  setLang: (lang) => { LANG = lang; window.Season.LANG = lang; applyI18N(); },
  getLang: () => LANG,
};
