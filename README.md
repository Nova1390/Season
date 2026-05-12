# Season

Season is an iOS app for ingredient-aware cooking.

It helps people decide what to cook by combining seasonal produce, fridge availability, recipe intelligence, shopping workflows, and a governed ingredient catalog powered by Supabase.

The product direction is simple: recipes and ingredients should become coherent, searchable, seasonal, nutritionally useful, and no longer fragmented across custom text fields.

## Product Highlights

- Seasonal discovery: ranked ingredients and recipes based on what is at peak right now.
- Fridge-aware cooking: add what you have and browse recipes you can make or almost make.
- Smart shopping: add missing recipe ingredients directly to the shopping list.
- Recipe intelligence: saved recipes, crispy votes, views, servings scaling, nutrition summaries, media, creators, and source attribution.
- Smart import: create recipes manually or parse recipe content from social captions and URLs.
- Creator layer: profiles, avatars, follows, social links, creator stats, and recipe libraries.
- Catalog autopilot: reduce custom recipe ingredients by routing unresolved text through matching, enrichment, governance, and reconciliation.
- Local-first UX: key flows stay responsive while Supabase sync runs in the background.

## App Structure

The main iOS tabs are:

- `Home`: editorial feed, featured recipe, seasonal picks, creator strips, and personalized recommendations.
- `Discover`: recipe and ingredient search with filters, trending sections, and quick-add actions.
- `Create`: recipe composer and smart import flow.
- `Today`: ranked in-season ingredients and seasonal insights.
- `Me`: account, profile, preferences, recipe library, diagnostics, and admin tools.

## Technical Overview

Season is built with:

- SwiftUI for the iOS client.
- Supabase for auth, Postgres data, edge functions, and avatar storage.
- Local persistence through `UserDefaults`, `AppStorage`, bundled JSON, and in-memory caches.
- A local-first plus write-through model for high-frequency UX domains.
- Supabase Edge Functions for recipe parsing, URL import, catalog enrichment, and catalog automation.

Important client entry points:

- `Season/SeasonApp.swift`: app entry point.
- `Season/Views/AuthGateView.swift`: Supabase session gate and username onboarding.
- `Season/ContentView.swift`: tab shell, shared view models, outbox dispatch.
- `Season/ViewModels/ProduceViewModel.swift`: core recipe, produce, ranking, nutrition, and catalog orchestration.
- `Season/Services/SupabaseService.swift`: Supabase client boundary.
- `Season/Services/RecipeRepository.swift`: remote recipe access layer.

## Data Strategy

Season is moving toward a single canonical catalog model:

- `ingredients`: canonical food identity.
- `ingredient_localizations`: display names by language.
- `ingredient_aliases_v2`: governed text-to-ingredient matching.
- `legacy_ingredient_mapping`: compatibility bridge only.

The goal is for published recipes to reference canonical `ingredient_id` values instead of remaining as custom ingredient text. This makes fridge matching, nutrition, filters, seasonality, reconciliation, and recommendations consistent.

Current app behavior remains hybrid:

- Recipes: Supabase is the target source of truth for published recipes.
- Fridge and shopping list: local-first with Supabase write-through and outbox replay.
- Recipe states: local-first for UX, with saved/crispy write-through.
- Catalog operations: backend-governed through RPCs, edge functions, audit tables, and admin workflows.

## Supabase Automation

The catalog pipeline is designed to continuously improve recipe ingredient quality:

1. Imported recipes produce normalized ingredient text.
2. Known aliases/localizations map text to canonical ingredients.
3. Unresolved text becomes candidate observations.
4. Enrichment drafts propose aliases, localizations, or new ingredients.
5. Safe decisions are reviewed, audited, and applied.
6. Recipe reconciliation reduces custom/unmapped ingredients over time.

The autopilot is intentionally conservative: it should not collapse meaningful culinary variants, and LLM output is treated as proposal material, not unchecked truth.

## Repository Map

```text
Season/
  Components/          Shared SwiftUI components
  Data/                Bundled local data used by the app
  Docs/                In-app architecture notes
  Localization/        App localization helpers
  Models/              Core domain models
  Services/            Supabase, repositories, sync, catalog, auth, nutrition
  Support/             Fonts, admin access, logging
  ViewModels/          Feature view models
  Views/               SwiftUI screens and design system

admin-console/
  *.html/js/css        Separate internal web console for catalog agent review
  config.example.js    Browser-safe local config template

supabase/
  functions/           Supabase Edge Functions
  migrations/          Database schema, policies, RPCs, and catalog automation

docs/
  design/              UI refresh prototypes and references
  security/            Security review disposition
  *.md                 Catalog, smart import, reconciliation, and product docs
```

