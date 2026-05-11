# Season Admin Console

Internal web console for Season catalog governance.

This folder is intentionally separate from the iOS app and from the public website. It is the future home for admin/catalog workflows such as proposal review, deterministic validation, manual apply, and learning-memory inspection.

## Current Scope

The first version is a zero-build static web app:

- no package manager;
- no bundled secrets;
- no service-role key in the browser;
- Supabase Auth session required;
- admin access enforced by existing Supabase RPCs and catalog-admin policies.

It currently supports:

- email/password login through Supabase Auth;
- loading the catalog agent review inbox;
- filtering by proposal status and limit;
- queueing proposals for validation;
- requesting more evidence;
- rejecting proposals with a note;
- running deterministic validation;
- applying already validated low-risk proposals;
- loading relevant learning memory for the selected proposal term.

## Local Setup

Create a local config file from the example:

```bash
cp admin-console/config.example.js admin-console/config.local.js
```

Edit `admin-console/config.local.js` with the target environment public Supabase URL and anon key.

Use `Season-dev` first:

- project ref: `gyuedxycbnqljryenapx`;
- URL: `https://gyuedxycbnqljryenapx.supabase.co`.

Never put a service-role key in this folder.

## Local Run

From the repo root:

```bash
python3 -m http.server 4177
```

Then open:

```text
http://localhost:4177/admin-console/
```

## Deployment Direction

Recommended production-style host:

- `admin.seasonapp.it` for the general backoffice;
- or `catalog.seasonapp.it` if we want this to remain catalog-only for now.

The console should initially point only to `Season-dev`. Staging can be enabled later with explicit config and release-governance checks.

## Security Notes

- The browser may only use the Supabase anon key.
- All privileged access must go through admin-only RPCs.
- RLS and `assert_catalog_admin(...)` remain the real gate.
- Do not add direct table writes from the frontend.
- Do not store API keys, service-role keys, or Apple keys here.
