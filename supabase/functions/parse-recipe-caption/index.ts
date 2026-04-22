import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  INGREDIENT_RESOLUTION_LLM_SYSTEM_PROMPT,
  RECIPE_IMPORT_LLM_SYSTEM_PROMPT,
  validateLLMIngredientResolutionOutput,
  validateLLMRecipeImportOutput,
} from "./llm_contract.ts";
import {
  extractTokenUsage,
  logLLMUsage,
  requestIdFromHeaders,
  type TokenUsage,
} from "../_shared/observability.ts";

interface ParseRecipeCaptionRequest {
  caption?: string;
  url?: string;
  languageCode?: string;
  ingredientCandidates?: PreparsedIngredientCandidate[];
}

type SmartImportMatchType = "exact" | "alias" | "ambiguous" | "none";
type SmartImportStatus = "resolved" | "inferred" | "unknown";

interface PreparsedIngredientCandidate {
  raw_text?: string;
  normalized_text?: string;
  possible_quantity?: number | null;
  possible_unit?: string | null;
  catalog_match?: {
    matchType?: SmartImportMatchType;
    match_type?: SmartImportMatchType;
    matchedIngredientId?: string | null;
    matched_ingredient_id?: string | null;
    confidence?: number | null;
  };
}

type ImportConfidence = "high" | "medium" | "low";

interface ParsedIngredient {
  name: string;
  quantity: number | null;
  unit: string | null;
  status?: SmartImportStatus;
  confidence?: number;
  matchType?: SmartImportMatchType;
  matchedIngredientId?: string | null;
}

interface ParseRecipeCaptionResponse {
  ok: boolean;
  result?: {
    title: string | null;
    ingredients: ParsedIngredient[];
    steps: string[];
    prepTimeMinutes: number | null;
    cookTimeMinutes: number | null;
    servings: number | null;
    confidence: ImportConfidence;
    inferredDish: string | null;
  };
  error?: {
    code: string;
    message: string;
  };
  meta?: {
    languageCode?: string;
    usedServerLLM: boolean;
    userId?: string;
    dayBucket?: string;
    remainingToday?: number;
    retryAfterSeconds?: number;
    smart_import_audit?: SmartImportAuditResponse;
  };
}

type ParseRecipeCaptionResult = NonNullable<ParseRecipeCaptionResponse["result"]>;

interface SmartImportAuditResponse {
  total_candidates: number;
  resolved_locally: number;
  sent_to_llm: number;
  final_unknown: number;
}

interface ProviderInvocationResult {
  parsed: unknown;
  durationMs: number;
  usage: TokenUsage;
}

class ProviderInvocationError extends Error {
  readonly durationMs: number;

  constructor(message: string, durationMs: number) {
    super(message);
    this.durationMs = durationMs;
    this.name = "ProviderInvocationError";
  }
}

