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
- No service-role secrets and no catalog admin surfaces.

Not implemented yet:

- Supabase Kotlin client.
- Google Sign-In native token exchange.
- Remote recipes.
- Local-first outbox.
- Smart Import publish.

## Setup

Install:

- Android Studio
- JDK compatible with the Android Gradle Plugin
- Android SDK with API 36

Optional local Gradle properties:

```properties
SEASON_SUPABASE_DEV_ANON_KEY=...
SEASON_SUPABASE_STAGING_ANON_KEY=...
```

Prefer `~/.gradle/gradle.properties` or CI secrets. Do not commit keys into the repo.

## Build

From `android-app/`:

```bash
./gradlew :app:assembleDebugDev
./gradlew :app:assembleInternalStaging
```

This repository currently does not include a Gradle wrapper jar. If Android Studio creates/updates the wrapper, commit the wrapper files together in a dedicated Android tooling commit.

## Implementation Order

Follow:

- `../docs/android-port-plan.md`
- `../docs/android-mvp-parity-checklist.md`
- `../docs/android-shared-contracts.md`

