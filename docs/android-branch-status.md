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
- Documentation for Android contracts, MVP checklist, and porting direction.

## Validated

Latest validated checks:

- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebugDev`
- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleInternalStaging`
- Emulator smoke: login/session restore, Home, Recipe Detail, Search, Today.
- Emulator smoke: save/crispy toggle.
- Emulator smoke: Fridge open, add/remove custom, add/remove catalog ingredient.

## Known Limits

Not done yet:

- Home imagery and richer ranking.
- Fridge local outbox/retry.
- Recipes-from-fridge matching.
- Shopping list.
- Smart Import Android draft and publish.
- Profile saved/published recipe lists.
- Staging QA and Google Play Internal Testing prep.

## Next Implementation Order

Recommended next steps:

1. Shopping List MVP with manual add/remove and Supabase sync.
2. Add-from-recipe CTA from Recipe Detail into Shopping List.
3. Recipes-from-fridge list.
4. Fridge and Shopping local outbox/retry.
5. Smart Import draft flow.
6. Smart Import publish flow.
7. Profile saved/published sections.
8. Full dev QA.
9. Staging configuration and Play Internal Testing prep.

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
