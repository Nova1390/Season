import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  RECIPE_IMPORT_LLM_SYSTEM_PROMPT,
  validateLLMRecipeImportOutput,
} from "./llm_contract.ts";

interface ParseRecipeCaptionRequest {
  caption?: string;
  url?: string;
  languageCode?: string;
}

type ImportConfidence = "high" | "medium" | "low";

interface ParsedIngredient {
  name: string;
  quantity: number | null;
  unit: string | null;
}

interface ParseRecipeCaptionResponse {
  ok: boolean;
  result?: {
    title: string | null;
    ingredients: ParsedIngredient[];
    steps: string[];
    prepTimeMinutes: number | null;
    cookTimeMinutes: number | null;
    confidence: ImportConfidence;
    inferredDish: string | null;
  };
  error?: {
    code: string;
    message: string;
  };
  meta?: {
    languageCode?: string;
    usedServerLLM: boolean;
    userId?: string;
    dayBucket?: string;
    remainingToday?: number;
    retryAfterSeconds?: number;
  };
}

const MAX_CAPTION_LENGTH = 12_000;
const DEFAULT_LANGUAGE_CODE = "en";
const DAILY_IMPORT_LIMIT = Number(Deno.env.get("PARSE_RECIPE_DAILY_LIMIT") ?? "20");
const MIN_COOLDOWN_SECONDS = Number(Deno.env.get("PARSE_RECIPE_MIN_COOLDOWN_SECONDS") ?? "2");
const PROVIDER_TIMEOUT_MS = Number(Deno.env.get("PARSE_RECIPE_PROVIDER_TIMEOUT_MS") ?? "20000");

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PROVIDER_API_KEY = Deno.env.get("RECIPE_IMPORT_PROVIDER_API_KEY") ?? "";
const PROVIDER_API_URL = Deno.env.get("RECIPE_IMPORT_LLM_API_URL") ?? "https://api.openai.com/v1/responses";
const PROVIDER_MODEL = Deno.env.get("RECIPE_IMPORT_LLM_MODEL") ?? "gpt-5-mini";

