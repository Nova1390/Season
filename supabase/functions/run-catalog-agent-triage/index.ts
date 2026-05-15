import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
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
import { recordAIUsageEvent } from "../_shared/ai_usage.ts";
import {
  CATALOG_AGENT_ALLOWED_IMPLICATION_LEVELS,
  CATALOG_AGENT_ALLOWED_SUBSTITUTABILITY,
  CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
  type CatalogAgentSemanticProfileOutput,
  type CatalogAgentProposalOutput,
  validateCatalogAgentTriageOutput,
} from "./llm_contract.ts";

interface AgentRunRequest {
  limit?: number;
  source_domain?: string | null;
  include_non_new?: boolean;
  dry_run?: boolean;
}

type ServiceSupabaseClient = SupabaseClient<any, "public", "public", any, any>;

interface ProviderInvocationResult {
  parsed: unknown;
  durationMs: number;
  usage: TokenUsage;
  reasoningTrace: Record<string, unknown>;
}

interface ProviderRoleResult {
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

const FUNCTION_NAME = "run-catalog-agent-triage";
const LOG_PREFIX = "SEASON_CATALOG_AGENT";
const AGENT_NAME = "catalog-governance-agent";
const AGENT_VERSION = "proposal-only-v5.0-external-evidence-grounding";
const PROMPT_VERSION = "catalog-agent-triage-v4-multi-pass";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const OPENAI_API_KEY = env("OPENAI_API_KEY");
const OPENAI_API_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = env("CATALOG_AGENT_OPENAI_MODEL", "gpt-5.4-mini");
const OPERATOR_TOKEN = env("CATALOG_AGENT_OPERATOR_TOKEN");

const AGENT_ENABLED = env("CATALOG_AGENT_ENABLED", "false").toLowerCase() === "true";
const MAX_ITEMS_PER_RUN = boundedInteger(numberEnv("CATALOG_AGENT_MAX_ITEMS_PER_RUN", 10), 1, 25);
const MAX_RUNS_PER_DAY = boundedInteger(numberEnv("CATALOG_AGENT_MAX_RUNS_PER_DAY", 3), 1, 24);
const RECENT_PROPOSAL_DAYS = boundedInteger(numberEnv("CATALOG_AGENT_RECENT_PROPOSAL_DAYS", 7), 0, 90);
const PROVIDER_TIMEOUT_MS = boundedInteger(numberEnv("CATALOG_AGENT_PROVIDER_TIMEOUT_MS", 20000), 1000, 60000);
const PROPOSAL_PERSISTENCE_ENABLED = env("CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED", "false").toLowerCase() === "true";
const SUPERSEDE_OPEN_PROPOSALS = env("CATALOG_AGENT_SUPERSEDE_OPEN_PROPOSALS", "true").toLowerCase() !== "false";
const REASONING_MODE = env("CATALOG_AGENT_REASONING_MODE", "multi_pass").toLowerCase() === "single_pass"
  ? "single_pass"
  : "multi_pass";
const MAX_REASONING_CALLS_PER_RUN = boundedInteger(numberEnv("CATALOG_AGENT_MAX_REASONING_CALLS_PER_RUN", 3), 1, 5);
const RISK_REVIEW_ENABLED = env("CATALOG_AGENT_RISK_REVIEW_ENABLED", "true").toLowerCase() !== "false";
const SELF_REPAIR_ENABLED = env("CATALOG_AGENT_SELF_REPAIR_ENABLED", "true").toLowerCase() !== "false";
const MAX_SELF_REPAIR_ITEMS = boundedInteger(numberEnv("CATALOG_AGENT_MAX_SELF_REPAIR_ITEMS", 5), 1, 10);
const LEARNING_WRITER_ENABLED = env("CATALOG_AGENT_LEARNING_WRITER_ENABLED", "false").toLowerCase() === "true";
const MAX_LEARNING_WRITER_SUGGESTIONS = boundedInteger(numberEnv("CATALOG_AGENT_MAX_LEARNING_WRITER_SUGGESTIONS", 5), 1, 20);
const INPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_AGENT_INPUT_COST_PER_1M_USD");
const OUTPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_AGENT_OUTPUT_COST_PER_1M_USD");

const GENERIC_AGGREGATE_TERMS = new Set([
  "aromi",
  "aromas",
  "cheese",
  "cheeses",
  "condimenti",
  "erbe",
  "formaggi",
  "fruit",
  "frutta",
  "herbs",
  "pesce",
  "seafood",
  "seasoning",
  "seasonings",
  "spezie",
  "spices",
  "verdura",
  "verdure",
  "vegetable",
  "vegetables",
]);

const CONCRETE_AGGREGATE_QUALIFIERS = [
  "blend",
  "erbe di provenza",
  "erbe mediterranee",
  "fruit mix",
  "misto",
  "miscela",
  "mix",
  "per arrosto",
  "per barbecue",
  "per carne",
  "per dolci",
  "per grigliata",
  "per pesce",
  "per pizza",
  "provenza",
  "quattro formaggi",
  "seasoning mix",
  "spice blend",
  "vegetable mix",
];

const RECIPE_PROCESS_BYPRODUCT_TERMS = new Set([
  "acqua cottura",
  "acqua della pasta",
  "acqua di cottura",
  "acqua di cottura della pasta",
  "cooking liquid",
  "cooking water",
  "liquido cottura",
  "liquido di cottura",
  "pasta water",
]);

const REUSABLE_LIQUID_IDENTITY_TERMS = [
  "aquafaba",
  "brodo",
  "broth",
  "dashi",
  "fumetto",
  "stock",
];

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  const startedAt = performance.now();
  let runId: number | null = null;

  try {
    console.log(`[${LOG_PREFIX}] phase=request_received method=${request.method} request_id=${requestId}`);

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

    if (!AGENT_ENABLED) {
      return errorJson(403, "AGENT_DISABLED", "Catalog agent is disabled by CATALOG_AGENT_ENABLED.");
    }

    let auth = await resolveCatalogAdminOrServiceRole(request, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
      supabaseServiceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      logPrefix: LOG_PREFIX,
    });
    if (!auth.allowed && hasOperatorToken(request)) {
      console.log(`[${LOG_PREFIX}] phase=auth_ok mode=operator_token`);
      auth = { allowed: true, mode: "service_role", bearerToken: null, userId: null };
    }
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHORIZED", "Catalog admin authentication is required.");
    }

    let payload: AgentRunRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const limit = boundedInteger(Number(payload.limit ?? MAX_ITEMS_PER_RUN), 1, MAX_ITEMS_PER_RUN);
    const sourceDomain = normalizeNullableText(payload.source_domain);
    const includeNonNew = payload.include_non_new === true;
    const dryRun = payload.dry_run === true;

    if (!dryRun && !PROPOSAL_PERSISTENCE_ENABLED) {
      return errorJson(403, "PROPOSAL_PERSISTENCE_DISABLED", "Proposal persistence requires CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=true.");
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const runsToday = await countRunsToday(adminClient);
    if (runsToday >= MAX_RUNS_PER_DAY) {
      const cancelledRun = await insertRun(adminClient, {
        status: "cancelled",
        sourceDomain,
        authUserId: auth.userId,
        inputSummary: {
          request_id: requestId,
          limit,
          source_domain: sourceDomain,
          include_non_new: includeNonNew,
          dry_run: dryRun,
          budget: budgetSummary(),
        },
        summary: {
          reason: "daily_run_budget_exhausted",
          runs_today: runsToday,
          max_runs_per_day: MAX_RUNS_PER_DAY,
        },
      });
      runId = cancelledRun;
      return jsonResponseWithStatus({
        ok: false,
        error: {
          code: "DAILY_RUN_BUDGET_EXHAUSTED",
          message: "Catalog agent daily run budget exhausted.",
        },
        meta: {
          run_id: runId,
          runs_today: runsToday,
          max_runs_per_day: MAX_RUNS_PER_DAY,
        },
      }, 429);
    }

    runId = await insertRun(adminClient, {
      status: "started",
      sourceDomain,
      authUserId: auth.userId,
      inputSummary: {
        request_id: requestId,
        limit,
        source_domain: sourceDomain,
        include_non_new: includeNonNew,
        dry_run: dryRun,
        budget: budgetSummary(),
      },
      summary: {},
    });

    await insertRunEvent(adminClient, runId, "run_started", {
      request_id: requestId,
      mode: "proposal_only",
      dry_run: dryRun,
    }, auth.userId);

    if (!OPENAI_API_KEY) {
      await failRun(adminClient, runId, "OPENAI_API_KEY is not configured.", {
        reason: "provider_not_configured",
      });
      logLLMUsage(LOG_PREFIX, {
        functionName: FUNCTION_NAME,
        requestId,
        status: "error",
        model: OPENAI_MODEL,
        reason: "provider_not_configured",
      });
      await recordAIUsageEvent({
        supabaseUrl: SUPABASE_URL,
        serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
        functionName: FUNCTION_NAME,
        requestId,
        agentRunId: runId,
        model: OPENAI_MODEL,
        status: "error",
        reason: "provider_not_configured",
      });
      return errorJson(500, "PROVIDER_NOT_CONFIGURED", "OPENAI_API_KEY is not configured.");
    }

    // Fetch beyond the requested LLM limit because recent-proposal dedupe can
    // remove high-priority rows before provider selection.
    const snapshotLimit = Math.min(100, Math.max(limit, limit * 4));
    const snapshot = await fetchSnapshot(adminClient, snapshotLimit, sourceDomain, includeNonNew);
    const workItems = readWorkItems(snapshot);
    const learningContext = await fetchLearningContext(adminClient, workItems);
    const trainingSignalContext = await fetchTrainingSignalContext(adminClient, workItems);
    const externalEvidenceContext = await fetchExternalEvidenceContext(adminClient, workItems);
    const enrichedWorkItems = attachCatalogMatcherHints(attachExternalEvidence(attachTrainingSignals(
      attachLearningMemory(workItems, learningContext),
      trainingSignalContext,
    ), externalEvidenceContext));
    const { eligibleItems: allEligibleItems, skippedRecent } = splitRecentProposalSkips(enrichedWorkItems, RECENT_PROPOSAL_DAYS);
    const eligibleItems = allEligibleItems.slice(0, limit);

    if (eligibleItems.length === 0) {
      const summary = {
        items_in_snapshot: workItems.length,
        items_eligible_before_limit: allEligibleItems.length,
        items_sent_to_llm: 0,
        proposals_created: 0,
        skipped_recent_proposal: skippedRecent.length,
        dry_run: dryRun,
        learning_memory: summarizeLearningContext(learningContext),
        training_signals: summarizeTrainingSignalContext(trainingSignalContext),
        external_evidence: summarizeExternalEvidenceContext(externalEvidenceContext),
        catalog_matcher: summarizeCatalogMatcher(eligibleItems),
        budget: budgetSummary(),
        duration_ms: elapsedMs(startedAt),
      };
      await completeRun(adminClient, runId, summary);
      await insertRunEvent(adminClient, runId, "run_completed_noop", summary, auth.userId);
      return jsonResponseWithStatus({ ok: true, run_id: runId, summary }, 200);
    }

    let providerEligibleItems = eligibleItems;
    const providerAttempt = await invokeProviderWithAdaptiveRetry(
      adminClient,
      requestId,
      runId,
      snapshot,
      eligibleItems,
      learningContext,
      trainingSignalContext,
      externalEvidenceContext,
      auth.userId,
    );
    providerEligibleItems = providerAttempt.eligibleItems;
    let providerResult = providerAttempt.result;
    const allowedTexts = new Set(providerEligibleItems.map((item) => normalizeText(item.normalized_text)));
    const repair = repairProviderOutputForValidation(providerResult.parsed);
    if (repair.repairs.length > 0) {
      providerResult.reasoningTrace = {
        ...providerResult.reasoningTrace,
        output_repairs: repair.repairs,
      };
      await insertRunEvent(adminClient, runId, "provider_output_repaired", {
        repairs: repair.repairs,
      }, auth.userId);
    }
    const validation = validateCatalogAgentTriageOutput(repair.parsed, allowedTexts);
    if (!validation.ok || !validation.value) {
      await failRun(adminClient, runId, "Provider output failed validation.", {
        validation_errors: validation.errors,
        usage: providerResult.usage,
      });
      logLLMUsage(LOG_PREFIX, {
        functionName: FUNCTION_NAME,
        requestId,
        status: "error",
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
        functionName: FUNCTION_NAME,
        requestId,
        agentRunId: runId,
        model: OPENAI_MODEL,
        status: "error",
        providerDurationMs: providerResult.durationMs,
        usage: null,
        estimatedCostUsd: null,
        reason: "validator_failed",
        metadata: {
          aggregate_usage: providerResult.usage,
          aggregate_estimated_cost_usd: estimateCost(providerResult.usage),
          reasoning_mode: REASONING_MODE,
          reasoning_trace: providerResult.reasoningTrace,
        },
      });
      return errorJson(502, "PROVIDER_OUTPUT_INVALID", `Provider output failed validation: ${validation.errors.join(" | ")}`);
    }

    let proposals = normalizeProposalStatuses(validation.value.proposals);
    const genericBaseRepair = repairGovernedGenericBaseReviews(proposals, providerEligibleItems);
    if (genericBaseRepair.repairs.length > 0) {
      proposals = genericBaseRepair.proposals;
      providerResult.reasoningTrace = {
        ...providerResult.reasoningTrace,
        governed_generic_base_repairs: genericBaseRepair.repairs,
      };
      await insertRunEvent(adminClient, runId, "governed_generic_base_repaired", {
        repairs: genericBaseRepair.repairs,
      }, auth.userId);
    }
    let qualityGate = evaluateProposalQuality(proposals, providerEligibleItems, dryRun);
    await insertRunEvent(adminClient, runId, "proposal_quality_gate_evaluated", qualityGate.summary, auth.userId);

    let selfRepairSummary: Record<string, unknown> | null = null;
    if (SELF_REPAIR_ENABLED && qualityGate.issues.some((issue) => issue.level === "error")) {
      const selfRepair = await attemptQualityGateSelfRepair(
        requestId,
        runId,
        snapshot,
        providerEligibleItems,
        learningContext,
        trainingSignalContext,
        proposals,
        qualityGate,
        allowedTexts,
      );
      selfRepairSummary = selfRepair.summary;

      providerResult = {
        ...providerResult,
        durationMs: providerResult.durationMs + selfRepair.durationMs,
        usage: addUsage(providerResult.usage, selfRepair.usage),
        reasoningTrace: {
          ...providerResult.reasoningTrace,
          quality_gate_self_repair: selfRepair.summary,
        },
      };
      proposals = selfRepair.proposals;
      qualityGate = evaluateProposalQuality(proposals, providerEligibleItems, dryRun);

      await insertRunEvent(adminClient, runId, "proposal_quality_gate_self_repair_completed", selfRepair.summary, auth.userId);
      await insertRunEvent(adminClient, runId, "proposal_quality_gate_evaluated_after_self_repair", qualityGate.summary, auth.userId);
    }

    const learningWriter = await handleLearningWriterSuggestions(
      adminClient,
      runId,
      qualityGate,
      proposals,
      providerEligibleItems,
      auth.userId,
    );

    const proposalInsert = dryRun
      ? { insertedIds: [], supersededIds: [] }
      : await insertProposals(adminClient, runId, qualityGate.persistableProposals, providerEligibleItems, repair.parsed, auth.userId);

    const cost = estimateCost(providerResult.usage);
    const summary = {
      items_in_snapshot: workItems.length,
      items_eligible_before_limit: allEligibleItems.length,
      items_eligible_before_retry: eligibleItems.length,
      items_sent_to_llm: providerEligibleItems.length,
      proposals_returned: proposals.length,
      proposals_persistable: qualityGate.persistableProposals.length,
      proposals_blocked_by_quality_gate: qualityGate.blockedProposals.length,
      proposals_created: proposalInsert.insertedIds.length,
      superseded_open_proposals: proposalInsert.supersededIds.length,
      skipped_recent_proposal: skippedRecent.length,
      dry_run: dryRun,
      proposal_quality_gate: qualityGate.summary,
      learning_writer: learningWriter.summary,
      usage: providerResult.usage,
      estimated_cost_usd: cost,
      model: OPENAI_MODEL,
      prompt_version: PROMPT_VERSION,
      learning_memory: summarizeLearningContext(learningContext),
      training_signals: summarizeTrainingSignalContext(trainingSignalContext),
      external_evidence: summarizeExternalEvidenceContext(externalEvidenceContext),
      provider_duration_ms: providerResult.durationMs,
      reasoning_mode: REASONING_MODE,
      reasoning_trace: providerResult.reasoningTrace,
      adaptive_retry: providerAttempt.retrySummary,
      quality_gate_self_repair: selfRepairSummary,
      catalog_matcher: summarizeCatalogMatcher(providerEligibleItems),
      budget: budgetSummary(),
      duration_ms: elapsedMs(startedAt),
    };

    await completeRun(adminClient, runId, summary);
    await insertRunEvent(adminClient, runId, "run_completed", summary, auth.userId);

    logLLMUsage(LOG_PREFIX, {
      functionName: FUNCTION_NAME,
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
      functionName: FUNCTION_NAME,
      requestId,
      agentRunId: runId,
      model: OPENAI_MODEL,
      status: "success",
      providerDurationMs: providerResult.durationMs,
      usage: null,
      estimatedCostUsd: null,
      metadata: {
        proposals_created: proposalInsert.insertedIds.length,
        superseded_open_proposals: proposalInsert.supersededIds.length,
        items_eligible_before_retry: eligibleItems.length,
        items_sent_to_llm: providerEligibleItems.length,
        aggregate_usage: providerResult.usage,
        aggregate_estimated_cost_usd: cost,
        reasoning_mode: REASONING_MODE,
        reasoning_trace: providerResult.reasoningTrace,
      },
    });

    return jsonResponseWithStatus({
      ok: true,
      run_id: runId,
      summary,
      proposals: proposals.map((proposal, index) => ({
        id: proposalInsertedId(proposal, qualityGate.persistableProposals, proposalInsert.insertedIds),
        proposal_type: proposal.proposal_type,
        normalized_text: proposal.normalized_text,
        risk_level: proposal.risk_level,
        status: proposal.status,
        quality_gate_status: qualityGate.acceptedIndexes.has(index) ? "persistable" : "blocked",
      })),
    }, 200);
  } catch (error) {
    console.log(`[${LOG_PREFIX}] phase=unhandled_error request_id=${requestId} error=${String(error)}`);
    if (runId !== null && SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
      try {
        const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
          auth: { persistSession: false, autoRefreshToken: false },
        });
        await failRun(adminClient, runId, String(error), {
          reason: "unhandled_error",
          request_id: requestId,
          duration_ms: elapsedMs(startedAt),
        });
      } catch (failError) {
        console.log(`[${LOG_PREFIX}] phase=failed_to_mark_run_failed request_id=${requestId} error=${String(failError)}`);
      }
    }
    logLLMUsage(LOG_PREFIX, {
      functionName: FUNCTION_NAME,
      requestId,
      status: "error",
      model: OPENAI_MODEL,
      reason: "unhandled_error",
    });
    if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
      await recordAIUsageEvent({
        supabaseUrl: SUPABASE_URL,
        serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
        functionName: FUNCTION_NAME,
        requestId,
        agentRunId: runId,
        model: OPENAI_MODEL,
        status: "error",
        reason: "unhandled_error",
      });
    }
    return errorJson(500, "UNHANDLED_ERROR", String(error));
  }
});

