# Catalog AI Agent Contracts

Status: implementation contract for Phase 0 and Phase 1 foundation.

This document turns `docs/catalog-ai-agent-operating-plan.md` into concrete contracts for the first implementation steps. Every future agent feature must update this file or a linked runbook in the same change.

## 1. Scope

Current scope:

- Define agent decision vocabulary.
- Define proposal JSON shape.
- Define proposal-only database persistence.
- Define safety rules for validation and future apply stages.

Out of scope for this phase:

- Calling an LLM.
- Scheduling an agent worker.
- Auto-applying proposals.
- Creating canonical ingredients autonomously.
- Mutating recipe ingredients.
- Adding iOS admin UI.

## 2. Non-Negotiable Rules

- Supabase remains the source of truth for catalog state.
- The agent never writes directly to `public.ingredients`, `public.ingredient_aliases_v2`, `public.ingredient_localizations`, or recipe JSON.
- Agent output is advisory until a backend validator and governed RPC accept it.
- Existing catalog architecture rules remain authoritative, especially alias-vs-canonical and hierarchy policy.
- Every agent run and proposal must be audit-readable by catalog admins.
- Every proposal must be attributable to a run, agent version, model, prompt version, and input snapshot hash when available.
- Service-role credentials must never be present in app code, repo files, or client-triggered payloads.

## 3. Decision Vocabulary

The first contract supports these proposal types:

- `approve_alias`: map observed text to an existing canonical ingredient.
- `create_canonical`: propose a new canonical ingredient identity.
- `add_localization`: propose a missing localized display name for an existing ingredient.
- `merge_duplicate`: propose that two canonical entries represent the same identity.
- `redirect_duplicate`: propose a canonical redirect from duplicate to target.
- `reconcile_recipe_ingredients`: propose recipe reconciliation through existing safe preview/apply RPCs.
- `ignore_noise`: mark an observation as not catalog-worthy.
- `needs_human_review`: explicitly route ambiguity to a reviewer.

Implementation note:

Phase 1 should store all proposal types but apply none. Phase 2 can review them. Phase 3 can auto-apply only low-risk alias/localization proposals after a validator exists.

## 4. Risk Levels

Supported risk levels:

- `low`
- `medium`
- `high`
- `critical`
- `unknown`

Auto-apply eligibility is never allowed for:

- `high`
- `critical`
- `unknown`

Default risk should be `unknown` when the agent does not explicitly justify risk.

## 5. Proposal Statuses

Supported proposal statuses:

- `draft`: inserted but not yet validated.
- `queued_for_validation`: ready for validator processing.
- `validated`: validator accepted the proposal as structurally safe.
- `auto_applied`: future state for low-risk proposals applied by governed RPCs.
- `needs_human_review`: requires operator decision.
- `rejected`: reviewer or validator rejected the proposal.
- `failed_validation`: backend validator found a conflict or policy violation.
- `superseded`: replaced by a newer or better proposal.

Phase 1 default:

- Insert proposals as `draft` or `needs_human_review`.
- Do not use `validated` or `auto_applied` until validator/apply stages exist.

## 6. Run Contract

An agent run represents one bounded analysis execution.

Required run fields:

- `agent_version`
- `status`

Recommended run fields:

- `environment`
- `agent_name`
- `model`
- `prompt_version`
- `mode`
- `source_domain`
- `input_snapshot_hash`
- `input_summary`
- `summary`
- `error_message`

Run statuses:

- `started`
- `completed`
- `failed`
- `cancelled`

Allowed run modes:

- `proposal_only`
- `validation`
- `auto_apply`
- `manual_replay`

Phase 1 mode:

- `proposal_only`

## 7. Proposal Contract

Each proposal must include enough structure for backend validation without relying on prose interpretation.

Required proposal fields:

- `run_id`
- `proposal_type`
- `normalized_text`
- `risk_level`
- `status`

Required by proposal type:

- `approve_alias`
  - `target_ingredient_id` or `target_slug`
  - `proposed_alias_text` or `normalized_text`
  - rationale

