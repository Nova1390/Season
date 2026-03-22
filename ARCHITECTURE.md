# Season Architecture (Current)

## Hybrid Model
Season currently uses a hybrid architecture:
- local state for core app continuity and responsiveness
- Supabase for authenticated identity data and selected cloud write-through

The app is not yet in full sync mode.

## Cloud-First vs Local-First

### Cloud-First (read)
- `profiles`
- `linked_social_accounts`

Account screens prefer cloud values when available, with safe local fallback.

### Local-First (state)
- `user_recipe_states` (UI source of truth is still local)
- `fridge_items`
- `shopping_list_items`

For `user_recipe_states`, selected fields are written through to cloud non-blockingly.

## Write-Through Concept
Write-through in Season means:
1. Local mutation happens first (primary behavior)
2. Cloud mutation is attempted asynchronously
3. Failures are logged and classified
4. No blocking UI, no sync reconciliation yet

Current write-through coverage:
- recipe `is_saved`
- recipe `is_crispied`

## Domain Breakdown
- Identity domain:
  - Supabase auth
  - profile read
  - linked social accounts read
- Recipe state domain:
  - local saved/crispied/archived state
  - partial cloud write-through (`is_saved`, `is_crispied`)
- Pantry domain:
  - fridge and shopping list remain local-only
- Observability domain:
  - request-level Supabase instrumentation
  - trace IDs for recipe state mutations
  - error category taxonomy for failures

