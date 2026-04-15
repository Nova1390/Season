import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const MIN_CONFIDENCE = 0.6;

type RunnerMode = "user" | "service_role";

interface BatchRequest {
  limit?: number;
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

interface IngredientInsertRow {
  id: string;
  slug: string;
}

interface ItemResult {
  normalized_text: string;
  slug: string | null;
  result_status: "created" | "skipped_existing" | "skipped_invalid" | "failed";
  detail: string;
  ingredient_id: string | null;
  error_message: string | null;
}

Deno.serve(async (request) => {
  try {
    console.log(`[SEASON_INGREDIENT_CREATE_BATCH] phase=request_received method=${request.method}`);

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
    const actorId = auth.userId;
    console.log(
      `[SEASON_INGREDIENT_CREATE_BATCH] phase=batch_started mode=${auth.mode} limit=${limit} actor_id=${actorId ?? "null"}`,
    );

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const drafts = await fetchReadyDrafts(serviceClient, limit);
    const items: ItemResult[] = [];

    for (const draft of drafts) {
      const normalizedText = normalizeText(draft.normalized_text);
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

        const existing = await findIngredientBySlug(serviceClient, slug!);
        if (existing) {
          await markDraftApplied(serviceClient, normalizedText, actorId);
          items.push({
            normalized_text: normalizedText,
            slug,
            result_status: "skipped_existing",
            detail: "ingredient_already_exists",
            ingredient_id: existing.id,
            error_message: null,
          });
          console.log(
            `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_skipped_existing normalized_text=${normalizedText} slug=${slug} ingredient_id=${existing.id}`,
          );
          continue;
        }

        const ingredient = await createIngredient(serviceClient, draft, slug!);
        await upsertIngredientLocalizations(serviceClient, ingredient.id, draft);
        await upsertApprovedAlias(serviceClient, draft, ingredient.id, actorId);
        await markDraftApplied(serviceClient, normalizedText, actorId);

        items.push({
          normalized_text: normalizedText,
          slug,
          result_status: "created",
          detail: "ingredient_created",
          ingredient_id: ingredient.id,
          error_message: null,
        });
        console.log(
          `[SEASON_INGREDIENT_CREATE_BATCH] phase=item_created normalized_text=${normalizedText} slug=${slug} ingredient_id=${ingredient.id}`,
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
      total: items.length,
      created: items.filter((item) => item.result_status === "created").length,
      skipped_existing: items.filter((item) => item.result_status === "skipped_existing").length,
      skipped_invalid: items.filter((item) => item.result_status === "skipped_invalid").length,
      failed: items.filter((item) => item.result_status === "failed").length,
    };

    console.log(
      `[SEASON_INGREDIENT_CREATE_BATCH] phase=batch_completed total=${summary.total} created=${summary.created} skipped_existing=${summary.skipped_existing} skipped_invalid=${summary.skipped_invalid} failed=${summary.failed}`,
    );

    return json({
      summary,
      items,
      metadata: {
        mode: auth.mode,
        limit,
        minimum_confidence: MIN_CONFIDENCE,
        generated_at: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.log(`[SEASON_INGREDIENT_CREATE_BATCH] phase=unhandled_error error=${String(error)}`);
    return errorJson(500, "INTERNAL_BATCH_ERROR", "Unexpected ingredient creation batch failure.");
  }
});

async function resolveAndAuthorize(
  request: Request,
): Promise<{ allowed: boolean; mode: RunnerMode; userId: string | null }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = extractBearerToken(authHeader) ?? "";

  const isServiceRole =
    (apikey && apikey === SUPABASE_SERVICE_ROLE_KEY) ||
    (bearer && bearer === SUPABASE_SERVICE_ROLE_KEY);

  if (isServiceRole) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_ok mode=service_role");
    return { allowed: true, mode: "service_role", userId: null };
  }

  if (!bearer) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_missing_user_token");
    return { allowed: false, mode: "user", userId: null };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
  if (userError || !userData.user?.id) {
    console.log("[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_invalid_user_token");
    return { allowed: false, mode: "user", userId: null };
  }

  const { data: adminData, error: adminError } = await userClient.rpc("is_current_user_catalog_admin");
  const isAdmin = adminError ? false : decodeBoolean(adminData);
  console.log(
    `[SEASON_INGREDIENT_CREATE_BATCH] phase=auth_user_checked user_id=${userData.user.id} is_admin=${isAdmin}`,
  );

  return { allowed: isAdmin, mode: "user", userId: userData.user.id };
}

async function fetchReadyDrafts(client: ReturnType<typeof createClient>, limit: number): Promise<ReadyDraftRow[]> {
  const { data, error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select(
      "normalized_text,status,ingredient_type,canonical_name_it,canonical_name_en,suggested_slug,default_unit,supported_units,is_seasonal,season_months,confidence_score,parent_candidate_slug,variant_kind,specificity_rank_suggestion,updated_at",
    )
    .eq("status", "ready")
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`ready_drafts_fetch_failed:${error.message}`);
  }

  return (data ?? []) as ReadyDraftRow[];
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

async function findIngredientBySlug(
  client: ReturnType<typeof createClient>,
  slug: string,
): Promise<IngredientInsertRow | null> {
  const { data, error } = await client
    .from("ingredients")
    .select("id,slug")
    .eq("slug", slug)
    .maybeSingle();

  if (error) {
    throw new Error(`ingredient_lookup_failed:${error.message}`);
  }

  if (!data) return null;
  return data as IngredientInsertRow;
}

async function createIngredient(
  client: ReturnType<typeof createClient>,
  draft: ReadyDraftRow,
  slug: string,
): Promise<IngredientInsertRow> {
  const defaultUnit = normalizeText(draft.default_unit) ?? "g";
  const supportedUnits = normalizeUnits(draft.supported_units, defaultUnit);
  const isSeasonal = draft.ingredient_type === "produce" ? Boolean(draft.is_seasonal) : false;
  const seasonMonths =
    draft.ingredient_type === "produce" && draft.is_seasonal
      ? normalizeSeasonMonths(draft.season_months)
      : [];
  const hierarchy = await resolveHierarchyInsert(client, draft, slug);

  const { data, error } = await client
    .from("ingredients")
    .insert({
      slug,
      ingredient_type: draft.ingredient_type,
      default_unit: defaultUnit,
      supported_units: supportedUnits,
      is_seasonal: isSeasonal,
      season_months: seasonMonths,
      parent_ingredient_id: hierarchy.parentIngredientID,
      specificity_rank: hierarchy.specificityRank,
      variant_kind: hierarchy.variantKind,
    })
    .select("id,slug")
    .single();

  if (error) {
    throw new Error(`ingredient_insert_failed:${error.message}`);
  }

  return data as IngredientInsertRow;
}

async function resolveHierarchyInsert(
  client: ReturnType<typeof createClient>,
  draft: ReadyDraftRow,
  slug: string,
): Promise<{ parentIngredientID: string | null; specificityRank: number; variantKind: string }> {
  const fallback = {
    parentIngredientID: null,
    specificityRank: 0,
    variantKind: "base",
  };

  const parentCandidateSlug = toSlug(draft.parent_candidate_slug);
  const variantKind = normalizeVariantKind(draft.variant_kind);
  const specificityRankSuggestion = normalizeSpecificityRankSuggestion(draft.specificity_rank_suggestion);
  const selfSlug = toSlug(slug);

  if (!parentCandidateSlug || !variantKind || !specificityRankSuggestion) {
    return fallback;
  }

  if (selfSlug && parentCandidateSlug === selfSlug) {
    return fallback;
  }

  const { data, error } = await client
    .from("ingredients")
    .select("id")
    .eq("slug", parentCandidateSlug)
    .limit(1)
    .maybeSingle();

  if (error) {
    console.log(
      `[SEASON_INGREDIENT_CREATE_BATCH] phase=hierarchy_parent_lookup_failed parent_slug=${parentCandidateSlug} error=${error.message}`,
    );
    return fallback;
  }

  const parentIngredientID = typeof data?.id === "string" ? data.id : null;
  if (!parentIngredientID) {
    return fallback;
  }

  return {
    parentIngredientID,
    specificityRank: specificityRankSuggestion,
    variantKind,
  };
}

async function upsertIngredientLocalizations(
  client: ReturnType<typeof createClient>,
  ingredientId: string,
  draft: ReadyDraftRow,
): Promise<void> {
  const canonicalIt = normalizeText(draft.canonical_name_it);
  if (!canonicalIt) {
    throw new Error("missing_canonical_name_it");
  }

  const rows: Record<string, unknown>[] = [
    {
      ingredient_id: ingredientId,
      language_code: "it",
      display_name: canonicalIt,
    },
  ];

  const canonicalEn = normalizeText(draft.canonical_name_en);
  if (canonicalEn) {
    rows.push({
      ingredient_id: ingredientId,
      language_code: "en",
      display_name: canonicalEn,
    });
  }

  const { error } = await client
    .from("ingredient_localizations")
    .upsert(rows, { onConflict: "ingredient_id,language_code" });

  if (error) {
    throw new Error(`localization_upsert_failed:${error.message}`);
  }
}

async function upsertApprovedAlias(
  client: ReturnType<typeof createClient>,
  draft: ReadyDraftRow,
  ingredientId: string,
  actorId: string | null,
): Promise<void> {
  const normalized = normalizeText(draft.normalized_text);
  if (!normalized) {
    throw new Error("missing_normalized_text");
  }

  const { data: existingAlias, error: aliasLookupError } = await client
    .from("ingredient_aliases_v2")
    .select("id,ingredient_id")
    .eq("normalized_alias_text", normalized)
    .eq("is_active", true)
    .limit(1)
    .maybeSingle();

  if (aliasLookupError) {
    throw new Error(`alias_lookup_failed:${aliasLookupError.message}`);
  }

  if (existingAlias && String(existingAlias.ingredient_id) !== ingredientId) {
    throw new Error("alias_conflict_existing_target");
  }

  if (existingAlias) {
    const { error: aliasUpdateError } = await client
      .from("ingredient_aliases_v2")
      .update({
        status: "approved",
        approval_source: "manual",
        approved_at: new Date().toISOString(),
        approved_by: actorId,
        review_notes: "auto_applied_from_ready_enrichment_draft",
      })
      .eq("id", existingAlias.id);

    if (aliasUpdateError) {
      throw new Error(`alias_update_failed:${aliasUpdateError.message}`);
    }
    return;
  }

  const aliasText = normalizeText(draft.canonical_name_it) ?? normalized;
  const { error: aliasInsertError } = await client
    .from("ingredient_aliases_v2")
    .insert({
      ingredient_id: ingredientId,
      alias_text: aliasText,
      normalized_alias_text: normalized,
      language_code: "it",
      source: "import_observation",
      confidence_score: draft.confidence_score,
      is_active: true,
      status: "approved",
      approval_source: "manual",
      approved_at: new Date().toISOString(),
      approved_by: actorId,
      review_notes: "auto_applied_from_ready_enrichment_draft",
    });

  if (aliasInsertError) {
    throw new Error(`alias_insert_failed:${aliasInsertError.message}`);
  }
}

async function markDraftApplied(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  actorId: string | null,
): Promise<void> {
  const payload: Record<string, unknown> = {
    status: "applied",
    updated_at: new Date().toISOString(),
    updated_by: actorId,
    reviewed_by: actorId,
  };

  const { error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .update(payload)
    .eq("normalized_text", normalizedText)
    .eq("status", "ready");

  if (error) {
    throw new Error(`draft_mark_applied_failed:${error.message}`);
  }
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

function normalizeSeasonMonths(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  const months = value
    .map((month) => Number(month))
    .filter((month) => Number.isInteger(month) && month >= 1 && month <= 12) as number[];
  return Array.from(new Set(months)).sort((a, b) => a - b);
}

function normalizeVariantKind(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeSpecificityRankSuggestion(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) return null;
  return parsed;
}

function clampLimit(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_LIMIT;
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
