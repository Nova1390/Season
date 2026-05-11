# Catalog Agent Learning Memory

Status: backend-first implementation contract.

This document describes the structured continuous-improvement memory for the Catalog Governance Agent.

## Purpose

The agent should not merely fail, get rejected, or ask for help. It should learn operationally.

Learning memory turns important outcomes into reusable artifacts:

- human rejections;
- validation failures;
- manual apply failures;
- recurring ambiguity;
- catalog gaps;
- policy gaps;
- prompt improvements;
- validator improvements.

## Backend Objects

Implemented by:

- `supabase/migrations/20260511120000_catalog_agent_structured_learning.sql`

Table:

- `public.catalog_agent_learnings`

RPCs:

- `public.record_catalog_agent_learning(...)`
- `public.get_catalog_agent_learning_memory(...)`
- `public.review_catalog_agent_learning(...)`

## Learning Types

Supported types:

- `human_rejection`
- `validator_failure`
- `manual_apply_failure`
- `policy_gap`
- `ambiguity`
- `duplicate_identity_risk`
- `prompt_improvement`
- `catalog_gap`
- `other`

## Lifecycle

Supported statuses:

- `draft`
- `needs_review`
- `accepted`
- `rejected`
- `implemented`
- `superseded`

Default status is `needs_review`.

## Automatic Learning Sources

The migration also updates existing RPCs so learning artifacts are created automatically when:

- a reviewer rejects a proposal;
- a reviewer requests more evidence;
- deterministic validation fails;
- manual apply fails.

## Safety Boundary

Learning memory is advisory.

It does not:

- mutate ingredients;
- approve aliases;
- add localizations;
- reconcile recipes;
- change prompt behavior automatically.

Accepted learnings must still be translated into explicit prompt, validator, policy, or evaluation-set changes.