async function countRunsToday(adminClient: ServiceSupabaseClient): Promise<number> {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const { count, error } = await adminClient
    .from("catalog_agent_runs")
    .select("id", { count: "exact", head: true })
    .eq("agent_name", AGENT_NAME)
    .eq("mode", "proposal_only")
    .in("status", ["started", "completed", "failed"])
    .gte("created_at", today.toISOString());

  if (error) {
    throw new Error(`run_budget_check_failed:${error.message}`);
  }

  return count ?? 0;
}

async function insertRun(
  adminClient: ServiceSupabaseClient,
  input: {
    status: "started" | "completed" | "failed" | "cancelled";
    sourceDomain: string | null;
    authUserId: string | null;
    inputSummary: Record<string, unknown>;
    summary: Record<string, unknown>;
  },
): Promise<number> {
  const now = new Date().toISOString();
  const { data, error } = await adminClient
    .from("catalog_agent_runs")
    .insert({
      environment: "dev",
      agent_name: AGENT_NAME,
      agent_version: AGENT_VERSION,
      model: OPENAI_MODEL,
      prompt_version: PROMPT_VERSION,
      mode: "proposal_only",
      source_domain: input.sourceDomain,
      input_summary: input.inputSummary,
      status: input.status,
      started_at: now,
      finished_at: input.status === "started" ? null : now,
      summary: input.summary,
      created_by: input.authUserId,
    })
    .select("id")
    .single();

  if (error || !data?.id) {
    throw new Error(`insert_run_failed:${error?.message ?? "missing id"}`);
  }

  return Number(data.id);
}

async function completeRun(
  adminClient: ServiceSupabaseClient,
  runId: number,
  summary: Record<string, unknown>,
) {
  const { error } = await adminClient
    .from("catalog_agent_runs")
    .update({
      status: "completed",
      finished_at: new Date().toISOString(),
      summary,
      updated_at: new Date().toISOString(),
    })
    .eq("id", runId);

  if (error) {
    throw new Error(`complete_run_failed:${error.message}`);
  }
}

async function failRun(
  adminClient: ServiceSupabaseClient,
  runId: number,
  message: string,
  summary: Record<string, unknown>,
) {
  const { error } = await adminClient
    .from("catalog_agent_runs")
    .update({
      status: "failed",
      finished_at: new Date().toISOString(),
      error_message: message,
      summary,
      updated_at: new Date().toISOString(),
    })
    .eq("id", runId);

  if (error) {
    throw new Error(`fail_run_failed:${error.message}`);
  }
}

async function insertRunEvent(
  adminClient: ServiceSupabaseClient,
  runId: number,
  eventType: string,
  payload: Record<string, unknown>,
  authUserId: string | null,
) {
  const { error } = await adminClient
    .from("catalog_agent_proposal_events")
    .insert({
      run_id: runId,
      event_type: eventType,
      event_payload: payload,
      created_by: authUserId,
    });

  if (error) {
    throw new Error(`insert_run_event_failed:${error.message}`);
  }
}

async function fetchSnapshot(
  adminClient: ServiceSupabaseClient,
  limit: number,
  sourceDomain: string | null,
  includeNonNew: boolean,
): Promise<Record<string, unknown>> {
  const { data, error } = await adminClient.rpc("get_catalog_agent_triage_snapshot", {
    p_limit: limit,
    p_source_domain: sourceDomain,
    p_include_non_new: includeNonNew,
  });

  if (error) {
    throw new Error(`snapshot_failed:${error.message}`);
  }
  if (!isRecord(data)) {
    throw new Error("snapshot_failed:payload_not_object");
  }

  return data;
}

async function fetchLearningContext(
  adminClient: ServiceSupabaseClient,
  eligibleItems: WorkItem[],
): Promise<Record<string, unknown>> {
  const normalizedTexts = eligibleItems
    .map((item) => normalizeText(item.normalized_text))
    .filter((text) => text.length > 0);

  if (normalizedTexts.length === 0) {
    return {};
  }

  const { data, error } = await adminClient.rpc("get_catalog_agent_learning_context", {
    p_normalized_texts: normalizedTexts,
    p_limit_per_term: 3,
  });

  if (error) {
    throw new Error(`learning_context_failed:${error.message}`);
  }
  if (!isRecord(data)) {
    throw new Error("learning_context_failed:payload_not_object");
  }

  return data;
}

async function fetchTrainingSignalContext(
  adminClient: ServiceSupabaseClient,
  eligibleItems: WorkItem[],
): Promise<Record<string, unknown>> {
  const normalizedTexts = Array.from(new Set(eligibleItems
    .flatMap((item) => catalogContextLookupTerms(item))
    .filter((text) => text.length > 0)
  ));

  if (normalizedTexts.length === 0) {
    return {};
  }

  const { data, error } = await adminClient.rpc("get_catalog_agent_training_signal_context", {
    p_normalized_texts: normalizedTexts,
    p_limit_per_term: 3,
  });

  if (error) {
    throw new Error(`training_signal_context_failed:${error.message}`);
  }
  if (!isRecord(data)) {
    throw new Error("training_signal_context_failed:payload_not_object");
  }

  return data;
}

async function fetchExternalEvidenceContext(
  adminClient: ServiceSupabaseClient,
  eligibleItems: WorkItem[],
): Promise<Record<string, unknown>> {
  const normalizedTexts = Array.from(new Set(eligibleItems
    .flatMap((item) => catalogContextLookupTerms(item))
    .filter((text) => text.length > 0)
  ));

  if (normalizedTexts.length === 0) {
    return {};
  }

  const { data, error } = await adminClient.rpc("get_catalog_agent_external_evidence_context", {
    p_normalized_texts: normalizedTexts,
    p_limit_per_term: 4,
  });

  if (error) {
    throw new Error(`external_evidence_context_failed:${error.message}`);
  }
  if (!isRecord(data)) {
    throw new Error("external_evidence_context_failed:payload_not_object");
  }

  return data;
}

const SEMANTIC_PROFILER_SYSTEM_PROMPT = `You are Season's catalog semantic profiler.

Return ONLY valid JSON.
Do not output markdown.
Do not apply catalog changes.

For each work item, analyze culinary identity and variant semantics before any operational decision.
Separate ingredient-existence confidence from canonical-target confidence.
Use recipe context, catalog candidates, and learning memory.

Return this exact JSON shape:
{
  "semantic_profiles": [
    {
      "normalized_text": string,
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
      "needs_risk_review": boolean
    }
  ]
}`;

const RISK_REVIEWER_SYSTEM_PROMPT = `You are Season's catalog risk reviewer.

Return ONLY valid JSON.
Do not output markdown.
Do not apply catalog changes.

Review semantic profiles for catalog safety risk.
Flag cases where aliasing could break recipe semantics, nutrition, allergy, seasonality, fridge matching, shopping matching, or filters.
Prefer conservative guidance when the evidence is incomplete.
Do not convert a clear catalog gap into human review solely because it is medium/high risk.
When a meaningful variant identity is clear and the catalog lacks a child/specialized node, recommend create_canonical draft with auto_apply_eligible=false.
Human review is for unresolved identity or policy ambiguity, not for every missing canonical ingredient.

Return this exact JSON shape:
{
  "risk_reviews": [
    {
      "normalized_text": string,
      "risk_flags": string[],
      "recommended_risk_level": "low" | "medium" | "high" | "critical" | "unknown",
      "decision_guidance": string,
      "blocking_questions": string[]
    }
  ]
}`;

async function invokeProvider(
  adminClient: ServiceSupabaseClient,
  requestId: string,
  runId: number,
  snapshot: Record<string, unknown>,
  eligibleItems: WorkItem[],
  learningContext: Record<string, unknown>,
  trainingSignalContext: Record<string, unknown>,
  externalEvidenceContext: Record<string, unknown>,
): Promise<ProviderInvocationResult> {
  const compactPacket = {
    policy: snapshot.policy,
    learning_memory_policy: readNestedRecord(learningContext, ["runtime_instruction"]),
    training_signal_policy: readNestedRecord(trainingSignalContext, ["runtime_instruction"]),
    external_evidence_policy: readNestedRecord(externalEvidenceContext, ["runtime_instruction"]),
    global_learning_memory: readNestedArray(learningContext, ["global_learnings"]).slice(0, 6),
    work_items: eligibleItems.map(compactWorkItem),
  };

  if (REASONING_MODE === "multi_pass" && MAX_REASONING_CALLS_PER_RUN >= 2) {
    return await invokeMultiPassProvider(adminClient, requestId, runId, compactPacket);
  }

  const result = await invokeProviderRole({
    taskRole: "decision_writer_single_pass",
    systemPrompt: CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
    userPrompt: [
      "Review this Season catalog governance work packet.",
      "Return strict JSON only using the required shape.",
      "Remember: proposal-only. Do not claim to apply changes.",
      JSON.stringify(compactPacket),
    ].join("\n"),
    maxOutputTokens: 5000,
  });

  await recordProviderRoleUsage(requestId, runId, "decision_writer_single_pass", result);
  return {
    parsed: result.parsed,
    durationMs: result.durationMs,
    usage: result.usage,
    reasoningTrace: {
      mode: "single_pass",
      max_reasoning_calls_per_run: MAX_REASONING_CALLS_PER_RUN,
      roles: [roleTrace(result, "decision_writer_single_pass")],
    },
  };
}

