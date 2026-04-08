import SwiftUI

struct CatalogCandidatesDebugView: View {
    private struct ApprovalRoute: Identifiable {
        let candidate: CatalogResolutionCandidateRecord
        var id: String { candidate.id }
    }

    private struct EnrichmentRoute: Identifiable {
        let candidate: CatalogResolutionCandidateRecord
        var id: String { candidate.id }
    }

    @State private var items: [CatalogResolutionCandidateRecord] = []
    @State private var readyEnrichmentDrafts: [ReadyCatalogEnrichmentDraftRecord] = []
    @State private var unifiedIngredients: [UnifiedIngredientCatalogSummaryRecord] = []
    @State private var isLoading = false
    @State private var isApproving = false
    @State private var creatingDraftNormalizedText: String?
    @State private var isAdminUser = false
    @State private var errorMessage = ""
    @State private var actionMessage = ""
    @State private var selectedIngredientID: String?
    @State private var ingredientSearchQuery = ""
    @State private var approvalRoute: ApprovalRoute?
    @State private var enrichmentRoute: EnrichmentRoute?

    private let supabaseService = SupabaseService.shared

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading candidates…")
                        .foregroundStyle(.secondary)
                }
            }

            if !isAdminUser && !isLoading {
                Text("Admin-only tool.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !isLoading && isAdminUser && errorMessage.isEmpty && items.isEmpty {
                Text("No candidates available.")
                    .foregroundStyle(.secondary)
            }

            if !isLoading && isAdminUser && errorMessage.isEmpty && readyEnrichmentDrafts.isEmpty {
                Text("No ready enrichment drafts.")
                    .foregroundStyle(.secondary)
            }

            if !actionMessage.isEmpty {
                Text(actionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(sortedItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.normalizedText)
                        .font(.body.weight(.semibold))

                    HStack(spacing: 10) {
                        Text("count: \(item.occurrenceCount)")
                        Text("suggested: \(item.suggestedResolutionType)")
                        Text("alias: \(item.existingAliasStatus)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                .padding(.vertical, 2)
            }

            if !readyEnrichmentDrafts.isEmpty {
                Section {
                    ForEach(sortedReadyEnrichmentDrafts) { draft in
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
                } header: {
                    Text("Ready Enrichment Drafts")
                }
            }
        }
        .navigationTitle("Catalog Candidates")
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
            readyEnrichmentDrafts = []
            unifiedIngredients = []
            return
        }

        let fetched = await supabaseService.fetchCatalogResolutionCandidates(limit: 50)
        items = fetched
        readyEnrichmentDrafts = await supabaseService.fetchReadyCatalogEnrichmentDrafts(limit: 50)
        unifiedIngredients = await supabaseService.fetchUnifiedIngredientCatalogSummary()
    }

    @MainActor
    private func approveAlias(for candidate: CatalogResolutionCandidateRecord) async {
        guard isAdminUser else { return }
        guard let ingredientID = selectedIngredientID else { return }
        isApproving = true
        defer { isApproving = false }

        do {
            try await supabaseService.approveCatalogAlias(
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
            try await supabaseService.createCatalogIngredientFromEnrichmentDraft(
                normalizedText: draft.normalizedText
            )
            actionMessage = "Ingredient created from draft \(draft.normalizedText)."
            await loadCandidates()
        } catch {
            errorMessage = "Failed to create ingredient from enrichment draft."
            print("[SEASON_CATALOG_ADMIN] phase=create_from_enrichment_failed normalized_text=\(draft.normalizedText) error=\(error)")
        }
    }

    private var sortedItems: [CatalogResolutionCandidateRecord] {
        items.sorted { lhs, rhs in
            if lhs.occurrenceCount != rhs.occurrenceCount {
                return lhs.occurrenceCount > rhs.occurrenceCount
            }
            let leftPriority = lhs.priorityScore ?? -Double.greatestFiniteMagnitude
            let rightPriority = rhs.priorityScore ?? -Double.greatestFiniteMagnitude
            if leftPriority != rightPriority {
                return leftPriority > rightPriority
            }
            return lhs.normalizedText < rhs.normalizedText
        }
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

    private let supabaseService = SupabaseService.shared
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
                    Text("Suggested prefill loaded. Review and confirm before marking ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Classification") {
                Picker("Ingredient type", selection: $form.ingredientType) {
                    Text("Unknown").tag("unknown")
                    Text("Produce").tag("produce")
                    Text("Basic").tag("basic")
                }
                .pickerStyle(.segmented)
            }

            Section("Canonical") {
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
                    Text("Produce requires explicit seasonality consideration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Toggle("Is seasonal", isOn: $form.isSeasonal)
                TextField("Season months (comma separated, 1-12)", text: $form.seasonMonthsCSV)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Review") {
                TextField("Confidence score (0-1)", text: $form.confidenceScoreText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                Toggle("Needs manual review", isOn: $form.needsManualReview)
                TextField("Reasoning summary", text: $form.reasoningSummary, axis: .vertical)
                    .lineLimit(2...5)
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
            }

            if !feedbackMessage.isEmpty {
                Section {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !validationErrors.isEmpty {
                Section("Validation errors") {
                    ForEach(validationErrors, id: \.self) { error in
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
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

    @MainActor
    private func loadExistingDraft() async {
        isLoading = true
        defer { isLoading = false }

        if let draft = await supabaseService.fetchCatalogEnrichmentDraft(normalizedText: candidate.normalizedText) {
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
            let result = try await supabaseService.upsertCatalogEnrichmentDraft(
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
            _ = try await supabaseService.upsertCatalogEnrichmentDraft(
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

            let result = try await supabaseService.validateCatalogEnrichmentDraft(
                normalizedText: candidate.normalizedText
            )
            validationPassed = result.validatedReady
            validationErrors = result.validationErrors
            feedbackMessage = result.validatedReady ? "Validation passed." : "Validation failed."
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
