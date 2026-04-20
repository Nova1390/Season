-- Remove legacy duplicate RLS policies now that the canonical recipes_* policies
-- define public reads and owner-only writes for public.recipes.

drop policy if exists "Authenticated users can read recipes" on public.recipes;
drop policy if exists "Users can delete their own recipes" on public.recipes;
drop policy if exists "Users can insert their own recipes" on public.recipes;
drop policy if exists "Users can update their own recipes" on public.recipes;
