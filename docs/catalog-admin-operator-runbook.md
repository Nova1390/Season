# Catalog Admin Operator Runbook

Status: dev console live at `https://catalog.seasonapp.it/`; staging remains intentionally untouched.

This runbook explains how to operate the Season catalog governance console without needing to read SQL, raw JSON, or backend code first.

## 1. Mental Model

The console is not the catalog brain. It is the operator cockpit.

- The Catalog Governance Agent is the manager.
- Autopilot workers do bounded execution.
- Supabase validators decide whether a mutation is actually safe.
- The console shows what happened, what is eligible, and where a human decision is still needed.

No browser action should ever bypass a guarded Supabase RPC.

## 2. Access

Open:

```text
https://catalog.seasonapp.it/
```

Sign in with a Supabase Auth user that has catalog-admin access on `Season-dev`.

Expected behavior:

- non-authenticated users see only login;
- authenticated users without catalog-admin access are signed out;
- the sidebar shows the active environment, currently `Season-dev`;
- privileged buttons still fail server-side if permissions are missing.

## 3. Review Inbox

Use `Catalog agent` for individual proposals.

Proposal states:

- `draft`: the agent created a proposal, but it has not entered validation.
- `queued_for_validation`: the proposal is waiting for deterministic checks.
- `failed_validation`: the backend rejected the proposal as unsafe or incomplete.
- `needs_human_review`: the agent intentionally escalated because the case is ambiguous.
- `validated`: the proposal passed deterministic checks.
- `auto_applied`: the proposal was applied by a guarded low-risk worker.
- `superseded`: a newer proposal or policy made this one obsolete.
- `rejected`: an operator explicitly rejected it.

Normal workflow:

1. Read the proposal rationale first.
2. Check target/proposal fields.
3. Check validation errors and evidence.
4. Use the action that matches the state.

Safe interpretation:

- A `needs_human_review` proposal is not directly actionable.
- If target fields are `none`, do not try to validate it manually as an apply candidate.
- Use `More evidence` when the agent is missing context.
- Use `Load learning` when an operator note should become future guidance.
- Use `Reject` only with a clear note.

## 4. Learning Memory

Use `Learning memory` to see what the agent has learned from prior failures, reviews, and corrections.

Good learning should be:

- specific enough to change future decisions;
- written as a reusable policy, not a one-off complaint;
- safe across languages and recipe sources;
- conservative when an ingredient identity is ambiguous.

Example:

```text
If a recipe says only "lievito", map it to the generic yeast/leavening entry only when the recipe context does not imply baking powder, sourdough starter, or a named chemical leavener.
```

Learning memory should reduce repetitive review, not create a hidden shortcut around validation.

## 5. Operations

Use `Operations` for manager-level worker visibility.

The key panels are:

- Recent worker jobs: what the agent asked workers to do.
- AI usage: today's model activity and approximate cost.
- Low-risk readiness: whether any proposal can be safely auto-applied.
- Auto-apply audit: what was applied and whether rollback is still possible.

Raw JSON is intentionally behind details panels. Prefer the visual summaries first.

## 6. Low-Risk Apply Dry-Run

The console exposes only dry-run for `low_risk_apply_batch`.

Use it when you want to know:

- whether there is safe apply work ready;
- how many proposals would be eligible;
- why the eligible count is zero.

Expected healthy result:

```text
No open low-risk apply work. Existing proposals are terminal or already handled.
```

That means the backlog is clean for this worker. It is not a failure.

If dry-run shows eligible proposals:

1. Review the preview.
2. Confirm they are low-risk existing-canonical changes.
3. Keep real apply disabled unless a specific controlled test is being performed.

## 7. Enrichment Draft Worker

The console can run small `enrichment_draft_batch` jobs.

Guardrails:

- UI limit is capped at 3.
- Use source-domain filters when possible.
- Avoid repeated runs if the failure ratio is high.
- Watch AI usage after each run.

Use this worker to create better draft metadata for unresolved catalog terms. Do not use it to force catalog identity decisions.

## 8. Rollback

Rollback is available only for active auto-apply audit records.

Before rollback:

- write a concrete reason;
- confirm the audit row is still active;
- prefer rollback only when the applied mutation is wrong or policy changed.

Rollback can fail safely if the underlying catalog row changed after the audit record. In that case, do not manually patch from the browser. Investigate the audit trail and backend state first.

## 9. Stop Conditions

Stop and investigate before running more automation if any of these happen:

- repeated validation failures for the same term;
- AI usage rises unexpectedly;
- rollback fails;
- a proposal targets the wrong canonical ingredient;
- a multilingual term has cultural or culinary ambiguity;
- staging or production data appears in the dev console unexpectedly;
- a button appears to mutate data without a matching audit/event record.

## 10. Promotion Gate

Before enabling this flow outside dev:

- Supabase lint must be clean.
- Security Advisor critical findings must be resolved or explicitly accepted.
- The console must point to the intended environment.
- Staging must have a separate config and release checklist.
- Low-risk real apply must remain disabled until dev dry-run history is boring.
- The Supabase PAT used during setup must be revoked/rotated.

The desired operational state is simple: the agent and workers handle routine catalog cleanup, while humans review only new policy, high-risk identity, and unexpected failures.
