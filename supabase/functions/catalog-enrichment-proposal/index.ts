import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  CATALOG_ENRICHMENT_SYSTEM_PROMPT,
  type CatalogEnrichmentProposal,
  validateCatalogEnrichmentProposal,
} from "./llm_contract.ts";
import { resolveCatalogAdminOrServiceRole } from "../_shared/auth.ts";
import {
  env,
  jsonResponse,
  jsonResponseWithStatus,
  numberEnv,
} from "../_shared/edge.ts";
import {
  extractTokenUsage,
  logLLMUsage,
  requestIdFromHeaders,
  type TokenUsage,
} from "../_shared/observability.ts";
import { estimateUsageCost, recordAIUsageEvent } from "../_shared/ai_usage.ts";

interface CatalogEnrichmentRequest {
  normalized_text?: string;
  original_text?: string;
  cleaned_text?: string;
  removed_qualifiers?: string[];
  agent_run_id?: number | null;
  agent_worker_job_id?: number | null;
}

interface NormalizedIdentityInput {
  cleanedText: string;
  removedQualifiers: string[];
}

interface ProviderInvocationResult {
  parsed: unknown;
  durationMs: number;
  usage: TokenUsage;
}

interface ExternalEvidencePromptContext {
  evidenceLines: string[];
  parentHints: string[];
}

class ProviderInvocationError extends Error {
  readonly durationMs: number;

