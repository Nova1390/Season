# Season Android

Native Android app foundation for Season.

## Status

This is the Android MVP foundation. It intentionally starts as a separate app under `android-app/` so it does not mix with the iOS project.

Current implementation:

- Kotlin + Jetpack Compose project skeleton.
- Package name: `it.seasonapp.season`.
- Build types: `debugDev`, `internalStaging`, `release`.
- Season design tokens baseline.
- Consumer shell tabs: Home, Scopri, Crea, Oggi, Io.
- Environment wiring for Supabase dev/staging URLs.
- Supabase Kotlin Auth/PostgREST client wiring.
- Google Credential Manager Sign-In wiring.
- Email/password auth, session restore, logout, and username onboarding.
- Home read-only recipe loading from Supabase dev.
- Remote recipe domain mapping for title, source, servings, ingredients, steps, and image URL.
- Recipe detail read-only navigation from the Home hero and remote rows.
- Recipe detail renders source, external badge, servings, ingredients with quantities, and numbered steps from the already-loaded recipe snapshot.
- Search read-only for recipes and catalog ingredients, with 300ms debounce and normalized query cache.
- Search recipe results open the same read-only recipe detail without introducing new mutations.
- Today read-only seasonal catalog view with current-month ranking and phase labels: peak, early season, and ending season.
- Today ingredient rows open an in-screen basic ingredient detail using catalog data already loaded from Supabase.
- Recipe detail supports save/unsave and crispy/uncrispy against `user_recipe_states`.
- Recipe state writes use optimistic UI plus a minimal local SharedPreferences outbox with foreground retry.
- Fridge inventory is wired as a global utility screen from the app bar.
- Fridge can list the authenticated user's `fridge_items`, add catalog ingredients, add custom fallback ingredients, and remove items on Supabase dev.
- Shopping List is wired as a global utility screen from the app bar.
- Shopping can list the authenticated user's `shopping_list_items`, add catalog ingredients, add custom fallback ingredients, check/uncheck items, and remove items on Supabase dev.
- Recipe Detail can add all recipe ingredients to Shopping List while preserving quantity, unit, source recipe id, and catalog id when present.
- No service-role secrets and no catalog admin surfaces.
- Gradle wrapper is available.
- `:app:assembleDebugDev` has been validated locally with Android Studio JBR.
- `:app:assembleInternalStaging` has been validated locally with Android Studio JBR.

Not implemented yet:

- Home imagery/richer feed ranking.
- Fridge local outbox/retry and recipes-from-fridge matching.
- Shopping local outbox/retry beyond the current direct Supabase MVP.
- Smart Import publish.

## Recipe State Sync

The Android MVP has a deliberately small outbox for recipe state actions only:

- `Save` and `Crispy` update the UI immediately.
- The app writes to Supabase `user_recipe_states` with the authenticated user session.
- If sync fails, the latest intended value for each `recipe_id + field` is kept locally and retried on foreground/session restore.
- Logout clears local user-specific recipe state and pending recipe-state intents.
- Recipe-state reads and writes refresh the Supabase session before remote sync, so a stale local session does not silently turn into failed outbox work.
- Supabase SDK logging is disabled in the Android client; app logs must keep using the redacted `SeasonLog` wrapper.
- This does not cover fridge, shopping, or Smart Import yet.

## Fridge MVP

The Android Fridge is currently remote-backed and intentionally small:

- The global `Frigo` action opens the user's inventory without adding a sixth bottom tab.
- Catalog ingredients are preferred and stored with `ingredient_id`.
- Custom fallback ingredients are allowed for user utility but never create catalog truth.
- Add/remove operations write directly to Supabase `fridge_items` with the authenticated session.
- Recipes-from-fridge and local outbox/retry are still pending; they will reuse the recipe-state sync pattern once the inventory flow is stable.

## Shopping MVP

The Android Shopping List is currently remote-backed and intentionally small:

- The global `Lista` action opens the user's shopping list without adding a sixth bottom tab.
- Catalog ingredients are stored with `ingredient_type = catalog` plus `ingredient_id`.
- Custom fallback ingredients are stored with `ingredient_type = custom` plus `custom_name`.
- Quantity and unit are optional but preserved when added manually or from Recipe Detail.
- Recipe-derived rows keep `source_recipe_id` for traceability.
- The Recipe Detail CTA skips obvious duplicates with the same ingredient/custom name, quantity, unit, and source recipe id.
- Local outbox/retry is still pending; it will reuse the recipe-state sync contract in the next sync-hardening pass.

## Setup

Install:

- Android Studio
- JDK compatible with the Android Gradle Plugin, or Android Studio's bundled JBR
- Android SDK with API 36

Optional local Gradle properties:

```properties
SEASON_SUPABASE_DEV_ANON_KEY=...
SEASON_SUPABASE_STAGING_ANON_KEY=...
SEASON_GOOGLE_WEB_CLIENT_ID=...
```

Prefer `~/.gradle/gradle.properties` or CI secrets. Do not commit keys into the repo.

For Android Google Sign-In on the dev build, create a Google Cloud Android OAuth client with:

- Package name: `it.seasonapp.season.dev`
- SHA-1: `9C:A9:22:36:B0:0C:98:BD:A4:1C:18:A0:A0:60:FA:0F:B9:79:DE:68`
- SHA-256: `96:5D:A7:E3:41:B9:31:FB:2A:94:2B:4C:23:D2:56:48:48:28:94:8F:0B:66:C1:40:54:24:07:77:B6:DE:A7:53`

The app uses the web client id in `SEASON_GOOGLE_WEB_CLIENT_ID` as the server client id for native Google Identity, then exchanges the returned ID token with Supabase Auth.

Important: `SEASON_GOOGLE_WEB_CLIENT_ID` must be the OAuth client of type `Web application`, usually the same client configured in the Supabase Google provider. The Android OAuth client above is still required for package/SHA verification, but it must not be pasted into `SEASON_GOOGLE_WEB_CLIENT_ID`.

## Build

From `android-app/`:

```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebugDev
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleInternalStaging
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:signingReport
```

If `JAVA_HOME` is already configured, the shorter commands are:

```bash
./gradlew :app:assembleDebugDev
./gradlew :app:assembleInternalStaging
```

## Implementation Order

Follow:

- `../docs/android-branch-status.md`
- `../docs/android-port-plan.md`
- `../docs/android-mvp-parity-checklist.md`
- `../docs/android-shared-contracts.md`
