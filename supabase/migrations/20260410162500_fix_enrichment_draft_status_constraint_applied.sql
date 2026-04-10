-- Corrective migration: ensure enrichment draft status accepts 'applied' in live DB.
-- This is intentionally surgical and only recreates the status check constraint.

alter table public.catalog_ingredient_enrichment_drafts
  drop constraint if exists catalog_ingredient_enrichment_drafts_status_check;

alter table public.catalog_ingredient_enrichment_drafts
  add constraint catalog_ingredient_enrichment_drafts_status_check
  check (status in ('pending', 'ready', 'rejected', 'applied'));
