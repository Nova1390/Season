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
const CANDIDATE_INTAKE_MULTIPLIER = 5;
const MAX_LIMIT = 5000;

type RunnerMode = "user" | "service_role";

interface AutomationRequest {
  recovery_limit?: number;
  enrich_limit?: number;
  create_limit?: number;
  debug?: unknown;
}

interface RecoveryRow {
  result_status?: string | null;
}

interface CandidateRow {
  normalized_text?: string | null;
  suggested_resolution_type?: string | null;
  has_approved_alias?: boolean | null;
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
    const debugEnabled = decodeBoolean(payload.debug);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_started mode=${auth.mode} recovery_limit=${recoveryLimit} enrich_limit=${enrichLimit} create_limit=${createLimit} debug=${debugEnabled}`,
    );

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const debugRunId = debugEnabled
      ? await createDebugRun(serviceClient, "run-catalog-automation-cycle", auth.mode, {
        recovery_limit: recoveryLimit,
        enrich_limit: enrichLimit,
        create_limit: createLimit,
      })
      : null;
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "start", {
      mode: auth.mode,
      recovery_limit: recoveryLimit,
      enrich_limit: enrichLimit,
      create_limit: createLimit,
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
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "recovery_summary", recoverySummary);

    const candidateIntakeSummary = await runCandidateIntakeStage({
      userClient,
      candidateLimit: clampLimit(enrichLimit * CANDIDATE_INTAKE_MULTIPLIER, enrichLimit),
      mode: auth.mode,
    });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "candidate_intake_summary", candidateIntakeSummary);

    const pendingDraftsBeforeEnrichment = await countPendingDrafts(serviceClient);
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=enrichment_stage_input pending_drafts=${pendingDraftsBeforeEnrichment} limit=${enrichLimit}`,
    );
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "enrichment_call_started", {
      pending_drafts_before_enrichment: pendingDraftsBeforeEnrichment,
      limit: enrichLimit,
    });

    const enrichmentSummary = await runFunctionStage({
      functionName: "run-catalog-enrichment-draft-batch",
      limit: enrichLimit,
      mode: auth.mode,
      bearerToken: auth.bearerToken,
      debug: debugEnabled,
    });
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=enrichment_stage_response ` +
      `total=${toInt(enrichmentSummary.total)} succeeded=${toInt(enrichmentSummary.succeeded)} ` +
      `failed=${toInt(enrichmentSummary.failed)} skipped=${toInt(enrichmentSummary.skipped)} ` +
      `ready=${toInt(enrichmentSummary.ready)} status=${String(enrichmentSummary.status ?? "unknown")} ` +
      `error=${String(enrichmentSummary.error ?? "none")}`,
    );
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "enrichment_response", enrichmentSummary);

    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "creation_call_started", {
      limit: createLimit,
    });
    const creationSummary = await runFunctionStage({
      functionName: "run-catalog-ingredient-creation-batch",
      limit: createLimit,
      mode: auth.mode,
      bearerToken: auth.bearerToken,
      debug: debugEnabled,
    });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "creation_response", creationSummary);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_completed ` +
      `recovery_failed=${recoverySummary.status == "failed"} ` +
      `candidate_intake_failed=${candidateIntakeSummary.status == "failed"} ` +
      `enrichment_failed=${enrichmentSummary.status == "failed"} ` +
      `creation_failed=${creationSummary.status == "failed"}`,
    );

    return json({
      summary: {
        recovery: recoverySummary,
        candidate_intake: candidateIntakeSummary,
        enrichment: enrichmentSummary,
        creation: creationSummary,
      },
      metadata: {
        mode: auth.mode,
        debug_enabled: debugEnabled,
        debug_run_id: debugRunId,
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

async function runCandidateIntakeStage(input: {
  userClient: ReturnType<typeof createClient> | null;
  candidateLimit: number;
  mode: RunnerMode;
}): Promise<{
  selected: number;
  eligible: number;
  submitted: number;
  succeeded: number;
  failed: number;
  skipped: number;
  status: "ok" | "failed";
  error?: string;
}> {
  if (!input.userClient) {
    return {
      selected: 0,
      eligible: 0,
      submitted: 0,
      succeeded: 0,
      failed: 0,
      skipped: 0,
      status: "failed",
      error: "missing_user_context_for_candidate_intake",
    };
  }

  try {
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=candidate_intake_started candidate_limit=${input.candidateLimit} mode=${input.mode}`,
    );

    const { data: candidatesData, error: candidatesError } = await input.userClient.rpc(
      "catalog_resolution_candidates",
      {
        limit_count: input.candidateLimit,
        only_status_new: true,
      },
    );

    if (candidatesError) {
      throw new Error(`candidate_select_failed:${candidatesError.message}`);
    }

    const candidates = Array.isArray(candidatesData) ? (candidatesData as CandidateRow[]) : [];
    const eligibleItems = candidates
      .filter((row) => {
        const normalizedText = String(row.normalized_text ?? "").trim().toLowerCase();
        if (!normalizedText) return false;
        if (row.has_approved_alias === true) return false;

        const suggestedType = String(row.suggested_resolution_type ?? "").trim().toLowerCase();
        if (suggestedType === "add_alias" || suggestedType === "alias_existing" || suggestedType === "ignore") {
          return false;
        }
        return true;
      })
      .map((row) => ({
        normalized_text: String(row.normalized_text ?? "").trim().toLowerCase(),
        action: "prepare_enrichment_draft",
      }));

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=candidate_intake_selected selected=${candidates.length} eligible=${eligibleItems.length}`,
    );

    if (eligibleItems.length === 0) {
      return {
        selected: candidates.length,
        eligible: 0,
        submitted: 0,
        succeeded: 0,
        failed: 0,
        skipped: 0,
        status: "ok",
      };
    }

    const { data: triageData, error: triageError } = await input.userClient.rpc(
      "execute_catalog_candidate_batch_triage",
      {
        p_items: eligibleItems,
        p_default_language_code: "it",
        p_reviewer_note: "automation_cycle_candidate_intake",
      },
    );

    if (triageError) {
      throw new Error(`candidate_intake_triage_failed:${triageError.message}`);
    }

    const triagePayload = isRecord(triageData) ? triageData : (Array.isArray(triageData) ? triageData[0] : null);
    const triageSummary = triagePayload && isRecord(triagePayload.summary) ? triagePayload.summary : {};
    const succeeded = toInt(triageSummary.succeeded);
    const failed = toInt(triageSummary.failed);
    const skipped = toInt(triageSummary.skipped);
    const submitted = toInt(triageSummary.total) || eligibleItems.length;

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=candidate_intake_completed selected=${candidates.length} eligible=${eligibleItems.length} submitted=${submitted} succeeded=${succeeded} failed=${failed} skipped=${skipped}`,
    );

    return {
      selected: candidates.length,
      eligible: eligibleItems.length,
      submitted,
      succeeded,
      failed,
      skipped,
      status: "ok",
    };
  } catch (error) {
    const message = String(error);
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=candidate_intake_failed error=${message}`);
    return {
      selected: 0,
      eligible: 0,
      submitted: 0,
      succeeded: 0,
      failed: 0,
      skipped: 0,
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
  debug: boolean;
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
      body: JSON.stringify(input.debug ? { limit: input.limit, debug: true } : { limit: input.limit }),
    });

    if (!response.ok) {
      const details = await response.text();
      throw new Error(`http_${response.status}:${details}`);
    }

    const payload = await response.json() as Record<string, unknown>;
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=${input.functionName}_response_payload ` +
      `keys=${Object.keys(payload).join(",")} has_summary=${isRecord(payload.summary)} has_error=${"error" in payload}`,
    );
    const summary = isRecord(payload.summary) ? payload.summary : {};
    if (input.functionName === "run-catalog-enrichment-draft-batch") {
      console.log(
        `[SEASON_CATALOG_AUTOMATION] phase=enrichment_stage_counts total=${toInt(summary.total)} succeeded=${toInt(summary.succeeded)} failed=${toInt(summary.failed)} skipped=${toInt(summary.skipped)} ready=${toInt(summary.ready)}`,
      );
    }
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

async function countPendingDrafts(client: ReturnType<typeof createClient>): Promise<number> {
  const { count, error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text", { count: "exact", head: true })
    .eq("status", "pending");

  if (error) {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=count_pending_drafts_failed error=${error.message}`);
    return 0;
  }
  return count ?? 0;
}

