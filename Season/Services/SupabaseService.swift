import Foundation
import Supabase
import CryptoKit

extension Notification.Name {
    static let seasonAuthStateDidChange = Notification.Name("season.auth_state_did_change")
}

enum NetworkErrorCategory: String {
    case auth_session
    case permission_rls
    case network_offline
    case rate_limit
    case server_error
    case client_validation
    case unknown
}

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
}

enum SupabaseServiceError: LocalizedError {
    case missingConfiguration(String)
    case invalidURL
    case unauthenticated
    case requestTimedOut(String, TimeInterval)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "Missing Supabase configuration: \(key)."
        case .invalidURL:
            return "Supabase URL is invalid."
        case .unauthenticated:
            return "No authenticated Supabase user found."
        case .requestTimedOut(let requestName, let seconds):
            return "\(requestName) timed out after \(Int(seconds))s."
        }
    }
}

enum ParseRecipeCaptionInvokeError: Error {
    case tooFrequent(retryAfterSeconds: Int?)
    case dailyLimitReached
}

struct SupabaseProfileProbe: Decodable {
    let id: UUID
}

struct Profile: Codable {
    let id: UUID
    let created_at: String?
    let display_name: String?
    let season_username: String?
    let is_admin: Bool?
    let avatar_url: String?
    let preferred_language: String?
    let is_public: Bool?
    let instagram_url: String?
    let tiktok_url: String?
}

struct CloudLinkedSocialAccount: Codable {
    let id: String?
    let user_id: String?
    let provider: String
    let provider_user_id: String?
    let display_name: String?
    let handle: String?
    let profile_image_url: String?
    let is_verified: Bool?
    let linked_at: String?
    let created_at: String?
}

struct CloudUserRecipeState: Codable {
    let id: String?
    let user_id: String?
    let recipe_id: String?
    let is_saved: Bool?
    let is_crispied: Bool?
    let is_archived: Bool?
    let updated_at: String?
}

struct CloudShoppingListItem: Codable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool?
    let created_at: String?
    let updated_at: String?
}

struct CloudFridgeItem: Codable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let created_at: String?
    let updated_at: String?
}

struct IngredientAliasRecord: Sendable {
    let produceID: String?
    let basicIngredientID: String?
    let aliasText: String
    let normalizedAliasText: String
    let languageCode: String?
    let source: String
    let confidence: Double?
    let isActive: Bool
}

struct UnifiedIngredientCatalogSummaryRecord: Sendable {
    let ingredientID: String
    let slug: String
    let ingredientType: String
    let enName: String?
    let itName: String?
    let legacyProduceID: String?
    let legacyBasicID: String?
}

struct UnifiedIngredientAliasRecord: Sendable {
    let ingredientID: String
    let aliasText: String
    let normalizedAliasText: String
    let languageCode: String?
    let source: String
    let confidence: Double?
    let isActive: Bool
}

struct CatalogResolutionCandidateRecord: Sendable, Identifiable {
    let normalizedText: String
    let occurrenceCount: Int
    let suggestedResolutionType: String
    let existingAliasStatus: String
    let priorityScore: Double?
    let canonicalParentExists: Bool
    let closeCanonicalChildExists: Bool
    let possibleActions: [String]
    let confidence: String
    let suggestedParentSlug: String?
    let reasoningHint: String?

    var id: String { normalizedText }
}

struct CatalogCoverageBlockerRecord: Sendable, Identifiable {
    let normalizedText: String
    let rowCount: Int
    let recipeCount: Int
    let occurrenceCount: Int
    let priorityScore: Double?
    let likelyFixType: String
    let canonicalCandidateIngredientID: String?
    let canonicalCandidateSlug: String?
    let canonicalCandidateName: String?
    let canonicalCandidateParentSlug: String?
    let canonicalCandidateIsChild: Bool
    let canonicalCandidateIsRoot: Bool
    let genericParentExists: Bool
    let suggestedResolutionType: String
    let blockerReason: String
    let recommendedNextAction: String

    var id: String { normalizedText }
}

struct ReadyCatalogEnrichmentDraftRecord: Sendable, Identifiable {
    let normalizedText: String
    let ingredientType: String
    let canonicalNameIT: String?
    let canonicalNameEN: String?
    let suggestedSlug: String?
    let confidenceScore: Double?
    let needsManualReview: Bool
    let updatedAt: Date?

    var id: String { normalizedText }
}

struct CatalogObservationCoverageRecord: Sendable, Identifiable {
    let normalizedText: String
    let observationStatus: String
    let occurrenceCount: Int
    let lastSeenAt: Date?
    let coverageState: String
    let coverageReason: String
    let canonicalTargetIngredientID: String?
    let canonicalTargetSlug: String?
    let canonicalTargetName: String?
    let aliasTargetIngredientID: String?
    let aliasTargetSlug: String?
    let aliasTargetName: String?

    var id: String { normalizedText }
}

struct PendingCatalogEnrichmentDraftReviewRecord: Sendable, Identifiable {
    let normalizedText: String
    let occurrenceCount: Int
    let draftUpdatedAt: Date?
    let reviewBucket: String
    let classificationReason: String
    let hasApprovedAlias: Bool
    let hasAnyAliasMatch: Bool
    let canonicalMatchCount: Int
    let quantityContaminated: Bool
    let lowRiskQualifier: Bool
    let descriptorAliasLike: Bool
    let isPastaShape: Bool
    let recommendedOperatorAction: String

    var id: String { normalizedText }
}

struct CatalogIngredientHierarchyRecord: Sendable, Identifiable {
    let ingredientID: String
    let ingredientSlug: String
    let parentIngredientID: String?
    let parentSlug: String?
    let ingredientType: String
    let specificityRank: Int
    let variantKind: String

    var id: String { ingredientID }
}

struct CatalogAdminOpsSnapshotMetadata: Sendable {
    let generatedAt: Date?
    let candidatesCount: Int
    let coverageBlockersCount: Int
    let readyEnrichmentDraftsCount: Int
    let observationCoverageCount: Int
    let source: String
}

struct CatalogAdminOpsSnapshot: Sendable {
    let candidates: [CatalogResolutionCandidateRecord]
    let coverageBlockers: [CatalogCoverageBlockerRecord]
    let readyEnrichmentDrafts: [ReadyCatalogEnrichmentDraftRecord]
    let observationCoverage: [CatalogObservationCoverageRecord]
    let metadata: CatalogAdminOpsSnapshotMetadata
}

struct CatalogCandidateBatchTriageItem: Sendable {
    let normalizedText: String
    let action: String
    let ingredientID: String?
    let aliasText: String?
    let languageCode: String?
    let confidenceScore: Double?
    let reviewerNote: String?
}

struct CatalogCandidateBatchTriageItemResult: Sendable {
    let normalizedText: String
    let intendedAction: String
    let resultStatus: String
    let detail: String?
    let errorMessage: String?
    let ingredientID: String?
    let aliasText: String?
    let draftStatus: String?
    let draftValidatedReady: Bool?
}

struct CatalogCandidateBatchTriageSummary: Sendable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let skipped: Int
}

struct CatalogCandidateBatchTriageResult: Sendable {
    let summary: CatalogCandidateBatchTriageSummary
    let items: [CatalogCandidateBatchTriageItemResult]
    let source: String
}

struct CatalogEnrichmentDraftBatchItemResult: Sendable {
    let normalizedText: String
    let resultStatus: String
    let detail: String
    let errorMessage: String?
    let validationErrors: [String]
    let validationPassed: Bool
    let finalStatus: String
}

struct CatalogEnrichmentDraftBatchSummary: Sendable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let skipped: Int
    let ready: Int
    let pending: Int
}

struct CatalogEnrichmentDraftBatchResult: Sendable {
    let summary: CatalogEnrichmentDraftBatchSummary
    let items: [CatalogEnrichmentDraftBatchItemResult]
    let mode: String
}

struct CatalogIngredientCreationBatchItemResult: Sendable {
    let normalizedText: String
    let slug: String?
    let resultStatus: String
    let detail: String
    let ingredientID: String?
    let errorMessage: String?
}

struct CatalogIngredientCreationBatchSummary: Sendable {
    let total: Int
    let created: Int
    let skippedExisting: Int
    let skippedInvalid: Int
    let failed: Int
}

struct CatalogIngredientCreationBatchResult: Sendable {
    let summary: CatalogIngredientCreationBatchSummary
    let items: [CatalogIngredientCreationBatchItemResult]
    let mode: String
}

struct CatalogAutomationCycleRecoverySummary: Sendable {
    let total: Int
    let observed: Int
    let skipped: Int
    let failed: Int
    let status: String
    let error: String?
}

struct CatalogAutomationCycleEnrichmentSummary: Sendable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let skipped: Int
    let ready: Int
    let status: String
    let error: String?
}

struct CatalogAutomationCycleCreationSummary: Sendable {
    let total: Int
    let created: Int
    let skippedExisting: Int
    let skippedInvalid: Int
    let failed: Int
    let status: String
    let error: String?
}

struct CatalogAutomationCycleResult: Sendable {
    let recovery: CatalogAutomationCycleRecoverySummary
    let enrichment: CatalogAutomationCycleEnrichmentSummary
    let creation: CatalogAutomationCycleCreationSummary
    let mode: String
}

struct CatalogAutoLocalizationItemResult: Sendable, Identifiable {
    let normalizedText: String
    let canonicalCandidateIngredientID: String?
    let canonicalCandidateSlug: String?
    let languageCode: String
    let attemptedDisplayName: String?
    let resultStatus: String
    let detail: String
    let errorMessage: String?

    var id: String { "\(normalizedText)|\(canonicalCandidateIngredientID ?? "none")|\(languageCode)" }
}

struct CatalogAutoAliasItemResult: Sendable, Identifiable {
    let normalizedText: String
    let canonicalCandidateIngredientID: String?
    let canonicalCandidateSlug: String?
    let languageCode: String
    let attemptedAliasText: String?
    let matchMethod: String?
    let resultStatus: String
    let detail: String
    let errorMessage: String?

    var id: String { "\(normalizedText)|\(canonicalCandidateIngredientID ?? "none")|\(languageCode)" }
}

struct RecipeObservationRecoveryRow: Sendable {
    let recipeID: String
    let ingredientIndex: Int
    let normalizedText: String
    let rawExample: String?
    let resultStatus: String
    let detail: String?
}

struct RecipeIngredientReconciliationPreviewRow: Sendable, Identifiable {
    let recipeID: String
    let recipeTitle: String
    let recipeIngredientRowID: String
    let ingredientIndex: Int
    let ingredientRawName: String
    let currentMappingState: String
    let proposedIngredientID: String?
    let proposedIngredientSlug: String?
    let proposedIngredientName: String?
    let confidenceSource: String
    let safeToApply: Bool
    let safetyReason: String

    var id: String { recipeIngredientRowID }
}

struct RecipeIngredientReconciliationApplyRow: Sendable, Identifiable {
    let batchID: String?
    let recipeID: String
    let recipeIngredientRowID: String
    let ingredientIndex: Int
    let matchedIngredientID: String?
    let matchSource: String
    let applied: Bool
    let applyStatus: String

    var id: String { recipeIngredientRowID }
}

struct CatalogEnrichmentDraftRecord: Sendable, Identifiable {
    let normalizedText: String
    let status: String
    let ingredientType: String
    let canonicalNameIT: String?
    let canonicalNameEN: String?
    let suggestedSlug: String?
    let suggestedAliases: [String]
    let defaultUnit: String?
    let supportedUnits: [String]
    let isSeasonal: Bool?
    let seasonMonths: [Int]
    let confidenceScore: Double?
    let needsManualReview: Bool
    let reasoningSummary: String?
    let reviewerNote: String?
    let validatedReady: Bool
    let validationErrors: [String]
    let updatedAt: Date?

    var id: String { normalizedText }
}

struct CatalogEnrichmentDraftMutationResult: Sendable {
    let normalizedText: String
    let status: String
    let ingredientType: String
    let validatedReady: Bool
    let validationErrors: [String]
}

private struct CloudIngredientAliasRow: Codable {
    let produce_id: String?
    let basic_ingredient_id: String?
    let alias_text: String?
    let normalized_alias_text: String?
    let language_code: String?
    let source: String?
    let confidence: Double?
    let is_active: Bool?
}

private struct CloudCatalogResolutionCandidateRow: Codable {
    let normalized_text: String?
    let occurrence_count: Int?
    let suggested_resolution_type: String?
    let existing_alias_status: String?
    let priority_score: Double?
    let canonical_parent_exists: Bool?
    let close_canonical_child_exists: Bool?
    let possible_actions: [String]?
    let confidence: String?
    let suggested_parent_slug: String?
    let reasoning_hint: String?
}

private struct CloudCatalogCoverageBlockerRow: Codable {
    let normalized_text: String?
    let row_count: Int?
    let recipe_count: Int?
    let occurrence_count: Int?
    let priority_score: Double?
    let likely_fix_type: String?
    let canonical_candidate_ingredient_id: String?
    let canonical_candidate_slug: String?
    let canonical_candidate_name: String?
    let canonical_candidate_parent_slug: String?
    let canonical_candidate_is_child: Bool?
    let canonical_candidate_is_root: Bool?
    let generic_parent_exists: Bool?
    let suggested_resolution_type: String?
    let blocker_reason: String?
    let recommended_next_action: String?
}

private struct CloudAddIngredientLocalizationRow: Codable {
    let applied: Bool?
    let status: String?
    let ingredient_id: String?
    let language_code: String?
    let display_name: String?
}

