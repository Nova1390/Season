# Android Shared Backend Contracts

Last updated: 2026-05-17

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
- Android package name.
- Debug SHA-1/SHA-256.
- Release SHA-1/SHA-256 before public testing.
- Web OAuth client remains used by Supabase provider setup.

Required Supabase behavior:

- Google provider enabled per environment.
- Email/password enabled per environment.
- Redirect/callback rules documented per environment.
- RLS must allow authenticated users to read/update their own profile.

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

## 10. Follow and Social Contract

Shared table:

- `follows`

MVP status:

- Profile basics can ship before follow UX.
- Follow actions can be added after core recipe/fridge/shopping flows are stable.

Rules:

- Follow sync should use authenticated user ownership.
- Notifications from follows are later-stage.

## 11. Notifications Contract

Android MVP can defer notifications.

When implemented:

- local inbox can mirror iOS notification center concepts;
- push notifications should use FCM;
- backend notification table should be designed before cross-device notification state is expected;
- follow/crispy notifications should be derived or event-driven, not hardcoded.

## 12. Logging and Privacy Contract

Android must follow the same privacy posture as iOS:

- No service-role key in client.
- No raw callback URLs in release logs.
- No emails/user IDs in release logs unless explicitly redacted.
- No raw Supabase payload dumps in release logs.
- No recipe/user state debug surfaces in public builds.
- Debug logs gated by build type or explicit internal flag.

## 13. Open Questions Before Coding

- Android package name: likely `com.roccodaffuso.season` or `it.seasonapp.season`.
- Google Play account/package ownership.
- Debug and release signing setup.
- Whether Android should share staging with iOS TestFlight or use a separate staging project later.
- Minimum Android version.
- Push notification timing.
- Whether first Android MVP should include recipe publishing or stop at draft creation.

