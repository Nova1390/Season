import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const AUTO_PROMOTION_MIN_CONFIDENCE = 0.9;
const RISKY_SEMANTIC_CATEGORIES = new Set<string>([]);
const PLACEHOLDER_REASONING_SUMMARY = "automation_cycle_candidate_intake";
const PLACEHOLDER_BACKLOG_HIGH_THRESHOLD = 30;
const PLACEHOLDER_BOOST_MULTIPLIER = 3;
const PLACEHOLDER_BOOST_CAP = 80;
const TRACKED_DEBUG_TERMS = new Set([
  "penne rigate",
  "sedanini rigati",
  "trofie",
  "fusilli",
  "pappardelle all'uovo",
]);
const DERIVED_ENTITY_ALLOWLIST = new Set(["tuorli", "albumi"]);
const SAFE_CLEAN_CORE_QUALIFIERS = new Set([
  "usage_phrase",
  "temperature_or_state_phrase",
  "approx_quantity",
  "fraction_quantity",
  "weight_or_volume_quantity",
  "count_quantity",
  "trailing_number",
  "parentheses_content",
]);
const SAFE_PRODUCE_CLEAN_QUALIFIERS = new Set([
  "approx_quantity",
  "fraction_quantity",
  "weight_or_volume_quantity",
  "count_quantity",
  "trailing_number",
]);
const INTRINSIC_VARIANT_ALLOWLIST = new Set([
  "latte intero",
  "zucchero di canna",
]);
const DETERMINISTIC_COMPACTION_CANONICAL_ALLOWLIST = new Set([
  "zafferano",
  "cioccolato_fondente",
]);

interface SafeCategoryPolicy {
  rootSlug: string;
  allowedVariantKinds: Set<string>;
  lexicalGuard: RegExp;
}

const SAFE_CATEGORY_ALLOWLIST: Record<string, SafeCategoryPolicy> = {
  pasta: {
    rootSlug: "pasta",
    allowedVariantKinds: new Set(["shape", "style", "variety"]),
    lexicalGuard: /\b(fusilli|penne|pappardelle|rigatoni|spaghett|conchiglioni|orecchiette|trofie|paccheri|tagliatelle)\b/i,
  },
  rice: {
    rootSlug: "riso",
    allowedVariantKinds: new Set(["variety", "type"]),
    lexicalGuard: /\b(riso|carnaroli|arborio|vialone)\b/i,
  },
  flour: {
    rootSlug: "farina",
    allowedVariantKinds: new Set(["variety", "type"]),
    lexicalGuard: /\bfarina\b(?!.*\b(semola|semolino|amido)\b)/i,
  },
};

type RunnerMode = "user" | "service_role";

interface BatchRequest {
  limit?: number;
  debug?: unknown;
}

interface PendingDraftRow {
  normalized_text: string;
  status: string;
  occurrence_count: number | null;
  updated_at: string | null;
  suggested_slug: string | null;
  ingredient_type: string | null;
  confidence_score: number | null;
  reasoning_summary: string | null;
  intake_placeholder: boolean;
}

interface PendingSelectionResult {
  drafts: PendingDraftRow[];
  placeholderBacklogCount: number;
  placeholderSelectedCount: number;
  placeholderQuota: number;
  effectiveLimit: number;
  placeholderOnlyMode: boolean;
}

interface ProposalResponse {
  ingredient_type: "produce" | "basic" | "unknown";
  canonical_name_it: string | null;
  canonical_name_en: string | null;
  suggested_slug: string;
  semantic_category: string | null;
  parent_candidate_slug: string | null;
  parent_candidate_reason: string | null;
  variant_kind: string | null;
  specificity_rank_suggestion: number | null;
  default_unit: string;
  supported_units: string[];
  is_seasonal: boolean | null;
  season_months: number[] | null;
  needs_manual_review: boolean;
  reasoning_summary: string;
  confidence_score: number;
}

interface SemanticHints {
  semantic_category: string | null;
  parent_candidate_slug: string | null;
  parent_candidate_reason: string | null;
  variant_kind: string | null;
  specificity_rank_suggestion: number | null;
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

interface AutoPromotionEligibility {
  eligible: boolean;
  reasons: string[];
}

interface NormalizedIdentityInput {
  cleanedText: string;
  removedQualifiers: string[];
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
    const debugEnabled = decodeBoolean(payload.debug);
    console.log(
      `[SEASON_CATALOG_ENRICH_BATCH] phase=batch_started mode=${auth.mode} limit=${limit} debug=${debugEnabled}`,
    );

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const debugRunId = debugEnabled
      ? await createDebugRun(serviceClient, "run-catalog-enrichment-draft-batch", auth.mode, {
        requested_limit: limit,
      })
      : null;
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "start", {
      mode: auth.mode,
      requested_limit: limit,
    });

    const pendingSelection = await fetchPendingDrafts(serviceClient, limit, debugRunId);
    const pendingDrafts = pendingSelection.drafts;
    const selectedByText = new Map(
      pendingDrafts.map((draft) => [draft.normalized_text, draft] as const),
    );
    const results: ItemResult[] = [];
    let placeholderSucceeded = 0;
    let placeholderFailed = 0;
    let placeholderSkippedDuringProcessing = 0;

