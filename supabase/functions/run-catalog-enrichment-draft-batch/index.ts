import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

type RunnerMode = "user" | "service_role";

interface BatchRequest {
  limit?: number;
}

interface PendingDraftRow {
  normalized_text: string;
  status: string;
  occurrence_count: number | null;
  updated_at: string | null;
}

interface ProposalResponse {
  ingredient_type: "produce" | "basic" | "unknown";
  canonical_name_it: string | null;
  canonical_name_en: string | null;
  suggested_slug: string;
  default_unit: string;
  supported_units: string[];
  is_seasonal: boolean | null;
  season_months: number[] | null;
  needs_manual_review: boolean;
  reasoning_summary: string;
  confidence_score: number;
}

interface DraftMutationRow {
  normalized_text: string;
  status: string;
  ingredient_type: string;
  validated_ready: boolean;
  validation_errors: string[];
}

interface DraftValidateRow {
  normalized_text: string;
  status: string;
  ingredient_type: string;
  is_ready: boolean;
  validation_errors: string[];
}

interface ItemResult {
  normalized_text: string;
  result_status: "succeeded" | "failed" | "skipped";
  detail: string;
  error_message: string | null;
  validation_errors: string[];
  validation_passed: boolean;
  final_status: string;
}

Deno.serve(async (request) => {
  try {
    console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=request_received method=${request.method}`);

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
    console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=batch_started mode=${auth.mode} limit=${limit}`);

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const pendingDrafts = await fetchPendingDrafts(serviceClient, limit);
    const results: ItemResult[] = [];

    for (const draft of pendingDrafts) {
      const normalizedText = normalizeText(draft.normalized_text);
      if (!normalizedText) {
        results.push({
          normalized_text: draft.normalized_text,
          result_status: "skipped",
          detail: "invalid_normalized_text",
          error_message: null,
          validation_errors: [],
          validation_passed: false,
          final_status: draft.status,
        });
        continue;
      }

      try {
        const latestStatus = await currentDraftStatus(serviceClient, normalizedText);
        if (latestStatus !== "pending") {
          results.push({
            normalized_text: normalizedText,
            result_status: "skipped",
            detail: `status_not_pending:${latestStatus}`,
            error_message: null,
            validation_errors: [],
            validation_passed: false,
            final_status: latestStatus,
          });
          continue;
        }

        const proposal = await fetchProposalWithFallback(normalizedText);

        const upsertPending = await upsertDraft(serviceClient, normalizedText, proposal, "pending");
        const validation = await validateDraft(serviceClient, normalizedText);
        const validationErrors = validation.validation_errors ?? [];
        const validationPassed = validationErrors.length === 0;

        let finalStatus = upsertPending.status ?? "pending";
        let detail = "proposal_applied_pending";

        if (validationPassed) {
          const upsertReady = await upsertDraft(serviceClient, normalizedText, proposal, "ready");
          finalStatus = upsertReady.status ?? "ready";
          detail = "proposal_applied_and_marked_ready";
        }

        results.push({
          normalized_text: normalizedText,
          result_status: "succeeded",
          detail,
          error_message: null,
          validation_errors: validationErrors,
          validation_passed: validationPassed,
          final_status: finalStatus,
        });
      } catch (error) {
        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=item_failed normalized_text=${normalizedText} error=${String(error)}`,
        );
        results.push({
          normalized_text: normalizedText,
          result_status: "failed",
          detail: "enrichment_failed",
          error_message: String(error),
          validation_errors: [],
          validation_passed: false,
          final_status: "pending",
        });
      }
    }

    const summary = {
      total: results.length,
      succeeded: results.filter((item) => item.result_status === "succeeded").length,
      failed: results.filter((item) => item.result_status === "failed").length,
      skipped: results.filter((item) => item.result_status === "skipped").length,
      ready: results.filter((item) => item.final_status === "ready").length,
      pending: results.filter((item) => item.final_status === "pending").length,
    };

    console.log(
      `[SEASON_CATALOG_ENRICH_BATCH] phase=batch_completed total=${summary.total} succeeded=${summary.succeeded} failed=${summary.failed} skipped=${summary.skipped} ready=${summary.ready}`,
    );

    return json({
      summary,
      items: results,
      metadata: {
        mode: auth.mode,
        limit,
        generated_at: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=unhandled_error error=${String(error)}`);
    return errorJson(500, "INTERNAL_BATCH_ERROR", "Unexpected batch enrichment failure.");
  }
});

