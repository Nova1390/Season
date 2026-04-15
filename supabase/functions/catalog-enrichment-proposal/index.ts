import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  CATALOG_ENRICHMENT_SYSTEM_PROMPT,
  type CatalogEnrichmentProposal,
  validateCatalogEnrichmentProposal,
} from "./llm_contract.ts";

interface CatalogEnrichmentRequest {
  normalized_text?: string;
  original_text?: string;
  cleaned_text?: string;
  removed_qualifiers?: string[];
}

interface NormalizedIdentityInput {
  cleanedText: string;
  removedQualifiers: string[];
}

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_API_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-5.4-mini";
const PROVIDER_TIMEOUT_MS = Number(Deno.env.get("CATALOG_ENRICHMENT_PROVIDER_TIMEOUT_MS") ?? "15000");
const MAX_NORMALIZED_TEXT_LENGTH = 120;

Deno.serve(async (request) => {
  try {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=request_received method=${request.method}`);

    if (request.method !== "POST") {
      return errorJson(405, "METHOD_NOT_ALLOWED", "Only POST is supported.");
    }

    const contentType = request.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("application/json")) {
      return errorJson(415, "INVALID_CONTENT_TYPE", "Request must use application/json.");
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return errorJson(500, "SERVER_MISCONFIGURED", "Supabase environment is not configured.");
    }

    const auth = await resolveCallerAuth(request);
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
    }

    let payload: CatalogEnrichmentRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const originalText = normalizeText(payload.original_text) || normalizeText(payload.normalized_text);
    if (!originalText) {
      return errorJson(422, "INVALID_INPUT", "normalized_text is required.");
    }

    if (originalText.length > MAX_NORMALIZED_TEXT_LENGTH) {
      return errorJson(422, "INVALID_INPUT", `normalized_text exceeds max length (${MAX_NORMALIZED_TEXT_LENGTH}).`);
    }

    const baseTextForCleaning = normalizeText(payload.cleaned_text) || originalText;
    const identityInput = normalizeIngredientIdentityInput(baseTextForCleaning);
    const cleanedText = normalizeText(identityInput.cleanedText) || originalText;
    const removedQualifiers = dedupeStrings([
      ...(Array.isArray(payload.removed_qualifiers) ? payload.removed_qualifiers : []),
      ...identityInput.removedQualifiers,
    ]);
    console.log(
      `[SEASON_CATALOG_ENRICHMENT] phase=identity_input original_text=${originalText} cleaned_text=${cleanedText} removed_qualifiers=${removedQualifiers.join("|")}`,
    );

    if (!OPENAI_API_KEY) {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_not_configured fallback=true");
      return json(buildFallbackProposal(cleanedText));
    }

    try {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_call_start");
      const providerOutput = await invokeProvider(cleanedText, originalText);
      const validation = validateCatalogEnrichmentProposal(providerOutput);

      if (!validation.ok || !validation.value) {
        console.log(
          `[SEASON_CATALOG_ENRICHMENT] phase=validator_failed fallback=true errors=${validation.errors.join(" | ")}`,
        );
        return json(buildFallbackProposal(cleanedText));
      }

      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_call_success validator_ok=true");
      const hierarchyHints = await inferHierarchyHints(cleanedText);
      const proposal = withSafeDefaults(validation.value, cleanedText, hierarchyHints);
      const deterministicFallback = maybeBuildDeterministicSimpleFallback(cleanedText, "low_confidence_or_unknown_provider_output");
      if (
        deterministicFallback &&
        (proposal.ingredient_type === "unknown" || proposal.confidence_score < 0.5)
      ) {
        console.log(
          `[SEASON_CATALOG_ENRICHMENT] phase=deterministic_fallback_used reason=low_confidence_or_unknown_provider_output cleaned_text=${cleanedText} inferred_type=${deterministicFallback.ingredient_type}`,
        );
        return json(deterministicFallback);
      }
      return json(proposal);
    } catch (error) {
      console.log(`[SEASON_CATALOG_ENRICHMENT] phase=provider_failed fallback=true error=${String(error)}`);
      return json(buildFallbackProposal(cleanedText));
    }
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=unhandled_error error=${String(error)}`);
    return json(buildFallbackProposal(""));
  }
});