- `create_canonical`
  - `proposed_slug`
  - `proposed_localized_name`
  - `proposed_language_code`
  - rationale explaining why alias/localization is insufficient

- `add_localization`
  - `target_ingredient_id` or `target_slug`
  - `proposed_localized_name`
  - `proposed_language_code`

- `merge_duplicate` / `redirect_duplicate`
  - target identity
  - duplicate identity
  - rationale explaining why identity is duplicate, not variant

- `reconcile_recipe_ingredients`
  - target identity
  - recipe impact metadata in `evidence`
  - must remain non-applicable until reconciliation safety preview confirms rows

- `ignore_noise`
  - rationale

- `needs_human_review`
  - rationale
  - blocking questions in `blocking_questions`

## 8. JSON Output Shape

The future agent function should return strict JSON matching this high-level shape:

```json
{
  "run_summary": {
    "items_reviewed": 0,
    "auto_apply_candidates": 0,
    "human_review_required": 0,
    "blocked": 0
  },
  "proposals": [
    {
      "proposal_type": "approve_alias",
      "normalized_text": "example",
      "target_slug": "example_slug",
      "confidence_score": 0.95,
      "risk_level": "low",
      "auto_apply_eligible": false,
      "rationale": "Short policy-based explanation.",
      "evidence": []
    }
  ]
}
```

Phase 1 persistence must store:

- the structured proposal fields,
- `rationale`,
- `evidence`,
- `blocking_questions`,
- optional raw model metadata only when it contains no secrets or unrelated user data.

## 9. Validation Rules

The future validator must reject proposals when:

- `proposal_type` is unsupported.
- `normalized_text` is blank.
- `confidence_score` is outside `0..1`.
- `risk_level` is unsupported.
- `auto_apply_eligible = true` and risk is not `low`.
- Alias proposal has no target.
- Canonical proposal has no slug/localized name.
- Parent proposal has no policy rationale.
- Target ingredient does not exist or is inactive/deprecated.
- Active alias conflict exists for the same normalized text.
- Proposed slug/localization conflicts with an existing canonical identity.
- Recipe reconciliation proposal is not confirmed by an existing safety preview.

Phase 1 does not implement validation logic; it stores enough data to make validation deterministic later.

## 10. Proposal Persistence Contract

Implemented by:

- `supabase/migrations/20260510130000_catalog_agent_proposal_foundation.sql`

Tables:

- `public.catalog_agent_runs`
- `public.catalog_agent_proposals`
- `public.catalog_agent_proposal_events`

Persistence rules:

- Tables are proposal-only and must not mutate catalog identity.
- RLS is enabled on all three tables.
- Catalog admins can read proposal data through RLS policies.
- `service_role` can write proposal data for future backend workers.
- App/client code must not receive direct write access.
- `auto_apply_eligible` is advisory only and restricted to `risk_level = 'low'`.
- `applied_at` can be set only when proposal status is `auto_applied`.
- Proposal events must reference either a proposal or a run.

Important limitation:

The migration intentionally does not include an agent snapshot RPC, LLM Edge Function, validator, auto-apply worker, or review UI.

## 11. Data Access Contract

The agent should receive bounded snapshots only. It should not browse the database freely.

Allowed snapshot data:

- normalized ingredient text
- raw example snippets
- occurrence counts
- source domain/name
- recipe title examples
- candidate queue hints
- possible canonical matches
- alias/localization conflicts
- hierarchy context
- previous accepted/rejected decisions

Disallowed snapshot data:

- user emails
- auth tokens
- service-role keys
- private profile metadata
- unrelated recipe notes
- unrelated user-generated content

## 12. Documentation Contract

Every future implementation change must update documentation in the same commit:

- Schema changes: update this file and relevant Supabase/security docs.
- Agent behavior changes: update this file and operating plan.
- Runtime/devops changes: add or update `supabase/devops/*` runbooks.
- UI changes: update functional/technical overview as needed.
- Security changes: update `docs/security/supabase-security-findings-disposition.md` or add a linked security note.

This prevents the agent system from becoming invisible infrastructure.