  constructor(message: string, durationMs: number) {
    super(message);
    this.durationMs = durationMs;
    this.name = "ProviderInvocationError";
  }
}

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const OPENAI_API_KEY = env("OPENAI_API_KEY");
const OPENAI_API_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-5.4-mini";
const PROVIDER_TIMEOUT_MS = numberEnv("CATALOG_ENRICHMENT_PROVIDER_TIMEOUT_MS", 15000);
const INPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_ENRICHMENT_INPUT_COST_PER_1M_USD");
const OUTPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_ENRICHMENT_OUTPUT_COST_PER_1M_USD");
const MAX_NORMALIZED_TEXT_LENGTH = 120;

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  try {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=request_received method=${request.method} request_id=${requestId}`);

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

    const auth = await resolveCatalogAdminOrServiceRole(request, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
      supabaseServiceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      logPrefix: "SEASON_CATALOG_ENRICHMENT",
    });
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHORIZED", "Catalog admin authentication is required.");
    }

    let payload: CatalogEnrichmentRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }
    const agentRunId = positiveIntegerOrNull(payload.agent_run_id);
    const agentWorkerJobId = positiveIntegerOrNull(payload.agent_worker_job_id);

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
      `[SEASON_CATALOG_ENRICHMENT] phase=identity_input request_id=${requestId} original_length=${originalText.length} cleaned_length=${cleanedText.length} removed_qualifier_count=${removedQualifiers.length}`,
    );

    const externalEvidence = await fetchExternalEvidencePromptContext(cleanedText);

    if (!OPENAI_API_KEY) {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_not_configured fallback=true");
      logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
        functionName: "catalog-enrichment-proposal",
        requestId,
        status: "fallback",
        providerDurationMs: null,
        model: OPENAI_MODEL,
        reason: "provider_not_configured",
      });
      await recordAIUsageEvent({
        supabaseUrl: SUPABASE_URL,
        serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
        functionName: "catalog-enrichment-proposal",
        requestId,
        agentRunId,
        workerJobId: agentWorkerJobId,
        model: OPENAI_MODEL,
        status: "fallback",
        reason: "provider_not_configured",
        metadata: usageMetadata(cleanedText, externalEvidence),
      });
      return json(buildFallbackProposal(cleanedText));
    }

    try {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_call_start");
      const providerResult = await invokeProvider(cleanedText, originalText, externalEvidence);
      const validation = validateCatalogEnrichmentProposal(providerResult.parsed);

      if (!validation.ok || !validation.value) {
        console.log(
          `[SEASON_CATALOG_ENRICHMENT] phase=validator_failed fallback=true errors=${validation.errors.join(" | ")}`,
        );
        logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
          functionName: "catalog-enrichment-proposal",
          requestId,
          status: "fallback",
          providerDurationMs: providerResult.durationMs,
          model: OPENAI_MODEL,
          inputTokens: providerResult.usage.inputTokens,
          outputTokens: providerResult.usage.outputTokens,
          totalTokens: providerResult.usage.totalTokens,
          reason: "validator_failed",
        });
        await recordAIUsageEvent({
          supabaseUrl: SUPABASE_URL,
          serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
          functionName: "catalog-enrichment-proposal",
          requestId,
          agentRunId,
          workerJobId: agentWorkerJobId,
          model: OPENAI_MODEL,
          status: "fallback",
          providerDurationMs: providerResult.durationMs,
          usage: providerResult.usage,
          estimatedCostUsd: estimateUsageCost(providerResult.usage, INPUT_COST_PER_1M_USD, OUTPUT_COST_PER_1M_USD),
          reason: "validator_failed",
          metadata: usageMetadata(cleanedText, externalEvidence, { validation_errors: validation.errors }),
        });
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
          `[SEASON_CATALOG_ENRICHMENT] phase=deterministic_fallback_used request_id=${requestId} reason=low_confidence_or_unknown_provider_output inferred_type=${deterministicFallback.ingredient_type}`,
        );
        logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
          functionName: "catalog-enrichment-proposal",
          requestId,
          status: "fallback",
          providerDurationMs: providerResult.durationMs,
          model: OPENAI_MODEL,
          inputTokens: providerResult.usage.inputTokens,
          outputTokens: providerResult.usage.outputTokens,
          totalTokens: providerResult.usage.totalTokens,
          reason: "low_confidence_or_unknown_provider_output",
        });
        await recordAIUsageEvent({
          supabaseUrl: SUPABASE_URL,
          serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
          functionName: "catalog-enrichment-proposal",
          requestId,
          agentRunId,
          workerJobId: agentWorkerJobId,
          model: OPENAI_MODEL,
          status: "fallback",
          providerDurationMs: providerResult.durationMs,
          usage: providerResult.usage,
          estimatedCostUsd: estimateUsageCost(providerResult.usage, INPUT_COST_PER_1M_USD, OUTPUT_COST_PER_1M_USD),
          reason: "low_confidence_or_unknown_provider_output",
          metadata: usageMetadata(cleanedText, externalEvidence),
        });
        return json(deterministicFallback);
      }
      logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
        functionName: "catalog-enrichment-proposal",
        requestId,
        status: "success",
        providerDurationMs: providerResult.durationMs,
        model: OPENAI_MODEL,
        inputTokens: providerResult.usage.inputTokens,
        outputTokens: providerResult.usage.outputTokens,
        totalTokens: providerResult.usage.totalTokens,
      });
      await recordAIUsageEvent({
        supabaseUrl: SUPABASE_URL,
        serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
        functionName: "catalog-enrichment-proposal",
        requestId,
        agentRunId,
        workerJobId: agentWorkerJobId,
        model: OPENAI_MODEL,
        status: "success",
        providerDurationMs: providerResult.durationMs,
        usage: providerResult.usage,
        estimatedCostUsd: estimateUsageCost(providerResult.usage, INPUT_COST_PER_1M_USD, OUTPUT_COST_PER_1M_USD),
        metadata: usageMetadata(cleanedText, externalEvidence),
      });
      return json(proposal);
    } catch (error) {
      console.log(`[SEASON_CATALOG_ENRICHMENT] phase=provider_failed fallback=true error=${String(error)}`);
      const providerDurationMs = error instanceof ProviderInvocationError ? error.durationMs : null;
      logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
        functionName: "catalog-enrichment-proposal",
        requestId,
        status: "error",
        providerDurationMs,
        model: OPENAI_MODEL,
        reason: "provider_failed",
      });
      await recordAIUsageEvent({
        supabaseUrl: SUPABASE_URL,
        serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
        functionName: "catalog-enrichment-proposal",
        requestId,
        agentRunId,
        workerJobId: agentWorkerJobId,
        model: OPENAI_MODEL,
        status: "error",
        providerDurationMs,
        reason: "provider_failed",
        metadata: usageMetadata(cleanedText, externalEvidence),
      });
      return json(buildFallbackProposal(cleanedText));
    }
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=unhandled_error error=${String(error)}`);
    logLLMUsage("SEASON_CATALOG_ENRICHMENT", {
      functionName: "catalog-enrichment-proposal",
      requestId,
      status: "error",
      model: OPENAI_MODEL,
      reason: "unhandled_error",
    });
    return json(buildFallbackProposal(""));
  }
});

function nonNegativeNumberEnv(name: string): number | null {
  const raw = Deno.env.get(name);
  if (raw === undefined || raw.trim().length === 0) return null;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return parsed;
}

function positiveIntegerOrNull(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) return null;
  return parsed;
}

