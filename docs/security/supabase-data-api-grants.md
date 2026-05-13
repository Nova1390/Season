# Supabase Data API Grants

Status: implemented compatibility guardrail.

Supabase announced a default privilege change for tables created in the `public` schema:

- 2026-05-30: new projects stop exposing new `public` tables to the Data API by default.
- 2026-10-30: existing projects move to the same behavior.

Season uses the Data API through Supabase client libraries and Edge Functions, so migrations must grant table privileges explicitly.

## Implemented Baseline

Migration:

- `supabase/migrations/20260513192000_explicit_public_data_api_grants.sql`

Purpose:

- make current app/catalog/admin table grants explicit;
- ensure service-role backend workflows keep Data API access on fresh rebuilds;
- keep existing app read/write surfaces available to `authenticated`;
- keep existing public read surfaces available to `anon`;
- avoid relying on historical default grants.

## Safety Boundary

`GRANT` is not the authorization policy by itself.

Season still relies on:

- RLS enabled on public tables;
- owner/user policies for user-owned data;
- catalog-admin allowlist policies for governance/admin surfaces;
- service-role-only RPCs for sensitive backend operations.

Sensitive tables such as `recipe_import_usage`, `custom_ingredient_observations`, automation tokens, and audit ledgers are not granted to normal app users unless an existing admin-console read surface requires it. They are accessed through RPCs or service-role Edge Functions.

## Migration Standard

For every new `public` table:

1. Enable RLS unless the table is intentionally service-role-only and unreachable from clients.
2. Add explicit `GRANT` statements in the same migration.
3. Grant only the minimum app role access needed.
4. Always grant required backend access to `service_role`.
5. Add policies immediately after grants when the table is exposed to `anon` or `authenticated`.

Recommended pattern:

```sql
create table if not exists public.example_table (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.example_table enable row level security;

grant select, insert, update, delete
  on table public.example_table
  to authenticated;

grant all privileges
  on table public.example_table
  to service_role;

create policy example_table_owner_select
on public.example_table
for select
to authenticated
using (auth.uid() = user_id);
```

## Local Verification

After adding a table migration, run an audit against migration text:

```bash
/Users/roccodaffuso/.deno/bin/deno eval '<grant audit script>'
```

The audit should verify that each newly created `public` table has at least one explicit grant, and service-role access when backend functions need it.