    for (const draft of pendingDrafts) {
      const normalizedText = normalizeText(draft.normalized_text);
      const identityInput = normalizeIngredientIdentityInput(normalizedText);
      const cleanedNormalizedText = normalizeText(identityInput.cleanedText) ?? normalizedText;
      console.log(
        `[SEASON_CATALOG_ENRICH_BATCH] phase=processing_started normalized_text=${draft.normalized_text} cleaned_text=${cleanedNormalizedText} intake_placeholder=${draft.intake_placeholder}`,
      );
      if (isTrackedDebugTerm(draft.normalized_text)) {
        await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "processing_started", {
          intake_placeholder: draft.intake_placeholder,
          status: draft.status,
          ingredient_type: draft.ingredient_type,
          confidence_score: draft.confidence_score,
          reasoning_summary: draft.reasoning_summary,
          original_text: normalizedText,
          cleaned_text: cleanedNormalizedText,
          removed_qualifiers: identityInput.removedQualifiers,
        }, draft.normalized_text);
      }
      if (!normalizedText) {
        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=llm_skipped normalized_text=${draft.normalized_text} reason=invalid_normalized_text`,
        );
        if (isTrackedDebugTerm(draft.normalized_text)) {
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "llm_skipped", {
            reason: "invalid_normalized_text",
          }, draft.normalized_text);
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "processing_skipped", {
            reason: "invalid_normalized_text",
            original_text: draft.normalized_text,
            cleaned_text: cleanedNormalizedText,
            removed_qualifiers: identityInput.removedQualifiers,
          }, draft.normalized_text);
        }
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
          console.log(
            `[SEASON_CATALOG_ENRICH_BATCH] phase=llm_skipped normalized_text=${normalizedText} reason=status_not_pending current_status=${latestStatus}`,
          );
          if (draft.intake_placeholder) {
            placeholderSkippedDuringProcessing += 1;
          }
          if (isTrackedDebugTerm(normalizedText)) {
            await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "llm_skipped", {
              reason: "status_not_pending",
              current_status: latestStatus,
            }, normalizedText);
            await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "processing_skipped", {
              reason: "status_not_pending",
              current_status: latestStatus,
              original_text: normalizedText,
              cleaned_text: cleanedNormalizedText,
              removed_qualifiers: identityInput.removedQualifiers,
            }, normalizedText);
          }
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

        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=llm_called normalized_text=${normalizedText} cleaned_text=${cleanedNormalizedText} removed_qualifiers=${identityInput.removedQualifiers.join("|")}`,
        );
        if (isTrackedDebugTerm(normalizedText)) {
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "llm_called", {
            original_text: normalizedText,
            cleaned_text: cleanedNormalizedText,
            removed_qualifiers: identityInput.removedQualifiers,
          }, normalizedText);
        }
        const proposal = await fetchProposalWithFallback({
          originalText: normalizedText,
          cleanedText: cleanedNormalizedText,
          removedQualifiers: identityInput.removedQualifiers,
        });
        const normalizedSuggestedSlug = normalizeText(proposal.suggested_slug);
        if (normalizedSuggestedSlug && await ingredientSlugExists(serviceClient, normalizedSuggestedSlug)) {
          await markDraftAppliedAlreadyExists(serviceClient, normalizedText);
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "auto_resolved_existing_slug", {
            auto_resolve_reason: "already_exists",
            suggested_slug: normalizedSuggestedSlug,
          }, normalizedText);
          results.push({
            normalized_text: normalizedText,
            result_status: "succeeded",
            detail: "auto_resolved_existing_slug",
            error_message: null,
            validation_errors: [],
            validation_passed: true,
            final_status: "applied",
          });
          if (draft.intake_placeholder) {
            placeholderSucceeded += 1;
          }
          continue;
        }

        const evaluationIdentityText = cleanedNormalizedText.length === 0
          ? normalizedText
          : cleanedNormalizedText;
        const autoPromotion = await evaluateAutoPromotionEligibility(
          serviceClient,
          evaluationIdentityText,
          proposal,
        );

        const upsertPending = await upsertDraft(
          serviceClient,
          normalizedText,
          proposal,
          "pending",
          true,
          "auto_enrichment_batch_v2_pending",
        );
        const validation = await validateDraft(serviceClient, normalizedText);
        const validationErrors = validation.validation_errors ?? [];
        const validationPassed = validationErrors.length === 0;

        let finalStatus = upsertPending.status ?? "pending";
        let detail = "proposal_applied_pending_manual_review";
        const onlyCanonicalConflict =
          autoPromotion.reasons.length === 1 &&
          autoPromotion.reasons[0] === "canonical_conflict";
        const safeExistingCanonical =
          validationPassed &&
          onlyCanonicalConflict &&
          isSafeExistingCanonicalAutoReady(proposal, normalizedText);
        const autoReadyDerivedEntity =
          isSafeDerivedCulinaryEntityAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            cleanedText: cleanedNormalizedText,
          });
        const autoReadyCleanCanonicalCore =
          isSafeCleanCanonicalCoreAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            originalText: normalizedText,
            cleanedText: cleanedNormalizedText,
            removedQualifiers: identityInput.removedQualifiers,
          });
        const autoReadyProduceCleanIdentity =
          isSafeProduceCleanIdentityAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            originalText: normalizedText,
            cleanedText: cleanedNormalizedText,
            removedQualifiers: identityInput.removedQualifiers,
          });
        const autoReadyIntrinsicVariant =
          isSafeIntrinsicVariantAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            originalText: normalizedText,
            cleanedText: cleanedNormalizedText,
            removedQualifiers: identityInput.removedQualifiers,
          });
        const autoReadyTransformedPreserved =
          isSafeTransformedPreservedAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            cleanedText: cleanedNormalizedText,
          });
        const autoReadyDeterministicCompaction =
          isSafeDeterministicallyCompactedCanonicalAutoReady({
            validationPassed,
            proposal,
            reasons: autoPromotion.reasons,
            originalText: normalizedText,
            cleanedText: cleanedNormalizedText,
          });
        const blockedByAgingMaturityDescriptor =
          hasAgingOrMaturityDescriptor(normalizedText) ||
          hasAgingOrMaturityDescriptor(cleanedNormalizedText);

        if (autoReadyDerivedEntity) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_derived_entity",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_derived_entity";
        } else if (autoReadyCleanCanonicalCore) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_clean_canonical_core",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_clean_canonical_core";
        } else if (autoReadyProduceCleanIdentity) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_produce_clean_identity",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_produce_clean_identity";
        } else if (autoReadyIntrinsicVariant) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_intrinsic_variant",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_intrinsic_variant";
        } else if (autoReadyTransformedPreserved) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_transformed_preserved",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_transformed_preserved";
        } else if (autoReadyDeterministicCompaction) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_ready_deterministic_compaction",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "auto_ready_deterministic_compaction";
        } else if (validationPassed && autoPromotion.eligible && !blockedByAgingMaturityDescriptor) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_enrichment_batch_v2_auto_promoted",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "proposal_auto_promoted_ready";
        } else if (validationPassed && autoPromotion.eligible && blockedByAgingMaturityDescriptor) {
          detail = "validation_passed_manual_review_required:aging_maturity_descriptor_requires_scoped_rule";
        } else if (safeExistingCanonical) {
          const upsertReady = await upsertDraft(
            serviceClient,
            normalizedText,
            proposal,
            "ready",
            false,
            "auto_enrichment_batch_v2_existing_canonical_ready",
          );
          finalStatus = upsertReady.status ?? "ready";
          detail = "proposal_auto_promoted_ready_existing_canonical";
        } else if (!validationPassed) {
          detail = "validation_failed_kept_pending";
        } else {
          detail = `validation_passed_manual_review_required:${autoPromotion.reasons.join("|")}`;
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
        if (isTrackedDebugTerm(normalizedText)) {
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "processing_completed", {
            result_status: "succeeded",
            detail,
            final_status: finalStatus,
            validation_errors: validationErrors,
            validation_passed: validationPassed,
            auto_ready_reason: autoReadyDerivedEntity
              ? "derived_entity"
              : autoReadyCleanCanonicalCore
              ? "clean_canonical_core"
              : autoReadyProduceCleanIdentity
              ? "produce_clean_identity"
              : autoReadyIntrinsicVariant
              ? "intrinsic_variant"
              : autoReadyTransformedPreserved
              ? "transformed_preserved"
              : autoReadyDeterministicCompaction
              ? "deterministic_compaction"
              : null,
            original_text: normalizedText,
            cleaned_text: cleanedNormalizedText,
            removed_qualifiers: identityInput.removedQualifiers,
          }, normalizedText);
        }
        if (draft.intake_placeholder) {
          placeholderSucceeded += 1;
        }
      } catch (error) {
        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=llm_skipped normalized_text=${normalizedText} reason=processing_exception`,
        );
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
        if (isTrackedDebugTerm(normalizedText ?? draft.normalized_text)) {
          await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "processing_completed", {
            result_status: "failed",
            detail: "enrichment_failed",
            error_message: String(error),
            final_status: "pending",
          }, normalizedText ?? draft.normalized_text);
        }
        if (draft.intake_placeholder) {
          placeholderFailed += 1;
        }
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
    const placeholderSelected = pendingSelection.placeholderSelectedCount;
    const placeholderBacklog = pendingSelection.placeholderBacklogCount;
    const placeholderSelectionSkipped = Math.max(0, placeholderBacklog - placeholderSelected);
    const placeholderProcessed = results.filter((item) => selectedByText.get(item.normalized_text)?.intake_placeholder).length;
    console.log(
      `[SEASON_CATALOG_ENRICH_BATCH] phase=placeholder_processing_summary ` +
      `backlog=${placeholderBacklog} ` +
      `quota=${pendingSelection.placeholderQuota} ` +
      `effective_limit=${pendingSelection.effectiveLimit} ` +
      `placeholder_only_mode=${pendingSelection.placeholderOnlyMode} ` +
      `selected=${placeholderSelected} ` +
      `skipped_selection=${placeholderSelectionSkipped} ` +
      `processed=${placeholderProcessed} ` +
      `succeeded=${placeholderSucceeded} ` +
      `failed=${placeholderFailed} ` +
      `skipped_processing=${placeholderSkippedDuringProcessing} ` +
      `remaining_estimate=${Math.max(0, placeholderBacklog - placeholderProcessed)}`,
    );
    await writeDebugEvent(serviceClient, debugRunId, "run-catalog-enrichment-draft-batch", "final_summary", {
      summary,
      placeholder_backlog: placeholderBacklog,
      placeholder_selected: placeholderSelected,
      placeholder_processed: placeholderProcessed,
      placeholder_succeeded: placeholderSucceeded,
      placeholder_failed: placeholderFailed,
      placeholder_skipped_processing: placeholderSkippedDuringProcessing,
      placeholder_quota: pendingSelection.placeholderQuota,
      effective_limit: pendingSelection.effectiveLimit,
      placeholder_only_mode: pendingSelection.placeholderOnlyMode,
    });

    return json({
      summary,
      items: results,
      metadata: {
        mode: auth.mode,
        debug_enabled: debugEnabled,
        debug_run_id: debugRunId,
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

async function fetchPendingDrafts(
  client: ReturnType<typeof createClient>,
  limit: number,
  debugRunId: string | null,
): Promise<PendingSelectionResult> {
  const trackedTerms = [
    "fusilli",
    "penne rigate",
    "trofie",
    "sedanini rigati",
    "pappardelle all'uovo",
    "burro a temperatura ambiente",
  ];

  const { count: totalPendingCount, error: totalPendingCountError } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text", { count: "exact", head: true })
    .eq("status", "pending");

  if (totalPendingCountError) {
    throw new Error(`pending_count_failed:${totalPendingCountError.message}`);
  }

  const { data: placeholderDataRaw, error: placeholderError } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text,status,updated_at,suggested_slug,ingredient_type,confidence_score,reasoning_summary,custom_ingredient_observations(occurrence_count)")
    .eq("status", "pending")
    .eq("ingredient_type", "unknown")
    .is("confidence_score", null)
    .order("updated_at", { ascending: true })
    .limit(Math.max(limit * 50, 1000));

  if (placeholderError) {
    throw new Error(`pending_placeholder_fetch_failed:${placeholderError.message}`);
  }

  const { data, error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text,status,updated_at,suggested_slug,ingredient_type,confidence_score,reasoning_summary,custom_ingredient_observations(occurrence_count)")
    .eq("status", "pending")
    .order("updated_at", { ascending: false })
    .limit(Math.max(limit * 6, limit));

  if (error) {
    throw new Error(`pending_fetch_failed:${error.message}`);
  }

  const { count: placeholderPendingCountLike, error: placeholderPendingCountLikeError } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text", { count: "exact", head: true })
    .eq("status", "pending")
    .eq("ingredient_type", "unknown")
    .is("confidence_score", null)
    .ilike("reasoning_summary", `%${PLACEHOLDER_REASONING_SUMMARY}%`);
  if (placeholderPendingCountLikeError) {
    throw new Error(`pending_placeholder_like_count_failed:${placeholderPendingCountLikeError.message}`);
  }

  const placeholderCandidateRows = (placeholderDataRaw ?? [])
    .map((row) => toPendingDraftRow(row as Record<string, unknown>));
  const placeholderRows = placeholderCandidateRows.filter((row) => row.intake_placeholder);
  const placeholderPendingCount = Math.max(placeholderRows.length, placeholderPendingCountLike ?? 0);
  const regularRows = (data ?? []).map((row) => toPendingDraftRow(row as Record<string, unknown>));
  const hardFallbackRows = placeholderCandidateRows
    .filter((row) => !row.intake_placeholder && isHardFallbackPlaceholderDraft(row));

  const placeholderBacklogHigh = placeholderPendingCount >= PLACEHOLDER_BACKLOG_HIGH_THRESHOLD;
  const effectiveLimit = placeholderBacklogHigh
    ? Math.min(MAX_LIMIT, Math.max(limit, Math.min(PLACEHOLDER_BOOST_CAP, limit * PLACEHOLDER_BOOST_MULTIPLIER)))
    : limit;
  const placeholderOnlyMode = placeholderBacklogHigh;
  const nonPlaceholderLane = placeholderOnlyMode
    ? Math.min(
      effectiveLimit,
      Math.max(2, Math.min(5, Math.floor(effectiveLimit * 0.15))),
    )
    : 0;
  const nonPlaceholderAvailable = regularRows.filter((row) => !row.intake_placeholder).length;
  const reservedNonPlaceholderSlots = placeholderOnlyMode
    ? Math.min(nonPlaceholderLane, nonPlaceholderAvailable)
    : 0;
  const placeholderQuota = placeholderOnlyMode
    ? Math.max(0, effectiveLimit - reservedNonPlaceholderSlots)
    : Math.min(effectiveLimit, Math.max(1, Math.floor(effectiveLimit * 0.7)));
  console.log(
    `[SEASON_CATALOG_ENRICH_BATCH] phase=placeholder_drain_policy backlog=${placeholderPendingCount} requested_limit=${limit} effective_limit=${effectiveLimit} placeholder_quota=${placeholderQuota} placeholder_only_mode=${placeholderOnlyMode} non_placeholder_lane=${reservedNonPlaceholderSlots}`,
  );
  if (debugRunId) {
    await writeDebugEvent(client, debugRunId, "run-catalog-enrichment-draft-batch", "pending_selection_policy", {
      placeholder_backlog: placeholderPendingCount,
      requested_limit: limit,
      effective_limit: effectiveLimit,
      placeholder_quota: placeholderQuota,
      placeholder_only_mode: placeholderOnlyMode,
      non_placeholder_lane: reservedNonPlaceholderSlots,
    });
  }

  const selectedByKey = new Map<string, PendingDraftRow>();
  for (const row of placeholderRows) {
    if (!row.normalized_text) continue;
    if (selectedByKey.size >= placeholderQuota) break;
    selectedByKey.set(row.normalized_text, row);
  }
  for (const row of hardFallbackRows) {
    if (!row.normalized_text) continue;
    if (selectedByKey.size >= placeholderQuota) break;
    selectedByKey.set(row.normalized_text, row);
  }
  const regularRowsForSelection = placeholderOnlyMode
    ? [
      ...regularRows.filter((row) => !row.intake_placeholder && !!row.suggested_slug),
      ...regularRows.filter((row) => !row.intake_placeholder && !row.suggested_slug),
    ]
    : regularRows;
  for (const row of regularRowsForSelection) {
    if (!row.normalized_text) continue;
    if (selectedByKey.has(row.normalized_text)) continue;
    if (selectedByKey.size >= effectiveLimit) break;
    selectedByKey.set(row.normalized_text, row);
  }

  const selected = Array.from(selectedByKey.values()).slice(0, effectiveLimit);
  const placeholderSelectedCount = selected.filter((row) => row.intake_placeholder).length;
  const normalSelectedCount = selected.length - placeholderSelectedCount;
  console.log(
    `[SEASON_CATALOG_ENRICH_BATCH] phase=pending_selection_stats total_pending=${totalPendingCount ?? 0} placeholder_pending=${placeholderPendingCount ?? 0} hard_fallback_candidates=${hardFallbackRows.length} placeholder_selected=${placeholderSelectedCount} normal_selected=${normalSelectedCount} selected=${selected.length} requested_limit=${limit} effective_limit=${effectiveLimit}`,
  );
  console.log(
    `[SEASON_CATALOG_ENRICH_BATCH] phase=pending_selection_selected first_n=${Math.min(selected.length, limit)} normalized_texts=${selected.slice(0, limit).map((row) => row.normalized_text).join("|")}`,
  );
  if (debugRunId) {
    await writeDebugEvent(client, debugRunId, "run-catalog-enrichment-draft-batch", "pending_selection_stats", {
      total_pending: totalPendingCount ?? 0,
      placeholder_pending: placeholderPendingCount ?? 0,
      hard_fallback_candidates: hardFallbackRows.length,
      placeholder_selected: placeholderSelectedCount,
      normal_selected: normalSelectedCount,
      selected: selected.length,
      requested_limit: limit,
      effective_limit: effectiveLimit,
      selected_normalized_texts: selected.slice(0, limit).map((row) => row.normalized_text),
    });
  }

  if (debugRunId) {
    const { data: trackedPendingRows, error: trackedPendingError } = await client
      .from("catalog_ingredient_enrichment_drafts")
      .select("normalized_text,ingredient_type,confidence_score,reasoning_summary,status")
      .eq("status", "pending")
      .in("normalized_text", trackedTerms);
    if (trackedPendingError) {
      throw new Error(`tracked_pending_fetch_failed:${trackedPendingError.message}`);
    }

    const trackedPendingMap = new Map<string, Record<string, unknown>>();
    const regularQuerySet = new Set(regularRows.map((row) => row.normalized_text));
    const placeholderQuerySet = new Set(
      (placeholderDataRaw ?? [])
        .map((row) => String((row as Record<string, unknown>).normalized_text ?? "").trim().toLowerCase())
        .filter((value) => value.length > 0),
    );
    const hardFallbackSet = new Set(hardFallbackRows.map((row) => row.normalized_text));
    for (const row of trackedPendingRows ?? []) {
      const record = row as Record<string, unknown>;
      const key = String(record.normalized_text ?? "").trim().toLowerCase();
      if (key) trackedPendingMap.set(key, record);
    }
    const trackedSelected = new Set(selected.map((row) => row.normalized_text));
    for (const term of trackedTerms) {
      const row = trackedPendingMap.get(term);
      if (!row) {
        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=tracked_selection term=${term} exists_pending=false exists_pending_query=false exists_placeholder_query=false placeholder_detected=false hard_fallback_match=false included_selected=false reason=not_pending`,
        );
        continue;
      }
      const trackedDraft = toPendingDraftRow(row);
      const detectedPlaceholder = trackedDraft.intake_placeholder;
      const hardFallbackMatch = isHardFallbackPlaceholderDraft(trackedDraft);
      const existsPendingQuery = regularQuerySet.has(term);
      const existsPlaceholderQuery = placeholderQuerySet.has(term);
      const selectedNow = trackedSelected.has(term);
      let reason = "selected";
      if (!selectedNow) {
        if (!existsPendingQuery && !existsPlaceholderQuery) {
          reason = "not_fetched_in_pending_window";
        } else if (!detectedPlaceholder && !hardFallbackMatch) {
          reason = "not_classified_as_placeholder";
        } else if (placeholderPendingCount > effectiveLimit) {
          reason = "placeholder_backlog_above_limit";
        } else {
          reason = "not_selected_after_dedupe";
        }
      }
      console.log(
        `[SEASON_CATALOG_ENRICH_BATCH] phase=tracked_selection term=${term} exists_pending=true exists_pending_query=${existsPendingQuery} exists_placeholder_query=${existsPlaceholderQuery} placeholder_detected=${detectedPlaceholder} hard_fallback_match=${hardFallbackMatch} included_selected=${selectedNow} reason=${reason}`,
      );
      await writeDebugEvent(client, debugRunId, "run-catalog-enrichment-draft-batch", "tracked_selection", {
        exists_pending: true,
        exists_pending_query: existsPendingQuery,
        exists_placeholder_query: existsPlaceholderQuery,
        placeholder_detected: detectedPlaceholder,
        hard_fallback_match: hardFallbackMatch,
        included_selected: selectedNow,
        reason,
      }, term);
      if (hardFallbackSet.has(term) && !selectedNow) {
        console.log(
          `[SEASON_CATALOG_ENRICH_BATCH] phase=tracked_selection term=${term} included_by_hard_fallback=false reason=selection_cap_reached`,
        );
        await writeDebugEvent(client, debugRunId, "run-catalog-enrichment-draft-batch", "tracked_selection", {
          included_by_hard_fallback: false,
          reason: "selection_cap_reached",
        }, term);
      }
    }
  }

  return {
    drafts: selected,
    placeholderBacklogCount: placeholderPendingCount,
    placeholderSelectedCount,
    placeholderQuota,
    effectiveLimit,
    placeholderOnlyMode,
  };
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