async function resolveAndAuthorize(request: Request): Promise<{ allowed: boolean; mode: RunnerMode }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = extractBearerToken(authHeader) ?? "";

  const isServiceRole =
    (apikey && apikey === SUPABASE_SERVICE_ROLE_KEY) ||
    (bearer && bearer === SUPABASE_SERVICE_ROLE_KEY);

  if (isServiceRole) {
    console.log("[SEASON_CATALOG_ENRICH_BATCH] phase=auth_ok mode=service_role");
    return { allowed: true, mode: "service_role" };
  }

  if (!bearer) {
    console.log("[SEASON_CATALOG_ENRICH_BATCH] phase=auth_missing_user_token");
    return { allowed: false, mode: "user" };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
  if (userError || !userData.user?.id) {
    console.log("[SEASON_CATALOG_ENRICH_BATCH] phase=auth_invalid_user_token");
    return { allowed: false, mode: "user" };
  }

  const { data: adminData, error: adminError } = await userClient.rpc("is_current_user_catalog_admin");
  const isAdmin = adminError ? false : decodeBoolean(adminData);
  console.log(
    `[SEASON_CATALOG_ENRICH_BATCH] phase=auth_user_checked user_id=${userData.user.id} is_admin=${isAdmin}`,
  );

  return { allowed: isAdmin, mode: "user" };
}

async function fetchPendingDrafts(client: ReturnType<typeof createClient>, limit: number): Promise<PendingDraftRow[]> {
  const { data, error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text,status,updated_at,custom_ingredient_observations(occurrence_count)")
    .eq("status", "pending")
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`pending_fetch_failed:${error.message}`);
  }

  return (data ?? [])
    .map((row: Record<string, unknown>) => {
      let occurrence = 0;
      if (Array.isArray(row.custom_ingredient_observations)) {
        occurrence = Number((row.custom_ingredient_observations[0] as Record<string, unknown> | undefined)?.occurrence_count ?? 0);
      } else if (row.custom_ingredient_observations && typeof row.custom_ingredient_observations === "object") {
        occurrence = Number((row.custom_ingredient_observations as Record<string, unknown>).occurrence_count ?? 0);
      }
      return {
        normalized_text: String(row.normalized_text ?? ""),
        status: String(row.status ?? "pending"),
        updated_at: row.updated_at ? String(row.updated_at) : null,
        occurrence_count: Number.isFinite(occurrence) ? occurrence : 0,
      } satisfies PendingDraftRow;
    })
    .sort((a, b) => {
      if ((a.occurrence_count ?? 0) !== (b.occurrence_count ?? 0)) {
        return (b.occurrence_count ?? 0) - (a.occurrence_count ?? 0);
      }
      return (b.updated_at ?? "").localeCompare(a.updated_at ?? "");
    });
}

async function currentDraftStatus(client: ReturnType<typeof createClient>, normalizedText: string): Promise<string> {
  const { data, error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("status")
    .eq("normalized_text", normalizedText)
    .maybeSingle();

  if (error) {
    throw new Error(`draft_status_fetch_failed:${error.message}`);
  }

  return String((data as Record<string, unknown> | null)?.status ?? "pending");
}

async function fetchProposalWithFallback(normalizedText: string): Promise<ProposalResponse> {
  const response = await fetch(`${SUPABASE_URL}/functions/v1/catalog-enrichment-proposal`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ normalized_text: normalizedText }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`proposal_fetch_failed:${response.status}:${details}`);
  }

  const parsed = await response.json() as ProposalResponse;
  return {
    ingredient_type: parsed.ingredient_type ?? "unknown",
    canonical_name_it: parsed.canonical_name_it ?? null,
    canonical_name_en: parsed.canonical_name_en ?? null,
    suggested_slug: normalizeText(parsed.suggested_slug) ?? normalizedText.replace(/\s+/g, "_"),
    default_unit: normalizeText(parsed.default_unit) ?? "g",
    supported_units: normalizeUnits(parsed.supported_units, parsed.default_unit),
    is_seasonal: parsed.is_seasonal ?? null,
    season_months: Array.isArray(parsed.season_months)
      ? parsed.season_months.filter((month) => Number.isInteger(month) && month >= 1 && month <= 12)
      : null,
    needs_manual_review: parsed.needs_manual_review ?? true,
    reasoning_summary: parsed.reasoning_summary ?? "",
    confidence_score: clamp01(parsed.confidence_score),
  };
}

