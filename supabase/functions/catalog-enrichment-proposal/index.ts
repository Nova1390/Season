import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  CATALOG_ENRICHMENT_SYSTEM_PROMPT,
  type CatalogEnrichmentProposal,
  validateCatalogEnrichmentProposal,
} from "./llm_contract.ts";

interface CatalogEnrichmentRequest {
  normalized_text?: string;
}

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_API_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-5.4-mini";
const PROVIDER_TIMEOUT_MS = Number(Deno.env.get("CATALOG_ENRICHMENT_PROVIDER_TIMEOUT_MS") ?? "15000");
const MAX_NORMALIZED_TEXT_LENGTH = 120;

Deno.serve(async (request) => {
  try {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=request_received method=${request.method}`);

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

    const auth = await resolveCallerAuth(request);
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
    }

    let payload: CatalogEnrichmentRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const normalizedText = normalizeText(payload.normalized_text);
    if (!normalizedText) {
      return errorJson(422, "INVALID_INPUT", "normalized_text is required.");
    }

    if (normalizedText.length > MAX_NORMALIZED_TEXT_LENGTH) {
      return errorJson(422, "INVALID_INPUT", `normalized_text exceeds max length (${MAX_NORMALIZED_TEXT_LENGTH}).`);
    }

    if (!OPENAI_API_KEY) {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_not_configured fallback=true");
      return json(buildFallbackProposal(normalizedText));
    }

    try {
      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_call_start");
      const providerOutput = await invokeProvider(normalizedText);
      const validation = validateCatalogEnrichmentProposal(providerOutput);

      if (!validation.ok || !validation.value) {
        console.log(
          `[SEASON_CATALOG_ENRICHMENT] phase=validator_failed fallback=true errors=${validation.errors.join(" | ")}`,
        );
        return json(buildFallbackProposal(normalizedText));
      }

      console.log("[SEASON_CATALOG_ENRICHMENT] phase=provider_call_success validator_ok=true");
      return json(withSafeDefaults(validation.value, normalizedText));
    } catch (error) {
      console.log(`[SEASON_CATALOG_ENRICHMENT] phase=provider_failed fallback=true error=${String(error)}`);
      return json(buildFallbackProposal(normalizedText));
    }
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICHMENT] phase=unhandled_error error=${String(error)}`);
    return json(buildFallbackProposal(""));
  }
});

async function resolveCallerAuth(request: Request): Promise<{ allowed: boolean; mode: "user" | "service_role" | "none" }> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearerToken = extractBearerToken(authHeader) ?? "";

  if (apikey && SUPABASE_SERVICE_ROLE_KEY && apikey === SUPABASE_SERVICE_ROLE_KEY) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=service_role");
    return { allowed: true, mode: "service_role" };
  }

  if (bearerToken && SUPABASE_SERVICE_ROLE_KEY && bearerToken === SUPABASE_SERVICE_ROLE_KEY) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=service_role");
    return { allowed: true, mode: "service_role" };
  }

  if (!bearerToken) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_missing");
    return { allowed: false, mode: "none" };
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.auth.getUser(bearerToken);
  if (error || !data.user?.id) {
    console.log("[SEASON_CATALOG_ENRICHMENT] phase=auth_invalid_user_token");
    return { allowed: false, mode: "none" };
  }

  console.log(`[SEASON_CATALOG_ENRICHMENT] phase=auth_resolved mode=user user_id=${data.user.id}`);
  return { allowed: true, mode: "user" };
}

async function invokeProvider(normalizedText: string): Promise<unknown> {
  const userPrompt = [
    "Generate a catalog enrichment proposal for this unresolved ingredient candidate.",
    "Return strict JSON only.",
    `normalized_text: ${normalizedText}`,
  ].join("\n");

  const payload = {
    model: OPENAI_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: CATALOG_ENRICHMENT_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userPrompt,
          },
        ],
      },
    ],
    temperature: 0,
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

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
      throw new Error(`provider_http_${response.status}: ${details}`);
    }

    const providerJSON = await response.json();
    const outputText = extractProviderOutputText(providerJSON);
    if (!outputText) {
      throw new Error("provider_missing_output_text");
    }

    const parsed = safeParseJSON(outputText);
    if (!parsed) {
      throw new Error("provider_invalid_json_output");
    }

    return parsed;
  } finally {
    clearTimeout(timeout);
  }
}

