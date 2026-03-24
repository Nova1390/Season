# Season Data Architecture

This document reflects the current behavior in code (`ProduceViewModel`, `ShoppingListViewModel`, `FridgeViewModel`, `RecipeStore`, `SupabaseService`, `OutboxStore`, `OutboxDispatcher`, `AccountView`).

### Produce

**Source of Truth**  
Local

**Local Storage**  
- Bundled JSON (`produce.json`) loaded through `ProduceStore.loadFromBundle()`
- In-memory cache in `ProduceViewModel`

**Remote Storage (Supabase)**  
none

**Write Strategy**  
Read-only domain (no write path)

**Read Strategy**  
Local bundle load on app startup

**Sync Behavior**  
No sync (static catalog)

**Current Limitations**  
- Catalog updates require app update / bundled data refresh
- No remote override path

### Recipes

**Source of Truth**  
Hybrid (local-first feed + remote merge)

**Local Storage**  
- `RecipeStore` cached in memory
- Curated seed recipes in code + `seed_recipes.json`
- User-created recipes in `UserDefaults` (`userCreatedRecipesData`)

**Remote Storage (Supabase)**  
- `recipes`

**Write Strategy**  
- Publish: local upsert first (`RecipeStore.upsertUserRecipe`) then non-blocking direct remote insert (`SupabaseService.createRecipe`)
- Draft save: local only

**Read Strategy**  
- Load local recipes first
- Then fetch remote recipes and merge by `recipe.id` (keep first seen)

**Sync Behavior**  
Best-effort merge on load; no authoritative reconciliation

**Current Limitations**  
- Remote recipe mapping back to local model is lossy (e.g., author defaults to `"Season"`)
- No conflict resolution if same `recipe.id` diverges
- No remote draft model

### Recipe States (saved / crispy)

**Source of Truth**  
Local-first

**Local Storage**  
- `UserDefaults` string sets in `ProduceViewModel`
  - `savedRecipeIDsRaw`
  - `crispiedRecipeIDsRaw`
  - `archivedRecipeIDsRaw`

**Remote Storage (Supabase)**  
- `user_recipe_states`

**Write Strategy**  
- Local toggle first
- Direct non-blocking write-through (`setRecipeSavedState`, `setRecipeCrispiedState`)
- Single transient retry inside service

**Read Strategy**  
- App behavior uses local sets
- Cloud fetch exists (`fetchMyUserRecipeStates`) but currently used for debug/testing, not as UI truth

**Sync Behavior**  
No state reconciliation loop; cloud mirrors local best-effort writes only

**Current Limitations**  
- Multi-device divergence likely
- `is_archived` not write-through integrated
- No cloud-first hydration for normal UX

### Shopping List

**Source of Truth**  
Local-first (with cloud write-through + outbox recording)

**Local Storage**  
- `UserDefaults` encoded `[ShoppingListEntry]` (`shoppingListEntries`)
- In-memory list in `ShoppingListViewModel`

**Remote Storage (Supabase)**  
- `shopping_list_items`

**Write Strategy**  
For create/update/delete:
1. local update
2. append outbox mutation
3. direct non-blocking Supabase write-through

**Read Strategy**  
- Main app behavior reads local list only
- Cloud reads available in debug/testing and diagnostics

**Sync Behavior**  
- Outbox dispatcher can replay pending mutations
- No cloud-to-local apply in normal flow

**Current Limitations**  
- Dual-write path (direct + outbox replay) can create ambiguity
- Failed outbox mutations are not auto-retried (dispatcher processes `pending` only)
- No cloud-first list rendering

### Fridge

**Source of Truth**  
Local-first (with cloud write-through + outbox recording)

**Local Storage**  
- `UserDefaults` encoded `FridgeSelectionPayload` (`fridgeIngredientSelection`)
- In-memory arrays in `FridgeViewModel`

**Remote Storage (Supabase)**  
- `fridge_items`

**Write Strategy**  
For create/delete flows:
1. local update
2. append outbox mutation
3. direct non-blocking Supabase write-through

(`updateFridgeItem` exists in service/dispatcher path but main fridge UX mostly emits create/delete semantics)

**Read Strategy**  
- Main app behavior reads local fridge only
- Cloud reads used in debug/testing and diagnostics

**Sync Behavior**  
- Pending outbox mutations can be replayed by dispatcher
- No cloud-to-local hydration in normal UX

**Current Limitations**  
- Same dual-write ambiguity as shopping list
- No automatic retry of failed outbox entries
- No cloud-first fridge UX

### Profiles

**Source of Truth**  
Hybrid (cloud-first display with local fallback)

**Local Storage**  
- `@AppStorage("accountUsername")`
- `@AppStorage("accountProfileImageURL")`
- `@AppStorage("linkedSocialAccountsRaw")` (legacy/local linked-account metadata)

