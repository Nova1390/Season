import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { TokenUsage } from "./observability.ts";

export interface AIUsageEventInput {
  supabaseUrl: string;
  serviceRoleKey: string;
  environment?: string;
  functionName: string;
  requestId?: string | null;
  agentRunId?: number | null;
  workerJobId?: number | null;
  model?: string | null;
  status: "success" | "fallback" | "error" | "skipped";
  providerDurationMs?: number | null;
  usage?: TokenUsage | null;
  estimatedCostUsd?: number | null;
  reason?: string | null;
  metadata?: Record<string, unknown>;
}

export async function recordAIUsageEvent(input: AIUsageEventInput): Promise<void> {
  if (!input.supabaseUrl || !input.serviceRoleKey) return;

  const client = createClient(input.supabaseUrl, input.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const usage = input.usage ?? null;
  const { error } = await client
    .from("catalog_ai_usage_events")
    .insert({
      environment: input.environment ?? "dev",
      function_name: input.functionName,
      request_id: input.requestId ?? null,
      agent_run_id: input.agentRunId ?? null,
      worker_job_id: input.workerJobId ?? null,
      model: input.model ?? null,
      status: input.status,
      provider_duration_ms: toInteger(input.providerDurationMs),
      input_tokens: toInteger(usage?.inputTokens),
      output_tokens: toInteger(usage?.outputTokens),
      total_tokens: toInteger(usage?.totalTokens),
      estimated_cost_usd: input.estimatedCostUsd ?? null,
      reason: input.reason ?? null,
      metadata: input.metadata ?? {},
    });

  if (error) {
    console.log(
      `[SEASON_AI_USAGE] phase=record_failed function_name=${input.functionName} request_id=${input.requestId ?? "null"} error=${error.message}`,
    );
  }
}

export function estimateUsageCost(
  usage: TokenUsage,
  inputCostPer1MUsd: number | null,
  outputCostPer1MUsd: number | null,
): number | null {
  if (inputCostPer1MUsd === null && outputCostPer1MUsd === null) {
    return null;
  }

  const inputCost = usage.inputTokens === null || inputCostPer1MUsd === null
    ? 0
    : (usage.inputTokens / 1_000_000) * inputCostPer1MUsd;
  const outputCost = usage.outputTokens === null || outputCostPer1MUsd === null
    ? 0
    : (usage.outputTokens / 1_000_000) * outputCostPer1MUsd;

  return Number((inputCost + outputCost).toFixed(6));
}

function toInteger(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.max(0, Math.floor(parsed));
}
