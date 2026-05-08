# Supabase Security Findings Disposition

## Scope

This document records the current disposition of Supabase Security Advisor findings for Season after the first safe hardening pass.

The pass is intentionally narrow. It focuses on:

- fixing only low-risk issues
- avoiding runtime breakage
- preserving current app behavior
- deferring complex security changes that require a permissions-boundary design

This is not a blanket warning cleanup. Findings that remain are known, understood, and intentionally deferred where changing them could affect runtime behavior, admin tooling, catalog governance, or reconciliation.

## What Has Been Fixed

### `public.recipes`

`public.recipes` is considered resolved for the current pass.

Current intended model:

- RLS enabled
- public read access for `anon` and `authenticated`
- authenticated owner writes only
- anon write-level privileges revoked

Policy model:

| Operation | Role | Rule |
|---|---|---|
| SELECT | `anon`, `authenticated` | public read |
| INSERT | `authenticated` | `user_id = auth.uid()` |
| UPDATE | `authenticated` | `user_id = auth.uid()` |
| DELETE | `authenticated` | `user_id = auth.uid()` |

This preserves the app's public recipe feed while protecting recipe writes.

### `public.handle_new_user`

`public.handle_new_user` is considered resolved for the current pass.

The function remains `SECURITY DEFINER`, because it is expected to create the matching profile row during auth user creation.

The mutable `search_path` warning was addressed by fixing the function search path:

```sql
search_path = public, auth, pg_temp
```

## What Is Intentionally Not Fixed

### `security_definer_view` Warnings

The remaining `security_definer_view` warnings are accepted temporarily, not ignored.

These views are not being blindly converted to `security_invoker` because doing so could break:

- Smart Import
- unified catalog bootstrap
- import resolution
- reconciliation diagnostics and apply flows
- admin/debug tooling
- catalog governance and Autopilot workflows

In particular, `ingredient_catalog_summary` is runtime-critical and must not be changed blindly. It is part of the app's unified catalog bootstrap path and can affect Smart Import materialization and ingredient resolution.

Changing these views safely requires a future permissions-boundary pass, not a lint-only migration.

## View Classification

### Runtime-Facing Critical View

| View | Disposition | Reason |
|---|---|---|
| `ingredient_catalog_summary` | Do not change blindly | Runtime-facing catalog summary used by the app's unified ingredient bootstrap. Switching to `security_invoker` without redesigning underlying catalog read policies could break Smart Import, catalog materialization, and import resolution. |

### Admin / Internal Views

These views are admin, internal, reconciliation, or catalog-governance surfaces. They require a future permissions-boundary pass before changing view security behavior.

| View | Disposition |
|---|---|
| `catalog_resolution_candidate_queue` | Defer |
| `catalog_coverage_blocker_terms` | Defer |
| `custom_ingredient_observation_summary` | Defer |
| `catalog_ready_enrichment_draft_queue` | Defer |
| `catalog_resolution_candidate_policy` | Defer |
| `recipe_ingredient_reconciliation_safety_preview` | Defer |
| `recipe_reconciliation_impact_summary` | Defer |
| `recipe_reconciliation_blockers` | Defer |
| `recipe_reconciliation_unresolved_text_analysis` | Defer |
| `recipe_reconciliation_match_source_breakdown` | Defer |
| `recipe_reconciliation_next_action_summary` | Defer |

No automatic or batch migration should be applied to convert all views to security_invoker.
These views are often chained together and depend on protected base tables such as catalog observations, aliases, localizations, enrichment drafts, audit tables, and recipe reconciliation data. A safe fix must decide which access should be available to:

- runtime app users
- authenticated catalog admins
- service-role automation
- internal diagnostics

## Other Warnings

### Storage Bucket Listing

Buckets:

- `avatars`
- `recipes`

Disposition: accepted temporarily.

Reason:

- the app uses public URLs for avatar and recipe media display
- no app-side `.list()` usage was found
- changing object `SELECT` policies could affect public image rendering or upload flows
- any storage hardening needs careful validation against media display and upload behavior

This should be handled in a dedicated storage policy pass.

### Leaked Password Protection

Disposition: accepted temporarily.

Reason:

- this is a Supabase Auth dashboard/configuration setting
- it is not fixed through an app migration
- enabling it is low risk but should be handled operationally in the dashboard

### Extension In Public Schema: `pg_net`

Disposition: accepted temporarily.

Reason:

- not considered critical for the current hardening pass
- should be reviewed separately if extension placement becomes part of a broader database hygiene effort

## Why Warnings Still Appear

Security Advisor warnings are expected to remain after this pass.

Remaining warnings are:

- known
- understood
- intentionally deferred

They are not being ignored. They are being held for a future permissions-boundary design because changing them blindly could break current product behavior or internal operations.

## Future Work

### SECURITY-BOUNDARY-001

Goal:

Redesign access boundaries between:

- runtime app
- admin tools
- catalog governance views
- reconciliation views
- service-role automation

This work should answer:

- which views are safe for runtime app access
- which views should be admin-only
- which data should be exposed through dedicated RPCs instead of direct views
- whether `security_invoker` is appropriate per view
- which base tables need explicit read policies for runtime-safe catalog access

This is not a lint cleanup task. It is a design task.

## Final Position

This pass is considered complete.

- Critical runtime risks have been mitigated
- Low-risk issues have been fixed
- Remaining findings are intentionally deferred

The system is currently in a **safe and stable state for development and testing**.

No further security changes should be applied without entering SECURITY-BOUNDARY-001.