const MAX_CAPTION_LENGTH = 12_000;
const MAX_PREPARSED_INGREDIENT_CANDIDATES = 40;
const DEFAULT_LANGUAGE_CODE = "en";
const DAILY_IMPORT_LIMIT = Number(Deno.env.get("PARSE_RECIPE_DAILY_LIMIT") ?? "20");
const MIN_COOLDOWN_SECONDS = Number(Deno.env.get("PARSE_RECIPE_MIN_COOLDOWN_SECONDS") ?? "2");
const PROVIDER_TIMEOUT_MS = Number(Deno.env.get("PARSE_RECIPE_PROVIDER_TIMEOUT_MS") ?? "20000");

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_API_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-5.4-mini";

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  try {
    console.log(`[SEASON_IMPORT_EDGE] phase=request_received method=${request.method} request_id=${requestId}`);

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

    const authHeader = request.headers.get("Authorization");
    const hasAuthHeader = !!authHeader;
    console.log(`[SEASON_IMPORT_EDGE] phase=auth_header_present value=${hasAuthHeader}`);
    if (!authHeader) {
      return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
    }
    const jwt = extractBearerToken(authHeader);
    if (!jwt) {
      console.log("[SEASON_IMPORT_EDGE] phase=jwt_invalid");
      return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: authData, error: authError } = await supabase.auth.getUser(jwt);
    const userID = authData.user?.id;
    if (authError || !userID) {
      console.log("[SEASON_IMPORT_EDGE] phase=jwt_invalid");
      return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
    }
    console.log("[SEASON_IMPORT_EDGE] phase=jwt_valid");
    console.log(`[SEASON_IMPORT_EDGE] phase=auth_resolved user_id=${userID}`);

    let payload: ParseRecipeCaptionRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const caption = normalizeText(payload.caption);
    const url = normalizeText(payload.url);
    const languageCode = normalizeLanguageCode(payload.languageCode);

    if (!caption && !url) {
      return errorJson(422, "EMPTY_INPUT", "Provide at least one of: caption or url.");
    }

    if (caption.length > MAX_CAPTION_LENGTH) {
      return errorJson(422, "CAPTION_TOO_LONG", `Caption exceeds max length (${MAX_CAPTION_LENGTH}).`);
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const dayBucket = new Date().toISOString().slice(0, 10);
    const quotaResult = await adminClient.rpc("consume_recipe_import_quota", {
      p_user_id: userID,
      p_day_bucket: dayBucket,
      p_daily_limit: DAILY_IMPORT_LIMIT,
      p_cooldown_seconds: MIN_COOLDOWN_SECONDS,
    });

    if (quotaResult.error || !Array.isArray(quotaResult.data) || quotaResult.data.length === 0) {
      console.log(`[SEASON_IMPORT_EDGE] phase=quota_failed user_id=${userID}`);
      return errorJson(500, "RATE_LIMIT_CHECK_FAILED", "Could not validate usage quota.");
    }

    const quota = quotaResult.data[0] as {
      allowed: boolean;
      reason: string;
      current_count: number;
      limit_count: number;
      retry_after_seconds: number;
    };

    if (!quota.allowed) {
      const code = quota.reason === "cooldown" ? "TOO_FREQUENT_REQUESTS" : "RATE_LIMIT_EXCEEDED";
      const message = quota.reason === "cooldown"
        ? "Please wait before sending another import request."
        : "Daily import limit reached.";

      return json(
        {
          ok: false,
          error: { code, message },
          meta: {
            usedServerLLM: false,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
            retryAfterSeconds: quota.retry_after_seconds,
          },
        },
        429,
      );
    }
    console.log(`[SEASON_IMPORT_EDGE] phase=quota_passed user_id=${userID}`);

    const smartImportCandidates = normalizedPreparsedIngredientCandidates(payload.ingredientCandidates);
    if (smartImportCandidates.length > 0) {
      const targetedCandidates = smartImportCandidates.filter(candidateNeedsLLM);
      const smartImportAudit = computeSmartImportAudit(smartImportCandidates);
      console.log(
        `[SEASON_IMPORT_EDGE] phase=smart_import_decision request_id=${requestId} candidates=${smartImportCandidates.length} targeted_llm_candidates=${targetedCandidates.length}`,
      );
      console.log(
        `[SEASON_SMART_IMPORT_AUDIT] phase=edge_input request_id=${requestId} total=${smartImportAudit.total} resolved=${smartImportAudit.resolved} ambiguous=${smartImportAudit.ambiguous} none=${smartImportAudit.none} sent_to_llm=${smartImportAudit.sentToLLM}`,
      );

      if (targetedCandidates.length === 0) {
        const mappedResult = buildSmartImportResult({
          caption,
          url,
          languageCode,
          candidates: smartImportCandidates,
          llmResolvedByIndex: new Map(),
        });
        const outputAudit = computeSmartImportOutputAudit(mappedResult.ingredients);
        console.log(
          `[SEASON_SMART_IMPORT_AUDIT] phase=edge_output request_id=${requestId} resolved_final=${outputAudit.resolvedFinal} inferred=${outputAudit.inferred} unknown=${outputAudit.unknown} llm_used=false`,
        );
        console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${mappedResult.ingredients.length} steps=${mappedResult.steps.length} confidence=${mappedResult.confidence} smart_import=true used_llm=false`);
        return json(
          {
            ok: true,
            result: mappedResult,
            meta: {
              languageCode,
              usedServerLLM: false,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
              smart_import_audit: buildSmartImportAuditResponse(smartImportAudit, outputAudit),
            },
          },
          200,
        );
      }

      if (!OPENAI_API_KEY) {
        console.log(`[SEASON_IMPORT_EDGE] phase=provider_not_configured request_id=${requestId}`);
        logLLMUsage("SEASON_IMPORT_EDGE", {
          functionName: "parse-recipe-caption",
          requestId,
          status: "error",
          providerDurationMs: null,
          model: OPENAI_MODEL,
          reason: "provider_not_configured",
        });
        return json(
          {
            ok: false,
            error: {
              code: "PROVIDER_NOT_CONFIGURED",
              message: "LLM provider key is not configured on the server.",
            },
            meta: {
              usedServerLLM: false,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
            },
          },
          500,
        );
      }

      console.log(`[SEASON_IMPORT_EDGE] phase=targeted_provider_call_start request_id=${requestId} candidates=${targetedCandidates.length}`);
      try {
        const providerResult = await invokeProviderForIngredientResolution({
          candidates: targetedCandidates,
          languageCode,
        });
        const validation = validateLLMIngredientResolutionOutput(providerResult.parsed);

        if (!validation.ok || !validation.value) {
          console.log(`[SEASON_IMPORT_EDGE] phase=targeted_validator_failed request_id=${requestId} error_count=${validation.errors.length}`);
          logLLMUsage("SEASON_IMPORT_EDGE", {
            functionName: "parse-recipe-caption",
            requestId,
            status: "error",
            providerDurationMs: providerResult.durationMs,
            model: OPENAI_MODEL,
            inputTokens: providerResult.usage.inputTokens,
            outputTokens: providerResult.usage.outputTokens,
            totalTokens: providerResult.usage.totalTokens,
            reason: "targeted_validator_failed",
          });
          return json(
            {
              ok: false,
              error: {
                code: "VALIDATION_FAILED",
                message: "Provider response did not match expected schema.",
              },
              meta: {
                usedServerLLM: true,
                userId: userID,
                dayBucket,
                remainingToday: Math.max(0, quota.limit_count - quota.current_count),
              },
            },
            502,
          );
        }

        logLLMUsage("SEASON_IMPORT_EDGE", {
          functionName: "parse-recipe-caption",
          requestId,
          status: "success",
          providerDurationMs: providerResult.durationMs,
          model: OPENAI_MODEL,
          inputTokens: providerResult.usage.inputTokens,
          outputTokens: providerResult.usage.outputTokens,
          totalTokens: providerResult.usage.totalTokens,
          reason: "targeted_ingredient_resolution",
        });

        const mappedResult = buildSmartImportResult({
          caption,
          url,
          languageCode,
          candidates: smartImportCandidates,
          llmResolvedByIndex: llmResolutionMap(validation.value.ingredients),
        });
        const outputAudit = computeSmartImportOutputAudit(mappedResult.ingredients);
        console.log(
          `[SEASON_SMART_IMPORT_AUDIT] phase=edge_output request_id=${requestId} resolved_final=${outputAudit.resolvedFinal} inferred=${outputAudit.inferred} unknown=${outputAudit.unknown} llm_used=true`,
        );
        console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${mappedResult.ingredients.length} steps=${mappedResult.steps.length} confidence=${mappedResult.confidence} smart_import=true used_llm=true`);
        return json(
          {
            ok: true,
            result: mappedResult,
            meta: {
              languageCode,
              usedServerLLM: true,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
              smart_import_audit: buildSmartImportAuditResponse(smartImportAudit, outputAudit),
            },
          },
          200,
        );
      } catch (error) {
        console.log(`[SEASON_IMPORT_EDGE] phase=targeted_provider_error request_id=${requestId} error=${String(error)}`);
        const providerDurationMs = error instanceof ProviderInvocationError ? error.durationMs : null;
        logLLMUsage("SEASON_IMPORT_EDGE", {
          functionName: "parse-recipe-caption",
          requestId,
          status: "error",
          providerDurationMs,
          model: OPENAI_MODEL,
          reason: "targeted_provider_request_failed",
        });
        return json(
          {
            ok: false,
            error: {
              code: "PROVIDER_REQUEST_FAILED",
              message: "Provider request failed.",
            },
            meta: {
              usedServerLLM: true,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
            },
          },
          502,
        );
      }
    }

    console.log(`[SEASON_IMPORT_EDGE] phase=provider_key_present value=${OPENAI_API_KEY.length > 0}`);
    if (!OPENAI_API_KEY) {
      console.log(`[SEASON_IMPORT_EDGE] phase=provider_not_configured request_id=${requestId}`);
      logLLMUsage("SEASON_IMPORT_EDGE", {
        functionName: "parse-recipe-caption",
        requestId,
        status: "error",
        providerDurationMs: null,
        model: OPENAI_MODEL,
        reason: "provider_not_configured",
      });
      return json(
      {
        ok: false,
          error: {
            code: "PROVIDER_NOT_CONFIGURED",
            message: "LLM provider key is not configured on the server.",
          },
          meta: {
            usedServerLLM: false,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          },
        },
        500,
      );
    }

    console.log(`[SEASON_IMPORT_EDGE] phase=provider_call_start request_id=${requestId}`);

    try {
      const providerResult = await invokeProviderForRecipeParse({ caption, url, languageCode });
      console.log(`[SEASON_IMPORT_EDGE] phase=provider_call_success request_id=${requestId}`);

      const validation = validateLLMRecipeImportOutput(providerResult.parsed);

      if (!validation.ok || !validation.value) {
        console.log(`[SEASON_IMPORT_EDGE] phase=validator_failed request_id=${requestId} error_count=${validation.errors.length}`);
        logLLMUsage("SEASON_IMPORT_EDGE", {
          functionName: "parse-recipe-caption",
          requestId,
          status: "error",
          providerDurationMs: providerResult.durationMs,
          model: OPENAI_MODEL,
          inputTokens: providerResult.usage.inputTokens,
          outputTokens: providerResult.usage.outputTokens,
          totalTokens: providerResult.usage.totalTokens,
          reason: "validator_failed",
        });
        return json(
          {
            ok: false,
            error: {
              code: "VALIDATION_FAILED",
              message: "Provider response did not match expected schema.",
            },
            meta: {
              usedServerLLM: true,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
            },
          },
          502,
        );
      }
      console.log(`[SEASON_IMPORT_EDGE] phase=validator_success request_id=${requestId}`);
      logLLMUsage("SEASON_IMPORT_EDGE", {
        functionName: "parse-recipe-caption",
        requestId,
        status: "success",
        providerDurationMs: providerResult.durationMs,
        model: OPENAI_MODEL,
        inputTokens: providerResult.usage.inputTokens,
        outputTokens: providerResult.usage.outputTokens,
        totalTokens: providerResult.usage.totalTokens,
      });

      const mappedResult: ParseRecipeCaptionResult = {
        title: validation.value.title.trim() ? validation.value.title : null,
        ingredients: validation.value.ingredients.map((item) => {
          const normalized = recoverExplicitMeasuredIngredient({
            name: item.name.trim(),
            quantity: item.quantity,
            unit: item.unit,
          });
          if (normalized.quantity !== null && normalized.unit !== null) {
            console.log(
              `[SEASON_IMPORT_EDGE] phase=final_quantity_preserved name_length=${normalized.name.length} quantity=${normalized.quantity} unit=${normalized.unit}`,
            );
          }
          return normalized;
        }),
        steps: validation.value.steps.map((step) => step.trim()).filter(Boolean),
        prepTimeMinutes: validation.value.prepTimeMinutes,
        cookTimeMinutes: validation.value.cookTimeMinutes,
        servings: validation.value.servings,
        confidence: validation.value.confidence,
        inferredDish: null,
      };

      console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${mappedResult.ingredients.length} steps=${mappedResult.steps.length} confidence=${mappedResult.confidence}`);
      return json(
        {
          ok: true,
          result: mappedResult,
          meta: {
            languageCode,
            usedServerLLM: true,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          },
        },
        200,
      );
    } catch (error) {
      console.log(`[SEASON_IMPORT_EDGE] phase=provider_or_validation_error request_id=${requestId} error=${String(error)}`);
      const providerDurationMs = error instanceof ProviderInvocationError ? error.durationMs : null;
      logLLMUsage("SEASON_IMPORT_EDGE", {
        functionName: "parse-recipe-caption",
        requestId,
        status: "error",
        providerDurationMs,
        model: OPENAI_MODEL,
        reason: "provider_request_failed",
      });
      return json(
        {
          ok: false,
          error: {
            code: "PROVIDER_REQUEST_FAILED",
            message: "Provider request failed.",
          },
          meta: {
            usedServerLLM: true,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          },
        },
        502,
      );
    }
  } catch (error) {
    console.log(`[SEASON_IMPORT_EDGE] phase=unhandled_error error=${String(error)}`);
    return errorJson(500, "INTERNAL_ERROR", "Unexpected server error.");
  }
});

interface NormalizedIngredientCandidate {
  index: number;
  rawText: string;
  normalizedText: string;
  possibleQuantity: number | null;
  possibleUnit: string | null;
  matchType: SmartImportMatchType;
  matchedIngredientId: string | null;
  matchConfidence: number;
}

interface LLMResolvedIngredient {
  index: number;
  name: string;
  quantity: number | null;
  unit: string | null;
  status: SmartImportStatus;
  confidence: number;
}

interface SmartImportInputAudit {
  total: number;
  resolved: number;
  ambiguous: number;
  none: number;
  sentToLLM: number;
}

interface SmartImportOutputAudit {
  resolvedFinal: number;
  inferred: number;
  unknown: number;
}

function normalizedPreparsedIngredientCandidates(value: unknown): NormalizedIngredientCandidate[] {
  if (!Array.isArray(value)) return [];

  const candidates: NormalizedIngredientCandidate[] = [];
  const seen = new Set<string>();
  for (const item of value.slice(0, MAX_PREPARSED_INGREDIENT_CANDIDATES)) {
    if (!isRecord(item)) continue;

    const rawText = normalizeText(item.raw_text).slice(0, 180);
    const normalizedText = normalizeIngredientCandidateText(
      normalizeText(item.normalized_text) || rawText,
    ).slice(0, 140);
    if (!normalizedText) continue;

    const quantity = normalizedPositiveNumber(item.possible_quantity);
    const unit = normalizedAllowedUnit(item.possible_unit);
    const catalogMatch = isRecord(item.catalog_match) ? item.catalog_match : {};
    const matchType = normalizedMatchType(catalogMatch.matchType ?? catalogMatch.match_type);
    const matchedIngredientId = normalizeText(catalogMatch.matchedIngredientId ?? catalogMatch.matched_ingredient_id) || null;
    const matchConfidence = normalizedConfidence(catalogMatch.confidence);
    const dedupeKey = `${normalizedText}|${quantity ?? "nil"}|${unit ?? "nil"}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);

    candidates.push({
      index: candidates.length,
      rawText: rawText || normalizedText,
      normalizedText,
      possibleQuantity: quantity,
      possibleUnit: unit,
      matchType,
      matchedIngredientId,
      matchConfidence,
    });
  }
  return candidates;
}

