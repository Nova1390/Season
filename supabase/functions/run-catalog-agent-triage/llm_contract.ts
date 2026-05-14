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

export const CATALOG_AGENT_ALLOWED_SUBSTITUTABILITY = [
  "full",
  "partial",
  "unsafe",
  "unknown",
] as const;

export const CATALOG_AGENT_ALLOWED_IMPLICATION_LEVELS = [
  "none",
  "possible",
  "likely",
  "material",
  "unknown",
] as const;

export type CatalogAgentProposalType = (typeof CATALOG_AGENT_ALLOWED_PROPOSAL_TYPES)[number];
export type CatalogAgentRiskLevel = (typeof CATALOG_AGENT_ALLOWED_RISK_LEVELS)[number];
export type CatalogAgentProposalStatus = (typeof CATALOG_AGENT_ALLOWED_STATUSES)[number];
export type CatalogAgentSubstitutability = (typeof CATALOG_AGENT_ALLOWED_SUBSTITUTABILITY)[number];
export type CatalogAgentImplicationLevel = (typeof CATALOG_AGENT_ALLOWED_IMPLICATION_LEVELS)[number];

export interface CatalogAgentSemanticProfileOutput {
  product_family: string | null;
  semantic_category: string | null;
  variant_dimension: string | null;
  variant_kind: string | null;
  parent_candidate_slug: string | null;
  is_identity_bearing_variant: boolean | null;
  substitutability_with_parent: CatalogAgentSubstitutability;
  attribute_implications: string[];
  nutrition_implication: CatalogAgentImplicationLevel;
  seasonality_implication: CatalogAgentImplicationLevel;
  allergy_implication: CatalogAgentImplicationLevel;
  fridge_matching_implication: CatalogAgentImplicationLevel;
  shopping_matching_implication: CatalogAgentImplicationLevel;
  filter_implication: CatalogAgentImplicationLevel;
  market_or_language_notes: string | null;
  confidence_score: number | null;
  evidence: string[];
  open_questions: string[];
}

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
  semantic_profile: CatalogAgentSemanticProfileOutput;
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
- distinguish ingredient-existence confidence from canonical-target confidence
- use learning memory to avoid repeating known mistakes
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
      "semantic_profile": {
        "product_family": string | null,
        "semantic_category": string | null,
        "variant_dimension": string | null,
        "variant_kind": string | null,
        "parent_candidate_slug": string | null,
        "is_identity_bearing_variant": boolean | null,
        "substitutability_with_parent": "full" | "partial" | "unsafe" | "unknown",
        "attribute_implications": string[],
        "nutrition_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "seasonality_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "allergy_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "fridge_matching_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "shopping_matching_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "filter_implication": "none" | "possible" | "likely" | "material" | "unknown",
        "market_or_language_notes": string | null,
        "confidence_score": number | null,
        "evidence": string[],
        "open_questions": string[]
      },
      "rationale": string,
      "evidence": [],
      "blocking_questions": []
    }
  ]
}

