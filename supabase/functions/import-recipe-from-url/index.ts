import { resolveCatalogAdminOrServiceRole } from "../_shared/auth.ts";
import {
  env,
  jsonResponseWithStatus,
  numberEnv,
} from "../_shared/edge.ts";

interface ImportRecipeFromURLRequest {
  url?: string;
}

interface ImportedRecipePreview {
  title: string;
  ingredients: string[];
  steps: string[];
  image_url: string | null;
  source_url: string;
  source_name: string;
}

interface JSONLDExtractionResult {
  blocks: unknown[];
  scriptBlockCount: number;
  parseSuccessCount: number;
  parseFailureCount: number;
}

const SUPABASE_URL = env("SUPABASE_URL");
const SUPABASE_ANON_KEY = env("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY");
const FETCH_TIMEOUT_MS = numberEnv("IMPORT_RECIPE_URL_FETCH_TIMEOUT_MS", 12000);
const MAX_HTML_BYTES = numberEnv("IMPORT_RECIPE_URL_MAX_HTML_BYTES", 2000000);
const MAX_REDIRECTS = numberEnv("IMPORT_RECIPE_URL_MAX_REDIRECTS", 5);

type ImportFetchErrorCode =
  | "URL_NOT_ALLOWED"
  | "REDIRECT_URL_NOT_ALLOWED"
  | "SOURCE_TOO_LARGE"
  | "TOO_MANY_REDIRECTS"
  | "FETCH_FAILED";

class ImportFetchError extends Error {
  readonly code: ImportFetchErrorCode;

  constructor(code: ImportFetchErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = "ImportFetchError";
  }
}

Deno.serve(async (request) => {
  let stage = "request_received";

  try {
    logInfo("request_received", { method: request.method });

    if (request.method !== "POST") {
      return errorJson(405, "METHOD_NOT_ALLOWED", "Only POST is supported.");
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return errorJson(500, "SERVER_MISCONFIGURED", "Supabase environment is not configured.");
    }

    const contentType = request.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("application/json")) {
      return errorJson(415, "INVALID_CONTENT_TYPE", "Request must use application/json.");
    }

    stage = "auth";
    const auth = await resolveCatalogAdminOrServiceRole(request, {
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
      supabaseServiceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      logPrefix: "SEASON_URL_IMPORT",
    });
    if (!auth.allowed) {
      return errorJson(401, "UNAUTHORIZED", "Catalog admin authentication is required.");
    }

    stage = "parse_body";
    let payload: ImportRecipeFromURLRequest;
    try {
      payload = await request.json();
    } catch {
      return errorJson(400, "INVALID_JSON", "Request body must be valid JSON.");
    }

    const rawURL = typeof payload.url === "string" ? payload.url : "";
    logInfo("incoming_raw_url", { raw_url: rawURL });

    stage = "normalize_url";
    const sourceURL = normalizeURL(payload.url);
    logInfo("normalized_url", { normalized_url: sourceURL || null });
    if (!sourceURL) {
      return errorJson(422, "INVALID_URL", "A valid absolute http/https URL is required.");
    }
    const disallowedReason = disallowedOutboundURLReason(sourceURL);
    if (disallowedReason) {
      logInfo("url_rejected", { reason: disallowedReason });
      return errorJson(422, "URL_NOT_ALLOWED", "URL host is not allowed.");
    }

    stage = "fetch_html";
    logInfo("fetch_started", { url: sourceURL });
    let fetchResult: { html: string; status: number; finalURL: string };
    try {
      fetchResult = await fetchHTML(sourceURL);
    } catch (error) {
      logError("fetch_failed", error, stage);
      if (error instanceof ImportFetchError) {
        if (error.code === "SOURCE_TOO_LARGE") {
          return errorJson(413, "SOURCE_TOO_LARGE", "Source page is too large to import.");
        }
        if (error.code === "URL_NOT_ALLOWED" || error.code === "REDIRECT_URL_NOT_ALLOWED") {
          return errorJson(422, "URL_NOT_ALLOWED", "URL host is not allowed.");
        }
      }
      return errorJson(502, "FETCH_FAILED", "Could not fetch source page.");
    }

    logInfo("fetch_completed", {
      status: fetchResult.status,
      final_url: fetchResult.finalURL,
    });
    logInfo("html_loaded", { html_length: fetchResult.html.length });

    stage = "extract_jsonld";
    const extraction = extractJSONLDBlocks(fetchResult.html);
    logInfo("jsonld_scan_completed", {
      script_block_count: extraction.scriptBlockCount,
      parse_success_count: extraction.parseSuccessCount,
      parse_failure_count: extraction.parseFailureCount,
    });

    if (extraction.scriptBlockCount === 0) {
      return errorJson(422, "NO_STRUCTURED_DATA", "No JSON-LD script blocks found.");
    }

    if (extraction.parseSuccessCount === 0) {
      return errorJson(422, "JSONLD_PARSE_FAILED", "JSON-LD blocks were found but could not be parsed.");
    }

    stage = "find_recipe_node";
    const recipeNode = findRecipeNode(extraction.blocks);
    logInfo("recipe_node_search", { recipe_node_found: recipeNode !== null });
    if (!recipeNode) {
      return errorJson(422, "RECIPE_NODE_NOT_FOUND", "No Recipe node found in parsed JSON-LD.");
    }

    stage = "build_preview";
    const preview = buildRecipePreview(recipeNode, fetchResult.finalURL || sourceURL);
    if (!preview) {
      return errorJson(422, "NO_STRUCTURED_DATA", "Recipe structured data is present but incomplete.");
    }

    logInfo("extraction_success", {
      title: preview.title,
      ingredient_count: preview.ingredients.length,
      step_count: preview.steps.length,
      source_name: preview.source_name,
    });

    return json(preview, 200);
  } catch (error) {
    logError("internal_import_error", error, stage);
    return errorJson(500, "INTERNAL_IMPORT_ERROR", "Unexpected import failure.");
  }
});

