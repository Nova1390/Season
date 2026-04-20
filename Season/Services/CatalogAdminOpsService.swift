import Foundation

struct CatalogAdminBulkMutationSummary: Sendable {
    let successCount: Int
    let failureCount: Int
}

struct CatalogObservationRecoverySummary: Sendable {
    let totalProcessed: Int
    let observedCount: Int
    let skippedCount: Int
    let failedCount: Int
}

struct CatalogEnrichmentBatchRunSummary: Sendable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let skipped: Int
    let ready: Int
    let pending: Int
}

struct CatalogAutomationCycleRunSummary: Sendable {
    let recovery: CatalogAutomationCycleRecoverySummary
    let candidateIntake: CatalogAutomationCycleCandidateIntakeSummary
    let enrichment: CatalogAutomationCycleEnrichmentSummary
    let creation: CatalogAutomationCycleCreationSummary
    let aliasAutoApply: CatalogAutomationCycleAutoApplySummary
    let localizationAutoApply: CatalogAutomationCycleAutoApplySummary
    let reconciliationApplyModernSafe: CatalogAutomationCycleReconciliationSummary
    let runStatus: String
    let stageStatus: [String: String]
    let policy: CatalogAutomationCyclePolicy
}

struct CatalogAutoLocalizationRunSummary: Sendable {
    let total: Int
    let succeeded: Int
    let skipped: Int
    let failed: Int
    let anomalyItems: [CatalogAutoLocalizationItemResult]
}

struct CatalogAutoAliasRunSummary: Sendable {
    let total: Int
    let succeeded: Int
    let skipped: Int
    let failed: Int
    let anomalyItems: [CatalogAutoAliasItemResult]
}

struct CatalogSafeRecipeReconciliationApplySummary: Sendable {
    let total: Int
    let applied: Int
    let skipped: Int
    let failed: Int
    let rows: [RecipeIngredientReconciliationApplyRow]
}

