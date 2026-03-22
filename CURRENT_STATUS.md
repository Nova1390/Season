# Current Status

## Working Today
- Supabase auth path is integrated for app testing flows.
- `profiles` can be read for the authenticated user.
- `linked_social_accounts` can be read for the authenticated user.
- `user_recipe_states` can be read for the authenticated user.
- Recipe state write-through is active for:
  - save/unsave (`is_saved`)
  - crispy toggle (`is_crispied`)
- Supabase requests have local instrumentation logs with duration and failure category.
- Recipe-state writes include trace IDs across local update -> service call -> write result logs.

## Not Implemented Yet
- No bidirectional sync between local state and Supabase.
- No cloud-first source of truth for recipe state.
- No write-through yet for `is_archived`, fridge, or shopping list.
- No outbox/offline queue.
- No conflict resolution layer.

## Known Limitations
- No sync means state can diverge across devices.
- Write-through failures do not reconcile automatically.
- Retry is minimal (single transient retry), not guaranteed delivery.
- Local state remains primary for recipe state UX.