Deno.serve(async (request) => {
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

  const authHeader = request.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const userResult = await userClient.auth.getUser();
  const userID = userResult.data.user?.id;
  if (!userID || userResult.error) {
    return errorJson(401, "UNAUTHENTICATED", "Authentication is required.");
  }

  let payload: ParseRecipeCaptionRequest;
  try {
    payload = await request.json();
  } catch {
    return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
  }

  const caption = normalizeText(payload.caption);
  const url = normalizeText(payload.url);
  const languageCode = normalizeLanguageCode(payload.languageCode);

  if (!caption && !url) {
    return errorJson(422, "EMPTY_INPUT", "Provide at least one of: caption or url.");
  }

  if (caption.length > MAX_CAPTION_LENGTH) {
    return errorJson(422, "CAPTION_TOO_LONG", `Caption exceeds max length (${MAX_CAPTION_LENGTH}).`);
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const dayBucket = new Date().toISOString().slice(0, 10);
  const quotaResult = await adminClient.rpc("consume_recipe_import_quota", {
    p_user_id: userID,
    p_day_bucket: dayBucket,
    p_daily_limit: DAILY_IMPORT_LIMIT,
    p_cooldown_seconds: MIN_COOLDOWN_SECONDS,
  });

  if (quotaResult.error || !Array.isArray(quotaResult.data) || quotaResult.data.length === 0) {
    return errorJson(500, "RATE_LIMIT_CHECK_FAILED", "Could not validate usage quota.");
  }

  const quota = quotaResult.data[0] as {
    allowed: boolean;
    reason: string;
    current_count: number;
    limit_count: number;
    retry_after_seconds: number;
  };

  if (!quota.allowed) {
    const code = quota.reason === "cooldown" ? "TOO_FREQUENT_REQUESTS" : "RATE_LIMIT_EXCEEDED";
    const message = quota.reason === "cooldown"
      ? "Please wait before sending another import request."
      : "Daily import limit reached.";

    return json(
      {
        ok: false,
        error: { code, message },
        meta: {
          usedServerLLM: false,
          userId: userID,
          dayBucket,
          remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          retryAfterSeconds: quota.retry_after_seconds,
        },
      },
      429,
    );
  }

  if (!PROVIDER_API_KEY) {
    return json(
      {
        ok: false,
        error: {
          code: "PROVIDER_NOT_CONFIGURED",
          message: "LLM provider key is not configured on the server.",
        },
        meta: {
          usedServerLLM: false,
          userId: userID,
          dayBucket,
          remainingToday: Math.max(0, quota.limit_count - quota.current_count),
        },
      },
      500,
    );
  }

  console.log(`[SEASON_IMPORT_EDGE] phase=llm_started user_id=${userID} day_bucket=${dayBucket}`);

  try {
    const llmOutput = await invokeProviderForRecipeParse({ caption, url, languageCode });
    const validation = validateLLMRecipeImportOutput(llmOutput);

    if (!validation.ok || !validation.value) {
      console.log(`[SEASON_IMPORT_EDGE] phase=llm_validation_failed user_id=${userID} errors=${validation.errors.join(" | ")}`);
      return json(
        {
          ok: false,
          error: {
            code: "PROVIDER_INVALID_OUTPUT",
            message: "Provider response did not match expected schema.",
          },
          meta: {
            usedServerLLM: true,
            userId: userID,
            dayBucket,
            remainingToday: Math.max(0, quota.limit_count - quota.current_count),
          },
        },
        502,
      );
    }

    const mappedResult: ParseRecipeCaptionResponse["result"] = {
      title: validation.value.title.trim() ? validation.value.title : null,
      ingredients: validation.value.ingredients.map((item) => ({
        name: item.name.trim(),
        quantity: item.quantity,
        unit: item.unit,
      })),
      steps: validation.value.steps.map((step) => step.trim()).filter(Boolean),
      prepTimeMinutes: validation.value.prepTimeMinutes,
      cookTimeMinutes: validation.value.cookTimeMinutes,
      confidence: validation.value.confidence,
      inferredDish: null,
    };

    console.log(`[SEASON_IMPORT_EDGE] phase=llm_ok user_id=${userID} ingredients=${mappedResult.ingredients.length} steps=${mappedResult.steps.length} confidence=${mappedResult.confidence}`);

    return json(
      {
        ok: true,
        result: mappedResult,
        meta: {
          languageCode,
          usedServerLLM: true,
          userId: userID,
          dayBucket,
          remainingToday: Math.max(0, quota.limit_count - quota.current_count),
        },
      },
      200,
    );
  } catch (error) {
    console.log(`[SEASON_IMPORT_EDGE] phase=llm_failed user_id=${userID} error=${String(error)}`);

    return json(
      {
        ok: false,
        error: {
          code: "PROVIDER_REQUEST_FAILED",
          message: "Provider request failed.",
        },
        meta: {
          usedServerLLM: true,
          userId: userID,
          dayBucket,
          remainingToday: Math.max(0, quota.limit_count - quota.current_count),
        },
      },
      502,
    );
  }
});

async function invokeProviderForRecipeParse(input: {
  caption: string;
  url: string;
  languageCode: string;
}): Promise<unknown> {
  const userContent = [
    `languageCode: ${input.languageCode}`,
    `url: ${input.url || ""}`,
    "caption:",
    input.caption,
  ].join("\n");

  const payload = {
    model: PROVIDER_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: RECIPE_IMPORT_LLM_SYSTEM_PROMPT,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userContent,
          },
        ],
      },
    ],
    temperature: 0,
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

  try {
    const response = await fetch(PROVIDER_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${PROVIDER_API_KEY}`,
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

function normalizeText(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function normalizeLanguageCode(value: unknown): string {
  if (typeof value !== "string") {
    return DEFAULT_LANGUAGE_CODE;
  }
  const cleaned = value.trim().toLowerCase();
  if (!cleaned) {
    return DEFAULT_LANGUAGE_CODE;
  }
  return cleaned.slice(0, 5);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function errorJson(status: number, code: string, message: string): Response {
  return json(
    {
      ok: false,
      error: { code, message },
      meta: {
        usedServerLLM: false,
      },
    },
    status,
  );
}

function json(payload: ParseRecipeCaptionResponse, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}