function candidateNeedsLLM(candidate: NormalizedIngredientCandidate): boolean {
  if (candidate.matchType === "exact") return false;
  if (candidate.matchType === "alias" && candidate.matchConfidence >= 0.85) return false;
  return true;
}

function computeSmartImportAudit(candidates: NormalizedIngredientCandidate[]): SmartImportInputAudit {
  const ambiguous = candidates.filter((candidate) => candidate.matchType === "ambiguous").length;
  const none = candidates.filter((candidate) => candidate.matchType === "none").length;
  return {
    total: candidates.length,
    resolved: candidates.filter((candidate) =>
      candidate.matchType === "exact" || candidate.matchType === "alias"
    ).length,
    ambiguous,
    none,
    sentToLLM: candidates.filter(candidateNeedsLLM).length,
  };
}

function computeSmartImportOutputAudit(ingredients: ParsedIngredient[]): SmartImportOutputAudit {
  const inferred = ingredients.filter((ingredient) => ingredient.status === "inferred").length;
  const unknown = ingredients.filter((ingredient) => ingredient.status === "unknown").length;
  return {
    resolvedFinal: ingredients.filter((ingredient) => ingredient.status === "resolved").length,
    inferred,
    unknown,
  };
}

function buildSmartImportAuditResponse(
  inputAudit: SmartImportInputAudit,
  outputAudit: SmartImportOutputAudit,
): SmartImportAuditResponse {
  return {
    total_candidates: inputAudit.total,
    resolved_locally: inputAudit.resolved,
    sent_to_llm: inputAudit.sentToLLM,
    final_unknown: outputAudit.unknown,
  };
}

