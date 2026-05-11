import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
import {
  CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
  type CatalogAgentProposalOutput,
  validateCatalogAgentTriageOutput,
} from "./llm_contract.ts";

interface AgentRunRequest {
  limit?: number;
  source_domain?: string | null;
  include_non_new?: boolean;
  dry_run?: boolean;
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

const FUNCTION_NAME = "run-catalog-agent-triage";
const LOG_PREFIX = "SEASON_CATALOG_AGENT";
const AGENT_NAME = "catalog-governance-agent";
const AGENT_VERSION = "proposal-only-v2-learning-memory";
const PROMPT_VERSION = "catalog-agent-triage-v2-learning-memory";

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
const RECENT_PROPOSAL_DAYS = boundedInteger(numberEnv("CATALOG_AGENT_RECENT_PROPOSAL_DAYS", 7), 1, 90);
const PROVIDER_TIMEOUT_MS = boundedInteger(numberEnv("CATALOG_AGENT_PROVIDER_TIMEOUT_MS", 20000), 1000, 60000);
const INPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_AGENT_INPUT_COST_PER_1M_USD");
const OUTPUT_COST_PER_1M_USD = nonNegativeNumberEnv("CATALOG_AGENT_OUTPUT_COST_PER_1M_USD");

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
      return errorJson(500, "PROVIDER_NOT_CONFIGURED", "OPENAI_API_KEY is not configured.");
    }

    const snapshot = await fetchSnapshot(adminClient, limit, sourceDomain, includeNonNew);
    const workItems = readWorkItems(snapshot).slice(0, limit);
    const learningContext = await fetchLearningContext(adminClient, workItems);
    const enrichedWorkItems = attachLearningMemory(workItems, learningContext);
    const { eligibleItems, skippedRecent } = splitRecentProposalSkips(enrichedWorkItems, RECENT_PROPOSAL_DAYS);

    if (eligibleItems.length === 0) {
      const summary = {
        items_in_snapshot: workItems.length,
        items_sent_to_llm: 0,
        proposals_created: 0,
        skipped_recent_proposal: skippedRecent.length,
        dry_run: dryRun,
        learning_memory: summarizeLearningContext(learningContext),
        budget: budgetSummary(),
        duration_ms: elapsedMs(startedAt),
      };
      await completeRun(adminClient, runId, summary);
      await insertRunEvent(adminClient, runId, "run_completed_noop", summary, auth.userId);
      return jsonResponseWithStatus({ ok: true, run_id: runId, summary }, 200);
    }

    const providerResult = await invokeProvider(snapshot, eligibleItems, learningContext);
    const allowedTexts = new Set(eligibleItems.map((item) => normalizeText(item.normalized_text)));
    const validation = validateCatalogAgentTriageOutput(providerResult.parsed, allowedTexts);
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
      return errorJson(502, "PROVIDER_OUTPUT_INVALID", `Provider output failed validation: ${validation.errors.join(" | ")}`);
    }

    const proposals = normalizeProposalStatuses(validation.value.proposals);
    const insertedProposalIDs = dryRun
      ? []
      : await insertProposals(adminClient, runId, proposals, eligibleItems, providerResult.parsed, auth.userId);

    const cost = estimateCost(providerResult.usage);
    const summary = {
      items_in_snapshot: workItems.length,
      items_sent_to_llm: eligibleItems.length,
      proposals_returned: proposals.length,
      proposals_created: insertedProposalIDs.length,
      skipped_recent_proposal: skippedRecent.length,
      dry_run: dryRun,
      usage: providerResult.usage,
      estimated_cost_usd: cost,
      model: OPENAI_MODEL,
      prompt_version: PROMPT_VERSION,
      learning_memory: summarizeLearningContext(learningContext),
      provider_duration_ms: providerResult.durationMs,
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

    return jsonResponseWithStatus({
      ok: true,
      run_id: runId,
      summary,
      proposals: proposals.map((proposal, index) => ({
        id: insertedProposalIDs[index] ?? null,
        proposal_type: proposal.proposal_type,
        normalized_text: proposal.normalized_text,
        risk_level: proposal.risk_level,
        status: proposal.status,
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
    return errorJson(500, "UNHANDLED_ERROR", String(error));
  }
});

async function countRunsToday(adminClient: ReturnType<typeof createClient>): Promise<number> {
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
  adminClient: ReturnType<typeof createClient>,
  input: {
    status: "started" | "completed" | "failed" | "cancelled";
    sourceDomain: string | null;
    authUserId: string | null;
    inputSummary: Record<string, unknown>;
    summary: Record<string, unknown>;
  },
): Promise<number> {
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
      finished_at: input.status === "started" ? null : new Date().toISOString(),
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
  adminClient: ReturnType<typeof createClient>,
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
  adminClient: ReturnType<typeof createClient>,
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
  adminClient: ReturnType<typeof createClient>,
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
  adminClient: ReturnType<typeof createClient>,
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
  adminClient: ReturnType<typeof createClient>,
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

async function invokeProvider(
  snapshot: Record<string, unknown>,
  eligibleItems: WorkItem[],
  learningContext: Record<string, unknown>,
): Promise<ProviderInvocationResult> {
  const compactPacket = {
    policy: snapshot.policy,
    learning_memory_policy: readNestedRecord(learningContext, ["runtime_instruction"]),
    global_learning_memory: readNestedArray(learningContext, ["global_learnings"]).slice(0, 6),
    work_items: eligibleItems.map(compactWorkItem),
  };

  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: CATALOG_AGENT_TRIAGE_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: [
              "Review this Season catalog governance work packet.",
              "Return strict JSON only using the required shape.",
              "Remember: proposal-only. Do not claim to apply changes.",
              JSON.stringify(compactPacket),
            ].join("\n"),
          },
        ],
      },
    ],
    temperature: 0,
    max_output_tokens: 4000,
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
    throw new ProviderInvocationError(String(error), elapsedMs(startedAt));
  } finally {
    clearTimeout(timeout);
  }
}

async function insertProposals(
  adminClient: ReturnType<typeof createClient>,
  runId: number,
  proposals: CatalogAgentProposalOutput[],
  eligibleItems: WorkItem[],
  rawAgentOutput: unknown,
  authUserId: string | null,
): Promise<number[]> {
  if (proposals.length === 0) return [];

  const itemByText = new Map(eligibleItems.map((item) => [normalizeText(item.normalized_text), item]));
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
      evidence: proposal.evidence,
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
      possible_canonical_matches: readNestedArray(item, ["context", "possible_canonical_matches"]).slice(0, 8),
      existing_alias_matches: readNestedArray(item, ["context", "existing_alias_matches"]).slice(0, 8),
      previous_catalog_decisions: readNestedArray(item, ["context", "previous_catalog_decisions"]).slice(0, 3),
      previous_agent_proposals: readNestedArray(item, ["context", "previous_agent_proposals"]).slice(0, 3),
      relevant_learning_memory: readNestedArray(item, ["context", "relevant_learning_memory"]).slice(0, 3),
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

function normalizeProposalStatuses(proposals: CatalogAgentProposalOutput[]): CatalogAgentProposalOutput[] {
  return proposals.map((proposal) => ({
    ...proposal,
    normalized_text: normalizeText(proposal.normalized_text),
    auto_apply_eligible: proposal.risk_level === "low" ? proposal.auto_apply_eligible : false,
    status: proposal.risk_level === "low" ? proposal.status : "needs_human_review",
  }));
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
