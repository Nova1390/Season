-- Phase 1 hierarchy schema introduction (non-breaking, additive only).
-- This migration prepares ingredients for parent-child hierarchy support
-- without changing existing behavior, pipelines, or matching logic.

alter table public.ingredients
  add column if not exists parent_ingredient_id uuid null references public.ingredients(id) on delete set null;

alter table public.ingredients
  add column if not exists specificity_rank smallint not null default 0;

alter table public.ingredients
  add column if not exists variant_kind text not null default 'base';

-- Safe backfill for existing rows to guarantee backward-compatible baseline state.
update public.ingredients
set
  parent_ingredient_id = null,
  specificity_rank = 0,
  variant_kind = 'base'
where
  parent_ingredient_id is not null
  or specificity_rank <> 0
  or variant_kind <> 'base';

create index if not exists idx_ingredients_parent_id
  on public.ingredients(parent_ingredient_id);

-- verify new columns exist
-- select column_name
-- from information_schema.columns
-- where table_name = 'ingredients'
--   and column_name in ('parent_ingredient_id', 'specificity_rank', 'variant_kind');

-- verify default values applied
-- select count(*)
-- from public.ingredients
-- where parent_ingredient_id is not null;

-- should be 0

-- select distinct specificity_rank, variant_kind
-- from public.ingredients;
