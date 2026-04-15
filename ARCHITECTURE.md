# Season Architecture (Current)

## Architecture Summary
Season is a hybrid local-first app with targeted cloud sync/write-through:
- local state remains the UX source for most interactive domains
- Supabase is used for identity/auth, cloud reads, and selected mutation pipelines
- request-level instrumentation and trace IDs are used across service writes

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

## Known Technical Debt / Next Hardening Areas
- `OutboxStore` on `UserDefaults` has long-term scalability limits.
- `RecipeRepository` still uses schema-drift fallback branches that should be reduced over time.
- Some admin batch operations are client-triggered and rely on strict operational discipline.
- This architecture document should be kept tightly synced with implementation changes.