final class CatalogAdminOpsService {
    static let shared = CatalogAdminOpsService()

    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }

    func approveAlias(
        normalizedText: String,
        ingredientID: String
    ) async throws {
        try await supabaseService.approveCatalogAlias(
            normalizedText: normalizedText,
            ingredientID: ingredientID
        )
    }

    func approveAliasesBulk(
        normalizedTexts: [String],
        ingredientID: String
    ) async -> CatalogAdminBulkMutationSummary {
        let batchItems = normalizedTexts.map {
            CatalogCandidateBatchTriageItem(
                normalizedText: $0,
                action: "approve_alias",
                ingredientID: ingredientID,
                aliasText: nil,
                languageCode: nil,
                confidenceScore: nil,
                reviewerNote: nil
            )
        }

        do {
            let result = try await executeBatchCandidateTriage(items: batchItems)
            return CatalogAdminBulkMutationSummary(
                successCount: result.summary.succeeded + result.summary.skipped,
                failureCount: result.summary.failed
            )
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=bulk_approve_alias_batch_failed fallback=sequential error=\(error)")
        }

        var successCount = 0
        var failureCount = 0

        for normalizedText in normalizedTexts {
            do {
                try await approveAlias(normalizedText: normalizedText, ingredientID: ingredientID)
                successCount += 1
            } catch {
                failureCount += 1
                print("[SEASON_CATALOG_ADMIN] phase=bulk_approve_alias_failed normalized_text=\(normalizedText) error=\(error)")
            }
        }

        return CatalogAdminBulkMutationSummary(successCount: successCount, failureCount: failureCount)
    }

    func executeBatchCandidateTriage(
        items: [CatalogCandidateBatchTriageItem],
        defaultLanguageCode: String? = nil,
        reviewerNote: String? = nil
    ) async throws -> CatalogCandidateBatchTriageResult {
        try await supabaseService.executeCatalogCandidateBatchTriage(
            items: items,
            defaultLanguageCode: defaultLanguageCode,
            reviewerNote: reviewerNote
        )
    }

    func addLocalization(
        ingredientID: String,
        text: String,
        languageCode: String
    ) async throws -> String {
        try await supabaseService.addIngredientLocalization(
            ingredientID: ingredientID,
            text: text,
            languageCode: languageCode
        )
    }

    func addLocalizationsBulk(
        requests: [(normalizedText: String, ingredientID: String, text: String, languageCode: String)]
    ) async -> CatalogAdminBulkMutationSummary {
        var successCount = 0
        var failureCount = 0

        for request in requests {
            do {
                let status = try await addLocalization(
                    ingredientID: request.ingredientID,
                    text: request.text,
                    languageCode: request.languageCode
                )
                if status == "inserted" || status == "already_exists" || status == "language_already_present" {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            } catch {
                failureCount += 1
                print("[SEASON_CATALOG_ADMIN] phase=bulk_add_localization_failed normalized_text=\(request.normalizedText) error=\(error)")
            }
        }

        return CatalogAdminBulkMutationSummary(successCount: successCount, failureCount: failureCount)
    }

    func fetchEnrichmentDraft(
        normalizedText: String
    ) async -> CatalogEnrichmentDraftRecord? {
        await supabaseService.fetchCatalogEnrichmentDraft(normalizedText: normalizedText)
    }

    func upsertEnrichmentDraft(
        normalizedText: String,
        status: String,
        ingredientType: String,
        canonicalNameIT: String?,
        canonicalNameEN: String?,
        suggestedSlug: String?,
        defaultUnit: String?,
        supportedUnits: [String],
        isSeasonal: Bool?,
        seasonMonths: [Int],
        confidenceScore: Double?,
        needsManualReview: Bool,
        reasoningSummary: String?
    ) async throws -> CatalogEnrichmentDraftMutationResult {
        try await supabaseService.upsertCatalogEnrichmentDraft(
            normalizedText: normalizedText,
            status: status,
            ingredientType: ingredientType,
            canonicalNameIT: canonicalNameIT,
            canonicalNameEN: canonicalNameEN,
            suggestedSlug: suggestedSlug,
            defaultUnit: defaultUnit,
            supportedUnits: supportedUnits,
            isSeasonal: isSeasonal,
            seasonMonths: seasonMonths,
            confidenceScore: confidenceScore,
            needsManualReview: needsManualReview,
            reasoningSummary: reasoningSummary
        )
    }

    func validateEnrichmentDraft(
        normalizedText: String
    ) async throws -> CatalogEnrichmentDraftMutationResult {
        try await supabaseService.validateCatalogEnrichmentDraft(normalizedText: normalizedText)
    }

    func createIngredientFromEnrichmentDraft(
        normalizedText: String
    ) async throws {
        try await supabaseService.createCatalogIngredientFromEnrichmentDraft(normalizedText: normalizedText)
    }

    func runUnresolvedObservationRecovery(
        limit: Int = 1000,
        source: String = "import_recovery"
    ) async throws -> CatalogObservationRecoverySummary {
        let rows = try await supabaseService.recoverUnresolvedRecipeIngredientObservations(
            limit: limit,
            recipeIDs: nil,
            source: source
        )

        let observed = rows.filter { $0.resultStatus == "observed" }.count
        let skipped = rows.filter { $0.resultStatus == "skipped" }.count
        let failed = rows.filter { $0.resultStatus == "failed" }.count
        return CatalogObservationRecoverySummary(
            totalProcessed: rows.count,
            observedCount: observed,
            skippedCount: skipped,
            failedCount: failed
        )
    }

    func runCatalogEnrichmentDraftBatch(
        limit: Int = 20,
        debug: Bool = false
    ) async throws -> CatalogEnrichmentBatchRunSummary {
        let result = try await supabaseService.runCatalogEnrichmentDraftBatch(limit: limit, debug: debug)
        return CatalogEnrichmentBatchRunSummary(
            total: result.summary.total,
            succeeded: result.summary.succeeded,
            failed: result.summary.failed,
            skipped: result.summary.skipped,
            ready: result.summary.ready,
            pending: result.summary.pending
        )
    }

    func runCatalogAutomationCycle(
        recoveryLimit: Int = 1000,
        enrichLimit: Int = 20,
        createLimit: Int = 20,
        debug: Bool = false
    ) async throws -> CatalogAutomationCycleRunSummary {
        let result = try await supabaseService.runCatalogAutomationCycle(
            recoveryLimit: recoveryLimit,
            enrichLimit: enrichLimit,
            createLimit: createLimit,
            debug: debug
        )
        return CatalogAutomationCycleRunSummary(
            recovery: result.recovery,
            candidateIntake: result.candidateIntake,
            enrichment: result.enrichment,
            creation: result.creation,
            aliasAutoApply: result.aliasAutoApply,
            localizationAutoApply: result.localizationAutoApply,
            reconciliationApplyModernSafe: result.reconciliationApplyModernSafe,
            runStatus: result.runStatus,
            stageStatus: result.stageStatus,
            policy: result.policy
        )
    }

    func previewSafeRecipeReconciliation(
        limit: Int = 20
    ) async throws -> [RecipeIngredientReconciliationPreviewRow] {
        try await supabaseService.previewSafeRecipeIngredientReconciliation(
            limit: limit,
            onlySafe: true
        )
    }

    func fetchIngredientHierarchy(
        limit: Int = 200
    ) async -> [CatalogIngredientHierarchyRecord] {
        await supabaseService.fetchCatalogIngredientHierarchy(limit: limit)
    }

    func autoApplySafeLocalizations(
        limit: Int = 50,
        languageCode: String = "it"
    ) async throws -> CatalogAutoLocalizationRunSummary {
        let rows = try await supabaseService.autoApplySafeLocalizations(
            limit: limit,
            languageCode: languageCode
        )
        let succeeded = rows.filter { $0.resultStatus == "succeeded" }.count
        let anomalyItems = rows.filter { $0.resultStatus != "succeeded" }
        let failed = rows.filter { $0.resultStatus == "failed" }.count
        let skipped = max(0, rows.count - succeeded - failed)
        return CatalogAutoLocalizationRunSummary(
            total: rows.count,
            succeeded: succeeded,
            skipped: skipped,
            failed: failed,
            anomalyItems: anomalyItems
        )
    }

    func autoApplySafeAliases(
        limit: Int = 50,
        languageCode: String = "it"
    ) async throws -> CatalogAutoAliasRunSummary {
        let rows = try await supabaseService.autoApplySafeAliases(
            limit: limit,
            languageCode: languageCode
        )
        let succeeded = rows.filter { $0.resultStatus == "succeeded" }.count
        let anomalyItems = rows.filter { $0.resultStatus != "succeeded" }
        let failed = rows.filter { $0.resultStatus == "failed" }.count
        let skipped = max(0, rows.count - succeeded - failed)
        return CatalogAutoAliasRunSummary(
            total: rows.count,
            succeeded: succeeded,
            skipped: skipped,
            failed: failed,
            anomalyItems: anomalyItems
        )
    }

    func applySafeRecipeReconciliation(
        limit: Int = 20,
        recipeIDs: [String]? = nil
    ) async throws -> CatalogSafeRecipeReconciliationApplySummary {
        let rows = try await supabaseService.applySafeRecipeIngredientReconciliation(
            limit: limit,
            recipeIDs: recipeIDs
        )
        let appliedCount = rows.filter { $0.applied && $0.applyStatus == "applied" }.count
        let failedCount = rows.filter { !$0.applied && !isSkipStatus($0.applyStatus) }.count
        let skippedCount = max(0, rows.count - appliedCount - failedCount)
        return CatalogSafeRecipeReconciliationApplySummary(
            total: rows.count,
            applied: appliedCount,
            skipped: skippedCount,
            failed: failedCount,
            rows: rows
        )
    }

    func applyModernSafeRecipeReconciliation(
        limit: Int = 20,
        recipeIDs: [String]? = nil
    ) async throws -> CatalogSafeRecipeReconciliationApplySummary {
        let rows = try await supabaseService.applyModernSafeRecipeIngredientReconciliation(
            limit: limit,
            recipeIDs: recipeIDs
        )
        let appliedCount = rows.filter { $0.applied && $0.applyStatus == "applied" }.count
        let failedCount = rows.filter { !$0.applied && !isSkipStatus($0.applyStatus) }.count
        let skippedCount = max(0, rows.count - appliedCount - failedCount)
        return CatalogSafeRecipeReconciliationApplySummary(
            total: rows.count,
            applied: appliedCount,
            skipped: skippedCount,
            failed: failedCount,
            rows: rows
        )
    }

    private func isSkipStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "already_resolved" ||
            normalized == "recipe_not_found_or_no_ingredients" ||
            normalized == "ingredient_index_not_found" ||
            normalized == "no_mapping"
    }
}
