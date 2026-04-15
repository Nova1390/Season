# Current Status

## Working Today
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
- Recipe ingredient model/fetch now supports canonical `ingredient_id` (with legacy `produce_id`/`basic_ingredient_id` compatibility).
- Catalog hierarchy fields are active (`parent_ingredient_id`, `specificity_rank`, `variant_kind`) with write-through in active catalog flow.
- Recipe reconciliation now has two apply paths:
  - legacy apply (legacy mapping dependent)
  - modern safe apply (`apply_recipe_ingredient_reconciliation_modern`) for safe modern matches.
- Catalog admin/debug operations are active in-app (`CatalogCandidatesDebugView` + `CatalogAdminOpsService`).
- Supabase requests have instrumentation logs with trace IDs and failure categories.

## Known Technical Debt / Next Hardening Areas
- `OutboxStore` uses `UserDefaults`; scale/operability limits remain for long-lived high-volume queues.
- `RecipeRepository` still carries schema-drift fallback branches for backward compatibility.
- Catalog/admin batch operations are client-triggered and require strict admin workflow discipline.
- Architecture/status docs must be kept aligned with implementation as these flows evolve.
