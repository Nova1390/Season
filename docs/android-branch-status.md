# Android Branch Status

Last updated: 2026-05-22

Branch: `feature/android-mvp-foundation`

Environment: `Season-dev` only until the MVP flows are stable.

## Purpose

This branch is the native Android MVP foundation for Season. It ports the iOS product into Kotlin + Jetpack Compose while keeping Supabase as the shared source of truth.

The Android app lives in `android-app/` and must stay separate from the iOS app source under `Season/`.

## Current Implementation

Done on this branch:

- Android project skeleton in `android-app/`.
- Build variants: `debugDev`, `internalStaging`, `release`.
- Supabase environment wiring for dev/staging.
- Supabase Kotlin Auth and PostgREST client.
- Google Credential Manager Sign-In.
- Email/password sign-in and sign-up.
- Session restore, logout, and username onboarding.
- Main shell with bottom tabs: Home, Scopri, Crea, Oggi, Io.
- Home read-only Supabase recipe feed.
- Recipe Detail read-only from Home/Search snapshots.
- Search read-only for recipes and catalog ingredients with debounce/cache.
- Today read-only seasonal catalog screen with phase labels.
- Save/crispy recipe state from Recipe Detail.
- Minimal local outbox for save/crispy retry.
- Fridge inventory screen from the top app bar.
- Fridge Supabase dev list/add/remove for catalog and custom ingredients.
- Shopping List utility screen from the top app bar.
- Shopping Supabase dev list/add catalog/add custom/check/remove.
- Recipe Detail CTA to add recipe ingredients to the Shopping List while preserving quantity, unit, source recipe id, and catalog id when available.
- Fridge “Cosa puoi cucinare” MVP with ready, missing-few, and almost-ready recipe groups.
- Fridge recipe matching uses catalog `ingredient_id` first and a conservative normalized-name fallback for custom items.
- Fridge missing-ingredient CTA can send only missing recipe ingredients to Shopping List.
- Shared JSON outbox store for local-first Android mutation queues.
- Fridge add/remove now uses local intent + foreground retry.
- Shopping add/check/remove now uses local intent + foreground retry.
- Smart Import draft flow from the `Crea` tab.
- Smart Import calls `parse-recipe-caption` with the authenticated Supabase session and maps the response into an editable draft.
- Smart Import draft dedupes ingredients and preserves title, servings, quantity/unit, steps, confidence, and catalog match hints.
- Smart Import publish inserts validated drafts into Supabase dev `recipes` as `user_generated` recipes.
- Profile MVP shows username plus saved and published recipe sections.
- Profile recipe rows can open the existing Recipe Detail screen.
- Documentation for Android contracts, MVP checklist, and porting direction.

## Validated

Latest validated checks:

- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebugDev`
- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleInternalStaging`
- Emulator smoke: login/session restore, Home, Recipe Detail, Search, Today.
- Emulator smoke: save/crispy toggle.
- Emulator smoke: Fridge open, add/remove custom, add/remove catalog ingredient.
- Build validation: Shopping List and Recipe Detail shopping CTA compile on `debugDev` and `internalStaging`.
- Build validation: Recipes-from-fridge matching and missing-to-shopping CTA compile on `debugDev` and `internalStaging`.
- Build validation: Fridge/Shopping outbox compile on `debugDev` and `internalStaging`.
- Build validation: Smart Import draft flow compiles on `debugDev` and `internalStaging`.
- Build validation: Smart Import publish flow compiles on `debugDev` and `internalStaging`.
- Build validation: Profile saved/published recipe sections compile on `debugDev` and `internalStaging`.
- Dev QA gate pass, 2026-05-22: installed `debugDev` on emulator and smoke-tested Home, Search, Today, Create/Smart Import entry, Profile, Shopping List, and Fridge inventory.
- Dev QA log pass, 2026-05-22: process-filtered logcat showed no Season crash, Supabase/PostgREST error, or feature-level error after the smoke flow.

## Known Limits

Not done yet:

- Home imagery and richer ranking.
- Recipes-from-fridge ranking is MVP-level and still needs richer scoring/visual polish.
- Fridge/Shopping outbox is MVP-level SharedPreferences JSON; Room can be introduced later if queues become more complex.
- Delete intents update UI optimistically; failed deletes are retained in outbox but not re-shown as visible rows yet.
- Shopping duplicate prevention is currently an MVP client-side guard, not a full offline reconciliation layer.
- Smart Import direct open-after-publish is deferred until fetch-by-id/deep-link support.
- Smart Import manual field editing before publish is still minimal; the user currently edits the source caption and re-imports.
- Smart Import draft still needs broader live caption QA on emulator/device before Play internal testing.
- Profile recipe lists are capped by the current 100-recipe MVP fetch window.
- Recipes-from-fridge section still needs a dedicated full-scroll QA pass with controlled fridge contents before Play internal testing.
- Staging QA and Google Play Internal Testing prep.

## Next Implementation Order

Recommended next steps:

1. Full Smart Import regression caption pass on emulator/device.
2. Recipes-from-fridge controlled data QA.
3. Staging configuration and Play Internal Testing prep.

## Guardrails

- Android uses anon key plus authenticated user session only.
- Android never uses service-role keys.
- Android never mutates catalog governance tables.
- Catalog governance remains on `catalog.seasonapp.it`.
- `admin-console/` is outside Android MVP scope.
- New Android behavior must update:
  - `android-app/README.md`
  - `docs/android-mvp-parity-checklist.md`
  - `docs/android-shared-contracts.md`
  - this status file when branch status changes.
