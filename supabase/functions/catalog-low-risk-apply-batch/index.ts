import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveCatalogAdminOrServiceRole } from "../_shared/auth.ts";
import {
  env,
  jsonResponseWithStatus,
  numberEnv,
} from "../_shared/edge.ts";
import { requestIdFromHeaders } from "../_shared/observability.ts";

interface ApplyBatchRequest {
  limit?: number;
  agent_run_id?: number | null;
  agent_worker_job_id?: number | null;
  dry_run?: boolean;
  debug?: boolean;
}

const FUNCTION_NAME = "catalog-low-risk-apply-batch";
const LOG_PREFIX = "SEASON_CATALOG_LOW_RISK_APPLY_BATCH";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const WORKER_ENABLED = env("CATALOG_AGENT_LOW_RISK_APPLY_ENABLED", "false").toLowerCase() === "true";
const MAX_LIMIT = boundedInteger(numberEnv("CATALOG_AGENT_LOW_RISK_APPLY_MAX_ITEMS", 5), 1, 25);

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  const startedAt = performance.now();
  let agentWorkerJobId: number | null = null;
  let serviceClient: ReturnType<typeof createClient> | null = null;

  try {
    console.log(`[${LOG_PREFIX}] phase=request_received method=${request.method} request_id=${requestId}`);

    if (request.method !== "POST") {
      return errorJson(405, "METHOD_NOT_ALLOWED", "Only POST is supported.");
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return errorJson(500, "SERVER_MISCONFIGURED", "Supabase environment is not configured.");
    }

    const auth = await resolveCatalogAdminOrServiceRole(request, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
      supabaseServiceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      logPrefix: LOG_PREFIX,
    });
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHORIZED", "Catalog admin authentication is required.");
    }

    let payload: ApplyBatchRequest = {};
    try {
      payload = await request.json();
    } catch {
      payload = {};
    }

    const dryRun = payload.dry_run === true;
    const limit = boundedInteger(Number(payload.limit ?? MAX_LIMIT), 1, MAX_LIMIT);
    const agentRunId = positiveIntegerOrNull(payload.agent_run_id);
    agentWorkerJobId = positiveIntegerOrNull(payload.agent_worker_job_id);
    const debug = payload.debug === true;

    console.log(
      `[${LOG_PREFIX}] phase=batch_requested mode=${auth.mode} enabled=${WORKER_ENABLED} dry_run=${dryRun} limit=${limit} agent_run_id=${agentRunId ?? "null"} worker_job_id=${agentWorkerJobId ?? "null"}`,
    );

    serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (agentWorkerJobId !== null) {
      await startWorkerJob(serviceClient, agentWorkerJobId);
    }

    if (dryRun) {
      const preview = await previewEligibleProposals(serviceClient, limit);
      const summary = {
        mode: "dry_run",
        total: preview.length,
        applied: 0,
        failed: 0,
        eligible_preview: preview,
        duration_ms: elapsedMs(startedAt),
      };

      if (agentWorkerJobId !== null) {
        await completeWorkerJob(serviceClient, agentWorkerJobId, summary);
      }

      return jsonResponseWithStatus({
        ok: true,
        worker: FUNCTION_NAME,
        dry_run: true,
        agent_run_id: agentRunId,
        agent_worker_job_id: agentWorkerJobId,
        summary,
        debug,
      }, 200);
    }

    if (!WORKER_ENABLED) {
      throw new WorkerDisabledError("low_risk_apply_worker_disabled");
    }

    const { data, error } = await serviceClient.rpc("apply_catalog_agent_low_risk_proposal_batch", {
      p_limit: limit,
      p_worker_job_id: agentWorkerJobId,
    });

    if (error) {
      throw new Error(`apply_low_risk_batch_failed:${error.message}`);
    }

    const summary = {
      mode: "apply",
      total: Number((data as Record<string, unknown> | null)?.applied ?? 0) +
        Number((data as Record<string, unknown> | null)?.failed ?? 0),
      applied: Number((data as Record<string, unknown> | null)?.applied ?? 0),
      failed: Number((data as Record<string, unknown> | null)?.failed ?? 0),
      result: data ?? {},
      duration_ms: elapsedMs(startedAt),
    };

    if (agentWorkerJobId !== null) {
      await completeWorkerJob(serviceClient, agentWorkerJobId, summary);
    }

    return jsonResponseWithStatus({
      ok: true,
      worker: FUNCTION_NAME,
      dry_run: false,
      agent_run_id: agentRunId,
      agent_worker_job_id: agentWorkerJobId,
      summary,
      debug,
    }, 200);
  } catch (error) {
    const message = String(error);
    console.log(`[${LOG_PREFIX}] phase=worker_failed request_id=${requestId} error=${message}`);

    if (serviceClient && agentWorkerJobId !== null) {
      await failWorkerJob(serviceClient, agentWorkerJobId, message, {
        duration_ms: elapsedMs(startedAt),
        request_id: requestId,
      });
    }

    if (error instanceof WorkerDisabledError) {
      return errorJson(403, "LOW_RISK_APPLY_DISABLED", "Low-risk apply worker is disabled.");
    }

    return errorJson(500, "LOW_RISK_APPLY_BATCH_FAILED", message);
  }
});

async function previewEligibleProposals(
  client: ReturnType<typeof createClient>,
  limit: number,
): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client
    .from("catalog_agent_proposals")
    .select("id,run_id,proposal_type,normalized_text,target_ingredient_id,target_slug,confidence_score,risk_level,created_at")
    .eq("status", "validated")
    .eq("risk_level", "low")
    .eq("auto_apply_eligible", true)
    .in("proposal_type", ["approve_alias", "add_localization"])
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) {
    throw new Error(`preview_eligible_low_risk_apply_failed:${error.message}`);
  }

  return Array.isArray(data) ? data : [];
}

async function startWorkerJob(
  client: ReturnType<typeof createClient>,
  workerJobId: number,
): Promise<void> {
  const { error } = await client.rpc("start_catalog_agent_worker_job", {
    p_job_id: workerJobId,
  });

  if (error) {
    throw new Error(`start_worker_job_failed:${error.message}`);
  }
}

async function completeWorkerJob(
  client: ReturnType<typeof createClient>,
  workerJobId: number,
  summary: Record<string, unknown>,
): Promise<void> {
  const { error } = await client.rpc("complete_catalog_agent_worker_job", {
    p_job_id: workerJobId,
    p_summary: summary,
  });

  if (error) {
    throw new Error(`complete_worker_job_failed:${error.message}`);
  }
}

async function failWorkerJob(
  client: ReturnType<typeof createClient>,
  workerJobId: number,
  message: string,
  summary: Record<string, unknown>,
): Promise<void> {
  const { error } = await client.rpc("fail_catalog_agent_worker_job", {
    p_job_id: workerJobId,
    p_failure_reason: message,
    p_summary: summary,
  });

  if (error) {
    console.log(`[${LOG_PREFIX}] phase=fail_worker_job_failed error=${error.message}`);
  }
}

function boundedInteger(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(Math.max(Math.floor(value), min), max);
}

function positiveIntegerOrNull(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) return null;
  return parsed;
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

class WorkerDisabledError extends Error {}
