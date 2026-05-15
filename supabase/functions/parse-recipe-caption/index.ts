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
type SmartImportDraftQuality = "publishable" | "needs_creator_review" | "needs_more_input";
type SmartImportNextAction =
  | "publish"
  | "review_draft"
  | "add_more_recipe_detail"
  | "add_method_steps"
  | "add_ingredient_amounts"
  | "resolve_ingredients";

interface ParsedIngredient {
  name: string;
  quantity: number | null;
  unit: string | null;
  status?: SmartImportStatus;
  confidence?: number;
  matchType?: SmartImportMatchType;
  matchedIngredientId?: string | null;
}

interface SmartImportAgentPass {
  name: string;
  usedLLM: boolean;
  reason: string;
  candidateCount?: number;
}

interface SmartImportQualityScorecard {
  blockingIssues: string[];
  niceToFix: string[];
  autoFixable: string[];
}

interface SmartImportQualityMetrics {
  ingredientCount: number;
  ingredientsWithQuantity: number;
  quantityCoverage: number;
  duplicateIngredientNames: string[];
  stepsCount: number;
  hasServings: boolean;
}

interface SmartImportAutoFixPlanItem {
  issue: string;
  action: string;
  reason: string;
}

interface SmartImportAutoFixPlan {
  safeFixes: SmartImportAutoFixPlanItem[];
  deferredFixes: SmartImportAutoFixPlanItem[];
}

interface SmartImportSafeAutoFixResult {
  result: ParseRecipeCaptionResult;
  appliedFixes: SmartImportAutoFixPlanItem[];
}

interface SmartImportLearningSummary {
  source: string | null;
  termsRequested: number;
  termsWithLearning: number;
  termLearningCount: number;
  globalLearningCount: number;
  unavailable: boolean;
}