Decision policy:
1) Use approve_alias only when observed text is a surface/quantity/preparation variant of an existing target.
2) Use add_localization when the text is the intended language display name for an existing ingredient.
2a) If the target already has a curated display name in that language, use approve_alias for plural forms, imported surface text, common alternate wording, or localized search terms. Do not use add_localization just because the observed text is in another language.
2b) For localized base plurals or singular/plural variants, prefer approve_alias to the active base canonical when semantic_profile.is_identity_bearing_variant=false and a safe target is present.
3) Use create_canonical when a genuinely distinct culinary identity is likely needed.
4) Use ignore_noise when the text is not an ingredient identity.
5) Use needs_human_review when language/culture/variant/product ambiguity exists.
6) If no safe target exists, do not invent target_ingredient_id.
7) For multilingual ambiguity, prefer needs_human_review.
8) For possible nutrition/allergy/seasonality differences, prefer needs_human_review.
9) target_ingredient_id must come only from work item context.
10) Every proposal needs a concrete rationale.
11) If a term is clearly an ingredient but canonical target is ambiguous, do not call it low-confidence noise. Return needs_human_review with candidate targets and missing evidence in evidence/blocking_questions.
12) Use recipe_context title, nearby ingredients, quantities, units, source, and step snippets to disambiguate terms such as yeast/baking powder/sourdough or generic vs specific variants.
13) For terms like "lievito", separate "is ingredient" from "which canonical leavening agent". Pick approve_alias only when recipe context and provided candidates make one target safe.
14) If the work item is bare "lievito", the canonical candidate "lievito" is present, and there is no evidence for a more specific leavening variant, prefer approve_alias to "lievito".
15) Do not map bare "lievito" to baking powder, brewer's yeast, sourdough starter, fresh yeast, or dry yeast unless the recipe text provides that specific evidence.
16) Do not collapse identity-bearing variants into generic base ingredients. If a term changes culinary identity, nutrition, seasonality, form factor, dietary suitability, or substitutability, require an explicit child/specialized target or human review/catalog-gap handling instead of approve_alias to the base.
17) Read global_learning_memory, each work item's relevant_learning_memory, and each work item's training_signals before deciding.
17a) Treat training_signals as corpus-derived advisory evidence only. They can support priority, evidence, and questions, but they are not catalog truth and must not bypass validators.
18) Treat learning memory as operational memory: implemented and accepted lessons are strong guidance; needs_review lessons are caution signals.
19) Do not repeat a prior failed/rejected/ambiguous recommendation unless the current work item contains new evidence that resolves the recorded problem.
20) When learning memory changes your decision, mention the learning_id in evidence.
21) Always fill semantic_profile before writing the final proposal fields. The semantic_profile is analysis evidence, not catalog truth.
22) product_family should describe the broad product family when clear, for example tomato, potato, yeast, onion, flour, cheese. Use null if unclear.
23) variant_dimension should describe why this may be a variant, for example size, cultivar, processing_state, fat_level, freshness, protected_designation, shape, product_type, or null.
24) is_identity_bearing_variant=true when the term can materially affect culinary use, substitutability, nutrition, seasonality, allergy, fridge matching, shopping matching, or filters.
25) substitutability_with_parent="full" only when the term can safely use the parent ingredient for recipe/fridge/shopping semantics. Use "partial", "unsafe", or "unknown" when a child/specialized target or review may be needed.
26) For terms such as "pomodorini" vs "pomodori", do not rely on a hardcoded example. Apply the general meaningful-variant rule: if the term is a recognized culinary/market variant with material matching or usage differences, do not auto-approve it as a base alias.
27) If a semantic_profile suggests a meaningful variant but the catalog has no explicit safe child target, prefer create_canonical or needs_human_review over approve_alias to the base.
28) Lack of an existing target is not, by itself, a reason for needs_human_review. If the term is clearly a real ingredient identity, no safe catalog target/candidate exists, and there is enough evidence to name the ingredient, return create_canonical instead of a vague review outcome.
29) For create_canonical, leave target_ingredient_id and target_slug null, set proposed_slug, proposed_localized_name, and proposed_language_code, set auto_apply_eligible=false, and use status="draft". The proposed_slug must be stable snake_case ASCII without inventing an existing id.
30) Use needs_human_review instead of create_canonical only when the identity boundary is unclear, the term may be a brand/package/preparation/noise, the variant policy is unresolved, or the proposed canonical would risk collapsing another meaningful ingredient.
31) Medium/high risk does not automatically mean needs_human_review. Actionable proposal types can be draft with auto_apply_eligible=false so deterministic validators and future workers can inspect them safely.
32) If implemented learning memory says a term or product family must not be compressed into a base ingredient, treat that as authorization to propose a child/specialized create_canonical draft when the identity is clear and the child target is missing. Do not ask for human review just because the new canonical would be medium/high risk; risk controls apply to apply eligibility, not to proposal creation.
33) For clear market or culinary variants such as size class, cultivar, processing state, fat level, freshness, protected designation, or product type, prefer create_canonical draft over needs_human_review when the variant identity is well known and the catalog lacks an explicit child/specialized node.
33a) Product-form terms such as flakes, powder, whole grain, chopped, sliced, smoked, dried, or fresh can be identity-bearing when they affect shopping/fridge matching, nutrition, or cooking behavior. If the identity is clear and no explicit child target exists, propose create_canonical rather than vague review.
34) Include concrete semantic_profile.evidence and proposal evidence that reference recipe context, catalog candidates, learning memory, catalog gaps, or missing evidence.
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

  return { ok: true, errors: [], value: payload as unknown as CatalogAgentTriageOutput };
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
    "semantic_profile",
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
  if (proposalType === "needs_human_review" && status !== "needs_human_review") {
    errors.push(`${prefix}.needs_human_review requires status needs_human_review`);
  }
  if (proposalType !== "needs_human_review" && status !== "draft") {
    errors.push(`${prefix}.actionable proposal types must use draft status`);
  }
  if (proposal.auto_apply_eligible === true && !["approve_alias", "add_localization"].includes(String(proposalType))) {
    errors.push(`${prefix}.auto_apply_eligible is only supported for approve_alias/add_localization`);
  }

  validateSemanticProfile(proposal.semantic_profile, `${prefix}.semantic_profile`, errors);

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

