import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveCatalogAdminOrServiceRole } from "../_shared/auth.ts";
import {
  env,
  fetchWithTimeout,
  jsonResponseWithStatus,
  numberEnv,
} from "../_shared/edge.ts";
import { requestIdFromHeaders } from "../_shared/observability.ts";

interface OrchestratorRequest {
  worker_name?: string;
  action?: string;
  limit?: number;
  source_domain?: string | null;
  risk_ceiling?: string;
  budget_limit_usd?: number | null;
  dry_run?: boolean;
  debug?: boolean;
}

interface WorkerJobRow {
  id: number;
  agent_run_id: number | null;
  worker_name: string;
  worker_function: string;
  requested_action: string;
  status: string;
  item_limit: number;
  dry_run: boolean;
}

const FUNCTION_NAME = "run-catalog-agent-orchestrator";
const LOG_PREFIX = "SEASON_CATALOG_ORCHESTRATOR";
const AGENT_NAME = "catalog-governance-agent";
const AGENT_VERSION = "worker-orchestrator-v1";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");
const OPERATOR_TOKEN = env("CATALOG_AGENT_OPERATOR_TOKEN");

const ORCHESTRATOR_ENABLED = env("CATALOG_AGENT_ORCHESTRATOR_ENABLED", "false").toLowerCase() === "true";
const MAX_WORKER_ITEMS_PER_RUN = boundedInteger(numberEnv("CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN", 5), 1, 25);
const WORKER_TIMEOUT_MS = boundedInteger(numberEnv("CATALOG_AGENT_WORKER_TIMEOUT_MS", 60000), 5000, 180000);

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  const startedAt = performance.now();
  let agentRunId: number | null = null;
  let workerJobId: number | null = null;

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

    if (!ORCHESTRATOR_ENABLED) {
      return errorJson(403, "ORCHESTRATOR_DISABLED", "Catalog agent orchestrator is disabled.");
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

    let payload: OrchestratorRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const workerName = normalizeText(payload.worker_name) ?? "enrichment_draft_batch";
    if (workerName !== "enrichment_draft_batch") {
      return errorJson(422, "UNSUPPORTED_WORKER", "Only enrichment_draft_batch is supported in v1.");
    }

    const action = normalizeText(payload.action) ?? "run";
    const limit = boundedInteger(Number(payload.limit ?? MAX_WORKER_ITEMS_PER_RUN), 1, MAX_WORKER_ITEMS_PER_RUN);
    const sourceDomain = normalizeNullableText(payload.source_domain);
    const riskCeiling = normalizeRiskCeiling(payload.risk_ceiling);
    if (payload.dry_run === true) {
      return errorJson(422, "DRY_RUN_NOT_SUPPORTED", "enrichment_draft_batch does not yet support dry_run.");
    }
    const dryRun = false;
    const debug = payload.debug === true;
    const budgetLimitUsd = nonNegativeNumberOrNull(payload.budget_limit_usd);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    agentRunId = await insertAgentRun(adminClient, {
      sourceDomain,
      authUserId: auth.userId,
      inputSummary: {
        request_id: requestId,
        worker_name: workerName,
        action,
        limit,
        source_domain: sourceDomain,
        risk_ceiling: riskCeiling,
        dry_run: dryRun,
        debug,
        budget_limit_usd: budgetLimitUsd,
      },
    });

    await insertRunEvent(adminClient, agentRunId, "orchestration_started", {
      request_id: requestId,
      worker_name: workerName,
      action,
    }, auth.userId);

    const workerJob = await createWorkerJob(adminClient, {
      agentRunId,
      workerName,
      action,
      sourceDomain,
      riskCeiling,
      limit,
      budgetLimitUsd,
      dryRun,
      requestPayload: {
        request_id: requestId,
        requested_by: FUNCTION_NAME,
        debug,
      },
    });
    workerJobId = workerJob.id;

    await insertRunEvent(adminClient, agentRunId, "worker_job_created", {
      worker_job_id: workerJobId,
      worker_name: workerJob.worker_name,
      worker_function: workerJob.worker_function,
      item_limit: workerJob.item_limit,
      dry_run: workerJob.dry_run,
    }, auth.userId);

    const workerResult = await invokeEnrichmentWorker({
      agentRunId,
      workerJobId,
      limit,
      sourceDomain,
      debug,
    });

    const summary = {
      worker_job_id: workerJobId,
      worker_name: workerName,
      worker_function: workerJob.worker_function,
      dry_run: dryRun,
      worker_summary: workerResult.summary ?? null,
      worker_metadata: workerResult.metadata ?? null,
      duration_ms: elapsedMs(startedAt),
    };

    await completeRun(adminClient, agentRunId, summary);
    await insertRunEvent(adminClient, agentRunId, "orchestration_completed", summary, auth.userId);

    return jsonResponseWithStatus({
      ok: true,
      run_id: agentRunId,
      worker_job_id: workerJobId,
      summary,
      worker_result: workerResult,
    }, 200);
  } catch (error) {
    console.log(`[${LOG_PREFIX}] phase=unhandled_error request_id=${requestId} error=${String(error)}`);
    if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && agentRunId !== null) {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      await failRun(adminClient, agentRunId, String(error), {
        worker_job_id: workerJobId,
        request_id: requestId,
        duration_ms: elapsedMs(startedAt),
      });
      await insertRunEvent(adminClient, agentRunId, "orchestration_failed", {
        worker_job_id: workerJobId,
        error: String(error),
      }, null);
    }
    return errorJson(500, "ORCHESTRATION_FAILED", String(error));
  }
});

