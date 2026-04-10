-- Allow enrichment drafts to be marked as applied after canonical ingredient creation.
-- Minimal status extension for batch apply pipeline.

alter table public.catalog_ingredient_enrichment_drafts
  drop constraint if exists catalog_ingredient_enrichment_drafts_status_check;

alter table public.catalog_ingredient_enrichment_drafts
  add constraint catalog_ingredient_enrichment_drafts_status_check
  check (status in ('pending', 'ready', 'rejected', 'applied'));