function buildSmartImportResult(input: {
  caption: string;
  url: string;
  languageCode: string;
  candidates: NormalizedIngredientCandidate[];
  llmResolvedByIndex: Map<number, LLMResolvedIngredient>;
}): ParseRecipeCaptionResult {
  const ingredients = input.candidates.map((candidate): ParsedIngredient => {
    const llmResolved = input.llmResolvedByIndex.get(candidate.index);
    if (llmResolved) {
      const recovered = recoverExplicitMeasuredIngredient({
        name: llmResolved.name,
        quantity: llmResolved.quantity,
        unit: llmResolved.unit,
      });
      return {
        ...recovered,
        status: llmResolved.status,
        confidence: clamp01(llmResolved.confidence),
        matchType: candidate.matchType,
        matchedIngredientId: candidate.matchedIngredientId,
      };
    }

    const status: SmartImportStatus = candidateNeedsLLM(candidate) ? "unknown" : "resolved";
    return {
      name: candidate.normalizedText,
      quantity: candidate.possibleQuantity,
      unit: candidate.possibleUnit,
      status,
      confidence: candidateNeedsLLM(candidate) ? 0.35 : candidate.matchConfidence,
      matchType: candidate.matchType,
      matchedIngredientId: candidate.matchedIngredientId,
    };
  });

  return {
    title: inferDeterministicTitle(input.caption) || inferTitleFromURL(input.url),
    ingredients,
    steps: extractDeterministicSteps(input.caption),
    prepTimeMinutes: null,
    cookTimeMinutes: null,
    servings: null,
    confidence: confidenceFromIngredients(ingredients),
    inferredDish: null,
  };
}