function validateSemanticProfile(
  value: unknown,
  prefix: string,
  errors: string[],
) {
  if (!isRecord(value)) {
    errors.push(`${prefix} must be an object`);
    return;
  }

  const expectedKeys = [
    "product_family",
    "semantic_category",
    "variant_dimension",
    "variant_kind",
    "parent_candidate_slug",
    "is_identity_bearing_variant",
    "substitutability_with_parent",
    "attribute_implications",
    "nutrition_implication",
    "seasonality_implication",
    "allergy_implication",
    "fridge_matching_implication",
    "shopping_matching_implication",
    "filter_implication",
    "market_or_language_notes",
    "confidence_score",
    "evidence",
    "open_questions",
  ];

  for (const key of expectedKeys) {
    if (!(key in value)) {
      errors.push(`${prefix} missing key: ${key}`);
    }
  }

  for (const nullableStringKey of [
    "product_family",
    "semantic_category",
    "variant_dimension",
    "variant_kind",
    "parent_candidate_slug",
    "market_or_language_notes",
  ]) {
    if (!isNullableString(value[nullableStringKey])) {
      errors.push(`${prefix}.${nullableStringKey} must be string or null`);
    }
  }

  if (!(value.is_identity_bearing_variant === null || typeof value.is_identity_bearing_variant === "boolean")) {
    errors.push(`${prefix}.is_identity_bearing_variant must be boolean or null`);
  }

  if (!CATALOG_AGENT_ALLOWED_SUBSTITUTABILITY.includes(value.substitutability_with_parent as CatalogAgentSubstitutability)) {
    errors.push(`${prefix}.substitutability_with_parent unsupported`);
  }

  for (const implicationKey of [
    "nutrition_implication",
    "seasonality_implication",
    "allergy_implication",
    "fridge_matching_implication",
    "shopping_matching_implication",
    "filter_implication",
  ]) {
    if (!CATALOG_AGENT_ALLOWED_IMPLICATION_LEVELS.includes(value[implicationKey] as CatalogAgentImplicationLevel)) {
      errors.push(`${prefix}.${implicationKey} unsupported`);
    }
  }

  if (!Array.isArray(value.attribute_implications) || !value.attribute_implications.every((item) => typeof item === "string")) {
    errors.push(`${prefix}.attribute_implications must be string[]`);
  }

  if (!Array.isArray(value.evidence) || !value.evidence.every((item) => typeof item === "string")) {
    errors.push(`${prefix}.evidence must be string[]`);
  }

  if (!Array.isArray(value.open_questions) || !value.open_questions.every((item) => typeof item === "string")) {
    errors.push(`${prefix}.open_questions must be string[]`);
  }

  if (!(value.confidence_score === null || (typeof value.confidence_score === "number" && Number.isFinite(value.confidence_score)))) {
    errors.push(`${prefix}.confidence_score must be number or null`);
  } else if (typeof value.confidence_score === "number" && (value.confidence_score < 0 || value.confidence_score > 1)) {
    errors.push(`${prefix}.confidence_score must be within 0..1`);
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