async function markDraftAppliedAlreadyExists(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
): Promise<void> {
  const { error } = await client
    .from("catalog_ingredient_enrichment_drafts")
    .update({
      status: "applied",
      needs_manual_review: false,
      reviewer_note: "auto_resolve_already_exists",
      updated_at: new Date().toISOString(),
    })
    .eq("normalized_text", normalizedText)
    .eq("status", "pending");

  if (error) {
    throw new Error(`draft_auto_resolve_existing_failed:${error.message}`);
  }
}

async function fetchProposalWithFallback(input: {
  originalText: string;
  cleanedText: string;
  removedQualifiers: string[];
}): Promise<ProposalResponse> {
  const originalText = input.originalText;
  const cleanedText = normalizeText(input.cleanedText) ?? originalText;
  const response = await fetch(`${SUPABASE_URL}/functions/v1/catalog-enrichment-proposal`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      normalized_text: cleanedText,
      original_text: originalText,
      cleaned_text: cleanedText,
      removed_qualifiers: input.removedQualifiers,
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`proposal_fetch_failed:${response.status}:${details}`);
  }

  const parsed = await response.json() as ProposalResponse;
  const semanticHints = inferSemanticHints(cleanedText);
  const semanticCategory = normalizeText(parsed.semantic_category) ?? semanticHints.semantic_category;
  const parentCandidateSlug = normalizeText(parsed.parent_candidate_slug) ?? semanticHints.parent_candidate_slug;
  const parentCandidateReason = normalizeText(parsed.parent_candidate_reason) ?? semanticHints.parent_candidate_reason;
  const variantKind = normalizeText(parsed.variant_kind) ?? semanticHints.variant_kind;
  const specificityRankSuggestion = Number.isInteger(parsed.specificity_rank_suggestion)
    ? Number(parsed.specificity_rank_suggestion)
    : semanticHints.specificity_rank_suggestion;

  return {
    ingredient_type: parsed.ingredient_type ?? "unknown",
    canonical_name_it: parsed.canonical_name_it ?? null,
    canonical_name_en: parsed.canonical_name_en ?? null,
    suggested_slug: normalizeText(parsed.suggested_slug) ?? cleanedText.replace(/\s+/g, "_"),
    semantic_category: semanticCategory,
    parent_candidate_slug: parentCandidateSlug,
    parent_candidate_reason: parentCandidateReason,
    variant_kind: parentCandidateSlug ? (variantKind ?? "variety") : null,
    specificity_rank_suggestion: parentCandidateSlug ? Math.max(1, Number(specificityRankSuggestion ?? 1)) : null,
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

function normalizeIngredientIdentityInput(normalizedText: string): NormalizedIdentityInput {
  let cleaned = normalizeText(normalizedText) ?? "";
  const removedQualifiers = new Set<string>();

  const apply = (pattern: RegExp, qualifier: string) => {
    if (pattern.test(cleaned)) {
      removedQualifiers.add(qualifier);
      cleaned = cleaned.replace(pattern, " ");
    }
  };

  apply(/\([^)]*\)/g, "parentheses_content");
  apply(/\b(circa|ca\.?)\s*\d+(?:[.,]\d+)?\b/gi, "approx_quantity");
  apply(/\b\d+\s*\/\s*\d+\s*bicchier[ei]\b/gi, "count_quantity");
  apply(/\bmezzo\s+bicchier[ei]\b/gi, "count_quantity");
  apply(/\b\d+\s*\/\s*\d+\b/g, "fraction_quantity");
  apply(/\b\d+(?:[.,]\d+)?\s*(?:g|gr|grammi?|kg|ml|cl|l|litri?)\b/gi, "weight_or_volume_quantity");
  apply(/\b\d+(?:[.,]\d+)?\s*(?:pizzic[oi]|mazzett[oi]|ciuff[oi]|cost[ae]|fogli[ae]|spicch[iio]|cucchiai?|cucchiain[iio]|pezzi?)\b/gi, "count_quantity");
  apply(/\b(a temperatura ambiente|freddo di frigo|freddo dal frigo|freddo di frigorifero|freddo da frigo)\b/gi, "temperature_or_state_phrase");
  apply(/\b(da pulire|da grattugiare|da tritare|da tagliare|da usare|da servire)\b/gi, "usage_phrase");
  apply(/\b(per decorare|per servire|per spolverizzare|per ungere)\b/gi, "usage_phrase");
  apply(/\bsgocciolat\w*\b/gi, "post_preparation_qualifier");
  apply(/\b\d+\b$/g, "trailing_number");

  cleaned = cleaned
    .replace(/[.,;:]+$/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();

  return {
    cleanedText: cleaned || normalizedText,
    removedQualifiers: Array.from(removedQualifiers),
  };
}

function inferSemanticHints(normalizedText: string): SemanticHints {
  const text = normalizeText(normalizedText) ?? "";
  if (!text) {
    return {
      semantic_category: null,
      parent_candidate_slug: null,
      parent_candidate_reason: null,
      variant_kind: null,
      specificity_rank_suggestion: null,
    };
  }

  if (/\b(fusilli|penne(\s+rigate)?|pappardelle(([\s_]+all['_\s]?uovo))?|rigatoni|spaghett(i|oni)|conchiglioni|orecchiette|trofie|paccheri|tagliatelle)\b/i.test(text)) {
    return {
      semantic_category: "pasta",
      parent_candidate_slug: "pasta",
      parent_candidate_reason: "shape_or_style_under_pasta_family",
      variant_kind: "shape",
      specificity_rank_suggestion: 1,
    };
  }

  if (/\bcipolla\s+(rossa|dorata|bianca)\b/i.test(text)) {
    return {
      semantic_category: "vegetable",
      parent_candidate_slug: "cipolla",
      parent_candidate_reason: "color_variant_under_cipolla_family",
      variant_kind: "variety",
      specificity_rank_suggestion: 1,
    };
  }

  if (/\b(riso|carnaroli|arborio|vialone)\b/i.test(text)) {
    return {
      semantic_category: "rice",
      parent_candidate_slug: "riso",
      parent_candidate_reason: "variety_under_riso_family",
      variant_kind: "variety",
      specificity_rank_suggestion: 1,
    };
  }

  if (/\b(farina|semola|manitoba|integrale|00)\b/i.test(text)) {
    return {
      semantic_category: "flour",
      parent_candidate_slug: "farina",
      parent_candidate_reason: "type_under_farina_family",
      variant_kind: "variety",
      specificity_rank_suggestion: 1,
    };
  }

  return {
    semantic_category: null,
    parent_candidate_slug: null,
    parent_candidate_reason: null,
    variant_kind: null,
    specificity_rank_suggestion: null,
  };
}

function isSafeExistingCanonicalAutoReady(
  proposal: ProposalResponse,
  normalizedText: string,
): boolean {
  const confidence = clamp01(proposal.confidence_score);
  const semanticCategory = normalizeText(proposal.semantic_category);
  const variantKind = normalizeText(proposal.variant_kind);
  if (!semanticCategory || !variantKind) return false;
  const policy = SAFE_CATEGORY_ALLOWLIST[semanticCategory];
  if (!policy) return false;
  return confidence >= AUTO_PROMOTION_MIN_CONFIDENCE &&
    policy.allowedVariantKinds.has(variantKind) &&
    policy.lexicalGuard.test(normalizedText);
}

async function upsertDraft(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  proposal: ProposalResponse,
  status: "pending" | "ready",
  needsManualReview: boolean,
  reviewerNote: string,
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
    p_needs_manual_review: needsManualReview,
    p_reasoning_summary: proposal.reasoning_summary,
    p_reviewer_note: reviewerNote,
  };

  const { data, error } = await client.rpc("upsert_catalog_ingredient_enrichment_draft", params);
  if (error) {
    throw new Error(`upsert_failed:${error.message}`);
  }
  const row = (Array.isArray(data) ? data[0] : data) as DraftMutationRow | null;
  if (!row) {
    throw new Error("upsert_failed:empty_response");
  }

  await persistDraftHierarchy(client, normalizedText, proposal);
  return row;
}

async function persistDraftHierarchy(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  proposal: ProposalResponse,
): Promise<void> {
  const parentCandidateSlug = normalizeText(proposal.parent_candidate_slug);
  const variantKind = normalizeText(proposal.variant_kind);
  const specificityRankSuggestion = Number.isInteger(proposal.specificity_rank_suggestion)
    ? Number(proposal.specificity_rank_suggestion)
    : null;

  const hasValidHierarchyTuple = !!(
    parentCandidateSlug &&
    variantKind &&
    Number.isInteger(specificityRankSuggestion) &&
    Number(specificityRankSuggestion) >= 1
  );

  const { error } = await client.rpc("set_catalog_ingredient_enrichment_draft_hierarchy", {
    p_normalized_text: normalizedText,
    p_parent_candidate_slug: hasValidHierarchyTuple ? parentCandidateSlug : null,
    p_variant_kind: hasValidHierarchyTuple ? variantKind : null,
    p_specificity_rank_suggestion: hasValidHierarchyTuple ? specificityRankSuggestion : null,
  });

  if (error) {
    // Keep enrichment flow stable even if hierarchy persistence fails.
    console.log(
      `[SEASON_CATALOG_ENRICH_BATCH] phase=draft_hierarchy_persist_failed normalized_text=${normalizedText} error=${error.message}`,
    );
  }
}

async function evaluateAutoPromotionEligibility(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  proposal: ProposalResponse,
): Promise<AutoPromotionEligibility> {
  const reasons: string[] = [];
  const confidence = clamp01(proposal.confidence_score);

  if (confidence < AUTO_PROMOTION_MIN_CONFIDENCE) {
    reasons.push("low_confidence");
  }

  const semanticCategory = normalizeText(proposal.semantic_category);
  if (!semanticCategory || semanticCategory === "unknown") {
    reasons.push("semantic_category_unknown");
  }

  if (semanticCategory && RISKY_SEMANTIC_CATEGORIES.has(semanticCategory)) {
    reasons.push("risky_semantic_category");
  }

  const parentCandidateSlug = normalizeText(proposal.parent_candidate_slug);
  const effectiveParent = await resolveEffectiveParentCandidateSlug(
    client,
    normalizedText,
    proposal,
    parentCandidateSlug,
    confidence,
  );
  if (!effectiveParent.parentSlug) {
    reasons.push("missing_parent_candidate");
  } else if (!effectiveParent.parentExists) {
    reasons.push("parent_not_found");
  }

  const canonicalConflict = await hasCanonicalConflict(client, normalizedText, proposal.suggested_slug);
  if (canonicalConflict) {
    reasons.push("canonical_conflict");
  }

  const aliasConflict = await hasApprovedAliasConflict(client, normalizedText, proposal.suggested_slug);
  if (aliasConflict) {
    reasons.push("alias_conflict");
  }

  return {
    eligible: reasons.length === 0,
    reasons,
  };
}

async function resolveEffectiveParentCandidateSlug(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  proposal: ProposalResponse,
  parentCandidateSlug: string | null,
  confidence: number,
): Promise<{ parentSlug: string | null; parentExists: boolean }> {
  if (parentCandidateSlug) {
    const parentExists = await ingredientSlugExists(client, parentCandidateSlug);
    if (parentExists) {
      return { parentSlug: parentCandidateSlug, parentExists: true };
    }
  }

  const safeFallbackRoot = getSafeFallbackRootSlug(proposal, confidence, normalizedText);
  if (safeFallbackRoot) {
    const rootExists = await ingredientSlugExists(client, safeFallbackRoot);
    if (rootExists) {
      return { parentSlug: safeFallbackRoot, parentExists: true };
    }
  }

  return { parentSlug: parentCandidateSlug, parentExists: false };
}

function getSafeFallbackRootSlug(
  proposal: ProposalResponse,
  confidence: number,
  normalizedText: string,
): string | null {
  const semanticCategory = normalizeText(proposal.semantic_category);
  const variantKind = normalizeText(proposal.variant_kind);
  if (!semanticCategory || !variantKind) return null;
  const policy = SAFE_CATEGORY_ALLOWLIST[semanticCategory];
  if (!policy) return null;
  const hasRequiredConfidence = confidence >= AUTO_PROMOTION_MIN_CONFIDENCE;
  const hasAllowedVariantKind = policy.allowedVariantKinds.has(variantKind);
  const hasLexicalEvidence = policy.lexicalGuard.test(normalizedText);
  if (hasRequiredConfidence && hasAllowedVariantKind && hasLexicalEvidence) {
    return policy.rootSlug;
  }
  return null;
}

async function ingredientSlugExists(
  client: ReturnType<typeof createClient>,
  slug: string,
): Promise<boolean> {
  const { data, error } = await client
    .from("ingredients")
    .select("id")
    .eq("slug", slug)
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`ingredient_slug_exists_check_failed:${error.message}`);
  }

  return !!((data as Record<string, unknown> | null)?.id);
}

async function hasCanonicalConflict(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  suggestedSlug: string,
): Promise<boolean> {
  const normalizedSlug = normalizeText(suggestedSlug) ?? "";
  const textAsSlug = normalizedText.replace(/\s+/g, "_");
  if (normalizedSlug) {
    const { data: bySlug, error: bySlugError } = await client
      .from("ingredients")
      .select("id")
      .eq("slug", normalizedSlug)
      .limit(1)
      .maybeSingle();

    if (bySlugError) {
      throw new Error(`canonical_conflict_slug_check_failed:${bySlugError.message}`);
    }
    if ((bySlug as Record<string, unknown> | null)?.id) {
      return true;
    }
  }

  const { data: byTextSlug, error: byTextSlugError } = await client
    .from("ingredients")
    .select("id")
    .eq("slug", textAsSlug)
    .limit(1)
    .maybeSingle();

  if (byTextSlugError) {
    throw new Error(`canonical_conflict_text_slug_check_failed:${byTextSlugError.message}`);
  }

  return !!((byTextSlug as Record<string, unknown> | null)?.id);
}

async function hasApprovedAliasConflict(
  client: ReturnType<typeof createClient>,
  normalizedText: string,
  suggestedSlug: string,
): Promise<boolean> {
  const { data, error } = await client
    .from("ingredient_aliases_v2")
    .select("ingredient_id,status,is_active,ingredients!inner(slug)")
    .eq("normalized_alias_text", normalizedText)
    .eq("status", "approved")
    .eq("is_active", true)
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`alias_conflict_check_failed:${error.message}`);
  }

  const row = data as
    | { ingredients?: { slug?: string } | Array<{ slug?: string }> }
    | null;
  if (!row) return false;

  const aliasTargetSlug = Array.isArray(row.ingredients)
    ? normalizeText(row.ingredients[0]?.slug)
    : normalizeText(row.ingredients?.slug);
  const normalizedSuggestedSlug = normalizeText(suggestedSlug);

  if (!aliasTargetSlug) return true;
  if (!normalizedSuggestedSlug) return true;
  return aliasTargetSlug !== normalizedSuggestedSlug;
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

function isIntakePlaceholderRow(row: Record<string, unknown>): boolean {
  const ingredientType = normalizeText(row.ingredient_type);
  const confidence = parseOptionalConfidence(row.confidence_score);
  const hasConfidence = confidence !== null;
  const reasoning = normalizeReasoningMarker(row.reasoning_summary);
  return ingredientType === "unknown" && !hasConfidence && reasoning.startsWith(PLACEHOLDER_REASONING_SUMMARY);
}

function isHardFallbackPlaceholderDraft(row: PendingDraftRow): boolean {
  const ingredientType = normalizeText(row.ingredient_type);
  const confidence = parseOptionalConfidence(row.confidence_score);
  const hasConfidence = confidence !== null;
  return ingredientType === "unknown" && !hasConfidence;
}

function normalizeReasoningMarker(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function toPendingDraftRow(row: Record<string, unknown>): PendingDraftRow {
  let occurrence = 0;
  if (Array.isArray(row.custom_ingredient_observations)) {
    occurrence = Number((row.custom_ingredient_observations[0] as Record<string, unknown> | undefined)?.occurrence_count ?? 0);
  } else if (row.custom_ingredient_observations && typeof row.custom_ingredient_observations === "object") {
    occurrence = Number((row.custom_ingredient_observations as Record<string, unknown>).occurrence_count ?? 0);
  }
  return {
    normalized_text: String(row.normalized_text ?? "").trim().toLowerCase(),
    status: String(row.status ?? "pending"),
    updated_at: row.updated_at ? String(row.updated_at) : null,
    suggested_slug: normalizeText(row.suggested_slug),
    occurrence_count: Number.isFinite(occurrence) ? occurrence : 0,
    ingredient_type: normalizeText(row.ingredient_type),
    confidence_score: parseOptionalConfidence(row.confidence_score),
    reasoning_summary: typeof row.reasoning_summary === "string" ? row.reasoning_summary : null,
    intake_placeholder: isIntakePlaceholderRow(row),
  };
}

function parseOptionalConfidence(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string" && value.trim().length === 0) return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return parsed;
}

function isSafeCleanCanonicalCoreAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  originalText: string;
  cleanedText: string;
  removedQualifiers: string[];
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "basic") return false;
  if (clamp01(input.proposal.confidence_score) < 0.97) return false;

  const original = normalizeText(input.originalText) ?? "";
  const cleaned = normalizeText(input.cleanedText) ?? "";
  if (!original || !cleaned || original === cleaned) return false;
  if (hasMixedOrUnclearIdentitySignal(cleaned)) return false;
  if (!Array.isArray(input.removedQualifiers) || input.removedQualifiers.length === 0) return false;
  if (!input.removedQualifiers.every((qualifier) => SAFE_CLEAN_CORE_QUALIFIERS.has(qualifier))) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;
  if (reasons.has("semantic_category_unknown")) return false;
  if (reasons.has("risky_semantic_category")) return false;
  if (reasons.has("low_confidence")) return false;

  return true;
}