function llmResolutionMap(items: LLMResolvedIngredient[]): Map<number, LLMResolvedIngredient> {
  const byIndex = new Map<number, LLMResolvedIngredient>();
  for (const item of items) {
    const name = normalizeText(item.name);
    if (!name) continue;
    byIndex.set(item.index, {
      index: item.index,
      name,
      quantity: normalizedPositiveNumber(item.quantity),
      unit: normalizedAllowedUnit(item.unit),
      status: normalizedStatus(item.status),
      confidence: clamp01(item.confidence),
    });
  }
  return byIndex;
}

async function invokeProviderForIngredientResolution(input: {
  candidates: NormalizedIngredientCandidate[];
  languageCode: string;
}): Promise<ProviderInvocationResult> {
  const userContent = [
    `languageCode: ${input.languageCode}`,
    "candidates:",
    JSON.stringify(input.candidates.map((candidate) => ({
      index: candidate.index,
      raw_text: candidate.rawText,
      normalized_text: candidate.normalizedText,
      possible_quantity: candidate.possibleQuantity,
      possible_unit: candidate.possibleUnit,
      match_type: candidate.matchType,
    }))),
  ].join("\n");

  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: INGREDIENT_RESOLUTION_LLM_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userContent,
          },
        ],
      },
    ],
    temperature: 0,
  };

  return invokeOpenAIProvider(payload);
}