async function invokeProvider(
  cleanedText: string,
  originalText: string,
  externalEvidence: ExternalEvidencePromptContext,
): Promise<ProviderInvocationResult> {
  const userPrompt = [
    "Generate a catalog enrichment proposal for this unresolved ingredient candidate.",
    "Return strict JSON only.",
    `normalized_text: ${cleanedText}`,
    `original_text: ${originalText}`,
    ...formatExternalEvidencePromptLines(externalEvidence),
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
  const startedAt = performance.now();

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
    const usage = extractTokenUsage(providerJSON);
    const outputText = extractProviderOutputText(providerJSON);
    if (!outputText) {
      throw new Error("provider_missing_output_text");
    }

    const parsed = safeParseJSON(outputText);
    if (!parsed) {
      throw new Error("provider_invalid_json_output");
    }

    return {
      parsed,
      durationMs: elapsedMs(startedAt),
      usage,
    };
  } catch (error) {
    throw new ProviderInvocationError(String(error), elapsedMs(startedAt));
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchExternalEvidencePromptContext(cleanedText: string): Promise<ExternalEvidencePromptContext> {
  const fallback: ExternalEvidencePromptContext = { evidenceLines: [], parentHints: [] };
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return fallback;

  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await client.rpc("get_catalog_agent_external_evidence_context", {
    p_normalized_texts: [cleanedText],
    p_limit_per_term: 3,
  });

  if (error) {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=external_evidence_lookup_failed term=${cleanedText} error=${error.message}`);
    return fallback;
  }

  const context = isRecord(data) ? data : {};
  const termEvidence = isRecord(context.term_external_evidence)
    ? context.term_external_evidence[cleanedText]
    : null;
  if (!Array.isArray(termEvidence)) return fallback;

  const evidenceLines = termEvidence
    .filter((entry) => isRecord(entry))
    .slice(0, 3)
    .map((entry) => formatEvidenceLine(entry as Record<string, unknown>))
    .filter((line) => line.length > 0);

  return {
    evidenceLines,
    parentHints: deriveParentHints(termEvidence.filter((entry) => isRecord(entry)) as Record<string, unknown>[]),
  };
}

function formatEvidenceLine(entry: Record<string, unknown>): string {
  const status = normalizeText(entry.status) ?? "unknown";
  const trust = normalizeText(entry.trust_level) ?? "unknown";
  const evidenceType = normalizeText(entry.evidence_type) ?? "unknown";
  const label = normalizeText(entry.canonical_label) ?? "unknown label";
  const summary = String(entry.evidence_summary ?? "").replace(/\s+/g, " ").trim();
  const confidence = entry.confidence_score === null || entry.confidence_score === undefined
    ? "unknown"
    : String(entry.confidence_score);
  return [
    `status=${status}`,
    `trust=${trust}`,
    `type=${evidenceType}`,
    `confidence=${confidence}`,
    `label=${label}`,
    summary ? `summary=${summary.slice(0, 420)}` : null,
  ].filter(Boolean).join("; ");
}

function deriveParentHints(entries: Record<string, unknown>[]): string[] {
  const hints = new Set<string>();
  for (const entry of entries) {
    const metadata = isRecord(entry.metadata) ? entry.metadata : {};
    const sourceCategory = normalizeText(metadata.source_category);
    if (sourceCategory === "formaggi_e_latticini") {
      hints.add("Italian cheese/dairy evidence can support semantic_category=cheese and parent_candidate_slug=formaggio when the ingredient is a named cheese; if setting that parent, also set variant_kind=product_type and specificity_rank_suggestion>=1.");
    }
    if (sourceCategory === "cereali_e_derivati") {
      hints.add("Italian cereal-derivative evidence can support semantic_category=cereal_product and a specific product-form identity rather than a generic grain collapse.");
    }
  }
  return Array.from(hints);
}

function formatExternalEvidencePromptLines(context: ExternalEvidencePromptContext): string[] {
  if (context.evidenceLines.length === 0 && context.parentHints.length === 0) return [];
  return [
    "external_catalog_evidence_policy: grounding-only; useful for identity/category/parent hints, never catalog truth by itself.",
    ...context.parentHints.map((hint) => `external_parent_hint: ${hint}`),
    ...context.evidenceLines.map((line, index) => `external_evidence_${index + 1}: ${line}`),
  ];
}

function usageMetadata(
  cleanedText: string,
  context: ExternalEvidencePromptContext,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    normalized_text: cleanedText,
    external_evidence_count: context.evidenceLines.length,
    external_parent_hint_count: context.parentHints.length,
    ...extra,
  };
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
      `[SEASON_CATALOG_ENRICHMENT] phase=ingredient_type_override reason=seafood_shellfish text_length=${text.length} from=produce to=basic`,
    );
    return "basic";
  }
  if (proposedType === "produce" && isNarrowPlantDerivedPreservedBasicCandidate(text)) {
    console.log(
      `[SEASON_CATALOG_ENRICHMENT] phase=ingredient_type_override reason=plant_derived_preserved_condiment text_length=${text.length} from=produce to=basic`,
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

function elapsedMs(startedAt: number): number {
  return Math.max(0, Math.round(performance.now() - startedAt));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function errorJson(status: number, code: string, message: string): Response {
  return jsonResponse({ ok: false, error: { code, message } }, { status });
}

function json(payload: CatalogEnrichmentProposal): Response {
  return jsonResponseWithStatus(payload, 200);
}
