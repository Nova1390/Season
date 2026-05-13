import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveCatalogAdminOrServiceRole } from "../_shared/auth.ts";
import {
  env,
  fetchWithTimeout,
  JSON_HEADERS,
  numberEnv,
} from "../_shared/edge.ts";
import { requestIdFromHeaders } from "../_shared/observability.ts";

interface DevShiftRequest {
  limit?: number;
  source_domain?: string | null;
  dry_run?: boolean;
  run_low_risk_preview?: boolean;
  run_triage?: boolean;
  debug?: boolean;
}

const FUNCTION_NAME = "run-catalog-agent-dev-shift";
const LOG_PREFIX = "SEASON_CATALOG_AGENT_DEV_SHIFT";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");
const OPERATOR_TOKEN = env("CATALOG_AGENT_OPERATOR_TOKEN");

const MAX_SHIFT_ITEMS = boundedInteger(numberEnv("CATALOG_AGENT_DEV_SHIFT_MAX_ITEMS", 1), 1, 3);
const FUNCTION_TIMEOUT_MS = boundedInteger(numberEnv("CATALOG_AGENT_DEV_SHIFT_TIMEOUT_MS", 60000), 5000, 180000);

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-season-catalog-agent-token",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  const startedAt = performance.now();

  try {
    console.log(`[${LOG_PREFIX}] phase=request_received method=${request.method} request_id=${requestId}`);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== "POST") {
      return shiftJson({ ok: false, error: { code: "METHOD_NOT_ALLOWED", message: "Only POST is supported." } }, 405);
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return shiftJson({
        ok: false,
        error: { code: "SERVER_MISCONFIGURED", message: "Supabase environment is not configured." },
      }, 500);
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
      return shiftJson({
        ok: false,
        error: { code: "UNAUTHORIZED", message: "Catalog admin authentication is required." },
      }, 401);
    }

    const payload = await readPayload(request);
    const limit = boundedInteger(Number(payload.limit ?? MAX_SHIFT_ITEMS), 1, MAX_SHIFT_ITEMS);
    const sourceDomain = normalizeNullableText(payload.source_domain);
    const dryRun = payload.dry_run !== false;
    const runLowRiskPreview = payload.run_low_risk_preview !== false;
    const runTriage = payload.run_triage === true;
    const debug = payload.debug === true;

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const guard = await rpcObject(adminClient, "catalog_agent_dev_schedule_guard", {
      p_environment: "dev",
    });

    if (guard.ok !== true) {
      const digest = await buildDigest(adminClient);
      return shiftJson({
        ok: true,
        skipped: true,
        reason: guard.reason ?? "guard_blocked",
        guard,
        digest,
        duration_ms: elapsedMs(startedAt),
      });
    }

    const allowed = isRecord(guard.allowed) ? guard.allowed : {};
    const workerResults: Record<string, unknown>[] = [];
    const skippedWorkers: Record<string, unknown>[] = [];

    if (runLowRiskPreview && allowed.low_risk_dry_run === true) {
      workerResults.push(await invokeOrchestrator({
        workerName: "low_risk_apply_batch",
        action: "dry_run",
        limit,
        sourceDomain,
        dryRun: true,
        debug,
      }));
    } else if (runLowRiskPreview) {
      skippedWorkers.push({
        worker_name: "low_risk_apply_batch",
        reason: "guard_disallowed_low_risk_dry_run",
      });
    }

    if (runTriage && allowed.triage === true) {
      skippedWorkers.push({
        worker_name: "catalog_agent_triage",
        reason: "triage_scheduler_not_enabled_in_dev_shift_yet",
      });
    } else if (runTriage) {
      skippedWorkers.push({
        worker_name: "catalog_agent_triage",
        reason: "guard_disallowed_triage",
      });
    }

    if (!dryRun && allowed.low_risk_apply === true) {
      skippedWorkers.push({
        worker_name: "low_risk_apply_batch",
        reason: "real_apply_intentionally_not_wired_to_scheduled_shift_yet",
      });
    }

    const digest = await buildDigest(adminClient);

    return shiftJson({
      ok: true,
      skipped: false,
      guard,
      dry_run: dryRun,
      limit,
      source_domain: sourceDomain,
      worker_results: workerResults,
      skipped_workers: skippedWorkers,
      digest,
      duration_ms: elapsedMs(startedAt),
    });
  } catch (error) {
    console.log(`[${LOG_PREFIX}] phase=unhandled_error request_id=${requestId} error=${String(error)}`);
    return shiftJson({
      ok: false,
      error: {
        code: "DEV_SHIFT_FAILED",
        message: String(error),
      },
      duration_ms: elapsedMs(startedAt),
    }, 500);
  }
});

async function readPayload(request: Request): Promise<DevShiftRequest> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) return {};

  try {
    const parsed = await request.json();
    return isRecord(parsed) ? parsed as DevShiftRequest : {};
  } catch {
    return {};
  }
}

async function buildDigest(adminClient: ReturnType<typeof createClient>): Promise<Record<string, unknown>> {
  return await rpcObject(adminClient, "catalog_agent_build_daily_digest", {
    p_report_date: new Date().toISOString().slice(0, 10),
    p_environment: "dev",
  });
}

async function rpcObject(
  client: ReturnType<typeof createClient>,
  name: string,
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const { data, error } = await client.rpc(name, args);
  if (error) {
    throw new Error(`${name}_failed:${error.message}`);
  }
  if (!isRecord(data)) {
    throw new Error(`${name}_failed:invalid_response`);
  }
  return data;
}

async function invokeOrchestrator(input: {
  workerName: string;
  action: string;
  limit: number;
  sourceDomain: string | null;
  dryRun: boolean;
  debug: boolean;
}): Promise<Record<string, unknown>> {
  const response = await fetchWithTimeout(
    `${SUPABASE_URL}/functions/v1/run-catalog-agent-orchestrator`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        worker_name: input.workerName,
        action: input.action,
        limit: input.limit,
        source_domain: input.sourceDomain,
        dry_run: input.dryRun,
        debug: input.debug,
      }),
    },
    FUNCTION_TIMEOUT_MS,
  );

  const text = await response.text();
  const parsed = safeParseJSON(text);
  if (!response.ok) {
    throw new Error(`orchestrator_invocation_failed:${response.status}:${text}`);
  }
  if (!isRecord(parsed)) {
    throw new Error("orchestrator_invocation_failed:invalid_json");
  }
  return parsed;
}

function hasOperatorToken(request: Request): boolean {
  const provided = request.headers.get("x-season-catalog-agent-token")?.trim() ?? "";
  return !!OPERATOR_TOKEN && provided.length > 0 && provided === OPERATOR_TOKEN;
}

function boundedInteger(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(Math.max(Math.floor(value), min), max);
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
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

function shiftJson(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...JSON_HEADERS,
      ...CORS_HEADERS,
    },
  });
}