function hasMixedOrUnclearIdentitySignal(cleanedText: string): boolean {
  const text = normalizeText(cleanedText) ?? "";
  if (!text) return true;
  // Conservative guard: mixed/composite patterns should stay manual.
  return /[,/;+]|(\be\b)|(\bo\b)/i.test(text);
}

function isSafeDerivedCulinaryEntityAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  cleanedText: string;
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "basic") return false;
  if (clamp01(input.proposal.confidence_score) < 0.95) return false;

  const cleaned = normalizeText(input.cleanedText) ?? "";
  if (!cleaned || !DERIVED_ENTITY_ALLOWLIST.has(cleaned)) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;

  return true;
}

function isSafeProduceCleanIdentityAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  originalText: string;
  cleanedText: string;
  removedQualifiers: string[];
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "produce") return false;
  if (clamp01(input.proposal.confidence_score) < 0.97) return false;

  const original = normalizeText(input.originalText) ?? "";
  const cleaned = normalizeText(input.cleanedText) ?? "";
  if (!original || !cleaned || original === cleaned) return false;
  if (!Array.isArray(input.removedQualifiers) || input.removedQualifiers.length === 0) return false;
  if (!input.removedQualifiers.every((qualifier) => SAFE_PRODUCE_CLEAN_QUALIFIERS.has(qualifier))) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;
  if (reasons.has("risky_semantic_category")) return false;

  return true;
}

function isSafeIntrinsicVariantAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  originalText: string;
  cleanedText: string;
  removedQualifiers: string[];
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "basic") return false;
  if (clamp01(input.proposal.confidence_score) < 0.95) return false;

  const original = normalizeText(input.originalText) ?? "";
  const cleaned = normalizeText(input.cleanedText) ?? "";
  if (!original || !cleaned) return false;
  if (hasMixedOrUnclearIdentitySignal(cleaned)) return false;
  if (Array.isArray(input.removedQualifiers) && input.removedQualifiers.length > 0) return false;
  if (!hasIntrinsicVariantIdentitySignal(cleaned)) return false;
  if (/\b\d+\b|\b(mesi?|anni?)\b|\bstagionatur\w*\b/i.test(cleaned)) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;
  if (reasons.has("risky_semantic_category")) return false;

  return true;
}

function isSafeTransformedPreservedAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  cleanedText: string;
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "basic") return false;
  if (clamp01(input.proposal.confidence_score) < 0.92) return false;

  const cleaned = normalizeText(input.cleanedText) ?? "";
  if (!cleaned) return false;
  if (hasMixedOrUnclearIdentitySignal(cleaned)) return false;
  if (!hasTransformedPreservedSignal(cleaned)) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;
  if (reasons.has("risky_semantic_category")) return false;

  return true;
}

