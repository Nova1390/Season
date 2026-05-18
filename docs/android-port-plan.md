# Season Android Port Plan

Last updated: 2026-05-18

## 1. Decision

Season Android should be built as a native Android app using Kotlin and Jetpack Compose, starting from a focused MVP.

This means:

- Native Android defines the technical stack.
- MVP defines the first release scope.
- Supabase remains part of the MVP from day one.
- The Android app is not a prototype, offline demo, or separate product.
- The Android app must use the same backend source of truth as iOS.
- Package name is `it.seasonapp.season`.
- The first MVP includes Smart Import draft creation and publishing.

The first Android milestone should be intentionally smaller than iOS, but production-shaped: real auth, real recipes, real catalog data, real Smart Import, and real user state sync.

## 2. Why Native Android

Season's iOS app is already mature and strongly shaped around SwiftUI, local-first state, Supabase, and a premium visual identity. A cross-platform rewrite would risk slowing down the validated iOS track.

Native Android gives us:

- Better long-term UX quality on Android.
- Direct access to Google Sign-In, notifications, background work, and Material/Compose patterns.
- Cleaner platform-specific performance and offline handling.
- No need to rewrite iOS just to share UI.
- A clear future path for Android-specific polish.

The tradeoff is that client UI/state must be implemented separately. That is acceptable because the backend, catalog intelligence, Smart Import, recipe data, auth, and governance workflows are already shared through Supabase.

## 3. MVP Scope

The Android MVP should prove that Season is useful to Android users without copying every iOS surface immediately.

### In Scope

- Supabase Auth with Google and email/password.
- Username/profile bootstrap after first login.
- Home feed with remote recipes and basic ranking.
- Today/seasonal ingredient discovery.
- Search for recipes and ingredients.
- Recipe detail with ingredients, servings, steps, save, crispy, and shopping-list CTA.
- Smart Import from caption text through the existing Supabase Edge Function.
- Fridge list.
- Recipes from fridge.
- Shopping list.
- Basic profile/account page.
- Light and dark mode baseline.
- Local-first state for fridge, shopping list, saved/crispy.
- Outbox/retry semantics for user actions.

### Out of Scope for First MVP

- Catalog admin/governance console.
- In-app catalog diagnostics.
- Full creator social analytics.
- Advanced notifications.
- Full visual parity with every iOS micro-interaction.
- Offline-first recipe cache beyond practical local state.
- Deep Android widgets, shortcuts, or wearables.
- Complete iOS feature parity in the first sprint.

## 4. Supabase Integration

Supabase is not optional for Android MVP. It is the shared backbone.

Android should use the same Supabase environments:

- Development: `Season-dev`.
- Staging/TestFlight equivalent: `Season-staging`.
- Future production: final production project or promoted staging architecture.

Android must integrate these domains:

- Auth: Google OAuth and email/password.
- Profiles: username, avatar URL, language, social metadata.
- Recipes: published remote recipes.
- Recipe states: saved, crispy, archived.
- Fridge items.
- Shopping list items.
- Follows, where exposed safely.
- Smart Import through `parse-recipe-caption`.
- Catalog reads for canonical ingredients, aliases, localizations, and matching metadata.

Android must not mutate catalog governance tables directly. Catalog changes remain governed by Supabase RPCs, Edge Functions, and `catalog.seasonapp.it`.

## 5. Proposed Repository Layout

No Android code should be added until the implementation phase starts.

When code begins, keep Android separate from iOS:

```text
android-app/
  app/
  build.gradle.kts
  settings.gradle.kts
  README.md
  docs/
```

The iOS app remains under:

```text
Season/
Season.xcodeproj
```

Shared backend and operational assets remain:

```text
supabase/
docs/
scripts/
```

Do not mix Android source files into `Season/`.

## 6. Architecture Target

Recommended Android architecture:

- Kotlin.
- Jetpack Compose.
- Navigation Compose.
- Kotlin coroutines and Flow.
- Supabase Kotlin client, if sufficiently mature for required auth/data flows.
- Repository layer per backend domain.
- ViewModel per major screen.
- Local persistence via DataStore for preferences and Room only if offline cache grows beyond simple state.
- WorkManager or app lifecycle retry for outbox processing.

Suggested module boundaries for MVP:

- `auth`: session, Google Sign-In, email login, username bootstrap.
- `recipes`: recipe list/detail, saved/crispy state.
- `home`: feed snapshot and ranking.
- `today`: seasonal ingredient ranking.
- `search`: recipe/ingredient search.
- `smartimport`: caption parsing and draft mapping.
- `fridge`: fridge state and recipes from fridge.
- `shopping`: shopping list state.
- `profile`: account/profile basics.
- `core`: design system, logging, networking, errors, environment.

## 7. Data Contracts To Reuse

Android should mirror the iOS domain model names where useful, but not copy Swift implementation details.

Critical contracts:

- `Recipe`
- `RecipeIngredient`
- `IngredientReference`
- `ProduceItem` or Android equivalent seasonal ingredient model
- `ShoppingListEntry`
- `FridgeCatalogItem`
- `FridgeCustomItem`
- `UserProfile`
- `FollowRelation`
- `UserRecipeState`
- Smart Import response/draft mapping

The Smart Import response shape should be documented and tested as a shared API contract before Android implementation begins.

## 8. Authentication Plan

Android should use Google Sign-In natively and hand the Google ID token to Supabase Auth when possible.

This avoids showing the random Supabase project URL in the Google consent screen and is better aligned with Android expectations.

Email/password should remain available for parity and tester fallback.

