# Current Status

## Working Today
- Release/TestFlight work remains on the staging-backed release line; the last documented fast bugfix candidate is `1.0.1 (4)`.
- This branch, `agent/catalog-governance`, is a dev-only branch for Catalog Governance Agent and Smart Import Agent work.
- Debug builds target the development Supabase environment; Release builds target the staging Supabase environment.
- `Season/PrivacyInfo.xcprivacy` is present and lint-clean for app-level privacy manifest coverage.
- Supabase auth path is integrated for app testing flows.
- `profiles` can be read for the authenticated user.
- `linked_social_accounts` can be read for the authenticated user.
- `user_recipe_states` can be read for the authenticated user.
- Recipe state write-through is active for:
  - save/unsave (`is_saved`)
  - crispy toggle (`is_crispied`)
- Fridge and shopping-list writes are outbox-first (`OutboxStore` + `OutboxDispatcher`).
- `BackfillService` for fridge/shopping now enqueues outbox mutations and dispatches them (no direct create writes).
- Follow sync uses delta tracking with local pending operations:
  - follow -> pending create
  - unfollow -> pending delete tombstone
  - `syncToBackend()` processes only pending rows.
- Recipe persistence uses extracted `RecipeRepository` read/write layer.
- Published recipe content is expected to come from Supabase. The local TheMealDB seed payload and loader have been removed from the app bundle path.
- Recipe ingredient model/fetch now supports canonical `ingredient_id` (with legacy `produce_id`/`basic_ingredient_id` compatibility).
- Catalog hierarchy fields are active (`parent_ingredient_id`, `specificity_rank`, `variant_kind`) with write-through in active catalog flow.
- Smart Import can parse social-style captions through `parse-recipe-caption`, preserve explicit quantities, dedupe duplicate ingredient candidates, and emit creator-facing quality states.
- Recipe reconciliation now has two apply paths:
  - legacy apply (legacy mapping dependent)
  - modern safe apply (`apply_recipe_ingredient_reconciliation_modern`) for safe modern matches.
- Catalog Governance Agent operations are dev-first and managed through the separate admin console at `https://catalog.seasonapp.it/`.
- Staging-specific catalog autopilot schedule/verify/unschedule scripts live under `supabase/devops/`.
- TestFlight staging preflight checks live in `supabase/devops/staging_testflight_preflight.sql`.
- Supabase requests have instrumentation logs with trace IDs and failure categories.
- Supabase dev schema is clean as of the 2026-05-15 branch audit: no pending migrations and no `supabase db lint` schema errors.

## Known Technical Debt / Next Hardening Areas
- App Store Connect processing, beta review, tester-group assignment, and external tester rollout remain operational release steps.
- Catalog-agent staging promotion is intentionally blocked until a separate promotion checklist and staging-specific smoke plan are approved.
- Staging preflight SQL should be run against the staging project before each release candidate and after catalog/security changes.
- `OutboxStore` uses `UserDefaults`; scale/operability limits remain for long-lived high-volume queues.
- `RecipeRepository` still carries schema-drift fallback branches for backward compatibility.
- Cloud-to-local hydration is still incomplete for fridge, shopping list, and recipe state domains.
- Real catalog/admin batch mutations remain gated by backend feature flags, worker ledgers, and admin workflow discipline.
- The Supabase PAT used during development should still be rotated before staging promotion or other sensitive deploy windows.
- Architecture/status docs must be kept aligned with implementation as these flows evolve.
