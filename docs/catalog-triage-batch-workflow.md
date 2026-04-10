# Catalog Triage Batch Workflow (Admin/Backoffice)

This workflow automates **initial triage only** for unresolved imported ingredient candidates:
- approve safe aliases
- mark clear noise as ignore
- prepare enrichment drafts for create-new-ingredient candidates

It does **not** auto-create ingredients, auto-mark drafts ready, or auto-approve anything beyond the explicit safe alias list.

## Script

Path:
- `scripts/catalog_triage_batch.py`

## Inputs (hardcoded for this approved batch)

The script includes 3 explicit sets:
1. Safe aliases
2. Create-new-ingredient draft seeds
3. Ignore/noise seeds

## USDA integration (new-ingredient draft group)

For each `create_new_ingredient` seed, the script:
1. calls USDA FoodData Central search API
2. selects the best candidate with a simple deterministic score
3. stores nutrition metadata in `p_nutrition_fields` (per 100g + source reference)
4. keeps `needs_manual_review = true`

If USDA match confidence is low or lookup fails:
- draft is still created
- nutrition payload includes lookup status/error
- manual review remains required

## Environment

Required:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional:
- `USDA_API_KEY` (defaults to `DEMO_KEY`)

## Run

Safe default (dry run; no DB mutations):
```bash
python3 scripts/catalog_triage_batch.py
```

Explicit dry run (same behavior):
```bash
python3 scripts/catalog_triage_batch.py --dry-run
```

Live apply (required for mutations):
```bash
python3 scripts/catalog_triage_batch.py --apply
```

`--apply` is mandatory for any write action.
Without `--apply`, the script is preview-only.

## Execution report (JSON)

On every run the script writes a structured report file to:

- `docs/reports/catalog_triage_report_<timestamp>.json`

Report includes:

- `timestamp`
- `dry_run`
- `aliases_attempted`
- `aliases_applied`
- `ignores_attempted`
- `ignores_applied`
- `drafts_attempted`
- `drafts_created`
- `drafts_updated`
- `skipped_items`
- `failed_items`
- `USDA_high_confidence`
- `USDA_low_confidence`
- `items[]` per processed term with:
  - `raw_term`
  - `normalized_text` (if found)
  - `intended_action`
  - `result_status` (`would_*`, `applied`, `created`, `already_done`, `failed`, etc.)
  - canonical target metadata (when relevant)
  - USDA match summary (for new-ingredient drafts)
  - `error_message` (if failed)

## What the script writes

### Alias group
- RPC: `approve_reconciliation_alias(...)`
- effect: approved active alias + candidate decision trail

### Ignore group
- RPC: `apply_catalog_candidate_decision(..., p_action='ignore')`
- effect: candidate moved to ignored status with audit trail

### New ingredient group
- RPC: `apply_catalog_candidate_decision(..., p_action='create_new_ingredient')`
- RPC: `upsert_catalog_ingredient_enrichment_draft(...)`
- effect: pending enrichment draft seeded with canonical proposal + USDA metadata (if available)

## Review checklist before trusting apply runs

1. Run preview first (`python3 scripts/catalog_triage_batch.py`).
2. Open the generated report JSON under `docs/reports/`.
3. Check:
   - `failed_items == 0`
   - `conflict` / `ingredient_not_found` / `candidate_not_found` entries
   - USDA low-confidence entries in `items[]` for manual review priority
4. Only then run `--apply`.

## Manual review still required

After script execution, admins still need to:
1. review each enrichment draft
2. validate fields (especially produce seasonality)
3. mark draft ready
4. trigger canonical ingredient creation from draft

No reconciliation apply is triggered by this script.