async function invokeProviderForRecipeParse(input: {
  caption: string;
  url: string;
  languageCode: string;
}): Promise<ProviderInvocationResult> {
  const userContent = [
    `languageCode: ${input.languageCode}`,
    `url: ${input.url || ""}`,
    "caption:",
    input.caption,
  ].join("\n");

  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: RECIPE_IMPORT_LLM_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userContent,
          },
        ],
      },
    ],
    temperature: 0,
  };

  return invokeOpenAIProvider(payload);
}

async function invokeOpenAIProvider(payload: unknown): Promise<ProviderInvocationResult> {
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
    console.log(`[SEASON_IMPORT_EDGE] phase=provider_fetch_failed error=${String(error)}`);
    throw new ProviderInvocationError(String(error), elapsedMs(startedAt));
  } finally {
    clearTimeout(timeout);
  }
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

function normalizeText(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function normalizeLanguageCode(value: unknown): string {
  if (typeof value !== "string") {
    return DEFAULT_LANGUAGE_CODE;
  }
  const cleaned = value.trim().toLowerCase();
  if (!cleaned) {
    return DEFAULT_LANGUAGE_CODE;
  }
  return cleaned.slice(0, 5);
}

function normalizeIngredientCandidateText(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[_-]/g, " ")
    .replace(/[^a-z0-9À-ÖØ-öø-ÿ\s]/gi, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function normalizedPositiveNumber(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  return parsed;
}

function normalizedAllowedUnit(value: unknown): string | null {
  const unit = normalizeText(value).toLowerCase();
  switch (unit) {
    case "g":
    case "ml":
    case "piece":
    case "tbsp":
    case "tsp":
      return unit;
    default:
      return null;
  }
}

function normalizedMatchType(value: unknown): SmartImportMatchType {
  switch (value) {
    case "exact":
    case "alias":
    case "ambiguous":
    case "none":
      return value;
    default:
      return "none";
  }
}

function normalizedStatus(value: unknown): SmartImportStatus {
  switch (value) {
    case "resolved":
    case "inferred":
    case "unknown":
      return value;
    default:
      return "unknown";
  }
}

function normalizedConfidence(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return clamp01(parsed);
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

function confidenceFromIngredients(ingredients: ParsedIngredient[]): ImportConfidence {
  if (ingredients.length === 0) return "low";
  const average = ingredients.reduce((sum, ingredient) => sum + (ingredient.confidence ?? 0), 0) / ingredients.length;
  const unknownCount = ingredients.filter((ingredient) => ingredient.status === "unknown").length;
  if (average >= 0.88 && unknownCount === 0) return "high";
  if (average >= 0.58 && unknownCount <= Math.max(1, Math.floor(ingredients.length / 3))) return "medium";
  return "low";
}

function inferDeterministicTitle(caption: string): string | null {
  const lines = nonEmptyCaptionLines(caption);
  for (const line of lines) {
    const cleaned = stripListMarker(line);
    if (!cleaned || cleaned.length < 3) continue;
    const lower = cleaned.toLowerCase();
    if (isSectionHeader(lower)) continue;
    if (lower.startsWith("#") || lower.startsWith("http")) continue;
    if (looksLikeIngredientLine(cleaned)) continue;
    return cleaned.replace(/[!?.,:\-–—…\s]+$/g, "").trim() || null;
  }
  return null;
}

function inferTitleFromURL(url: string): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, "");
    return host || null;
  } catch {
    return null;
  }
}

