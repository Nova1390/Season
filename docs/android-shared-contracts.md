# Android Shared Backend Contracts

Last updated: 2026-05-22

This document captures the backend contracts Android should reuse from iOS.

The goal is to avoid a second interpretation of Season's data model. Android can have native UI and native state management, but it should share the same Supabase truth, Edge Function contracts, and sync semantics.

## 1. Environment Contract

Android should support environment switching without code edits.

Required environments:

| Environment | Supabase project | Purpose |
|---|---|---|
| Dev | `Season-dev` | Android development and internal debugging. |
| Staging | `Season-staging` | Closed testing / Play internal testing. |
| Production | TBD | Future public release. |

Rules:

- Do not point Android production builds at dev.
- Do not mutate staging catalog governance without explicit release approval.
- Do not store service-role keys in Android.
- Public client keys must be scoped through RLS and grants.

## 2. Auth Contract

Android MVP should support:

- Google Sign-In.
- Email/password.
- Session restore.
- Logout.
- Username/profile completion.

Google Sign-In should prefer native Android Google identity flow, then exchange the ID token with Supabase Auth.

Required Google Cloud items before Android auth implementation:

- Android OAuth client.
- Android dev package name: `it.seasonapp.season.dev`.
- Debug SHA-1: `9C:A9:22:36:B0:0C:98:BD:A4:1C:18:A0:A0:60:FA:0F:B9:79:DE:68`.
- Debug SHA-256: `96:5D:A7:E3:41:B9:31:FB:2A:94:2B:4C:23:D2:56:48:48:28:94:8F:0B:66:C1:40:54:24:07:77:B6:DE:A7:53`.
- Release SHA-1/SHA-256 before public testing.
- Web OAuth client remains used by Supabase provider setup.

Required Supabase behavior:

- Google provider enabled per environment.
- Email/password enabled per environment.
- Redirect/callback rules documented per environment.
- RLS must allow authenticated users to read/update their own profile.

Current Android implementation status:

- Supabase Kotlin Auth/PostgREST is wired behind a dev/staging environment gate.
- Google Credential Manager requests a Google ID token and exchanges it with Supabase.
- Email/password sign-in and sign-up call Supabase Auth directly.
- Session restore checks the local Supabase session before showing the signed-out screen.
- Username onboarding writes only to the authenticated user's `profiles` row.
- `Season-dev` is the only intended environment for this phase.

## 3. Profile Contract

Shared table:

- `profiles`

Android should read/write only user-owned fields through RLS-safe operations.

Required fields for MVP:

- user id
- username
- display name
- avatar URL
- language preference
- admin flag read-only if exposed at all

Android should not expose catalog/admin tools even if an admin flag exists.

## 4. Recipe Contract

Shared table:

- `recipes`

Android should render remote published recipes as source of truth.

Required MVP fields:

- id
- title
- description
- image/media URL
- source domain/title
- creator id/name
- servings
- ingredients
- steps
- tags/metadata where available
- published/visibility status

Rules:

- Do not use seed recipes as release truth.
- Preserve remote recipe IDs exactly for saved/crispy/shopping references.
- Keep ingredient identity fields intact: `ingredient_id`, `produce_id`, `basic_ingredient_id`, raw text, confidence, quantity, and unit.

## 5. Recipe State Contract

Shared table:

- `user_recipe_states`

MVP actions:

- save/unsave
- crispy/uncrispy
- optional archive later

Semantics:

- UI should update locally first.
- Remote write should be queued/retried.
- Foreground/app launch should reconcile pending state.
- Failed sync must not silently lose user intent.

Android should mirror the iOS outbox idea, not necessarily its storage implementation.

Android MVP implementation:

