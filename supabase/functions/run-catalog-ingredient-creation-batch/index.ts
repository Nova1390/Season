import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  env,
  extractBearerToken,
  jsonResponse,
  numberEnv,
} from "../_shared/edge.ts";
import { requestIdFromHeaders } from "../_shared/observability.ts";

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = boundedInteger(numberEnv("CATALOG_AGENT_INGREDIENT_CREATION_MAX_ITEMS", 3), 1, 10);
const MIN_CONFIDENCE = 0.6;
const WORKER_ENABLED = env("CATALOG_AGENT_INGREDIENT_CREATION_ENABLED", "false").toLowerCase() === "true";

type RunnerMode = "user" | "service_role";

type ServiceSupabaseClient = SupabaseClient<any, "public", "public", any, any>;

interface BatchRequest {
  limit?: number;
  source_domain?: string | null;
  agent_run_id?: number | null;
  agent_worker_job_id?: number | null;
  debug?: boolean;
}

interface ReadyDraftRow {
  normalized_text: string;
  status: string;
  ingredient_type: "produce" | "basic" | "unknown" | null;
  canonical_name_it: string | null;
  canonical_name_en: string | null;
  suggested_slug: string | null;
  default_unit: string | null;
  supported_units: string[] | null;
  is_seasonal: boolean | null;
  season_months: number[] | null;
  confidence_score: number | null;
  parent_candidate_slug: string | null;
  variant_kind: string | null;
  specificity_rank_suggestion: number | null;
  updated_at: string | null;
}

interface ItemResult {
  normalized_text: string;
  slug: string | null;
  result_status: "created" | "skipped_existing" | "skipped_invalid" | "failed";
  detail: string;
  ingredient_id: string | null;
  error_message: string | null;
}

interface CreateFromDraftRow {
  ingredient_id: string | null;
  normalized_text: string | null;
  slug: string | null;
  created_new: boolean | null;
  alias_created: boolean | null;
  resulting_observation_status: string | null;
}

