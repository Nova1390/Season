# Catalog Agent Review Inbox

Status: backend-first implementation contract.

This document describes the first review surface for the autonomous Catalog Governance Agent. It is intentionally not an auto-apply system.

## Purpose

The Review Inbox lets a catalog admin inspect, filter, and triage agent proposals before any deterministic validator or governed apply RPC is introduced.

It answers:

- What did the agent propose?
- Why did it propose it?
- What evidence and observations were used?
- Is there an existing target or proposed slug conflict?
- What human decision is needed next?

It does not answer:

- Apply this alias now.
- Create this canonical ingredient now.
- Reconcile recipes now.
- Schedule autonomous catalog mutation.

## Backend RPCs

Implemented by:

- `supabase/migrations/20260511100000_catalog_agent_review_inbox.sql`

### `public.get_catalog_agent_review_inbox(...)`

Admin-only read RPC.

Inputs:

- `p_statuses text[]`: defaults to reviewable statuses.
- `p_proposal_type text`: optional proposal type filter.
- `p_risk_levels text[]`: optional risk filter.
- `p_source_domain text`: optional run source-domain filter.
- `p_limit integer`: defaults to `50`, capped at `100`.
- `p_offset integer`: pagination offset.

Returns:

- metadata, filters, total counts, status counts, risk counts;
- proposal summary;
- run summary;
- target ingredient display metadata when present;
- proposed fields and proposed slug conflict;
- linked unresolved observations;
- latest proposal events.

### `public.review_catalog_agent_proposal(...)`

Admin-only lifecycle RPC.

Allowed actions:

- `reject`: marks proposal `rejected`; reviewer note is required.
- `defer`: records a deferral event and keeps current status.
- `request_more_evidence`: marks `needs_human_review` and records an event.
- `queue_for_validation`: marks `queued_for_validation`.
- `mark_needs_human_review`: marks `needs_human_review`.

Mutation scope:

- updates `catalog_agent_proposals.status`;
- optionally updates `rejection_reason`;
- inserts `catalog_agent_proposal_events`;
- does not touch `ingredients`, aliases, localizations, recipes, observations, or reconciliation state.

## Review Policy

Admins should reject proposals when:

- the target ingredient is semantically wrong;
- a proposed canonical slug represents an over-specific duplicate;
- the rationale contradicts catalog architecture policy;
- multilingual ambiguity is unresolved;
- the proposal would risk nutrition, allergy, seasonality, or cultural correctness.

Admins should request more evidence when:

- the proposal might be right but lacks context;
- possible canonical targets are missing;
- observation examples are insufficient;
- language or source-domain assumptions are unclear.

Admins should queue for validation only when:

- the proposal is structurally complete;
- identity reasoning looks sound;
- any ambiguity is acceptable for deterministic validator checks.

## Next Stage

Queued proposals are handled by the deterministic validator:

- `docs/catalog-agent-deterministic-validator.md`
- `public.validate_catalog_agent_proposal(...)`
- `public.validate_catalog_agent_proposal_batch(...)`

The validator can mark proposals `validated` or `failed_validation`, but it still cannot apply catalog changes.

## Learning Behavior

Human rejections and more-evidence requests create structured learning artifacts through:

- `docs/catalog-agent-learning-memory.md`
- `public.record_catalog_agent_learning(...)`

The agent should treat these as feedback signals, not just audit logs.

## Operational Hygiene

The agent runs `public.cleanup_catalog_agent_review_inbox(...)` at startup.
The cleanup preserves audit history but supersedes rows that should no longer
occupy the operator inbox:

- older duplicate open proposals for the same normalized term;
- proposals already resolved by an active approved alias;
- proposals already represented by an active canonical ingredient;
- validated `ignore_noise` proposals that do not require follow-up mutation.

This is intentionally status-only cleanup. It never creates ingredients, approves
aliases, changes recipes, or applies catalog mutations. Its purpose is to keep
the dashboard focused on current operational work rather than historical
learning debris.

## Current Autonomy Level

Level 1.5: propose plus human triage.

The agent still cannot apply changes. The reviewer still cannot apply changes through this inbox. Apply paths will require a separate validator and existing governed RPCs.