- Recipe state outbox is intentionally limited to `save/unsave` and `crispy/uncrispy`.
- Pending intents are keyed by `recipe_id + field`; the newest target value wins.
- The UI applies the intended value immediately, then Supabase confirms through `user_recipe_states`.
- Foreground/session restore retries pending intents.
- Before fetching or applying recipe-state mutations, Android refreshes the Supabase session and leaves the intent pending if auth/network refresh fails.
- Logout clears local user-specific recipe-state cache and pending intents.
- Fridge and shopping will reuse the same local-first contract later, but are not covered by this recipe-state outbox.

## 6. Fridge Contract

Shared table:

- `fridge_items`

MVP actions:

- add ingredient
- remove ingredient
- list user's fridge items
- match recipes from fridge

Rules:

- Prefer catalog/canonical ingredient references when available.
- Allow custom fallback for user utility.
- Custom fallback must feed observation/training paths only.
- Android must not create canonical catalog items directly.

Android MVP implementation:

- The first Android Fridge screen reads the authenticated user's `fridge_items`, enriches catalog rows through `ingredient_catalog_app_summary`, and writes add/remove through a local-first JSON outbox.
- Catalog adds store `ingredient_type = catalog` plus `ingredient_id`, matching the iOS `FridgeViewModel` contract.
- Custom fallback adds store `ingredient_type = custom` plus `custom_name`.
- The screen prevents obvious duplicate custom names locally, but backend uniqueness is not assumed.
- Recipes-from-fridge is available as an MVP derived view using already-fetched published recipes.
- Matching prefers recipe ingredient `ingredient_id` against catalog fridge rows, then normalized ingredient names against custom fridge rows.
- Recipes with fewer than two structured ingredients are ignored so smoke-test/low-signal rows do not dominate the user-facing groups.
- Recipes are grouped as ready, missing-few, and almost-ready; this is user utility scoring, not catalog truth.
- Missing recipe ingredients can be sent to Shopping List with `source_recipe_id`, quantity, unit, and catalog id when available.
- Fridge add/remove uses a local JSON outbox with optimistic UI and foreground retry.
- Delete intents are retained until synced, but the MVP UI removes the row immediately and does not re-show failed deletes yet.

## 7. Shopping List Contract

Shared table:

- `shopping_list_items`

MVP actions:

- add manual item
- add missing recipe ingredient
- remove/check item
- preserve quantity and unit

Rules:

- Recipe-derived items should keep recipe context when available.
- Catalog IDs should be preserved.
- Local-first actions need retry/reconciliation.

Android MVP implementation:

- The first Android Shopping List screen reads the authenticated user's `shopping_list_items`, enriches catalog rows through `ingredient_catalog_app_summary`, and writes add/check/remove through a local-first JSON outbox.
- Catalog adds store `ingredient_type = catalog` plus `ingredient_id`, matching the iOS shopping contract.
- Custom fallback adds store `ingredient_type = custom` plus `custom_name`.
- Manual adds and Recipe Detail adds preserve `quantity` and `unit` when available.
- Recipe-derived rows keep `source_recipe_id` so future grouping/reconciliation can attribute items back to a recipe.
- The Android client skips obvious duplicates using `ingredient_id/custom display name + quantity + unit + source_recipe_id`.
- Shopping add/check/remove uses a local JSON outbox with optimistic UI and foreground retry.
- Add/check visible pending rows show `Sincronizzazione…` or `Da sincronizzare`.
- Delete intents are retained until synced, but the MVP UI removes the row immediately and does not re-show failed deletes yet.

## 7.1 Shared Android Outbox Contract

Android now has a reusable SharedPreferences JSON outbox store for lightweight user mutations.

Rules:

- Every pending mutation is scoped by authenticated `user_id`.
- Each intent exposes a stable merge key so the latest equivalent operation wins.
- UI applies the user's intent immediately.
- Foreground/session restore retries pending work.
- Logout clears user-specific pending work.
- The outbox stores no secrets, tokens, email addresses, or raw Supabase payloads.
- Room can replace this implementation later without changing the feature-level contract.

## 8. Smart Import Contract

Shared Edge Function:

- `parse-recipe-caption`

