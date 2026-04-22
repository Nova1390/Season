import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractBearerToken } from "./edge.ts";

export type AuthMode = "user" | "service_role";

export interface CatalogAdminAuthResult {
  allowed: boolean;
  mode: AuthMode;
  bearerToken: string | null;
  userId: string | null;
}

export interface CatalogAdminAuthConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  logPrefix: string;
}

export async function resolveCatalogAdminOrServiceRole(
  request: Request,
  config: CatalogAdminAuthConfig,
): Promise<CatalogAdminAuthResult> {
  const apikey = request.headers.get("apikey") ?? "";
  const authHeader = request.headers.get("Authorization") ?? "";
  const bearer = extractBearerToken(authHeader) ?? "";

  const isServiceRole =
    !!config.supabaseServiceRoleKey &&
    ((apikey && apikey === config.supabaseServiceRoleKey) ||
      (bearer && bearer === config.supabaseServiceRoleKey));

  if (isServiceRole) {
    log(config.logPrefix, "auth_ok", { mode: "service_role" });
    return { allowed: true, mode: "service_role", bearerToken: null, userId: null };
  }

  if (!bearer) {
    log(config.logPrefix, "auth_missing_user_token", {});
    return { allowed: false, mode: "user", bearerToken: null, userId: null };
  }

  const userClient = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(bearer);
  if (userError || !userData.user?.id) {
    log(config.logPrefix, "auth_invalid_user_token", {});
    return { allowed: false, mode: "user", bearerToken: null, userId: null };
  }

  const { data: adminData, error: adminError } = await userClient.rpc("is_current_user_catalog_admin");
  const isAdmin = adminError ? false : decodeRPCBoolean(adminData);
  log(config.logPrefix, "auth_user_checked", {
    user_id: userData.user.id,
    is_admin: isAdmin,
  });

  return {
    allowed: isAdmin,
    mode: "user",
    bearerToken: bearer,
    userId: userData.user.id,
  };
}

function decodeRPCBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "t" || normalized === "1";
  }
  if (Array.isArray(value) && value.length > 0) {
    return decodeRPCBoolean(value[0]);
  }
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if ("is_current_user_catalog_admin" in record) {
      return decodeRPCBoolean(record.is_current_user_catalog_admin);
    }
  }
  return false;
}

function log(prefix: string, phase: string, details: Record<string, unknown>) {
  const suffix = Object.entries(details)
    .map(([key, value]) => `${key}=${value === null ? "null" : String(value)}`)
    .join(" ");
  console.log(`[${prefix}] phase=${phase} ${suffix}`.trim());
}