Apple Sign-In is not required for Android MVP.

Supabase provider setup:

- Google OAuth is already active on `Season-dev`.
- Staging should be enabled only when Android staging testing begins.
- Google Cloud OAuth must include Android package name and SHA fingerprints for debug/release builds.

## 9. Smart Import Android Scope

Smart Import is a key Android MVP feature because it gives creators a fast reason to use Season.

Android should call the existing `parse-recipe-caption` Edge Function and then map the result into a local draft composer.

MVP Smart Import behavior:

- Paste caption.
- Parse title, servings, ingredients, quantities, units, and steps.
- Preserve quantities.
- Dedupe ingredients.
- Show catalog matched vs needs review.
- Block publish only when required recipe information is missing.
- Allow manual correction after import.
- Generate catalog training signals through the same backend path, without mutating catalog truth.

The Android implementation must inherit the learning from iOS regressions:

- Do not lose titles except when genuinely absent.
- Do not drop quantities.
- Do not duplicate ingredients.
- Ingredient-only captions can create drafts but should explain missing steps.
- Low-signal/promo captions should not pretend to be complete recipes.

## 10. Design Direction

Android should feel like Season, not like a default Material demo.

Principles:

- Preserve Season's editorial food identity.
- Keep Newsreader-like serif hierarchy where feasible.
- Use platform-appropriate Compose interactions.
- Maintain premium light and dark palettes.
- Avoid over-porting iOS layouts that feel awkward on Android.
- Keep bottom navigation familiar but Android-native.

Design parity should be intentional:

- Same product promise.
- Same key flows.
- Same tone and content hierarchy.
- Platform-native controls where they improve usability.

## 11. Implementation Phases

### Phase 0: Planning and Contract Freeze

- Finalize this plan.
- Create parity checklist.
- Document shared API contracts.
- Decide Android package name.
- Confirm Google Cloud Android OAuth setup.
- Confirm Supabase dev/staging access.

### Phase 1: Project Skeleton

- Create `android-app/`.
- Add Kotlin/Compose project.
- Add environment config for dev only.
- Add logging/privacy policy.
- Add design tokens baseline.
- Add CI/build command notes.

Initial foundation status:

- `android-app/` exists.
- Kotlin + Jetpack Compose Gradle project files exist.
- Build types are declared: `debugDev`, `internalStaging`, `release`.
- A placeholder consumer shell exists for Home, Search, Create, Today, and Profile.
- Gradle wrapper exists.
- Supabase Kotlin Auth/PostGREST and Google Credential Manager are wired.
- Auth UI now supports Google entry, email login/signup, session restore, username onboarding, and logout.
- Home now has an initial read-only Supabase recipe repository and renders a remote hero plus recommended rows from `recipes`.
- Home to recipe detail navigation is wired read-only using the already-loaded `SeasonRecipe` snapshot. No recipe mutations or fetch-by-id are introduced in this phase.
- Search now has a read-only recipe/catalog repository flow with debounce, normalized query cache, and recipe-result navigation into detail.
- Today now has a read-only seasonal catalog repository flow with current-month phase labels and basic ingredient detail.
- `:app:assembleDebugDev` and `:app:assembleInternalStaging` have been validated locally with Android Studio JBR after auth wiring.

### Phase 2: Auth and Session

- Google Sign-In dev: code wired; manual verification pending Google Cloud Android OAuth client and local Gradle secrets.
- Email/password login dev: code wired.
- Username/profile bootstrap: code wired against shared `profiles`.
- Session persistence: code wired through Supabase Auth local session.
- Logout: code wired.

### Phase 3: Read-Only Product Core

- Home feed: initial read-only remote snapshot wired; still needs richer ranking, imagery, and filters.
- Recipe detail: initial Home to detail flow is wired with source, external badge, servings, ingredient quantities, numbered steps, and empty states.
- Search: initial read-only recipe and ingredient search is wired; ingredient deep links and advanced ranking remain later.
- Today seasonal list: initial current-month catalog view is wired with `Al meglio`, `Primizia`, and `Fine stagione` phases; richer curves/visual polish remain later.
- Profile basics.

### Phase 4: Local-First Actions

- Save/crispy.
- Fridge add/remove.
- Shopping list add/remove.
- Outbox/retry.
- Foreground reconciliation.

### Phase 5: Smart Import

- Caption import screen.
- Edge Function integration.
- Draft composer.
- Manual correction.
- Publish path.
- Regression captions from iOS.

### Phase 6: QA and Staging

- Dev E2E.
- Staging config.
- Google Play internal testing prep.
- Privacy/data safety review.
- Crash/logging review.

## 12. Risks

- Supabase Kotlin client maturity may differ from iOS client behavior.
- Google OAuth setup requires Android package and SHA fingerprints.
- Rebuilding local-first/outbox semantics incorrectly could create state drift.
- Smart Import UX can regress if Android draft mapping differs from iOS.
- Design quality can drop if the app becomes a generic Material clone.
- Maintaining iOS and Android separately requires discipline in shared backend contracts.

## 13. Acceptance Criteria For Starting Code

Before feature implementation beyond the skeleton:

- MVP scope is accepted.
- Package name is chosen.
- Auth strategy is confirmed.
- Shared Supabase environments are confirmed.
- Smart Import contract is documented.
- First implementation branch is created from the chosen base.
- `android-app/` ownership and README are agreed.

Current defaults chosen:

- MVP scope: core complete.
- Package: `it.seasonapp.season`.
- Auth: native Google Sign-In plus Supabase Auth.
- Android source ownership: `android-app/`.