async function invokeProviderWithAdaptiveRetry(
  adminClient: ServiceSupabaseClient,
  requestId: string,
  runId: number,
  snapshot: Record<string, unknown>,
  eligibleItems: WorkItem[],
  learningContext: Record<string, unknown>,
  trainingSignalContext: Record<string, unknown>,
  externalEvidenceContext: Record<string, unknown>,
  authUserId: string | null,
): Promise<{
  result: ProviderInvocationResult;
  eligibleItems: WorkItem[];
  retrySummary: Record<string, unknown> | null;
}> {
  try {
    const result = await invokeProvider(
      adminClient,
      requestId,
      runId,
      snapshot,
      eligibleItems,
      learningContext,
      trainingSignalContext,
      externalEvidenceContext,
    );
    return {
      result,
      eligibleItems,
      retrySummary: null,
    };
  } catch (error) {
    if (!isProviderTimeoutError(error) || eligibleItems.length <= 1) {
      throw error;
    }

    const retryLimit = Math.max(1, Math.ceil(eligibleItems.length / 2));
    const retryItems = eligibleItems.slice(0, retryLimit);
    const retrySummary = {
      enabled: true,
      reason: "provider_timeout",
      original_item_count: eligibleItems.length,
      retry_item_count: retryItems.length,
      failed_attempt_error: String(error),
      strategy: "halve_eligible_items_once",
    };

    await insertRunEvent(adminClient, runId, "provider_adaptive_retry_scheduled", retrySummary, authUserId);
    await recordAIUsageEvent({
      supabaseUrl: SUPABASE_URL,
      serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      functionName: FUNCTION_NAME,
      requestId,
      agentRunId: runId,
      model: OPENAI_MODEL,
      status: "error",
      providerDurationMs: error instanceof ProviderInvocationError ? error.durationMs : null,
      reason: "provider_timeout_retry",
      metadata: retrySummary,
    });

    console.log(
      `[${LOG_PREFIX}] phase=provider_adaptive_retry request_id=${requestId} run_id=${runId} ` +
        `original_items=${eligibleItems.length} retry_items=${retryItems.length} error=${String(error)}`,
    );

    const retryResult = await invokeProvider(
      adminClient,
      requestId,
      runId,
      snapshot,
      retryItems,
      learningContext,
      trainingSignalContext,
      externalEvidenceContext,
    );

    retryResult.reasoningTrace = {
      ...retryResult.reasoningTrace,
      adaptive_retry: {
        ...retrySummary,
        retry_status: "succeeded",
      },
    };

    await insertRunEvent(adminClient, runId, "provider_adaptive_retry_succeeded", {
      ...retrySummary,
      retry_usage: retryResult.usage,
      retry_provider_duration_ms: retryResult.durationMs,
    }, authUserId);

    return {
      result: retryResult,
      eligibleItems: retryItems,
      retrySummary: {
        ...retrySummary,
        retry_status: "succeeded",
      },
    };
  }
}

function isProviderTimeoutError(error: unknown): boolean {
  if (!(error instanceof ProviderInvocationError)) return false;
  const message = error.message.toLowerCase();
  return message.includes("aborterror") ||
    message.includes("signal has been aborted") ||
    message.includes("timeout");
}

function repairProviderOutputForValidation(parsed: unknown): {
  parsed: unknown;
  repairs: Record<string, unknown>[];
} {
  if (!isRecord(parsed) || !Array.isArray(parsed.proposals)) {
    return { parsed, repairs: [] };
  }

  const repairs: Record<string, unknown>[] = [];
  const repairedProposals = parsed.proposals.map((proposal, index) => {
    if (!isRecord(proposal)) return proposal;

    const proposalType = String(proposal.proposal_type ?? "");
    const autoApplySupported = ["approve_alias", "add_localization"].includes(proposalType) &&
      String(proposal.risk_level ?? "") === "low";
    let nextProposal: Record<string, unknown> = proposal;

    if (proposal.auto_apply_eligible === true && !autoApplySupported) {
      repairs.push({
        proposal_index: index,
        normalized_text: typeof proposal.normalized_text === "string" ? proposal.normalized_text : null,
        original_proposal_type: proposalType,
        repair: "disable_auto_apply_eligible",
        reason: "auto_apply_not_supported_for_proposal",
      });
      nextProposal = {
        ...nextProposal,
        auto_apply_eligible: false,
      };
    }

    const missingTarget = ["approve_alias", "add_localization"].includes(proposalType) &&
      !nonEmptyString(proposal.target_ingredient_id) &&
      !nonEmptyString(proposal.target_slug);
    const incompleteCanonical = proposalType === "create_canonical" &&
      (!nonEmptyString(proposal.proposed_slug) || !nonEmptyString(proposal.proposed_localized_name));

    if (!missingTarget && !incompleteCanonical) return nextProposal;

    const reason = missingTarget
      ? `${proposalType}_missing_target`
      : "create_canonical_missing_required_fields";
    repairs.push({
      proposal_index: index,
      normalized_text: typeof proposal.normalized_text === "string" ? proposal.normalized_text : null,
      original_proposal_type: proposalType,
      repair: "downgrade_to_needs_human_review",
      reason,
    });

    const blockingQuestions = Array.isArray(proposal.blocking_questions)
      ? proposal.blocking_questions.filter((item): item is string => typeof item === "string")
      : [];
    const evidence = Array.isArray(proposal.evidence) ? [...proposal.evidence] : [];

    return {
      ...nextProposal,
      proposal_type: "needs_human_review",
      target_ingredient_id: null,
      target_slug: null,
      auto_apply_eligible: false,
      status: "needs_human_review",
      risk_level: normalizeRiskForRepair(proposal.risk_level),
      rationale: appendRepairRationale(proposal.rationale, reason),
      evidence: [
        ...evidence,
        {
          type: "provider_output_repair",
          reason,
          original_proposal_type: proposalType,
        },
      ],
      blocking_questions: [
        ...blockingQuestions,
        repairBlockingQuestion(reason),
      ],
    };
  });

  return {
    parsed: {
      ...parsed,
      proposals: repairedProposals,
    },
    repairs,
  };
}

function nonEmptyString(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeRiskForRepair(value: unknown): string {
  return ["low", "medium", "high", "critical", "unknown"].includes(String(value))
    ? String(value)
    : "unknown";
}

function appendRepairRationale(value: unknown, reason: string): string {
  const base = typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : "The provider returned an incomplete actionable proposal.";
  return `${base} Downgraded to human review because ${reason}.`;
}

function repairBlockingQuestion(reason: string): string {
  if (reason === "create_canonical_missing_required_fields") {
    return "Which stable slug and localized display name should be used before creating this canonical ingredient draft?";
  }
  return "Which existing canonical target should this proposal use before it can become actionable?";
}

async function invokeMultiPassProvider(
  adminClient: ServiceSupabaseClient,
  requestId: string,
  runId: number,
  compactPacket: Record<string, unknown>,
): Promise<ProviderInvocationResult> {
  const semanticResult = await invokeProviderRole({
    taskRole: "semantic_profiler",
    systemPrompt: SEMANTIC_PROFILER_SYSTEM_PROMPT,
    userPrompt: [
      "Profile these catalog work items before any decision is made.",
      "Focus on product family, variant identity, substitutability, and catalog implications.",
      JSON.stringify(compactPacket),
    ].join("\n"),
    maxOutputTokens: 5000,
  });
  await recordProviderRoleUsage(requestId, runId, "semantic_profiler", semanticResult);

  const semanticProfiles = normalizeSemanticProfilePass(semanticResult.parsed, compactPacket);
  let aggregateUsage = semanticResult.usage;
  let aggregateDurationMs = semanticResult.durationMs;
  const roleTraces = [roleTrace(semanticResult, "semantic_profiler")];
  let riskReviews: Record<string, unknown>[] = [];

  const riskReviewAllowed = RISK_REVIEW_ENABLED && MAX_REASONING_CALLS_PER_RUN >= 3;
  const hasRiskReviewWork = semanticProfiles.some((profile) => profile.needs_risk_review === true);
  if (riskReviewAllowed && hasRiskReviewWork) {
    const riskResult = await invokeProviderRole({
      taskRole: "risk_reviewer",
      systemPrompt: RISK_REVIEWER_SYSTEM_PROMPT,
      userPrompt: [
        "Review these semantic profiles for catalog safety risk.",
        "Do not decide final actions. Provide risk guidance only.",
        JSON.stringify({
          policy: compactPacket.policy,
          work_items: compactPacket.work_items,
          semantic_profiles: semanticProfiles,
        }),
      ].join("\n"),
      maxOutputTokens: 3500,
    });
    await recordProviderRoleUsage(requestId, runId, "risk_reviewer", riskResult);
    riskReviews = normalizeRiskReviewPass(riskResult.parsed, compactPacket);
    aggregateUsage = addUsage(aggregateUsage, riskResult.usage);
    aggregateDurationMs += riskResult.durationMs;
    roleTraces.push(roleTrace(riskResult, "risk_reviewer"));
  }

  const decisionResult = await invokeProviderRole({
    taskRole: "decision_writer",
    systemPrompt: CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
    userPrompt: [
      "Write the final proposal-only catalog governance decisions.",
      "Use the original work packet plus the semantic profile and risk review context.",
      "Return strict JSON only using the required proposal shape.",
      "Do not apply changes.",
      JSON.stringify({
        ...compactPacket,
        reasoning_context: {
          semantic_profiles: semanticProfiles,
          risk_reviews: riskReviews,
          policy: {
            mode: "multi_pass",
            max_reasoning_calls_per_run: MAX_REASONING_CALLS_PER_RUN,
            risk_review_performed: riskReviews.length > 0,
            instruction: "Semantic profiles and catalog_matcher hints are analysis evidence. Final proposals must still obey the triage contract. Use catalog_matcher.recommended_action, ranked_targets, blocked_actions, and safe_targets before writing final proposals. For safe_existing_target, prefer approve_alias over add_localization when the term is a plural/surface/search form and the target already has a display name. If catalog_matcher.outcome is catalog_gap_candidate and semantic identity is clear, create a canonical draft instead of vague review. If catalog_matcher.recommended_action is create_canonical_if_identity_clear and match_explanation says governed lexical evidence marks a creator-facing generic base term, do not block only because child/specific variants exist; propose the missing base canonical with auto_apply_eligible=false. If catalog_matcher shows ambiguous targets, ask a precise blocking question.",
          },
        },
      }),
    ].join("\n"),
    maxOutputTokens: 5000,
  });
  await recordProviderRoleUsage(requestId, runId, "decision_writer", decisionResult);

  aggregateUsage = addUsage(aggregateUsage, decisionResult.usage);
  aggregateDurationMs += decisionResult.durationMs;
  roleTraces.push(roleTrace(decisionResult, "decision_writer"));

  await insertRunEvent(adminClient, runId, "reasoning_trace_created", {
    mode: "multi_pass",
    semantic_profiles: semanticProfiles.length,
    risk_reviews: riskReviews.length,
    roles: roleTraces,
  }, null);

  return {
    parsed: decisionResult.parsed,
    durationMs: aggregateDurationMs,
    usage: aggregateUsage,
    reasoningTrace: {
      mode: "multi_pass",
      max_reasoning_calls_per_run: MAX_REASONING_CALLS_PER_RUN,
      semantic_profile_count: semanticProfiles.length,
      risk_review_enabled: RISK_REVIEW_ENABLED,
      risk_review_performed: riskReviews.length > 0,
      roles: roleTraces,
    },
  };
}

async function invokeProviderRole(input: {
  taskRole: string;
  systemPrompt: string;
  userPrompt: string;
  maxOutputTokens: number;
}): Promise<ProviderRoleResult> {
  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: input.systemPrompt,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: input.userPrompt,
          },
        ],
      },
    ],
    temperature: 0,
    max_output_tokens: input.maxOutputTokens,
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
      throw new Error(`provider_http_${response.status}:${details}`);
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
    throw new ProviderInvocationError(`${input.taskRole}:${String(error)}`, elapsedMs(startedAt));
  } finally {
    clearTimeout(timeout);
  }
}

async function recordProviderRoleUsage(
  requestId: string,
  runId: number,
  taskRole: string,
  result: ProviderRoleResult,
) {
  logLLMUsage(LOG_PREFIX, {
    functionName: `${FUNCTION_NAME}:${taskRole}`,
    requestId,
    status: "success",
    providerDurationMs: result.durationMs,
    model: OPENAI_MODEL,
    inputTokens: result.usage.inputTokens,
    outputTokens: result.usage.outputTokens,
    totalTokens: result.usage.totalTokens,
  });

  await recordAIUsageEvent({
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
    functionName: FUNCTION_NAME,
    requestId,
    agentRunId: runId,
    model: OPENAI_MODEL,
    status: "success",
    providerDurationMs: result.durationMs,
    usage: result.usage,
    estimatedCostUsd: estimateCost(result.usage),
    metadata: {
      task_role: taskRole,
      reasoning_mode: REASONING_MODE,
    },
  });
}

function roleTrace(result: ProviderRoleResult, taskRole: string): Record<string, unknown> {
  return {
    task_role: taskRole,
    provider_duration_ms: result.durationMs,
    usage: result.usage,
  };
}

function normalizeSemanticProfilePass(
  parsed: unknown,
  compactPacket: Record<string, unknown>,
): Array<Record<string, unknown> & { needs_risk_review: boolean }> {
  const allowedTexts = new Set(compactWorkItemTexts(compactPacket));
  const rawProfiles = readNestedArray(parsed, ["semantic_profiles"]);
  const profileByText = new Map<string, Record<string, unknown> & { needs_risk_review: boolean }>();

  for (const rawProfile of rawProfiles) {
    if (!isRecord(rawProfile)) continue;
    const normalizedText = normalizeText(rawProfile.normalized_text);
    if (!allowedTexts.has(normalizedText)) continue;
    const semanticProfile = sanitizeSemanticProfile(rawProfile.semantic_profile);
    const needsRiskReview = rawProfile.needs_risk_review === true ||
      semanticProfile.is_identity_bearing_variant === true ||
      semanticProfile.substitutability_with_parent !== "full" ||
      semanticProfile.open_questions.length > 0;
    profileByText.set(normalizedText, {
      normalized_text: normalizedText,
      semantic_profile: semanticProfile,
      needs_risk_review: needsRiskReview,
    });
  }

  for (const text of allowedTexts) {
    if (!profileByText.has(text)) {
      profileByText.set(text, {
        normalized_text: text,
        semantic_profile: defaultSemanticProfile(text),
        needs_risk_review: true,
      });
    }
  }

  return [...profileByText.values()];
}