function isSafeDeterministicallyCompactedCanonicalAutoReady(input: {
  validationPassed: boolean;
  proposal: ProposalResponse;
  reasons: string[];
  originalText: string;
  cleanedText: string;
}): boolean {
  if (!input.validationPassed) return false;
  if (input.proposal.ingredient_type !== "basic") return false;
  if (clamp01(input.proposal.confidence_score) < 0.93) return false;

  const canonicalSlug = normalizeSlugToken(input.proposal.suggested_slug);
  if (!canonicalSlug || !DETERMINISTIC_COMPACTION_CANONICAL_ALLOWLIST.has(canonicalSlug)) return false;

  const originalSlug = normalizeSlugToken(input.originalText);
  if (!originalSlug) return false;
  // Require clear compaction from an over-specific variant into the canonical slug.
  if (canonicalSlug === originalSlug) return false;
  if (!originalSlug.startsWith(`${canonicalSlug}_`)) return false;

  if (hasMixedOrUnclearIdentitySignal(input.cleanedText)) return false;

  const reasons = new Set(input.reasons.map((reason) => normalizeText(reason) ?? reason));
  if (reasons.has("alias_conflict")) return false;
  if (reasons.has("risky_semantic_category")) return false;

  return true;
}

function hasIntrinsicVariantIdentitySignal(cleanedText: string): boolean {
  const cleaned = normalizeText(cleanedText) ?? "";
  if (!cleaned) return false;
  return INTRINSIC_VARIANT_ALLOWLIST.has(cleaned);
}

