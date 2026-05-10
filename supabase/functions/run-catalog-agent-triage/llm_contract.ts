export const CATALOG_AGENT_ALLOWED_PROPOSAL_TYPES = [
  "approve_alias",
  "create_canonical",
  "add_localization",
  "ignore_noise",
  "needs_human_review",
] as const;

export const CATALOG_AGENT_ALLOWED_RISK_LEVELS = [
  "low",
  "medium",
  "high",
  "critical",
  "unknown",
] as const;

export const CATALOG_AGENT_ALLOWED_STATUSES = [
  "draft",
  "needs_human_review",
] as const;

export type CatalogAgentProposalType = (typeof CATALOG_AGENT_ALLOWED_PROPOSAL_TYPES)[number];
export type CatalogAgentRiskLevel = (typeof CATALOG_AGENT_ALLOWED_RISK_LEVELS)[number];
export type CatalogAgentProposalStatus = (typeof CATALOG_AGENT_ALLOWED_STATUSES)[number];

export interface CatalogAgentProposalOutput {
  proposal_type: CatalogAgentProposalType;
  normalized_text: string;
  target_ingredient_id: string | null;
  target_slug: string | null;
  proposed_slug: string | null;
  proposed_alias_text: string | null;
  proposed_localized_name: string | null;
  proposed_language_code: string | null;
  confidence_score: number | null;
  risk_level: CatalogAgentRiskLevel;
  auto_apply_eligible: boolean;
  status: CatalogAgentProposalStatus;
  rationale: string;
  evidence: unknown[];
  blocking_questions: string[];
}

export interface CatalogAgentTriageOutput {
  run_summary: {
    items_reviewed: number;
    proposals_created: number;
    human_review_required: number;
    blocked: number;
  };
  proposals: CatalogAgentProposalOutput[];
}

export const CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT = `You are Season's autonomous Catalog Governance Operator.

Return ONLY valid JSON.
Do not output markdown.
Do not output code fences.
Do not output comments.
Do not output any text before or after JSON.

You are responsible for catalog quality, not for maximizing automation.

Your mission:
- protect ingredient identity correctness
- reduce unresolved custom ingredient backlog
- handle multilingual ambiguity carefully
- propose clear, auditable next actions
- escalate uncertainty

You MUST NOT:
- mutate catalog data
- claim that you applied anything
- invent ingredient ids
- collapse meaningful variants into generic ingredients
- use auto_apply_eligible=true unless risk_level is "low"

Allowed proposal_type values:
- "approve_alias"
- "create_canonical"
- "add_localization"
- "ignore_noise"
- "needs_human_review"

Allowed risk_level values:
- "low"
- "medium"
- "high"
- "critical"
- "unknown"

Allowed status values:
- "draft"
- "needs_human_review"

Return exactly this JSON shape:
{
  "run_summary": {
    "items_reviewed": number,
    "proposals_created": number,
    "human_review_required": number,
    "blocked": number
  },
  "proposals": [
    {
      "proposal_type": "approve_alias" | "create_canonical" | "add_localization" | "ignore_noise" | "needs_human_review",
      "normalized_text": string,
      "target_ingredient_id": string | null,
      "target_slug": string | null,
      "proposed_slug": string | null,
      "proposed_alias_text": string | null,
      "proposed_localized_name": string | null,
      "proposed_language_code": string | null,
      "confidence_score": number | null,
      "risk_level": "low" | "medium" | "high" | "critical" | "unknown",
      "auto_apply_eligible": boolean,
      "status": "draft" | "needs_human_review",
      "rationale": string,
      "evidence": [],
      "blocking_questions": []
    }
  ]
}

Decision policy:
1) Use approve_alias only when observed text is a surface/quantity/preparation variant of an existing target.
2) Use add_localization when the text is a language display name for an existing ingredient.
3) Use create_canonical when a genuinely distinct culinary identity is likely needed.
4) Use ignore_noise when the text is not an ingredient identity.
5) Use needs_human_review when language/culture/variant/product ambiguity exists.
6) If no safe target exists, do not invent target_ingredient_id.
7) For multilingual ambiguity, prefer needs_human_review.
8) For possible nutrition/allergy/seasonality differences, prefer needs_human_review.
9) target_ingredient_id must come only from work item context.
10) Every proposal needs a concrete rationale.
`;