async function fetchHTML(sourceURL: string): Promise<{ html: string; status: number; finalURL: string }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  let currentURL = sourceURL;

  try {
    for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount += 1) {
      const disallowedReason = disallowedOutboundURLReason(currentURL);
      if (disallowedReason) {
        throw new ImportFetchError("URL_NOT_ALLOWED", `url_not_allowed:${disallowedReason}`);
      }

      const response = await fetch(currentURL, {
        method: "GET",
        headers: {
          "user-agent": "SeasonBot/1.0 (+https://season.local)",
          "accept": "text/html,application/xhtml+xml",
        },
        redirect: "manual",
        signal: controller.signal,
      });

      if (isRedirectStatus(response.status)) {
        const location = response.headers.get("location");
        if (!location) {
          throw new ImportFetchError("FETCH_FAILED", `redirect_missing_location:${response.status}`);
        }

        const nextURL = normalizeRedirectURL(location, currentURL);
        const redirectDisallowedReason = nextURL ? disallowedOutboundURLReason(nextURL) : "invalid_redirect_url";
        if (!nextURL || redirectDisallowedReason) {
          throw new ImportFetchError(
            "REDIRECT_URL_NOT_ALLOWED",
            `redirect_url_not_allowed:${redirectDisallowedReason}`,
          );
        }

        currentURL = nextURL;
        continue;
      }

      if (!response.ok) {
        throw new ImportFetchError("FETCH_FAILED", `fetch_http_${response.status}`);
      }

      const contentLength = Number(response.headers.get("content-length") ?? "0");
      if (Number.isFinite(contentLength) && contentLength > MAX_HTML_BYTES) {
        throw new ImportFetchError("SOURCE_TOO_LARGE", `content_length_exceeded:${contentLength}`);
      }

      return {
        html: await readResponseTextWithLimit(response, MAX_HTML_BYTES),
        status: response.status,
        finalURL: response.url || currentURL,
      };
    }

    throw new ImportFetchError("TOO_MANY_REDIRECTS", `too_many_redirects:${MAX_REDIRECTS}`);
  } finally {
    clearTimeout(timeout);
  }
}