interface SmartImportAgentSummary {
  version: "smart_import_agent_v1";
  draftQuality: SmartImportDraftQuality;
  nextAction: SmartImportNextAction;
  actionReason: string;
  operationalSignals: string[];
  qualityMetrics: SmartImportQualityMetrics;
  scorecard: SmartImportQualityScorecard;
  autoFixPlan: SmartImportAutoFixPlan;
  appliedAutoFixes: SmartImportAutoFixPlanItem[];
  reviewHints: string[];
  unresolvedIngredients: string[];
  passes: SmartImportAgentPass[];
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
    smartImportAgent?: SmartImportAgentSummary;
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
const LLM_ENABLED = Deno.env.get("PARSE_RECIPE_LLM_ENABLED") !== "false";
const PROVIDER_MAX_OUTPUT_TOKENS = Number(Deno.env.get("PARSE_RECIPE_PROVIDER_MAX_OUTPUT_TOKENS") ?? "1800");

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
      const learningContext = await fetchSmartImportLearningContext(adminClient, smartImportCandidates);
      const learningSummary = summarizeSmartImportLearningContext(learningContext);
      console.log(
        `[SEASON_IMPORT_EDGE] phase=smart_import_decision request_id=${requestId} candidates=${smartImportCandidates.length} targeted_llm_candidates=${targetedCandidates.length}`,
      );
      console.log(
        `[SEASON_SMART_IMPORT_AUDIT] phase=edge_input request_id=${requestId} total=${smartImportAudit.total} resolved=${smartImportAudit.resolved} ambiguous=${smartImportAudit.ambiguous} none=${smartImportAudit.none} sent_to_llm=${smartImportAudit.sentToLLM}`,
      );
      console.log(
        `[SEASON_IMPORT_LEARNING] phase=context_loaded request_id=${requestId} source=${learningSummary.source ?? "none"} terms_requested=${learningSummary.termsRequested} terms_with_learning=${learningSummary.termsWithLearning} term_lessons=${learningSummary.termLearningCount} global_lessons=${learningSummary.globalLearningCount} unavailable=${learningSummary.unavailable}`,
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
        const agentResult = attachSmartImportAgentSummary(mappedResult, {
          inputAudit: smartImportAudit,
          outputAudit,
          usedLLM: false,
          mode: "candidate_resolution",
          learningSummary,
          caption,
          url,
        });
        console.log(
          `[SEASON_SMART_IMPORT_AUDIT] phase=edge_output request_id=${requestId} resolved_final=${outputAudit.resolvedFinal} inferred=${outputAudit.inferred} unknown=${outputAudit.unknown} llm_used=false`,
        );
        console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${agentResult.ingredients.length} steps=${agentResult.steps.length} confidence=${agentResult.confidence} smart_import=true used_llm=false draft_quality=${agentResult.smartImportAgent?.draftQuality}`);
        return json(
          {
            ok: true,
            result: agentResult,
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

      if (!LLM_ENABLED) {
        console.log(`[SEASON_IMPORT_EDGE] phase=provider_disabled request_id=${requestId}`);
        logLLMUsage("SEASON_IMPORT_EDGE", {
          functionName: "parse-recipe-caption",
          requestId,
          status: "error",
          providerDurationMs: null,
          model: OPENAI_MODEL,
          reason: "provider_disabled",
        });
        return json(
          {
            ok: false,
            error: {
              code: "PROVIDER_DISABLED",
              message: "Smart Import AI is temporarily disabled on the server.",
            },
            meta: {
              usedServerLLM: false,
              userId: userID,
              dayBucket,
              remainingToday: Math.max(0, quota.limit_count - quota.current_count),
            },
          },
          503,
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
          learningContext,
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
        const agentResult = attachSmartImportAgentSummary(mappedResult, {
          inputAudit: smartImportAudit,
          outputAudit,
          usedLLM: true,
          mode: "candidate_resolution",
          learningSummary,
          caption,
          url,
        });
        console.log(
          `[SEASON_SMART_IMPORT_AUDIT] phase=edge_output request_id=${requestId} resolved_final=${outputAudit.resolvedFinal} inferred=${outputAudit.inferred} unknown=${outputAudit.unknown} llm_used=true`,
        );
        console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${agentResult.ingredients.length} steps=${agentResult.steps.length} confidence=${agentResult.confidence} smart_import=true used_llm=true draft_quality=${agentResult.smartImportAgent?.draftQuality}`);
        return json(
          {
            ok: true,
            result: agentResult,
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
    if (!LLM_ENABLED) {
      console.log(`[SEASON_IMPORT_EDGE] phase=provider_disabled request_id=${requestId}`);
      logLLMUsage("SEASON_IMPORT_EDGE", {
        functionName: "parse-recipe-caption",
        requestId,
        status: "error",
        providerDurationMs: null,
        model: OPENAI_MODEL,
        reason: "provider_disabled",
      });
      return json(
        {
          ok: false,
          error: {
            code: "PROVIDER_DISABLED",
            message: "Smart Import AI is temporarily disabled on the server.",
          },
          meta: {
            usedServerLLM: false,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          },
        },
        503,
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

    console.log(`[SEASON_IMPORT_EDGE] phase=provider_call_start request_id=${requestId}`);

    try {
      let providerResult = await invokeProviderForRecipeParse({ caption, url, languageCode });
      console.log(`[SEASON_IMPORT_EDGE] phase=provider_call_success request_id=${requestId}`);

      let validation = validateLLMRecipeImportOutput(providerResult.parsed);
      let schemaRepairAttempted = false;

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
          reason: "validator_failed_first_pass",
        });

        schemaRepairAttempted = true;
        console.log(`[SEASON_IMPORT_EDGE] phase=provider_schema_repair_start request_id=${requestId}`);
        providerResult = await invokeProviderForRecipeParse({
          caption,
          url,
          languageCode,
          repairErrors: validation.errors,
        });
        validation = validateLLMRecipeImportOutput(providerResult.parsed);

        if (!validation.ok || !validation.value) {
          console.log(`[SEASON_IMPORT_EDGE] phase=validator_failed_after_repair request_id=${requestId} error_count=${validation.errors.length}`);
          logLLMUsage("SEASON_IMPORT_EDGE", {
            functionName: "parse-recipe-caption",
            requestId,
            status: "error",
            providerDurationMs: providerResult.durationMs,
            model: OPENAI_MODEL,
            inputTokens: providerResult.usage.inputTokens,
            outputTokens: providerResult.usage.outputTokens,
            totalTokens: providerResult.usage.totalTokens,
            reason: "validator_failed_after_schema_repair",
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
        reason: schemaRepairAttempted ? "full_recipe_parse_schema_repair" : "full_recipe_parse",
      });

      const recipeOutput = validation.value;
      const mappedIngredients = dedupeParsedIngredients(recipeOutput.ingredients.map((item) => {
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
      }));
      const mappedResult: ParseRecipeCaptionResult = {
        title: recipeOutput.title.trim() ? recipeOutput.title : null,
        ingredients: mappedIngredients,
        steps: recipeOutput.steps.map((step) => step.trim()).filter(Boolean),
        prepTimeMinutes: recipeOutput.prepTimeMinutes,
        cookTimeMinutes: recipeOutput.cookTimeMinutes,
        servings: recipeOutput.servings,
        confidence: recipeOutput.confidence,
        inferredDish: null,
      };
      const agentResult = attachSmartImportAgentSummary(mappedResult, {
        usedLLM: true,
        mode: "full_recipe_parse",
        caption,
        url,
      });

      console.log(`[SEASON_IMPORT_EDGE] phase=response_success request_id=${requestId} ingredients=${agentResult.ingredients.length} steps=${agentResult.steps.length} confidence=${agentResult.confidence} draft_quality=${agentResult.smartImportAgent?.draftQuality}`);
      return json(
        {
          ok: true,
          result: agentResult,
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
    const candidate: NormalizedIngredientCandidate = {
      index: 0,
      rawText: rawText || normalizedText,
      normalizedText,
      possibleQuantity: quantity,
      possibleUnit: unit,
      matchType,
      matchedIngredientId,
      matchConfidence,
    };

    const existingIndex = candidates.findIndex((existing) => existing.normalizedText === candidate.normalizedText);
    if (existingIndex >= 0) {
      if (candidateQualityScore(candidate) > candidateQualityScore(candidates[existingIndex])) {
        candidates[existingIndex] = candidate;
      }
      continue;
    }

    candidates.push(candidate);
  }
  return candidates.map((candidate, index) => ({ ...candidate, index }));
}

function candidateQualityScore(candidate: NormalizedIngredientCandidate): number {
  return (candidate.possibleQuantity !== null ? 1_000 : 0)
    + (candidate.possibleUnit !== null ? 100 : 0)
    + (candidate.matchedIngredientId !== null ? 50 : 0)
    + (candidate.matchType === "exact" ? 30 : candidate.matchType === "alias" ? 20 : 0)
    + Math.round(candidate.matchConfidence * 10)
    + Math.min(candidate.rawText.length, 80);
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

function attachSmartImportAgentSummary(
  result: ParseRecipeCaptionResult,
  input: {
    inputAudit?: SmartImportInputAudit;
    outputAudit?: SmartImportOutputAudit;
    usedLLM: boolean;
    mode: "candidate_resolution" | "full_recipe_parse";
    learningSummary?: SmartImportLearningSummary;
    caption?: string;
    url?: string;
  },
): ParseRecipeCaptionResult {
  const safeAutoFix = applySmartImportSafeAutoFixes(result, {
    caption: input.caption ?? "",
    url: input.url ?? "",
  });
  const outputAudit = input.outputAudit ?? computeSmartImportOutputAudit(safeAutoFix.result.ingredients);
  return {
    ...safeAutoFix.result,
    smartImportAgent: buildSmartImportAgentSummary(safeAutoFix.result, {
      ...input,
      outputAudit,
      appliedAutoFixes: safeAutoFix.appliedFixes,
    }),
  };
}

function applySmartImportSafeAutoFixes(
  result: ParseRecipeCaptionResult,
  context: { caption: string; url: string },
): SmartImportSafeAutoFixResult {
  const appliedFixes: SmartImportAutoFixPlanItem[] = [];
  let fixedResult = result;

  if (!result.title?.trim()) {
    const fallbackTitle = result.inferredDish?.trim() ||
      inferDeterministicTitle(context.caption) ||
      inferTitleFromURL(context.url);

    if (fallbackTitle) {
      fixedResult = {
        ...fixedResult,
        title: fallbackTitle,
      };
      appliedFixes.push({
        issue: "title_missing",
        action: "use_safe_title_fallback",
        reason: "The server filled a missing title using an explicit caption title, inferred dish, or URL host without calling the LLM again.",
      });
    }
  }

  if (fixedResult.servings === null) {
    const inferredServings = inferDeterministicServings(context.caption);
    if (inferredServings !== null) {
      fixedResult = {
        ...fixedResult,
        servings: inferredServings,
      };
      appliedFixes.push({
        issue: "servings_missing",
        action: "use_explicit_caption_servings",
        reason: "The server recovered servings from explicit caption text such as per 2, x2, or 2 persone without guessing.",
      });
    }
  }

  return {
    result: fixedResult,
    appliedFixes,
  };
}

function buildSmartImportAgentSummary(
  result: ParseRecipeCaptionResult,
  input: {
    inputAudit?: SmartImportInputAudit;
    outputAudit: SmartImportOutputAudit;
    usedLLM: boolean;
    mode: "candidate_resolution" | "full_recipe_parse";
    learningSummary?: SmartImportLearningSummary;
    appliedAutoFixes?: SmartImportAutoFixPlanItem[];
    caption?: string;
  },
): SmartImportAgentSummary {
  const reviewHints = smartImportReviewHints(result, input.outputAudit);
  const unresolvedIngredients = result.ingredients
    .filter((ingredient) => ingredient.status === "unknown" || !ingredient.matchedIngredientId && ingredient.matchType === "none")
    .map((ingredient) => ingredient.name)
    .filter(Boolean)
    .slice(0, 12);
  const scorecard = smartImportQualityScorecard(result, input.outputAudit, reviewHints);
  const autoFixPlan = smartImportAutoFixPlan(result, scorecard);
  const nextAction = smartImportNextAction(result, input.outputAudit, reviewHints);
  const qualityMetrics = smartImportQualityMetrics(result);
  const operationalSignals = smartImportOperationalSignals(result, input.outputAudit, reviewHints, scorecard, input.caption ?? "");

  let draftQuality: SmartImportDraftQuality = "publishable";
  if (result.ingredients.length === 0 || result.steps.length === 0) {
    draftQuality = "needs_more_input";
  } else if (result.confidence === "low" || input.outputAudit.unknown > 0 || reviewHints.length > 0) {
    draftQuality = "needs_creator_review";
  }

  const passes: SmartImportAgentPass[] = [];
  if (input.mode === "candidate_resolution") {
    passes.push({
      name: "swift_preparse_catalog_memory",
      usedLLM: false,
      reason: "Swift extracted ingredient candidates and local catalog matches before calling the server.",
      candidateCount: input.inputAudit?.total,
    });
    if (input.usedLLM) {
      passes.push({
        name: "targeted_ingredient_resolution",
        usedLLM: true,
        reason: input.learningSummary && !input.learningSummary.unavailable
          ? "Only ambiguous, unknown, or low-confidence ingredient candidates were sent to the LLM with relevant learning memory attached."
          : "Only ambiguous, unknown, or low-confidence ingredient candidates were sent to the LLM.",
        candidateCount: input.inputAudit?.sentToLLM,
      });
    }
  } else {
    passes.push({
      name: "full_recipe_caption_parse",
      usedLLM: true,
      reason: "No preparsed candidates were provided, so the LLM extracted the full draft from caption and URL context.",
    });
  }

  if (input.learningSummary && !input.learningSummary.unavailable && input.learningSummary.termLearningCount + input.learningSummary.globalLearningCount > 0) {
    passes.push({
      name: "learning_memory_context",
      usedLLM: false,
      reason: `Loaded ${input.learningSummary.termLearningCount} term lessons and ${input.learningSummary.globalLearningCount} global lessons as advisory context for import reasoning.`,
      candidateCount: input.learningSummary.termsWithLearning,
    });
  }

  passes.push({
    name: "draft_quality_gate",
    usedLLM: false,
    reason: "Server scored draft completeness and surfaced creator review hints without mutating the catalog.",
    candidateCount: result.ingredients.length,
  });
  if ((input.appliedAutoFixes?.length ?? 0) > 0) {
    passes.push({
      name: "safe_autofix_worker",
      usedLLM: false,
      reason: "Server applied deterministic draft cleanup that does not mutate the catalog or invent recipe content.",
      candidateCount: input.appliedAutoFixes?.length,
    });
  }

  return {
    version: "smart_import_agent_v1",
    draftQuality,
    nextAction: nextAction.name,
    actionReason: nextAction.reason,
    operationalSignals,
    qualityMetrics,
    scorecard,
    autoFixPlan,
    appliedAutoFixes: input.appliedAutoFixes ?? [],
    reviewHints,
    unresolvedIngredients,
    passes,
  };
}

function smartImportOperationalSignals(
  result: ParseRecipeCaptionResult,
  outputAudit: SmartImportOutputAudit,
  reviewHints: string[],
  scorecard: SmartImportQualityScorecard,
  caption: string,
): string[] {
  const signals: string[] = [];

  if (result.ingredients.length > 0 && result.steps.length === 0) {
    signals.push("ingredients_only_caption");
  }
  if (result.ingredients.length === 0 && result.steps.length === 0) {
    signals.push("low_signal_caption");
  }
  if (result.steps.length > 0 && reviewHints.includes("quantities_missing")) {
    signals.push("method_without_amounts");
  }
  if (result.servings === null) {
    signals.push("missing_servings_metadata");
  }
  if (result.prepTimeMinutes === null && result.cookTimeMinutes === null) {
    signals.push("missing_timing_metadata");
  }
  if (outputAudit.unknown > 0 || scorecard.blockingIssues.includes("unresolved_ingredients_present")) {
    signals.push("catalog_identity_review_needed");
  }
  if (result.confidence === "low") {
    signals.push("low_confidence_parse");
  }
  signals.push(smartImportCaptionCategory(caption, result, reviewHints));
  if (result.ingredients.some((ingredient) => ingredient.quantity !== null) && reviewHints.includes("quantities_missing")) {
    signals.push("partial_quantity_caption");
  }
  if (smartImportQualityMetrics(result).duplicateIngredientNames.length > 0) {
    signals.push("duplicate_ingredients_detected");
  }

  return uniqueStrings(signals);
}

function smartImportQualityMetrics(result: ParseRecipeCaptionResult): SmartImportQualityMetrics {
  const duplicateIngredientNames = duplicateParsedIngredientNames(result.ingredients);
  const ingredientsWithQuantity = result.ingredients.filter((ingredient) => ingredient.quantity !== null).length;
  const ingredientCount = result.ingredients.length;
  return {
    ingredientCount,
    ingredientsWithQuantity,
    quantityCoverage: ingredientCount === 0 ? 0 : Number((ingredientsWithQuantity / ingredientCount).toFixed(3)),
    duplicateIngredientNames,
    stepsCount: result.steps.length,
    hasServings: result.servings !== null,
  };
}

function duplicateParsedIngredientNames(ingredients: ParsedIngredient[]): string[] {
  const counts = new Map<string, number>();
  for (const ingredient of ingredients) {
    const key = normalizeIngredientCandidateText(ingredient.name);
    if (!key) continue;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return Array.from(counts.entries())
    .filter(([, count]) => count > 1)
    .map(([name]) => name);
}

function smartImportCaptionCategory(
  caption: string,
  result: ParseRecipeCaptionResult,
  reviewHints: string[],
): string {
  const normalized = normalizeText(caption);
  const hasIngredientHeader = /\bingredienti\b|\bdosi\b|\boccorrente\b|\bcosa serve\b/i.test(normalized);
  const hasMethodMarker = /\bprocedimento\b|\bpreparazione\b|\bcuoci\b|\bmescola\b|\baggiungi\b|\binforna\b|\bfrulla\b|\bversa\b/i.test(normalized);
  const quantityMentions = (caption.match(/\b\d+(?:[.,]\d+)?\s*(?:g|gr|kg|ml|l|litri?|cucchiai?|cucchiaini?|uova?|tuorli|spicchi|persone)\b|q\.?\s*b\.?/gi) ?? []).length;

  if (result.ingredients.length === 0 && result.steps.length === 0) return "low_signal_caption";
  if (result.ingredients.length > 0 && result.steps.length === 0) return "ingredients_only_caption";
  if (hasIngredientHeader && hasMethodMarker && quantityMentions >= 2) return "complete_recipe_caption";
  if (hasMethodMarker && reviewHints.includes("quantities_missing")) return "method_without_amounts";
  if (quantityMentions >= 2 && result.steps.length > 0) return "messy_recipe_like_caption";
  return "creator_caption";
}

function smartImportQualityScorecard(
  result: ParseRecipeCaptionResult,
  outputAudit: SmartImportOutputAudit,
  reviewHints: string[],
): SmartImportQualityScorecard {
  const blockingIssues: string[] = [];
  const niceToFix: string[] = [];
  const autoFixable: string[] = [];

  if (reviewHints.includes("ingredients_missing")) {
    blockingIssues.push("ingredients_missing");
  }
  if (reviewHints.includes("steps_missing")) {
    blockingIssues.push("steps_missing");
  }
  if (reviewHints.includes("unresolved_ingredients_present") || outputAudit.unknown > 0) {
    blockingIssues.push("unresolved_ingredients_present");
  }
  if (reviewHints.includes("low_confidence_parse")) {
    blockingIssues.push("low_confidence_parse");
  }

  if (reviewHints.includes("quantities_missing")) {
    niceToFix.push("quantities_missing");
  }
  if (result.servings === null) {
    niceToFix.push("servings_missing");
  }
  if (result.prepTimeMinutes === null && result.cookTimeMinutes === null) {
    niceToFix.push("timings_missing");
  }

  if (reviewHints.includes("title_missing")) {
    if (result.inferredDish) {
      autoFixable.push("title_missing");
    } else {
      blockingIssues.push("title_missing");
    }
  }

  return {
    blockingIssues: uniqueStrings(blockingIssues),
    niceToFix: uniqueStrings(niceToFix),
    autoFixable: uniqueStrings(autoFixable),
  };
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values));
}

function smartImportAutoFixPlan(
  result: ParseRecipeCaptionResult,
  scorecard: SmartImportQualityScorecard,
): SmartImportAutoFixPlan {
  const safeFixes: SmartImportAutoFixPlanItem[] = [];
  const deferredFixes: SmartImportAutoFixPlanItem[] = [];

  if (scorecard.autoFixable.includes("title_missing") && result.inferredDish) {
    safeFixes.push({
      issue: "title_missing",
      action: "use_inferred_dish_as_title",
      reason: "The model already inferred a dish name, so the server can use it as a draft title without catalog mutation or extra LLM cost.",
    });
  }

  for (const issue of scorecard.blockingIssues) {
    if (issue === "steps_missing") {
      deferredFixes.push({
        issue,
        action: "ask_creator_for_method_steps",
        reason: "Preparation steps should come from the creator or explicit caption text; the server must not invent a method.",
      });
    } else if (issue === "ingredients_missing") {
      deferredFixes.push({
        issue,
        action: "ask_creator_for_ingredients",
        reason: "A recipe without ingredient structure cannot be repaired safely from context alone.",
      });
    } else if (issue === "unresolved_ingredients_present") {
      deferredFixes.push({
        issue,
        action: "route_to_catalog_resolution",
        reason: "Catalog identity needs reconciliation or creator review before unattended publishing.",
      });
    } else {
      deferredFixes.push({
        issue,
        action: "manual_review",
        reason: "The issue is blocking and does not have a deterministic safe fix yet.",
      });
    }
  }

  for (const issue of scorecard.niceToFix) {
    if (issue === "quantities_missing") {
      deferredFixes.push({
        issue,
        action: "ask_creator_for_amounts",
        reason: "Ingredient amounts are useful for publishing quality, but inventing doses would be unsafe.",
      });
    } else if (issue === "servings_missing") {
      deferredFixes.push({
        issue,
        action: "ask_creator_for_servings",
        reason: "Servings affect shopping and nutrition; keep them explicit unless a future deterministic rule is added.",
      });
    } else if (issue === "timings_missing") {
      deferredFixes.push({
        issue,
        action: "ask_creator_for_timings",
        reason: "Prep and cook times are helpful metadata but should not be guessed from a short caption.",
      });
    }
  }

  return {
    safeFixes,
    deferredFixes,
  };
}

function smartImportNextAction(
  result: ParseRecipeCaptionResult,
  outputAudit: SmartImportOutputAudit,
  reviewHints: string[],
): { name: SmartImportNextAction; reason: string } {
  if (result.ingredients.length === 0) {
    return {
      name: "add_more_recipe_detail",
      reason: "The caption does not contain enough ingredient structure to create a reliable draft.",
    };
  }
  if (result.steps.length === 0) {
    return {
      name: "add_method_steps",
      reason: "The draft has ingredients, but no preparation method was found. Ask the creator for at least one real step or assembly instruction.",
    };
  }
  if (outputAudit.unknown > 0) {
    return {
      name: "resolve_ingredients",
      reason: "Some ingredients remain unresolved against the catalog and should be checked before publishing.",
    };
  }
  if (reviewHints.includes("quantities_missing")) {
    return {
      name: "add_ingredient_amounts",
      reason: "The recipe structure is usable, but ingredient amounts are missing or too vague for a creator-ready draft.",
    };
  }
  if (reviewHints.length > 0 || result.confidence === "low") {
    return {
      name: "review_draft",
      reason: "The draft is usable, but the assistant found details that deserve a final creator review.",
    };
  }
  return {
    name: "publish",
    reason: "The draft has a title, ingredients, quantities, steps, and no blocking catalog issues.",
  };
}

function smartImportReviewHints(
  result: ParseRecipeCaptionResult,
  outputAudit: SmartImportOutputAudit,
): string[] {
  const hints: string[] = [];
  if (!result.title || result.title.trim().length === 0) {
    hints.push("title_missing");
  }
  if (result.ingredients.length === 0) {
    hints.push("ingredients_missing");
  }
  if (result.steps.length === 0) {
    hints.push("steps_missing");
  }
  if (outputAudit.unknown > 0) {
    hints.push("unresolved_ingredients_present");
  }
  if (result.ingredients.length > 0 && !result.ingredients.some((ingredient) => ingredient.quantity !== null)) {
    hints.push("quantities_missing");
  }
  if (result.confidence === "low") {
    hints.push("low_confidence_parse");
  }
  return hints;
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
  const dedupedIngredients = dedupeParsedIngredients(ingredients);

  return {
    title: inferDeterministicTitle(input.caption) || inferTitleFromURL(input.url),
    ingredients: dedupedIngredients,
    steps: extractDeterministicSteps(input.caption),
    prepTimeMinutes: null,
    cookTimeMinutes: null,
    servings: inferDeterministicServings(input.caption),
    confidence: confidenceFromIngredients(dedupedIngredients),
    inferredDish: null,
  };
}

function dedupeParsedIngredients(ingredients: ParsedIngredient[]): ParsedIngredient[] {
  const result: ParsedIngredient[] = [];

  for (const ingredient of ingredients) {
    const existingIndex = parsedIngredientDuplicateIndex(ingredient, result);
    if (existingIndex >= 0) {
      if (parsedIngredientQualityScore(ingredient) > parsedIngredientQualityScore(result[existingIndex])) {
        result[existingIndex] = ingredient;
      }
      continue;
    }
    result.push(ingredient);
  }

  return result;
}

function parsedIngredientDuplicateIndex(
  ingredient: ParsedIngredient,
  existingIngredients: ParsedIngredient[],
): number {
  const normalizedName = normalizeIngredientCandidateText(ingredient.name);

  return existingIngredients.findIndex((existing) => {
    const existingName = normalizeIngredientCandidateText(existing.name);
    if (normalizedName && normalizedName === existingName) {
      return true;
    }

    const sameCatalogIdentity = ingredient.matchedIngredientId !== null
      && ingredient.matchedIngredientId !== undefined
      && ingredient.matchedIngredientId === existing.matchedIngredientId;
    if (!sameCatalogIdentity) {
      return false;
    }

    return true;
  });
}

function parsedIngredientQualityScore(ingredient: ParsedIngredient): number {
  const statusScore = ingredient.status === "resolved" ? 60 : ingredient.status === "inferred" ? 40 : 0;
  return (ingredient.quantity !== null ? 1_000 : 0)
    + (ingredient.unit !== null ? 100 : 0)
    + (ingredient.matchedIngredientId ? 70 : 0)
    + statusScore
    + Math.round((ingredient.confidence ?? 0) * 10)
    + Math.min(ingredient.name.length, 80);
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

async function fetchSmartImportLearningContext(
  adminClient: any,
  candidates: NormalizedIngredientCandidate[],
): Promise<Record<string, unknown>> {
  const normalizedTexts = Array.from(
    new Set(
      candidates
        .map((candidate) => normalizeIngredientCandidateText(candidate.normalizedText))
        .filter(Boolean),
    ),
  ).slice(0, 40);

  if (normalizedTexts.length === 0) {
    return {};
  }

  const { data, error } = await adminClient.rpc("get_catalog_agent_learning_context", {
    p_normalized_texts: normalizedTexts,
    p_limit_per_term: 2,
  });

  if (error) {
    console.log(`[SEASON_IMPORT_LEARNING] phase=context_unavailable error=${error.message}`);
    return {
      metadata: {
        source: "catalog_agent_learning_context_unavailable",
        unavailable: true,
        error_message: error.message,
        terms_requested: normalizedTexts.length,
      },
    };
  }

  return isRecord(data) ? data : {};
}

function summarizeSmartImportLearningContext(context: Record<string, unknown>): SmartImportLearningSummary {
  const metadata = readNestedRecord(context, ["metadata"]);
  const globalLearnings = readNestedArray(context, ["global_learnings"]);
  const termLearnings = readNestedRecord(context, ["term_learnings"]);

  return {
    source: typeof metadata.source === "string" ? metadata.source : null,
    termsRequested: numberOrZero(metadata.terms_requested),
    termsWithLearning: numberOrZero(metadata.terms_with_learning),
    termLearningCount: Object.values(termLearnings)
      .filter(Array.isArray)
      .reduce((total, learnings) => total + learnings.length, 0),
    globalLearningCount: globalLearnings.length,
    unavailable: metadata.unavailable === true,
  };
}

function compactSmartImportLearningContextForPrompt(context: Record<string, unknown>): Record<string, unknown> {
  const termLearnings = readNestedRecord(context, ["term_learnings"]);
  const compactTermLearnings: Record<string, unknown> = {};

  for (const [term, rawLearnings] of Object.entries(termLearnings)) {
    if (!Array.isArray(rawLearnings)) continue;
    compactTermLearnings[term] = rawLearnings
      .filter(isRecord)
      .slice(0, 2)
      .map(compactLearningArtifact);
  }

  return {
    runtime_instruction: readNestedRecord(context, ["runtime_instruction"]),
    term_learnings: compactTermLearnings,
    global_learnings: readNestedArray(context, ["global_learnings"])
      .filter(isRecord)
      .slice(0, 4)
      .map(compactLearningArtifact),
  };
}

function compactLearningArtifact(learning: Record<string, unknown>): Record<string, unknown> {
  return {
    learning_type: learning.learning_type ?? null,
    status: learning.status ?? null,
    severity: learning.severity ?? null,
    observed_problem: learning.observed_problem ?? null,
    corrected_decision: learning.corrected_decision ?? null,
    policy_implication: learning.policy_implication ?? null,
    prompt_recommendation: learning.prompt_recommendation ?? null,
  };
}

async function invokeProviderForIngredientResolution(input: {
  candidates: NormalizedIngredientCandidate[];
  languageCode: string;
  learningContext: Record<string, unknown>;
}): Promise<ProviderInvocationResult> {
  const userContent = [
    `languageCode: ${input.languageCode}`,
    "relevant_learning_memory:",
    JSON.stringify(compactSmartImportLearningContextForPrompt(input.learningContext)),
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
    max_output_tokens: providerMaxOutputTokens(),
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
  repairErrors?: string[];
}): Promise<ProviderInvocationResult> {
  const userContent = [
    `languageCode: ${input.languageCode}`,
    `url: ${input.url || ""}`,
    ...(input.repairErrors && input.repairErrors.length > 0
      ? [
        "schema_repair_context:",
        "Your previous JSON failed validation. Return the same recipe extraction intent, but fix ONLY the schema errors below.",
        JSON.stringify(input.repairErrors.slice(0, 12)),
        "Remember: output one JSON object only, with exactly the required keys and allowed enum values.",
      ]
      : []),
    "caption:",
    input.caption,
  ].join("\n");

  const payload = {
    model: OPENAI_MODEL,
    max_output_tokens: providerMaxOutputTokens(),
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

function providerMaxOutputTokens(): number {
  if (!Number.isFinite(PROVIDER_MAX_OUTPUT_TOKENS)) return 1800;
  return Math.max(256, Math.min(4000, Math.floor(PROVIDER_MAX_OUTPUT_TOKENS)));
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
    case "gr":
    case "grammi":
      return "g";
    case "ml":
      return "ml";
    case "kg":
      return "g";
    case "l":
    case "lt":
    case "litro":
    case "litri":
      return "ml";
    case "piece":
    case "pieces":
    case "pezzo":
    case "pezzi":
    case "spicchio":
    case "spicchi":
    case "uovo":
    case "uova":
    case "tuorlo":
    case "tuorli":
      return "piece";
    case "tbsp":
    case "cucchiaio":
    case "cucchiai":
      return "tbsp";
    case "tsp":
    case "cucchiaino":
    case "cucchiaini":
      return "tsp";
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

function inferDeterministicServings(caption: string): number | null {
  const normalized = normalizeText(caption);
  const patterns = [
    /\bper\s+(\d{1,2})\s*(?:persone|persona|porzioni|porzione)?\b/i,
    /\b(?:dose|dosi)\s+per\s+(\d{1,2})\b/i,
    /\b(\d{1,2})\s*(?:persone|persona|porzioni|porzione)\b/i,
    /\bx\s*(\d{1,2})\b/i,
  ];

  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (!match) continue;
    const value = Number(match[1]);
    if (Number.isInteger(value) && value >= 1 && value <= 20) {
      return value;
    }
  }

  return null;
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

  const pattern = /^(\d+(?:[.,]\d+)?)\s*(kg|g|gr|ml|l|lt|litro|litri|piece|pieces|pezzo|pezzi|spicchio|spicchi|uovo|uova|tuorlo|tuorli|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini)\s+(.+)$/i;
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
    case "gr":
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
    case "lt":
    case "litro":
    case "litri":
      recoveredUnit = "ml";
      recoveredQuantity = parsedQuantity * 1000;
      break;
    case "piece":
    case "pieces":
    case "pezzo":
    case "pezzi":
    case "spicchio":
    case "spicchi":
    case "uovo":
    case "uova":
    case "tuorlo":
    case "tuorli":
      recoveredUnit = "piece";
      break;
    case "tbsp":
    case "cucchiaio":
    case "cucchiai":
      recoveredUnit = "tbsp";
      break;
    case "tsp":
    case "cucchiaino":
    case "cucchiaini":
      recoveredUnit = "tsp";
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

function readNestedRecord(value: unknown, path: string[]): Record<string, unknown> {
  let current: unknown = value;
  for (const key of path) {
    if (!isRecord(current)) return {};
    current = current[key];
  }
  return isRecord(current) ? current : {};
}

function readNestedArray(value: unknown, path: string[]): unknown[] {
  let current: unknown = value;
  for (const key of path) {
    if (!isRecord(current)) return [];
    current = current[key];
  }
  return Array.isArray(current) ? current : [];
}

function numberOrZero(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
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