function extractDeterministicSteps(caption: string): string[] {
  const lines = nonEmptyCaptionLines(caption);
  const steps: string[] = [];
  let inSteps = false;
  for (const line of lines) {
    const stripped = stripListMarker(line);
    const lower = stripped.toLowerCase();
    if (isStepHeader(lower)) {
      inSteps = true;
      continue;
    }
    if (inSteps && isIngredientHeader(lower)) {
      break;
    }
    if (inSteps && stripped) {
      steps.push(stripped);
    }
  }
  if (steps.length > 0) return steps;

  return lines
    .map(stripListMarker)
    .filter((line) => /^(step\s*)?\d+[\).\:-]\s+|^(mix|cook|bake|stir|combine|serve|cuoci|mescola|aggiungi|inforna)\b/i.test(line))
    .map((line) => line.replace(/^(step\s*)?\d+[\).\:-]\s+/i, "").trim())
    .filter(Boolean)
    .slice(0, 12);
}

function nonEmptyCaptionLines(caption: string): string[] {
  return caption
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function stripListMarker(line: string): string {
  return line
    .replace(/^\s*[-•*]+\s*/, "")
    .replace(/^\s*\d+[\).\:-]\s*/, "")
    .trim();
}

function isSectionHeader(lower: string): boolean {
  return isIngredientHeader(lower) || isStepHeader(lower);
}

