# Season Admin Console

Internal web console for Season catalog governance.

This folder is intentionally separate from the iOS app and from the public website. It is the future home for admin/catalog workflows such as proposal review, deterministic validation, manual apply, and learning-memory inspection.

Operator docs:

- `docs/catalog-admin-operator-runbook.md`
- `docs/catalog-governance-dev-closeout-checklist.md`

## Current Scope

The first version is a zero-build static web app:

- no package manager;
- no bundled secrets;
- no service-role key in the browser;
- Supabase Auth session required;
- admin access enforced by existing Supabase RPCs and catalog-admin policies.

It currently supports:

- email/password login through Supabase Auth;
- explicit catalog-admin authorization check before the workspace opens;
- loading the catalog agent review inbox;
- filtering by proposal status and limit;
- queueing proposals for validation;
- requesting more evidence;
- rejecting proposals with a note;
- running deterministic validation;
- applying already validated low-risk proposals;
- preparing enrichment drafts from `create_canonical` catalog-gap proposals;
- loading relevant learning memory for the selected proposal term;
- running approved agent worker jobs from the Operations section;
- explaining why low-risk dry-runs have zero eligible proposals;
- showing worker runs and low-risk readiness as visual summaries before raw JSON;
- inline help bubbles for dashboard fields, worker controls, pipeline steps, and run metrics;
- viewing recent agent-orchestrated Autopilot worker jobs;
- viewing today's catalog AI usage rollup.
- viewing auto-apply audit and rollback summary.
- rolling back active auto-apply audit records with a required operator reason.

The action buttons are state-aware. For example, a `needs_human_review` proposal is treated as a triage outcome, so validation/apply actions are disabled in the UI and still guarded by backend RPC policy.

For `create_canonical`, the console does not create an ingredient directly. It exposes `Prepare draft`, which calls `prepare_catalog_agent_canonical_enrichment_draft(...)` and creates or refreshes a pending enrichment draft. Autopilot must enrich that draft and backend validators must pass before any ingredient creation flow can run.

Operations worker controls are deliberately narrow:

- `low_risk_apply_batch` is exposed only as `dry_run=true`;
- `enrichment_draft_batch` is capped in the UI to 3 items per run;
- `ingredient_creation_batch` is available only for ready enrichment drafts and still requires the backend `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true` flag;
- real low-risk apply remains unavailable from the console;
- every run is still authorized by Supabase Auth and recorded in `catalog_agent_worker_jobs`.
- readiness diagnostics come from `get_catalog_agent_auto_apply_diagnostics()`, not browser-side policy guesses.

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

## Deployment

Current dev deployment:

- URL: `https://catalog.seasonapp.it/`
- Hosting path: `/home/u280052083/domains/seasonapp.it/public_html/catalog`
- Supabase environment: `Season-dev`
- Config file on host: `config.local.js`

If the URL returns `404`, first verify that the Hostinger subdomain still points to the custom folder and that the folder exists. The expected folder is:

```text
/home/u280052083/domains/seasonapp.it/public_html/catalog
```

Deploy only static files:

- `.htaccess`
- `index.html`
- `styles.css`
- `app.js`
- `config.local.js`

The deployed `config.local.js` may contain a browser-safe Supabase publishable/anon key. It must never contain a service-role key.

SSH deploy is configured with the dedicated local key:

```bash
scp -i ~/.ssh/codex-season-website-deploy -P 65002 \
  admin-console/index.html \
  admin-console/app.js \
  admin-console/styles.css \
  u280052083@82.198.227.60:/home/u280052083/domains/seasonapp.it/public_html/catalog/
```

Staging can be enabled later with explicit config and release-governance checks.

Before enabling staging, follow `docs/catalog-governance-dev-closeout-checklist.md` and create a staging-specific console configuration. Do not reuse dev assumptions silently.

## Security Notes

- The browser may only use the Supabase anon key.
- All privileged access must go through admin-only RPCs.
- RLS and `assert_catalog_admin(...)` remain the real gate.
- Agent worker jobs and AI usage are read-only in the console.
- Auto-apply audit rows are visible in the console. Rollback is available only for active `applied` audit rows and still runs through the guarded `rollback_catalog_agent_apply(...)` RPC.
- The console calls `is_current_user_catalog_admin()` immediately after login and signs out non-admin users before showing the workspace.
- Console RPCs are not executable by `anon`; they are granted only to `authenticated` and `service_role`.
- Do not add direct table writes from the frontend.
- Do not store API keys, service-role keys, or Apple keys here.