private struct CloudReadyCatalogEnrichmentDraftRow: Codable {
    let normalized_text: String?
    let ingredient_type: String?
    let canonical_name_it: String?
    let canonical_name_en: String?
    let suggested_slug: String?
    let confidence_score: Double?
    let needs_manual_review: Bool?
    let updated_at: String?
}

private struct CloudCatalogObservationCoverageRow: Codable {
    let normalized_text: String?
    let observation_status: String?
    let occurrence_count: Int?
    let last_seen_at: String?
    let coverage_state: String?
    let coverage_reason: String?
    let canonical_target_ingredient_id: String?
    let canonical_target_slug: String?
    let canonical_target_name: String?
    let alias_target_ingredient_id: String?
    let alias_target_slug: String?
    let alias_target_name: String?
}

private struct CloudPendingCatalogEnrichmentDraftReviewRow: Codable {
    let normalized_text: String?
    let occurrence_count: Int?
    let draft_updated_at: String?
    let review_bucket: String?
    let classification_reason: String?
    let has_approved_alias: Bool?
    let has_any_alias_match: Bool?
    let canonical_match_count: Int?
    let quantity_contaminated: Bool?
    let low_risk_qualifier: Bool?
    let descriptor_alias_like: Bool?
    let is_pasta_shape: Bool?
    let recommended_operator_action: String?
}

private struct CloudCatalogIngredientHierarchyRow: Codable {
    let ingredient_id: String?
    let ingredient_slug: String?
    let parent_ingredient_id: String?
    let parent_slug: String?
    let ingredient_type: String?
    let specificity_rank: Int?
    let variant_kind: String?
}

private struct CloudCatalogAdminOpsSnapshotMetadataCounts: Codable {
    let candidates: Int?
    let coverage_blockers: Int?
    let ready_enrichment_drafts: Int?
    let observation_coverage: Int?
}

private struct CloudCatalogAdminOpsSnapshotMetadata: Codable {
    let generated_at: String?
    let counts: CloudCatalogAdminOpsSnapshotMetadataCounts?
    let source: String?
}

private struct CloudCatalogAdminOpsSnapshot: Codable {
    let candidates: [CloudCatalogResolutionCandidateRow]?
    let coverage_blockers: [CloudCatalogCoverageBlockerRow]?
    let ready_enrichment_drafts: [CloudReadyCatalogEnrichmentDraftRow]?
    let observation_coverage: [CloudCatalogObservationCoverageRow]?
    let metadata: CloudCatalogAdminOpsSnapshotMetadata?
}

private struct CloudCatalogCandidateBatchTriageSummary: Codable {
    let total: Int?
    let succeeded: Int?
    let failed: Int?
    let skipped: Int?
}

private struct CloudCatalogCandidateBatchTriageItemResult: Codable {
    let normalized_text: String?
    let action: String?
    let intended_action: String?
    let result_status: String?
    let error_message: String?
    let detail: String?
    let ingredient_id: String?
    let alias_text: String?
    let draft_status: String?
    let draft_validated_ready: Bool?
}

private struct CloudCatalogCandidateBatchTriageMetadata: Codable {
    let source: String?
}

private struct CloudCatalogCandidateBatchTriageResult: Codable {
    let summary: CloudCatalogCandidateBatchTriageSummary?
    let items: [CloudCatalogCandidateBatchTriageItemResult]?
    let metadata: CloudCatalogCandidateBatchTriageMetadata?
}

private struct CloudRecipeObservationRecoveryRow: Codable {
    let recipe_id: String?
    let ingredient_index: Int?
    let normalized_text: String?
    let raw_example: String?
    let result_status: String?
    let detail: String?
}

private struct CloudCatalogAutoLocalizationRow: Codable {
    let normalized_text: String?
    let canonical_candidate_ingredient_id: String?
    let canonical_candidate_slug: String?
    let language_code: String?
    let attempted_display_name: String?
    let result_status: String?
    let detail: String?
    let error_message: String?
}

private struct CloudCatalogAutoAliasRow: Codable {
    let normalized_text: String?
    let canonical_candidate_ingredient_id: String?
    let canonical_candidate_slug: String?
    let language_code: String?
    let attempted_alias_text: String?
    let match_method: String?
    let result_status: String?
    let detail: String?
    let error_message: String?
}

private struct CloudRecipeIngredientReconciliationPreviewRow: Codable {
    let recipe_id: String?
    let recipe_title: String?
    let recipe_ingredient_row_id: String?
    let ingredient_index: Int?
    let ingredient_raw_name: String?
    let current_mapping_state: String?
    let proposed_ingredient_id: String?
    let proposed_ingredient_slug: String?
    let proposed_ingredient_name: String?
    let confidence_source: String?
    let safe_to_apply: Bool?
    let safety_reason: String?
}

private struct CloudRecipeIngredientReconciliationApplyRow: Codable {
    let batch_id: String?
    let recipe_id: String?
    let recipe_ingredient_row_id: String?
    let ingredient_index: Int?
    let matched_ingredient_id: String?
    let match_source: String?
    let applied: Bool?
    let apply_status: String?
}

private struct CloudCatalogEnrichmentDraftBatchSummary: Codable {
    let total: Int?
    let succeeded: Int?
    let failed: Int?
    let skipped: Int?
    let ready: Int?
    let pending: Int?
}

private struct CloudCatalogEnrichmentDraftBatchItemRow: Codable {
    let normalized_text: String?
    let result_status: String?
    let detail: String?
    let error_message: String?
    let validation_errors: [String]?
    let validation_passed: Bool?
    let final_status: String?
}

private struct CloudCatalogEnrichmentDraftBatchMetadata: Codable {
    let mode: String?
}

private struct CloudCatalogEnrichmentDraftBatchResponse: Codable {
    let summary: CloudCatalogEnrichmentDraftBatchSummary?
    let items: [CloudCatalogEnrichmentDraftBatchItemRow]?
    let metadata: CloudCatalogEnrichmentDraftBatchMetadata?
}

private struct CloudCatalogIngredientCreationBatchSummary: Codable {
    let total: Int?
    let created: Int?
    let skipped_existing: Int?
    let skipped_invalid: Int?
    let failed: Int?
}

private struct CloudCatalogIngredientCreationBatchItemRow: Codable {
    let normalized_text: String?
    let slug: String?
    let result_status: String?
    let detail: String?
    let ingredient_id: String?
    let error_message: String?
}

private struct CloudCatalogIngredientCreationBatchMetadata: Codable {
    let mode: String?
}

private struct CloudCatalogIngredientCreationBatchResponse: Codable {
    let summary: CloudCatalogIngredientCreationBatchSummary?
    let items: [CloudCatalogIngredientCreationBatchItemRow]?
    let metadata: CloudCatalogIngredientCreationBatchMetadata?
}

private struct CloudCatalogAutomationCycleRecoverySummary: Codable {
    let total: Int?
    let observed: Int?
    let skipped: Int?
    let failed: Int?
    let status: String?
    let error: String?
}

private struct CloudCatalogAutomationCycleEnrichmentSummary: Codable {
    let total: Int?
    let succeeded: Int?
    let failed: Int?
    let skipped: Int?
    let ready: Int?
    let status: String?
    let error: String?
}

private struct CloudCatalogAutomationCycleCreationSummary: Codable {
    let total: Int?
    let created: Int?
    let skipped_existing: Int?
    let skipped_invalid: Int?
    let failed: Int?
    let status: String?
    let error: String?
}

private struct CloudCatalogAutomationCycleSummary: Codable {
    let recovery: CloudCatalogAutomationCycleRecoverySummary?
    let enrichment: CloudCatalogAutomationCycleEnrichmentSummary?
    let creation: CloudCatalogAutomationCycleCreationSummary?
}

private struct CloudCatalogAutomationCycleMetadataLimits: Codable {
    let recovery_limit: Int?
    let enrich_limit: Int?
    let create_limit: Int?
}

private struct CloudCatalogAutomationCycleMetadata: Codable {
    let mode: String?
    let limits: CloudCatalogAutomationCycleMetadataLimits?
}

private struct CloudCatalogAutomationCycleResponse: Codable {
    let summary: CloudCatalogAutomationCycleSummary?
    let metadata: CloudCatalogAutomationCycleMetadata?
}

private struct CloudCatalogEnrichmentDraftRow: Codable {
    let normalized_text: String?
    let status: String?
    let ingredient_type: String?
    let canonical_name_it: String?
    let canonical_name_en: String?
    let suggested_slug: String?
    let suggested_aliases: [String]?
    let default_unit: String?
    let supported_units: [String]?
    let is_seasonal: Bool?
    let season_months: [Int]?
    let confidence_score: Double?
    let needs_manual_review: Bool?
    let reasoning_summary: String?
    let reviewer_note: String?
    let validated_ready: Bool?
    let validation_errors: [String]?
    let updated_at: String?
}

private struct CloudCatalogEnrichmentDraftMutationRow: Codable {
    let normalized_text: String?
    let status: String?
    let ingredient_type: String?
    let validated_ready: Bool?
    let is_ready: Bool?
    let validation_errors: [String]?
}

private struct CloudUnifiedIngredientCatalogSummaryRow: Codable {
    let ingredient_id: String
    let slug: String
    let ingredient_type: String
    let en_name: String?
    let it_name: String?
    let legacy_produce_id: String?
    let legacy_basic_id: String?
}

private struct CloudUnifiedIngredientAliasRow: Codable {
    let ingredient_id: String?
    let alias_text: String?
    let normalized_alias_text: String?
    let language_code: String?
    let source: String?
    let confidence: Double?
    let is_active: Bool?
}

struct ParseRecipeCaptionFunctionIngredient: Codable {
    let name: String
    let quantity: Double?
    let unit: String?
}

struct ParseRecipeCaptionFunctionResult: Codable {
    let title: String?
    let ingredients: [ParseRecipeCaptionFunctionIngredient]
    let steps: [String]
    let prepTimeMinutes: Double?
    let cookTimeMinutes: Double?
    let confidence: String
    let inferredDish: String?
}

struct ParseRecipeCaptionFunctionError: Codable {
    let code: String
    let message: String
}

struct ParseRecipeCaptionFunctionResponse: Codable {
    let ok: Bool
    let result: ParseRecipeCaptionFunctionResult?
    let error: ParseRecipeCaptionFunctionError?
}

struct CatalogEnrichmentProposalFunctionRequest: Encodable {
    let normalized_text: String
}

private struct CatalogEnrichmentBatchRequest: Encodable {
    let limit: Int
    let debug: Bool
}

private struct CatalogAutomationCycleRequest: Encodable {
    let recovery_limit: Int
    let enrich_limit: Int
    let create_limit: Int
    let debug: Bool
}

struct CatalogEnrichmentProposalFunctionResponse: Codable {
    let ingredient_type: String
    let canonical_name_it: String?
    let canonical_name_en: String?
    let suggested_slug: String
    let semantic_category: String?
    let parent_candidate_slug: String?
    let parent_candidate_reason: String?
    let variant_kind: String?
    let specificity_rank_suggestion: Int?
    let default_unit: String
    let supported_units: [String]
    let is_seasonal: Bool?
    let season_months: [Int]?
    let needs_manual_review: Bool
    let reasoning_summary: String
    let confidence_score: Double
}

struct CustomIngredientObservation: Sendable {
    let normalizedText: String
    let rawExample: String
    let languageCode: String?
    let source: String
    let latestRecipeID: String?
}

private struct ParseRecipeCaptionFunctionRequest: Encodable {
    let caption: String?
    let url: String?
    let languageCode: String
}

struct ImportedRecipePreview: Codable, Sendable {
    let title: String
    let ingredients: [String]
    let steps: [String]
    let imageURL: String?
    let sourceURL: String
    let sourceName: String

    private enum CodingKeys: String, CodingKey {
        case title
        case ingredients
        case steps
        case imageURL = "image_url"
        case sourceURL = "source_url"
        case sourceName = "source_name"
    }
}

private struct ImportRecipeFromURLFunctionRequest: Encodable {
    let url: String
}

private struct ParseRecipeCaptionFunctionErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    struct MetaBody: Decodable {
        let retryAfterSeconds: Int?
    }

    let ok: Bool
    let error: ErrorBody?
    let meta: MetaBody?
}

private struct ImportRecipeFromURLErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    let ok: Bool?
    let error: ErrorBody?
}

private struct CloudFollowRow: Codable {
    let id: String?
    let follower_id: String?
    let following_id: String?
    let created_at: String?
}

private struct FollowInsertPayload: Encodable {
    let follower_id: String
    let following_id: String
    let created_at: String
}

private struct ShoppingListItemInsertPayload: Encodable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool
    let created_at: String
    let updated_at: String
}

private struct ShoppingListItemUpdatePayload: Encodable {
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool
    let updated_at: String
}

private struct FridgeItemInsertPayload: Encodable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let created_at: String
    let updated_at: String
}

private struct FridgeItemUpdatePayload: Encodable {
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let updated_at: String
}

private struct ProfileSocialLinksUpdatePayload: Encodable {
    let instagram_url: String?
    let tiktok_url: String?
}

private struct ProfileAvatarUpdatePayload: Encodable {
    let avatar_url: String?
}

private struct ProfileIdentityUpsertPayload: Encodable {
    let id: String
    let display_name: String?
    let season_username: String
}

final class SupabaseService {
    static let shared = SupabaseService()