Deno.serve(async (request) => {
  const requestId = requestIdFromHeaders(request);
  const startedAt = performance.now();
  let agentWorkerJobId: number | null = null;
  let serviceClient: ServiceSupabaseClient | null = null;

  try {
    console.log(`[SEASON_INGREDIENT_CREATE_BATCH] phase=request_received method=${request.method} request_id=${requestId}`);

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

    let payload: BatchRequest = {};
    try {
      payload = await request.json();
    } catch {
      payload = {};
    }

    const limit = clampLimit(payload.limit);
    const sourceDomain = normalizeText(payload.source_domain);
    const agentRunId = positiveIntegerOrNull(payload.agent_run_id);
    agentWorkerJobId = positiveIntegerOrNull(payload.agent_worker_job_id);
    const debug = payload.debug === true;
    const actorId = auth.userId;
    console.log(
      `[SEASON_INGREDIENT_CREATE_BATCH] phase=batch_started mode=${auth.mode} enabled=${WORKER_ENABLED} limit=${limit} source_domain=${sourceDomain ?? "null"} actor_id=${actorId ?? "null"} agent_run_id=${agentRunId ?? "null"} worker_job_id=${agentWorkerJobId ?? "null"}`,
    );

    serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const writerClient = auth.bearerToken
      ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${auth.bearerToken}` } },
      })
      : serviceClient;

    if (agentWorkerJobId !== null) {
      await startWorkerJob(serviceClient, agentWorkerJobId);
    }

    if (!WORKER_ENABLED) {
      throw new WorkerDisabledError("ingredient_creation_worker_disabled");
    }

    const drafts = await fetchReadyDrafts(serviceClient, limit, sourceDomain);
    const items: ItemResult[] = [];

    for (const draft of drafts) {
      const normalizedText = normalizeText(draft.normalized_text) ?? "";
      const slug = toSlug(draft.suggested_slug);

      try {
        console.log(
          `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_started normalized_text=${normalizedText} slug=${slug ?? "null"}`,
        );

        const invalidReason = invalidDraftReason(draft, slug);
        if (invalidReason) {
          items.push({
            normalized_text: normalizedText,
            slug,
            result_status: "skipped_invalid",
            detail: invalidReason,
            ingredient_id: null,
            error_message: null,
          });
          console.log(
            `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_skipped_invalid normalized_text=${normalizedText} reason=${invalidReason}`,
          );
          continue;
        }

        const creation = await createIngredientFromDraft(writerClient, draft);

        const createdNew = creation.created_new === true;
        const ingredientID = normalizeText(creation.ingredient_id);
        const resultSlug = toSlug(creation.slug) ?? slug;
        const resultStatus = createdNew ? "created" : "skipped_existing";
        const detail = createdNew ? "ingredient_created" : "ingredient_already_exists";

        items.push({
          normalized_text: normalizedText,
          slug: resultSlug,
          result_status: resultStatus,
          detail,
          ingredient_id: ingredientID,
          error_message: null,
        });
        console.log(
          `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_${resultStatus} normalized_text=${normalizedText} slug=${resultSlug ?? "null"} ingredient_id=${ingredientID ?? "null"}`,
        );
      } catch (error) {
        const message = String(error);
        items.push({
          normalized_text: normalizedText,
          slug,
          result_status: "failed",
          detail: "creation_failed",
          ingredient_id: null,
          error_message: message,
        });
        console.log(
          `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_failed normalized_text=${normalizedText} slug=${slug ?? "null"} error=${message}`,
        );
      }
    }

    const summary = {
      mode: "create_ingredient",
      total: items.length,
      created: items.filter((item) => item.result_status === "created").length,
      skipped_existing: items.filter((item) => item.result_status === "skipped_existing").length,
      skipped_invalid: items.filter((item) => item.result_status === "skipped_invalid").length,
      failed: items.filter((item) => item.result_status === "failed").length,
      duration_ms: elapsedMs(startedAt),
    };

    if (agentWorkerJobId !== null) {
      await completeWorkerJob(serviceClient, agentWorkerJobId, summary);
    }

    console.log(
      `[SEASON_INGREDIENT_CREATE_BATCH] phase=batch_completed total=${summary.total} created=${summary.created} skipped_existing=${summary.skipped_existing} skipped_invalid=${summary.skipped_invalid} failed=${summary.failed}`,
    );

    return json({
      summary,
      items,
      agent_run_id: agentRunId,
      agent_worker_job_id: agentWorkerJobId,
      debug,
      metadata: {
        mode: auth.mode,
        limit,
        source_domain: sourceDomain,
        minimum_confidence: MIN_CONFIDENCE,
        generated_at: new Date().toISOString(),
      },
    });
  } catch (error) {
    const message = String(error);
    console.log(`[SEASON_INGREDIENT_CREATE_BATCH] phase=unhandled_error request_id=${requestId} error=${message}`);

    if (serviceClient && agentWorkerJobId !== null) {
      await failWorkerJob(serviceClient, agentWorkerJobId, message, {
        duration_ms: elapsedMs(startedAt),
        request_id: requestId,
      });
    }

    if (error instanceof WorkerDisabledError) {
      return errorJson(403, "INGREDIENT_CREATION_DISABLED", "Ingredient creation worker is disabled.");
    }

    return errorJson(500, "INTERNAL_BATCH_ERROR", "Unexpected ingredient creation batch failure.");
  }
});

async function resolveAndAuthorize(
  request: Request,
): Promise<{ allowed: boolean; mode: RunnerMode; userId: string | null; bearerToken: string | null }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = extractBearerToken(authHeader) ?? "";

  const isServiceRole =
    (apikey && apikey === SUPABASE_SERVICE_ROLE_KEY) ||
    (bearer && bearer === SUPABASE_SERVICE_ROLE_KEY);

  if (isServiceRole) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_ok mode=service_role");
    return { allowed: true, mode: "service_role", userId: null, bearerToken: null };
  }

  if (!bearer) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_missing_user_token");
    return { allowed: false, mode: "user", userId: null, bearerToken: null };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
  if (userError || !userData.user?.id) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_invalid_user_token");
    return { allowed: false, mode: "user", userId: null, bearerToken: null };
  }

  const { data: adminData, error: adminError } = await userClient.rpc("is_current_user_catalog_admin");
  const isAdmin = adminError ? false : decodeBoolean(adminData);
  console.log(
    `[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_user_checked user_id=${userData.user.id} is_admin=${isAdmin}`,
  );

  return { allowed: isAdmin, mode: "user", userId: userData.user.id, bearerToken: bearer };
}

async function fetchReadyDrafts(
  client: ServiceSupabaseClient,
  limit: number,
  sourceDomain: string | null,
): Promise<ReadyDraftRow[]> {
  let normalizedTexts: string[] | null = null;

  if (sourceDomain) {
    const { data: observations, error: observationError } = await client
      .from("custom_ingredient_observations")
      .select("normalized_text")
      .eq("source", sourceDomain)
      .limit(500);

    if (observationError) {
      throw new Error(`source_observations_fetch_failed:${observationError.message}`);
    }

    normalizedTexts = Array.from(new Set((observations ?? [])
      .map((row) => normalizeText((row as Record<string, unknown>).normalized_text))
      .filter((value): value is string => Boolean(value))));

    if (normalizedTexts.length === 0) {
      return [];
    }
  }

  let query = client
    .from("catalog_ingredient_enrichment_drafts")
    .select(
      "normalized_text,status,ingredient_type,canonical_name_it,canonical_name_en,suggested_slug,default_unit,supported_units,is_seasonal,season_months,confidence_score,parent_candidate_slug,variant_kind,specificity_rank_suggestion,updated_at",
    )
    .eq("status", "ready");

  if (normalizedTexts) {
    query = query.in("normalized_text", normalizedTexts);
  }

  const { data, error } = await query
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`ready_drafts_fetch_failed:${error.message}`);
  }

  return (data ?? []) as ReadyDraftRow[];
}

async function startWorkerJob(
  client: ServiceSupabaseClient,
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
  client: ServiceSupabaseClient,
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
  client: ServiceSupabaseClient,
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
    console.log(`[SEASON_INGREDIENT_CREATE_BATCH] phase=fail_worker_job_failed error=${error.message}`);
  }
}

function invalidDraftReason(draft: ReadyDraftRow, slug: string | null): string | null {
  const type = draft.ingredient_type;
  if (!type || type === "unknown") {
    return "invalid_type_unknown";
  }

  if (!slug) {
    return "missing_slug";
  }

  const confidence = Number(draft.confidence_score ?? 0);
  if (!Number.isFinite(confidence) || confidence < MIN_CONFIDENCE) {
    return "low_confidence";
  }

  const defaultUnit = normalizeText(draft.default_unit);
  if (!defaultUnit) {
    return "missing_default_unit";
  }

  const units = normalizeUnits(draft.supported_units, defaultUnit);
  if (units.length === 0) {
    return "missing_supported_units";
  }

  if (type === "produce" && draft.is_seasonal === null) {
    return "produce_requires_is_seasonal_considered";
  }

  const itName = normalizeText(draft.canonical_name_it);
  if (!itName) {
    return "missing_canonical_name_it";
  }

  return null;
}

async function createIngredientFromDraft(
  client: ServiceSupabaseClient,
  draft: ReadyDraftRow,
): Promise<CreateFromDraftRow> {
  const normalizedText = normalizeText(draft.normalized_text);
  if (!normalizedText) {
    throw new Error("missing_normalized_text");
  }

  const { data, error } = await client
    .rpc("create_catalog_ingredient_from_enrichment_draft", {
      p_normalized_text: normalizedText,
      p_reviewer_note: "auto_applied_from_ready_enrichment_draft",
      p_confidence_score: draft.confidence_score,
    });

  if (error) {
    throw new Error(`create_from_draft_failed:${error.message}`);
  }

  const rows = Array.isArray(data) ? data as CreateFromDraftRow[] : [];
  const row = rows[0];
  if (!row?.ingredient_id) {
    throw new Error("create_from_draft_returned_no_ingredient");
  }

  return row;
}

function normalizeText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toSlug(value: unknown): string | null {
  const text = normalizeText(value);
  if (!text) return null;
  const slug = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return slug.length > 0 ? slug : null;
}

function normalizeUnits(value: unknown, fallbackUnit: string): string[] {
  const units = Array.isArray(value) ? value : [];
  const normalized = units
    .map((unit) => (typeof unit === "string" ? unit.trim().toLowerCase() : ""))
    .filter((unit) => unit.length > 0);

  const fallback = (fallbackUnit || "g").trim().toLowerCase();
  if (!normalized.includes(fallback)) {
    normalized.unshift(fallback);
  }

  return Array.from(new Set(normalized));
}

function clampLimit(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_LIMIT;
  return Math.max(1, Math.min(MAX_LIMIT, Math.floor(parsed)));
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

function decodeBoolean(payload: unknown): boolean {
  if (typeof payload === "boolean") return payload;
  if (typeof payload === "string") return payload.toLowerCase() === "true";
  if (Array.isArray(payload) && payload.length > 0) return decodeBoolean(payload[0]);
  if (payload && typeof payload === "object" && "is_current_user_catalog_admin" in payload) {
    return decodeBoolean((payload as Record<string, unknown>).is_current_user_catalog_admin);
  }
  return false;
}

function json(body: unknown, init: ResponseInit = {}): Response {
  return jsonResponse(body, init);
}

function errorJson(status: number, code: string, message: string): Response {
  return json({ error: code, message }, { status });
}

class WorkerDisabledError extends Error {}
