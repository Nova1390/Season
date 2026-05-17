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
- No service-role secrets and no catalog admin surfaces.
- Gradle wrapper is available.
- `:app:assembleDebugDev` has been validated locally with Android Studio JBR.
- `:app:assembleInternalStaging` has been validated locally with Android Studio JBR.

Not implemented yet:

- Remote recipes.
- Local-first outbox.
- Smart Import publish.

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

- `../docs/android-port-plan.md`
- `../docs/android-mvp-parity-checklist.md`
- `../docs/android-shared-contracts.md`
