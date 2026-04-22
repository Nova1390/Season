import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  env,
  extractBearerToken,
  fetchWithTimeout,
  firstEnv,
  jsonResponse,
  numberEnv,
} from "../_shared/edge.ts";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const DEFAULT_RECOVERY_LIMIT = 1000;
const DEFAULT_ENRICH_LIMIT = 20;
const DEFAULT_CREATE_LIMIT = 20;
const CANDIDATE_INTAKE_MULTIPLIER = 5;
const MAX_LIMIT = 5000;
const FUNCTION_CALL_TIMEOUT_MS = numberEnv("CATALOG_AUTOMATION_FUNCTION_TIMEOUT_MS", 55000);

type RunnerMode = "user" | "service_role";

interface AutomationRequest {
  recovery_limit?: number;
  enrich_limit?: number;
  create_limit?: number;
  apply_aliases?: unknown;
  apply_localizations?: unknown;
  apply_reconciliation?: unknown;
  dry_run?: unknown;
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

interface AutoApplyRow {
  normalized_text?: string | null;
  canonical_candidate_slug?: string | null;
  attempted_alias_text?: string | null;
  match_method?: string | null;
  result_status?: string | null;
  detail?: string | null;
  error_message?: string | null;
}

interface ReconciliationApplyRow {
  applied?: boolean | null;
  apply_status?: string | null;
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