**Remote Storage (Supabase)**  
- `profiles`
- `linked_social_accounts` (read + delete currently used)

**Write Strategy**  
- Profile social links: direct remote update (`profiles`)
- Linked social disconnect: remote delete by provider
- OAuth/local linked account metadata still maintained locally for bridge behavior

**Read Strategy**  
- Fetch cloud profile and cloud linked accounts in `AccountView`
- Fallback to local fields when cloud missing/unavailable

**Sync Behavior**  
Manual fetch on account screen lifecycle and debug actions; no formal profile sync engine

**Current Limitations**  
- Mixed local/cloud account-linking paths coexist
- Cloud linked account create/link write is not a complete dedicated pipeline in app-side architecture

### Avatars / Media

**Source of Truth**  
Avatars: remote-first URL in profile (with local cached URL fallback)  
Recipe media: mostly local

**Local Storage**  
- Avatar URL cached in `@AppStorage("accountProfileImageURL")`
- Recipe images/media references stored in local `Recipe` data

**Remote Storage (Supabase)**  
- Storage bucket: `avatars`
- `profiles.avatar_url`
- Recipe media pipeline to Supabase storage is not implemented

**Write Strategy**  
- Avatar upload: direct storage upload + profile update
- Recipe media: no Supabase upload pipeline

**Read Strategy**  
- Avatar displayed by URL when present
- Recipe media rendered from local assets/remote URLs already present in recipe payload

**Sync Behavior**  
No media sync system beyond avatar URL update

**Current Limitations**  
- No generalized media service for recipe photos/videos
- No signed/private media flow

### Ingredients

**Source of Truth**  
Hybrid foundational domain (catalog local; identity unification newly introduced but not adopted everywhere)

**Local Storage**  
- Produce catalog from bundled JSON
- Basic ingredient catalog from bundled JSON
- New `IngredientReference` model + mapping extensions

**Remote Storage (Supabase)**  
Indirect via domain tables (`recipes.ingredients`, `shopping_list_items`, `fridge_items`)

**Write Strategy**  
Domain-specific mapping per feature (shopping/fridge/recipe), no centralized ingredient write service

**Read Strategy**  
Domain-specific resolution in each view model

**Sync Behavior**  
No standalone ingredient sync domain

**Current Limitations**  
- `IngredientReference` exists but is not yet fully adopted as cross-domain canonical identity
- Ingredient mapping logic remains duplicated across view models/services

## System Patterns

#### Local-first pattern
Used in:
- recipe states (saved/crispy/archived)
- shopping list
- fridge
- recipe drafts

Why:
- immediate UX response
- offline-friendly baseline
- minimal blocking on network/auth state

#### Write-through pattern
Used in:
- recipe saved/crispy -> `user_recipe_states`
- shopping list -> `shopping_list_items`
- fridge -> `fridge_items`
- published recipes -> `recipes`

Risks:
- local and remote can diverge
- failures are logged but not always reconciled automatically
- direct write-through plus outbox replay can create duplicate/ordering ambiguity

#### Outbox system
Where used:
- shopping list mutations
- fridge mutations

Behavior:
- stores mutation payloads in `UserDefaults`
- dispatcher processes `pending` sequentially
- statuses: `pending -> in_progress -> completed/failed`
- auto-triggered on app launch + foreground

Current limitations:
- no automatic retry/backoff for `failed` records
- no dedupe/consolidation layer
- no guaranteed exactly-once semantics
- coexists with direct write-through (temporary dual-write)

## Known Gaps (CRITICAL)

- No follow backend system (follow state remains local/AppStorage)
- Recipe author/creator is not fully linked to profile identity in feed/detail data flow
- Recipe media pipeline is incomplete (avatars supported; recipe media storage pipeline missing)
- Ingredient domain unification is not fully adopted yet across all mutation/read paths
- Dual-write ambiguity exists (direct Supabase write + outbox replay for same mutation domain)
- No full multi-device reconciliation (cloud reads not consistently used to hydrate/resolve local state)

## Target Direction

- **Produce**: remain local-first static catalog (optional remote admin update path later)
- **Recipes**: move to clearer remote ownership model; keep local draft-first authoring with explicit publish sync
- **Recipe States (saved/crispy)**: evolve toward cloud-backed truth with local cache, plus deterministic reconciliation on launch
- **Shopping List**: keep local-first UX, but make outbox the single remote write path and add deterministic cloud hydration/reconciliation
- **Fridge**: same direction as shopping list (single write path + hydration + reconciliation)
- **Profiles**: backend-first for identity fields and linked accounts, with local cache as UI fallback only
- **Avatars / Media**: keep avatars remote-first; add explicit recipe media upload/storage model (ownership + URL lifecycle)
- **Ingredients**: adopt `IngredientReference` as canonical cross-domain identity surface to reduce mapping divergence