async function createDebugRun(
  client: ReturnType<typeof createClient>,
  functionName: string,
  mode: string,
  metadata: Record<string, unknown>,
): Promise<string | null> {
  try {
    const { data, error } = await client
      .from("catalog_function_debug_runs")
      .insert({
        function_name: functionName,
        mode,
        metadata,
      })
      .select("run_id")
      .single();

    if (error) {
      console.log(`[SEASON_CATALOG_AUTOMATION] phase=debug_run_insert_failed error=${error.message}`);
      return null;
    }
    return String((data as Record<string, unknown> | null)?.run_id ?? "");
  } catch (error) {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=debug_run_insert_failed error=${String(error)}`);
    return null;
  }
}

async function writeDebugEvent(
  client: ReturnType<typeof createClient>,
  runId: string | null,
  functionName: string,
  stage: string,
  payload: Record<string, unknown> | unknown,
  trackedTerm?: string,
): Promise<void> {
  if (!runId) return;
  try {
    const safePayload = isRecord(payload) ? payload : { value: payload };
    const { error } = await client
      .from("catalog_function_debug_events")
      .insert({
        run_id: runId,
        function_name: functionName,
        stage,
        tracked_term: trackedTerm ?? null,
        payload: safePayload,
      });

    if (error) {
      console.log(`[SEASON_CATALOG_AUTOMATION] phase=debug_event_insert_failed stage=${stage} error=${error.message}`);
    }
  } catch (error) {
    console.log(`[SEASON_CATALOG_AUTOMATION] phase=debug_event_insert_failed stage=${stage} error=${String(error)}`);
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

function toInt(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.floor(parsed));
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