async function readResponseTextWithLimit(response: Response, maxBytes: number): Promise<string> {
  if (!response.body) return "";

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;

    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      try {
        await reader.cancel();
      } catch {
        // Best effort: response is already being rejected for size.
      }
      throw new ImportFetchError("SOURCE_TOO_LARGE", `body_size_exceeded:${totalBytes}`);
    }
    chunks.push(value);
  }

  const merged = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return new TextDecoder().decode(merged);
}

function normalizeRedirectURL(location: string, baseURL: string): string {
  const trimmed = location.trim();
  if (!trimmed) return "";

  try {
    const parsed = new URL(trimmed, baseURL);
    if (!(parsed.protocol === "http:" || parsed.protocol === "https:")) return "";
    return parsed.toString();
  } catch {
    return "";
  }
}

function isRedirectStatus(status: number): boolean {
  return status >= 300 && status <= 399;
}

function buildRecipePreview(recipeNode: Record<string, unknown>, sourceURL: string): ImportedRecipePreview | null {
  const title = normalizeWhitespace(readString(recipeNode.name) ?? readString(recipeNode.headline) ?? "");
  const ingredients = normalizeIngredientArray(readArray(recipeNode.recipeIngredient) ?? readArray(recipeNode.ingredients));
  const steps = extractSteps(recipeNode.recipeInstructions);
  const imageURL = extractRecipeImageURL(recipeNode.image);

  if (!title && ingredients.length === 0 && steps.length === 0) {
    return null;
  }

  return {
    title: title || "Untitled recipe",
    ingredients,
    steps,
    image_url: imageURL,
    source_url: sourceURL,
    source_name: safeHostname(sourceURL),
  };
}

function extractRecipeImageURL(rawImage: unknown): string | null {
  if (!rawImage) return null;

  const candidates: string[] = [];

  const appendCandidate = (value: unknown) => {
    if (typeof value === "string") {
      const normalized = normalizeURL(value);
      if (normalized) candidates.push(normalized);
      return;
    }

    if (isRecord(value)) {
      const fromURL = readString(value.url);
      if (fromURL) {
        const normalized = normalizeURL(fromURL);
        if (normalized) candidates.push(normalized);
      }
      const fromContentURL = readString(value.contentUrl);
      if (fromContentURL) {
        const normalized = normalizeURL(fromContentURL);
        if (normalized) candidates.push(normalized);
      }
      return;
    }
  };

  if (Array.isArray(rawImage)) {
    for (const item of rawImage) appendCandidate(item);
  } else {
    appendCandidate(rawImage);
  }

  return candidates[0] ?? null;
}

function extractJSONLDBlocks(html: string): JSONLDExtractionResult {
  const blocks: unknown[] = [];
  let scriptBlockCount = 0;
  let parseSuccessCount = 0;
  let parseFailureCount = 0;

  const regex = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

  for (const match of html.matchAll(regex)) {
    scriptBlockCount += 1;
    const raw = (match[1] ?? "").trim();
    if (!raw) continue;

    const decoded = decodeBasicEntities(raw);
    const parsed = safeParseJSON(decoded);

    if (parsed !== null) {
      blocks.push(parsed);
      parseSuccessCount += 1;
    } else {
      parseFailureCount += 1;
    }
  }

  return {
    blocks,
    scriptBlockCount,
    parseSuccessCount,
    parseFailureCount,
  };
}

function findRecipeNode(blocks: unknown[]): Record<string, unknown> | null {
  for (const block of blocks) {
    const candidates = flattenJSONLDNodes(block);
    for (const candidate of candidates) {
      const type = candidate["@type"];
      if (typeMatchesRecipe(type)) {
        return candidate;
      }
    }
  }
  return null;
}

function flattenJSONLDNodes(input: unknown): Record<string, unknown>[] {
  if (Array.isArray(input)) {
    return input.flatMap((item) => flattenJSONLDNodes(item));
  }

  if (!isRecord(input)) return [];

  const graph = input["@graph"];
  if (Array.isArray(graph)) {
    return [input, ...graph.flatMap((item) => flattenJSONLDNodes(item))];
  }

  return [input];
}