function normalizeRiskReviewPass(
  parsed: unknown,
  compactPacket: Record<string, unknown>,
): Record<string, unknown>[] {
  const allowedTexts = new Set(compactWorkItemTexts(compactPacket));
  const rawReviews = readNestedArray(parsed, ["risk_reviews"]);

  return rawReviews
    .filter(isRecord)
    .map((review) => ({
      normalized_text: normalizeText(review.normalized_text),
      risk_flags: stringArray(review.risk_flags).slice(0, 8),
      recommended_risk_level: allowedRiskLevel(review.recommended_risk_level),
      decision_guidance: stringOrNull(review.decision_guidance) ?? "No specific risk guidance returned.",
      blocking_questions: stringArray(review.blocking_questions).slice(0, 8),
    }))
    .filter((review) => allowedTexts.has(String(review.normalized_text)));
}

function compactWorkItemTexts(compactPacket: Record<string, unknown>): string[] {
  const workItems = Array.isArray(compactPacket.work_items) ? compactPacket.work_items : [];
  return workItems
    .filter(isRecord)
    .map((item) => normalizeText(item.normalized_text))
    .filter((text) => text.length > 0);
}

function sanitizeSemanticProfile(value: unknown): CatalogAgentSemanticProfileOutput {
  const record = isRecord(value) ? value : {};
  return {
    product_family: stringOrNull(record.product_family),
    semantic_category: stringOrNull(record.semantic_category),
    variant_dimension: stringOrNull(record.variant_dimension),
    variant_kind: stringOrNull(record.variant_kind),
    parent_candidate_slug: stringOrNull(record.parent_candidate_slug),
    is_identity_bearing_variant: typeof record.is_identity_bearing_variant === "boolean"
      ? record.is_identity_bearing_variant
      : null,
    substitutability_with_parent: allowedSubstitutability(record.substitutability_with_parent),
    attribute_implications: stringArray(record.attribute_implications).slice(0, 12),
    nutrition_implication: allowedImplication(record.nutrition_implication),
    seasonality_implication: allowedImplication(record.seasonality_implication),
    allergy_implication: allowedImplication(record.allergy_implication),
    fridge_matching_implication: allowedImplication(record.fridge_matching_implication),
    shopping_matching_implication: allowedImplication(record.shopping_matching_implication),
    filter_implication: allowedImplication(record.filter_implication),
    market_or_language_notes: stringOrNull(record.market_or_language_notes),
    confidence_score: boundedConfidence(record.confidence_score),
    evidence: stringArray(record.evidence).slice(0, 12),
    open_questions: stringArray(record.open_questions).slice(0, 8),
  };
}

function defaultSemanticProfile(normalizedText: string): CatalogAgentSemanticProfileOutput {
  return {
    product_family: null,
    semantic_category: null,
    variant_dimension: null,
    variant_kind: null,
    parent_candidate_slug: null,
    is_identity_bearing_variant: null,
    substitutability_with_parent: "unknown",
    attribute_implications: [],
    nutrition_implication: "unknown",
    seasonality_implication: "unknown",
    allergy_implication: "unknown",
    fridge_matching_implication: "unknown",
    shopping_matching_implication: "unknown",
    filter_implication: "unknown",
    market_or_language_notes: null,
    confidence_score: null,
    evidence: [`Semantic profiler did not return a valid profile for ${normalizedText}.`],
    open_questions: ["Run decision writer conservatively because semantic profile is incomplete."],
  };
}

function allowedSubstitutability(value: unknown): CatalogAgentSemanticProfileOutput["substitutability_with_parent"] {
  return CATALOG_AGENT_ALLOWED_SUBSTITUTABILITY.includes(value as CatalogAgentSemanticProfileOutput["substitutability_with_parent"])
    ? value as CatalogAgentSemanticProfileOutput["substitutability_with_parent"]
    : "unknown";
}

function allowedImplication(value: unknown): CatalogAgentSemanticProfileOutput["nutrition_implication"] {
  return CATALOG_AGENT_ALLOWED_IMPLICATION_LEVELS.includes(value as CatalogAgentSemanticProfileOutput["nutrition_implication"])
    ? value as CatalogAgentSemanticProfileOutput["nutrition_implication"]
    : "unknown";
}

function allowedRiskLevel(value: unknown): string {
  return ["low", "medium", "high", "critical", "unknown"].includes(String(value))
    ? String(value)
    : "unknown";
}

