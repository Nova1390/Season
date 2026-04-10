alter table public.recipes
    add column if not exists source_url text,
    add column if not exists source_name text,
    add column if not exists source_type text;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'recipes_source_type_check'
    ) then
        alter table public.recipes
            add constraint recipes_source_type_check
            check (
                source_type is null
                or source_type in ('curated_import', 'user_generated', 'seed_web')
            );
    end if;
end
$$;
