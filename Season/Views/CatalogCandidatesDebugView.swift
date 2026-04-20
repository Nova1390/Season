import SwiftUI

struct CatalogCandidatesDebugView: View {
    private struct MetricCardView: View {
        let value: String
        let label: String
        let icon: String
        let tint: Color
        @State private var hasAppeared = false

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(hasAppeared ? 1 : 0.96)
            .opacity(hasAppeared ? 1 : 0.7)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    hasAppeared = true
                }
            }
        }
    }

    private struct ApprovalRoute: Identifiable {
        let candidate: CatalogResolutionCandidateRecord
        var id: String { candidate.id }
    }

    private struct EnrichmentRoute: Identifiable {
        let candidate: CatalogResolutionCandidateRecord
        var id: String { candidate.id }
    }

    private struct BulkAliasRoute: Identifiable {
        let candidates: [CatalogResolutionCandidateRecord]
        var id: String { candidates.map(\.id).sorted().joined(separator: ",") }
    }

    private struct SemanticAutomationAnomaly: Identifiable {
        let id: String
        let normalizedText: String
        let title: String
        let message: String
    }

    @State private var items: [CatalogResolutionCandidateRecord] = []
    @State private var coverageBlockers: [CatalogCoverageBlockerRecord] = []
    @State private var readyEnrichmentDrafts: [ReadyCatalogEnrichmentDraftRecord] = []
    @State private var observationCoverage: [CatalogObservationCoverageRecord] = []
    @State private var ingredientHierarchyRows: [CatalogIngredientHierarchyRecord] = []
    @State private var pendingDraftReviewRows: [PendingCatalogEnrichmentDraftReviewRecord] = []
    @State private var unifiedIngredients: [UnifiedIngredientCatalogSummaryRecord] = []
    @State private var isLoading = false
    @State private var isApproving = false
    @State private var isSelectionMode = false
    @State private var creatingDraftNormalizedText: String?
    @State private var isAdminUser = false
    @State private var errorMessage = ""
    @State private var actionMessage = ""
    @State private var selectedIngredientID: String?
    @State private var ingredientSearchQuery = ""
    @State private var selectedCandidateIDs: Set<String> = []
    @State private var selectedCoverageBlockerIDs: Set<String> = []
    @State private var bulkSelectedIngredientID: String?
    @State private var bulkIngredientSearchQuery = ""
    @State private var approvalRoute: ApprovalRoute?
    @State private var enrichmentRoute: EnrichmentRoute?
    @State private var bulkAliasRoute: BulkAliasRoute?
    @State private var importURL = ""
    @State private var isParsingURLImport = false
    @State private var isSavingImportedRecipe = false
    @State private var importedRecipePreview: ImportedRecipePreview?
    @State private var lastSavedImportedRecipe: Recipe?
    @State private var isRunningCuratedBatch = false
    @State private var runningBatchName: String?
    @State private var isRunningObservationRecovery = false
    @State private var isRunningEnrichmentBatch = false
    @State private var isRunningIngredientCreationBatch = false
    @State private var isRunningAutoAlias = false
    @State private var isRunningAutoLocalization = false
    @State private var isRunningAutomationCycle = false
    @State private var isRunningReconciliationPreview = false
    @State private var isRunningReconciliationApply = false
    @State private var isRunningModernReconciliationApply = false
    @State private var isAdvancedDebugExpanded = false
    @State private var lastAutomationRun: CatalogAutomationCycleRunSummary?
    @State private var reconciliationPreviewRows: [RecipeIngredientReconciliationPreviewRow] = []
    @State private var lastReconciliationApplySummary: CatalogSafeRecipeReconciliationApplySummary?
    @State private var lastModernReconciliationApplySummary: CatalogSafeRecipeReconciliationApplySummary?
    @State private var lastAutoAliasSummary: CatalogAutoAliasRunSummary?
    @State private var lastAutoLocalizationSummary: CatalogAutoLocalizationRunSummary?
    @State private var showAutomationSuccessFlash = false
    @State private var enableDebugInstrumentation = false
    @State private var recoveryLimitInput = "1000"
    @State private var enrichmentLimitInput = "20"
    @State private var creationLimitInput = "10"
    @State private var enrichmentOnlyLimitInput = "20"
    @ObservedObject var viewModel: ProduceViewModel

    private let supabaseService = SupabaseService.shared
    private let catalogAdminOpsService = CatalogAdminOpsService.shared

    private var configuredRecoveryLimit: Int {
        max(1, min(5000, Int(recoveryLimitInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1000))
    }

    private var configuredEnrichmentLimit: Int {
        max(1, min(100, Int(enrichmentLimitInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 20))
    }

    private var configuredCreationLimit: Int {
        max(1, min(100, Int(creationLimitInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 10))
    }

    private var configuredEnrichmentOnlyLimit: Int {
        max(1, min(100, Int(enrichmentOnlyLimitInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 20))
    }

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading catalog control panel…")
                        .foregroundStyle(.secondary)
                }
            }

            if !isAdminUser && !isLoading {
                Text("Admin-only tool.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isAdminUser {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Catalog Autopilot")
                            .font(.title3.weight(.semibold))

                        Text("Runs recovery, draft enrichment, and ingredient creation in one safe cycle.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            Task { await runCatalogAutomationCycle() }
                        } label: {
                            HStack(spacing: 10) {
                                if isRunningAutomationCycle {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if showAutomationSuccessFlash {
                                    Image(systemName: "checkmark.circle.fill")
                                }

                                Text(
                                    isRunningAutomationCycle
                                    ? "Running catalog autopilot…"
                                    : "Run catalog autopilot"
                                )
                                .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            isRunningAutomationCycle
                            || isRunningIngredientCreationBatch
                            || isRunningEnrichmentBatch
                            || isRunningCuratedBatch
                            || isRunningObservationRecovery
                        )
                        .opacity(
                            (isRunningAutomationCycle
                             || isRunningIngredientCreationBatch
                             || isRunningEnrichmentBatch
                             || isRunningCuratedBatch
                             || isRunningObservationRecovery) ? 0.75 : 1
                        )

                        if let run = lastAutomationRun, let compactSummary = compactAutopilotSummary(from: run) {
                            Text(compactSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No autopilot run yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if !actionMessage.isEmpty {
                            Text(actionMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                exceptionInboxSection

                if !isLoading && hasPrimaryCatalogContent == false {
                    Section {
                        Text("No exceptions require human judgment right now.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(isAdvancedDebugExpanded ? "Hide technical tools" : "Show technical tools") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isAdvancedDebugExpanded.toggle()
                        }
                    }
                    .font(.body.weight(.semibold))
                }

                if isAdvancedDebugExpanded {
                    technicalToolsActionsSection
                    draftReviewSection
                    if isSelectionMode { bulkActionsSection }
                    if !coverageBlockers.isEmpty { coverageBlockersSection }
                    if !draftIngredientSuggestionCandidates.isEmpty { draftIngredientSuggestionsSection }
                    if !ambiguousHoldCandidates.isEmpty { ambiguousHoldSection }
                    if !ingredientHierarchyRows.isEmpty { ingredientHierarchySection }
                    if !observationCoverage.isEmpty { observationCoverageSection }
                    importFromURLSection
                }
            }
        }
        .navigationTitle("Catalog Control Panel")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAdminUser && (isAdvancedDebugExpanded || isSelectionMode) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        toggleSelectionMode()
                    }
                }
            }
        }
        .task {
            await loadCandidates()
        }
        .refreshable {
            await loadCandidates()
        }
        .sheet(item: $approvalRoute) { route in
            NavigationStack {
                List {
                    Section("Candidate") {
                        Text(route.candidate.normalizedText)
                            .font(.body.weight(.semibold))
                    }

                    Section("Target ingredient") {
                        TextField("Search ingredient", text: $ingredientSearchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        ForEach(filteredIngredients, id: \.ingredientID) { ingredient in
                            Button {
                                selectedIngredientID = ingredient.ingredientID
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ingredientDisplayName(for: ingredient))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(ingredient.slug)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedIngredientID == ingredient.ingredientID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Approve Alias")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            approvalRoute = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Approve") {
                            Task {
                                await approveAlias(for: route.candidate)
                            }
                        }
                        .disabled(selectedIngredientID == nil || isApproving)
                    }
                }
            }
        }
        .sheet(item: $enrichmentRoute) { route in
            NavigationStack {
                CatalogEnrichmentDraftEditorView(
                    candidate: route.candidate,
                    onClose: {
                        enrichmentRoute = nil
                    },
                    onSaved: { statusMessage in
                        actionMessage = statusMessage
                        Task {
                            await loadCandidates()
                        }
                    }
                )
            }
        }
        .sheet(item: $bulkAliasRoute) { route in
            NavigationStack {
                List {
                    Section("Selection") {
                        Text("\(route.candidates.count) candidates selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Target ingredient") {
                        TextField("Search ingredient", text: $bulkIngredientSearchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        ForEach(filteredIngredientsForBulkAlias, id: \.ingredientID) { ingredient in
                            Button {
                                bulkSelectedIngredientID = ingredient.ingredientID
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ingredientDisplayName(for: ingredient))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(ingredient.slug)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if bulkSelectedIngredientID == ingredient.ingredientID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Bulk approve alias")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            bulkAliasRoute = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            Task { await approveAliasBulk(for: route.candidates) }
                        }
                        .disabled(bulkSelectedIngredientID == nil || isApproving)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadCandidates() async {
        isLoading = true
        errorMessage = ""
        actionMessage = ""
        defer { isLoading = false }

        isAdminUser = await AdminAccessControl.fetchIsCurrentUserAdmin(
            supabaseService: supabaseService
        )
        guard isAdminUser else {
            items = []
            coverageBlockers = []
            readyEnrichmentDrafts = []
            observationCoverage = []
            ingredientHierarchyRows = []
            pendingDraftReviewRows = []
            unifiedIngredients = []
            return
        }

        if let snapshot = await supabaseService.fetchCatalogAdminOpsSnapshot(
            candidatesLimit: 50,
            coverageBlockersLimit: 30,
            readyDraftsLimit: 50,
            focusAliasLocalization: true
        ) {
            items = snapshot.candidates
            coverageBlockers = snapshot.coverageBlockers
            readyEnrichmentDrafts = snapshot.readyEnrichmentDrafts
            observationCoverage = snapshot.observationCoverage
            print(
                "[SEASON_CATALOG_DEBUG] phase=ops_snapshot_consumed " +
                "generated_at=\(snapshot.metadata.generatedAt?.description ?? "nil") " +
                "candidates=\(snapshot.metadata.candidatesCount) " +
                "coverage_blockers=\(snapshot.metadata.coverageBlockersCount) " +
                "ready_drafts=\(snapshot.metadata.readyEnrichmentDraftsCount) " +
                "observation_coverage=\(snapshot.metadata.observationCoverageCount) " +
                "source=\(snapshot.metadata.source)"
            )
        } else {
            items = []
            coverageBlockers = []
            readyEnrichmentDrafts = []
            observationCoverage = []
            pendingDraftReviewRows = []
            errorMessage = "Failed to load catalog admin snapshot."
        }
        pendingDraftReviewRows = await supabaseService.fetchPendingCatalogEnrichmentDraftReview(limit: 200)
        unifiedIngredients = await supabaseService.fetchUnifiedIngredientCatalogSummary()
        ingredientHierarchyRows = await catalogAdminOpsService.fetchIngredientHierarchy(limit: 200)
    }

    @MainActor
    private func approveAlias(for candidate: CatalogResolutionCandidateRecord) async {
        guard isAdminUser else { return }
        guard let ingredientID = selectedIngredientID else { return }
        isApproving = true
        defer { isApproving = false }

        do {
            try await catalogAdminOpsService.approveAlias(
                normalizedText: candidate.normalizedText,
                ingredientID: ingredientID
            )
            actionMessage = "Alias approved for \(candidate.normalizedText)."
            approvalRoute = nil
            selectedIngredientID = nil
            ingredientSearchQuery = ""
            await loadCandidates()
        } catch {
            errorMessage = "Failed to approve alias. Please try again."
            print("[SEASON_CATALOG_ADMIN] phase=approve_alias_failed normalized_text=\(candidate.normalizedText) error=\(error)")
        }
    }

    @MainActor
    private func createIngredient(from draft: ReadyCatalogEnrichmentDraftRecord) async {
        guard isAdminUser else { return }
        creatingDraftNormalizedText = draft.normalizedText
        defer { creatingDraftNormalizedText = nil }

        do {
            try await catalogAdminOpsService.createIngredientFromEnrichmentDraft(
                normalizedText: draft.normalizedText
            )
            actionMessage = "Ingredient created from draft \(draft.normalizedText)."
            await loadCandidates()
        } catch {
            errorMessage = "Failed to create ingredient from enrichment draft."
            print("[SEASON_CATALOG_ADMIN] phase=create_from_enrichment_failed normalized_text=\(draft.normalizedText) error=\(error)")
        }
    }


    @MainActor
    private func approveAliasBulk(for candidates: [CatalogResolutionCandidateRecord]) async {
        guard isAdminUser else { return }
        guard let ingredientID = bulkSelectedIngredientID else { return }
        isApproving = true
        defer { isApproving = false }

        let summary = await catalogAdminOpsService.approveAliasesBulk(
            normalizedTexts: candidates.map(\.normalizedText),
            ingredientID: ingredientID
        )
        actionMessage = "Bulk alias: \(summary.successCount) applied, \(summary.failureCount) failed."
        bulkAliasRoute = nil
        clearSelections()
        await loadCandidates()
    }

    private struct CuratedAliasBatchItem {
        let normalizedText: String
        let targetSlug: String
        let occurrenceCount: Int
    }

    private var safeAliasSuggestions: [CuratedAliasBatchItem] {
        let readyDraftTexts = Set(
            readyEnrichmentDrafts.map { $0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        let blockerByText: [String: CatalogCoverageBlockerRecord] = Dictionary(
            uniqueKeysWithValues: coverageBlockers.map {
                ($0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0)
            }
        )

        return items.compactMap { candidate in
            let normalized = candidate.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return nil }
            guard !readyDraftTexts.contains(normalized) else { return nil }
            guard candidate.existingAliasStatus.lowercased() != "approved" else { return nil }
            guard candidate.suggestedResolutionType.lowercased() == "alias_existing" else { return nil }
            guard let blocker = blockerByText[normalized] else { return nil }
            guard blocker.likelyFixType.lowercased() == "alias" else { return nil }
            guard blocker.recommendedNextAction.lowercased() == "add_alias" else { return nil }

            let slug = blocker.canonicalCandidateSlug?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard !slug.isEmpty else { return nil }
            return CuratedAliasBatchItem(
                normalizedText: normalized,
                targetSlug: slug,
                occurrenceCount: candidate.occurrenceCount
            )
        }
        .sorted {
            if $0.occurrenceCount != $1.occurrenceCount { return $0.occurrenceCount > $1.occurrenceCount }
            return $0.normalizedText < $1.normalizedText
        }
    }

    private var draftIngredientSuggestionCandidates: [CatalogResolutionCandidateRecord] {
        let safeAliasTexts = Set(safeAliasSuggestions.map(\.normalizedText))
        let readyDraftTexts = Set(
            readyEnrichmentDrafts.map { $0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        let blockerByText: [String: CatalogCoverageBlockerRecord] = Dictionary(
            uniqueKeysWithValues: coverageBlockers.map {
                ($0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0)
            }
        )

        return items.filter { candidate in
            let normalized = candidate.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return false }
            guard !safeAliasTexts.contains(normalized) else { return false }
            guard !readyDraftTexts.contains(normalized) else { return false }
            guard candidate.existingAliasStatus.lowercased() != "approved" else { return false }

            let blocker = blockerByText[normalized]
            let hasCanonicalSlug = !(blocker?.canonicalCandidateSlug?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let likelyFixType = blocker?.likelyFixType.lowercased() ?? ""
            let recommendedAction = blocker?.recommendedNextAction.lowercased() ?? ""

            // Strong alias-like signal: do not send to enrichment draft prep.
            if likelyFixType == "alias" || recommendedAction == "add_alias" {
                return false
            }
            if hasCanonicalSlug && (likelyFixType == "alias" || candidate.suggestedResolutionType.lowercased() == "alias_existing") {
                return false
            }

            // Exclude obvious quantity-contaminated candidate text.
            if isQuantityContaminatedCandidateText(normalized) {
                return false
            }

            // Exclude low-risk preparation/state qualifiers when likely canonical alias handling exists.
            if hasLowRiskQualifier(normalized) && hasCanonicalSlug {
                return false
            }

            let suggested = candidate.suggestedResolutionType.lowercased()
            guard suggested == "create_new_ingredient" || suggested == "unknown" else { return false }

            let isPastaShape = isLikelyPastaShapeCandidate(normalized)
            let strongNewIngredientSignal =
                isPastaShape ||
                likelyFixType == "new_ingredient" ||
                recommendedAction == "create_new_ingredient"

            // Conservative threshold by default; allow lower only on strong evidence.
            if candidate.occurrenceCount < 2 && !strongNewIngredientSignal {
                return false
            }

            return true
        }
        .sorted {
            if $0.occurrenceCount != $1.occurrenceCount { return $0.occurrenceCount > $1.occurrenceCount }
            return $0.normalizedText < $1.normalizedText
        }
    }

    private var ambiguousHoldCandidates: [CatalogResolutionCandidateRecord] {
        let safeAliasTexts = Set(safeAliasSuggestions.map(\.normalizedText))
        let draftTexts = Set(draftIngredientSuggestionCandidates.map {
            $0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })

        return items.filter { candidate in
            let normalized = candidate.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return false }
            return !safeAliasTexts.contains(normalized) && !draftTexts.contains(normalized)
        }
        .sorted {
            if $0.occurrenceCount != $1.occurrenceCount { return $0.occurrenceCount > $1.occurrenceCount }
            return $0.normalizedText < $1.normalizedText
        }
    }

    private var pendingDraftKeepForReview: [PendingCatalogEnrichmentDraftReviewRecord] {
        pendingDraftReviewRows.filter { $0.reviewBucket.uppercased() == "KEEP_PENDING_FOR_REVIEW" }
    }

    private var pendingDraftShouldBeAlias: [PendingCatalogEnrichmentDraftReviewRecord] {
        pendingDraftReviewRows.filter { $0.reviewBucket.uppercased() == "SHOULD_BE_ALIAS_INSTEAD" }
    }

    private var pendingDraftShouldHoldOrReject: [PendingCatalogEnrichmentDraftReviewRecord] {
        pendingDraftReviewRows.filter { $0.reviewBucket.uppercased() == "SHOULD_BE_REJECTED_OR_HOLD" }
    }

    private var newIngredientQueue: [CatalogResolutionCandidateRecord] {
        draftIngredientSuggestionCandidates
    }

    private var reviewLaterQueue: [CatalogResolutionCandidateRecord] {
        ambiguousHoldCandidates
    }

    private var needsNewVariantDecision: [CatalogResolutionCandidateRecord] {
        newIngredientQueue.filter { candidate in
            candidate.possibleActions.contains("new_variant") &&
            !candidate.possibleActions.contains("new_root") &&
            candidate.confidence != "high"
        }
    }

    private var needsNewRootDecision: [CatalogResolutionCandidateRecord] {
        newIngredientQueue.filter { candidate in
            candidate.possibleActions.contains("new_root") &&
            !candidate.possibleActions.contains("new_variant")
        }
    }

    private var needsHumanReviewCandidates: [CatalogResolutionCandidateRecord] {
        let variantIDs = Set(needsNewVariantDecision.map(\.id))
        let rootIDs = Set(needsNewRootDecision.map(\.id))
        return (newIngredientQueue + reviewLaterQueue).filter { candidate in
            !variantIDs.contains(candidate.id) && !rootIDs.contains(candidate.id)
        }
    }

    private var hasSemanticAutomationAnomalies: Bool {
        !(lastAutoAliasSummary?.anomalyItems.filter(semanticAnomaly).isEmpty ?? true) ||
        !(lastAutoLocalizationSummary?.anomalyItems.filter(semanticAnomaly).isEmpty ?? true)
    }

    private var semanticAutomationAnomalyItems: [SemanticAutomationAnomaly] {
        let aliasItems = (lastAutoAliasSummary?.anomalyItems ?? [])
            .filter(semanticAnomaly)
            .map { item in
                SemanticAutomationAnomaly(
                    id: "alias|\(item.id)",
                    normalizedText: item.normalizedText,
                    title: "Alias automation needs review",
                    message: item.errorMessage ?? item.detail
                )
            }

        let localizationItems = (lastAutoLocalizationSummary?.anomalyItems ?? [])
            .filter(semanticAnomaly)
            .map { item in
                SemanticAutomationAnomaly(
                    id: "localization|\(item.id)",
                    normalizedText: item.normalizedText,
                    title: "Localization automation needs review",
                    message: item.errorMessage ?? item.detail
                )
            }

        return aliasItems + localizationItems
    }

    private var semanticAutomationAnomalyCount: Int {
        semanticAutomationAnomalyItems.count
    }

    private var hasPrimaryCatalogContent: Bool {
        !needsNewVariantDecision.isEmpty ||
        !needsNewRootDecision.isEmpty ||
        !needsHumanReviewCandidates.isEmpty ||
        hasSemanticAutomationAnomalies
    }

    private var lastRunStatusValue: String {
        guard let run = lastAutomationRun else { return "—" }
        return isAutomationRunSuccessful(run) ? "Success" : "Failed"
    }

    private var lastRunStatusTint: Color {
        guard let run = lastAutomationRun else { return .secondary }
        return isAutomationRunSuccessful(run) ? .green : .red
    }

    private func isAutomationRunSuccessful(_ run: CatalogAutomationCycleRunSummary) -> Bool {
        let failedStatuses = [
            run.recovery.status,
            run.candidateIntake.status,
            run.enrichment.status,
            run.creation.status,
            run.aliasAutoApply.status,
            run.localizationAutoApply.status,
            run.reconciliationApplyModernSafe.status
        ]
            .map { $0.lowercased() }
            .contains("failed")
        let stageFailedCount = run.stageStatus.values.map { $0.lowercased() }.filter { $0 == "failed" }.count
        return !failedStatuses &&
            run.runStatus.lowercased() != "failed" &&
            stageFailedCount == 0 &&
            run.recovery.failed == 0 &&
            run.candidateIntake.failed == 0 &&
            run.enrichment.failed == 0 &&
            run.creation.failed == 0 &&
            run.aliasAutoApply.failed == 0 &&
            run.localizationAutoApply.failed == 0 &&
            run.reconciliationApplyModernSafe.failed == 0
    }

    private func compactAutopilotSummary(from run: CatalogAutomationCycleRunSummary) -> String? {
        let failedTotal = run.recovery.failed +
            run.candidateIntake.failed +
            run.enrichment.failed +
            run.creation.failed +
            run.aliasAutoApply.failed +
            run.localizationAutoApply.failed +
            run.reconciliationApplyModernSafe.failed
        return "Last run · status: \(run.runStatus) · recovered: \(run.recovery.observed) · intake: \(run.candidateIntake.submitted) · enriched: \(run.enrichment.succeeded) · created: \(run.creation.created) · alias: \(run.aliasAutoApply.succeeded) · loc: \(run.localizationAutoApply.succeeded) · reconciled: \(run.reconciliationApplyModernSafe.applied) · failed: \(failedTotal)"
    }

    @ViewBuilder
    private func summaryRow(title: String, value: String, isFailed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isFailed ? .red : .green)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func isQuantityContaminatedCandidateText(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        // Keep known canonical flour pattern eligible.
        if normalized == "farina 00" { return false }

        // Measured quantity patterns like: 400 g, 1 kg, 80 ml, 1 pizzico.
        let measuredPattern = #"\b\d+(?:[.,]\d+)?\s*(g|kg|gr|ml|l|cl|pizzico|pizzichi|cucchiaio|cucchiai|cucchiaino|cucchiaini|tbsp|tsp|cup)\b"#
        if normalized.range(of: measuredPattern, options: .regularExpression) != nil {
            return true
        }

        // Standalone numeric count at end often indicates contaminated ingredient line fragments.
        let trailingCountPattern = #"\s\d+$"#
        if normalized.range(of: trailingCountPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func hasLowRiskQualifier(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let qualifiers = [
            "ammorbidito",
            "da grattugiare",
            "in grani",
            "a temperatura ambiente",
            "freddo di frigo",
            "fresco",
            "fresca",
            "tritato",
            "tritata"
        ]
        return qualifiers.contains { normalized.contains($0) }
    }

    private func isLikelyPastaShapeCandidate(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pastaShapes = [
            "conchiglioni",
            "spaghettoni",
            "tagliatelle",
            "pappardelle",
            "rigatoni",
            "mezze maniche",
            "penne rigate",
            "fusilli",
            "orecchiette",
            "trofie",
            "paccheri"
        ]
        return pastaShapes.contains { normalized.contains($0) }
    }

    @MainActor
    private func runAutoAliasSweep() async {
        guard isAdminUser else { return }
        isRunningAutoAlias = true
        defer { isRunningAutoAlias = false }

        do {
            let summary = try await catalogAdminOpsService.autoApplySafeAliases(
                limit: 50,
                languageCode: "it"
            )
            lastAutoAliasSummary = summary
            actionMessage =
                "Auto-alias done. total=\(summary.total), " +
                "succeeded=\(summary.succeeded), skipped=\(summary.skipped), failed=\(summary.failed)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=auto_alias_ui_done " +
                "total=\(summary.total) succeeded=\(summary.succeeded) " +
                "skipped=\(summary.skipped) failed=\(summary.failed)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Auto-alias run failed."
            print("[SEASON_CATALOG_ADMIN] phase=auto_alias_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runCuratedBatchB() async {
        guard isAdminUser else { return }
        isRunningCuratedBatch = true
        runningBatchName = "B"
        defer {
            isRunningCuratedBatch = false
            runningBatchName = nil
        }

        let draftCandidates = draftIngredientSuggestionCandidates
        print("[SEASON_CATALOG_ADMIN] phase=run_draft_ingredient_suggestions_started candidate_count=\(draftCandidates.count)")
        let items: [CatalogCandidateBatchTriageItem] = draftCandidates.map {
            CatalogCandidateBatchTriageItem(
                normalizedText: $0.normalizedText,
                action: "prepare_enrichment_draft",
                ingredientID: nil,
                aliasText: nil,
                languageCode: "it",
                confidenceScore: nil,
                reviewerNote: "dynamic_prepare_draft_suggestions_v1"
            )
        }

        guard !items.isEmpty else {
            actionMessage = "No draft ingredient suggestions available."
            return
        }

        do {
            let result = try await catalogAdminOpsService.executeBatchCandidateTriage(
                items: items,
                defaultLanguageCode: "it",
                reviewerNote: "dynamic_prepare_draft_suggestions_v1"
            )
            actionMessage = "Draft ingredient suggestions done. total=\(result.summary.total), succeeded=\(result.summary.succeeded), failed=\(result.summary.failed), skipped=\(result.summary.skipped)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=run_draft_ingredient_suggestions_done " +
                "submitted=\(items.count) total=\(result.summary.total) " +
                "succeeded=\(result.summary.succeeded) failed=\(result.summary.failed) skipped=\(result.summary.skipped)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Draft ingredient suggestions failed. Please try again."
            print("[SEASON_CATALOG_ADMIN] phase=run_draft_ingredient_suggestions_failed error=\(error)")
        }
    }

    @MainActor
    private func parseRecipeFromURL() async {
        guard isAdminUser else { return }
        let normalizedURL = importURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedURL.isEmpty else { return }
        isParsingURLImport = true
        errorMessage = ""
        defer { isParsingURLImport = false }

        do {
            importedRecipePreview = try await supabaseService.importRecipeFromURL(url: normalizedURL)
            actionMessage = "Recipe parsed from URL."
        } catch {
            importedRecipePreview = nil
            errorMessage = (error as NSError).localizedDescription
            print("[SEASON_URL_IMPORT_UI] phase=parse_failed error=\(error)")
        }
    }

    @MainActor
    private func saveImportedRecipePreview() async {
        guard isAdminUser else { return }
        guard let preview = importedRecipePreview else { return }
        isSavingImportedRecipe = true
        errorMessage = ""
        defer { isSavingImportedRecipe = false }

        do {
            let sourceAttribution = sourceAttributionDisplayName(preview: preview)
            let ingredients = preview.ingredients
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { normalizedImportedIngredient(from: $0) }

            let steps = preview.steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let title = preview.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Imported recipe"
                : preview.title.trimmingCharacters(in: .whitespacesAndNewlines)

            let recipe = Recipe(
                id: UUID().uuidString.lowercased(),
                title: title,
                author: sourceAttribution,
                creatorId: "unknown",
                creatorDisplayName: sourceAttribution,
                creatorAvatarURL: nil,
                ingredients: ingredients.isEmpty ? [
                    RecipeIngredient(
                        produceID: nil,
                        basicIngredientID: nil,
                        quality: .basic,
                        name: "Ingredient",
                        quantityValue: 1,
                        quantityUnit: .piece,
                        rawIngredientLine: nil,
                        mappingConfidence: .unmapped
                    ),
                ] : ingredients,
                preparationSteps: steps.isEmpty ? ["Review instructions from source."] : steps,
                prepTimeMinutes: nil,
                cookTimeMinutes: nil,
                difficulty: nil,
                servings: 2,
                crispy: 0,
                viewCount: 0,
                dietaryTags: [],
                seasonalMatchPercent: 50,
                createdAt: Date(),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: nil,
                mediaLinkURL: preview.sourceURL,
                instagramURL: nil,
                tiktokURL: nil,
                sourceURL: preview.sourceURL,
                sourceName: preview.sourceName,
                sourcePlatform: .other,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                sourceType: .curatedImport,
                isUserGenerated: false,
                imageURL: nonEmptyTrimmed(preview.imageURL),
                imageSource: nil,
                attributionText: nil,
                publicationStatus: .published,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            )

            try await supabaseService.createRecipe(recipe)
            viewModel.commitPublishedRecipeLocally(recipe)
            lastSavedImportedRecipe = recipe
            actionMessage = "Recipe saved: \(recipe.title)"
            await loadCandidates()
        } catch {
            errorMessage = (error as NSError).localizedDescription
            print("[SEASON_URL_IMPORT_UI] phase=save_failed error=\(error)")
        }
    }

    private func normalizedImportedIngredient(from rawLine: String) -> RecipeIngredient {
        let parsed = parseImportedIngredientLine(rawLine)
        let match = matchedIngredientAlias(for: parsed.ingredientName)
        let localizedLanguage = viewModel.localizer.languageCode

        switch match {
        case .produce(let produce):
            return RecipeIngredient(
                produceID: produce.id,
                basicIngredientID: nil,
                quality: .coreSeasonal,
                name: produce.displayName(languageCode: localizedLanguage),
                quantityValue: parsed.quantityValue,
                quantityUnit: parsed.quantityUnit,
                rawIngredientLine: rawLine,
                mappingConfidence: .high
            )
        case .basic(let basic):
            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: basic.id,
                quality: .basic,
                name: basic.displayName(languageCode: localizedLanguage),
                quantityValue: parsed.quantityValue,
                quantityUnit: parsed.quantityUnit,
                rawIngredientLine: rawLine,
                mappingConfidence: .high
            )
        case .none:
            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: nil,
                quality: .basic,
                name: parsed.ingredientName,
                quantityValue: parsed.quantityValue,
                quantityUnit: parsed.quantityUnit,
                rawIngredientLine: rawLine,
                mappingConfidence: .unmapped
            )
        }
    }

    private func matchedIngredientAlias(for rawName: String) -> IngredientAliasMatch? {
        for query in importedIngredientQueries(from: rawName) {
            if let match = viewModel.resolveIngredientForImport(query: query) {
                return match
            }
        }
        return nil
    }

    private func sourceAttributionDisplayName(preview: ImportedRecipePreview) -> String {
        let sourceCandidate = preview.sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostCandidate = URL(string: preview.sourceURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bestDomain = [sourceCandidate, hostCandidate]
            .first(where: { $0.contains(".") && !$0.isEmpty })
            ?? hostCandidate
        let resolved = sourceBrandName(from: bestDomain) ?? "Source"
        return "Via \(resolved)"
    }

    private func sourceBrandName(from rawDomain: String) -> String? {
        let lowered = rawDomain.lowercased().replacingOccurrences(of: "www.", with: "")
        var parts = lowered.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }

        if parts.count >= 2 {
            let weakSecondLevel = Set(["co", "com", "org", "net", "gov", "edu", "ac"])
            if parts.count >= 3, weakSecondLevel.contains(parts[parts.count - 2]) {
                parts = [parts[parts.count - 3]]
            } else {
                parts = [parts[parts.count - 2]]
            }
        }

        let token = parts[0]
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        return token
            .split(separator: " ")
            .map { value in
                let word = String(value)
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private func importedIngredientQueries(from raw: String) -> [String] {
        let normalizedRaw = normalizedIngredientIdentity(raw)
        guard !normalizedRaw.isEmpty else { return [] }

        var seen = Set<String>()
        var output: [String] = []

        func append(_ value: String) {
            let normalized = normalizedIngredientIdentity(value)
            guard !normalized.isEmpty else { return }
            guard seen.insert(normalized).inserted else { return }
            output.append(normalized)
        }

        append(normalizedRaw)
        append(strippingIngredientDescriptors(normalizedRaw))
        append(replacingCommonImportedPhrases(normalizedRaw))
        return output
    }

    private func normalizedIngredientIdentity(_ raw: String) -> String {
        strippingParentheticalText(raw)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s']"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func strippingParentheticalText(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func replacingCommonImportedPhrases(_ normalized: String) -> String {
        var value = normalized
        let replacements: [(String, String)] = [
            ("olio extravergine d'oliva", "olive oil"),
            ("olio evo", "olive oil"),
            ("cipolle rosse", "cipolla rossa"),
            ("patate", "patata"),
            ("cipolle", "cipolla")
        ]
        for (source, target) in replacements where value == source {
            value = target
            break
        }
        return value
    }

    private func strippingIngredientDescriptors(_ normalized: String) -> String {
        let tokens = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        let descriptors = Set([
            "fresco", "fresca", "freschi", "fresche", "fresh",
            "rosso", "rossa", "rosse", "red",
            "intero", "intera", "interi", "intere",
            "fino", "fina", "fini", "fine",
            "secco", "secca", "secchi", "secche",
            "tritato", "tritata", "tritati", "tritate"
        ])
        let filtered = tokens.filter { !descriptors.contains($0) }
        return filtered.isEmpty ? normalized : filtered.joined(separator: " ")
    }

    private struct ImportedIngredientParseResult {
        let ingredientName: String
        let quantityValue: Double
        let quantityUnit: RecipeQuantityUnit
    }

    private func parseImportedIngredientLine(_ line: String) -> ImportedIngredientParseResult {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ImportedIngredientParseResult(ingredientName: "Ingredient", quantityValue: 1, quantityUnit: .piece)
        }

        if let parsed = parseMeasuredIngredientPrefix(trimmed) {
            return parsed
        }

        if let parsed = parseMeasuredIngredientSuffix(trimmed) {
            return parsed
        }

        return ImportedIngredientParseResult(
            ingredientName: cleanedIngredientDisplayName(trimmed),
            quantityValue: 1,
            quantityUnit: .piece
        )
    }

    private func parseMeasuredIngredientPrefix(_ line: String) -> ImportedIngredientParseResult? {
        let pattern = #"^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cup|cups|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|pezzo|pezzi|piece|pieces)\s+(.+?)\s*$"#
        return parseMeasuredIngredient(line, pattern: pattern, ingredientGroup: 3, quantityGroup: 1, unitGroup: 2)
    }

    private func parseMeasuredIngredientSuffix(_ line: String) -> ImportedIngredientParseResult? {
        let pattern = #"^\s*(.+?)\s+(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cup|cups|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|pezzo|pezzi|piece|pieces)\s*$"#
        return parseMeasuredIngredient(line, pattern: pattern, ingredientGroup: 1, quantityGroup: 2, unitGroup: 3)
    }

    private func parseMeasuredIngredient(
        _ line: String,
        pattern: String,
        ingredientGroup: Int,
        quantityGroup: Int,
        unitGroup: Int
    ) -> ImportedIngredientParseResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: nsRange) else {
            return nil
        }

        guard let ingredientRange = Range(match.range(at: ingredientGroup), in: line),
              let quantityRange = Range(match.range(at: quantityGroup), in: line),
              let unitRange = Range(match.range(at: unitGroup), in: line) else {
            return nil
        }

        let rawIngredient = String(line[ingredientRange])
        let rawQuantity = String(line[quantityRange]).replacingOccurrences(of: ",", with: ".")
        let rawUnit = String(line[unitRange]).lowercased()
        guard let quantity = Double(rawQuantity),
              let mappedUnit = mappedQuantityUnit(rawUnit) else {
            return nil
        }

        let normalized = normalizeQuantity(value: quantity, rawUnit: rawUnit, mappedUnit: mappedUnit)
        return ImportedIngredientParseResult(
            ingredientName: cleanedIngredientDisplayName(rawIngredient),
            quantityValue: normalized.value,
            quantityUnit: normalized.unit
        )
    }

    private func mappedQuantityUnit(_ raw: String) -> RecipeQuantityUnit? {
        switch raw {
        case "g":
            return .g
        case "kg":
            return .g
        case "ml":
            return .ml
        case "l":
            return .ml
        case "tbsp", "cucchiaio", "cucchiai":
            return .tbsp
        case "tsp", "cucchiaino", "cucchiaini":
            return .tsp
        case "cup", "cups":
            return .cup
        case "spicchio", "spicchi", "clove", "cloves":
            return .clove
        case "pezzo", "pezzi", "piece", "pieces":
            return .piece
        default:
            return nil
        }
    }

    private func normalizeQuantity(value: Double, rawUnit: String, mappedUnit: RecipeQuantityUnit) -> (value: Double, unit: RecipeQuantityUnit) {
        switch rawUnit {
        case "kg":
            return (value * 1000, .g)
        case "l":
            return (value * 1000, .ml)
        default:
            return (value, mappedUnit)
        }
    }

    private func cleanedIngredientDisplayName(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+[\.,;:]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Ingredient" : cleaned
    }

    private func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private var draftReviewSection: some View {
        if !pendingDraftReviewRows.isEmpty || !readyEnrichmentDrafts.isEmpty {
            Section("Draft review (technical)") {
                if !pendingDraftReviewRows.isEmpty {
                    Text("Pending enrichment draft cleanup review")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if !pendingDraftKeepForReview.isEmpty {
                        Text("KEEP_PENDING_FOR_REVIEW (\(pendingDraftKeepForReview.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(pendingDraftKeepForReview) { item in
                            pendingDraftReviewRow(item)
                        }
                    }

                    if !pendingDraftShouldBeAlias.isEmpty {
                        Text("SHOULD_BE_ALIAS_INSTEAD (\(pendingDraftShouldBeAlias.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(pendingDraftShouldBeAlias) { item in
                            pendingDraftReviewRow(item)
                        }
                    }

                    if !pendingDraftShouldHoldOrReject.isEmpty {
                        Text("SHOULD_BE_REJECTED_OR_HOLD (\(pendingDraftShouldHoldOrReject.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(pendingDraftShouldHoldOrReject) { item in
                            pendingDraftReviewRow(item)
                        }
                    }
                }

                if !readyEnrichmentDrafts.isEmpty {
                    if !pendingDraftReviewRows.isEmpty {
                        Divider()
                    }
                    Text("Ready enrichment drafts")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(sortedReadyEnrichmentDrafts) { draft in
                        readyEnrichmentDraftRow(draft)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var technicalToolsActionsSection: some View {
        Section("Technical tools") {
            Text("Secondary diagnostics and maintenance actions. Use work queues above for day-to-day triage.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Advanced Run Controls")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Toggle("Enable debug instrumentation", isOn: $enableDebugInstrumentation)
                    .font(.caption)

                HStack(spacing: 8) {
                    Text("Recovery")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("1000", text: $recoveryLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    Text("Enrichment")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("20", text: $enrichmentLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                HStack(spacing: 8) {
                    Text("Creation")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("10", text: $creationLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    Text("Enrichment-only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("20", text: $enrichmentOnlyLimitInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }

            Button {
                Task { await runAutoAliasSweep() }
            } label: {
                if isRunningAutoAlias {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Auto-approving safe aliases…")
                    }
                } else {
                    Text("Auto-approve safe aliases (50)")
                }
            }
            .disabled(
                isRunningAutoAlias ||
                isRunningCuratedBatch ||
                isRunningObservationRecovery ||
                isRunningEnrichmentBatch ||
                isRunningIngredientCreationBatch
            )

            if let summary = lastAutoAliasSummary {
                Text("Auto-alias summary: total=\(summary.total), succeeded=\(summary.succeeded), skipped=\(summary.skipped), failed=\(summary.failed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !summary.anomalyItems.isEmpty {
                    Text("Alias anomalies")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(summary.anomalyItems.prefix(10)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.normalizedText)
                                .font(.caption.weight(.semibold))
                            Text("\(item.resultStatus): \(item.errorMessage ?? item.detail)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                Task { await runCuratedBatchB() }
            } label: {
                if isRunningCuratedBatch && runningBatchName == "B" {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Preparing draft ingredients…")
                    }
                } else {
                    Text("Run bulk draft preparation (\(draftIngredientSuggestionCandidates.count))")
                }
            }
            .disabled(isRunningCuratedBatch || draftIngredientSuggestionCandidates.isEmpty)

            Divider()

            Text("Localization is auto-handled for high-confidence localization-only cases. Manual localization is not part of daily workflow.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await runAutoLocalizationSweep() }
            } label: {
                if isRunningAutoLocalization {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Auto-applying safe localizations…")
                    }
                } else {
                    Text("Auto-apply safe localizations (50)")
                }
            }
            .disabled(
                isRunningAutoLocalization ||
                isRunningCuratedBatch ||
                isRunningObservationRecovery ||
                isRunningEnrichmentBatch ||
                isRunningIngredientCreationBatch
            )

            if let summary = lastAutoLocalizationSummary {
                Text("Auto-localization summary: total=\(summary.total), succeeded=\(summary.succeeded), skipped=\(summary.skipped), failed=\(summary.failed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !summary.anomalyItems.isEmpty {
                    Text("Localization anomalies")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(summary.anomalyItems.prefix(10)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.normalizedText)
                                .font(.caption.weight(.semibold))
                            Text("\(item.resultStatus): \(item.errorMessage ?? item.detail)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            Button {
                Task { await runPendingDraftEnrichmentBatch(limit: configuredEnrichmentOnlyLimit) }
            } label: {
                if isRunningEnrichmentBatch {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Enriching pending drafts…")
                    }
                } else {
                    Text("Run enrichment only (\(configuredEnrichmentOnlyLimit))")
                }
            }
            .disabled(isRunningEnrichmentBatch || isRunningCuratedBatch || isRunningObservationRecovery || isRunningIngredientCreationBatch)

            Button {
                Task { await runCatalogIngredientCreationBatch() }
            } label: {
                if isRunningIngredientCreationBatch {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Creating ingredients from ready drafts…")
                    }
                } else {
                    Text("Create ingredients from ready drafts (10)")
                }
            }
            .disabled(isRunningIngredientCreationBatch || isRunningEnrichmentBatch || isRunningCuratedBatch || isRunningObservationRecovery)

            Divider()

            Text("Recover unresolved ingredient observations from already-saved recipes.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await runObservationRecovery() }
            } label: {
                if isRunningObservationRecovery {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Running observation recovery…")
                    }
                } else {
                    Text("Run unresolved observation recovery (1000)")
                }
            }
            .disabled(isRunningObservationRecovery || isRunningCuratedBatch)

            Divider()

            Text("Safe recipe ingredient reconciliation (existing imported recipes).")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Preview shows safe candidates. Legacy apply still requires legacy bridge mapping; modern apply writes ingredient_id directly from safe modern matches.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                Task { await runSafeRecipeReconciliationPreview() }
            } label: {
                if isRunningReconciliationPreview {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading reconciliation preview…")
                    }
                } else {
                    Text("Preview safe recipe reconciliation")
                }
            }
            .disabled(
                isRunningReconciliationPreview ||
                isRunningReconciliationApply ||
                isRunningModernReconciliationApply ||
                isRunningObservationRecovery ||
                isRunningCuratedBatch
            )

            Button {
                Task { await runSafeRecipeReconciliationApply() }
            } label: {
                if isRunningReconciliationApply {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Applying safe recipe reconciliation…")
                    }
                } else {
                    Text("Apply safe recipe reconciliation (20)")
                }
            }
            .disabled(
                isRunningReconciliationApply ||
                isRunningModernReconciliationApply ||
                isRunningReconciliationPreview ||
                isRunningObservationRecovery ||
                isRunningCuratedBatch
            )

            if let summary = lastReconciliationApplySummary {
                Text("Reconciliation apply summary: total=\(summary.total), applied=\(summary.applied), skipped=\(summary.skipped), failed=\(summary.failed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await runModernSafeRecipeReconciliationApply() }
            } label: {
                if isRunningModernReconciliationApply {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Applying modern safe recipe reconciliation…")
                    }
                } else {
                    Text("Apply modern safe recipe reconciliation (20)")
                }
            }
            .disabled(
                isRunningModernReconciliationApply ||
                isRunningReconciliationApply ||
                isRunningReconciliationPreview ||
                isRunningObservationRecovery ||
                isRunningCuratedBatch
            )

            if let summary = lastModernReconciliationApplySummary {
                Text("Modern reconciliation apply summary: total=\(summary.total), applied=\(summary.applied), skipped=\(summary.skipped), failed=\(summary.failed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !reconciliationPreviewRows.isEmpty {
                Text("Safe reconciliation preview (\(reconciliationPreviewRows.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(reconciliationPreviewRows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.recipeTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("\(row.ingredientRawName) → \(row.proposedIngredientName ?? row.proposedIngredientSlug ?? "—")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("source: \(row.confidenceSource) · reason: \(row.safetyReason)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var exceptionInboxSection: some View {
        Section("Needs your decision") {
            Text("Only exceptions that require human judgment are shown here.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !needsNewVariantDecision.isEmpty {
                Text("Needs new variant decision")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(needsNewVariantDecision) { item in
                    exceptionCard(item, actionLabel: "Review as variant")
                }
            }

            if !needsNewRootDecision.isEmpty {
                Text("Needs new root decision")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(needsNewRootDecision) { item in
                    exceptionCard(item, actionLabel: "Review as new root")
                }
            }

            if !needsHumanReviewCandidates.isEmpty || hasSemanticAutomationAnomalies {
                Text("Needs human review")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(needsHumanReviewCandidates) { item in
                    exceptionCard(item, actionLabel: "Review")
                }

                ForEach(semanticAutomationAnomalyItems, id: \.id) { anomaly in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(anomaly.normalizedText)
                            .font(.body.weight(.semibold))
                        Text("Automation anomaly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(anomaly.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button("Review") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAdvancedDebugExpanded = true
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var advancedDebugSection: some View {
        Section {
            Toggle(isOn: $isAdvancedDebugExpanded) {
                Text("Advanced debug")
                    .font(.body.weight(.semibold))
            }
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func exceptionCard(_ item: CatalogResolutionCandidateRecord, actionLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.normalizedText)
                .font(.body.weight(.semibold))

            Text(exceptionDecisionLabel(for: item))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let canonicalCandidate = canonicalCandidateLabel(for: item.normalizedText) {
                Text("Canonical candidate: \(canonicalCandidate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let parentSlug = item.suggestedParentSlug, !parentSlug.isEmpty {
                Text("Suggested parent: \(parentSlug)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(exceptionPlainExplanation(for: item))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !isSelectionMode {
                Button {
                    enrichmentRoute = EnrichmentRoute(candidate: item)
                } label: {
                    Text(actionLabel)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isAdminUser || isApproving || creatingDraftNormalizedText != nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func exceptionDecisionLabel(for item: CatalogResolutionCandidateRecord) -> String {
        if needsNewVariantDecision.contains(where: { $0.id == item.id }) {
            return "Likely new variant"
        }
        if needsNewRootDecision.contains(where: { $0.id == item.id }) {
            return "Likely new root"
        }
        return "Needs semantic review"
    }

    private func exceptionPlainExplanation(for item: CatalogResolutionCandidateRecord) -> String {
        if let hint = item.reasoningHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            return hint
        }
        if needsNewVariantDecision.contains(where: { $0.id == item.id }) {
            return "A related ingredient family exists, but this term still needs a human variant decision."
        }
        if needsNewRootDecision.contains(where: { $0.id == item.id }) {
            return "No safe parent path was identified; this may be a new canonical root ingredient."
        }
        return "No safe canonical decision was made automatically."
    }

    private func semanticAnomaly(_ item: CatalogAutoAliasItemResult) -> Bool {
        if item.resultStatus == "failed" { return true }
        let detail = item.detail.lowercased()
        return detail.contains("conflict") || detail.contains("no_unambiguous") || detail.contains("low_confidence")
    }

    private func semanticAnomaly(_ item: CatalogAutoLocalizationItemResult) -> Bool {
        if item.resultStatus == "failed" { return true }
        let detail = item.detail.lowercased()
        return detail.contains("conflict") || detail.contains("low_confidence")
    }

    private func canonicalCandidateLabel(for normalizedText: String) -> String? {
        let key = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        guard let blocker = coverageBlockers.first(where: {
            $0.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }) else {
            return nil
        }
        if let canonicalName = blocker.canonicalCandidateName, !canonicalName.isEmpty {
            return canonicalName
        }
        if let canonicalSlug = blocker.canonicalCandidateSlug, !canonicalSlug.isEmpty {
            return canonicalSlug
        }
        return nil
    }

    @MainActor
    private func runObservationRecovery() async {
        guard isAdminUser else { return }
        isRunningObservationRecovery = true
        defer { isRunningObservationRecovery = false }

        do {
            let summary = try await catalogAdminOpsService.runUnresolvedObservationRecovery(
                limit: 1000,
                source: "import_recovery"
            )
            actionMessage =
                "Observation recovery done. total=\(summary.totalProcessed), " +
                "observed=\(summary.observedCount), skipped=\(summary.skippedCount), failed=\(summary.failedCount)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=observation_recovery_ui_done " +
                "total=\(summary.totalProcessed) observed=\(summary.observedCount) " +
                "skipped=\(summary.skippedCount) failed=\(summary.failedCount)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Observation recovery failed."
            print("[SEASON_CATALOG_ADMIN] phase=observation_recovery_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runAutoLocalizationSweep() async {
        guard isAdminUser else { return }
        isRunningAutoLocalization = true
        defer { isRunningAutoLocalization = false }

        do {
            let summary = try await catalogAdminOpsService.autoApplySafeLocalizations(
                limit: 50,
                languageCode: "it"
            )
            lastAutoLocalizationSummary = summary
            actionMessage =
                "Auto-localization done. total=\(summary.total), " +
                "succeeded=\(summary.succeeded), skipped=\(summary.skipped), failed=\(summary.failed)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=auto_localization_ui_done " +
                "total=\(summary.total) succeeded=\(summary.succeeded) " +
                "skipped=\(summary.skipped) failed=\(summary.failed)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Auto-localization run failed."
            print("[SEASON_CATALOG_ADMIN] phase=auto_localization_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runSafeRecipeReconciliationPreview() async {
        guard isAdminUser else { return }
        isRunningReconciliationPreview = true
        defer { isRunningReconciliationPreview = false }

        do {
            let rows = try await catalogAdminOpsService.previewSafeRecipeReconciliation(limit: 20)
            reconciliationPreviewRows = rows
            actionMessage = "Safe reconciliation preview loaded: \(rows.count) rows."
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_preview_ui_done rows=\(rows.count)")
        } catch {
            errorMessage = "Safe reconciliation preview failed."
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_preview_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runSafeRecipeReconciliationApply() async {
        guard isAdminUser else { return }
        isRunningReconciliationApply = true
        defer { isRunningReconciliationApply = false }

        do {
            let summary = try await catalogAdminOpsService.applySafeRecipeReconciliation(limit: 20)
            lastReconciliationApplySummary = summary
            let previewCount = reconciliationPreviewRows.count
            let eligibilityNote: String
            if previewCount > 0, summary.total < previewCount {
                eligibilityNote = " (preview=\(previewCount), apply-eligible=\(summary.total); missing legacy mapping likely)"
            } else {
                eligibilityNote = ""
            }
            actionMessage =
                "Safe reconciliation apply done. total=\(summary.total), " +
                "applied=\(summary.applied), skipped=\(summary.skipped), failed=\(summary.failed)\(eligibilityNote)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_ui_done " +
                "total=\(summary.total) applied=\(summary.applied) skipped=\(summary.skipped) failed=\(summary.failed) preview_count=\(previewCount)"
            )
            let refreshedPreview = try await catalogAdminOpsService.previewSafeRecipeReconciliation(limit: 20)
            reconciliationPreviewRows = refreshedPreview
            await loadCandidates()
        } catch {
            errorMessage = "Safe reconciliation apply failed."
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runModernSafeRecipeReconciliationApply() async {
        guard isAdminUser else { return }
        isRunningModernReconciliationApply = true
        defer { isRunningModernReconciliationApply = false }

        do {
            let summary = try await catalogAdminOpsService.applyModernSafeRecipeReconciliation(limit: 20)
            lastModernReconciliationApplySummary = summary
            actionMessage =
                "Modern safe reconciliation apply done. total=\(summary.total), " +
                "applied=\(summary.applied), skipped=\(summary.skipped), failed=\(summary.failed)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_modern_ui_done " +
                "total=\(summary.total) applied=\(summary.applied) skipped=\(summary.skipped) failed=\(summary.failed)"
            )
            let refreshedPreview = try await catalogAdminOpsService.previewSafeRecipeReconciliation(limit: 20)
            reconciliationPreviewRows = refreshedPreview
            await loadCandidates()
        } catch {
            errorMessage = "Modern safe reconciliation apply failed."
            print("[SEASON_CATALOG_ADMIN] phase=recipe_reconciliation_apply_modern_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runPendingDraftEnrichmentBatch(limit: Int) async {
        guard isAdminUser else { return }
        isRunningEnrichmentBatch = true
        defer { isRunningEnrichmentBatch = false }

        do {
            let safeLimit = max(1, min(100, limit))
            let summary = try await catalogAdminOpsService.runCatalogEnrichmentDraftBatch(
                limit: safeLimit,
                debug: enableDebugInstrumentation
            )
            actionMessage =
                "Enrichment-only run (\(safeLimit)) done. total=\(summary.total), " +
                "succeeded=\(summary.succeeded), failed=\(summary.failed), skipped=\(summary.skipped), " +
                "ready=\(summary.ready), pending=\(summary.pending)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=enrichment_batch_ui_done " +
                "limit=\(safeLimit) " +
                "debug=\(enableDebugInstrumentation) " +
                "total=\(summary.total) succeeded=\(summary.succeeded) " +
                "failed=\(summary.failed) skipped=\(summary.skipped) ready=\(summary.ready)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Pending draft enrichment batch failed."
            print("[SEASON_CATALOG_ADMIN] phase=enrichment_batch_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runCatalogIngredientCreationBatch() async {
        guard isAdminUser else { return }
        isRunningIngredientCreationBatch = true
        defer { isRunningIngredientCreationBatch = false }

        do {
            let result = try await supabaseService.runCatalogIngredientCreationBatch(limit: 10)
            let summary = result.summary
            actionMessage =
                "Ingredient creation batch done. total=\(summary.total), " +
                "created=\(summary.created), skipped_existing=\(summary.skippedExisting), " +
                "skipped_invalid=\(summary.skippedInvalid), failed=\(summary.failed)"
            print(
                "[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_ui_done " +
                "total=\(summary.total) created=\(summary.created) " +
                "skipped_existing=\(summary.skippedExisting) skipped_invalid=\(summary.skippedInvalid) failed=\(summary.failed)"
            )
            await loadCandidates()
        } catch {
            errorMessage = "Ingredient creation batch failed."
            print("[SEASON_CATALOG_ADMIN] phase=ingredient_create_batch_ui_failed error=\(error)")
        }
    }

    @MainActor
    private func runCatalogAutomationCycle() async {
        guard isAdminUser else { return }
        isRunningAutomationCycle = true
        showAutomationSuccessFlash = false
        defer { isRunningAutomationCycle = false }

        do {
            let result = try await catalogAdminOpsService.runCatalogAutomationCycle(
                recoveryLimit: configuredRecoveryLimit,
                enrichLimit: configuredEnrichmentLimit,
                createLimit: configuredCreationLimit,
                debug: enableDebugInstrumentation
            )
            lastAutomationRun = result
            actionMessage =
                "Automation cycle done (run_status=\(result.runStatus)). " +
                "Recovery: total=\(result.recovery.total), observed=\(result.recovery.observed), skipped=\(result.recovery.skipped), failed=\(result.recovery.failed). " +
                "Candidate intake: selected=\(result.candidateIntake.selected), eligible=\(result.candidateIntake.eligible), submitted=\(result.candidateIntake.submitted), succeeded=\(result.candidateIntake.succeeded), skipped=\(result.candidateIntake.skipped), failed=\(result.candidateIntake.failed). " +
                "Enrichment: total=\(result.enrichment.total), succeeded=\(result.enrichment.succeeded), failed=\(result.enrichment.failed), skipped=\(result.enrichment.skipped), ready=\(result.enrichment.ready). " +
                "Creation: total=\(result.creation.total), created=\(result.creation.created), skipped_existing=\(result.creation.skippedExisting), skipped_invalid=\(result.creation.skippedInvalid), failed=\(result.creation.failed). " +
                "Alias auto-apply: total=\(result.aliasAutoApply.total), succeeded=\(result.aliasAutoApply.succeeded), skipped=\(result.aliasAutoApply.skipped), failed=\(result.aliasAutoApply.failed), status=\(result.aliasAutoApply.status). " +
                "Localization auto-apply: total=\(result.localizationAutoApply.total), succeeded=\(result.localizationAutoApply.succeeded), skipped=\(result.localizationAutoApply.skipped), failed=\(result.localizationAutoApply.failed), status=\(result.localizationAutoApply.status). " +
                "Reconciliation (modern safe): total=\(result.reconciliationApplyModernSafe.total), applied=\(result.reconciliationApplyModernSafe.applied), skipped=\(result.reconciliationApplyModernSafe.skipped), failed=\(result.reconciliationApplyModernSafe.failed), status=\(result.reconciliationApplyModernSafe.status). " +
                "Policy: apply_aliases=\(result.policy.applyAliases), apply_localizations=\(result.policy.applyLocalizations), apply_reconciliation=\(result.policy.applyReconciliation), dry_run=\(result.policy.dryRun). " +
                "Stage status: \(result.stageStatus)."
            if result.aliasAutoApply.rpcError != nil || !result.aliasAutoApply.failedItems.isEmpty {
                let aliasSample = result.aliasAutoApply.failedItems
                    .prefix(3)
                    .map { item in
                        let normalizedText = item.normalizedText ?? "none"
                        let detail = item.detail ?? "none"
                        let errorMessage = item.errorMessage ?? "none"
                        return "\(normalizedText)|\(detail)|\(errorMessage)"
                    }
                    .joined(separator: ";")
                actionMessage +=
                    " Alias diagnostics: failed_items_total=\(result.aliasAutoApply.failedItemsTotal), " +
                    "rpc_error_message=\(result.aliasAutoApply.rpcError?.message ?? "none"), " +
                    "rpc_error_code=\(result.aliasAutoApply.rpcError?.code ?? "none"), " +
                    "rpc_error_details=\(result.aliasAutoApply.rpcError?.details ?? "none"), " +
                    "rpc_error_hint=\(result.aliasAutoApply.rpcError?.hint ?? "none"), " +
                    "failed_items=\(aliasSample)."
            }

            print(
                "[SEASON_CATALOG_ADMIN] phase=automation_cycle_ui_done " +
                "debug=\(enableDebugInstrumentation) " +
                "run_status=\(result.runStatus) " +
                "recovery_total=\(result.recovery.total) recovery_failed=\(result.recovery.failed) recovery_status=\(result.recovery.status) " +
                "candidate_intake_total=\(result.candidateIntake.submitted) candidate_intake_failed=\(result.candidateIntake.failed) candidate_intake_status=\(result.candidateIntake.status) " +
                "enrichment_total=\(result.enrichment.total) enrichment_failed=\(result.enrichment.failed) enrichment_status=\(result.enrichment.status) " +
                "creation_total=\(result.creation.total) creation_failed=\(result.creation.failed) creation_status=\(result.creation.status) " +
                "alias_total=\(result.aliasAutoApply.total) alias_failed=\(result.aliasAutoApply.failed) alias_status=\(result.aliasAutoApply.status) " +
                "localization_total=\(result.localizationAutoApply.total) localization_failed=\(result.localizationAutoApply.failed) localization_status=\(result.localizationAutoApply.status) " +
                "reconciliation_total=\(result.reconciliationApplyModernSafe.total) reconciliation_failed=\(result.reconciliationApplyModernSafe.failed) reconciliation_status=\(result.reconciliationApplyModernSafe.status) " +
                "policy_apply_aliases=\(result.policy.applyAliases) policy_apply_localizations=\(result.policy.applyLocalizations) policy_apply_reconciliation=\(result.policy.applyReconciliation) policy_dry_run=\(result.policy.dryRun) " +
                "stage_status=\(result.stageStatus)"
            )

            withAnimation(.easeInOut(duration: 0.2)) {
                showAutomationSuccessFlash = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAutomationSuccessFlash = false
                    }
                }
            }

            await loadCandidates()
        } catch {
            errorMessage = "Catalog automation cycle failed."
            showAutomationSuccessFlash = false
            print("[SEASON_CATALOG_ADMIN] phase=automation_cycle_ui_failed error=\(error)")
        }
    }

    @ViewBuilder
    private var importFromURLSection: some View {
        Section("Import from URL") {
            TextField("https://example.com/recipe", text: $importURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await parseRecipeFromURL() }
            } label: {
                if isParsingURLImport {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Parsing…")
                    }
                } else {
                    Text("Parse")
                }
            }
            .disabled(isParsingURLImport || importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let importedRecipePreview {
                importedRecipePreviewSection(importedRecipePreview)
            }

            if let lastSavedImportedRecipe {
                lastSavedRecipeSection(lastSavedImportedRecipe)
            }
        }
    }

    @ViewBuilder
    private func importedRecipePreviewSection(_ preview: ImportedRecipePreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.title)
                .font(.headline)

            Text("Source: \(preview.sourceName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !preview.ingredients.isEmpty {
                Text("Ingredients")
                    .font(.subheadline.weight(.semibold))
                ForEach(preview.ingredients, id: \.self) { ingredient in
                    Text("• \(ingredient)")
                        .font(.caption)
                }
            }

            if !preview.steps.isEmpty {
                Text("Steps")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 2)
                ForEach(Array(preview.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.caption)
                }
            }

            Button {
                Task { await saveImportedRecipePreview() }
            } label: {
                if isSavingImportedRecipe {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Saving recipe…")
                    }
                } else {
                    Text("Save recipe")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSavingImportedRecipe)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func lastSavedRecipeSection(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved recipe")
                .font(.subheadline.weight(.semibold))
            Text(recipe.title)
                .font(.body.weight(.semibold))
            if let source = recipe.sourceName ?? recipe.sourceURL {
                Text("Source: \(source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Recipe ID: \(recipe.id)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var bulkActionsSection: some View {
        Section("Bulk actions") {
            Text("Selected: \(selectedCandidateIDs.count) candidates, \(selectedCoverageBlockerIDs.count) blockers")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Bulk approve alias") {
                bulkIngredientSearchQuery = ""
                bulkSelectedIngredientID = nil
                bulkAliasRoute = BulkAliasRoute(candidates: selectedCandidates)
            }
            .disabled(selectedCandidates.isEmpty || !isAdminUser || isApproving)
        }
    }

    @ViewBuilder
    private var coverageBlockersSection: some View {
        Section("Top blocked terms (coverage)") {
            ForEach(coverageBlockers) { item in
                coverageBlockerRow(item)
            }
        }
    }

    @ViewBuilder
    private func coverageBlockerRow(_ item: CatalogCoverageBlockerRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isSelectionMode {
                Button {
                    toggleCoverageBlockerSelection(item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedCoverageBlockerIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCoverageBlockerIDs.contains(item.id) ? .green : .secondary)
                        Text(item.normalizedText)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(item.normalizedText)
                    .font(.body.weight(.semibold))
            }

            HStack(spacing: 10) {
                Text("fix: \(item.likelyFixType)")
                Text("rows: \(item.rowCount)")
                Text("recipes: \(item.recipeCount)")
                Text("occ: \(item.occurrenceCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let canonicalName = item.canonicalCandidateName,
               let canonicalSlug = item.canonicalCandidateSlug {
                Text("candidate: \(canonicalName) (\(canonicalSlug))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if item.canonicalCandidateIsChild, let parentSlug = item.canonicalCandidateParentSlug {
                    Text("hierarchy: child of \(parentSlug)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if item.canonicalCandidateIsRoot {
                    Text("hierarchy: root node")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("generic parent exists: \(item.genericParentExists ? "yes" : "no")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("blocker: \(item.blockerReason)")
                .font(.caption)
                .foregroundStyle(.secondary)

        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var draftIngredientSuggestionsSection: some View {
        Section("New ingredient draft suggestions (\(draftIngredientSuggestionCandidates.count))") {
            ForEach(draftIngredientSuggestionCandidates) { item in
                candidateRow(item)
            }
        }
    }

    @ViewBuilder
    private var ambiguousHoldSection: some View {
        Section("Ambiguous / hold (\(ambiguousHoldCandidates.count))") {
            ForEach(ambiguousHoldCandidates) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.normalizedText)
                        .font(.body.weight(.semibold))
                    HStack(spacing: 10) {
                        Text("occurrences: \(item.occurrenceCount)")
                        Text("suggested: \(item.suggestedResolutionType)")
                        Text("alias_status: \(item.existingAliasStatus)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var ingredientHierarchySection: some View {
        Section("Ingredient hierarchy (admin)") {
            ForEach(ingredientHierarchyRows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.ingredientSlug)
                            .font(.body.weight(.semibold))
                        if let parentSlug = row.parentSlug, !parentSlug.isEmpty {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(parentSlug)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("root")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("type: \(row.ingredientType)")
                        Text("rank: \(row.specificityRank)")
                        Text("kind: \(row.variantKind)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var observationCoverageSection: some View {
        Section("Observed term coverage state") {
            ForEach(observationCoverage) { item in
                observationCoverageRow(item)
            }
        }
    }

    @ViewBuilder
    private func observationCoverageRow(_ item: CatalogObservationCoverageRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.normalizedText)
                .font(.body.weight(.semibold))

            HStack(spacing: 10) {
                Text("state: \(item.coverageState)")
                Text("obs: \(item.observationStatus)")
                Text("count: \(item.occurrenceCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("reason: \(item.coverageReason)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let aliasName = item.aliasTargetName ?? item.aliasTargetSlug {
                Text("alias target: \(aliasName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let canonicalName = item.canonicalTargetName ?? item.canonicalTargetSlug {
                Text("canonical target: \(canonicalName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var pendingDraftReviewSection: some View {
        Section("Pending enrichment draft cleanup review") {
            if !pendingDraftKeepForReview.isEmpty {
                Text("KEEP_PENDING_FOR_REVIEW (\(pendingDraftKeepForReview.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(pendingDraftKeepForReview) { item in
                    pendingDraftReviewRow(item)
                }
            }

            if !pendingDraftShouldBeAlias.isEmpty {
                Text("SHOULD_BE_ALIAS_INSTEAD (\(pendingDraftShouldBeAlias.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(pendingDraftShouldBeAlias) { item in
                    pendingDraftReviewRow(item)
                }
            }

            if !pendingDraftShouldHoldOrReject.isEmpty {
                Text("SHOULD_BE_REJECTED_OR_HOLD (\(pendingDraftShouldHoldOrReject.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(pendingDraftShouldHoldOrReject) { item in
                    pendingDraftReviewRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func pendingDraftReviewRow(_ item: PendingCatalogEnrichmentDraftReviewRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.normalizedText)
                .font(.body.weight(.semibold))

            HStack(spacing: 10) {
                Text("bucket: \(item.reviewBucket)")
                Text("count: \(item.occurrenceCount)")
                Text("matches: \(item.canonicalMatchCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("reason: \(item.classificationReason)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("next: \(item.recommendedOperatorAction)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func candidateRow(_ item: CatalogResolutionCandidateRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isSelectionMode {
                Button {
                    toggleCandidateSelection(item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedCandidateIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCandidateIDs.contains(item.id) ? .green : .secondary)
                        Text(item.normalizedText)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(item.normalizedText)
                    .font(.body.weight(.semibold))
            }

            HStack(spacing: 10) {
                Text("count: \(item.occurrenceCount)")
                Text("suggested: \(item.suggestedResolutionType)")
                Text("alias: \(item.existingAliasStatus)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !item.possibleActions.isEmpty {
                HStack(spacing: 10) {
                    Text("options: \(item.possibleActions.joined(separator: " / "))")
                    Text("confidence: \(item.confidence)")
                    if let parentSlug = item.suggestedParentSlug, !parentSlug.isEmpty {
                        Text("parent: \(parentSlug)")
                    }
                    if item.closeCanonicalChildExists {
                        Text("close child exists")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let reasoningHint = item.reasoningHint, !reasoningHint.isEmpty {
                Text("reasoning: \(reasoningHint)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isSelectionMode {
                Button {
                    selectedIngredientID = nil
                    ingredientSearchQuery = ""
                    approvalRoute = ApprovalRoute(candidate: item)
                } label: {
                    if isApproving && approvalRoute?.candidate.id == item.id {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Approving alias…")
                        }
                        .font(.caption.weight(.semibold))
                    } else {
                        Text("Approve alias")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApproving || !isAdminUser)

                Button {
                    enrichmentRoute = EnrichmentRoute(candidate: item)
                } label: {
                    Text("Prepare ingredient")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(!isAdminUser || isApproving || creatingDraftNormalizedText != nil)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var readyEnrichmentDraftsSection: some View {
        Section {
            ForEach(sortedReadyEnrichmentDrafts) { draft in
                readyEnrichmentDraftRow(draft)
            }
        } header: {
            Text("Ready Enrichment Drafts")
        }
    }

    @ViewBuilder
    private func readyEnrichmentDraftRow(_ draft: ReadyCatalogEnrichmentDraftRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(draft.normalizedText)
                .font(.body.weight(.semibold))

            HStack(spacing: 10) {
                Text("type: \(draft.ingredientType)")
                Text("slug: \(draft.suggestedSlug ?? "—")")
                if let confidence = draft.confidenceScore {
                    Text("confidence: \(String(format: "%.2f", confidence))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let canonical = preferredCanonicalName(for: draft), !canonical.isEmpty {
                Text("canonical: \(canonical)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await createIngredient(from: draft)
                }
            } label: {
                if creatingDraftNormalizedText == draft.normalizedText {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Creating ingredient…")
                    }
                    .font(.caption.weight(.semibold))
                } else {
                    Text("Create ingredient")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isAdminUser || isApproving || creatingDraftNormalizedText != nil)
        }
        .padding(.vertical, 2)
    }

    private func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            clearSelections()
        }
    }

    private func clearSelections() {
        selectedCandidateIDs = []
        selectedCoverageBlockerIDs = []
    }

    private func toggleCandidateSelection(_ candidate: CatalogResolutionCandidateRecord) {
        if selectedCandidateIDs.contains(candidate.id) {
            selectedCandidateIDs.remove(candidate.id)
        } else {
            selectedCandidateIDs.insert(candidate.id)
        }
    }

    private func toggleCoverageBlockerSelection(_ blocker: CatalogCoverageBlockerRecord) {
        if selectedCoverageBlockerIDs.contains(blocker.id) {
            selectedCoverageBlockerIDs.remove(blocker.id)
        } else {
            selectedCoverageBlockerIDs.insert(blocker.id)
        }
    }

    private var selectedCandidates: [CatalogResolutionCandidateRecord] {
        items.filter { selectedCandidateIDs.contains($0.id) }
    }

    private var selectedCoverageBlockers: [CatalogCoverageBlockerRecord] {
        coverageBlockers.filter { selectedCoverageBlockerIDs.contains($0.id) }
    }

    private var sortedReadyEnrichmentDrafts: [ReadyCatalogEnrichmentDraftRecord] {
        readyEnrichmentDrafts.sorted { lhs, rhs in
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
    }

    private var filteredIngredients: [UnifiedIngredientCatalogSummaryRecord] {
        let query = ingredientSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = unifiedIngredients.sorted { lhs, rhs in
            ingredientDisplayName(for: lhs).localizedCaseInsensitiveCompare(ingredientDisplayName(for: rhs)) == .orderedAscending
        }
        guard !query.isEmpty else { return source }
        return source.filter { ingredient in
            ingredient.slug.lowercased().contains(query) ||
            ingredientDisplayName(for: ingredient).lowercased().contains(query) ||
            (ingredient.enName?.lowercased().contains(query) ?? false) ||
            (ingredient.itName?.lowercased().contains(query) ?? false)
        }
    }

    private var filteredIngredientsForBulkAlias: [UnifiedIngredientCatalogSummaryRecord] {
        let query = bulkIngredientSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = unifiedIngredients.sorted { lhs, rhs in
            ingredientDisplayName(for: lhs).localizedCaseInsensitiveCompare(ingredientDisplayName(for: rhs)) == .orderedAscending
        }
        guard !query.isEmpty else { return source }
        return source.filter { ingredient in
            ingredient.slug.lowercased().contains(query) ||
            ingredientDisplayName(for: ingredient).lowercased().contains(query) ||
            (ingredient.enName?.lowercased().contains(query) ?? false) ||
            (ingredient.itName?.lowercased().contains(query) ?? false)
        }
    }

    private func ingredientDisplayName(for ingredient: UnifiedIngredientCatalogSummaryRecord) -> String {
        let preferredCode = Locale.preferredLanguages.first ?? "en"
        if preferredCode.lowercased().hasPrefix("it"),
           let itName = ingredient.itName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !itName.isEmpty {
            return itName
        }
        if let enName = ingredient.enName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !enName.isEmpty {
            return enName
        }
        if let itName = ingredient.itName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !itName.isEmpty {
            return itName
        }
        return ingredient.slug.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func preferredCanonicalName(for draft: ReadyCatalogEnrichmentDraftRecord) -> String? {
        let preferredCode = Locale.preferredLanguages.first ?? "en"
        if preferredCode.lowercased().hasPrefix("it"),
           let it = draft.canonicalNameIT?.trimmingCharacters(in: .whitespacesAndNewlines),
           !it.isEmpty {
            return it
        }
        if let en = draft.canonicalNameEN?.trimmingCharacters(in: .whitespacesAndNewlines), !en.isEmpty {
            return en
        }
        if let it = draft.canonicalNameIT?.trimmingCharacters(in: .whitespacesAndNewlines), !it.isEmpty {
            return it
        }
        return nil
    }
}

private struct CatalogEnrichmentDraftEditorView: View {
    struct FormState {
        var ingredientType: String = "unknown"
        var canonicalNameIT: String = ""
        var canonicalNameEN: String = ""
        var suggestedSlug: String = ""
        var defaultUnit: String = "piece"
        var supportedUnitsCSV: String = "piece"
        var isSeasonal: Bool = false
        var seasonMonthsCSV: String = ""
        var confidenceScoreText: String = ""
        var needsManualReview: Bool = true
        var reasoningSummary: String = ""
    }

    let candidate: CatalogResolutionCandidateRecord
    let onClose: () -> Void
    let onSaved: (String) -> Void

    @State private var form = FormState()
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isValidating = false
    @State private var isMarkingReady = false
    @State private var validationErrors: [String] = []
    @State private var validationPassed = false
    @State private var feedbackMessage = ""
    @State private var errorMessage = ""
    @State private var currentStatus = "pending"
    @State private var isPrefilledSuggestion = false

    private let catalogAdminOpsService = CatalogAdminOpsService.shared
    private let enrichmentProvider: any CatalogEnrichmentProposalProviding = CatalogEnrichmentProviders.default

    var body: some View {
        Form {
            Section("Candidate") {
                Text(candidate.normalizedText)
                    .font(.body.weight(.semibold))
                Text("suggested: \(candidate.suggestedResolutionType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isPrefilledSuggestion {
                    Text("A provider-generated suggestion was loaded. Review, validate, then mark ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Draft status") {
                HStack(spacing: 10) {
                    Circle()
                        .fill(currentWorkflowStateColor)
                        .frame(width: 9, height: 9)
                    Text(currentWorkflowStateLabel)
                        .font(.subheadline.weight(.semibold))
                }
                Text(currentWorkflowStateDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Classification") {
                Picker("Ingredient type", selection: $form.ingredientType) {
                    Text("Unknown").tag("unknown")
                    Text("Produce").tag("produce")
                    Text("Basic").tag("basic")
                }
                .pickerStyle(.segmented)
            }

            Section("Canonical naming") {
                TextField("Canonical name (IT)", text: $form.canonicalNameIT)
                TextField("Canonical name (EN)", text: $form.canonicalNameEN)
                TextField("Suggested slug", text: $form.suggestedSlug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Units") {
                TextField("Default unit", text: $form.defaultUnit)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Supported units (comma separated)", text: $form.supportedUnitsCSV)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Seasonality") {
                if form.ingredientType == "produce" {
                    Text("Produce drafts require explicit seasonality before they can be ready.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Toggle("Is seasonal", isOn: $form.isSeasonal)
                TextField("Season months (comma separated, 1-12)", text: $form.seasonMonthsCSV)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Review & confidence") {
                TextField("Confidence score (0-1)", text: $form.confidenceScoreText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                Toggle("Needs manual review", isOn: $form.needsManualReview)
                Text("Keep this on when the suggestion needs a human check before canonical creation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Reasoning summary", text: $form.reasoningSummary, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Validation status") {
                HStack {
                    Image(systemName: validationPassed && validationErrors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(validationPassed && validationErrors.isEmpty ? .green : .orange)
                    Text(validationPassed && validationErrors.isEmpty ? "Validation passed" : "Validation needed")
                        .font(.subheadline.weight(.semibold))
                }

                if validationErrors.isEmpty {
                    Text(validationPassed ? "Draft is valid. You can now mark it ready." : "Run “Validate draft” to check if this draft is ready.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Fix the following issues before marking ready:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(validationErrors, id: \.self) { error in
                        Label(validationErrorMessage(for: error), systemImage: "xmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Actions") {
                Button {
                    Task { await saveDraft(markReady: false) }
                } label: {
                    if isSaving {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Saving draft…") }
                    } else {
                        Text("Save draft")
                    }
                }
                .disabled(anyActionRunning)

                Button {
                    Task { await validateDraft() }
                } label: {
                    if isValidating {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Validating…") }
                    } else {
                        Text("Validate draft")
                    }
                }
                .disabled(anyActionRunning)

                Button {
                    Task { await saveDraft(markReady: true) }
                } label: {
                    if isMarkingReady {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Marking ready…") }
                    } else {
                        Text("Mark ready")
                    }
                }
                .disabled(anyActionRunning || !validationPassed)

                Text(markReadyBlockReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !feedbackMessage.isEmpty {
                Section {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Prepare ingredient")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .task {
            await loadExistingDraft()
        }
    }

    private var anyActionRunning: Bool {
        isLoading || isSaving || isValidating || isMarkingReady
    }

    private var currentWorkflowStateLabel: String {
        switch currentStatus.lowercased() {
        case "ready":
            return "Ready"
        case "rejected":
            return "Rejected"
        default:
            if validationPassed && validationErrors.isEmpty {
                return "Validated"
            }
            return "Pending"
        }
    }

    private var currentWorkflowStateDescription: String {
        switch currentWorkflowStateLabel {
        case "Ready":
            return "This draft is ready for “Create ingredient”."
        case "Rejected":
            return "This draft is marked rejected. Update fields and validate again if needed."
        case "Validated":
            return "Validation passed. You can now mark this draft ready."
        default:
            return "Draft is not ready yet. Save and validate after editing."
        }
    }

    private var currentWorkflowStateColor: Color {
        switch currentWorkflowStateLabel {
        case "Ready":
            return .green
        case "Validated":
            return .blue
        case "Rejected":
            return .red
        default:
            return .orange
        }
    }

    private var markReadyBlockReason: String {
        if anyActionRunning {
            return "Please wait for the current action to finish."
        }
        if validationPassed && validationErrors.isEmpty {
            return "Next step: mark this draft ready."
        }
        if !validationErrors.isEmpty {
            return "Mark ready is disabled until validation errors are fixed."
        }
        return "Mark ready is disabled until you run validation successfully."
    }

    @MainActor
    private func loadExistingDraft() async {
        isLoading = true
        defer { isLoading = false }

        if let draft = await catalogAdminOpsService.fetchEnrichmentDraft(normalizedText: candidate.normalizedText) {
            form.ingredientType = draft.ingredientType
            form.canonicalNameIT = draft.canonicalNameIT ?? ""
            form.canonicalNameEN = draft.canonicalNameEN ?? ""
            form.suggestedSlug = draft.suggestedSlug ?? candidate.normalizedText.replacingOccurrences(of: " ", with: "_")
            form.defaultUnit = draft.defaultUnit ?? "piece"
            form.supportedUnitsCSV = draft.supportedUnits.joined(separator: ", ")
            form.isSeasonal = draft.isSeasonal ?? false
            form.seasonMonthsCSV = draft.seasonMonths.map(String.init).joined(separator: ",")
            if let confidence = draft.confidenceScore {
                form.confidenceScoreText = String(confidence)
            }
            form.needsManualReview = draft.needsManualReview
            form.reasoningSummary = draft.reasoningSummary ?? ""
            validationErrors = draft.validationErrors
            validationPassed = draft.validatedReady
            currentStatus = draft.status
            isPrefilledSuggestion = false
        } else {
            if let proposal = await enrichmentProvider.propose(for: candidate.normalizedText) {
                applyProposalPrefill(proposal)
                isPrefilledSuggestion = true
            } else {
                form.suggestedSlug = candidate.normalizedText.replacingOccurrences(of: " ", with: "_")
                isPrefilledSuggestion = false
            }
        }
    }

    @MainActor
    private func saveDraft(markReady: Bool) async {
        isSaving = !markReady
        isMarkingReady = markReady
        errorMessage = ""
        feedbackMessage = ""
        defer {
            isSaving = false
            isMarkingReady = false
        }

        do {
            let result = try await catalogAdminOpsService.upsertEnrichmentDraft(
                normalizedText: candidate.normalizedText,
                status: markReady ? "ready" : "pending",
                ingredientType: form.ingredientType,
                canonicalNameIT: normalizedOptional(form.canonicalNameIT),
                canonicalNameEN: normalizedOptional(form.canonicalNameEN),
                suggestedSlug: normalizedOptional(form.suggestedSlug),
                defaultUnit: normalizedOptional(form.defaultUnit),
                supportedUnits: parseCSVStrings(form.supportedUnitsCSV),
                isSeasonal: form.ingredientType == "produce" ? form.isSeasonal : nil,
                seasonMonths: parseCSVIntegers(form.seasonMonthsCSV),
                confidenceScore: parseConfidence(form.confidenceScoreText),
                needsManualReview: form.needsManualReview,
                reasoningSummary: normalizedOptional(form.reasoningSummary)
            )
            currentStatus = result.status
            validationPassed = result.validatedReady
            validationErrors = result.validationErrors
            feedbackMessage = markReady ? "Draft marked ready." : "Draft saved."
            onSaved(feedbackMessage)
        } catch {
            errorMessage = userFriendlyError(from: error)
        }
    }

    @MainActor
    private func validateDraft() async {
        isValidating = true
        errorMessage = ""
        feedbackMessage = ""
        defer { isValidating = false }

        do {
            // Ensure the latest local edits are persisted before validation.
            _ = try await catalogAdminOpsService.upsertEnrichmentDraft(
                normalizedText: candidate.normalizedText,
                status: currentStatus == "ready" ? "ready" : "pending",
                ingredientType: form.ingredientType,
                canonicalNameIT: normalizedOptional(form.canonicalNameIT),
                canonicalNameEN: normalizedOptional(form.canonicalNameEN),
                suggestedSlug: normalizedOptional(form.suggestedSlug),
                defaultUnit: normalizedOptional(form.defaultUnit),
                supportedUnits: parseCSVStrings(form.supportedUnitsCSV),
                isSeasonal: form.ingredientType == "produce" ? form.isSeasonal : nil,
                seasonMonths: parseCSVIntegers(form.seasonMonthsCSV),
                confidenceScore: parseConfidence(form.confidenceScoreText),
                needsManualReview: form.needsManualReview,
                reasoningSummary: normalizedOptional(form.reasoningSummary)
            )

            let result = try await catalogAdminOpsService.validateEnrichmentDraft(
                normalizedText: candidate.normalizedText
            )
            validationPassed = result.validatedReady
            validationErrors = result.validationErrors
            feedbackMessage = result.validatedReady
                ? "Validation passed."
                : "Validation found issues. Fix them and validate again."
        } catch {
            errorMessage = userFriendlyError(from: error)
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseCSVStrings(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func parseCSVIntegers(_ value: String) -> [Int] {
        value
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func parseConfidence(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func userFriendlyError(from error: Error) -> String {
        let raw = String(describing: error)
        if raw.contains("draft_not_ready") {
            return "Draft is not ready yet. Fix validation errors and try again."
        }
        if raw.contains("admin_required") {
            return "Admin access required."
        }
        return "Operation failed. Please try again."
    }

    private func validationErrorMessage(for error: String) -> String {
        switch error {
        case "ready_requires_classified_ingredient_type":
            return "Select Produce or Basic before marking ready."
        case "ready_requires_canonical_name":
            return "Add at least one canonical name (IT or EN)."
        case "ready_requires_suggested_slug":
            return "Add a suggested slug."
        case "ready_requires_default_unit":
            return "Set a default unit."
        case "ready_requires_supported_units":
            return "Add at least one supported unit."
        case "default_unit_must_be_supported":
            return "Default unit must be included in supported units."
        case "produce_requires_is_seasonal_considered":
            return "For produce, explicitly set whether it is seasonal."
        case "produce_seasonal_requires_season_months":
            return "For seasonal produce, add season months (1-12)."
        case "season_months_out_of_range":
            return "Season months must be values between 1 and 12."
        default:
            return error.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @MainActor
    private func applyProposalPrefill(_ proposal: CatalogEnrichmentProposal) {
        form.ingredientType = proposal.ingredientType
        form.canonicalNameIT = proposal.canonicalNameIT ?? ""
        form.canonicalNameEN = proposal.canonicalNameEN ?? ""
        form.suggestedSlug = proposal.suggestedSlug
        form.defaultUnit = proposal.defaultUnit
        form.supportedUnitsCSV = proposal.supportedUnits.joined(separator: ", ")
        if let seasonal = proposal.isSeasonal {
            form.isSeasonal = seasonal
        } else {
            form.isSeasonal = proposal.ingredientType == "produce"
        }
        form.seasonMonthsCSV = proposal.seasonMonths.map(String.init).joined(separator: ",")
        if let confidence = proposal.confidenceScore {
            form.confidenceScoreText = String(confidence)
        } else {
            form.confidenceScoreText = ""
        }
        form.needsManualReview = proposal.needsManualReview
        form.reasoningSummary = proposal.reasoningSummary ?? ""
        validationErrors = []
        validationPassed = false
        currentStatus = "pending"
    }
}
