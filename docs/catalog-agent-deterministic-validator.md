# Catalog Agent Deterministic Validator

Status: backend-first implementation contract.

This document describes the first deterministic validation layer for Catalog Governance Agent proposals.

The validator is not an apply worker. It is the safety gate between human triage and any future governed apply path.

## Purpose

The validator turns a reviewed proposal into one of two states:

- `validated`: structurally safe enough for a future apply adapter to consider.
- `failed_validation`: blocked by deterministic policy or data conflicts.

It does not:

- approve aliases;
- create canonical ingredients;
- add localizations;
- reconcile recipe ingredients;
- update custom observations;
- schedule autonomous work.

## Backend RPCs

Implemented by:

- `supabase/migrations/20260511103000_catalog_agent_deterministic_validator.sql`

### `public.validate_catalog_agent_proposal(...)`

Admin-only single-proposal validator.

Input:

- `p_proposal_id bigint`

Required precondition:

- proposal status should be `queued_for_validation`.

Output:

- `ok`
- `proposal_id`
- `run_id`
- resulting `status`
- structured `validation_errors`

Mutation scope:

- updates `catalog_agent_proposals.status`;
- updates `catalog_agent_proposals.validation_errors`;
- disables `auto_apply_eligible` when validation fails or risk is not `low`;
- inserts one `catalog_agent_proposal_events` row.

### `public.validate_catalog_agent_proposal_batch(...)`

Admin-only batch wrapper for queued proposals.

Input:

- `p_limit integer`, default `25`, capped at `100`.

It validates oldest `queued_for_validation` proposals first.

## Validator V1 Rules

General rules:

- proposal must be queued for validation;
- `normalized_text` must be present;
- `proposal_type` must be supported by validator v1;
- `risk_level` must be supported;
- `confidence_score` must be within `0..1`;
- `auto_apply_eligible=true` requires `risk_level=low`;
- rationale is required.

Target rules:

- `approve_alias` and `add_localization` require a valid target;
- target id and target slug must match when both are present;
- target ingredient must exist and be active.

Alias rules:

- `approve_alias` requires alias text or normalized text;
- active alias conflicts against another target fail validation;
- alias text matching another ingredient localization fails validation.

Localization rules:

- `add_localization` requires localized name and language code;
- a different existing localization on the target language blocks validation;
- localized text already belonging to another ingredient blocks validation.

Canonical proposal rules:

- `create_canonical` requires proposed slug, localized name, and language code;
- existing ingredient slug blocks validation;
- existing localized display name blocks validation.

Non-actionable proposal rules:

- `needs_human_review` is a useful triage result but cannot be validated for apply.

## Current Autonomy Level

Level 2: deterministic validation.

The system can now say "this proposal passes/fails deterministic checks", but still cannot apply catalog changes.