async function upsertDraft(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  proposal: ProposalResponse,
  status: "pending" | "ready",
): Promise<DraftMutationRow> {
  const params = {
    p_normalized_text: normalizedText,
    p_status: status,
    p_ingredient_type: proposal.ingredient_type,
    p_canonical_name_it: proposal.canonical_name_it,
    p_canonical_name_en: proposal.canonical_name_en,
    p_suggested_slug: proposal.suggested_slug,
    p_suggested_aliases: [],
    p_default_unit: proposal.default_unit,
    p_supported_units: proposal.supported_units,
    p_is_seasonal: proposal.is_seasonal,
    p_season_months: proposal.season_months ?? [],
    p_nutrition_fields: {},
    p_confidence_score: proposal.confidence_score,
    p_needs_manual_review: true,
    p_reasoning_summary: proposal.reasoning_summary,
    p_reviewer_note: "auto_enrichment_batch_v1",
  };

  const { data, error } = await client.rpc("upsert_catalog_ingredient_enrichment_draft", params);
  if (error) {
    throw new Error(`upsert_failed:${error.message}`);
  }
  const row = (Array.isArray(data) ? data[0] : data) as DraftMutationRow | null;
  if (!row) {
    throw new Error("upsert_failed:empty_response");
  }
  return row;
}

async function validateDraft(client: ReturnType<typeof createClient>, normalizedText: string): Promise<DraftValidateRow> {
  const { data, error } = await client.rpc("validate_catalog_ingredient_enrichment_draft", {
    p_normalized_text: normalizedText,
  });
  if (error) {
    throw new Error(`validate_failed:${error.message}`);
  }
  const row = (Array.isArray(data) ? data[0] : data) as DraftValidateRow | null;
  if (!row) {
    throw new Error("validate_failed:empty_response");
  }
  return row;
}

function normalizeText(value: unknown): string | null {
  const text = String(value ?? "").trim().toLowerCase();
  return text.length > 0 ? text : null;
}

function normalizeUnits(units: unknown, fallbackDefaultUnit: unknown): string[] {
  const normalized = Array.isArray(units)
    ? units
        .map((unit) => String(unit ?? "").trim().toLowerCase())
        .filter((unit) => unit.length > 0)
    : [];

  const defaultUnit = String(fallbackDefaultUnit ?? "g").trim().toLowerCase() || "g";
  if (!normalized.includes(defaultUnit)) {
    normalized.push(defaultUnit);
  }

  return Array.from(new Set(normalized));
}

function clampLimit(value: number | undefined): number {
  if (!Number.isFinite(value)) return DEFAULT_LIMIT;
  const safe = Math.floor(Number(value));
  return Math.min(Math.max(safe, 1), MAX_LIMIT);
}

function clamp01(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0.1;
  return Math.max(0, Math.min(1, parsed));
}

function extractBearerToken(authorization: string): string | null {
  if (!authorization) return null;
  const [scheme, token] = authorization.trim().split(/\s+/);
  if (!scheme || !token || scheme.toLowerCase() !== "bearer") return null;
  return token;
}

function decodeBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "t" || normalized === "1";
  }
  if (Array.isArray(value) && value.length > 0) {
    return decodeBoolean(value[0]);
  }
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if ("is_current_user_catalog_admin" in record) {
      return decodeBoolean(record.is_current_user_catalog_admin);
    }
  }
  return false;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}

function errorJson(status: number, code: string, message: string): Response {
  return json({ ok: false, error: { code, message } }, status);
}
