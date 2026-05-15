# Italian External Evidence Ingestion

Status: dev-only operator workflow for `agent/catalog-governance`.

## Purpose

Italian food sources can help the Catalog Governance Agent reason about local
ingredients, regional products, product forms, and nutrition without turning
external databases into Season catalog truth.

The ingestion workflow writes only to:

```text
public.catalog_agent_external_evidence
```

It does not create ingredients, approve aliases, add localizations, change
recipes, or apply catalog mutations.

## Supported Italian Source Slots

- `crea_alimenti_nutrizione`: Italian generic ingredient and nutrition evidence.
- `ieo_bda`: Italian composition evidence; store compact reviewed summaries until redistribution obligations are confirmed.
- `masaf_pat`: traditional Italian agri-food product evidence.
- `regional_pat`: regional traditional product evidence tied to a specific official regional source URL.

These source keys are grounding context only. The agent must still pass through
matcher grounding, deterministic validation, proposal persistence gates, apply
workers, audit, and rollback.

## Input Format

Use CSV or JSON. Required fields:

- `normalized_text`
- `source_key`
- `source_license`
- `evidence_type`
- `evidence_summary`

Recommended fields:

- `source_record_id`
- `source_url`
- `source_license_url`
- `trust_level`
- `confidence_score`
- `language_code`
- `canonical_label`
- `aliases`
- `metadata`
- `raw_payload`
- `status`

Allowed `status` values:

- `needs_review`
- `accepted`
- `implemented`
- `rejected`
- `superseded`

Default status is `needs_review`. That is intentionally weak support: it can
help the agent ask better questions or increase confidence slightly, but it does
not authorize catalog changes.

## CSV Example

```csv
normalized_text,source_key,source_record_id,source_url,source_license,source_license_url,evidence_type,trust_level,confidence_score,language_code,canonical_label,aliases,evidence_summary,metadata,status
stracchino,crea_alimenti_nutrizione,review-2026-05-15-stracchino,,Operator reviewed summary,,ingredient_identity,medium,0.85,it,Stracchino,"[""crescenza""]","Italian soft cheese identity evidence; useful to avoid generic cheese collapse.","{""review_scope"":""manual pilot""}",needs_review
```

For CSV, JSON fields such as `aliases`, `metadata`, and `raw_payload` must be
valid JSON. `aliases` may also be a pipe-separated string for convenience.

## Dry Run

Preview a file without writing anything:

```bash
python3 scripts/catalog_external_evidence/import_external_evidence.py \
  docs/catalog-agent-italian-evidence-reviewed.csv \
  --only-italian-sources \
  --dry-run \
  --json
```

## Dev Import

Import reviewed rows into `Season-dev`:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/catalog_external_evidence/import_external_evidence.py \
  docs/catalog-agent-italian-evidence-reviewed.csv \
  --only-italian-sources \
  --limit 50
```

This uses the governed RPC:

```text
public.upsert_catalog_agent_external_evidence(...)
```

The importer validates source keys, evidence types, trust levels, statuses,
confidence bounds, JSON fields, and required source license labels before any
network write.

## Review Rules

- Store compact summaries, IDs, URLs, license labels, and small structured hints.
- Do not bulk-copy source database payloads.
- Keep uncertain or license-unreviewed rows as `needs_review`.
- Promote evidence to `accepted` only after operator review.
- Use `implemented` only when the evidence has already been reflected in a governed Season behavior, validator, fixture, or learning rule.
- Never treat an external row as proof that an alias/canonical creation is safe.

## Good First Batch

The first reviewed Italian batch lives in:

```text
docs/catalog-agent-italian-evidence-reviewed.csv
```

It starts with a tiny reviewed set before any wider ingestion:

- `stracchino`
- `pecorino romano`
- `fiocchi d avena`
- `pomodorini`
- `olive`

The goal is to improve agent reasoning and blocking questions, not to fill the
database quickly. Piccoli passi, niente alluvioni di dati.

The first batch deliberately stores every row as `needs_review`. It is still
useful: the agent can use it to rank confidence and ask better questions, but
it cannot treat the evidence as implemented policy.