async function resolveCallerAuth(request: Request): Promise<{ allowed: boolean; mode: "user" | "service_role" | "none" }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearerToken = extractBearerToken(authHeader) ?? "";

  if (apikey && SUPABASE_SERVICE_ROLE_KEY && apikey === SUPABASE_SERVICE_ROLE_KEY) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=service_role");
    return { allowed: true, mode: "service_role" };
  }

  if (bearerToken && SUPABASE_SERVICE_ROLE_KEY && bearerToken === SUPABASE_SERVICE_ROLE_KEY) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=service_role");
    return { allowed: true, mode: "service_role" };
  }

  if (!bearerToken) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_missing");
    return { allowed: false, mode: "none" };
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.auth.getUser(bearerToken);
  if (error || !data.user?.id) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_invalid_user_token");
    return { allowed: false, mode: "none" };
  }

  console.log(`[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=user user_id=${data.user.id}`);
  return { allowed: true, mode: "user" };
}

async function invokeProvider(cleanedText: string, originalText: string): Promise<unknown> {
  const userPrompt = [
    "Generate a catalog enrichment proposal for this unresolved ingredient candidate.",
    "Return strict JSON only.",
    `normalized_text: ${cleanedText}`,
    `original_text: ${originalText}`,
  ].join("\n");

  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: CATALOG_ENRICHMENT_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userPrompt,
          },
        ],
      },
    ],
    temperature: 0,
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

  try {
    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!response.ok) {
      const details = await response.text();
      throw new Error(`provider_http_${response.status}: ${details}`);
    }

    const providerJSON = await response.json();
    const outputText = extractProviderOutputText(providerJSON);
    if (!outputText) {
      throw new Error("provider_missing_output_text");
    }

    const parsed = safeParseJSON(outputText);
    if (!parsed) {
      throw new Error("provider_invalid_json_output");
    }

    return parsed;
  } finally {
    clearTimeout(timeout);
  }
}

function withSafeDefaults(
  value: CatalogEnrichmentProposal,
  normalizedText: string,
  hierarchyHints: HierarchyHints,
): CatalogEnrichmentProposal {
  const fallback = buildFallbackProposal(normalizedText);
  const supportedUnits = dedupeUnits(value.supported_units);
  const defaultUnit = value.default_unit.trim() || fallback.default_unit;
  const units = supportedUnits.includes(defaultUnit) ? supportedUnits : dedupeUnits([defaultUnit, ...supportedUnits]);
  const ingredientType = normalizedIngredientType(value.ingredient_type, normalizedText);
  const normalizedSuggestedSlug = toSnakeCase(value.suggested_slug) || fallback.suggested_slug;
  const compaction = applyDeterministicCompaction({
    cleanedText: normalizedText,
    suggestedSlug: normalizedSuggestedSlug,
  });
  const hasCompactionMatch =
    compaction.canonicalSlug !== normalizedSuggestedSlug ||
    compaction.forcedParentSlug !== null;
  const semanticCategory = cleanNullableString(value.semantic_category) ?? hierarchyHints.semanticCategory;
  const parentCandidateSlug = hasCompactionMatch
    ? compaction.forcedParentSlug
    : cleanNullableString(value.parent_candidate_slug) ?? hierarchyHints.parentCandidateSlug;
  const parentCandidateReason = cleanNullableString(value.parent_candidate_reason) ?? hierarchyHints.parentCandidateReason;
  const variantKind = parentCandidateSlug ? (cleanNullableString(value.variant_kind) ?? hierarchyHints.variantKind ?? "variety") : null;
  const specificityRankSuggestion = parentCandidateSlug
    ? Math.max(1, Number.isInteger(value.specificity_rank_suggestion) ? value.specificity_rank_suggestion as number : (hierarchyHints.specificityRankSuggestion ?? 1))
    : null;

  let confidence = clamp01(value.confidence_score);
  if (parentCandidateSlug && hierarchyHints.parentExists && confidence < 0.85) {
    confidence = 0.85;
  }
  if (hierarchyHints.semanticStrength === "high" && confidence < 0.9) {
    confidence = 0.9;
  }

  return {
    ingredient_type: ingredientType,
    canonical_name_it: cleanNullableString(value.canonical_name_it),
    canonical_name_en: cleanNullableString(value.canonical_name_en),
    suggested_slug: compaction.canonicalSlug,
    semantic_category: semanticCategory,
    parent_candidate_slug: parentCandidateSlug,
    parent_candidate_reason: parentCandidateReason,
    variant_kind: variantKind,
    specificity_rank_suggestion: specificityRankSuggestion,
    default_unit: defaultUnit,
    supported_units: units.length > 0 ? units : fallback.supported_units,
    is_seasonal: ingredientType === "produce" ? value.is_seasonal : null,
    season_months: ingredientType === "produce" ? value.season_months : null,
    needs_manual_review: true,
    reasoning_summary: value.reasoning_summary?.trim() || fallback.reasoning_summary,
    confidence_score: confidence,
  };
}

