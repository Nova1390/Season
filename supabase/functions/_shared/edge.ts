export const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

export function env(name: string, fallback = ""): string {
  return Deno.env.get(name) ?? fallback;
}

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`missing_required_env:${name}`);
  }
  return value;
}

export function numberEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (raw === undefined || raw.trim().length === 0) return fallback;

  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function firstEnv(names: string[], fallback = ""): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value !== undefined && value.trim().length > 0) {
      return value;
    }
  }
  return fallback;
}

export function extractBearerToken(header: string | null | undefined): string | null {
  const match = (header ?? "").match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const token = match[1]?.trim();
  return token || null;
}

export function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...JSON_HEADERS,
      ...(init.headers ?? {}),
    },
  });
}

export function jsonResponseWithStatus(body: unknown, status = 200): Response {
  return jsonResponse(body, { status });
}

export async function fetchWithTimeout(
  input: string | URL | Request,
  init: RequestInit = {},
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const existingSignal = init.signal;

  const abortFromExistingSignal = () => controller.abort();
  if (existingSignal) {
    if (existingSignal.aborted) {
      controller.abort();
    } else {
      existingSignal.addEventListener("abort", abortFromExistingSignal, { once: true });
    }
  }

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
    existingSignal?.removeEventListener("abort", abortFromExistingSignal);
  }
}