    const runStartedAt = new Date();
    const recoveryLimit = clampLimit(payload.recovery_limit, DEFAULT_RECOVERY_LIMIT);
    const enrichLimit = clampLimit(payload.enrich_limit, DEFAULT_ENRICH_LIMIT);
    const createLimit = clampLimit(payload.create_limit, DEFAULT_CREATE_LIMIT);
    const reconciliationLimit = createLimit;
    const applyAliases = decodeBooleanWithDefault(payload.apply_aliases, true);
    const applyLocalizations = decodeBooleanWithDefault(payload.apply_localizations, true);
    const applyReconciliation = decodeBooleanWithDefault(payload.apply_reconciliation, true);
    const dryRun = decodeBoolean(payload.dry_run);
    const debugEnabled = decodeBoolean(payload.debug);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_started mode=${auth.mode} recovery_limit=${recoveryLimit} enrich_limit=${enrichLimit} create_limit=${createLimit} reconciliation_limit=${reconciliationLimit} apply_aliases=${applyAliases} apply_localizations=${applyLocalizations} apply_reconciliation=${applyReconciliation} dry_run=${dryRun} debug=${debugEnabled}`,
    );

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const debugRunId = debugEnabled
      ? await createDebugRun(serviceClient, "run-catalog-automation-cycle", auth.mode, {
        recovery_limit: recoveryLimit,
        enrich_limit: enrichLimit,
        create_limit: createLimit,
        reconciliation_limit: reconciliationLimit,
        apply_aliases: applyAliases,
        apply_localizations: applyLocalizations,
        apply_reconciliation: applyReconciliation,
        dry_run: dryRun,
      })
      : null;
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "start", {
      mode: auth.mode,
      recovery_limit: recoveryLimit,
      enrich_limit: enrichLimit,
      create_limit: createLimit,
      reconciliation_limit: reconciliationLimit,
      apply_aliases: applyAliases,
      apply_localizations: applyLocalizations,
      apply_reconciliation: applyReconciliation,
      dry_run: dryRun,
    });

    const userClient = auth.bearerToken
      ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${auth.bearerToken}` } },
      })
      : null;

    const recoverySummary = dryRun
      ? {
        total: 0,
        observed: 0,
        skipped: 0,
        failed: 0,
        status: "skipped_dry_run",
      }
      : await runRecoveryStage({
        userClient,
        recoveryLimit,
        mode: auth.mode,
      });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "recovery_summary", recoverySummary);

    const candidateIntakeSummary = dryRun
      ? {
        selected: 0,
        eligible: 0,
        submitted: 0,
        succeeded: 0,
        failed: 0,
        skipped: 0,
        status: "skipped_dry_run",
      }
      : await runCandidateIntakeStage({
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

    const enrichmentSummary = dryRun
      ? {
        total: 0,
        succeeded: 0,
        failed: 0,
        skipped: 0,
        ready: 0,
        status: "skipped_dry_run",
      }
      : await runFunctionStage({
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
      dry_run: dryRun,
    });
    const creationSummary = dryRun
      ? {
        total: 0,
        created: 0,
        skipped_existing: 0,
        skipped_invalid: 0,
        failed: 0,
        status: "skipped_dry_run",
      }
      : await runFunctionStage({
        functionName: "run-catalog-ingredient-creation-batch",
        limit: createLimit,
        mode: auth.mode,
        bearerToken: auth.bearerToken,
        debug: debugEnabled,
      });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "creation_response", creationSummary);

    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "alias_auto_apply_started", {
      limit: enrichLimit,
      apply_aliases: applyAliases,
      dry_run: dryRun,
    });
    const aliasSummary = await runAutoAliasStage({
      userClient,
      limit: enrichLimit,
      applyEnabled: applyAliases,
      dryRun,
    });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "alias_auto_apply_response", aliasSummary);

    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "localization_auto_apply_started", {
      limit: enrichLimit,
      apply_localizations: applyLocalizations,
      dry_run: dryRun,
    });
    const localizationSummary = await runAutoLocalizationStage({
      userClient,
      limit: enrichLimit,
      applyEnabled: applyLocalizations,
      dryRun,
    });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "localization_auto_apply_response", localizationSummary);

    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "reconciliation_apply_started", {
      limit: reconciliationLimit,
      apply_reconciliation: applyReconciliation,
      dry_run: dryRun,
    });
    const reconciliationSummary = await runModernReconciliationStage({
      userClient,
      limit: reconciliationLimit,
      applyEnabled: applyReconciliation,
      dryRun,
    });
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-automation-cycle", "reconciliation_apply_response", reconciliationSummary);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=cycle_completed ` +
      `recovery_failed=${recoverySummary.status == "failed"} ` +
      `candidate_intake_failed=${candidateIntakeSummary.status == "failed"} ` +
      `enrichment_failed=${enrichmentSummary.status == "failed"} ` +
      `creation_failed=${creationSummary.status == "failed"} ` +
      `alias_failed=${aliasSummary.status == "failed"} ` +
      `localization_failed=${localizationSummary.status == "failed"} ` +
      `reconciliation_failed=${reconciliationSummary.status == "failed"}`,
    );

    const stageStatus = {
      recovery: String(recoverySummary.status ?? "unknown"),
      candidate_intake: String(candidateIntakeSummary.status ?? "unknown"),
      enrichment: String(enrichmentSummary.status ?? "unknown"),
      creation: String(creationSummary.status ?? "unknown"),
      alias_auto_apply: String(aliasSummary.status ?? "unknown"),
      localization_auto_apply: String(localizationSummary.status ?? "unknown"),
      reconciliation_apply_modern_safe: String(reconciliationSummary.status ?? "unknown"),
    };
    const runCompletedAt = new Date();
    const failedStageCount = Object.values(stageStatus).filter((status) => status === "failed").length;
    const runStatus = failedStageCount > 0 ? "failed" : "ok";

    return json({
      summary: {
        recovery: recoverySummary,
        candidate_intake: candidateIntakeSummary,
        enrichment: enrichmentSummary,
        creation: creationSummary,
        alias_auto_apply: aliasSummary,
        localization_auto_apply: localizationSummary,
        reconciliation_apply_modern_safe: reconciliationSummary,
      },
      metadata: {
        run_status: runStatus,
        started_at: runStartedAt.toISOString(),
        completed_at: runCompletedAt.toISOString(),
        duration_ms: Math.max(0, runCompletedAt.getTime() - runStartedAt.getTime()),
        mode: auth.mode,
        environment: resolveEnvironment(),
        debug_enabled: debugEnabled,
        debug_run_id: debugRunId,
        policy: {
          apply_aliases: applyAliases,
          apply_localizations: applyLocalizations,
          apply_reconciliation: applyReconciliation,
          dry_run: dryRun,
        },
        stage_status: stageStatus,
        limits: {
          recovery_limit: recoveryLimit,
          enrich_limit: enrichLimit,
          create_limit: createLimit,
          reconciliation_limit: reconciliationLimit,
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

    const response = await fetchWithTimeout(`${SUPABASE_URL}/functions/v1/${input.functionName}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey,
        Authorization: authHeader,
      },
      body: JSON.stringify(input.debug ? { limit: input.limit, debug: true } : { limit: input.limit }),
    }, FUNCTION_CALL_TIMEOUT_MS);

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

async function runAutoAliasStage(input: {
  userClient: ReturnType<typeof createClient> | null;
  limit: number;
  applyEnabled: boolean;
  dryRun: boolean;
}): Promise<Record<string, unknown>> {
  if (!input.applyEnabled) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "skipped_policy",
      detail: "apply_aliases_disabled",
    };
  }

  if (input.dryRun) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "skipped_dry_run",
      detail: "dry_run_enabled",
    };
  }

  if (!input.userClient) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "noop",
      detail: "no_user_context_alias_stage_not_executed",
    };
  }

  try {
    const { data, error } = await input.userClient.rpc("auto_apply_safe_aliases", {
      p_limit: input.limit,
      p_language_code: "it",
    });

    if (error) {
      const rpcError = formatRpcError(error);
      console.log(
        `[SEASON_CATALOG_AUTOMATION] phase=alias_auto_apply_rpc_failed ` +
        `message=${rpcError.message} code=${rpcError.code ?? "null"} ` +
        `details=${rpcError.details ?? "null"} hint=${rpcError.hint ?? "null"}`,
      );
      return {
        total: 1,
        succeeded: 0,
        skipped: 0,
        failed: 1,
        status: "failed",
        error: rpcError.message,
        rpc_error: rpcError,
      };
    }

    const rows = Array.isArray(data) ? data as AutoApplyRow[] : [];
    const succeeded = rows.filter((row) => String(row.result_status ?? "").toLowerCase() === "succeeded").length;
    const failed = rows.filter((row) => String(row.result_status ?? "").toLowerCase() === "failed").length;
    const skipped = Math.max(0, rows.length - succeeded - failed);
    const status = failed > 0 ? "failed" : (rows.length > 0 ? "ok" : "noop");
    const failedRows = rows
      .filter((row) => String(row.result_status ?? "").toLowerCase() === "failed")
      .map((row) => ({
        normalized_text: normalizeNullableText(row.normalized_text),
        canonical_candidate_slug: normalizeNullableText(row.canonical_candidate_slug),
        attempted_alias_text: normalizeNullableText(row.attempted_alias_text),
        match_method: normalizeNullableText(row.match_method),
        detail: normalizeNullableText(row.detail),
        error_message: normalizeNullableText(row.error_message),
      }));
    const failureSamples = failedRows.slice(0, 5);

    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=alias_auto_apply_rpc_response ` +
      `total=${rows.length} succeeded=${succeeded} skipped=${skipped} failed=${failed} status=${status}`,
    );
    if (failureSamples.length > 0) {
      console.log(
        `[SEASON_CATALOG_AUTOMATION] phase=alias_auto_apply_failed_rows samples=${JSON.stringify(failureSamples)}`,
      );
    }

    return {
      total: rows.length,
      succeeded,
      skipped,
      failed,
      status,
      failed_items: failureSamples,
      failed_items_total: failedRows.length,
      response_payload_size: rows.length,
    };
  } catch (error) {
    const message = String(error);
    console.log(
      `[SEASON_CATALOG_AUTOMATION] phase=alias_auto_apply_unhandled_error error=${message}`,
    );
    return {
      total: 1,
      succeeded: 0,
      skipped: 0,
      failed: 1,
      status: "failed",
      error: message,
    };
  }
}

async function runAutoLocalizationStage(input: {
  userClient: ReturnType<typeof createClient> | null;
  limit: number;
  applyEnabled: boolean;
  dryRun: boolean;
}): Promise<Record<string, unknown>> {
  if (!input.applyEnabled) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "skipped_policy",
      detail: "apply_localizations_disabled",
    };
  }

  if (input.dryRun) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "skipped_dry_run",
      detail: "dry_run_enabled",
    };
  }

  if (!input.userClient) {
    return {
      total: 0,
      succeeded: 0,
      skipped: 0,
      failed: 0,
      status: "noop",
      detail: "no_user_context_localization_stage_not_executed",
    };
  }

  try {
    const { data, error } = await input.userClient.rpc("auto_apply_safe_localizations", {
      p_limit: input.limit,
      p_language_code: "it",
    });

    if (error) {
      throw new Error(error.message);
    }

    const rows = Array.isArray(data) ? data as AutoApplyRow[] : [];
    const succeeded = rows.filter((row) => String(row.result_status ?? "").toLowerCase() === "succeeded").length;
    const failed = rows.filter((row) => String(row.result_status ?? "").toLowerCase() === "failed").length;
    const skipped = Math.max(0, rows.length - succeeded - failed);
    const status = failed > 0 ? "failed" : (rows.length > 0 ? "ok" : "noop");

    return {
      total: rows.length,
      succeeded,
      skipped,
      failed,
      status,
    };
  } catch (error) {
    return {
      total: 1,
      succeeded: 0,
      skipped: 0,
      failed: 1,
      status: "failed",
      error: String(error),
    };
  }
}