function applyDeterministicCompaction(input: {
  cleanedText: string;
  suggestedSlug: string;
}): {
  canonicalSlug: string;
  forcedParentSlug: string | null;
} {
  const cleanedText = normalizeText(input.cleanedText).toLowerCase();
  const suggestedSlug = toSnakeCase(input.suggestedSlug);

  // A) taleggio morbido -> taleggio, parent formaggi
  if (cleanedText.includes("taleggio") && cleanedText.includes("morbid")) {
    return {
      canonicalSlug: "taleggio",
      forcedParentSlug: "formaggi",
    };
  }

  // B) *_all_uovo -> remove suffix, parent pasta
  const pastaEggMatch = suggestedSlug.match(/^(.+)_all_uovo$/);
  if (pastaEggMatch?.[1]) {
    return {
      canonicalSlug: pastaEggMatch[1],
      forcedParentSlug: "pasta",
    };
  }

  // C) pane mollica -> pane, no parent
  if (cleanedText.includes("pane") && cleanedText.includes("mollica")) {
    return {
      canonicalSlug: "pane",
      forcedParentSlug: null,
    };
  }

  // D) champignon -> champignon, parent funghi
  if (cleanedText.includes("champignon")) {
    return {
      canonicalSlug: "champignon",
      forcedParentSlug: "funghi",
    };
  }

  // E) cioccolato fondente (+ percentage/usage qualifiers) -> cioccolato_fondente
  if (cleanedText.includes("cioccolato") && cleanedText.includes("fondente")) {
    return {
      canonicalSlug: "cioccolato_fondente",
      forcedParentSlug: null,
    };
  }

  // F) zafferano (+ presentation qualifiers like "in pistilli") -> zafferano
  if (cleanedText.includes("zafferano")) {
    return {
      canonicalSlug: "zafferano",
      forcedParentSlug: null,
    };
  }

  return {
    canonicalSlug: suggestedSlug,
    forcedParentSlug: null,
  };
}

function buildFallbackProposal(normalizedText: string): CatalogEnrichmentProposal {
  const deterministicFallback = maybeBuildDeterministicSimpleFallback(normalizedText, "provider_unavailable_or_invalid_output");
  if (deterministicFallback) {
    return deterministicFallback;
  }

  const safeText = normalizeText(normalizedText);
  const slug = toSnakeCase(safeText || "unknown_ingredient");
  const titleIt = safeText ? toTitleCase(safeText) : null;

  return {
    ingredient_type: "unknown",
    canonical_name_it: titleIt,
    canonical_name_en: null,
    suggested_slug: slug,
    semantic_category: null,
    parent_candidate_slug: null,
    parent_candidate_reason: null,
    variant_kind: null,
    specificity_rank_suggestion: null,
    default_unit: "g",
    supported_units: ["g", "piece"],
    is_seasonal: null,
    season_months: null,
    needs_manual_review: true,
    reasoning_summary: "Fallback proposal generated due to provider unavailability or invalid output.",
    confidence_score: 0.1,
  };
}