    let configuration: SupabaseConfiguration?
    let configurationIssue: String?
    private let client: SupabaseClient?
    private let authRepository: AuthRepository
    private let recipeRepository: RecipeRepository

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseService.loadConfiguration(from: bundle)
            self.configuration = configuration
            self.configurationIssue = nil
            self.client = SupabaseClient(
                supabaseURL: configuration.url,
                supabaseKey: configuration.anonKey
            )
        } catch {
            self.configuration = nil
            self.configurationIssue = (error as? LocalizedError)?.errorDescription ?? "Supabase configuration is invalid."
            self.client = nil
        }

        self.authRepository = AuthRepository(
            client: self.client,
            configurationIssue: self.configurationIssue
        )
        self.recipeRepository = RecipeRepository(
            client: self.client,
            configurationIssue: self.configurationIssue
        )
    }

    func currentAuthenticatedUserID() -> UUID? {
        authRepository.currentAuthenticatedUserID()
    }

    func currentAuthenticatedEmail() -> String? {
        authRepository.currentAuthenticatedEmail()
    }

    func isCurrentUserCatalogAdmin() async -> Bool {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_ADMIN] phase=admin_status_check_failed reason=missing_configuration")
            return false
        }

        let currentUserID = supabaseClient.auth.currentUser?.id.uuidString.lowercased()
        print("[SEASON_CATALOG_ADMIN] phase=admin_status_rpc_called current_user_id=\(currentUserID ?? "nil")")

        if currentUserID == nil {
            do {
                let sessionUserID = try await supabaseClient.auth.session.user.id.uuidString.lowercased()
                print("[SEASON_CATALOG_ADMIN] phase=admin_status_session_restored user_id=\(sessionUserID)")
            } catch {
                print("[SEASON_CATALOG_ADMIN] phase=admin_status_check_skipped reason=unauthenticated error=\(error)")
                return false
            }
        }

        do {
            let response = try await supabaseClient
                .rpc("is_current_user_catalog_admin")
                .execute()
            let rawResponse = String(data: response.data, encoding: .utf8) ?? "<non_utf8>"
            print("[SEASON_CATALOG_ADMIN] phase=admin_status_rpc_response raw=\(rawResponse)")
            let isAdmin = decodeRPCBoolean(response.data, key: "is_current_user_catalog_admin")
            let payloadDescription = describeRPCPayload(response.data)
            print("[SEASON_CATALOG_ADMIN] phase=admin_status_decode payload=\(payloadDescription) decoded_is_admin=\(isAdmin)")
            return isAdmin
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=admin_status_check_failed error=\(error)")
            return false
        }
    }

    func isUsernameAvailable(_ username: String, excludingUserID: UUID? = nil) async throws -> Bool {
        try await instrumentedRequest(name: "isUsernameAvailable") {
            try await authRepository.isUsernameAvailable(username, excludingUserID: excludingUserID)
        }
    }

    func fetchFollows(for followerId: String) async -> [FollowRelation] {
        let normalizedFollowerID = normalizeFollowID(followerId)
        guard !normalizedFollowerID.isEmpty else { return [] }

        print("[SEASON_SUPABASE] request=fetchFollows phase=request_started follower_id=\(normalizedFollowerID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await client
                .from("follows")
                .select()
                .eq("follower_id", value: normalizedFollowerID)
                .execute()

            let rows = try JSONDecoder().decode([CloudFollowRow].self, from: response.data)
            let iso8601 = ISO8601DateFormatter()
            let relations = rows.compactMap { row -> FollowRelation? in
                let follower = normalizeFollowID(row.follower_id ?? "")
                let following = normalizeFollowID(row.following_id ?? "")
                guard !follower.isEmpty, !following.isEmpty, following != "unknown" else { return nil }
                let createdAt = row.created_at.flatMap { iso8601.date(from: $0) } ?? Date()
                return FollowRelation(followerId: follower, followingId: following, createdAt: createdAt)
            }

            print("[SEASON_SUPABASE] request=fetchFollows phase=request_ok follower_id=\(normalizedFollowerID) count=\(relations.count)")
            return relations
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed reason=table_missing follower_id=\(normalizedFollowerID) error=\(error)")
                return []
            }
            print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed follower_id=\(normalizedFollowerID) error=\(error)")
            return []
        }
    }

    func createFollow(_ relation: FollowRelation) async {
        let followerID = normalizeFollowID(relation.followerId)
        let followingID = normalizeFollowID(relation.followingId)
        guard !followerID.isEmpty, !followingID.isEmpty, followingID != "unknown" else { return }

        print("[SEASON_SUPABASE] request=createFollow phase=request_started follower_id=\(followerID) following_id=\(followingID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=createFollow phase=request_failed reason=missing_configuration")
            return
        }

        let payload = FollowInsertPayload(
            follower_id: followerID,
            following_id: followingID,
            created_at: ISO8601DateFormatter().string(from: relation.createdAt)
        )

        do {
            _ = try await client
                .from("follows")
                .upsert(payload, onConflict: "follower_id,following_id")
                .execute()
            print("[SEASON_SUPABASE] request=createFollow phase=request_ok follower_id=\(followerID) following_id=\(followingID)")
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=createFollow phase=request_failed reason=table_missing follower_id=\(followerID) following_id=\(followingID) error=\(error)")
                return
            }
            print("[SEASON_SUPABASE] request=createFollow phase=request_failed follower_id=\(followerID) following_id=\(followingID) error=\(error)")
        }
    }

    func deleteFollow(followerId: String, followingId: String) async {
        let normalizedFollowerID = normalizeFollowID(followerId)
        let normalizedFollowingID = normalizeFollowID(followingId)
        guard !normalizedFollowerID.isEmpty, !normalizedFollowingID.isEmpty else { return }

        print("[SEASON_SUPABASE] request=deleteFollow phase=request_started follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed reason=missing_configuration")
            return
        }

        do {
            _ = try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: normalizedFollowerID)
                .eq("following_id", value: normalizedFollowingID)
                .execute()
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_ok follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID)")
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed reason=table_missing follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID) error=\(error)")
                return
            }
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID) error=\(error)")
        }
    }

    func setSession(accessToken: String, refreshToken: String) async throws {
        guard let client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }
        _ = try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
        notifyAuthStateDidChange()
    }

    func signInWithEmail(email: String, password: String) async throws -> UUID {
        try await instrumentedRequest(name: "signInWithEmail") {
            let userID = try await authRepository.signInWithEmail(email: email, password: password)
            notifyAuthStateDidChange()
            return userID
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> UUID {
        try await instrumentedRequest(name: "signUpWithEmail") {
            let userID = try await authRepository.signUpWithEmail(email: email, password: password)
            notifyAuthStateDidChange()
            return userID
        }
    }

    func signOut() async throws {
        try await instrumentedRequest(name: "signOut") {
            try await authRepository.signOut()
            notifyAuthStateDidChange()
        }
    }

    func signInWithAppleIDToken(_ idToken: String) async throws -> UUID {
        try await instrumentedRequest(name: "signInWithAppleIDToken") {
            let userID = try await authRepository.signInWithAppleIDToken(idToken)
            notifyAuthStateDidChange()
            return userID
        }
    }

    #if DEBUG
    func authenticateWithEmailPasswordForTesting(email: String, password: String) async throws -> UUID {
        try await instrumentedRequest(name: "authenticateWithEmailPasswordForTesting") {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedEmail.isEmpty else {
                throw SupabaseServiceError.missingConfiguration("Email")
            }
            guard !normalizedPassword.isEmpty else {
                throw SupabaseServiceError.missingConfiguration("Password")
            }

            guard let client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            do {
                _ = try await client.auth.signIn(email: normalizedEmail, password: normalizedPassword)
            } catch {
                _ = try await client.auth.signUp(email: normalizedEmail, password: normalizedPassword)
                _ = try await client.auth.signIn(email: normalizedEmail, password: normalizedPassword)
            }

            guard let userID = client.auth.currentUser?.id else {
                throw SupabaseServiceError.unauthenticated
            }
            return userID
        }
    }
    #endif

    func validateProfilePipeline(for userID: UUID) async throws -> Bool {
        try await authRepository.validateProfilePipeline(for: userID)
    }

    func fetchMyProfile() async throws -> Profile? {
        try await instrumentedRequest(name: "fetchMyProfile") {
            try await authRepository.fetchMyProfile()
        }
    }

    func updateMyProfileSocialLinks(instagramURL: String?, tiktokURL: String?) async throws {
        try await instrumentedRequest(name: "updateProfileSocialLinks") {
            try await authRepository.updateMyProfileSocialLinks(instagramURL: instagramURL, tiktokURL: tiktokURL)
        }
    }

    func upsertMyProfileIdentity(username: String, displayName: String?) async throws {
        try await instrumentedRequest(name: "upsertMyProfileIdentity") {
            try await authRepository.upsertMyProfileIdentity(username: username, displayName: displayName)
        }
    }

    func uploadMyProfileAvatar(imageData: Data) async throws -> String {
        try await instrumentedRequest(name: "uploadMyProfileAvatar") {
            try await authRepository.uploadMyProfileAvatar(imageData: imageData)
        }
    }

    func uploadRecipeImage(imageData: Data, recipeID: String) async throws -> String {
        try await instrumentedRequest(name: "uploadRecipeImage", metadata: "recipe_id=\(recipeID)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            let userAtUploadTime = supabaseClient.auth.currentUser
            let hasAuthenticatedUser = userAtUploadTime != nil
            let currentUserID = userAtUploadTime?.id.uuidString.lowercased() ?? "nil"

            guard let user = userAtUploadTime else {
                throw SupabaseServiceError.unauthenticated
            }

            let bucketName = "recipes"
            let normalizedRecipeID = recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = "\(user.id.uuidString.lowercased())/\(normalizedRecipeID).jpg"
            let pathSegments = path.split(separator: "/").map(String.init)
            let firstFolderSegment = pathSegments.indices.contains(0) ? pathSegments[0] : "nil"
            let uidPathSegment = pathSegments.indices.contains(1) ? pathSegments[1] : "nil"
            let fileSegment = pathSegments.indices.contains(2) ? pathSegments[2] : "nil"
            let timeoutSeconds: TimeInterval = 10

            print("[SEASON_SUPABASE] phase=upload_context bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) has_authenticated_user=\(hasAuthenticatedUser) current_user_id=\(currentUserID) path_first_segment=\(firstFolderSegment) path_uid_segment=\(uidPathSegment) path_file_segment=\(fileSegment)")
            print("[SEASON_SUPABASE] phase=upload_started bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) expected_auth_uid=\(user.id.uuidString.lowercased())")

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        _ = try await supabaseClient.storage
                            .from(bucketName)
                            .upload(
                                path,
                                data: imageData,
                                options: FileOptions(
                                    contentType: "image/jpeg",
                                    upsert: true
                                )
                            )
                    }

                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        throw SupabaseServiceError.requestTimedOut("uploadRecipeImage", timeoutSeconds)
                    }

                    _ = try await group.next()
                    group.cancelAll()
                }

                return try supabaseClient.storage
                    .from(bucketName)
                    .getPublicURL(path: path)
                    .absoluteString
            } catch let SupabaseServiceError.requestTimedOut(requestName, seconds) {
                print("[SEASON_SUPABASE] request=\(requestName) phase=request_timeout duration_s=\(Int(seconds)) recipe_id=\(recipeID)")
                throw SupabaseServiceError.requestTimedOut(requestName, seconds)
            } catch {
                print("[SEASON_SUPABASE] phase=upload_failed bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) expected_auth_uid=\(user.id.uuidString.lowercased()) error=\(error)")
                throw error
            }
        }
    }

    func parseRecipeCaption(
        caption: String?,
        url: String?,
        languageCode: String
    ) async throws -> ParseRecipeCaptionFunctionResponse {
        try await instrumentedRequest(name: "parseRecipeCaption") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                print("[SEASON_IMPORT_AUTH] phase=missing_current_user has_session=false invoke_with_authenticated_context=false")
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print("[SEASON_IMPORT_AUTH] phase=missing_access_token user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=false invoke_with_authenticated_context=false error=\(error)")
                throw SupabaseServiceError.unauthenticated
            }
            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            supabaseClient.functions.setAuth(token: accessToken)
            print("[SEASON_IMPORT_AUTH] phase=session_ready user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=true invoke_with_authenticated_context=true")

            let normalizedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = ParseRecipeCaptionFunctionRequest(
                caption: normalizedCaption?.isEmpty == true ? nil : normalizedCaption,
                url: normalizedURL?.isEmpty == true ? nil : normalizedURL,
                languageCode: languageCode
            )

            print("[SEASON_IMPORT_AUTH] phase=invoke_started user_id=\(authenticatedUser.id.uuidString.lowercased()) authenticated_context=true")
            do {
                return try await supabaseClient.functions.invoke(
                    "parse-recipe-caption",
                    options: FunctionInvokeOptions(
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(accessToken)",
                            "apikey": anonKey
                        ],
                        body: payload
                    )
                )
            } catch let functionsError as FunctionsError {
                switch functionsError {
                case .httpError(let code, let data):
                    if code == 429,
                       let parsed = try? JSONDecoder().decode(ParseRecipeCaptionFunctionErrorEnvelope.self, from: data),
                       let errorCode = parsed.error?.code {
                        if errorCode == "TOO_FREQUENT_REQUESTS" {
                            throw ParseRecipeCaptionInvokeError.tooFrequent(
                                retryAfterSeconds: parsed.meta?.retryAfterSeconds
                            )
                        }
                        if errorCode == "RATE_LIMIT_EXCEEDED" {
                            throw ParseRecipeCaptionInvokeError.dailyLimitReached
                        }
                    }
                    throw functionsError
                case .relayError:
                    throw functionsError
                }
            }
        }
    }

    func importRecipeFromURL(url: String) async throws -> ImportedRecipePreview {
        try await instrumentedRequest(name: "importRecipeFromURL") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                print("[SEASON_URL_IMPORT_AUTH] phase=missing_current_user has_session=false")
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print("[SEASON_URL_IMPORT_AUTH] phase=missing_access_token user_id=\(authenticatedUser.id.uuidString.lowercased()) error=\(error)")
                throw SupabaseServiceError.unauthenticated
            }

            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedURL.isEmpty else {
                throw SupabaseServiceError.invalidURL
            }

            supabaseClient.functions.setAuth(token: accessToken)
            print("[SEASON_URL_IMPORT_AUTH] phase=invoke_started user_id=\(authenticatedUser.id.uuidString.lowercased())")

            do {
                return try await supabaseClient.functions.invoke(
                    "import-recipe-from-url",
                    options: FunctionInvokeOptions(
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(accessToken)",
                            "apikey": anonKey
                        ],
                        body: ImportRecipeFromURLFunctionRequest(url: normalizedURL)
                    )
                )
            } catch let functionsError as FunctionsError {
                switch functionsError {
                case .httpError(_, let data):
                    if let parsed = try? JSONDecoder().decode(ImportRecipeFromURLErrorEnvelope.self, from: data),
                       let message = parsed.error?.message,
                       !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw NSError(
                            domain: "Season.ImportRecipeFromURL",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: message]
                        )
                    }
                    throw functionsError
                case .relayError:
                    throw functionsError
                }
            }
        }
    }

    func fetchCatalogEnrichmentProposal(
        normalizedText: String
    ) async throws -> CatalogEnrichmentProposalFunctionResponse {
        try await instrumentedRequest(name: "fetchCatalogEnrichmentProposal") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                print("[SEASON_CATALOG_ENRICH_AUTH] phase=missing_current_user has_session=false invoke_with_authenticated_context=false")
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print("[SEASON_CATALOG_ENRICH_AUTH] phase=missing_access_token user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=false invoke_with_authenticated_context=false error=\(error)")
                throw SupabaseServiceError.unauthenticated
            }

            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            supabaseClient.functions.setAuth(token: accessToken)

            let payload = CatalogEnrichmentProposalFunctionRequest(
                normalized_text: normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )

            print("[SEASON_CATALOG_ENRICH_AUTH] phase=invoke_started user_id=\(authenticatedUser.id.uuidString.lowercased()) authenticated_context=true")

            return try await supabaseClient.functions.invoke(
                "catalog-enrichment-proposal",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(accessToken)",
                        "apikey": anonKey
                    ],
                    body: payload
                )
            )
        }
    }

    func fetchMyLinkedSocialAccounts() async throws -> [CloudLinkedSocialAccount] {
        try await instrumentedRequest(name: "fetchMyLinkedSocialAccounts") {
            try await authRepository.fetchMyLinkedSocialAccounts()
        }
    }

    func deleteMyLinkedSocialAccount(provider: String) async throws {
        try await instrumentedRequest(name: "deleteMyLinkedSocialAccount", metadata: "provider=\(provider)") {
            try await authRepository.deleteMyLinkedSocialAccount(provider: provider)
        }
    }

    func fetchMyUserRecipeStates() async throws -> [CloudUserRecipeState] {
        try await instrumentedRequest(name: "fetchMyUserRecipeStates") {
            try await recipeRepository.fetchMyUserRecipeStates()
        }
    }

    func fetchMyShoppingListItems() async throws -> [CloudShoppingListItem] {
        try await instrumentedRequest(name: "fetchMyShoppingListItems") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return []
            }

            let response = try await supabaseClient
                .from("shopping_list_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .execute()

            return try JSONDecoder().decode([CloudShoppingListItem].self, from: response.data)
        }
    }

    func fetchMyFridgeItems() async throws -> [CloudFridgeItem] {
        try await instrumentedRequest(name: "fetchMyFridgeItems") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return []
            }

            let response = try await supabaseClient
                .from("fridge_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .execute()

            return try JSONDecoder().decode([CloudFridgeItem].self, from: response.data)
        }
    }

    func fetchActiveIngredientAliases() async -> [IngredientAliasRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_ALIAS] phase=fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_aliases")
                .select()
                .eq("is_active", value: true)
                .execute()

            let rows = try JSONDecoder().decode([CloudIngredientAliasRow].self, from: response.data)
            let records = rows.compactMap { row -> IngredientAliasRecord? in
                let normalized = row.normalized_alias_text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""
                guard !normalized.isEmpty else { return nil }

                let alias = row.alias_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? normalized
                let produceID = row.produce_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                let basicID = row.basic_ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (produceID?.isEmpty == false) != (basicID?.isEmpty == false) else { return nil }
                let sourceValue = row.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                return IngredientAliasRecord(
                    produceID: produceID?.isEmpty == true ? nil : produceID,
                    basicIngredientID: basicID?.isEmpty == true ? nil : basicID,
                    aliasText: alias,
                    normalizedAliasText: normalized,
                    languageCode: row.language_code?.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: sourceValue.isEmpty ? "manual" : sourceValue,
                    confidence: row.confidence,
                    isActive: row.is_active ?? true
                )
            }
            print("[SEASON_ALIAS] phase=fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingIngredientAliasesTableError(error) {
                print("[SEASON_ALIAS] phase=fetch_failed reason=table_missing error=\(error)")
                return []
            }
            print("[SEASON_ALIAS] phase=fetch_failed error=\(error)")
            return []
        }
    }

    func fetchUnifiedIngredientCatalogSummary() async -> [UnifiedIngredientCatalogSummaryRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_UNIFIED] phase=catalog_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_catalog_summary")
                .select()
                .execute()

            let rows = try JSONDecoder().decode([CloudUnifiedIngredientCatalogSummaryRow].self, from: response.data)
            let records = rows.map { row in
                UnifiedIngredientCatalogSummaryRecord(
                    ingredientID: row.ingredient_id.trimmingCharacters(in: .whitespacesAndNewlines),
                    slug: row.slug.trimmingCharacters(in: .whitespacesAndNewlines),
                    ingredientType: row.ingredient_type.trimmingCharacters(in: .whitespacesAndNewlines),
                    enName: row.en_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                    itName: row.it_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                    legacyProduceID: row.legacy_produce_id?.trimmingCharacters(in: .whitespacesAndNewlines),
                    legacyBasicID: row.legacy_basic_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            print("[SEASON_UNIFIED] phase=catalog_fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingUnifiedIngredientSummaryRelationError(error) {
                print("[SEASON_UNIFIED] phase=catalog_fetch_failed reason=relation_missing error=\(error)")
                return []
            }
            print("[SEASON_UNIFIED] phase=catalog_fetch_failed error=\(error)")
            return []
        }
    }

    func fetchUnifiedIngredientAliases() async -> [UnifiedIngredientAliasRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_aliases_v2")
                .select()
                .eq("is_active", value: true)
                .execute()

            let rows = try JSONDecoder().decode([CloudUnifiedIngredientAliasRow].self, from: response.data)
            let records = rows.compactMap { row -> UnifiedIngredientAliasRecord? in
                let ingredientID = row.ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let normalized = row.normalized_alias_text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""
                guard !ingredientID.isEmpty, !normalized.isEmpty else { return nil }

                let aliasText = row.alias_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? normalized
                let sourceValue = row.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return UnifiedIngredientAliasRecord(
                    ingredientID: ingredientID,
                    aliasText: aliasText,
                    normalizedAliasText: normalized,
                    languageCode: row.language_code?.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: sourceValue.isEmpty ? "manual" : sourceValue,
                    confidence: row.confidence,
                    isActive: row.is_active ?? true
                )
            }
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingUnifiedIngredientAliasesRelationError(error) {
                print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed reason=relation_missing error=\(error)")
                return []
            }
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed error=\(error)")
            return []
        }
    }

    func observeCustomIngredientObservations(_ observations: [CustomIngredientObservation]) async {
        guard !observations.isEmpty else { return }
        guard let supabaseClient = self.client else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_failed reason=missing_configuration count=\(observations.count)")
            return
        }
        guard supabaseClient.auth.currentUser != nil else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_skipped reason=unauthenticated count=\(observations.count)")
            return
        }

        for observation in observations {
            print("[SEASON_CUSTOM_INGREDIENT] phase=observed normalized_text=\(observation.normalizedText) source=\(observation.source)")
            var params: [String: String] = [
                "p_normalized_text": observation.normalizedText,
                "p_raw_example": observation.rawExample,
                "p_source": observation.source
            ]
            if let languageCode = observation.languageCode, !languageCode.isEmpty {
                params["p_language_code"] = languageCode
            }
            if let latestRecipeID = observation.latestRecipeID, !latestRecipeID.isEmpty {
                params["p_latest_recipe_id"] = latestRecipeID
            }

            do {
                _ = try await supabaseClient
                    .rpc("observe_custom_ingredient", params: params)
                    .execute()
                print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_succeeded normalized_text=\(observation.normalizedText)")
            } catch {
                print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_failed normalized_text=\(observation.normalizedText) error=\(error)")
            }
        }
    }

    private func normalizedCustomIngredientObservationText(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    private func unresolvedCustomIngredientObservationsForRecipe(_ recipe: Recipe) -> [CustomIngredientObservation] {
        var seen = Set<String>()
        var observations: [CustomIngredientObservation] = []

        for ingredient in recipe.ingredients {
            if ingredient.produceID != nil || ingredient.basicIngredientID != nil {
                continue
            }

            let rawName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { continue }

            let normalized = normalizedCustomIngredientObservationText(rawName)
            guard !normalized.isEmpty else { continue }
            guard seen.insert(normalized).inserted else { continue }

            observations.append(
                CustomIngredientObservation(
                    normalizedText: normalized,
                    rawExample: rawName,
                    languageCode: nil,
                    source: recipe.sourceType == .curatedImport ? "import" : "manual",
                    latestRecipeID: recipe.id
                )
            )
        }

        return observations
    }

    private func observeUnresolvedCustomIngredientsForRecipeIfNeeded(_ recipe: Recipe) {
        let observations = unresolvedCustomIngredientObservationsForRecipe(recipe)
        guard !observations.isEmpty else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=post_publish_observation_skipped reason=no_unresolved recipe_id=\(recipe.id)")
            return
        }

        print("[SEASON_CUSTOM_INGREDIENT] phase=post_publish_observation_started recipe_id=\(recipe.id) count=\(observations.count)")
        Task {
            await observeCustomIngredientObservations(observations)
        }
    }

    func fetchCatalogAdminOpsSnapshot(
        candidatesLimit: Int = 50,
        coverageBlockersLimit: Int = 30,
        readyDraftsLimit: Int = 50,
        focusAliasLocalization: Bool = true
    ) async -> CatalogAdminOpsSnapshot? {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_DEBUG] phase=ops_snapshot_fetch_failed reason=missing_configuration")
            return nil
        }

        do {
            let params: [String: AnyJSON] = [
                "p_candidates_limit": .integer(max(1, candidatesLimit)),
                "p_coverage_blockers_limit": .integer(max(1, coverageBlockersLimit)),
                "p_ready_drafts_limit": .integer(max(1, readyDraftsLimit)),
                "p_focus_alias_localization": .bool(focusAliasLocalization)
            ]

            let response = try await supabaseClient
                .rpc("get_catalog_admin_ops_snapshot", params: params)
                .execute()

            let payload = try JSONDecoder().decode(CloudCatalogAdminOpsSnapshot.self, from: response.data)
            let candidates = mapCatalogResolutionCandidates(payload.candidates ?? [])
            let coverageBlockers = mapCatalogCoverageBlockers(payload.coverage_blockers ?? [])
            let readyDrafts = mapReadyCatalogEnrichmentDrafts(payload.ready_enrichment_drafts ?? [])
            let observationCoverage = mapCatalogObservationCoverage(payload.observation_coverage ?? [])
            let iso8601 = ISO8601DateFormatter()
            let generatedAt = payload.metadata?.generated_at.flatMap { iso8601.date(from: $0) }
            let counts = payload.metadata?.counts
            let metadata = CatalogAdminOpsSnapshotMetadata(
                generatedAt: generatedAt,
                candidatesCount: counts?.candidates ?? candidates.count,
                coverageBlockersCount: counts?.coverage_blockers ?? coverageBlockers.count,
                readyEnrichmentDraftsCount: counts?.ready_enrichment_drafts ?? readyDrafts.count,
                observationCoverageCount: counts?.observation_coverage ?? observationCoverage.count,
                source: cleanedOptional(payload.metadata?.source) ?? "catalog_admin_ops_snapshot_v2"
            )

            print(
                "[SEASON_CATALOG_DEBUG] phase=ops_snapshot_fetch_ok " +
                "candidates=\(candidates.count) " +
                "coverage_blockers=\(coverageBlockers.count) " +
                "ready_drafts=\(readyDrafts.count) " +
                "observation_coverage=\(observationCoverage.count)"
            )

            return CatalogAdminOpsSnapshot(
                candidates: candidates,
                coverageBlockers: coverageBlockers,
                readyEnrichmentDrafts: readyDrafts,
                observationCoverage: observationCoverage,
                metadata: metadata
            )
        } catch {
            print("[SEASON_CATALOG_DEBUG] phase=ops_snapshot_fetch_failed error=\(error)")
            return nil
        }
    }

    func executeCatalogCandidateBatchTriage(
        items: [CatalogCandidateBatchTriageItem],
        defaultLanguageCode: String? = nil,
        reviewerNote: String? = nil
    ) async throws -> CatalogCandidateBatchTriageResult {
        try await instrumentedRequest(name: "executeCatalogCandidateBatchTriage", metadata: "items=\(items.count)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let payloadItems: [AnyJSON] = items.map { item in
                var payload: [String: AnyJSON] = [
                    "normalized_text": .string(item.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
                    "action": .string(item.action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                ]
                if let ingredientID = cleanedOptional(item.ingredientID) {
                    payload["ingredient_id"] = .string(ingredientID.lowercased())
                }
                if let aliasText = cleanedOptional(item.aliasText) {
                    payload["alias_text"] = .string(aliasText)
                }
                if let languageCode = cleanedOptional(item.languageCode) {
                    payload["language_code"] = .string(languageCode.lowercased())
                }
                if let confidenceScore = item.confidenceScore {
                    payload["confidence_score"] = .double(confidenceScore)
                }
                if let reviewerNote = cleanedOptional(item.reviewerNote) {
                    payload["reviewer_note"] = .string(reviewerNote)
                }
                return .object(payload)
            }

            let params: [String: AnyJSON] = [
                "p_items": .array(payloadItems),
                "p_default_language_code": cleanedOptional(defaultLanguageCode).map { .string($0.lowercased()) } ?? .null,
                "p_reviewer_note": cleanedOptional(reviewerNote).map { .string($0) } ?? .null
            ]

            let response = try await supabaseClient
                .rpc("execute_catalog_candidate_batch_triage", params: params)
                .execute()

            let payload = try JSONDecoder().decode(CloudCatalogCandidateBatchTriageResult.self, from: response.data)
            let summary = CatalogCandidateBatchTriageSummary(
                total: payload.summary?.total ?? items.count,
                succeeded: payload.summary?.succeeded ?? 0,
                failed: payload.summary?.failed ?? 0,
                skipped: payload.summary?.skipped ?? 0
            )
            let mappedItems: [CatalogCandidateBatchTriageItemResult] = (payload.items ?? []).map { row in
                let action = cleanedOptional(row.intended_action) ?? cleanedOptional(row.action) ?? ""
                let errorMessage = cleanedOptional(row.error_message)
                return CatalogCandidateBatchTriageItemResult(
                    normalizedText: cleanedOptional(row.normalized_text) ?? "",
                    intendedAction: action,
                    resultStatus: cleanedOptional(row.result_status) ?? "failed",
                    detail: cleanedOptional(row.detail) ?? errorMessage,
                    errorMessage: errorMessage,
                    ingredientID: cleanedOptional(row.ingredient_id)?.lowercased(),
                    aliasText: cleanedOptional(row.alias_text),
                    draftStatus: cleanedOptional(row.draft_status),
                    draftValidatedReady: row.draft_validated_ready
                )
            }

            let result = CatalogCandidateBatchTriageResult(
                summary: summary,
                items: mappedItems,
                source: cleanedOptional(payload.metadata?.source) ?? "catalog_candidate_batch_triage_v1"
            )

            print(
                "[SEASON_CATALOG_ADMIN] phase=batch_triage_ok " +
                "total=\(result.summary.total) " +
                "succeeded=\(result.summary.succeeded) " +
                "failed=\(result.summary.failed) " +
                "skipped=\(result.summary.skipped)"
            )
            if result.summary.failed > 0 {
                for item in result.items where item.resultStatus == "failed" {
                    print(
                        "[SEASON_CATALOG_ADMIN] phase=batch_triage_item_failed " +
                        "action=\(item.intendedAction) normalized_text=\(item.normalizedText) " +
                        "error=\(item.errorMessage ?? item.detail ?? "unknown_error")"
                    )
                }
            }

            return result
        }
    }

    func recoverUnresolvedRecipeIngredientObservations(
        limit: Int = 1000,
        recipeIDs: [String]? = nil,
        source: String = "import_recovery"
    ) async throws -> [RecipeObservationRecoveryRow] {
        try await instrumentedRequest(
            name: "recoverUnresolvedRecipeIngredientObservations",
            metadata: "limit=\(limit)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let cleanedRecipeIDs = (recipeIDs ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, limit)),
                "p_recipe_ids": cleanedRecipeIDs.isEmpty ? .null : .array(cleanedRecipeIDs.map { .string($0) }),
                "p_source": .string(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "import_recovery" : source.trimmingCharacters(in: .whitespacesAndNewlines))
            ]

            print("[SEASON_CATALOG_ADMIN] phase=observation_recovery_rpc_started limit=\(max(1, limit)) recipe_ids=\(cleanedRecipeIDs.count)")
            let response = try await supabaseClient
                .rpc("recover_unresolved_recipe_ingredient_observations", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudRecipeObservationRecoveryRow].self, from: response.data)
            let mapped = rows.map { row in
                RecipeObservationRecoveryRow(
                    recipeID: cleanedOptional(row.recipe_id) ?? "",
                    ingredientIndex: row.ingredient_index ?? 0,
                    normalizedText: cleanedOptional(row.normalized_text) ?? "",
                    rawExample: cleanedOptional(row.raw_example),
                    resultStatus: cleanedOptional(row.result_status) ?? "failed",
                    detail: cleanedOptional(row.detail)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=observation_recovery_rpc_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func autoApplySafeLocalizations(
        limit: Int = 50,
        languageCode: String = "it"
    ) async throws -> [CatalogAutoLocalizationItemResult] {
        try await instrumentedRequest(
            name: "autoApplySafeLocalizations",
            metadata: "limit=\(limit) language_code=\(languageCode)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let safeLimit = max(1, min(limit, 500))
            let safeLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "it"
                : languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let params: [String: AnyJSON] = [
                "p_limit": .integer(safeLimit),
                "p_language_code": .string(safeLanguage)
            ]

            print("[SEASON_CATALOG_ADMIN] phase=auto_localization_rpc_started limit=\(safeLimit) language_code=\(safeLanguage)")
            let response = try await supabaseClient
                .rpc("auto_apply_safe_localizations", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudCatalogAutoLocalizationRow].self, from: response.data)
            let mapped = rows.compactMap { row -> CatalogAutoLocalizationItemResult? in
                let normalized = cleanedOptional(row.normalized_text) ?? ""
                guard !normalized.isEmpty else { return nil }
                return CatalogAutoLocalizationItemResult(
                    normalizedText: normalized,
                    canonicalCandidateIngredientID: cleanedOptional(row.canonical_candidate_ingredient_id)?.lowercased(),
                    canonicalCandidateSlug: cleanedOptional(row.canonical_candidate_slug),
                    languageCode: cleanedOptional(row.language_code) ?? safeLanguage,
                    attemptedDisplayName: cleanedOptional(row.attempted_display_name),
                    resultStatus: cleanedOptional(row.result_status) ?? "failed",
                    detail: cleanedOptional(row.detail) ?? "unknown",
                    errorMessage: cleanedOptional(row.error_message)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=auto_localization_rpc_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func autoApplySafeAliases(
        limit: Int = 50,
        languageCode: String = "it"
    ) async throws -> [CatalogAutoAliasItemResult] {
        try await instrumentedRequest(
            name: "autoApplySafeAliases",
            metadata: "limit=\(limit) language_code=\(languageCode)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let safeLimit = max(1, min(limit, 500))
            let safeLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "it"
                : languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let params: [String: AnyJSON] = [
                "p_limit": .integer(safeLimit),
                "p_language_code": .string(safeLanguage)
            ]

            print("[SEASON_CATALOG_ADMIN] phase=auto_alias_rpc_started limit=\(safeLimit) language_code=\(safeLanguage)")
            let response = try await supabaseClient
                .rpc("auto_apply_safe_aliases", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudCatalogAutoAliasRow].self, from: response.data)
            let mapped = rows.compactMap { row -> CatalogAutoAliasItemResult? in
                let normalized = cleanedOptional(row.normalized_text) ?? ""
                guard !normalized.isEmpty else { return nil }
                return CatalogAutoAliasItemResult(
                    normalizedText: normalized,
                    canonicalCandidateIngredientID: cleanedOptional(row.canonical_candidate_ingredient_id)?.lowercased(),
                    canonicalCandidateSlug: cleanedOptional(row.canonical_candidate_slug),
                    languageCode: cleanedOptional(row.language_code) ?? safeLanguage,
                    attemptedAliasText: cleanedOptional(row.attempted_alias_text),
                    matchMethod: cleanedOptional(row.match_method),
                    resultStatus: cleanedOptional(row.result_status) ?? "failed",
                    detail: cleanedOptional(row.detail) ?? "unknown",
                    errorMessage: cleanedOptional(row.error_message)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=auto_alias_rpc_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func previewSafeRecipeIngredientReconciliation(
        limit: Int = 20,
        onlySafe: Bool = true
    ) async throws -> [RecipeIngredientReconciliationPreviewRow] {
        try await instrumentedRequest(
            name: "previewSafeRecipeIngredientReconciliation",
            metadata: "limit=\(limit) only_safe=\(onlySafe)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, min(limit, 200))),
                "p_only_safe": .bool(onlySafe)
            ]

            let response = try await supabaseClient
                .rpc("preview_safe_recipe_ingredient_reconciliation", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudRecipeIngredientReconciliationPreviewRow].self, from: response.data)
            let mapped = rows.map { row in
                RecipeIngredientReconciliationPreviewRow(
                    recipeID: cleanedOptional(row.recipe_id) ?? "",
                    recipeTitle: cleanedOptional(row.recipe_title) ?? "Untitled recipe",
                    recipeIngredientRowID: cleanedOptional(row.recipe_ingredient_row_id) ?? "",
                    ingredientIndex: row.ingredient_index ?? 0,
                    ingredientRawName: cleanedOptional(row.ingredient_raw_name) ?? "—",
                    currentMappingState: cleanedOrUnknown(row.current_mapping_state),
                    proposedIngredientID: cleanedOptional(row.proposed_ingredient_id)?.lowercased(),
                    proposedIngredientSlug: cleanedOptional(row.proposed_ingredient_slug),
                    proposedIngredientName: cleanedOptional(row.proposed_ingredient_name),
                    confidenceSource: cleanedOrUnknown(row.confidence_source),
                    safeToApply: row.safe_to_apply ?? false,
                    safetyReason: cleanedOrUnknown(row.safety_reason)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_preview_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func applySafeRecipeIngredientReconciliation(
        limit: Int = 20,
        recipeIDs: [String]? = nil
    ) async throws -> [RecipeIngredientReconciliationApplyRow] {
        try await instrumentedRequest(
            name: "applySafeRecipeIngredientReconciliation",
            metadata: "limit=\(limit)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let cleanedRecipeIDs = (recipeIDs ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, min(limit, 200))),
                "p_recipe_ids": cleanedRecipeIDs.isEmpty ? .null : .array(cleanedRecipeIDs.map { .string($0) })
            ]

            let response = try await supabaseClient
                .rpc("apply_recipe_ingredient_reconciliation", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudRecipeIngredientReconciliationApplyRow].self, from: response.data)
            let mapped = rows.map { row in
                RecipeIngredientReconciliationApplyRow(
                    batchID: cleanedOptional(row.batch_id)?.lowercased(),
                    recipeID: cleanedOptional(row.recipe_id) ?? "",
                    recipeIngredientRowID: cleanedOptional(row.recipe_ingredient_row_id) ?? "",
                    ingredientIndex: row.ingredient_index ?? 0,
                    matchedIngredientID: cleanedOptional(row.matched_ingredient_id)?.lowercased(),
                    matchSource: cleanedOrUnknown(row.match_source),
                    applied: row.applied ?? false,
                    applyStatus: cleanedOrUnknown(row.apply_status)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func applyModernSafeRecipeIngredientReconciliation(
        limit: Int = 20,
        recipeIDs: [String]? = nil
    ) async throws -> [RecipeIngredientReconciliationApplyRow] {
        try await instrumentedRequest(
            name: "applyModernSafeRecipeIngredientReconciliation",
            metadata: "limit=\(limit)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let cleanedRecipeIDs = (recipeIDs ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, min(limit, 200))),
                "p_recipe_ids": cleanedRecipeIDs.isEmpty ? .null : .array(cleanedRecipeIDs.map { .string($0) })
            ]

            let response = try await supabaseClient
                .rpc("apply_recipe_ingredient_reconciliation_modern", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudRecipeIngredientReconciliationApplyRow].self, from: response.data)
            let mapped = rows.map { row in
                RecipeIngredientReconciliationApplyRow(
                    batchID: cleanedOptional(row.batch_id)?.lowercased(),
                    recipeID: cleanedOptional(row.recipe_id) ?? "",
                    recipeIngredientRowID: cleanedOptional(row.recipe_ingredient_row_id) ?? "",
                    ingredientIndex: row.ingredient_index ?? 0,
                    matchedIngredientID: cleanedOptional(row.matched_ingredient_id)?.lowercased(),
                    matchSource: cleanedOrUnknown(row.match_source),
                    applied: row.applied ?? false,
                    applyStatus: cleanedOrUnknown(row.apply_status)
                )
            }
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_modern_ok rows=\(mapped.count)")
            return mapped
        }
    }

    func runCatalogEnrichmentDraftBatch(
        limit: Int = 20,
        debug: Bool = false
    ) async throws -> CatalogEnrichmentDraftBatchResult {
        try await instrumentedRequest(
            name: "runCatalogEnrichmentDraftBatch",
            metadata: "limit=\(limit),debug=\(debug)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print(
                    "[SEASON_CATALOG_ADMIN] phase=enrichment_batch_missing_access_token " +
                    "user_id=\(authenticatedUser.id.uuidString.lowercased()) error=\(error)"
                )
                throw SupabaseServiceError.unauthenticated
            }

            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            let safeLimit = max(1, min(100, limit))
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_batch_invoke_started limit=\(safeLimit) debug=\(debug)")

            supabaseClient.functions.setAuth(token: accessToken)
            let response: CloudCatalogEnrichmentDraftBatchResponse = try await supabaseClient.functions.invoke(
                "run-catalog-enrichment-draft-batch",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(accessToken)",
                        "apikey": anonKey
                    ],
                    body: CatalogEnrichmentBatchRequest(
                        limit: safeLimit,
                        debug: debug
                    )
                )
            )

            let summary = CatalogEnrichmentDraftBatchSummary(
                total: response.summary?.total ?? 0,
                succeeded: response.summary?.succeeded ?? 0,
                failed: response.summary?.failed ?? 0,
                skipped: response.summary?.skipped ?? 0,
                ready: response.summary?.ready ?? 0,
                pending: response.summary?.pending ?? 0
            )
            let items: [CatalogEnrichmentDraftBatchItemResult] = (response.items ?? []).map { row in
                CatalogEnrichmentDraftBatchItemResult(
                    normalizedText: cleanedOptional(row.normalized_text) ?? "",
                    resultStatus: cleanedOrUnknown(row.result_status),
                    detail: cleanedOptional(row.detail) ?? "",
                    errorMessage: cleanedOptional(row.error_message),
                    validationErrors: row.validation_errors ?? [],
                    validationPassed: row.validation_passed ?? false,
                    finalStatus: cleanedOrUnknown(row.final_status)
                )
            }

            let result = CatalogEnrichmentDraftBatchResult(
                summary: summary,
                items: items,
                mode: cleanedOptional(response.metadata?.mode) ?? "unknown"
            )

            print(
                "[SEASON_CATALOG_ADMIN] phase=enrichment_batch_invoke_ok " +
                "total=\(summary.total) succeeded=\(summary.succeeded) " +
                "failed=\(summary.failed) skipped=\(summary.skipped) ready=\(summary.ready)"
            )
            if summary.failed > 0 {
                for item in items where item.resultStatus == "failed" {
                    print(
                        "[SEASON_CATALOG_ADMIN] phase=enrichment_batch_item_failed " +
                        "normalized_text=\(item.normalizedText) error=\(item.errorMessage ?? "unknown_error")"
                    )
                }
            }

            return result
        }
    }

    func runCatalogIngredientCreationBatch(limit: Int = 20) async throws -> CatalogIngredientCreationBatchResult {
        try await instrumentedRequest(name: "runCatalogIngredientCreationBatch", metadata: "limit=\(limit)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print(
                    "[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_missing_access_token " +
                    "user_id=\(authenticatedUser.id.uuidString.lowercased()) error=\(error)"
                )
                throw SupabaseServiceError.unauthenticated
            }

            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            let safeLimit = max(1, min(100, limit))
            print("[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_invoke_started limit=\(safeLimit)")

            supabaseClient.functions.setAuth(token: accessToken)
            let response: CloudCatalogIngredientCreationBatchResponse = try await supabaseClient.functions.invoke(
                "run-catalog-ingredient-creation-batch",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(accessToken)",
                        "apikey": anonKey
                    ],
                    body: ["limit": safeLimit]
                )
            )

            let summary = CatalogIngredientCreationBatchSummary(
                total: response.summary?.total ?? 0,
                created: response.summary?.created ?? 0,
                skippedExisting: response.summary?.skipped_existing ?? 0,
                skippedInvalid: response.summary?.skipped_invalid ?? 0,
                failed: response.summary?.failed ?? 0
            )

            let items: [CatalogIngredientCreationBatchItemResult] = (response.items ?? []).map { row in
                CatalogIngredientCreationBatchItemResult(
                    normalizedText: cleanedOptional(row.normalized_text) ?? "",
                    slug: cleanedOptional(row.slug),
                    resultStatus: cleanedOrUnknown(row.result_status),
                    detail: cleanedOptional(row.detail) ?? "",
                    ingredientID: cleanedOptional(row.ingredient_id)?.lowercased(),
                    errorMessage: cleanedOptional(row.error_message)
                )
            }

            let result = CatalogIngredientCreationBatchResult(
                summary: summary,
                items: items,
                mode: cleanedOptional(response.metadata?.mode) ?? "unknown"
            )

            print(
                "[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_invoke_ok " +
                "total=\(summary.total) created=\(summary.created) " +
                "skipped_existing=\(summary.skippedExisting) skipped_invalid=\(summary.skippedInvalid) failed=\(summary.failed)"
            )

            if summary.failed > 0 {
                for item in items where item.resultStatus == "failed" {
                    print(
                        "[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_item_failed " +
                        "normalized_text=\(item.normalizedText) error=\(item.errorMessage ?? "unknown_error")"
                    )
                }
            }

            return result
        }
    }

    func runCatalogAutomationCycle(
        recoveryLimit: Int = 1000,
        enrichLimit: Int = 20,
        createLimit: Int = 20,
        debug: Bool = false
    ) async throws -> CatalogAutomationCycleResult {
        try await instrumentedRequest(
            name: "runCatalogAutomationCycle",
            metadata: "recovery=\(recoveryLimit),enrich=\(enrichLimit),create=\(createLimit),debug=\(debug)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print(
                    "[SEASON_CATALOG_ADMIN] phase=automation_cycle_missing_access_token " +
                    "user_id=\(authenticatedUser.id.uuidString.lowercased()) error=\(error)"
                )
                throw SupabaseServiceError.unauthenticated
            }

            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            let safeRecoveryLimit = max(1, min(5000, recoveryLimit))
            let safeEnrichLimit = max(1, min(100, enrichLimit))
            let safeCreateLimit = max(1, min(100, createLimit))
            print(
                "[SEASON_CATALOG_ADMIN] phase=automation_cycle_invoke_started " +
                "recovery_limit=\(safeRecoveryLimit) enrich_limit=\(safeEnrichLimit) create_limit=\(safeCreateLimit) debug=\(debug)"
            )

            supabaseClient.functions.setAuth(token: accessToken)
            let response: CloudCatalogAutomationCycleResponse = try await supabaseClient.functions.invoke(
                "run-catalog-automation-cycle",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(accessToken)",
                        "apikey": anonKey
                    ],
                    body: CatalogAutomationCycleRequest(
                        recovery_limit: safeRecoveryLimit,
                        enrich_limit: safeEnrichLimit,
                        create_limit: safeCreateLimit,
                        debug: debug
                    )
                )
            )

            let recovery = CatalogAutomationCycleRecoverySummary(
                total: response.summary?.recovery?.total ?? 0,
                observed: response.summary?.recovery?.observed ?? 0,
                skipped: response.summary?.recovery?.skipped ?? 0,
                failed: response.summary?.recovery?.failed ?? 0,
                status: cleanedOptional(response.summary?.recovery?.status) ?? "failed",
                error: cleanedOptional(response.summary?.recovery?.error)
            )
            let enrichment = CatalogAutomationCycleEnrichmentSummary(
                total: response.summary?.enrichment?.total ?? 0,
                succeeded: response.summary?.enrichment?.succeeded ?? 0,
                failed: response.summary?.enrichment?.failed ?? 0,
                skipped: response.summary?.enrichment?.skipped ?? 0,
                ready: response.summary?.enrichment?.ready ?? 0,
                status: cleanedOptional(response.summary?.enrichment?.status) ?? "failed",
                error: cleanedOptional(response.summary?.enrichment?.error)
            )
            let creation = CatalogAutomationCycleCreationSummary(
                total: response.summary?.creation?.total ?? 0,
                created: response.summary?.creation?.created ?? 0,
                skippedExisting: response.summary?.creation?.skipped_existing ?? 0,
                skippedInvalid: response.summary?.creation?.skipped_invalid ?? 0,
                failed: response.summary?.creation?.failed ?? 0,
                status: cleanedOptional(response.summary?.creation?.status) ?? "failed",
                error: cleanedOptional(response.summary?.creation?.error)
            )

            let result = CatalogAutomationCycleResult(
                recovery: recovery,
                enrichment: enrichment,
                creation: creation,
                mode: cleanedOptional(response.metadata?.mode) ?? "unknown"
            )

            print(
                "[SEASON_CATALOG_ADMIN] phase=automation_cycle_invoke_ok " +
                "recovery_total=\(recovery.total) recovery_failed=\(recovery.failed) " +
                "enrichment_total=\(enrichment.total) enrichment_failed=\(enrichment.failed) " +
                "creation_total=\(creation.total) creation_failed=\(creation.failed)"
            )

            return result
        }
    }

    func fetchCatalogResolutionCandidates(limit: Int = 50) async -> [CatalogResolutionCandidateRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_DEBUG] phase=candidate_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("catalog_resolution_candidate_queue")
                .select("normalized_text,occurrence_count,suggested_resolution_type,existing_alias_status,priority_score")
                .order("priority_score", ascending: false)
                .order("occurrence_count", ascending: false)
                .order("normalized_text", ascending: true)
                .limit(max(1, limit))
                .execute()

            let rows = try JSONDecoder().decode([CloudCatalogResolutionCandidateRow].self, from: response.data)
            let mapped = mapCatalogResolutionCandidates(rows)

            print("[SEASON_CATALOG_DEBUG] phase=candidate_fetch_ok count=\(mapped.count)")
            return mapped
        } catch {
            print("[SEASON_CATALOG_DEBUG] phase=candidate_fetch_failed error=\(error)")
            return []
        }
    }

    func fetchCatalogCoverageBlockers(
        limit: Int = 50,
        focusAliasLocalization: Bool = true
    ) async -> [CatalogCoverageBlockerRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_DEBUG] phase=coverage_blocker_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, limit)),
                "p_focus_alias_localization": .bool(focusAliasLocalization)
            ]
            let response = try await supabaseClient
                .rpc(
                    "top_catalog_coverage_blockers",
                    params: params
                )
                .execute()

            let rows = try JSONDecoder().decode([CloudCatalogCoverageBlockerRow].self, from: response.data)
            let mapped = mapCatalogCoverageBlockers(rows)

            print("[SEASON_CATALOG_DEBUG] phase=coverage_blocker_fetch_ok count=\(mapped.count)")
            return mapped
        } catch {
            print("[SEASON_CATALOG_DEBUG] phase=coverage_blocker_fetch_failed error=\(error)")
            return []
        }
    }

    func fetchPendingCatalogEnrichmentDraftReview(
        limit: Int = 200
    ) async -> [PendingCatalogEnrichmentDraftReviewRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_ADMIN] phase=pending_draft_review_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .rpc("review_pending_catalog_enrichment_drafts", params: ["p_limit": max(1, limit)])
                .execute()

            let rows = try JSONDecoder().decode([CloudPendingCatalogEnrichmentDraftReviewRow].self, from: response.data)
            let mapped = mapPendingCatalogEnrichmentDraftReview(rows)
            print("[SEASON_CATALOG_ADMIN] phase=pending_draft_review_fetch_ok count=\(mapped.count)")
            return mapped
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=pending_draft_review_fetch_failed error=\(error)")
            return []
        }
    }

    func fetchCatalogIngredientHierarchy(
        limit: Int = 200
    ) async -> [CatalogIngredientHierarchyRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_ADMIN] phase=ingredient_hierarchy_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let params: [String: AnyJSON] = [
                "p_limit": .integer(max(1, min(limit, 500)))
            ]
            let response = try await supabaseClient
                .rpc("list_catalog_ingredient_hierarchy", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudCatalogIngredientHierarchyRow].self, from: response.data)
            let mapped = mapCatalogIngredientHierarchy(rows)
            print("[SEASON_CATALOG_ADMIN] phase=ingredient_hierarchy_fetch_ok count=\(mapped.count)")
            return mapped
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=ingredient_hierarchy_fetch_failed error=\(error)")
            return []
        }
    }

    func approveCatalogAlias(normalizedText: String, ingredientID: String) async throws {
        try await instrumentedRequest(name: "approveCatalogAlias", metadata: "normalized_text=\(normalizedText)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let targetIngredientID = ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !targetIngredientID.isEmpty else { return }

            print("[SEASON_CATALOG_ADMIN] phase=approve_alias_started normalized_text=\(normalized) ingredient_id=\(targetIngredientID)")
            let payload: [String: String] = [
                "p_normalized_text": normalized,
                "p_ingredient_id": targetIngredientID
            ]

            _ = try await supabaseClient
                .rpc("approve_reconciliation_alias", params: payload)
                .execute()

            print("[SEASON_CATALOG_ADMIN] phase=approve_alias_succeeded normalized_text=\(normalized) ingredient_id=\(targetIngredientID)")
        }
    }

    func addIngredientLocalization(
        ingredientID: String,
        text: String,
        languageCode: String
    ) async throws -> String {
        try await instrumentedRequest(name: "addIngredientLocalization", metadata: "ingredient_id=\(ingredientID)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let cleanedIngredientID = ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedLanguageCode = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleanedIngredientID.isEmpty, !cleanedText.isEmpty else {
                throw SupabaseServiceError.missingConfiguration("ingredient_id/text")
            }

            let payload: [String: String] = [
                "p_ingredient_id": cleanedIngredientID,
                "p_text": cleanedText,
                "p_language_code": cleanedLanguageCode.isEmpty ? "it" : cleanedLanguageCode
            ]

            let response = try await supabaseClient
                .rpc("add_ingredient_localization", params: payload)
                .execute()
            let rows = try JSONDecoder().decode([CloudAddIngredientLocalizationRow].self, from: response.data)
            let status = rows.first?.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
            let applied = rows.first?.applied ?? false

            print("[SEASON_CATALOG_ADMIN] phase=add_localization_result ingredient_id=\(cleanedIngredientID) status=\(status) applied=\(applied)")
            return status
        }
    }

    func fetchReadyCatalogEnrichmentDrafts(limit: Int = 50) async -> [ReadyCatalogEnrichmentDraftRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_ADMIN] phase=ready_enrichment_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .rpc("list_ready_catalog_enrichment_drafts", params: ["limit_count": max(1, limit)])
                .execute()

            let rows = try JSONDecoder().decode([CloudReadyCatalogEnrichmentDraftRow].self, from: response.data)
            let mapped = mapReadyCatalogEnrichmentDrafts(rows)

            let sorted = mapped.sorted { lhs, rhs in
                switch (lhs.updatedAt, rhs.updatedAt) {
                case let (left?, right?) where left != right:
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    break
                }
                return lhs.normalizedText < rhs.normalizedText
            }
            print("[SEASON_CATALOG_ADMIN] phase=ready_enrichment_fetch_ok count=\(sorted.count)")
            return sorted
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=ready_enrichment_fetch_failed error=\(error)")
            return []
        }
    }

    func createCatalogIngredientFromEnrichmentDraft(normalizedText: String) async throws {
        try await instrumentedRequest(name: "createCatalogIngredientFromEnrichmentDraft", metadata: "normalized_text=\(normalizedText)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return }

            print("[SEASON_CATALOG_ADMIN] phase=create_from_enrichment_started normalized_text=\(normalized)")
            _ = try await supabaseClient
                .rpc("create_catalog_ingredient_from_enrichment_draft", params: ["p_normalized_text": normalized])
                .execute()
            print("[SEASON_CATALOG_ADMIN] phase=create_from_enrichment_succeeded normalized_text=\(normalized)")
        }
    }

    func fetchCatalogEnrichmentDraft(normalizedText: String) async -> CatalogEnrichmentDraftRecord? {
        guard let supabaseClient = self.client else {
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_draft_fetch_failed reason=missing_configuration")
            return nil
        }
        let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        do {
            let response = try await supabaseClient
                .rpc("get_catalog_ingredient_enrichment_draft", params: ["p_normalized_text": normalized])
                .execute()
            let rows = try JSONDecoder().decode([CloudCatalogEnrichmentDraftRow].self, from: response.data)
            guard let row = rows.first else { return nil }
            let iso8601 = ISO8601DateFormatter()
            let mapped = CatalogEnrichmentDraftRecord(
                normalizedText: row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? normalized,
                status: row.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "pending",
                ingredientType: row.ingredient_type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown",
                canonicalNameIT: row.canonical_name_it?.trimmingCharacters(in: .whitespacesAndNewlines),
                canonicalNameEN: row.canonical_name_en?.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedSlug: row.suggested_slug?.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedAliases: row.suggested_aliases ?? [],
                defaultUnit: row.default_unit?.trimmingCharacters(in: .whitespacesAndNewlines),
                supportedUnits: row.supported_units ?? [],
                isSeasonal: row.is_seasonal,
                seasonMonths: row.season_months ?? [],
                confidenceScore: row.confidence_score,
                needsManualReview: row.needs_manual_review ?? true,
                reasoningSummary: row.reasoning_summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                reviewerNote: row.reviewer_note?.trimmingCharacters(in: .whitespacesAndNewlines),
                validatedReady: row.validated_ready ?? false,
                validationErrors: row.validation_errors ?? [],
                updatedAt: row.updated_at.flatMap { iso8601.date(from: $0) }
            )
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_draft_fetch_ok normalized_text=\(normalized) status=\(mapped.status)")
            return mapped
        } catch {
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_draft_fetch_failed normalized_text=\(normalized) error=\(error)")
            return nil
        }
    }

    func upsertCatalogEnrichmentDraft(
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
        try await instrumentedRequest(name: "upsertCatalogEnrichmentDraft", metadata: "normalized_text=\(normalizedText)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else {
                throw SupabaseServiceError.missingConfiguration("normalized_text")
            }
            let canonicalNameITValue = canonicalNameIT?.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonicalNameENValue = canonicalNameEN?.trimmingCharacters(in: .whitespacesAndNewlines)
            let suggestedSlugValue = suggestedSlug?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let defaultUnitValue = defaultUnit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let reasoningSummaryValue = reasoningSummary?.trimmingCharacters(in: .whitespacesAndNewlines)

            let canonicalNameITJSON: AnyJSON = (canonicalNameITValue?.isEmpty == false) ? .string(canonicalNameITValue!) : .null
            let canonicalNameENJSON: AnyJSON = (canonicalNameENValue?.isEmpty == false) ? .string(canonicalNameENValue!) : .null
            let suggestedSlugJSON: AnyJSON = (suggestedSlugValue?.isEmpty == false) ? .string(suggestedSlugValue!) : .null
            let defaultUnitJSON: AnyJSON = (defaultUnitValue?.isEmpty == false) ? .string(defaultUnitValue!) : .null
            let reasoningSummaryJSON: AnyJSON = (reasoningSummaryValue?.isEmpty == false) ? .string(reasoningSummaryValue!) : .null

            let params: [String: AnyJSON] = [
                "p_normalized_text": .string(normalized),
                "p_status": .string(status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
                "p_ingredient_type": .string(ingredientType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
                "p_canonical_name_it": canonicalNameITJSON,
                "p_canonical_name_en": canonicalNameENJSON,
                "p_suggested_slug": suggestedSlugJSON,
                "p_default_unit": defaultUnitJSON,
                "p_supported_units": .array(supportedUnits.map { .string($0) }),
                "p_is_seasonal": isSeasonal.map { .bool($0) } ?? .null,
                "p_season_months": .array(seasonMonths.map { .integer($0) }),
                "p_confidence_score": confidenceScore.map { .double($0) } ?? .null,
                "p_needs_manual_review": .bool(needsManualReview),
                "p_reasoning_summary": reasoningSummaryJSON,
                "p_reviewer_note": .null
            ]

            let response = try await supabaseClient
                .rpc("upsert_catalog_ingredient_enrichment_draft", params: params)
                .execute()
            let rows = try JSONDecoder().decode([CloudCatalogEnrichmentDraftMutationRow].self, from: response.data)
            guard let row = rows.first else {
                throw SupabaseServiceError.missingConfiguration("upsert_catalog_ingredient_enrichment_draft response")
            }

            let result = CatalogEnrichmentDraftMutationResult(
                normalizedText: row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? normalized,
                status: row.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? status.lowercased(),
                ingredientType: row.ingredient_type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ingredientType.lowercased(),
                validatedReady: row.validated_ready ?? row.is_ready ?? false,
                validationErrors: row.validation_errors ?? []
            )
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_draft_upsert_ok normalized_text=\(result.normalizedText) status=\(result.status) validated_ready=\(result.validatedReady)")
            return result
        }
    }

    func validateCatalogEnrichmentDraft(
        normalizedText: String
    ) async throws -> CatalogEnrichmentDraftMutationResult {
        try await instrumentedRequest(name: "validateCatalogEnrichmentDraft", metadata: "normalized_text=\(normalizedText)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }
            guard supabaseClient.auth.currentUser != nil else {
                throw SupabaseServiceError.unauthenticated
            }

            let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else {
                throw SupabaseServiceError.missingConfiguration("normalized_text")
            }

            let response = try await supabaseClient
                .rpc("validate_catalog_ingredient_enrichment_draft", params: ["p_normalized_text": normalized])
                .execute()
            let rows = try JSONDecoder().decode([CloudCatalogEnrichmentDraftMutationRow].self, from: response.data)
            guard let row = rows.first else {
                throw SupabaseServiceError.missingConfiguration("validate_catalog_ingredient_enrichment_draft response")
            }

            let result = CatalogEnrichmentDraftMutationResult(
                normalizedText: row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? normalized,
                status: row.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "pending",
                ingredientType: row.ingredient_type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown",
                validatedReady: row.validated_ready ?? row.is_ready ?? false,
                validationErrors: row.validation_errors ?? []
            )
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_draft_validate_ok normalized_text=\(result.normalizedText) validated_ready=\(result.validatedReady)")
            return result
        }
    }

    func createRecipe(_ recipe: Recipe) async throws {
        try await instrumentedRequest(name: "createRecipe", metadata: "recipe_id=\(recipe.id)") {
            try await recipeRepository.createRecipe(recipe)
            observeUnresolvedCustomIngredientsForRecipeIfNeeded(recipe)
        }
    }

    func fetchRecipes(limit: Int = 40, offset: Int = 0) async throws -> [Recipe] {
        try await instrumentedRequest(
            name: "fetchRecipes",
            metadata: "limit=\(limit) offset=\(offset)"
        ) {
            try await recipeRepository.fetchRecipes(limit: limit, offset: offset)
        }
    }

    func setRecipeSavedState(recipeID: String, isSaved: Bool, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=service_entered")
        try await instrumentedRequest(
            name: "setRecipeSavedState",
            traceID: traceID,
            metadata: "action=saved recipe=\(recipeID) target=\(isSaved)"
        ) {
            do {
                try await performWithRetry {
                    try await recipeRepository.upsertRecipeSavedState(recipeID: recipeID, isSaved: isSaved)
                }
                print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=write_ok")
            } catch {
                let category = classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func setRecipeCrispiedState(recipeID: String, isCrispied: Bool, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=service_entered")
        try await instrumentedRequest(
            name: "setRecipeCrispiedState",
            traceID: traceID,
            metadata: "action=crispied recipe=\(recipeID) target=\(isCrispied)"
        ) {
            do {
                try await performWithRetry {
                    try await recipeRepository.upsertRecipeCrispiedState(recipeID: recipeID, isCrispied: isCrispied)
                }
                print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=write_ok")
            } catch {
                let category = classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func createShoppingListItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?,
        isChecked: Bool,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "createShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_create item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let payload = ShoppingListItemInsertPayload(
                id: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString),
                user_id: user.id.uuidString,
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                source_recipe_id: sourceRecipeID,
                is_checked: isChecked,
                created_at: now,
                updated_at: now
            )

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .insert(payload)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func updateShoppingListItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?,
        isChecked: Bool,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "updateShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_update item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let payload = ShoppingListItemUpdatePayload(
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                source_recipe_id: sourceRecipeID,
                is_checked: isChecked,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .update(payload)
                    .eq("id", value: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func deleteShoppingListItem(localItemID: String, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "deleteShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_delete item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .delete()
                    .eq("id", value: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func createFridgeItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "createFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_create item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let payload = FridgeItemInsertPayload(
                id: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString),
                user_id: user.id.uuidString,
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                created_at: now,
                updated_at: now
            )

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .insert(payload)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_ok")
            } catch {
                if self.isDuplicateKeyPostgresError(error) {
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=duplicate_detected error=\(error)")
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=duplicate_fallback_update")

                    let fallbackPayload = FridgeItemUpdatePayload(
                        ingredient_type: ingredientType,
                        ingredient_id: ingredientID,
                        custom_name: customName,
                        quantity: quantity,
                        unit: unit,
                        updated_at: now
                    )

                    do {
                        _ = try await supabaseClient
                            .from("fridge_items")
                            .update(fallbackPayload)
                            .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                            .eq("user_id", value: user.id.uuidString)
                            .execute()
                        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_ok")
                    } catch {
                        let category = self.classifyNetworkError(error)
                        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                        throw error
                    }
                } else {
                    let category = self.classifyNetworkError(error)
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                    throw error
                }
            }
        }
    }

    func updateFridgeItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "updateFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_update item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let payload = FridgeItemUpdatePayload(
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .update(payload)
                    .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func deleteFridgeItem(localItemID: String, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "deleteFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_delete item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .delete()
                    .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    private func instrumentedRequest<T>(
        name: String,
        traceID: String? = nil,
        metadata: String? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let tracePart = traceID.map { " trace=\($0)" } ?? ""
        let metadataPart = metadata.map { " \($0)" } ?? ""
        print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_started")

        do {
            let result = try await operation()
            let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1000).rounded())
            print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_ok duration_ms=\(elapsedMs)")
            return result
        } catch {
            let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1000).rounded())
            let category = classifyNetworkError(error)
            print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_failed duration_ms=\(elapsedMs) category=\(category.rawValue) error=\(error)")
            throw error
        }
    }

    private func performWithRetry(
        operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch {
            if isTransientNetworkError(error) {
                print("[SEASON_SUPABASE] retrying operation after transient error...")
                try await Task.sleep(nanoseconds: 300_000_000)
                try await operation()
            } else {
                throw error
            }
        }
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            (nsError.code == -1005 ||
             nsError.code == -1001 ||
             nsError.code == -1009)
    }

    private func classifyNetworkError(_ error: Error) -> NetworkErrorCategory {
        if let serviceError = error as? SupabaseServiceError {
            switch serviceError {
            case .unauthenticated:
                return .auth_session
            case .missingConfiguration, .invalidURL:
                return .client_validation
            case .requestTimedOut:
                return .network_offline
            }
        }

        if error is DecodingError || error is EncodingError {
            return .client_validation
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case -1009, -1005, -1001:
                return .network_offline
            default:
                break
            }
        }

        if let statusCode = extractHTTPStatusCode(from: nsError) {
            switch statusCode {
            case 401:
                return .auth_session
            case 403:
                return .permission_rls
            case 429:
                return .rate_limit
            case 500...599:
                return .server_error
            case 400...499:
                return .client_validation
            default:
                break
            }
        }

        let message = [
            nsError.localizedDescription,
            String(describing: error)
        ]
        .joined(separator: " ")
        .lowercased()

        if message.contains("rls") ||
            message.contains("permission denied") ||
            message.contains("forbidden") {
            return .permission_rls
        }
        if message.contains("unauthorized") ||
            message.contains("jwt") ||
            message.contains("session") ||
            message.contains("not authenticated") {
            return .auth_session
        }
        if message.contains("rate limit") ||
            message.contains("too many requests") {
            return .rate_limit
        }
        if message.contains("offline") ||
            message.contains("timed out") ||
            message.contains("timeout") ||
            message.contains("connection lost") {
            return .network_offline
        }
        if message.contains("decode") ||
            message.contains("encoding") ||
            message.contains("invalid") ||
            message.contains("missing") {
            return .client_validation
        }

        return .unknown
    }

    private func extractHTTPStatusCode(from error: NSError) -> Int? {
        let keys = ["status", "statusCode", "StatusCode", "code"]
        for key in keys {
            if let value = error.userInfo[key] as? Int, (100...599).contains(value) {
                return value
            }
            if let value = error.userInfo[key] as? NSNumber {
                let intValue = value.intValue
                if (100...599).contains(intValue) {
                    return intValue
                }
            }
            if let value = error.userInfo[key] as? String, let intValue = Int(value), (100...599).contains(intValue) {
                return intValue
            }
        }

        if let response = error.userInfo["response"] as? HTTPURLResponse {
            return response.statusCode
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return extractHTTPStatusCode(from: underlying)
        }

        return nil
    }

    private func isDuplicateKeyPostgresError(_ error: Error) -> Bool {
        if let code = extractPostgresErrorCode(from: error), code == "23505" {
            return true
        }

        let message = String(describing: error).lowercased()
        return message.contains("23505") &&
            message.contains("duplicate key")
    }

    private func extractPostgresErrorCode(from error: Error) -> String? {
        let nsError = error as NSError
        let keys = ["code", "sqlState", "sqlstate", "postgresCode", "PostgresCode", "pgcode"]

        for key in keys {
            if let value = nsError.userInfo[key] as? String, !value.isEmpty {
                return value
            }
            if let value = nsError.userInfo[key] as? NSNumber {
                return value.stringValue
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return extractPostgresErrorCode(from: underlying)
        }

        return nil
    }

    private func isMissingColumnError(_ error: Error, column: String) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("pgrst204") || (message.contains(column.lowercased()) && message.contains("column"))
    }

    private func isMissingAnyColumnError(_ error: Error, columns: [String]) -> Bool {
        columns.contains { isMissingColumnError(error, column: $0) }
    }

    private func isMissingFollowsTableError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("follows") &&
            message.contains("does not exist")
    }

    private func isMissingIngredientAliasesTableError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_aliases") &&
            message.contains("does not exist")
    }

    private func isMissingUnifiedIngredientSummaryRelationError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_catalog_summary") &&
            message.contains("does not exist")
    }

    private func isMissingUnifiedIngredientAliasesRelationError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_aliases_v2") &&
            message.contains("does not exist")
    }

    private func normalizeFollowID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func shoppingListRowID(localItemID: String, userID: String) -> String {
        deterministicUUIDString(from: "shopping_list_item|\(userID)|\(localItemID)")
    }

    private func fridgeRowID(localItemID: String, userID: String) -> String {
        deterministicUUIDString(from: "fridge_item|\(userID)|\(localItemID)")
    }

    private func deterministicUUIDString(from input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple).uuidString.lowercased()
    }

    private func notifyAuthStateDidChange() {
        NotificationCenter.default.post(name: .seasonAuthStateDidChange, object: nil)
    }

    private func mapCatalogResolutionCandidates(
        _ rows: [CloudCatalogResolutionCandidateRow]
    ) -> [CatalogResolutionCandidateRecord] {
        rows.compactMap { row -> CatalogResolutionCandidateRecord? in
            let normalizedText = row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !normalizedText.isEmpty else { return nil }
            return CatalogResolutionCandidateRecord(
                normalizedText: normalizedText,
                occurrenceCount: max(0, row.occurrence_count ?? 0),
                suggestedResolutionType: (row.suggested_resolution_type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? row.suggested_resolution_type!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : "unknown",
                existingAliasStatus: (row.existing_alias_status?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? row.existing_alias_status!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : "none",
                priorityScore: row.priority_score,
                canonicalParentExists: row.canonical_parent_exists ?? false,
                closeCanonicalChildExists: row.close_canonical_child_exists ?? false,
                possibleActions: (row.possible_actions ?? []).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }.filter { !$0.isEmpty },
                confidence: cleanedOptional(row.confidence)?.lowercased() ?? "low",
                suggestedParentSlug: cleanedOptional(row.suggested_parent_slug),
                reasoningHint: cleanedOptional(row.reasoning_hint)
            )
        }
    }

    private func mapCatalogCoverageBlockers(
        _ rows: [CloudCatalogCoverageBlockerRow]
    ) -> [CatalogCoverageBlockerRecord] {
        rows.compactMap { row -> CatalogCoverageBlockerRecord? in
            let normalizedText = row.normalized_text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            guard !normalizedText.isEmpty else { return nil }
            return CatalogCoverageBlockerRecord(
                normalizedText: normalizedText,
                rowCount: max(0, row.row_count ?? 0),
                recipeCount: max(0, row.recipe_count ?? 0),
                occurrenceCount: max(0, row.occurrence_count ?? 0),
                priorityScore: row.priority_score,
                likelyFixType: cleanedOrUnknown(row.likely_fix_type),
                canonicalCandidateIngredientID: cleanedOptional(row.canonical_candidate_ingredient_id),
                canonicalCandidateSlug: cleanedOptional(row.canonical_candidate_slug),
                canonicalCandidateName: cleanedOptional(row.canonical_candidate_name),
                canonicalCandidateParentSlug: cleanedOptional(row.canonical_candidate_parent_slug),
                canonicalCandidateIsChild: row.canonical_candidate_is_child ?? false,
                canonicalCandidateIsRoot: row.canonical_candidate_is_root ?? false,
                genericParentExists: row.generic_parent_exists ?? false,
                suggestedResolutionType: cleanedOrUnknown(row.suggested_resolution_type),
                blockerReason: cleanedOrUnknown(row.blocker_reason),
                recommendedNextAction: cleanedOrUnknown(row.recommended_next_action)
            )
        }
    }

    private func mapReadyCatalogEnrichmentDrafts(
        _ rows: [CloudReadyCatalogEnrichmentDraftRow]
    ) -> [ReadyCatalogEnrichmentDraftRecord] {
        let iso8601 = ISO8601DateFormatter()
        return rows.compactMap { row -> ReadyCatalogEnrichmentDraftRecord? in
            let normalizedText = row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard !normalizedText.isEmpty else { return nil }
            let ingredientType = row.ingredient_type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
            return ReadyCatalogEnrichmentDraftRecord(
                normalizedText: normalizedText,
                ingredientType: ingredientType,
                canonicalNameIT: row.canonical_name_it?.trimmingCharacters(in: .whitespacesAndNewlines),
                canonicalNameEN: row.canonical_name_en?.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedSlug: row.suggested_slug?.trimmingCharacters(in: .whitespacesAndNewlines),
                confidenceScore: row.confidence_score,
                needsManualReview: row.needs_manual_review ?? true,
                updatedAt: row.updated_at.flatMap { iso8601.date(from: $0) }
            )
        }
    }

    private func mapCatalogObservationCoverage(
        _ rows: [CloudCatalogObservationCoverageRow]
    ) -> [CatalogObservationCoverageRecord] {
        let iso8601 = ISO8601DateFormatter()
        return rows.compactMap { row -> CatalogObservationCoverageRecord? in
            let normalizedText = row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard !normalizedText.isEmpty else { return nil }
            return CatalogObservationCoverageRecord(
                normalizedText: normalizedText,
                observationStatus: cleanedOrUnknown(row.observation_status),
                occurrenceCount: max(0, row.occurrence_count ?? 0),
                lastSeenAt: row.last_seen_at.flatMap { iso8601.date(from: $0) },
                coverageState: cleanedOrUnknown(row.coverage_state),
                coverageReason: cleanedOrUnknown(row.coverage_reason),
                canonicalTargetIngredientID: cleanedOptional(row.canonical_target_ingredient_id),
                canonicalTargetSlug: cleanedOptional(row.canonical_target_slug),
                canonicalTargetName: cleanedOptional(row.canonical_target_name),
                aliasTargetIngredientID: cleanedOptional(row.alias_target_ingredient_id),
                aliasTargetSlug: cleanedOptional(row.alias_target_slug),
                aliasTargetName: cleanedOptional(row.alias_target_name)
            )
        }
    }

    private func mapPendingCatalogEnrichmentDraftReview(
        _ rows: [CloudPendingCatalogEnrichmentDraftReviewRow]
    ) -> [PendingCatalogEnrichmentDraftReviewRecord] {
        let iso8601 = ISO8601DateFormatter()
        return rows.compactMap { row -> PendingCatalogEnrichmentDraftReviewRecord? in
            let normalizedText = row.normalized_text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard !normalizedText.isEmpty else { return nil }
            return PendingCatalogEnrichmentDraftReviewRecord(
                normalizedText: normalizedText,
                occurrenceCount: max(0, row.occurrence_count ?? 0),
                draftUpdatedAt: row.draft_updated_at.flatMap { iso8601.date(from: $0) },
                reviewBucket: cleanedOrUnknown(row.review_bucket),
                classificationReason: cleanedOrUnknown(row.classification_reason),
                hasApprovedAlias: row.has_approved_alias ?? false,
                hasAnyAliasMatch: row.has_any_alias_match ?? false,
                canonicalMatchCount: max(0, row.canonical_match_count ?? 0),
                quantityContaminated: row.quantity_contaminated ?? false,
                lowRiskQualifier: row.low_risk_qualifier ?? false,
                descriptorAliasLike: row.descriptor_alias_like ?? false,
                isPastaShape: row.is_pasta_shape ?? false,
                recommendedOperatorAction: cleanedOrUnknown(row.recommended_operator_action)
            )
        }
    }

    private func mapCatalogIngredientHierarchy(
        _ rows: [CloudCatalogIngredientHierarchyRow]
    ) -> [CatalogIngredientHierarchyRecord] {
        rows.compactMap { row -> CatalogIngredientHierarchyRecord? in
            let ingredientID = row.ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let ingredientSlug = row.ingredient_slug?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard !ingredientID.isEmpty, !ingredientSlug.isEmpty else { return nil }
            return CatalogIngredientHierarchyRecord(
                ingredientID: ingredientID,
                ingredientSlug: ingredientSlug,
                parentIngredientID: cleanedOptional(row.parent_ingredient_id)?.lowercased(),
                parentSlug: cleanedOptional(row.parent_slug)?.lowercased(),
                ingredientType: cleanedOrUnknown(row.ingredient_type),
                specificityRank: max(0, row.specificity_rank ?? 0),
                variantKind: cleanedOrUnknown(row.variant_kind)
            )
        }
    }

    private func decodeRPCBoolean(_ data: Data, key: String) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return false
        }

        if let number = json as? NSNumber {
            return number.boolValue
        }
        if let boolValue = json as? Bool {
            return boolValue
        }
        if let textValue = json as? String {
            let normalized = textValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "true" || normalized == "t" || normalized == "1"
        }
        if let dict = json as? [String: Any], let boolValue = dict[key] as? Bool {
            return boolValue
        }
        if let dict = json as? [String: Any], let number = dict[key] as? NSNumber {
            return number.boolValue
        }
        if let dict = json as? [String: Any], let textValue = dict[key] as? String {
            let normalized = textValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "true" || normalized == "t" || normalized == "1"
        }
        if let array = json as? [Any], let first = array.first {
            if let number = first as? NSNumber {
                return number.boolValue
            }
            if let boolValue = first as? Bool {
                return boolValue
            }
            if let textValue = first as? String {
                let normalized = textValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalized == "true" || normalized == "t" || normalized == "1"
            }
            if let dict = first as? [String: Any], let boolValue = dict[key] as? Bool {
                return boolValue
            }
            if let dict = first as? [String: Any], let number = dict[key] as? NSNumber {
                return number.boolValue
            }
            if let dict = first as? [String: Any], let textValue = dict[key] as? String {
                let normalized = textValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalized == "true" || normalized == "t" || normalized == "1"
            }
        }

        return false
    }

    private func describeRPCPayload(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            let raw = String(data: data, encoding: .utf8) ?? "<non_utf8>"
            return "type=parse_failed value=\(raw)"
        }
        return "type=\(type(of: json)) value=\(json)"
    }

    private func cleanedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func cleanedOrUnknown(_ value: String?) -> String {
        cleanedOptional(value) ?? "unknown"
    }

    private static func loadConfiguration(from bundle: Bundle) throws -> SupabaseConfiguration {
        let urlString = firstInfoPlistString(
            in: bundle,
            keys: ["SUPABASE_URL", "SupabaseURL", "supabase_url"]
        )
        let key = firstInfoPlistString(
            in: bundle,
            keys: ["SUPABASE_ANON_KEY", "SupabaseAnonKey", "supabase_anon_key"]
        )

        let normalizedURLString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedKey = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !normalizedURLString.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("SUPABASE_URL")
        }

        guard !normalizedKey.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
        }

        guard let url = URL(string: normalizedURLString) else {
            throw SupabaseServiceError.invalidURL
        }

        return SupabaseConfiguration(url: url, anonKey: normalizedKey)
    }

    private static func firstInfoPlistString(in bundle: Bundle, keys: [String]) -> String? {
        for key in keys {
            if let value = bundle.object(forInfoDictionaryKey: key) as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }

            if let value = bundle.infoDictionary?[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
