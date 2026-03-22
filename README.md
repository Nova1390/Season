# Season iOS App

## What Is Season
Season is an iOS app for ingredient-aware cooking decisions.  
It combines local recipe usage (saved/crispied/archived), fridge and shopping workflows, and seasonal ingredient context.

## Current Architecture
- Client: SwiftUI iOS app
- Backend: Supabase (auth + selected user data tables)
- Local persistence: UserDefaults/AppStorage + local bundled data
- Integration model: hybrid local + cloud (incremental migration)

## Current Data Model Approach
- `profiles`: cloud-first read in Account view (local fallback)
- `linked_social_accounts`: cloud-first read in Account view (local fallback)
- `user_recipe_states`: local-first with non-blocking Supabase write-through for:
  - `is_saved`
  - `is_crispied`
  - no sync yet
- `fridge_items`: local-only
- `shopping_list_items`: local-only

## Backend Strategy
Incremental backend adoption:
1. Read-only integration
2. Write-through for selected mutations
3. Full sync (future)

## Current Development Status
Phase 1 (Stabilization) is completed with:
- RLS validation
- write-through tracing
- network error taxonomy
- Supabase request instrumentation