function typeMatchesRecipe(type: unknown): boolean {
  if (typeof type === "string") {
    return type.toLowerCase().includes("recipe");
  }
  if (Array.isArray(type)) {
    return type.some((entry) => typeof entry === "string" && entry.toLowerCase().includes("recipe"));
  }
  return false;
}

function extractSteps(rawInstructions: unknown): string[] {
  const rows: string[] = [];

  if (typeof rawInstructions === "string") {
    rows.push(rawInstructions);
  } else if (Array.isArray(rawInstructions)) {
    for (const item of rawInstructions) {
      if (typeof item === "string") {
        rows.push(item);
      } else if (isRecord(item)) {
        const text = readString(item.text) ?? readString(item.name);
        if (text) rows.push(text);
      }
    }
  } else if (isRecord(rawInstructions)) {
    const text = readString(rawInstructions.text) ?? readString(rawInstructions.name);
    if (text) rows.push(text);
  }

  return normalizeStepArray(rows);
}

function normalizeIngredientArray(values: unknown[] | undefined): string[] {
  if (!Array.isArray(values)) return [];

  const out: string[] = [];
  for (const value of values) {
    if (typeof value !== "string") continue;
    const normalized = cleanIngredientLine(value);
    if (normalized) out.push(normalized);
  }

  return out;
}

function normalizeStepArray(values: unknown[] | undefined): string[] {
  if (!Array.isArray(values)) return [];

  const out: string[] = [];
  for (const value of values) {
    if (typeof value !== "string") continue;
    const normalized = cleanStepLine(value);
    if (normalized) out.push(normalized);
  }

  return out;
}

function cleanIngredientLine(value: string): string {
  let cleaned = normalizeWhitespace(value);
  cleaned = cleaned.replace(/\bq\s*\.?\s*b\s*\.?\b/gi, "");
  cleaned = cleaned.replace(/\bquanto\s+basta\b/gi, "");
  cleaned = cleaned.replace(/\s{2,}/g, " ");
  cleaned = cleaned.replace(/^[,;:\-–—\s]+/, "");
  cleaned = cleaned.replace(/[\.,;:\-–—\s]+$/, "");
  return normalizeWhitespace(cleaned);
}

function cleanStepLine(value: string): string {
  const raw = normalizeWhitespace(value);
  if (!raw) return "";

  const tokens = raw.split(" ");
  const kept: string[] = [];

  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i];
    if (isStandaloneNumberToken(token) && !isMeaningfulNumberContext(tokens, i)) {
      continue;
    }
    kept.push(token);
  }

  let cleaned = kept.join(" ");
  cleaned = cleaned.replace(/\s+([,.;:!?])/g, "$1");
  cleaned = cleaned.replace(/([([{])\s+/g, "$1");
  cleaned = cleaned.replace(/\s+([)\]}])/g, "$1");
  cleaned = cleaned.replace(/\s{2,}/g, " ");

  return normalizeWhitespace(cleaned);
}

function isStandaloneNumberToken(token: string): boolean {
  const normalized = token.trim().replace(/^[([{]+|[)\]},.;:!?]+$/g, "");
  return /^\d+(?:[.,]\d+)?$/.test(normalized);
}

function isMeaningfulNumberContext(tokens: string[], index: number): boolean {
  const next = normalizeUnitToken(tokens[index + 1] ?? "");
  const prev = normalizeUnitToken(tokens[index - 1] ?? "");

  if (MEANINGFUL_NUMBER_UNITS.has(next)) return true;
  if (MEANINGFUL_NUMBER_UNITS.has(prev)) return true;

  const rawPrev = (tokens[index - 1] ?? "").trim();
  const rawNext = (tokens[index + 1] ?? "").trim();
  if (rawPrev === "-" || rawNext === "-") return true;

  return false;
}