function withSafeDefaults(value: CatalogEnrichmentProposal, normalizedText: string): CatalogEnrichmentProposal {
  const fallback = buildFallbackProposal(normalizedText);
  const supportedUnits = dedupeUnits(value.supported_units);
  const defaultUnit = value.default_unit.trim() || fallback.default_unit;
  const units = supportedUnits.includes(defaultUnit) ? supportedUnits : dedupeUnits([defaultUnit, ...supportedUnits]);
  const ingredientType = normalizedIngredientType(value.ingredient_type, normalizedText);

  return {
    ingredient_type: ingredientType,
    canonical_name_it: cleanNullableString(value.canonical_name_it),
    canonical_name_en: cleanNullableString(value.canonical_name_en),
    suggested_slug: toSnakeCase(value.suggested_slug) || fallback.suggested_slug,
    default_unit: defaultUnit,
    supported_units: units.length > 0 ? units : fallback.supported_units,
    is_seasonal: ingredientType === "produce" ? value.is_seasonal : null,
    season_months: ingredientType === "produce" ? value.season_months : null,
    needs_manual_review: true,
    reasoning_summary: value.reasoning_summary?.trim() || fallback.reasoning_summary,
    confidence_score: clamp01(value.confidence_score),
  };
}

function buildFallbackProposal(normalizedText: string): CatalogEnrichmentProposal {
  const safeText = normalizeText(normalizedText);
  const slug = toSnakeCase(safeText || "unknown_ingredient");
  const titleIt = safeText ? toTitleCase(safeText) : null;

  return {
    ingredient_type: "unknown",
    canonical_name_it: titleIt,
    canonical_name_en: null,
    suggested_slug: slug,
    default_unit: "g",
    supported_units: ["g", "piece"],
    is_seasonal: null,
    season_months: null,
    needs_manual_review: true,
    reasoning_summary: "Fallback proposal generated due to provider unavailability or invalid output.",
    confidence_score: 0.1,
  };
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

function normalizedIngredientType(
  proposedType: CatalogEnrichmentProposal["ingredient_type"],
  normalizedText: string,
): CatalogEnrichmentProposal["ingredient_type"] {
  const text = normalizeText(normalizedText).toLowerCase();
  if (proposedType === "produce" && isSeafoodShellfishTerm(text)) {
    console.log(
      `[SEASON_CATALOG_ENRICHMENT] phase=ingredient_type_override reason=seafood_shellfish normalized_text=${text} from=produce to=basic`,
    );
    return "basic";
  }
  return proposedType;
}

function isSeafoodShellfishTerm(value: string): boolean {
  if (!value) return false;

  return /\b(vongol[ae]|cozz[ae]|calamar[io]|scamp[io]|seppi[ae]|gamber[io]|canocchi[ea]|astice|aragosta|frutti di mare|mollusch[io])\b/i
    .test(value);
}

function normalizeText(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim();
}

function cleanNullableString(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toSnakeCase(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_{2,}/g, "_") || "unknown_ingredient";
}

function toTitleCase(value: string): string {
  return value
    .split(/\s+/)
    .filter(Boolean)
    .map((token) => token.charAt(0).toUpperCase() + token.slice(1))
    .join(" ");
}

function dedupeUnits(units: string[]): string[] {
  const unique = new Set<string>();
  for (const raw of units) {
    const cleaned = raw.trim();
    if (cleaned) unique.add(cleaned);
  }
  return Array.from(unique);
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function extractBearerToken(authHeader: string): string | null {
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const token = match[1]?.trim();
  return token ? token : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function errorJson(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ ok: false, error: { code, message } }),
    {
      status,
      headers: JSON_HEADERS,
    },
  );
}

function json(payload: CatalogEnrichmentProposal): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: JSON_HEADERS,
  });
}