Input:

- caption text
- optional source URL/media URL
- optional language/context metadata

Expected output:

- title
- servings
- ingredients
- quantity/unit per ingredient where present
- steps
- quality/completeness signals
- catalog match status
- unresolved/custom ingredient signals

Android mapping rules:

- Do not discard parsed title unless absent.
- Do not discard quantity/unit.
- Dedupe by catalog id first, then normalized name, then quantity/unit.
- Missing steps should block publish but not invalidate ingredients.
- Ingredient-only captions should produce a draft with clear missing-step guidance.
- Promo/low-signal captions should not be marked as publish-ready.
- Android draft creation uses the authenticated Supabase session and anon key only; no service role or catalog-admin path is available in the client.
- Android keeps catalog match hints as draft context. It does not create canonical ingredients, aliases, or catalog truth from Smart Import.

Current Android MVP status:

- Draft creation is wired from the `Crea` tab.
- Publish is wired for validated drafts and inserts into `recipes` with `source_type = user_generated`.
- Manual correction is still limited to re-running import from edited caption/link input; dedicated draft field editing remains a follow-up.
- Publish confirmation currently returns the created recipe id. Direct navigation to the newly created detail requires the later fetch-by-id/deep-link path.

Regression captions are listed in `docs/android-mvp-parity-checklist.md`.

## 9. Catalog Contract

Shared catalog concepts:

- `ingredients`
- `ingredient_localizations`
- `ingredient_aliases_v2`
- `legacy_ingredient_mapping`

Android can read catalog data needed for:

- ingredient display
- search
- fridge add
- shopping list add
- recipe ingredient display
- Smart Import match review

Android cannot:

- approve aliases directly
- create canonical ingredients directly
- run catalog admin operations from the app
- bypass validators/RPC guardrails

Catalog governance remains external:

- Supabase RPCs and Edge Functions.
- `catalog.seasonapp.it`.
- Audit/learning tables.

## 10. Android Profile Contract

The Android MVP profile is consumer-facing only.

- Read the authenticated user's public profile data already available after onboarding.
- Read saved recipe ids from `user_recipe_states` where `is_saved = true`.
- Read published recipes from `recipes.user_id`.
- Never expose catalog governance/admin controls in the Android app.
- MVP profile recipe sections may use the current recipe feed window; dedicated pagination can follow before wider beta if the user has many recipes.

## 11. Follow and Social Contract

Shared table:

- `follows`

MVP status:

- Profile basics can ship before follow UX.
- Follow actions can be added after core recipe/fridge/shopping flows are stable.

Rules:

- Follow sync should use authenticated user ownership.
- Notifications from follows are later-stage.

## 12. Notifications Contract

Android MVP can defer notifications.

When implemented:

- local inbox can mirror iOS notification center concepts;
- push notifications should use FCM;
- backend notification table should be designed before cross-device notification state is expected;
- follow/crispy notifications should be derived or event-driven, not hardcoded.

## 13. Logging and Privacy Contract

Android must follow the same privacy posture as iOS:

- No service-role key in client.
- No raw callback URLs in release logs.
- No emails/user IDs in release logs unless explicitly redacted.
- No raw Supabase payload dumps in release logs.
- No recipe/user state debug surfaces in public builds.
- Debug logs gated by build type or explicit internal flag.
- Supabase SDK logging is disabled at client creation; domain logs must go through the redacted app logger.

## 14. Decisions And Remaining Setup

- Android package name: `it.seasonapp.season`.
- MVP scope: core complete.
- Smart Import scope: draft creation plus publish.
- Google Play account/package ownership.
- Debug and release signing setup.
- Whether Android should share staging with iOS TestFlight or use a separate staging project later.
- Minimum Android version.
- Push notification timing.
- Release/prod Supabase project strategy.

Current implementation foundation:

- Android app source lives in `android-app/`.
- Build types map to dev, staging, and future production.
- Client config must never include service-role keys.
