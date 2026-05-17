# Android MVP Parity Checklist

Last updated: 2026-05-17

This checklist defines what Android must match from iOS before it can be considered a useful MVP.

It is not a full feature parity list. It is the minimum real Season experience for Android.

## Legend

- `MVP`: required for first Android MVP.
- `Later`: explicitly deferred.
- `Shared`: should use the same Supabase/backend contract as iOS.
- `Android-native`: should use Android-specific implementation rather than copying SwiftUI internals.

## 1. Auth and Onboarding

| Capability | Priority | Notes |
|---|---|---|
| Google Sign-In | MVP | Android-native Google Sign-In, Supabase session. |
| Email/password login | MVP | Tester fallback and parity. |
| Email signup | MVP | Use existing Supabase Auth policies. |
| Username gate | MVP | Required for social identity consistency. |
| Profile fetch/create | MVP | Shared `profiles` table. |
| Apple Sign-In | Later | Not needed on Android. |
| OAuth social linking for Instagram/TikTok | Later | Creator polish, not first MVP. |

## 2. Home

| Capability | Priority | Notes |
|---|---|---|
| Remote recipe load | MVP | Supabase source of truth. |
| Main featured recipe | MVP | Ranking can be simpler than iOS initially. |
| Quick filters | MVP | Must be readable in light/dark. |
| Trending/seasonal sections | MVP | Use same recipe/catalog signals where possible. |
| Creator strips | Later | Nice, not essential for first Android validation. |
| Advanced feed diversity tuning | Later | Keep contract open. |

## 3. Today / Seasonality

| Capability | Priority | Notes |
|---|---|---|
| Current month seasonal ranking | MVP | Reuse seasonality data. |
| Phase labels | MVP | Must distinguish peak, primizia, and ending season where data allows. |
| Ingredient detail navigation | MVP | At least basic product detail. |
| Smooth curve chart | Later | Valuable polish after MVP. |

## 4. Search

| Capability | Priority | Notes |
|---|---|---|
| Recipe search | MVP | Query remote/local snapshot. |
| Ingredient search | MVP | Catalog-backed where possible. |
| Filter chips | MVP | Keep simple and readable. |
| Debounce/cache | MVP | Avoid janky typing. |
| Advanced ranking parity | Later | Tune after real Android usage. |

## 5. Recipe Detail

| Capability | Priority | Notes |
|---|---|---|
| Title/media/source/creator | MVP | Remote recipes must render cleanly. |
| Servings scaling | MVP | Core cooking utility. |
| Ingredients with quantities | MVP | No quantity loss. |
| Steps | MVP | Required for cooking flow. |
| Save | MVP | Local-first + Supabase state. |
| Crispy | MVP | Local-first + Supabase state. |
| Add missing to shopping list | MVP | Key conversion action. |
| Follow creator | Later | Social expansion. |
| Nutrition summary | Later | Useful, not first MVP blocker. |

## 6. Smart Import

| Capability | Priority | Notes |
|---|---|---|
| Paste caption | MVP | Primary creator value prop. |
| Parse with Supabase Edge Function | MVP | Shared `parse-recipe-caption`. |
| Preserve title | MVP | Regression-critical. |
| Preserve servings | MVP | Regression-critical. |
| Preserve quantities/units | MVP | Regression-critical. |
| Dedupe ingredients | MVP | Regression-critical. |
| Detect missing steps | MVP | Should block publish but keep draft. |
| Manual correction | MVP | Creator must be able to fix parser misses. |
| Publish recipe | MVP | Remote insert path. |
| URL import | Later | Existing iOS admin/history use case, not first Android MVP. |

## 7. Fridge

| Capability | Priority | Notes |
|---|---|---|
| Add catalog ingredient | MVP | Shared catalog identity where available. |
| Add custom fallback | MVP | Must feed observation path, not catalog truth directly. |
| Remove ingredient | MVP | Local-first. |
| Recipes from fridge | MVP | Must be discoverable, not just one suggestion. |
| Sync to Supabase | MVP | Outbox/retry. |
| Advanced categorization | Later | After MVP. |

## 8. Shopping List

| Capability | Priority | Notes |
|---|---|---|
| Add manually | MVP | Catalog/custom support. |
| Add from recipe | MVP | Core flow. |
| Remove/check off | MVP | Local-first. |
| Quantity/unit display | MVP | Must preserve recipe quantities. |
| Sync to Supabase | MVP | Outbox/retry. |
| Multi-recipe grouping | Later | Polish. |

## 9. Profile and Social

| Capability | Priority | Notes |
|---|---|---|
| Current user profile | MVP | Username/avatar/basic stats. |
| Logout | MVP | Must reset local session state. |
| Saved recipes list | MVP | Useful account utility. |
| Published recipes list | MVP | Creator baseline. |
| Follows | Later | Can reuse backend after core stable. |
| Notifications inbox | Later | Not first MVP blocker. |

## 10. Notifications

| Capability | Priority | Notes |
|---|---|---|
| Local notification inbox | Later | Bell can be added after core app. |
| Push notifications | Later | Requires FCM/APNs equivalent and backend notification table. |
| Follow/crispy notifications | Later | Implement after social surfaces are stable. |

## 11. Catalog and Governance

| Capability | Priority | Notes |
|---|---|---|
| Read canonical catalog data | MVP | For ingredient matching/display. |
| Send unresolved signals | MVP | Non-mutating training signal path. |
| Admin console in app | Later/Never | Governance stays on `catalog.seasonapp.it`. |
| Catalog mutation from Android | Later/Never | Must remain backend-governed. |

## 12. Technical Gates

| Gate | Required Before MVP Release |
|---|---|
| Debug build installs on emulator and real Android device. |
| Google Sign-In works on debug build. |
| Supabase dev and staging environments are switchable. |
| Logs do not expose emails, user IDs, callback URLs, raw payloads, or secrets. |
| Smart Import passes the iOS regression caption set. |
| Fridge/shopping/saved/crispy survive app restart. |
| Outbox retries after simulated network failure. |
| Light/dark mode readable on main screens. |
| Android README documents setup and build commands. |

Current foundation note:

- `android-app/` has the initial Compose shell and environment build types.
- Gradle wrapper exists.
- `:app:assembleDebugDev` and `:app:assembleInternalStaging` have been validated locally with Android Studio JBR.

## 13. Regression Caption Set

These captions should be reused when Android Smart Import starts:

```text
Risotto ai funghi per 2: riso 180g, funghi 250g, brodo vegetale caldo 700ml, burro 20g, parmigiano 30g. Tosta il riso, aggiungi i funghi, cuoci con il brodo poco alla volta e manteca con burro e parmigiano.
```

```text
Insalata di pollo per 2: pollo grigliato 250g, lattuga 120g, pomodorini 150g, mais 80g, olive 40g, olio 1 cucchiaio, limone mezzo. Taglia tutto, unisci in ciotola e condisci.
```

```text
Pancake banana e avena x2: banana 1, uova 2, fiocchi d'avena 80g, latte 100ml, lievito 1 cucchiaino. Frulla tutto, cuoci in padella antiaderente 2 minuti per lato.
```

```text
Muffin banana e cioccolato per 6: banana 2, farina 180g, uova 2, zucchero 80g, latte 80ml, lievito 1 bustina, gocce di cioccolato 70g. Mescola tutto, versa negli stampi e cuoci a 180 gradi per 20 minuti.
```

```text
Frittata spinaci e patate per 2: uova 4, spinaci 150g, patate 250g, parmigiano 30g, sale q.b., olio 1 cucchiaio. Lessare le patate, saltare gli spinaci, unire con le uova e cuocere in padella.
```