## Documentation

Start here:

- [Functional overview](docs/season-functional-overview.md): product behavior, features, users, flows, and TestFlight data expectations.
- [Technical overview](docs/season-technical-overview.md): architecture, sync model, Supabase, catalog automation, build, and operational notes.
- [Architecture status](ARCHITECTURE.md): current local-first/cloud sync architecture.
- [Current status](CURRENT_STATUS.md): what is working today and known hardening areas.
- [Catalog architecture](docs/catalog-architecture.md): canonical ingredient identity contract.
- [Smart Import + Catalog Intelligence](docs/smart-import-catalog-intelligence-pipeline.md): source of truth for import, enrichment, autopilot, and reconciliation.
- [Catalog AI Agent Operating Plan](docs/catalog-ai-agent-operating-plan.md): proposal-first plan for adding an AI agent without bypassing Supabase/autopilot guardrails.
- [Catalog Agent Responsibility Charter](docs/catalog-agent-responsibility-charter.md): operating charter for the autonomous catalog governance agent as a careful Season operator.
- [Catalog AI Agent Contracts](docs/catalog-ai-agent-contracts.md): concrete Phase 0/1 contracts for proposal schema, statuses, risk, and documentation discipline.
- [Catalog Admin Console Plan](docs/catalog-admin-console-plan.md): web-first internal console direction for catalog agent review, validation, apply, and learning memory.
- [Catalog Admin Operator Runbook](docs/catalog-admin-operator-runbook.md): practical guide for using the dev console safely.
- [Catalog Governance Dev Closeout Checklist](docs/catalog-governance-dev-closeout-checklist.md): final dev checks before promoting or reviewing the current catalog-governance branch.
- [Data architecture](Season/Docs/DataArchitecture.md): per-domain source-of-truth and sync model.
- [Security disposition](docs/security/supabase-security-findings-disposition.md): security findings and decisions.
- [Catalog consolidation plan](docs/catalog-system-review-and-consolidation-plan.md): review snapshot and refactor roadmap for catalog operations.

## Build

Open `Season.xcodeproj` in Xcode and use the `Season` scheme.

Useful validation commands:

```bash
xcodebuild -scheme Season -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme Season -configuration Release -sdk iphoneos build CODE_SIGNING_ALLOWED=NO
plutil -lint Season-Info.plist
plutil -lint Season/PrivacyInfo.xcprivacy
git diff --check
```

Notes:

- Debug is configured for the development Supabase environment.
- Release is configured for the staging Supabase environment.
- `CODE_SIGNING_ALLOWED=NO` validates compilation and packaging, not App Store signing.
- TestFlight distribution uses a signed Archive/export/upload flow; the current staging candidate is `1.0.1 (4)`.

## Release Hygiene

The Release bundle is expected to exclude:

- local seed recipe payloads;
- smart-import debug reports;
- internal docs;
- local batch input files;
- Xcode user state.

For TestFlight, staging should contain the selected recipe catalog. Local TheMealDB/seed recipes should not be used as the app's recipe source of truth.

Staging preflight SQL lives in `supabase/devops/staging_testflight_preflight.sql`. If catalog autopilot should run on staging, use the dedicated `staging_catalog_autopilot_v2_*` scripts rather than the dev scheduler.

## Development Principles

- Keep Supabase as the source of truth for published recipe/catalog content.
- Preserve local-first UX where it improves responsiveness.
- Move recipe ingredients toward canonical `ingredient_id`.
- Treat aliases and localizations as governed data, not ad hoc strings.
- Keep catalog automation auditable and conservative.
- Avoid introducing parallel ingredient identity systems.
- Keep docs aligned with code whenever architecture changes.

## Current Status

The app is in a TestFlight rollout preparation phase:

- iOS Release builds successfully against staging.
- TestFlight candidate `1.0.1 (4)` is the current bugfix candidate from Release configuration.
- Auth, profile, recipe feed, fridge, shopping list, creator, and smart import flows are integrated.
- Fridge and shopping list use local-first state with outbox-backed Supabase sync.
- Catalog hierarchy, enrichment, and reconciliation workflows are active.
- Remaining hardening areas are documented in the functional and technical overviews.