async function runModernReconciliationStage(input: {
  userClient: ReturnType<typeof createClient> | null;
  limit: number;
  applyEnabled: boolean;
  dryRun: boolean;
}): Promise<Record<string, unknown>> {
  if (!input.applyEnabled) {
    return {
      total: 0,
      applied: 0,
      skipped: 0,
      failed: 0,
      status: "skipped_policy",
      detail: "apply_reconciliation_disabled",
    };
  }

  if (!input.userClient) {
    return {
      total: 0,
      applied: 0,
      skipped: 0,
      failed: 0,
      status: "noop",
      detail: "no_user_context_reconciliation_stage_not_executed",
    };
  }

  try {
    if (input.dryRun) {
      const { data, error } = await input.userClient.rpc("preview_safe_recipe_ingredient_reconciliation", {
        p_limit: input.limit,
        p_only_safe: true,
      });
      if (error) {
        throw new Error(error.message);
      }
      const rows = Array.isArray(data) ? data : [];
      return {
        total: rows.length,
        applied: 0,
        skipped: rows.length,
        failed: 0,
        status: "skipped_dry_run",
        detail: "dry_run_enabled_preview_only",
      };
    }

    const { data, error } = await input.userClient.rpc("apply_recipe_ingredient_reconciliation_modern", {
      p_limit: input.limit,
      p_recipe_ids: null,
    });

    if (error) {
      throw new Error(error.message);
    }

    const rows = Array.isArray(data) ? data as ReconciliationApplyRow[] : [];
    const applied = rows.filter((row) => row.applied === true && String(row.apply_status ?? "").toLowerCase() === "applied").length;
    const failed = rows.filter((row) => row.applied !== true && !isReconciliationSkipStatus(row.apply_status)).length;
    const skipped = Math.max(0, rows.length - applied - failed);
    const status = failed > 0 ? "failed" : (rows.length > 0 ? "ok" : "noop");

    return {
      total: rows.length,
      applied,
      skipped,
      failed,
      status,
    };
  } catch (error) {
    return {
      total: 1,
      applied: 0,
      skipped: 0,
      failed: 1,
      status: "failed",
      error: String(error),
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

function decodeBooleanWithDefault(payload: unknown, fallback: boolean): boolean {
  if (payload === null || payload === undefined) return fallback;
  return decodeBoolean(payload);
}

function isReconciliationSkipStatus(value: unknown): boolean {
  const status = String(value ?? "").trim().toLowerCase();
  if (!status) return false;
  return status === "already_resolved" ||
    status === "recipe_not_found_or_no_ingredients" ||
    status === "ingredient_index_not_found" ||
    status === "matched_ingredient_missing" ||
    status === "failed_to_build_updated_ingredients";
}

function resolveEnvironment(): string {
  return firstEnv(["CATALOG_AUTOPILOT_ENV", "SUPABASE_ENV", "DENO_ENV"], "unknown");
}

function normalizeNullableText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function formatRpcError(error: unknown): { message: string; code: string | null; details: string | null; hint: string | null } {
  if (isRecord(error)) {
    return {
      message: String(error.message ?? "unknown_rpc_error"),
      code: normalizeNullableText(error.code),
      details: normalizeNullableText(error.details),
      hint: normalizeNullableText(error.hint),
    };
  }
  return {
    message: String(error ?? "unknown_rpc_error"),
    code: null,
    details: null,
    hint: null,
  };
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
  return jsonResponse(body, init);
}

function errorJson(status: number, code: string, message: string): Response {
  return json({ error: code, message }, { status });
}
