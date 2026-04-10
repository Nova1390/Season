import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEFAULT_RECOVERY_LIMIT = 1000;
const DEFAULT_ENRICH_LIMIT = 20;
const DEFAULT_CREATE_LIMIT = 20;
const MAX_LIMIT = 5000;

type RunnerMode = "user" | "service_role";

interface AutomationRequest {
  recovery_limit?: number;
  enrich_limit?: number;
  create_limit?: number;
}

interface RecoveryRow {
  result_status?: string | null;
}

Deno.serve(async (request) => {
  try {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=request_received method=${request.method}`);

    if (request.method !== "POST") {
      return errorJson(405, "METHOD_NOT_ALLOWED", "Only POST is supported.");
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return errorJson(500, "SERVER_MISCONFIGURED", "Supabase environment is not configured.");
    }

    const auth = await resolveAndAuthorize(request);
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHORIZED", "Catalog admin authentication is required.");
    }

    let payload: AutomationRequest = {};
    try {
      payload = await request.json();
    } catch {
      payload = {};
    }

    const recoveryLimit = clampLimit(payload.recovery_limit, DEFAULT_RECOVERY_LIMIT);
    const enrichLimit = clampLimit(payload.enrich_limit, DEFAULT_ENRICH_LIMIT);
    const createLimit = clampLimit(payload.create_limit, DEFAULT_CREATE_LIMIT);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_started mode=${auth.mode} recovery_limit=${recoveryLimit} enrich_limit=${enrichLimit} create_limit=${createLimit}`,
    );

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const userClient = auth.bearerToken
      ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${auth.bearerToken}` } },
      })
      : null;

    const recoverySummary = await runRecoveryStage({
      userClient,
      recoveryLimit,
      mode: auth.mode,
    });

    const enrichmentSummary = await runFunctionStage({
      functionName: "run-catalog-enrichment-draft-batch",
      limit: enrichLimit,
      mode: auth.mode,
      bearerToken: auth.bearerToken,
    });

    const creationSummary = await runFunctionStage({
      functionName: "run-catalog-ingredient-creation-batch",
      limit: createLimit,
      mode: auth.mode,
      bearerToken: auth.bearerToken,
    });

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_completed ` +
      `recovery_failed=${recoverySummary.status == "failed"} ` +
      `enrichment_failed=${enrichmentSummary.status == "failed"} ` +
      `creation_failed=${creationSummary.status == "failed"}`,
    );

    return json({
      summary: {
        recovery: recoverySummary,
        enrichment: enrichmentSummary,
        creation: creationSummary,
      },
      metadata: {
        mode: auth.mode,
        limits: {
          recovery_limit: recoveryLimit,
          enrich_limit: enrichLimit,
          create_limit: createLimit,
        },
        generated_at: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=unhandled_error error=${String(error)}`);
    return errorJson(500, "INTERNAL_AUTOMATION_ERROR", "Unexpected catalog automation cycle failure.");
  }
});

async function runRecoveryStage(input: {
  userClient: ReturnType<typeof createClient> | null;
  recoveryLimit: number;
  mode: RunnerMode;
}): Promise<{
  total: number;
  observed: number;
  skipped: number;
  failed: number;
  status: "ok" | "failed";
  error?: string;
}> {
  if (!input.userClient) {
    return {
      total: 0,
      observed: 0,
      skipped: 0,
      failed: 0,
      status: "failed",
      error: "missing_user_context_for_recovery",
    };
  }

  try {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=recovery_started limit=${input.recoveryLimit} mode=${input.mode}`);
    const { data, error } = await input.userClient.rpc(
      "recover_unresolved_recipe_ingredient_observations",
      {
        p_limit: input.recoveryLimit,
        p_recipe_ids: null,
        p_source: "automation_cycle",
      },
    );
    if (error) {
      throw new Error(error.message);
    }

    const rows = Array.isArray(data) ? data as RecoveryRow[] : [];
    const observed = rows.filter((row) => (row.result_status ?? "") === "observed").length;
    const skipped = rows.filter((row) => (row.result_status ?? "") === "skipped").length;
    const failed = rows.filter((row) => (row.result_status ?? "") === "failed").length;

    return {
      total: rows.length,
      observed,
      skipped,
      failed,
      status: "ok",
    };
  } catch (error) {
    const message = String(error);
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=recovery_failed error=${message}`);
    return {
      total: 0,
      observed: 0,
      skipped: 0,
      failed: 0,
      status: "failed",
      error: message,
    };
  }
}

async function runFunctionStage(input: {
  functionName: string;
  limit: number;
  mode: RunnerMode;
  bearerToken: string | null;
}): Promise<Record<string, unknown>> {
  try {
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=${input.functionName}_started limit=${input.limit} mode=${input.mode}`,
    );

    const authHeader = input.mode === "service_role"
      ? `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      : `Bearer ${input.bearerToken ?? ""}`;
    const apikey = input.mode === "service_role" ? SUPABASE_SERVICE_ROLE_KEY : SUPABASE_ANON_KEY;

    const response = await fetch(`${SUPABASE_URL}/functions/v1/${input.functionName}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey,
        Authorization: authHeader,
      },
      body: JSON.stringify({ limit: input.limit }),
    });

    if (!response.ok) {
      const details = await response.text();
      throw new Error(`http_${response.status}:${details}`);
    }

    const payload = await response.json() as Record<string, unknown>;
    const summary = isRecord(payload.summary) ? payload.summary : {};
    return {
      ...summary,
      status: "ok",
    };
  } catch (error) {
    const message = String(error);
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=${input.functionName}_failed error=${message}`);

    if (input.functionName == "run-catalog-enrichment-draft-batch") {
      return {
        total: 0,
        succeeded: 0,
        failed: 0,
        skipped: 0,
        ready: 0,
        status: "failed",
        error: message,
      };
    }

    return {
      total: 0,
      created: 0,
      skipped_existing: 0,
      skipped_invalid: 0,
      failed: 0,
      status: "failed",
      error: message,
    };
  }
}

async function resolveAndAuthorize(
  request: Request,
): Promise<{ allowed: boolean; mode: RunnerMode; bearerToken: string | null }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = extractBearerToken(authHeader) ?? "";

  const isServiceRole =
    (apikey && apikey === SUPABASE_SERVICE_ROLE_KEY) ||
    (bearer && bearer === SUPABASE_SERVICE_ROLE_KEY);

  if (isServiceRole) {
    console.log("[SEASON_CATALOG_AUTOMATION] phase=auth_ok mode=service_role");
    return { allowed: true, mode: "service_role", bearerToken: null };
  }

  if (!bearer) {
    console.log("[SEASON_CATALOG_AUTOMATION] phase=auth_missing_user_token");
    return { allowed: false, mode: "user", bearerToken: null };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
  if (userError || !userData.user?.id) {
    console.log("[SEASON_CATALOG_AUTOMATION] phase=auth_invalid_user_token");
    return { allowed: false, mode: "user", bearerToken: null };
  }

  const { data: adminData, error: adminError } = await userClient.rpc("is_current_user_catalog_admin");
  const isAdmin = adminError ? false : decodeBoolean(adminData);
  console.log(
    `[SEASON_CATALOG_AUTOMATION] phase=auth_user_checked user_id=${userData.user.id} is_admin=${isAdmin}`,
  );

  return { allowed: isAdmin, mode: "user", bearerToken: bearer };
}

function clampLimit(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(MAX_LIMIT, Math.floor(parsed)));
}

function decodeBoolean(payload: unknown): boolean {
  if (typeof payload === "boolean") return payload;
  if (typeof payload === "string") return payload.toLowerCase() === "true";
  if (Array.isArray(payload) && payload.length > 0) return decodeBoolean(payload[0]);
  if (payload && typeof payload === "object" && "is_current_user_catalog_admin" in payload) {
    return decodeBoolean((payload as Record<string, unknown>).is_current_user_catalog_admin);
  }
  return false;
}

function extractBearerToken(header: string): string | null {
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...JSON_HEADERS,
      ...(init.headers ?? {}),
    },
  });
}

function errorJson(status: number, code: string, message: string): Response {
  return json({ error: code, message }, { status });
}
