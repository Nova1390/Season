# Catalog Agent External Evidence

Status: dev-only foundation on `agent/catalog-governance`.

## Purpose

External catalog evidence lets the Catalog Governance Agent use trusted public
food/catalog sources as grounding context without treating them as Season catalog
truth.

This is not model training and not catalog import. It is a governed evidence
layer.

The agent may use external evidence to improve:

- ingredient existence confidence;
- variant and product-form reasoning;
- synonym/localization hints;
- taxonomy/family classification;
- nutrition enrichment direction;
- blocking questions for ambiguous terms.

The agent must not use external evidence to bypass:

- current Season catalog candidates;
- learning memory;
- deterministic validators;
- apply workers;
- rollback/audit requirements.

## Data Contract

External evidence lives in:

```text
public.catalog_agent_external_evidence
```

Each row is tied to:

- `normalized_text`: the Season-observed term;
- `source_key`: the external source;
- `source_license`: the license label;
- `evidence_type`: what kind of evidence the row provides;
- `trust_level`: low, medium, or high;
- `confidence_score`: optional source/matcher confidence;
- `evidence_summary`: compact human-readable reasoning;
- `metadata` and `raw_payload`: structured details for audit.

Supported source keys:

- `usda_fdc`: FoodData Central, best for generic foods and nutrients.
- `wikidata`: CC0 multilingual/taxonomy labels and identity hints.
- `foodon`: ontology/taxonomy support.
- `open_food_facts`: branded/packaged product evidence; use cautiously because ODbL obligations matter.
- `manual_open_source_review`: operator-reviewed external evidence summary.
- `crea_alimenti_nutrizione`: Italian food-composition and nutrition grounding for common Italian culinary terms.
- `ieo_bda`: Italian food-composition reference grounding; use compact reviewed summaries until redistribution obligations are confirmed.
- `masaf_pat`: Italian traditional agri-food product grounding for regional/traditional identity boundaries.
- `regional_pat`: regional Italian traditional-product grounding for local product names and regional identity.

Supported evidence types:

- `ingredient_identity`
- `variant_identity`
- `synonym_or_label`
- `taxonomy`
- `nutrition`
- `branded_product`
- `packaged_product`
- `not_catalog_identity`
- `ambiguous_identity`

## Runtime Contract

`get_catalog_agent_external_evidence_context(...)` returns a compact packet:

- `metadata`
- `runtime_instruction`
- `term_external_evidence`

`run-catalog-agent-triage` attaches up to four rows per work item under:

```json
context.external_catalog_evidence
```

The prompt policy says:

- external evidence is grounding only;
- cite `source_key` and `evidence_type` when it changes confidence or proposal type;
- `needs_review` evidence is weak support;
- accepted/implemented evidence is stronger, but still not catalog truth.

## Ingestion

Reviewed evidence can be imported with:

```bash
python3 scripts/catalog_external_evidence/import_external_evidence.py \
  docs/catalog-agent-italian-evidence-reviewed.csv \
  --only-italian-sources \
  --dry-run \
  --json
```

The importer validates the file locally before writing. Live imports require
`SUPABASE_SERVICE_ROLE_KEY` and call only
`public.upsert_catalog_agent_external_evidence(...)`.

Operational runbook:

- `docs/catalog-agent-italian-external-evidence-ingestion.md`
- `docs/catalog-agent-italian-evidence-reviewed.csv`
- `docs/catalog-agent-italian-evidence-reviewed.example.csv`

## Source Policy

Initial preferred order:

1. USDA FoodData Central for nutrient/generic food evidence.
2. Wikidata for CC0 multilingual and taxonomy hints.
3. FoodOn for ontology/family evidence.
4. Open Food Facts only for packaged/branded product evidence after license-aware review.
5. CREA Alimenti e Nutrizione for Italian generic ingredients and nutrition composition.
6. IEO BDA for Italian composition checks, only as reviewed compact summaries until license/redistribution is confirmed.
7. MASAF PAT and regional PAT sources for traditional Italian products and local identity boundaries.

Open Food Facts can be very useful, but its ODbL license means we should not
blindly copy large chunks into Season without attribution/share-alike analysis.

Italian sources matter because the first public audience is Italian. They should
help the agent understand terms such as `stracchino`, `pecorino romano`,
`pane raffermo`, `fiocchi d avena`, or regional products without forcing those
terms through US-centric food datasets.

The ingestion rule stays conservative:

- store source IDs, URLs, licenses, compact summaries, and small structured hints;
- do not bulk-copy external database payloads into Season;
- do not treat a source row as proof that an alias or canonical ingredient is safe;
- prefer `needs_review` evidence until the source/license has been reviewed;
- promote evidence to `accepted` or `implemented` only through the catalog admin workflow.

## Safety

External evidence does not:

- create ingredients;
- approve aliases;
- add localizations;
- alter recipes;
- alter Smart Import output directly;
- auto-apply anything.

It only changes the evidence packet seen by the agent. All downstream mutations
still pass through proposal persistence, validation, worker gating, audit, and
rollback.