export function validateCatalogAgentTriageOutput(
  payload: unknown,
  allowedNormalizedTexts: Set<string>,
): {
  ok: boolean;
  errors: string[];
  value?: CatalogAgentTriageOutput;
} {
  const errors: string[] = [];

  if (!isRecord(payload)) {
    return { ok: false, errors: ["payload must be an object"] };
  }

  if (!isRecord(payload.run_summary)) {
    errors.push("run_summary must be an object");
  } else {
    for (const key of ["items_reviewed", "proposals_created", "human_review_required", "blocked"]) {
      if (!Number.isInteger(payload.run_summary[key]) || Number(payload.run_summary[key]) < 0) {
        errors.push(`run_summary.${key} must be a non-negative integer`);
      }
    }
  }

  if (!Array.isArray(payload.proposals)) {
    errors.push("proposals must be an array");
  } else {
    payload.proposals.forEach((proposal, index) => {
      validateProposal(proposal, index, allowedNormalizedTexts, errors);
    });
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  return { ok: true, errors: [], value: payload as CatalogAgentTriageOutput };
}

function validateProposal(
  proposal: unknown,
  index: number,
  allowedNormalizedTexts: Set<string>,
  errors: string[],
) {
  const prefix = `proposals[${index}]`;
  if (!isRecord(proposal)) {
    errors.push(`${prefix} must be an object`);
    return;
  }

  const expectedKeys = [
    "proposal_type",
    "normalized_text",
    "target_ingredient_id",
    "target_slug",
    "proposed_slug",
    "proposed_alias_text",
    "proposed_localized_name",
    "proposed_language_code",
    "confidence_score",
    "risk_level",
    "auto_apply_eligible",
    "status",
    "rationale",
    "evidence",
    "blocking_questions",
  ];

  for (const key of expectedKeys) {
    if (!(key in proposal)) {
      errors.push(`${prefix} missing key: ${key}`);
    }
  }

  const proposalType = proposal.proposal_type;
  if (!CATALOG_AGENT_ALLOWED_PROPOSAL_TYPES.includes(proposalType as CatalogAgentProposalType)) {
    errors.push(`${prefix}.proposal_type unsupported`);
  }

  const normalizedText = normalizeString(proposal.normalized_text);
  if (!normalizedText) {
    errors.push(`${prefix}.normalized_text required`);
  } else if (!allowedNormalizedTexts.has(normalizedText)) {
    errors.push(`${prefix}.normalized_text not present in work packet`);
  }

  for (const nullableStringKey of [
    "target_ingredient_id",
    "target_slug",
    "proposed_slug",
    "proposed_alias_text",
    "proposed_localized_name",
    "proposed_language_code",
  ]) {
    if (!isNullableString(proposal[nullableStringKey])) {
      errors.push(`${prefix}.${nullableStringKey} must be string or null`);
    }
  }

  if (!(proposal.confidence_score === null || (typeof proposal.confidence_score === "number" && Number.isFinite(proposal.confidence_score)))) {
    errors.push(`${prefix}.confidence_score must be number or null`);
  } else if (typeof proposal.confidence_score === "number" && (proposal.confidence_score < 0 || proposal.confidence_score > 1)) {
    errors.push(`${prefix}.confidence_score must be within 0..1`);
  }

  const riskLevel = proposal.risk_level;
  if (!CATALOG_AGENT_ALLOWED_RISK_LEVELS.includes(riskLevel as CatalogAgentRiskLevel)) {
    errors.push(`${prefix}.risk_level unsupported`);
  }

  if (typeof proposal.auto_apply_eligible !== "boolean") {
    errors.push(`${prefix}.auto_apply_eligible must be boolean`);
  }
  if (proposal.auto_apply_eligible === true && riskLevel !== "low") {
    errors.push(`${prefix}.auto_apply_eligible requires low risk`);
  }

  const status = proposal.status;
  if (!CATALOG_AGENT_ALLOWED_STATUSES.includes(status as CatalogAgentProposalStatus)) {
    errors.push(`${prefix}.status unsupported`);
  }
  if (riskLevel !== "low" && status !== "needs_human_review") {
    errors.push(`${prefix}.status must be needs_human_review for non-low risk`);
  }

  if (typeof proposal.rationale !== "string" || proposal.rationale.trim().length < 12) {
    errors.push(`${prefix}.rationale must be a meaningful string`);
  }

  if (!Array.isArray(proposal.evidence)) {
    errors.push(`${prefix}.evidence must be an array`);
  }

  if (!Array.isArray(proposal.blocking_questions) || !proposal.blocking_questions.every((item) => typeof item === "string")) {
    errors.push(`${prefix}.blocking_questions must be string[]`);
  }

  if (proposalType === "approve_alias" || proposalType === "add_localization") {
    if (!normalizeString(proposal.target_ingredient_id) && !normalizeString(proposal.target_slug)) {
      errors.push(`${prefix}.${proposalType} requires target_ingredient_id or target_slug`);
    }
  }

  if (proposalType === "create_canonical") {
    if (!normalizeString(proposal.proposed_slug)) {
      errors.push(`${prefix}.create_canonical requires proposed_slug`);
    }
    if (!normalizeString(proposal.proposed_localized_name)) {
      errors.push(`${prefix}.create_canonical requires proposed_localized_name`);
    }
  }
}

function normalizeString(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function isNullableString(value: unknown): boolean {
  return value === null || typeof value === "string";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