function isIngredientHeader(lower: string): boolean {
  return lower.replace(/:$/, "").startsWith("ingredienti") ||
    lower.replace(/:$/, "").startsWith("ingredients");
}

function isStepHeader(lower: string): boolean {
  const normalized = lower.replace(/:$/, "");
  return normalized.startsWith("procedimento") ||
    normalized.startsWith("preparazione") ||
    normalized.startsWith("steps") ||
    normalized.startsWith("method") ||
    normalized.startsWith("instructions");
}

function looksLikeIngredientLine(line: string): boolean {
  return /^\s*[-•*]/.test(line) ||
    /\b\d+(?:[.,]\d+)?\s*(kg|g|ml|l|tbsp|tsp|cup|cups|piece|pieces)\b/i.test(line);
}

function recoverExplicitMeasuredIngredient(item: ParsedIngredient): ParsedIngredient {
  const rawName = item.name.trim();
  if (!rawName) return item;

  const pattern = /^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|piece|pieces)\s+(.+)$/i;
  const match = rawName.match(pattern);
  if (!match) return item;

  console.log(`[SEASON_IMPORT_EDGE] phase=explicit_quantity_detected raw_length=${rawName.length}`);

  const quantityToken = match[1].replace(",", ".");
  const unitToken = match[2].toLowerCase();
  const remainingName = match[3].trim();
  const parsedQuantity = Number(quantityToken);

  if (!Number.isFinite(parsedQuantity) || parsedQuantity <= 0 || !remainingName) {
    return item;
  }

  // Only recover when model did not provide quantity explicitly.
  if (item.quantity !== null) {
    return {
      name: remainingName,
      quantity: item.quantity,
      unit: item.unit,
    };
  }

  let recoveredQuantity = parsedQuantity;
  let recoveredUnit: string | null = null;
  switch (unitToken) {
    case "g":
      recoveredUnit = "g";
      break;
    case "kg":
      recoveredUnit = "g";
      recoveredQuantity = parsedQuantity * 1000;
      break;
    case "ml":
      recoveredUnit = "ml";
      break;
    case "l":
      recoveredUnit = "ml";
      recoveredQuantity = parsedQuantity * 1000;
      break;
    case "piece":
    case "pieces":
      recoveredUnit = "piece";
      break;
    default:
      recoveredUnit = null;
      break;
  }

  if (!recoveredUnit) return item;

  console.log(
    `[SEASON_IMPORT_EDGE] phase=explicit_quantity_recovered name_length=${remainingName.length} quantity=${recoveredQuantity} unit=${recoveredUnit}`,
  );
  return {
    name: remainingName,
    quantity: recoveredQuantity,
    unit: recoveredUnit,
  };
}

function elapsedMs(startedAt: number): number {
  return Math.max(0, Math.round(performance.now() - startedAt));
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
  return json(
    {
      ok: false,
      error: { code, message },
      meta: {
        usedServerLLM: false,
      },
    },
    status,
  );
}

function json(payload: ParseRecipeCaptionResponse, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}