function boundedConfidence(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.min(1, Math.max(0, parsed));
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function numberOrNull(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function addUsage(a: TokenUsage, b: TokenUsage): TokenUsage {
  return {
    inputTokens: addNullableNumbers(a.inputTokens, b.inputTokens),
    outputTokens: addNullableNumbers(a.outputTokens, b.outputTokens),
    totalTokens: addNullableNumbers(a.totalTokens, b.totalTokens),
  };
}

function addNullableNumbers(a: number | null, b: number | null): number | null {
  if (a === null && b === null) return null;
  return (a ?? 0) + (b ?? 0);
}

type ProposalQualityIssue = {
  proposal_index: number;
  normalized_text: string;
  code: string;
  level: "error" | "warning";
  message: string;
};

type ProposalQualityGateResult = {
  persistableProposals: CatalogAgentProposalOutput[];
  blockedProposals: CatalogAgentProposalOutput[];
  acceptedIndexes: Set<number>;
  issues: ProposalQualityIssue[];
  summary: Record<string, unknown>;
};

type QualityGateSelfRepairResult = {
  proposals: CatalogAgentProposalOutput[];
  usage: TokenUsage;
  durationMs: number;
  summary: Record<string, unknown>;
};

type LearningWriterSuggestion = {
  normalized_text: string;
  learning_type: string;
  severity: string;
  observed_problem: string;
  corrected_decision: string;
  policy_implication: string;
  evaluation_recommendation: string;
  prompt_recommendation: string;
  validator_recommendation: string;
  original_recommendation: Record<string, unknown>;
};

function evaluateProposalQuality(
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
  dryRun: boolean,
): ProposalQualityGateResult {
  const itemByText = new Map(eligibleItems.map((item) => [normalizeText(item.normalized_text), item]));
  const persistableProposals: CatalogAgentProposalOutput[] = [];
  const blockedProposals: CatalogAgentProposalOutput[] = [];
  const acceptedIndexes = new Set<number>();
  const issues: ProposalQualityIssue[] = [];
  const proposalTextCounts = new Map<string, number>();

  for (const proposal of proposals) {
    const text = normalizeText(proposal.normalized_text);
    if (!text) continue;
    proposalTextCounts.set(text, (proposalTextCounts.get(text) ?? 0) + 1);
  }

  proposals.forEach((proposal, index) => {
    const normalizedText = normalizeText(proposal.normalized_text);
    const proposalIssues = proposalQualityIssues(proposal, index, itemByText.get(normalizedText));
    if ((proposalTextCounts.get(normalizedText) ?? 0) > 1) {
      proposalIssues.push({
        proposal_index: index,
        normalized_text: normalizedText,
        code: "duplicate_proposal_for_work_item",
        level: "error",
        message: "Each work item can have at most one proposal per run.",
      });
    }
    issues.push(...proposalIssues);

    const hasError = proposalIssues.some((issue) => issue.level === "error");
    if (hasError) {
      blockedProposals.push(proposal);
      return;
    }

    acceptedIndexes.add(index);
    persistableProposals.push(proposal);
  });

  return {
    persistableProposals,
    blockedProposals,
    acceptedIndexes,
    issues,
    summary: {
      mode: dryRun ? "dry_run" : "persistence",
      persistence_enabled: PROPOSAL_PERSISTENCE_ENABLED,
      proposals_returned: proposals.length,
      proposals_persistable: persistableProposals.length,
      proposals_blocked: blockedProposals.length,
      error_count: issues.filter((issue) => issue.level === "error").length,
      warning_count: issues.filter((issue) => issue.level === "warning").length,
      issues: issues.slice(0, 25),
    },
  };
}

async function handleLearningWriterSuggestions(
  adminClient: ServiceSupabaseClient,
  runId: number,
  qualityGate: ProposalQualityGateResult,
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
  authUserId: string | null,
): Promise<{ summary: Record<string, unknown>; suggestions: LearningWriterSuggestion[] }> {
  const suggestions = buildLearningWriterSuggestions(qualityGate, proposals, eligibleItems)
    .slice(0, MAX_LEARNING_WRITER_SUGGESTIONS);

  const summary: Record<string, unknown> = {
    enabled: LEARNING_WRITER_ENABLED,
    suggestion_count: suggestions.length,
    persisted_count: 0,
    suggestions: suggestions.slice(0, 10),
  };

  if (suggestions.length === 0) {
    return { summary, suggestions };
  }

  await insertRunEvent(adminClient, runId, "learning_writer_suggestions_created", summary, authUserId);

  if (!LEARNING_WRITER_ENABLED) {
    return { summary, suggestions };
  }

  const rows = suggestions.map((suggestion) => ({
    run_id: runId,
    normalized_text: suggestion.normalized_text,
    learning_type: suggestion.learning_type,
    severity: suggestion.severity,
    status: "needs_review",
    original_recommendation: suggestion.original_recommendation,
    observed_problem: suggestion.observed_problem,
    corrected_decision: suggestion.corrected_decision,
    policy_implication: suggestion.policy_implication,
    evaluation_recommendation: suggestion.evaluation_recommendation,
    prompt_recommendation: suggestion.prompt_recommendation,
    validator_recommendation: suggestion.validator_recommendation,
    created_by: authUserId,
  }));

  const { data, error } = await (adminClient as any)
    .from("catalog_agent_learnings")
    .insert(rows)
    .select("id");

  if (error) {
    throw new Error(`learning_writer_insert_failed:${error.message}`);
  }

  const learningIds = (Array.isArray(data) ? data : [])
    .map((row) => Number((row as Record<string, unknown>).id))
    .filter((id) => Number.isFinite(id));

  return {
    summary: {
      ...summary,
      persisted_count: learningIds.length,
      learning_ids: learningIds,
    },
    suggestions,
  };
}

function buildLearningWriterSuggestions(
  qualityGate: ProposalQualityGateResult,
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
): LearningWriterSuggestion[] {
  const itemByText = new Map(eligibleItems.map((item) => [normalizeText(item.normalized_text), item]));
  const proposalByText = new Map(proposals.map((proposal) => [normalizeText(proposal.normalized_text), proposal]));
  const seen = new Set<string>();
  const suggestions: LearningWriterSuggestion[] = [];

  for (const issue of qualityGate.issues.filter((item) => item.level === "error")) {
    const key = `${issue.normalized_text}|${issue.code}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const proposal = proposalByText.get(issue.normalized_text);
    const item = itemByText.get(issue.normalized_text);
    suggestions.push(learningSuggestionForQualityIssue(issue, proposal, item));
  }

  return suggestions;
}

function learningSuggestionForQualityIssue(
  issue: ProposalQualityIssue,
  proposal: CatalogAgentProposalOutput | undefined,
  item: WorkItem | undefined,
): LearningWriterSuggestion {
  const matcher = readNestedRecord(item, ["context", "catalog_matcher"]);
  const proposalType = proposal?.proposal_type ?? "unknown";
  const learningType = learningTypeForQualityIssue(issue.code);
  const severity = severityForQualityIssue(issue.code);

  return {
    normalized_text: issue.normalized_text,
    learning_type: learningType,
    severity,
    observed_problem: `Quality gate blocked ${proposalType} for "${issue.normalized_text}": ${issue.code}. ${issue.message}`,
    corrected_decision: correctedDecisionForQualityIssue(issue.code, matcher),
    policy_implication: policyImplicationForQualityIssue(issue.code),
    evaluation_recommendation: `Add or update a golden/eval case for "${issue.normalized_text}" covering ${issue.code}.`,
    prompt_recommendation: promptRecommendationForQualityIssue(issue.code),
    validator_recommendation: `Keep runtime/database validators aligned with quality-gate code ${issue.code}.`,
    original_recommendation: {
      proposal_type: proposalType,
      target_slug: proposal?.target_slug ?? null,
      proposed_slug: proposal?.proposed_slug ?? null,
      confidence_score: proposal?.confidence_score ?? null,
      risk_level: proposal?.risk_level ?? null,
      catalog_matcher: matcher,
      quality_gate_issue: issue,
    },
  };
}

function learningTypeForQualityIssue(code: string): string {
  if (code.includes("duplicate") || code.includes("safe_existing_target")) return "duplicate_identity_risk";
  if (code.includes("meaningful_variant")) return "variant_policy";
  if (code.includes("generic_aggregate") || code.includes("recipe_process")) return "state_vs_identity";
  if (code.includes("alias_candidate")) return "alias_policy";
  if (code.includes("canonical")) return "catalog_gap";
  if (code.includes("target") || code.includes("confidence") || code.includes("evidence")) return "prompt_improvement";
  return "other";
}

function severityForQualityIssue(code: string): string {
  if (code.includes("duplicate") || code.includes("generic_aggregate") || code.includes("recipe_process")) return "high";
  if (code.includes("unsafe") || code.includes("critical")) return "high";
  return "medium";
}

function correctedDecisionForQualityIssue(code: string, matcher: Record<string, unknown>): string {
  const outcome = normalizeText(matcher.outcome);
  if (code === "create_canonical_conflicts_with_safe_existing_target") {
    return "Use the catalog matcher safe target for approve_alias/add_localization, or escalate if recipe context contradicts the target.";
  }
  if (code === "generic_aggregate_requires_specific_identity") {
    return "Return needs_human_review unless source evidence identifies a concrete blend, mix, or product identity.";
  }
  if (code === "recipe_process_byproduct_not_canonical") {
    return "Keep process byproducts as recipe context unless the text identifies a reusable ingredient such as broth, stock, or aquafaba.";
  }
  if (outcome === "catalog_gap_candidate") {
    return "If semantic identity is clear, create a canonical draft with complete proposed fields; otherwise ask one blocking question.";
  }
  return "Downgrade to needs_human_review with a precise blocking question until the missing evidence is available.";
}

function policyImplicationForQualityIssue(code: string): string {
  if (code.includes("safe_existing_target")) {
    return "Safe existing targets take precedence over canonical creation to avoid duplicate catalog identity.";
  }
  if (code.includes("generic_aggregate")) {
    return "Broad aggregate/category words are not ingredients unless source evidence names a concrete product identity.";
  }
  if (code.includes("recipe_process")) {
    return "Technique/process liquids are recipe context by default, not catalog identity.";
  }
  return "Quality-gate failures should become advisory learning before future autonomy increases.";
}

function promptRecommendationForQualityIssue(code: string): string {
  if (code.includes("target")) {
    return "Use catalog_matcher.safe_targets and do not invent or ignore target grounding.";
  }
  if (code.includes("canonical")) {
    return "Before create_canonical, check catalog_matcher outcome and explain why no existing target is safe.";
  }
  return "Explain the blocked condition directly in rationale/evidence before proposing an action.";
}

async function attemptQualityGateSelfRepair(
  requestId: string,
  runId: number,
  snapshot: Record<string, unknown>,
  eligibleItems: WorkItem[],
  learningContext: Record<string, unknown>,
  trainingSignalContext: Record<string, unknown>,
  proposals: CatalogAgentProposalOutput[],
  qualityGate: ProposalQualityGateResult,
  allowedTexts: Set<string>,
): Promise<QualityGateSelfRepairResult> {
  const errorIssues = qualityGate.issues.filter((issue) => issue.level === "error");
  const repairTexts = Array.from(new Set(errorIssues.map((issue) => issue.normalized_text).filter(Boolean)))
    .slice(0, MAX_SELF_REPAIR_ITEMS);
  const repairTextSet = new Set(repairTexts);

  if (repairTexts.length === 0) {
    return {
      proposals,
      usage: { inputTokens: null, outputTokens: null, totalTokens: null },
      durationMs: 0,
      summary: {
        enabled: SELF_REPAIR_ENABLED,
        attempted: false,
        reason: "no_error_issues",
      },
    };
  }

  const repairItems = eligibleItems.filter((item) => repairTextSet.has(normalizeText(item.normalized_text)));
  const originalBlockedProposals = proposals.filter((proposal) => repairTextSet.has(normalizeText(proposal.normalized_text)));
  const result = await invokeProviderRole({
    taskRole: "quality_gate_self_repair",
    systemPrompt: CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
    userPrompt: [
      "Repair only the catalog governance proposals that failed the runtime quality gate.",
      "Return strict JSON only using the required proposal shape.",
      "Return exactly one proposal per blocked normalized_text listed in repair_targets.",
      "Do not include unaffected work items.",
      "Do not apply changes.",
      "If an actionable proposal cannot be made safe, return needs_human_review with a concrete blocking question.",
      JSON.stringify({
        policy: snapshot.policy,
        learning_memory_policy: readNestedRecord(learningContext, ["runtime_instruction"]),
        training_signal_policy: readNestedRecord(trainingSignalContext, ["runtime_instruction"]),
        repair_targets: repairTexts,
        quality_gate_issues: errorIssues.filter((issue) => repairTextSet.has(issue.normalized_text)),
        original_blocked_proposals: originalBlockedProposals,
        work_items: repairItems.map(compactWorkItem),
      }),
    ].join("\n"),
    maxOutputTokens: 3500,
  });
  await recordProviderRoleUsage(requestId, runId, "quality_gate_self_repair", result);

  const outputRepair = repairProviderOutputForValidation(result.parsed);
  const validation = validateCatalogAgentTriageOutput(outputRepair.parsed, new Set(repairTexts.filter((text) => allowedTexts.has(text))));
  let repairedProposals = validation.ok && validation.value
    ? normalizeProposalStatuses(validation.value.proposals)
    : [];

  const uniqueRepaired: CatalogAgentProposalOutput[] = [];
  const seenRepairedTexts = new Set<string>();
  for (const proposal of repairedProposals) {
    const text = normalizeText(proposal.normalized_text);
    if (!repairTextSet.has(text) || seenRepairedTexts.has(text)) continue;
    seenRepairedTexts.add(text);
    uniqueRepaired.push(proposal);
  }
  repairedProposals = uniqueRepaired;

  for (const text of repairTexts) {
    if (seenRepairedTexts.has(text)) continue;
    const fallback = originalBlockedProposals.find((proposal) => normalizeText(proposal.normalized_text) === text);
    if (fallback) {
      repairedProposals.push(downgradeProposalToHumanReview(fallback, errorIssues.filter((issue) => issue.normalized_text === text)));
    }
  }

  const mergedProposals = [
    ...proposals.filter((proposal) => !repairTextSet.has(normalizeText(proposal.normalized_text))),
    ...repairedProposals,
  ];

  return {
    proposals: mergedProposals,
    usage: result.usage,
    durationMs: result.durationMs,
    summary: {
      enabled: SELF_REPAIR_ENABLED,
      attempted: true,
      repair_targets: repairTexts,
      original_error_count: errorIssues.length,
      output_repairs: outputRepair.repairs,
      validation_ok: validation.ok,
      validation_errors: validation.errors,
      repaired_proposals_returned: repairedProposals.length,
      fallback_review_count: repairedProposals.filter((proposal) =>
        proposal.evidence.some((evidence) => isRecord(evidence) && evidence.type === "quality_gate_self_repair_fallback")
      ).length,
      usage: result.usage,
      duration_ms: result.durationMs,
    },
  };
}

function downgradeProposalToHumanReview(
  proposal: CatalogAgentProposalOutput,
  issues: ProposalQualityIssue[],
): CatalogAgentProposalOutput {
  const messages = issues.map((issue) => `${issue.code}: ${issue.message}`);
  return {
    ...proposal,
    proposal_type: "needs_human_review",
    risk_level: proposal.risk_level === "low" ? "medium" : proposal.risk_level,
    status: "needs_human_review",
    auto_apply_eligible: false,
    rationale: [
      proposal.rationale,
      "Downgraded to human review by the quality-gate self-repair fallback because the actionable proposal was not safe to persist.",
    ].filter((text) => text.trim().length > 0).join(" "),
    evidence: [
      {
        type: "quality_gate_self_repair_fallback",
        issues: messages,
      },
      ...proposal.evidence,
    ],
    blocking_questions: [
      ...proposal.blocking_questions,
      "Which safe catalog action should replace the blocked proposal?",
    ],
  };
}

function proposalQualityIssues(
  proposal: CatalogAgentProposalOutput,
  index: number,
  item: WorkItem | undefined,
): ProposalQualityIssue[] {
  const issues: ProposalQualityIssue[] = [];
  const normalizedText = normalizeText(proposal.normalized_text);
  const addIssue = (level: "error" | "warning", code: string, message: string) => {
    issues.push({ proposal_index: index, normalized_text: normalizedText, code, level, message });
  };

  const semanticProfile = proposal.semantic_profile;
  const proposalConfidence = typeof proposal.confidence_score === "number" ? proposal.confidence_score : null;
  const semanticConfidence = typeof semanticProfile.confidence_score === "number" ? semanticProfile.confidence_score : null;
  const hasProposalEvidence = Array.isArray(proposal.evidence) && proposal.evidence.length > 0;
  const hasSemanticEvidence = Array.isArray(semanticProfile.evidence) && semanticProfile.evidence.length > 0;
  const hasBlockingQuestions = Array.isArray(proposal.blocking_questions) && proposal.blocking_questions.some((text) => text.trim().length > 0);
  const hasSemanticOpenQuestions = Array.isArray(semanticProfile.open_questions) && semanticProfile.open_questions.some((text) => text.trim().length > 0);
  const hasConcreteEvidence = hasProposalEvidence || hasSemanticEvidence;

  if (!item) {
    addIssue("error", "missing_work_item", "Proposal text is not present in the eligible work packet.");
  }

  if (!hasConcreteEvidence) {
    addIssue("error", "missing_evidence", "Persisted proposals require proposal evidence or semantic-profile evidence.");
  }

  if (proposal.rationale.trim().length < 40) {
    addIssue("warning", "short_rationale", "Rationale is valid but too short for comfortable operator review.");
  }

  if (["unknown", "critical"].includes(proposal.risk_level) && proposal.proposal_type !== "needs_human_review") {
    addIssue("error", "unsafe_actionable_risk", "Unknown or critical risk can only be persisted as needs_human_review.");
  }

  if (proposal.auto_apply_eligible && proposal.risk_level !== "low") {
    addIssue("error", "auto_apply_requires_low_risk", "auto_apply_eligible requires low risk.");
  }

  if (proposal.proposal_type === "approve_alias" || proposal.proposal_type === "add_localization") {
    if (proposalConfidence === null || proposalConfidence < 0.85) {
      addIssue("error", "low_actionable_confidence", "Alias/localization proposals require confidence_score >= 0.85.");
    }
    if (semanticConfidence === null || semanticConfidence < 0.65) {
      addIssue("error", "low_semantic_confidence", "Alias/localization proposals require semantic_profile.confidence_score >= 0.65.");
    }
    if (!contextContainsTarget(item, proposal)) {
      addIssue("error", "target_not_grounded_in_context", "Target slug or id must appear in the work packet context.");
    }
  }

  if (proposal.proposal_type === "add_localization") {
    if (!normalizeText(proposal.proposed_localized_name) || !normalizeText(proposal.proposed_language_code)) {
      addIssue("error", "localization_fields_missing", "add_localization requires proposed_localized_name and proposed_language_code.");
    }
  }

  if (proposal.proposal_type === "create_canonical") {
    if (catalogMatcherOutcome(item) === "safe_existing_target") {
      addIssue(
        "error",
        "create_canonical_conflicts_with_safe_existing_target",
        "A safe existing catalog target is grounded by the catalog matcher; create_canonical would risk a duplicate identity.",
      );
    }
    if (hasTrainingSignal(item, "catalog_alias_candidate") && !itemHasSafeTarget(item) && !hasCreatorFacingGenericBasePolicy(item)) {
      addIssue(
        "error",
        "alias_candidate_requires_target_before_canonical_creation",
        "catalog_alias_candidate signals require safe target matching/review before create_canonical can be persisted.",
      );
    }
    if (isGenericAggregateCanonicalCandidate(proposal, item)) {
      addIssue(
        "error",
        "generic_aggregate_requires_specific_identity",
        "Broad aggregate/category terms require evidence of a concrete product, blend, mix, or identity-bearing aggregate before create_canonical can be persisted.",
      );
    }
    if (isRecipeProcessByproductCanonicalCandidate(proposal, item)) {
      addIssue(
        "error",
        "recipe_process_byproduct_not_canonical",
        "Recipe-process liquids/byproducts require evidence of a reusable ingredient identity before create_canonical can be persisted.",
      );
    }
    if (proposalConfidence === null || proposalConfidence < 0.75) {
      addIssue("error", "low_create_canonical_confidence", "create_canonical proposals require confidence_score >= 0.75.");
    }
    if (semanticConfidence === null || semanticConfidence < 0.7) {
      addIssue("error", "low_create_canonical_semantic_confidence", "create_canonical proposals require semantic_profile.confidence_score >= 0.7.");
    }
    if (!isSafeProposedSlug(proposal.proposed_slug)) {
      addIssue("error", "unsafe_proposed_slug", "create_canonical proposed_slug must be lowercase ASCII snake_case.");
    }
    if (!normalizeText(proposal.proposed_localized_name) || !normalizeText(proposal.proposed_language_code)) {
      addIssue("error", "canonical_fields_missing", "create_canonical requires proposed_localized_name and proposed_language_code.");
    }
    if (normalizeText(proposal.target_ingredient_id) || normalizeText(proposal.target_slug)) {
      addIssue("error", "canonical_should_not_have_target", "create_canonical must not set an existing target.");
    }
    if (!normalizeText(semanticProfile.product_family) && !normalizeText(semanticProfile.semantic_category)) {
      addIssue("error", "missing_semantic_family", "create_canonical requires product_family or semantic_category in the semantic profile.");
    }
    if (proposal.auto_apply_eligible) {
      addIssue("error", "canonical_never_auto_apply", "create_canonical must never be auto_apply_eligible.");
    }
  }

  if (proposal.proposal_type === "needs_human_review") {
    if (!hasBlockingQuestions && !hasSemanticOpenQuestions) {
      addIssue("error", "review_without_question", "needs_human_review must contain a concrete blocking or open question.");
    }
  }

  if (proposal.proposal_type === "ignore_noise") {
    if (proposalConfidence === null || proposalConfidence < 0.8) {
      addIssue("error", "low_ignore_noise_confidence", "ignore_noise requires confidence_score >= 0.8.");
    }
  }

  return issues;
}

function hasTrainingSignal(item: WorkItem | undefined, trainingSignal: string): boolean {
  if (!item) return false;
  return readNestedArray(item, ["context", "training_signals"]).some((signal) =>
    normalizeText(isRecord(signal) ? signal.training_signal : null) === trainingSignal
  );
}

function itemHasSafeTarget(item: WorkItem | undefined): boolean {
  if (!item) return false;
  const context = readNestedRecord(item, ["context"]);
  const coverageBlocker = readNestedRecord(item, ["coverage_blocker"]);
  const matcher = readNestedRecord(context, ["catalog_matcher"]);
  return readNestedArray(matcher, ["safe_targets"]).length > 0 ||
    readNestedArray(context, ["possible_canonical_matches"]).length > 0 ||
    readNestedArray(context, ["existing_alias_matches"]).length > 0 ||
    normalizeText(coverageBlocker.canonical_candidate_ingredient_id).length > 0 ||
    normalizeText(coverageBlocker.canonical_candidate_slug).length > 0;
}

function catalogMatcherOutcome(item: WorkItem | undefined): string {
  if (!item) return "";
  return normalizeText(readNestedRecord(item, ["context", "catalog_matcher"]).outcome);
}

function isGenericAggregateCanonicalCandidate(
  proposal: CatalogAgentProposalOutput,
  item: WorkItem | undefined,
): boolean {
  const terms = new Set([
    normalizeText(proposal.normalized_text),
    normalizeText(proposal.proposed_slug).replaceAll("_", " "),
    normalizeText(proposal.proposed_localized_name),
    normalizeText(proposal.semantic_profile.product_family),
    normalizeText(proposal.semantic_profile.semantic_category),
  ].filter((text) => text.length > 0));

  const hasGenericAggregateTerm = Array.from(terms).some((term) => GENERIC_AGGREGATE_TERMS.has(term));
  if (!hasGenericAggregateTerm) return false;

  const evidenceText = [
    item?.normalized_text,
    ...readNestedArray(item, ["observation", "raw_examples"]),
    readNestedRecord(item, ["observation"]).latest_example,
    readNestedRecord(item, ["context", "recipe_context"]).title,
    ...readNestedArray(item, ["context", "recipe_context", "nearby_ingredients"]),
    ...readNestedArray(item, ["context", "recipe_context", "step_snippets"]),
  ]
    .map(normalizeText)
    .filter((text) => text.length > 0)
    .join(" ");

  return !CONCRETE_AGGREGATE_QUALIFIERS.some((qualifier) => evidenceText.includes(qualifier));
}

function isRecipeProcessByproductCanonicalCandidate(
  proposal: CatalogAgentProposalOutput,
  item: WorkItem | undefined,
): boolean {
  const terms = new Set([
    normalizeText(proposal.normalized_text),
    normalizeText(proposal.proposed_slug).replaceAll("_", " "),
    normalizeText(proposal.proposed_localized_name),
  ].filter((text) => text.length > 0));

  const hasProcessByproductTerm = Array.from(terms).some((term) => RECIPE_PROCESS_BYPRODUCT_TERMS.has(term));
  if (!hasProcessByproductTerm) return false;

  const evidenceText = [
    ...readNestedArray(item, ["observation", "raw_examples"]),
    readNestedRecord(item, ["observation"]).latest_example,
    readNestedRecord(item, ["context", "recipe_context"]).title,
    ...readNestedArray(item, ["context", "recipe_context", "nearby_ingredients"]),
    ...readNestedArray(item, ["context", "recipe_context", "step_snippets"]),
  ]
    .map(normalizeText)
    .filter((text) => text.length > 0)
    .join(" ");

  return !REUSABLE_LIQUID_IDENTITY_TERMS.some((term) => evidenceText.includes(term));
}

function proposalInsertedId(
  proposal: CatalogAgentProposalOutput,
  persistableProposals: CatalogAgentProposalOutput[],
  insertedProposalIDs: number[],
): number | null {
  const persistableIndex = persistableProposals.indexOf(proposal);
  return persistableIndex >= 0 ? (insertedProposalIDs[persistableIndex] ?? null) : null;
}

function contextContainsTarget(item: WorkItem | undefined, proposal: CatalogAgentProposalOutput): boolean {
  if (!item) return false;
  const targetSlug = normalizeText(proposal.target_slug);
  const targetId = normalizeText(proposal.target_ingredient_id);
  if (!targetSlug && !targetId) return false;

  const candidateRecords = [
    ...readNestedArray(item, ["context", "catalog_matcher", "safe_targets"]),
    ...readNestedArray(item, ["context", "catalog_matcher", "candidate_targets"]),
    ...readNestedArray(item, ["context", "possible_canonical_matches"]),
    ...readNestedArray(item, ["context", "existing_alias_matches"]),
    readNestedRecord(item, ["coverage_blocker"]),
  ].filter(isRecord);

  return candidateRecords.some((candidate) => {
    const candidateSlugs = [
      candidate.slug,
      candidate.ingredient_slug,
      candidate.canonical_candidate_slug,
      candidate.parent_slug,
    ].map(normalizeText);
    const candidateIds = [
      candidate.ingredient_id,
      candidate.target_ingredient_id,
      candidate.canonical_candidate_ingredient_id,
    ].map(normalizeText);
    return (targetSlug && candidateSlugs.includes(targetSlug)) || (targetId && candidateIds.includes(targetId));
  });
}

function isSafeProposedSlug(value: string | null): boolean {
  return typeof value === "string" && /^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(value.trim());
}

async function insertProposals(
  adminClient: ServiceSupabaseClient,
  runId: number,
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
  rawAgentOutput: unknown,
  authUserId: string | null,
): Promise<{ insertedIds: number[]; supersededIds: number[] }> {
  if (proposals.length === 0) return { insertedIds: [], supersededIds: [] };

  const itemByText = new Map(eligibleItems.map((item) => [normalizeText(item.normalized_text), item]));
  const proposalTexts = Array.from(new Set(proposals.map((proposal) => normalizeText(proposal.normalized_text)).filter(Boolean)));
  const supersededIds = await supersedeOpenProposalsForTexts(adminClient, runId, proposalTexts, authUserId);
  const rows = proposals.map((proposal) => {
    const item = itemByText.get(normalizeText(proposal.normalized_text));
    return {
      run_id: runId,
      proposal_type: proposal.proposal_type,
      normalized_text: normalizeText(proposal.normalized_text),
      source_observation_ids: observationIDsForItem(item),
      target_ingredient_id: emptyToNull(proposal.target_ingredient_id),
      target_slug: emptyToNull(proposal.target_slug),
      proposed_slug: emptyToNull(proposal.proposed_slug),
      proposed_alias_text: emptyToNull(proposal.proposed_alias_text),
      proposed_localized_name: emptyToNull(proposal.proposed_localized_name),
      proposed_language_code: emptyToNull(proposal.proposed_language_code),
      confidence_score: proposal.confidence_score,
      risk_level: proposal.risk_level,
      auto_apply_eligible: proposal.auto_apply_eligible,
      rationale: proposal.rationale,
      evidence: evidenceWithSemanticProfile(proposal),
      blocking_questions: proposal.blocking_questions,
      raw_agent_output: rawAgentOutput,
      status: proposal.status,
      created_by: authUserId,
    };
  });

  const { data, error } = await adminClient
    .from("catalog_agent_proposals")
    .insert(rows)
    .select("id");

  if (error) {
    throw new Error(`insert_proposals_failed:${error.message}`);
  }

  const ids = (Array.isArray(data) ? data : [])
    .map((row) => Number((row as Record<string, unknown>).id))
    .filter((id) => Number.isFinite(id));

  if (ids.length > 0) {
    const { error: eventError } = await adminClient
      .from("catalog_agent_proposal_events")
      .insert(ids.map((id) => ({
        proposal_id: id,
        run_id: runId,
        event_type: "proposal_created",
        event_payload: { source: FUNCTION_NAME },
        created_by: authUserId,
      })));

    if (eventError) {
      throw new Error(`insert_proposal_events_failed:${eventError.message}`);
    }
  }

  return { insertedIds: ids, supersededIds };
}

async function supersedeOpenProposalsForTexts(
  adminClient: ServiceSupabaseClient,
  runId: number,
  normalizedTexts: string[],
  authUserId: string | null,
): Promise<number[]> {
  if (!SUPERSEDE_OPEN_PROPOSALS || normalizedTexts.length === 0) return [];

  const openStatuses = [
    "draft",
    "needs_human_review",
    "queued_for_validation",
    "validated",
    "failed_validation",
  ];

  const { data, error } = await adminClient
    .from("catalog_agent_proposals")
    .select("id, normalized_text, proposal_type, status")
    .in("normalized_text", normalizedTexts)
    .in("status", openStatuses);

  if (error) {
    throw new Error(`select_open_proposals_for_supersede_failed:${error.message}`);
  }

  const rows = Array.isArray(data) ? data : [];
  const ids = rows
    .map((row) => Number((row as Record<string, unknown>).id))
    .filter((id) => Number.isFinite(id));

  if (ids.length === 0) return [];

  const { error: updateError } = await adminClient
    .from("catalog_agent_proposals")
    .update({ status: "superseded" })
    .in("id", ids);

  if (updateError) {
    throw new Error(`supersede_open_proposals_failed:${updateError.message}`);
  }

  const { error: eventError } = await adminClient
    .from("catalog_agent_proposal_events")
    .insert(ids.map((id) => ({
      proposal_id: id,
      run_id: runId,
      event_type: "proposal_superseded_by_agent_refresh",
      event_payload: {
        source: FUNCTION_NAME,
        reason: "newer_persistable_proposal_for_same_normalized_text",
      },
      created_by: authUserId,
    })));

  if (eventError) {
    throw new Error(`insert_supersede_events_failed:${eventError.message}`);
  }

  return ids;
}

type WorkItem = Record<string, unknown>;

function readWorkItems(snapshot: Record<string, unknown>): WorkItem[] {
  return Array.isArray(snapshot.work_items)
    ? snapshot.work_items.filter(isRecord)
    : [];
}

function splitRecentProposalSkips(items: WorkItem[], recentDays: number): {
  eligibleItems: WorkItem[];
  skippedRecent: WorkItem[];
} {
  const cutoff = Date.now() - recentDays * 24 * 60 * 60 * 1000;
  const eligibleItems: WorkItem[] = [];
  const skippedRecent: WorkItem[] = [];

  for (const item of items) {
    const proposals = readNestedArray(item, ["context", "previous_agent_proposals"]);
    const hasRecentProposal = proposals.some((proposal) => {
      if (!isRecord(proposal) || typeof proposal.created_at !== "string") return false;
      const status = normalizeText(proposal.status);
      if (["failed_validation", "rejected", "superseded"].includes(status)) return false;
      const timestamp = Date.parse(proposal.created_at);
      return Number.isFinite(timestamp) && timestamp >= cutoff && !hasLearningMemoryAfter(item, timestamp);
    });

    if (hasRecentProposal) {
      skippedRecent.push(item);
    } else {
      eligibleItems.push(item);
    }
  }

  return { eligibleItems, skippedRecent };
}

function hasLearningMemoryAfter(item: WorkItem, proposalTimestamp: number): boolean {
  const learnings = readNestedArray(item, ["context", "relevant_learning_memory"]);

  return learnings.some((learning) => {
    if (!isRecord(learning) || typeof learning.created_at !== "string") return false;
    const learningTimestamp = Date.parse(learning.created_at);
    return Number.isFinite(learningTimestamp) && learningTimestamp > proposalTimestamp;
  });
}

function compactWorkItem(item: WorkItem): Record<string, unknown> {
  return {
    normalized_text: item.normalized_text,
    observation: pickRecord(readNestedRecord(item, ["observation"]), [
      "observation_id",
      "occurrence_count",
      "latest_example",
      "raw_examples",
      "language_code",
      "source",
      "latest_recipe_id",
      "status",
    ]),
    priority: readNestedRecord(item, ["priority"]),
    coverage_blocker: readNestedRecord(item, ["coverage_blocker"]),
    context: {
      recipe_context: readNestedRecord(item, ["context", "recipe_context"]),
      semantic_disambiguation: readNestedRecord(item, ["context", "semantic_disambiguation"]),
      catalog_matcher: readNestedRecord(item, ["context", "catalog_matcher"]),
      possible_canonical_matches: readNestedArray(item, ["context", "possible_canonical_matches"]).slice(0, 8),
      existing_alias_matches: readNestedArray(item, ["context", "existing_alias_matches"]).slice(0, 8),
      previous_catalog_decisions: readNestedArray(item, ["context", "previous_catalog_decisions"]).slice(0, 3),
      previous_agent_proposals: readNestedArray(item, ["context", "previous_agent_proposals"]).slice(0, 3),
      relevant_learning_memory: readNestedArray(item, ["context", "relevant_learning_memory"]).slice(0, 3),
      training_signals: readNestedArray(item, ["context", "training_signals"]).slice(0, 3),
      external_catalog_evidence: readNestedArray(item, ["context", "external_catalog_evidence"]).slice(0, 4),
    },
    agent_instruction: item.agent_instruction,
  };
}

function attachLearningMemory(items: WorkItem[], learningContext: Record<string, unknown>): WorkItem[] {
  const termLearnings = readNestedRecord(learningContext, ["term_learnings"]);

  return items.map((item) => {
    const normalizedText = normalizeText(item.normalized_text);
    const relevantMemory = Array.isArray(termLearnings[normalizedText])
      ? (termLearnings[normalizedText] as unknown[])
      : [];

    return {
      ...item,
      context: {
        ...readNestedRecord(item, ["context"]),
        relevant_learning_memory: relevantMemory,
      },
    };
  });
}

function attachTrainingSignals(items: WorkItem[], trainingSignalContext: Record<string, unknown>): WorkItem[] {
  const termSignals = readNestedRecord(trainingSignalContext, ["term_training_signals"]);

  return items.map((item) => {
    const relevantSignals = uniqueTrainingSignals(catalogContextLookupTerms(item)
      .flatMap((term) => Array.isArray(termSignals[term]) ? (termSignals[term] as unknown[]) : []));

    return {
      ...item,
      context: {
        ...readNestedRecord(item, ["context"]),
        training_signals: relevantSignals,
      },
    };
  });
}

function attachExternalEvidence(items: WorkItem[], externalEvidenceContext: Record<string, unknown>): WorkItem[] {
  const termEvidence = readNestedRecord(externalEvidenceContext, ["term_external_evidence"]);

  return items.map((item) => {
    const relevantEvidence = uniqueExternalEvidence(catalogContextLookupTerms(item)
      .flatMap((term) => Array.isArray(termEvidence[term]) ? (termEvidence[term] as unknown[]) : []));

    return {
      ...item,
      context: {
        ...readNestedRecord(item, ["context"]),
        external_catalog_evidence: relevantEvidence,
      },
    };
  });
}

function attachCatalogMatcherHints(items: WorkItem[]): WorkItem[] {
  return items.map((item) => ({
    ...item,
    context: {
      ...readNestedRecord(item, ["context"]),
      catalog_matcher: buildCatalogMatcherHint(item),
    },
  }));
}

function buildCatalogMatcherHint(item: WorkItem): Record<string, unknown> {
  const normalizedText = normalizeText(item.normalized_text);
  const possibleMatches = readNestedArray(item, ["context", "possible_canonical_matches"]).filter(isRecord);
  const aliasMatches = readNestedArray(item, ["context", "existing_alias_matches"]).filter(isRecord);
  const coverageBlocker = readNestedRecord(item, ["coverage_blocker"]);
  const trainingSignals = readNestedArray(item, ["context", "training_signals"]).filter(isRecord);
  const exactCanonicalTargets = possibleMatches
    .filter((match) => isExactCanonicalMatch(match))
    .map((match) => matcherTargetFromCanonical(match))
    .filter(isRecord);
  const exactAliasTargets = aliasMatches
    .filter((match) => isExactActiveAliasMatch(match, normalizedText))
    .map((match) => matcherTargetFromAlias(match))
    .filter(isRecord);
  const coverageTarget = matcherTargetFromCoverageBlocker(coverageBlocker);
  const safeTargets = uniqueMatcherTargets([
    ...exactAliasTargets,
    ...exactCanonicalTargets,
    ...(coverageTarget ? [coverageTarget] : []),
  ]);
  const candidateTargets = uniqueMatcherTargets([
    ...possibleMatches.map(matcherTargetFromCanonical).filter(isRecord),
    ...aliasMatches.map(matcherTargetFromAlias).filter(isRecord),
    ...(coverageTarget ? [coverageTarget] : []),
  ]);
  const blockers = matcherBlockers(item, safeTargets, candidateTargets);
  const rankedTargets = rankMatcherTargets(item, safeTargets, candidateTargets);
  const hasGenericBaseLookup = hasGovernedGenericBaseLookup(item);
  const hasAliasCandidateSignal = trainingSignals.some((signal) =>
    normalizeText(signal.training_signal) === "catalog_alias_candidate"
  );
  const likelyIngredient = itemLooksLikeIngredient(item);
  const hasCreatorGenericBase = isCreatorFacingGenericBaseCandidate(
    item,
    safeTargets,
    candidateTargets,
    likelyIngredient,
    hasGenericBaseLookup,
  );

  let outcome = "review_required";
  let confidence = 0.45;
  let rationale = "Catalog matcher found insufficient deterministic evidence for an actionable target.";

  if (safeTargets.length === 1 && blockers.length === 0) {
    outcome = "safe_existing_target";
    confidence = 0.9;
    rationale = "Exactly one active exact target is grounded in aliases, canonical matches, or coverage blocker context.";
  } else if (hasCreatorGenericBase) {
    outcome = "catalog_gap_candidate";
    confidence = hasGenericBaseLookup ? 0.72 : 0.66;
    rationale = hasGenericBaseLookup
      ? "Governed lexical evidence marks this as a creator-facing generic base term. Existing specific child variants are supporting context, not blockers for a missing base identity."
      : "The term is a concrete creator-facing generic base ingredient. Existing specific child variants are supporting context, not blockers for a missing base identity.";
  } else if (safeTargets.length > 1 || candidateTargets.length > 1) {
    outcome = "ambiguous_existing_targets";
    confidence = 0.7;
    rationale = "Multiple plausible catalog targets exist; the LLM must not invent a target and should ask for precise missing evidence if context does not disambiguate.";
  } else if (hasAliasCandidateSignal && safeTargets.length === 0) {
    outcome = "needs_target_matching";
    confidence = 0.75;
    rationale = "Training signals suggest alias-like text, but no safe existing target is grounded in the packet.";
  } else if (candidateTargets.length === 1) {
    outcome = "candidate_target_requires_semantic_check";
    confidence = 0.65;
    rationale = "One candidate target exists, but it is not an exact active match and requires semantic validation before it becomes actionable.";
  } else if (likelyIngredient) {
    outcome = "catalog_gap_candidate";
    confidence = 0.6;
    rationale = "The term looks like a recipe ingredient and no safe target is grounded, so create_canonical may be appropriate if semantic identity is clear.";
  }

  const actionAdvice = matcherActionAdvice({
    outcome,
    blockers,
    rankedTargets,
    hasAliasCandidateSignal,
    hasGenericBaseLookup,
    hasCreatorGenericBase,
    likelyIngredient,
  });

  return {
    version: "catalog_matcher_v1",
    normalized_text: normalizedText,
    outcome,
    confidence_score: confidence,
    matcher_confidence: confidence,
    safe_targets: safeTargets.slice(0, 5),
    candidate_targets: candidateTargets.slice(0, 8),
    ranked_targets: rankedTargets.slice(0, 8),
    blockers,
    blocked_actions: actionAdvice.blocked_actions,
    recommended_action: actionAdvice.recommended_action,
    rationale,
    match_explanation: actionAdvice.match_explanation,
    training_signal_count: trainingSignals.length,
    lexical_candidate_terms: readNestedArray(item, ["context", "lexical_candidate_terms"]).slice(0, 8),
  };
}

function hasGovernedGenericBaseLookup(item: WorkItem | undefined): boolean {
  if (!item) return false;
  return readNestedArray(item, ["context", "lexical_candidate_terms"])
    .filter(isRecord)
    .some((term) =>
      normalizeText(term.expansion_source) === "governed_generic_base_lookup" ||
      normalizeText(term.source) === "governed_generic_base_lookup"
    );
}

function isExactCanonicalMatch(match: Record<string, unknown>): boolean {
  return ["it_name_exact", "en_name_exact", "slug_exact", "compact_key", "it_name_lexical_variant"].includes(
    normalizeText(match.match_reason),
  ) && normalizeText(match.quality_status) === "active";
}

function isExactActiveAliasMatch(match: Record<string, unknown>, normalizedText: string): boolean {
  return normalizeText(match.normalized_alias_text) === normalizedText &&
    match.is_active === true &&
    ["approved", "active"].includes(normalizeText(match.status));
}

function matcherTargetFromCanonical(match: Record<string, unknown>): Record<string, unknown> {
  return {
    source: "possible_canonical_matches",
    ingredient_id: stringOrNull(match.ingredient_id),
    slug: stringOrNull(match.slug),
    parent_slug: stringOrNull(match.parent_slug),
    match_reason: stringOrNull(match.match_reason),
    quality_status: stringOrNull(match.quality_status),
    specificity_rank: numberOrNull(match.specificity_rank),
    variant_kind: stringOrNull(match.variant_kind),
    it_name: stringOrNull(match.it_name),
    en_name: stringOrNull(match.en_name),
  };
}

function matcherTargetFromAlias(match: Record<string, unknown>): Record<string, unknown> {
  return {
    source: "existing_alias_matches",
    ingredient_id: stringOrNull(match.ingredient_id),
    slug: stringOrNull(match.ingredient_slug),
    alias_text: stringOrNull(match.alias_text),
    normalized_alias_text: stringOrNull(match.normalized_alias_text),
    confidence_score: numberOrNull(match.confidence_score),
    status: stringOrNull(match.status),
    is_active: match.is_active === true,
  };
}

function matcherTargetFromCoverageBlocker(blocker: Record<string, unknown>): Record<string, unknown> | null {
  const ingredientId = stringOrNull(blocker.canonical_candidate_ingredient_id);
  const slug = stringOrNull(blocker.canonical_candidate_slug);
  if (!ingredientId && !slug) return null;
  return {
    source: "coverage_blocker",
    ingredient_id: ingredientId,
    slug,
    name: stringOrNull(blocker.canonical_candidate_name),
    likely_fix_type: stringOrNull(blocker.likely_fix_type),
    recommended_next_action: stringOrNull(blocker.recommended_next_action),
  };
}

function uniqueMatcherTargets(targets: Record<string, unknown>[]): Record<string, unknown>[] {
  const seen = new Set<string>();
  const unique: Record<string, unknown>[] = [];
  for (const target of targets) {
    const key = [
      normalizeText(target.ingredient_id),
      normalizeText(target.slug),
      normalizeText(target.source),
    ].join("|");
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(target);
  }
  return unique;
}

function rankMatcherTargets(
  item: WorkItem,
  safeTargets: Record<string, unknown>[],
  candidateTargets: Record<string, unknown>[],
): Record<string, unknown>[] {
  const safeKeys = new Set(safeTargets.map(matcherTargetKey));
  return uniqueMatcherTargets([...safeTargets, ...candidateTargets])
    .map((target) => {
      const score = matcherTargetScore(item, target, safeKeys.has(matcherTargetKey(target)));
      return {
        ...target,
        score,
        explanation: matcherTargetExplanation(target, score),
      };
    })
    .sort((a, b) => (numberOrNull(b.score) ?? 0) - (numberOrNull(a.score) ?? 0));
}

function matcherTargetKey(target: Record<string, unknown>): string {
  return [
    normalizeText(target.ingredient_id),
    normalizeText(target.slug),
  ].join("|");
}

function matcherTargetScore(
  item: WorkItem,
  target: Record<string, unknown>,
  isSafeTarget: boolean,
): number {
  const normalizedText = normalizeText(item.normalized_text);
  const source = normalizeText(target.source);
  const matchReason = normalizeText(target.match_reason);
  let score = isSafeTarget ? 80 : 40;

  if (source === "existing_alias_matches") score += 18;
  if (source === "coverage_blocker") score += 14;
  if (source === "possible_canonical_matches") score += 10;
  if (matchReason.includes("exact")) score += 20;
  if (matchReason.includes("lexical")) score += 12;
  if (matchReason.includes("compact")) score += 8;
  if (normalizeText(target.slug) === normalizedText) score += 8;
  if (normalizeText(target.normalized_alias_text) === normalizedText) score += 10;
  if (normalizeText(target.quality_status) === "active") score += 8;
  if (target.is_active === true) score += 8;
  score += Math.round((numberOrNull(target.confidence_score) ?? 0) * 10);

  const rank = numberOrNull(target.specificity_rank);
  if (rank !== null) score += Math.max(0, 8 - Math.min(rank, 8));

  return Math.max(0, Math.min(100, score));
}

function matcherTargetExplanation(target: Record<string, unknown>, score: number): string {
  const source = stringOrNull(target.source) ?? "unknown_source";
  const reason = stringOrNull(target.match_reason) ?? stringOrNull(target.likely_fix_type) ?? "context_match";
  const slug = stringOrNull(target.slug) ?? "unknown_target";
  return `${slug} ranked ${score}/100 from ${source} via ${reason}.`;
}

function matcherActionAdvice(input: {
  outcome: string;
  blockers: string[];
  rankedTargets: Record<string, unknown>[];
  hasAliasCandidateSignal: boolean;
  hasGenericBaseLookup: boolean;
  hasCreatorGenericBase: boolean;
  likelyIngredient: boolean;
}): { recommended_action: string; blocked_actions: string[]; match_explanation: string } {
  const blockedActions = new Set<string>();
  for (const blocker of input.blockers) {
    if (blocker.includes("generic_aggregate") || blocker.includes("recipe_process")) {
      blockedActions.add("create_canonical");
    }
    if (blocker.includes("multiple")) {
      blockedActions.add("approve_alias");
      blockedActions.add("add_localization");
    }
  }

  if (input.outcome === "safe_existing_target" && input.rankedTargets.length > 0) {
    blockedActions.add("create_canonical");
    blockedActions.add("add_localization_when_display_name_already_exists");
    return {
      recommended_action: "approve_alias",
      blocked_actions: Array.from(blockedActions),
      match_explanation: "A single grounded existing target is available; treat the observed text as an alias/search surface unless the display localization is actually missing.",
    };
  }

  if (input.outcome === "catalog_gap_candidate" && input.likelyIngredient) {
    if (input.hasAliasCandidateSignal) blockedActions.add("create_canonical_without_target_review");
    return {
      recommended_action: input.hasAliasCandidateSignal && !input.hasCreatorGenericBase
        ? "needs_human_review"
        : "create_canonical_if_identity_clear",
      blocked_actions: Array.from(blockedActions),
      match_explanation: input.hasAliasCandidateSignal && !input.hasCreatorGenericBase
        ? "Corpus evidence suggests alias-like text, but no safe target is grounded; request matching evidence before canonical creation."
        : input.hasGenericBaseLookup
        ? "Governed lexical evidence marks this as a creator-facing generic base term; create a base canonical draft if no exact base target exists, while keeping specific forms as variants."
        : input.hasCreatorGenericBase
        ? "Concrete creator-facing generic base term; create a base canonical draft if no exact base target exists, while keeping specific forms as variants."
        : "No safe target is grounded and the term looks ingredient-like; canonical creation is acceptable only if semantic identity is clear.",
    };
  }

  if (input.outcome === "candidate_target_requires_semantic_check") {
    return {
      recommended_action: "needs_human_review_or_approve_alias_after_semantic_check",
      blocked_actions: Array.from(blockedActions),
      match_explanation: "One candidate exists but is not a deterministic exact target; require semantic evidence before action.",
    };
  }

  return {
    recommended_action: "needs_human_review",
    blocked_actions: Array.from(blockedActions),
    match_explanation: "Matcher evidence is insufficient or ambiguous; ask a concrete blocking question.",
  };
}

function matcherBlockers(
  item: WorkItem,
  safeTargets: Record<string, unknown>[],
  candidateTargets: Record<string, unknown>[],
): string[] {
  const blockers: string[] = [];
  const normalizedText = normalizeText(item.normalized_text);
  if (GENERIC_AGGREGATE_TERMS.has(normalizedText)) {
    blockers.push("generic_aggregate_requires_specific_identity");
  }
  if (RECIPE_PROCESS_BYPRODUCT_TERMS.has(normalizedText)) {
    blockers.push("recipe_process_byproduct_not_canonical");
  }
  if (safeTargets.length > 1) {
    blockers.push("multiple_safe_targets");
  } else if (
    safeTargets.length === 0 &&
    candidateTargets.length > 1 &&
    !hasCreatorFacingGenericBasePolicy(item) &&
    !isCreatorFacingGenericBaseCandidate(item, safeTargets, candidateTargets, itemLooksLikeIngredient(item), hasGovernedGenericBaseLookup(item))
  ) {
    blockers.push("multiple_candidate_targets");
  }
  return blockers;
}

function isCreatorFacingGenericBaseCandidate(
  item: WorkItem,
  safeTargets: Record<string, unknown>[],
  candidateTargets: Record<string, unknown>[],
  likelyIngredient: boolean,
  hasGenericBaseLookup: boolean,
): boolean {
  if (!likelyIngredient || safeTargets.length > 0) return false;
  const normalizedText = normalizeText(item.normalized_text);
  if (!normalizedText || GENERIC_AGGREGATE_TERMS.has(normalizedText) || RECIPE_PROCESS_BYPRODUCT_TERMS.has(normalizedText)) {
    return false;
  }

  if (hasGenericBaseLookup) return true;

  const tokenCount = normalizedText.split(/\s+/).filter(Boolean).length;
  if (tokenCount > 2) return false;

  const lexicalTerms = readNestedArray(item, ["context", "lexical_candidate_terms"])
    .map((term) => normalizeText(isRecord(term) ? term.term : null))
    .filter(Boolean);
  const hasExactLexicalSelf = lexicalTerms.includes(normalizedText);
  if (!hasExactLexicalSelf) return false;

  // If the catalog only exposes child/specific candidates, keep the generic base
  // as a valid catalog gap instead of forcing a human-review loop.
  return candidateTargets.length > 1 && candidateTargets.every((target) => {
    const source = normalizeText(target.source);
    const matchReason = normalizeText(target.match_reason);
    const targetSlug = normalizeText(target.slug);
    return source !== "existing_alias_matches" &&
      targetSlug !== normalizedText &&
      !matchReason.includes("exact");
  });
}

function itemLooksLikeIngredient(item: WorkItem): boolean {
  const observation = readNestedRecord(item, ["observation"]);
  const recipeContext = readNestedRecord(item, ["context", "recipe_context"]);
  return normalizeText(observation.latest_example).length > 0 ||
    readNestedArray(observation, ["raw_examples"]).length > 0 ||
    readNestedArray(recipeContext, ["matched_ingredient_rows"]).length > 0 ||
    readNestedArray(recipeContext, ["nearby_ingredients"]).length > 0;
}

function catalogContextLookupTerms(item: WorkItem): string[] {
  const terms = new Set<string>();
  addCatalogContextLookupTerm(terms, item.normalized_text);

  for (const lexicalCandidate of readNestedArray(item, ["context", "lexical_candidate_terms"])) {
    addCatalogContextLookupTerm(terms, isRecord(lexicalCandidate) ? lexicalCandidate.term : null);
  }

  return Array.from(terms);
}

function addCatalogContextLookupTerm(terms: Set<string>, value: unknown): void {
  const normalized = normalizeText(value);
  const simplified = simplifyCatalogSignalText(value);
  if (normalized.length > 0) terms.add(normalized);
  if (simplified.length > 0) terms.add(simplified);
}

function uniqueTrainingSignals(signals: unknown[]): unknown[] {
  const seen = new Set<string>();
  const unique: unknown[] = [];

  for (const signal of signals) {
    const key = stableSignalKey(signal);
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(signal);
  }

  return unique;
}

function uniqueExternalEvidence(evidenceItems: unknown[]): unknown[] {
  const seen = new Set<string>();
  const unique: unknown[] = [];

  for (const evidence of evidenceItems) {
    const key = stableExternalEvidenceKey(evidence);
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(evidence);
  }

  return unique;
}

function stableSignalKey(signal: unknown): string {
  if (!isRecord(signal)) return JSON.stringify(signal);
  const id = signal.id;
  if (typeof id === "number" || typeof id === "string") return `id:${id}`;
  return [
    signal.training_signal,
    signal.source,
    signal.occurrence_count,
  ].map((value) => String(value ?? "")).join("|");
}

function stableExternalEvidenceKey(evidence: unknown): string {
  if (!isRecord(evidence)) return JSON.stringify(evidence);
  const id = evidence.id;
  if (typeof id === "number" || typeof id === "string") return `id:${id}`;
  return [
    evidence.source_key,
    evidence.source_record_id,
    evidence.evidence_type,
    evidence.evidence_summary,
  ].map((value) => String(value ?? "")).join("|");
}

function summarizeLearningContext(learningContext: Record<string, unknown>): Record<string, unknown> {
  const metadata = readNestedRecord(learningContext, ["metadata"]);
  const globalLearnings = readNestedArray(learningContext, ["global_learnings"]);
  const termLearnings = readNestedRecord(learningContext, ["term_learnings"]);
  return {
    source: metadata.source ?? null,
    terms_requested: metadata.terms_requested ?? null,
    terms_with_learning: metadata.terms_with_learning ?? null,
    global_learning_count: globalLearnings.length,
    term_learning_count: Object.values(termLearnings)
      .filter(Array.isArray)
      .reduce((total, learnings) => total + learnings.length, 0),
  };
}

function summarizeTrainingSignalContext(trainingSignalContext: Record<string, unknown>): Record<string, unknown> {
  const metadata = readNestedRecord(trainingSignalContext, ["metadata"]);
  const termSignals = readNestedRecord(trainingSignalContext, ["term_training_signals"]);
  return {
    source: metadata.source ?? null,
    terms_requested: metadata.terms_requested ?? null,
    terms_with_training_signals: metadata.terms_with_training_signals ?? null,
    training_signal_count: Object.values(termSignals)
      .filter(Array.isArray)
      .reduce((total, signals) => total + signals.length, 0),
  };
}

function summarizeExternalEvidenceContext(externalEvidenceContext: Record<string, unknown>): Record<string, unknown> {
  const metadata = readNestedRecord(externalEvidenceContext, ["metadata"]);
  const termEvidence = readNestedRecord(externalEvidenceContext, ["term_external_evidence"]);
  return {
    source: metadata.source ?? null,
    terms_requested: metadata.terms_requested ?? null,
    terms_with_external_evidence: metadata.terms_with_external_evidence ?? null,
    external_evidence_count: Object.values(termEvidence)
      .filter(Array.isArray)
      .reduce((total, evidence) => total + evidence.length, 0),
  };
}

function summarizeCatalogMatcher(items: WorkItem[]): Record<string, unknown> {
  const counts = new Map<string, number>();
  let safeTargetCount = 0;
  let blockerCount = 0;

  for (const item of items) {
    const matcher = readNestedRecord(item, ["context", "catalog_matcher"]);
    const outcome = normalizeText(matcher.outcome) || "missing";
    counts.set(outcome, (counts.get(outcome) ?? 0) + 1);
    safeTargetCount += readNestedArray(matcher, ["safe_targets"]).length;
    blockerCount += readNestedArray(matcher, ["blockers"]).length;
  }

  return {
    version: "catalog_matcher_v1",
    items: items.length,
    outcome_counts: Object.fromEntries(counts.entries()),
    safe_target_count: safeTargetCount,
    blocker_count: blockerCount,
    recommended_actions: items.reduce((accumulator: Record<string, number>, item) => {
      const action = normalizeText(readNestedRecord(item, ["context", "catalog_matcher"]).recommended_action) || "missing";
      accumulator[action] = (accumulator[action] ?? 0) + 1;
      return accumulator;
    }, {}),
  };
}

function normalizeProposalStatuses(proposals: CatalogAgentProposalOutput[]): CatalogAgentProposalOutput[] {
  return proposals.map((proposal) => {
    const actionableAutoApplyType = ["approve_alias", "add_localization"].includes(proposal.proposal_type);
    return {
      ...proposal,
      normalized_text: normalizeText(proposal.normalized_text),
      auto_apply_eligible: proposal.risk_level === "low" && actionableAutoApplyType
        ? proposal.auto_apply_eligible
        : false,
      status: proposal.proposal_type === "needs_human_review" ? "needs_human_review" : "draft",
    };
  });
}

function repairGovernedGenericBaseReviews(
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
): { proposals: CatalogAgentProposalOutput[]; repairs: Record<string, unknown>[] } {
  const itemByText = new Map(eligibleItems.map((item) => [normalizeText(item.normalized_text), item]));
  const repairs: Record<string, unknown>[] = [];

  const repairedProposals = proposals.map((proposal) => {
    const item = itemByText.get(normalizeText(proposal.normalized_text));
    if (!shouldRepairGovernedGenericBaseReview(proposal, item)) return proposal;

    const proposedSlug = governedGenericBaseSlug(item) ?? safeSlugFromText(proposal.normalized_text);
    if (!proposedSlug) return proposal;

    repairs.push({
      normalized_text: normalizeText(proposal.normalized_text),
      original_proposal_type: proposal.proposal_type,
      repair: "needs_human_review_to_create_canonical",
      reason: "governed_generic_base_lookup",
      proposed_slug: proposedSlug,
    });

    const semanticProfile: CatalogAgentSemanticProfileOutput = {
      ...proposal.semantic_profile,
      product_family: proposal.semantic_profile.product_family ?? proposedSlug.replaceAll("_", " "),
      semantic_category: proposal.semantic_profile.semantic_category ?? "ingredient",
      parent_candidate_slug: null,
      substitutability_with_parent: proposal.semantic_profile.substitutability_with_parent === "unknown"
        ? "partial"
        : proposal.semantic_profile.substitutability_with_parent,
      confidence_score: Math.max(proposal.semantic_profile.confidence_score ?? 0, 0.72),
      evidence: [
        ...proposal.semantic_profile.evidence,
        "Governed lexical evidence marks this as a creator-facing generic base term; child variants support the product family but do not block a missing base canonical draft.",
      ],
      open_questions: proposal.semantic_profile.open_questions.filter((question) =>
        !normalizeText(question).includes("which specific")
      ),
    };

    return normalizeProposalStatuses([{
      ...proposal,
      proposal_type: "create_canonical",
      target_ingredient_id: null,
      target_slug: null,
      proposed_slug: proposedSlug,
      proposed_alias_text: null,
      proposed_localized_name: localizedNameForGenericBase(proposal.normalized_text),
      proposed_language_code: "it",
      confidence_score: Math.max(proposal.confidence_score ?? 0, 0.78),
      risk_level: proposal.risk_level === "critical" || proposal.risk_level === "unknown" ? "medium" : proposal.risk_level,
      auto_apply_eligible: false,
      status: "draft",
      semantic_profile: semanticProfile,
      rationale: [
        proposal.rationale,
        "Deterministic governed-generic-base repair: the matcher identified a missing creator-facing base ingredient, so this should become a canonical draft instead of a vague human-review item.",
      ].filter((text) => text.trim().length > 0).join(" "),
      evidence: [
        ...proposal.evidence,
        {
          type: "governed_generic_base_repair",
          matcher_outcome: readNestedRecord(item, ["context", "catalog_matcher"]).outcome,
          matcher_recommended_action: readNestedRecord(item, ["context", "catalog_matcher"]).recommended_action,
          proposed_slug: proposedSlug,
        },
      ],
      blocking_questions: [],
    }])[0];
  });

  return { proposals: repairedProposals, repairs };
}

function shouldRepairGovernedGenericBaseReview(
  proposal: CatalogAgentProposalOutput,
  item: WorkItem | undefined,
): boolean {
  if (!item) return false;
  if (proposal.proposal_type !== "needs_human_review") return false;
  if (!hasCreatorFacingGenericBasePolicy(item)) return false;

  const matcher = readNestedRecord(item, ["context", "catalog_matcher"]);
  return normalizeText(matcher.outcome) === "catalog_gap_candidate" &&
    normalizeText(matcher.recommended_action) === "create_canonical_if_identity_clear" &&
    readNestedArray(matcher, ["safe_targets"]).length === 0 &&
    !readNestedArray(matcher, ["blocked_actions"]).map(normalizeText).includes("create_canonical");
}

function hasCreatorFacingGenericBasePolicy(item: WorkItem | undefined): boolean {
  if (!item) return false;
  if (hasGovernedGenericBaseLookup(item)) return true;
  const matcher = readNestedRecord(item, ["context", "catalog_matcher"]);
  return normalizeText(matcher.outcome) === "catalog_gap_candidate" &&
    normalizeText(matcher.recommended_action) === "create_canonical_if_identity_clear" &&
    normalizeText(matcher.match_explanation).includes("creator-facing generic base");
}

function governedGenericBaseSlug(item: WorkItem | undefined): string | null {
  if (!item) return null;
  for (const term of readNestedArray(item, ["context", "lexical_candidate_terms"]).filter(isRecord)) {
    const source = normalizeText(term.expansion_source) || normalizeText(term.source);
    if (source !== "governed_generic_base_lookup") continue;
    const slug = safeSlugFromText(term.term);
    if (slug) return slug;
  }
  return null;
}

function safeSlugFromText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const slug = value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");
  return isSafeProposedSlug(slug) ? slug : null;
}

function localizedNameForGenericBase(value: string): string {
  const normalized = normalizeText(value);
  if (!normalized) return "Ingrediente";
  return normalized
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function evidenceWithSemanticProfile(proposal: CatalogAgentProposalOutput): unknown[] {
  const existingEvidence = Array.isArray(proposal.evidence) ? proposal.evidence : [];
  return [
    {
      type: "semantic_profile",
      semantic_profile: proposal.semantic_profile,
    },
    ...existingEvidence,
  ];
}

function observationIDsForItem(item: WorkItem | undefined): number[] {
  if (!item) return [];
  const observation = readNestedRecord(item, ["observation"]);
  const id = Number(observation.observation_id);
  return Number.isFinite(id) && id > 0 ? [Math.floor(id)] : [];
}

function estimateCost(usage: TokenUsage): number | null {
  if (INPUT_COST_PER_1M_USD === null && OUTPUT_COST_PER_1M_USD === null) {
    return null;
  }
  const input = usage.inputTokens ?? 0;
  const output = usage.outputTokens ?? 0;
  const inputCost = INPUT_COST_PER_1M_USD === null ? 0 : (input / 1_000_000) * INPUT_COST_PER_1M_USD;
  const outputCost = OUTPUT_COST_PER_1M_USD === null ? 0 : (output / 1_000_000) * OUTPUT_COST_PER_1M_USD;
  return Number((inputCost + outputCost).toFixed(8));
}

function budgetSummary(): Record<string, unknown> {
  return {
    max_items_per_run: MAX_ITEMS_PER_RUN,
    max_runs_per_day: MAX_RUNS_PER_DAY,
    recent_proposal_days: RECENT_PROPOSAL_DAYS,
    provider_timeout_ms: PROVIDER_TIMEOUT_MS,
    proposal_persistence_enabled: PROPOSAL_PERSISTENCE_ENABLED,
    supersede_open_proposals: SUPERSEDE_OPEN_PROPOSALS,
    reasoning_mode: REASONING_MODE,
    max_reasoning_calls_per_run: MAX_REASONING_CALLS_PER_RUN,
    risk_review_enabled: RISK_REVIEW_ENABLED,
    self_repair_enabled: SELF_REPAIR_ENABLED,
    max_self_repair_items: MAX_SELF_REPAIR_ITEMS,
    learning_writer_enabled: LEARNING_WRITER_ENABLED,
    max_learning_writer_suggestions: MAX_LEARNING_WRITER_SUGGESTIONS,
    input_cost_per_1m_usd: INPUT_COST_PER_1M_USD,
    output_cost_per_1m_usd: OUTPUT_COST_PER_1M_USD,
  };
}

function hasOperatorToken(request: Request): boolean {
  if (!OPERATOR_TOKEN) return false;
  const provided = request.headers.get("x-season-catalog-agent-token")?.trim() ?? "";
  return provided.length > 0 && provided === OPERATOR_TOKEN;
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

function readNestedRecord(value: unknown, path: string[]): Record<string, unknown> {
  let cursor: unknown = value;
  for (const key of path) {
    if (!isRecord(cursor)) return {};
    cursor = cursor[key];
  }
  return isRecord(cursor) ? cursor : {};
}

function readNestedArray(value: unknown, path: string[]): unknown[] {
  let cursor: unknown = value;
  for (const key of path) {
    if (!isRecord(cursor)) return [];
    cursor = cursor[key];
  }
  return Array.isArray(cursor) ? cursor : [];
}

function pickRecord(record: Record<string, unknown>, keys: string[]): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const key of keys) {
    output[key] = record[key] ?? null;
  }
  return output;
}

function emptyToNull(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeNullableText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeText(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function simplifyCatalogSignalText(value: unknown): string {
  if (typeof value !== "string") return "";
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function boundedInteger(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, Math.floor(value)));
}

function nonNegativeNumberEnv(name: string): number | null {
  const raw = Deno.env.get(name);
  if (!raw || raw.trim().length === 0) return null;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return parsed;
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