function maybeBuildDeterministicSimpleFallback(
  cleanedText: string,
  reason: "provider_unavailable_or_invalid_output" | "low_confidence_or_unknown_provider_output",
): CatalogEnrichmentProposal | null {
  const normalized = normalizeText(cleanedText).toLowerCase();
  if (!isSimpleIngredientIdentity(normalized)) return null;

  const inferredType = inferDeterministicIngredientType(normalized);
  const defaultUnit = inferredType === "produce" ? "piece" : "g";
  const supportedUnits = inferredType === "produce" ? ["piece", "g"] : ["g", "piece"];

  return {
    ingredient_type: inferredType,
    canonical_name_it: toTitleCase(normalized),
    canonical_name_en: null,
    suggested_slug: toSnakeCase(normalized),
    semantic_category: null,
    parent_candidate_slug: null,
    parent_candidate_reason: null,
    variant_kind: null,
    specificity_rank_suggestion: null,
    default_unit: defaultUnit,
    supported_units: supportedUnits,
    is_seasonal: null,
    season_months: null,
    needs_manual_review: true,
    reasoning_summary: "Deterministic fallback: simple ingredient inferred without LLM",
    confidence_score: inferredType === "produce" ? 0.68 : 0.72,
  };
}

function isSimpleIngredientIdentity(value: string): boolean {
  if (!value) return false;
  const normalized = value.replace(/\s+/g, " ").trim();
  if (!/^[a-zà-ÿ'\s]+$/i.test(normalized)) return false;
  if (/[,&/+]/.test(normalized)) return false;
  const parts = normalized.split(" ").filter((part) => part.length > 0);
  if (parts.length === 0 || parts.length > 2) return false;
  const blockers = new Set(["di", "da", "con", "per", "e", "o"]);
  if (parts.some((part) => blockers.has(part))) return false;
  return true;
}

function inferDeterministicIngredientType(value: string): CatalogEnrichmentProposal["ingredient_type"] {
  const produceLexicon = new Set([
    "limone", "limoni", "zucchina", "zucchine", "porro", "porri", "sedano", "prezzemolo",
    "cipolla", "cipolle", "patata", "patate", "carota", "carote", "pomodoro", "pomodori",
    "melanzana", "melanzane", "finocchio", "finocchi", "broccolo", "broccoli",
    "aglio", "basilico", "rucola", "lattuga", "spinaci",
  ]);
  if (produceLexicon.has(value)) {
    return "produce";
  }
  if (/^(limon|zucchin|porr|sedan|prezzemol|cipoll|patat|carot|pomodor|melanzan|finocch|broccol|agli|basilic)/i.test(value)) {
    return "produce";
  }
  return "basic";
}

interface HierarchyHints {
  semanticCategory: string | null;
  parentCandidateSlug: string | null;
  parentCandidateReason: string | null;
  variantKind: string | null;
  specificityRankSuggestion: number | null;
  semanticStrength: "none" | "medium" | "high";
  parentExists: boolean;
}

async function inferHierarchyHints(normalizedText: string): Promise<HierarchyHints> {
  const text = normalizeText(normalizedText).toLowerCase();
  const fallback: HierarchyHints = {
    semanticCategory: null,
    parentCandidateSlug: null,
    parentCandidateReason: null,
    variantKind: null,
    specificityRankSuggestion: null,
    semanticStrength: "none",
    parentExists: false,
  };

  if (!text) return fallback;

  let semanticCategory: string | null = null;
  let parentCandidateSlug: string | null = null;
  let parentCandidateReason: string | null = null;
  let variantKind: string | null = null;
  let specificityRankSuggestion: number | null = null;
  let semanticStrength: "none" | "medium" | "high" = "none";

  if (isPastaShapeText(text)) {
    semanticCategory = "pasta";
    parentCandidateSlug = "pasta";
    parentCandidateReason = "shape_or_style_under_pasta_family";
    variantKind = "shape";
    specificityRankSuggestion = 1;
    semanticStrength = "high";
  } else if (/\bcipolla\s+(rossa|dorata|bianca)\b/i.test(text)) {
    semanticCategory = "vegetable";
    parentCandidateSlug = "cipolla";
    parentCandidateReason = "color_variant_under_cipolla_family";
    variantKind = "variety";
    specificityRankSuggestion = 1;
    semanticStrength = "high";
  } else if (/\b(parmigiano|pecorino|grana|gorgonzola)\b/i.test(text)) {
    semanticCategory = "cheese";
    parentCandidateSlug = "formaggio";
    parentCandidateReason = "likely_cheese_variant";
    variantKind = "designation";
    specificityRankSuggestion = 1;
    semanticStrength = "medium";
  }

  const parentExists = parentCandidateSlug ? await catalogSlugExists(parentCandidateSlug) : false;
  if (parentCandidateSlug && !parentExists) {
    parentCandidateReason = `${parentCandidateReason ?? "semantic_parent_candidate"}_parent_not_found`;
    if (semanticStrength === "high") semanticStrength = "medium";
  }

  return {
    semanticCategory,
    parentCandidateSlug: parentExists ? parentCandidateSlug : null,
    parentCandidateReason: parentExists ? parentCandidateReason : null,
    variantKind: parentExists ? variantKind : null,
    specificityRankSuggestion: parentExists ? specificityRankSuggestion : null,
    semanticStrength,
    parentExists,
  };
}

async function catalogSlugExists(slug: string): Promise<boolean> {
  if (!slug || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return false;
  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await client
    .from("ingredients")
    .select("id")
    .eq("slug", slug)
    .limit(1)
    .maybeSingle();

  if (error) {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=hierarchy_lookup_failed slug=${slug} error=${error.message}`);
    return false;
  }
  return !!(data && (data as Record<string, unknown>).id);
}

function isPastaShapeText(value: string): boolean {
  return /\b(fusilli|penne(\s+rigate)?|pappardelle(([\s_]+all['_\s]?uovo))?|rigatoni|spaghett(i|oni)|conchiglioni|orecchiette|trofie|paccheri|tagliatelle)\b/i
    .test(value);
}

function extractProviderOutputText(payload: unknown): string {
  if (!isRecord(payload)) return "";

  if (typeof payload.output_text === "string" && payload.output_text.trim().length > 0) {
    return payload.output_text.trim();
  }

  const output = payload.output;
  if (!Array.isArray(output)) return "";

  for (const item of output) {
    if (!isRecord(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (!isRecord(content)) continue;
      if (typeof content.text === "string" && content.text.trim().length > 0) {
        return content.text.trim();
      }
      if (typeof content.output_text === "string" && content.output_text.trim().length > 0) {
        return content.output_text.trim();
      }
    }
  }

  return "";
}

function safeParseJSON(raw: string): unknown | null {
  const trimmed = raw.trim();
  const fenced = trimmed
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();

  try {
    return JSON.parse(fenced);
  } catch {
    return null;
  }
}

function normalizedIngredientType(
  proposedType: CatalogEnrichmentProposal["ingredient_type"],
  normalizedText: string,
): CatalogEnrichmentProposal["ingredient_type"] {
  const text = normalizeText(normalizedText).toLowerCase();
  if (proposedType === "produce" && isSeafoodShellfishTerm(text)) {
    console.log(
      `[SEASON_CATALOG_ENRICHMENT] phase=ingredient_type_override reason=seafood_shellfish normalized_text=${text} from=produce to=basic`,
    );
    return "basic";
  }
  if (proposedType === "produce" && isNarrowPlantDerivedPreservedBasicCandidate(text)) {
    console.log(
      `[SEASON_CATALOG_ENRICHMENT] phase=ingredient_type_override reason=plant_derived_preserved_condiment normalized_text=${text} from=produce to=basic`,
    );
    return "basic";
  }
  return proposedType;
}

function isSeafoodShellfishTerm(value: string): boolean {
  if (!value) return false;

  return /\b(vongol[ae]|cozz[ae]|calamar[io]|scamp[io]|seppi[ae]|gamber[io]|canocchi[ea]|astice|aragosta|frutti di mare|mollusch[io])\b/i
    .test(value);
}

function isNarrowPlantDerivedPreservedBasicCandidate(value: string): boolean {
  if (!value) return false;
  return /\bcapperi\b.*\b(sotto\s+sale|sott['’]?olio)\b/i.test(value);
}

function normalizeText(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim();
}

function normalizeIngredientIdentityInput(normalizedText: string): NormalizedIdentityInput {
  let cleaned = normalizeText(normalizedText);
  const removedQualifiers = new Set<string>();

  const apply = (pattern: RegExp, qualifier: string) => {
    if (pattern.test(cleaned)) {
      removedQualifiers.add(qualifier);
      cleaned = cleaned.replace(pattern, " ");
    }
  };

  apply(/\([^)]*\)/g, "parentheses_content");
  apply(/\b(circa|ca\.?)\s*\d+(?:[.,]\d+)?\b/gi, "approx_quantity");
  apply(/\b\d+\s*\/\s*\d+\s*bicchier[ei]\b/gi, "count_quantity");
  apply(/\bmezzo\s+bicchier[ei]\b/gi, "count_quantity");
  apply(/\b\d+\s*\/\s*\d+\b/g, "fraction_quantity");
  apply(/\b\d+(?:[.,]\d+)?\s*(?:g|gr|grammi?|kg|ml|cl|l|litri?)\b/gi, "weight_or_volume_quantity");
  apply(/\b\d+(?:[.,]\d+)?\s*(?:pizzic[oi]|mazzett[oi]|ciuff[oi]|cost[ae]|fogli[ae]|spicch[iio]|cucchiai?|cucchiain[iio]|pezzi?)\b/gi, "count_quantity");
  apply(/\b(a temperatura ambiente|freddo di frigo|freddo dal frigo|freddo di frigorifero|freddo da frigo)\b/gi, "temperature_or_state_phrase");
  apply(/\b(da pulire|da grattugiare|da tritare|da tagliare|da usare|da servire)\b/gi, "usage_phrase");
  apply(/\b(per decorare|per servire|per spolverizzare|per ungere)\b/gi, "usage_phrase");
  apply(/\bsgocciolat\w*\b/gi, "post_preparation_qualifier");
  apply(/\b\d+\b$/g, "trailing_number");

  cleaned = cleaned
    .replace(/[.,;:]+$/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();

  return {
    cleanedText: cleaned || normalizedText,
    removedQualifiers: Array.from(removedQualifiers),
  };
}

function dedupeStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const output: string[] = [];
  for (const value of values) {
    const normalized = normalizeText(value).toLowerCase();
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    output.push(normalized);
  }
  return output;
}

function cleanNullableString(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toSnakeCase(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_{2,}/g, "_") || "unknown_ingredient";
}

function toTitleCase(value: string): string {
  return value
    .split(/\s+/)
    .filter(Boolean)
    .map((token) => token.charAt(0).toUpperCase() + token.slice(1))
    .join(" ");
}

function dedupeUnits(units: string[]): string[] {
  const unique = new Set<string>();
  for (const raw of units) {
    const cleaned = raw.trim();
    if (cleaned) unique.add(cleaned);
  }
  return Array.from(unique);
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function extractBearerToken(authHeader: string): string | null {
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const token = match[1]?.trim();
  return token ? token : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function errorJson(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ ok: false, error: { code, message } }),
    {
      status,
      headers: JSON_HEADERS,
    },
  );
}

function json(payload: CatalogEnrichmentProposal): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: JSON_HEADERS,
  });
}
