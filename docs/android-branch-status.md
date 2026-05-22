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
- Documentation for Android contracts, MVP checklist, and porting direction.

## Validated

Latest validated checks:

- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebugDev`
- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleInternalStaging`
- Emulator smoke: login/session restore, Home, Recipe Detail, Search, Today.
- Emulator smoke: save/crispy toggle.
- Emulator smoke: Fridge open, add/remove custom, add/remove catalog ingredient.
- Build validation: Shopping List and Recipe Detail shopping CTA compile on `debugDev` and `internalStaging`.

## Known Limits

Not done yet:

- Home imagery and richer ranking.
- Fridge local outbox/retry.
- Recipes-from-fridge matching.
- Shopping local outbox/retry.
- Shopping duplicate prevention is currently an MVP client-side guard, not a full offline reconciliation layer.
- Smart Import Android draft and publish.
- Profile saved/published recipe lists.
- Staging QA and Google Play Internal Testing prep.

## Next Implementation Order

Recommended next steps:

1. Recipes-from-fridge list.
2. Fridge and Shopping local outbox/retry.
3. Smart Import draft flow.
4. Smart Import publish flow.
5. Profile saved/published sections.
6. Full dev QA.
7. Staging configuration and Play Internal Testing prep.

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
