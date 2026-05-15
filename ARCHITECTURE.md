# Season Architecture (Current)

## Architecture Summary
Season is a hybrid local-first app with targeted cloud sync/write-through:
- local state remains the UX source for most interactive domains
- Supabase is used for identity/auth, cloud reads, and selected mutation pipelines
- request-level instrumentation and trace IDs are used across service writes
- published recipe/catalog content is expected to come from Supabase, not local recipe seed payloads

## Release & Environment Model
- Debug is configured for the development Supabase environment.
- Release is configured for the staging Supabase environment for TestFlight preparation.
- `agent/catalog-governance` is a dev-only branch until a separate staging promotion is approved.
- The app no longer loads the removed TheMealDB `seed_recipes.json` payload; staging is the recipe catalog source of truth for release validation.
- `Season/PrivacyInfo.xcprivacy` declares app-level accessed API usage for UserDefaults.
- Staging operational scripts live under `supabase/devops/`, including TestFlight preflight and catalog autopilot schedule/verify/unschedule scripts.

## Write & Sync Model (Current)

### Outbox-First Domains
- `fridge_items` and `shopping_list_items` are outbox-first.
- Local mutations enqueue `OutboxMutationRecord` in `OutboxStore`.
- `OutboxDispatcher` replays pending mutations to Supabase with retry/backoff and status tracking.
- `BackfillService` converges onto this same path (enqueue + dispatcher), not direct create writes.

### Follow Sync (Delta-Based)
- Local follow state is stored in `FollowStore`.
- `FollowRelation` includes minimal sync metadata:
  - `isActive`
  - `pendingSyncOperation` (`create` / `delete` / `none`)
  - `lastSyncedAt`
- Unfollow uses local tombstones (`pending delete`) so delete intent survives until backend sync.
- `FollowSyncManager.syncToBackend()` processes only pending follow rows; no full-set re-push loop.

### Recipe State & Repository
- `user_recipe_states` remains local-first in UI with write-through for:
  - `is_saved`
  - `is_crispied`
- Recipe cloud access is extracted behind `RecipeRepository` (create/fetch + compatibility fallbacks).
- `RecipeStore` is now local-user/draft oriented. Published feed quality depends on Supabase hydration and repository merge behavior.

## Catalog & Reconciliation Model (Current)
- Ingredient hierarchy is active in canonical catalog model:
  - `parent_ingredient_id`
  - `specificity_rank`
  - `variant_kind`
- Active catalog enrichment/creation flow now writes hierarchy fields when resolvable, with conservative fallback behavior.
- Admin/debug catalog operations are available in-app (`CatalogCandidatesDebugView` via `CatalogAdminOpsService`).
- Recipe reconciliation apply has two paths:
  - legacy apply path (legacy bridge dependent)
  - modern safe apply path (`apply_recipe_ingredient_reconciliation_modern`) for safe modern matches.
- iOS recipe ingredient model/fetch now supports `ingredient_id` while retaining legacy compatibility (`produce_id`, `basic_ingredient_id`).

## Agent & Smart Import Model (Current Dev Branch)
- The Catalog Governance Agent is the manager-level catalog operator for dev: it can triage unresolved observations, attach deterministic matcher hints, generate governed proposals, delegate bounded workers, and record worker/AI usage.
- Autopilot and batch functions are bounded workers, not independent catalog owners.
- Smart Import is the creator-facing drafting agent: it can parse social captions, preserve quantities, dedupe ingredient candidates, use advisory catalog learning memory, and return creator-friendly quality guidance without mutating catalog truth.
- Catalog mutations still go through governed backend writers, validators, feature flags, and audit tables.
- Staging autonomy remains out of scope for this branch until a dedicated promotion checklist is accepted.

## Known Technical Debt / Next Hardening Areas
- TestFlight build `1.0.1 (4)` is historical release-line context; App Store Connect processing/review steps remain operational outside this dev branch.
- Staging preflight SQL should be run against the staging project before each release candidate and after catalog/security changes.
- `OutboxStore` on `UserDefaults` has long-term scalability limits.
- `RecipeRepository` still uses schema-drift fallback branches that should be reduced over time.
- Cloud-to-local hydration is incomplete for fridge/shopping/recipe states.
- Some admin batch operations are client-triggered and rely on strict operational discipline.
- Supabase PAT rotation is still recommended before staging or external tester operational work.
- This architecture document should be kept tightly synced with implementation changes.
