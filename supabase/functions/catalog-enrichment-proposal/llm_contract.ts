export const CATALOG_ENRICHMENT_ALLOWED_INGREDIENT_TYPES = [
  "produce",
  "basic",
  "unknown",
] as const;

export type CatalogEnrichmentIngredientType =
  (typeof CATALOG_ENRICHMENT_ALLOWED_INGREDIENT_TYPES)[number];

export interface CatalogEnrichmentProposal {
  ingredient_type: CatalogEnrichmentIngredientType;
  canonical_name_it: string | null;
  canonical_name_en: string | null;
  suggested_slug: string;
  default_unit: string;
  supported_units: string[];
  is_seasonal: boolean | null;
  season_months: number[] | null;
  needs_manual_review: boolean;
  reasoning_summary: string;
  confidence_score: number;
}

export const CATALOG_ENRICHMENT_SYSTEM_PROMPT = `You are a strict JSON engine for Season catalog enrichment proposals.

Return ONLY valid JSON.
Do not output markdown.
Do not output code fences.
Do not output comments.
Do not output explanations.
Do not output any text before or after JSON.

You MUST return exactly this object shape:
{
  "ingredient_type": "produce" | "basic" | "unknown",
  "canonical_name_it": string | null,
  "canonical_name_en": string | null,
  "suggested_slug": string,
  "default_unit": string,
  "supported_units": string[],
  "is_seasonal": boolean | null,
  "season_months": number[] | null,
  "needs_manual_review": boolean,
  "reasoning_summary": string,
  "confidence_score": number
}

Rules:
1) Input is a normalized unresolved ingredient text.
2) Classify ingredient_type as produce/basic/unknown conservatively.
3) Be conservative; prefer null over guessing.
4) Keep needs_manual_review=true by default.
5) suggested_slug must be lowercase snake_case and stable.
6) default_unit must be a practical unit token.
7) supported_units must include default_unit.
8) For produce:
   - set is_seasonal true or false if known; null if unknown.
   - season_months only when is_seasonal=true.
9) For non-produce:
   - set is_seasonal=null
   - set season_months=null
10) confidence_score must be 0..1.
11) canonical names should be human-usable; if unknown use null.
12) Do not hallucinate uncommon nutrition or taxonomy details.
`;

export function validateCatalogEnrichmentProposal(payload: unknown): {
  ok: boolean;
  errors: string[];
  value?: CatalogEnrichmentProposal;
} {
  const errors: string[] = [];

  if (!isRecord(payload)) {
    return { ok: false, errors: ["payload must be an object"] };
  }

  const expectedKeys = [
    "ingredient_type",
    "canonical_name_it",
    "canonical_name_en",
    "suggested_slug",
    "default_unit",
    "supported_units",
    "is_seasonal",
    "season_months",
    "needs_manual_review",
    "reasoning_summary",
    "confidence_score",
  ];

  for (const key of expectedKeys) {
    if (!(key in payload)) {
      errors.push(`missing key: ${key}`);
    }
  }

  for (const key of Object.keys(payload)) {
    if (!expectedKeys.includes(key)) {
      errors.push(`unexpected key: ${key}`);
    }
  }

  const type = payload.ingredient_type;
  if (!CATALOG_ENRICHMENT_ALLOWED_INGREDIENT_TYPES.includes(type as CatalogEnrichmentIngredientType)) {
    errors.push("ingredient_type must be produce|basic|unknown");
  }

  if (!isNullableString(payload.canonical_name_it)) {
    errors.push("canonical_name_it must be string or null");
  }

  if (!isNullableString(payload.canonical_name_en)) {
    errors.push("canonical_name_en must be string or null");
  }

  if (typeof payload.suggested_slug !== "string" || payload.suggested_slug.trim().length === 0) {
    errors.push("suggested_slug must be non-empty string");
  }

  if (typeof payload.default_unit !== "string" || payload.default_unit.trim().length === 0) {
    errors.push("default_unit must be non-empty string");
  }

  if (!Array.isArray(payload.supported_units) || !payload.supported_units.every((unit) => typeof unit === "string" && unit.trim().length > 0)) {
    errors.push("supported_units must be array of non-empty strings");
  }

  if (!(payload.is_seasonal === null || typeof payload.is_seasonal === "boolean")) {
    errors.push("is_seasonal must be boolean or null");
  }

  if (!(payload.season_months === null || (Array.isArray(payload.season_months) && payload.season_months.every((m) => Number.isInteger(m) && m >= 1 && m <= 12)))) {
    errors.push("season_months must be null or array of 1..12 integers");
  }

  if (typeof payload.needs_manual_review !== "boolean") {
    errors.push("needs_manual_review must be boolean");
  }

  if (typeof payload.reasoning_summary !== "string") {
    errors.push("reasoning_summary must be string");
  }

  if (typeof payload.confidence_score !== "number" || !Number.isFinite(payload.confidence_score)) {
    errors.push("confidence_score must be number");
  } else if (payload.confidence_score < 0 || payload.confidence_score > 1) {
    errors.push("confidence_score must be within 0..1");
  }

  if (Array.isArray(payload.supported_units) && typeof payload.default_unit === "string") {
    const normalizedDefault = payload.default_unit.trim().toLowerCase();
    const normalizedUnits = payload.supported_units.map((u) => u.trim().toLowerCase());
    if (!normalizedUnits.includes(normalizedDefault)) {
      errors.push("supported_units must include default_unit");
    }
  }

  if (type !== "produce") {
    if (payload.is_seasonal !== null) {
      errors.push("is_seasonal must be null for non-produce");
    }
    if (payload.season_months !== null) {
      errors.push("season_months must be null for non-produce");
    }
  } else {
    if (payload.is_seasonal === true && payload.season_months === null) {
      errors.push("season_months required when produce is seasonal");
    }
    if (payload.is_seasonal !== true && payload.season_months !== null) {
      errors.push("season_months must be null when produce is not seasonal");
    }
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    errors: [],
    value: payload as CatalogEnrichmentProposal,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}