function normalizeUnitToken(token: string): string {
  return token
    .toLowerCase()
    .replace(/^[([{]+|[)\]},.;:!?]+$/g, "")
    .trim();
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function readString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readArray(value: unknown): unknown[] | undefined {
  return Array.isArray(value) ? value : undefined;
}

function normalizeURL(value: unknown): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  if (!trimmed) return "";

  try {
    const parsed = new URL(trimmed);
    if (!(parsed.protocol === "http:" || parsed.protocol === "https:")) return "";
    return parsed.toString();
  } catch {
    return "";
  }
}

function disallowedOutboundURLReason(url: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return "invalid_url";
  }

  if (!(parsed.protocol === "http:" || parsed.protocol === "https:")) {
    return "unsupported_protocol";
  }

  if (parsed.username || parsed.password) {
    return "credentials_not_allowed";
  }

  const hostname = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (!hostname) return "missing_hostname";

  if (isBlockedHostname(hostname)) {
    return "blocked_hostname";
  }

  if (isBlockedIPLiteral(hostname)) {
    return "blocked_ip_literal";
  }

  return null;
}

function isBlockedHostname(hostname: string): boolean {
  if (hostname === "localhost" || hostname === "localhost.localdomain") return true;
  if (hostname.endsWith(".localhost")) return true;
  if (hostname.endsWith(".local")) return true;
  if (hostname.endsWith(".internal")) return true;
  return false;
}

function isBlockedIPLiteral(hostname: string): boolean {
  const unwrapped = hostname.replace(/^\[|\]$/g, "");
  const lower = unwrapped.toLowerCase();
  if (lower.includes(":")) {
    if (lower === "::1" || lower === "0:0:0:0:0:0:0:1") return true;
    if (lower.startsWith("fc") || lower.startsWith("fd")) return true;
    if (lower.startsWith("fe80:")) return true;
    return false;
  }

  const octets = unwrapped.split(".");
  if (octets.length !== 4) return false;

  const numbers = octets.map((part) => Number(part));
  if (!numbers.every((part) => Number.isInteger(part) && part >= 0 && part <= 255)) {
    return false;
  }

  const [a, b] = numbers;
  if (a === 0) return true;
  if (a === 10) return true;
  if (a === 127) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  if (a >= 224) return true;

  return false;
}

function safeHostname(url: string): string {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return "unknown-source";
  }
}

function decodeBasicEntities(input: string): string {
  return input
    .replace(/&quot;/g, '"')
    .replace(/&#34;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}

const MEANINGFUL_NUMBER_UNITS = new Set<string>([
  "°c",
  "c",
  "gradi",
  "grado",
  "min",
  "minuto",
  "minuti",
  "minute",
  "minutes",
  "h",
  "hr",
  "hour",
  "hours",
  "ora",
  "ore",
  "sec",
  "secondo",
  "secondi",
  "second",
  "seconds",
  "g",
  "gr",
  "grammo",
  "grammi",
  "kg",
  "ml",
  "cl",
  "dl",
  "l",
  "cucchiaio",
  "cucchiai",
  "cucchiaino",
  "cucchiaini",
  "tbsp",
  "tsp",
  "cup",
  "cups",
  "piece",
  "pieces",
  "pezzo",
  "pezzi",
  "spicchio",
  "spicchi",
]);

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

function json(body: unknown, status = 200): Response {
  return jsonResponseWithStatus(body, status);
}

function errorJson(status: number, code: string, message: string): Response {
  return json({ ok: false, error: { code, message } }, status);
}

function logInfo(phase: string, details: Record<string, unknown>) {
  console.log(`[SEASON_URL_IMPORT] phase=${phase} ${stringifyDetails(details)}`.trim());
}

function logError(phase: string, error: unknown, stage: string) {
  const message = error instanceof Error ? error.message : String(error);
  const stack = error instanceof Error ? (error.stack ?? "") : "";
  console.log(
    `[SEASON_URL_IMPORT] phase=${phase} stage=${stage} error_message=${message} error_stack=${stack.replace(/\s+/g, " ").trim()}`,
  );
}

function stringifyDetails(details: Record<string, unknown>): string {
  return Object.entries(details)
    .map(([key, value]) => `${key}=${value === null ? "null" : String(value)}`)
    .join(" ");
}
