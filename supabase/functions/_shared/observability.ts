export interface TokenUsage {
  inputTokens: number | null;
  outputTokens: number | null;
  totalTokens: number | null;
}

export interface LLMUsageLog {
  functionName: string;
  requestId: string;
  status: "success" | "fallback" | "error";
  providerDurationMs?: number | null;
  model?: string | null;
  inputTokens?: number | null;
  outputTokens?: number | null;
  totalTokens?: number | null;
  reason?: string | null;
}

export function requestIdFromHeaders(request: Request): string {
  const existing =
    request.headers.get("x-request-id") ??
    request.headers.get("x-correlation-id") ??
    request.headers.get("cf-ray");
  const normalized = existing?.trim();
  return normalized && normalized.length > 0 ? normalized : crypto.randomUUID();
}

export function extractTokenUsage(payload: unknown): TokenUsage {
  if (!isRecord(payload)) return emptyUsage();
  const usage = isRecord(payload.usage) ? payload.usage : null;
  if (!usage) return emptyUsage();

  const inputTokens = readNumber(usage.input_tokens) ?? readNumber(usage.prompt_tokens);
  const outputTokens = readNumber(usage.output_tokens) ?? readNumber(usage.completion_tokens);
  const totalTokens = readNumber(usage.total_tokens) ??
    sumTokens(inputTokens, outputTokens);

  return {
    inputTokens,
    outputTokens,
    totalTokens,
  };
}

export function logLLMUsage(prefix: string, event: LLMUsageLog): void {
  const details: Record<string, unknown> = {
    function_name: event.functionName,
    request_id: event.requestId,
    status: event.status,
    provider_duration_ms: event.providerDurationMs ?? null,
    model: event.model ?? null,
    input_tokens: event.inputTokens ?? null,
    output_tokens: event.outputTokens ?? null,
    total_tokens: event.totalTokens ?? null,
    reason: event.reason ?? null,
  };
  console.log(`[${prefix}] phase=llm_usage ${stringifyDetails(details)}`);
}

function emptyUsage(): TokenUsage {
  return {
    inputTokens: null,
    outputTokens: null,
    totalTokens: null,
  };
}

function readNumber(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.max(0, Math.floor(parsed));
}

function sumTokens(inputTokens: number | null, outputTokens: number | null): number | null {
  if (inputTokens === null && outputTokens === null) return null;
  return (inputTokens ?? 0) + (outputTokens ?? 0);
}

function stringifyDetails(details: Record<string, unknown>): string {
  return Object.entries(details)
    .map(([key, value]) => `${key}=${value === null ? "null" : String(value)}`)
    .join(" ");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
