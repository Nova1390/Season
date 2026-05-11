# Catalog Agent Manual Apply Adapter

Status: backend-first implementation contract.

This document describes the first path from a validated Catalog Governance Agent proposal to a real catalog mutation.

It is manual, admin-only, and restricted to low-risk proposal types.

## Purpose

The adapter applies only proposals that already passed:

- agent proposal generation;
- human review lifecycle;
- deterministic validation.

It exists so the agent can help with catalog work without becoming a direct database writer.

## Backend RPCs

Implemented by:

- `supabase/migrations/20260511113000_catalog_agent_manual_apply_adapter.sql`

### `public.apply_catalog_agent_proposal(...)`

Admin-only single proposal apply.

Requirements:

- proposal status is `validated`;
- proposal risk is `low`;
- proposal type is `approve_alias` or `add_localization`.

Mutation path:

- `approve_alias` calls `public.apply_catalog_candidate_decision(..., 'approve_alias', ...)`;
- `add_localization` calls `public.add_ingredient_localization(...)`.

The adapter then marks the proposal `applied`, stores `applied_at` / `applied_by`, and writes a `manual_apply_succeeded` event.

### `public.apply_catalog_agent_proposal_batch(...)`

Admin-only batch wrapper.

It processes oldest validated low-risk alias/localization proposals first and returns per-item results.

## Explicit Non-Goals

The adapter does not:

- apply `create_canonical`;
- apply `needs_human_review`;
- apply medium/high/critical/unknown risk proposals;
- bypass deterministic validation;
- write directly to `ingredients`, aliases, or localizations;
- reconcile recipe ingredients.

## Learning Behavior

Manual apply failures create structured learning artifacts through:

- `docs/catalog-agent-learning-memory.md`
- `public.record_catalog_agent_learning(...)`

This is important because a proposal can pass validation and still fail inside a governed apply RPC. That failure should tighten future validator or apply preconditions.

## Current Autonomy Level

Level 2.5: manual governed apply.

The agent can now move from proposal to real catalog action only when an admin intentionally applies a validated, low-risk proposal through governed backend RPCs.