function hasTransformedPreservedSignal(text: string): boolean {
  const normalized = normalizeText(text) ?? "";
  if (!normalized) return false;
  return /\bsott['’]?olio\b|\baffumicat\w*\b|\bsotto\s+sale\b/i.test(normalized);
}

function hasAgingOrMaturityDescriptor(text: string): boolean {
  const normalized = normalizeText(text) ?? "";
  if (!normalized) return false;
  return /\b\d+\b|\b(mesi?|anni?)\b|\bstagionatur\w*\b/i.test(normalized);
}

function normalizeSlugToken(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isTrackedDebugTerm(value: string): boolean {
  const normalized = normalizeText(value);
  if (!normalized) return false;
  return TRACKED_DEBUG_TERMS.has(normalized);
}

async function createDebugRun(
  client: ReturnType<typeof createClient>,
  functionName: string,
  mode: string,
  metadata: Record<string, unknown>,
): Promise<string | null> {
  try {
    const { data, error } = await client
      .from("catalog_function_debug_runs")
      .insert({
        function_name: functionName,
        mode,
        metadata,
      })
      .select("run_id")
      .single();

    if (error) {
      console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=debug_run_insert_failed error=${error.message}`);
      return null;
    }
    return String((data as Record<string, unknown> | null)?.run_id ?? "");
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=debug_run_insert_failed error=${String(error)}`);
    return null;
  }
}

async function writeDebugEvent(
  client: ReturnType<typeof createClient>,
  runId: string | null,
  functionName: string,
  stage: string,
  payload: Record<string, unknown> | unknown,
  trackedTerm?: string,
): Promise<void> {
  if (!runId) return;
  try {
    const safePayload = isRecord(payload) ? payload : { value: payload };
    const { error } = await client
      .from("catalog_function_debug_events")
      .insert({
        run_id: runId,
        function_name: functionName,
        stage,
        tracked_term: trackedTerm ?? null,
        payload: safePayload,
      });
    if (error) {
      console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=debug_event_insert_failed stage=${stage} error=${error.message}`);
    }
  } catch (error) {
    console.log(`[SEASON_CATALOG_ENRICH_BATCH] phase=debug_event_insert_failed stage=${stage} error=${String(error)}`);
  }
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