async function insertAgentRun(
  adminClient: ReturnType<typeof createClient>,
  input: {
    sourceDomain: string | null;
    authUserId: string | null;
    inputSummary: Record<string, unknown>;
  },
): Promise<number> {
  const { data, error } = await adminClient
    .from("catalog_agent_runs")
    .insert({
      environment: "dev",
      agent_name: AGENT_NAME,
      agent_version: AGENT_VERSION,
      model: null,
      prompt_version: null,
      mode: "worker_orchestration",
      source_domain: input.sourceDomain,
      input_summary: input.inputSummary,
      status: "started",
      summary: {},
      created_by: input.authUserId,
    })
    .select("id")
    .single();

  if (error || !data?.id) {
    throw new Error(`insert_orchestration_run_failed:${error?.message ?? "missing id"}`);
  }

  return Number(data.id);
}

async function createWorkerJob(
  adminClient: ReturnType<typeof createClient>,
  input: {
    agentRunId: number;
    workerName: string;
    action: string;
    sourceDomain: string | null;
    riskCeiling: string;
    limit: number;
    budgetLimitUsd: number | null;
    dryRun: boolean;
    requestPayload: Record<string, unknown>;
  },
): Promise<WorkerJobRow> {
  const { data, error } = await adminClient.rpc("create_catalog_agent_worker_job", {
    p_agent_run_id: input.agentRunId,
    p_worker_name: input.workerName,
    p_requested_action: input.action,
    p_source_domain: input.sourceDomain,
    p_risk_ceiling: input.riskCeiling,
    p_item_limit: input.limit,
    p_budget_limit_usd: input.budgetLimitUsd,
    p_dry_run: input.dryRun,
    p_request_payload: input.requestPayload,
  });

  if (error) {
    throw new Error(`create_worker_job_failed:${error.message}`);
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row || typeof row !== "object") {
    throw new Error("create_worker_job_failed:empty_response");
  }

  return {
    id: Number((row as Record<string, unknown>).id),
    agent_run_id: positiveIntegerOrNull((row as Record<string, unknown>).agent_run_id),
    worker_name: String((row as Record<string, unknown>).worker_name ?? ""),
    worker_function: String((row as Record<string, unknown>).worker_function ?? ""),
    requested_action: String((row as Record<string, unknown>).requested_action ?? ""),
    status: String((row as Record<string, unknown>).status ?? ""),
    item_limit: Number((row as Record<string, unknown>).item_limit ?? input.limit),
    dry_run: (row as Record<string, unknown>).dry_run === true,
  };
}

async function invokeEnrichmentWorker(input: {
  agentRunId: number;
  workerJobId: number;
  limit: number;
  sourceDomain: string | null;
  debug: boolean;
}): Promise<Record<string, unknown>> {
  const response = await fetchWithTimeout(
    `${SUPABASE_URL}/functions/v1/run-catalog-enrichment-draft-batch`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        limit: input.limit,
        debug: input.debug,
        source_domain: input.sourceDomain,
        agent_run_id: input.agentRunId,
        agent_worker_job_id: input.workerJobId,
      }),
    },
    WORKER_TIMEOUT_MS,
  );

  const text = await response.text();
  const parsed = safeParseJSON(text);
  if (!response.ok) {
    throw new Error(`worker_invocation_failed:${response.status}:${text}`);
  }
  if (!isRecord(parsed)) {
    throw new Error("worker_invocation_failed:invalid_json");
  }
  return parsed;
}

async function completeRun(
  adminClient: ReturnType<typeof createClient>,
  runId: number,
  summary: Record<string, unknown>,
): Promise<void> {
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
    throw new Error(`complete_orchestration_run_failed:${error.message}`);
  }
}

async function failRun(
  adminClient: ReturnType<typeof createClient>,
  runId: number,
  message: string,
  summary: Record<string, unknown>,
): Promise<void> {
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
    console.log(`[${LOG_PREFIX}] phase=fail_run_failed error=${error.message}`);
  }
}

async function insertRunEvent(
  adminClient: ReturnType<typeof createClient>,
  runId: number,
  eventType: string,
  payload: Record<string, unknown>,
  authUserId: string | null,
): Promise<void> {
  const { error } = await adminClient
    .from("catalog_agent_proposal_events")
    .insert({
      run_id: runId,
      event_type: eventType,
      event_payload: payload,
      created_by: authUserId,
    });

  if (error) {
    throw new Error(`insert_orchestration_event_failed:${error.message}`);
  }
}

function hasOperatorToken(request: Request): boolean {
  const provided = request.headers.get("x-season-catalog-agent-token")?.trim() ?? "";
  return !!OPERATOR_TOKEN && provided.length > 0 && provided === OPERATOR_TOKEN;
}

function boundedInteger(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(Math.max(Math.floor(value), min), max);
}

function normalizeRiskCeiling(value: unknown): string {
  const normalized = normalizeText(value) ?? "low";
  return ["low", "medium", "high", "critical"].includes(normalized) ? normalized : "low";
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
}

function normalizeText(value: unknown): string | null {
  const text = String(value ?? "").trim().toLowerCase();
  return text.length > 0 ? text : null;
}

function nonNegativeNumberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return parsed;
}

function positiveIntegerOrNull(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) return null;
  return parsed;
}

function safeParseJSON(raw: string): unknown | null {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function elapsedMs(startedAt: number): number {
  return Math.max(0, Math.round(performance.now() - startedAt));
}

function errorJson(status: number, code: string, message: string): Response {
  return jsonResponseWithStatus({
    ok: false,
    error: { code, message },
  }, status);
}
