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

    private struct LocalizationRoute: Identifiable {
        let blocker: CatalogCoverageBlockerRecord
        var id: String { blocker.id }
    }

    private struct BulkAliasRoute: Identifiable {
        let candidates: [CatalogResolutionCandidateRecord]
        var id: String { candidates.map(\.id).sorted().joined(separator: ",") }
    }

    private struct BulkLocalizationRoute: Identifiable {
        let blockers: [CatalogCoverageBlockerRecord]
        var id: String { blockers.map(\.id).sorted().joined(separator: ",") }
    }

    @State private var items: [CatalogResolutionCandidateRecord] = []
    @State private var coverageBlockers: [CatalogCoverageBlockerRecord] = []
    @State private var readyEnrichmentDrafts: [ReadyCatalogEnrichmentDraftRecord] = []
    @State private var unifiedIngredients: [UnifiedIngredientCatalogSummaryRecord] = []
    @State private var isLoading = false
    @State private var isApproving = false
    @State private var isAddingLocalization = false
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
    @State private var localizationRoute: LocalizationRoute?
    @State private var bulkAliasRoute: BulkAliasRoute?
    @State private var bulkLocalizationRoute: BulkLocalizationRoute?
    @State private var localizationText = ""
    @State private var localizationLanguageCode = "it"
    @State private var bulkLocalizationText = ""
    @State private var bulkLocalizationLanguageCode = "it"

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

            if !isLoading && isAdminUser && errorMessage.isEmpty && coverageBlockers.isEmpty {
                Text("No blocked terms available.")
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

            if isSelectionMode {
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

                    Button("Bulk add localization") {
                        guard let first = selectedLocalizationBlockers.first else { return }
                        bulkLocalizationText = first.normalizedText
                        bulkLocalizationLanguageCode = "it"
                        bulkLocalizationRoute = BulkLocalizationRoute(blockers: selectedLocalizationBlockers)
                    }
                    .disabled(!canRunBulkLocalization || !isAdminUser || isAddingLocalization)
                }
            }

            if !coverageBlockers.isEmpty {
                Section("Top blocked terms (coverage)") {
                    ForEach(coverageBlockers) { item in
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
                            }

                            Text("blocker: \(item.blockerReason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !isSelectionMode,
                               item.likelyFixType == "localization",
                               item.canonicalCandidateIngredientID != nil {
                                Button {
                                    localizationText = item.normalizedText
                                    localizationLanguageCode = "it"
                                    localizationRoute = LocalizationRoute(blocker: item)
                                } label: {
                                    if isAddingLocalization && localizationRoute?.blocker.id == item.id {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Adding localization…")
                                        }
                                        .font(.caption.weight(.semibold))
                                    } else {
                                        Text("Add localization")
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(!isAdminUser || isAddingLocalization)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            ForEach(items) { item in
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAdminUser {
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
        .sheet(item: $localizationRoute) { route in
            NavigationStack {
                Form {
                    Section("Blocked term") {
                        Text(route.blocker.normalizedText)
                            .font(.body.weight(.semibold))
                    }

                    Section("Canonical ingredient") {
                        Text(route.blocker.canonicalCandidateName ?? route.blocker.canonicalCandidateSlug ?? "—")
                            .font(.body)
                        Text(route.blocker.canonicalCandidateSlug ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Localization") {
                        TextField("Localization text", text: $localizationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Picker("Language", selection: $localizationLanguageCode) {
                            Text("Italiano (it)").tag("it")
                            Text("English (en)").tag("en")
                        }
                    }
                }
                .navigationTitle("Add localization")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            localizationRoute = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            Task { await addLocalization(for: route.blocker) }
                        }
                        .disabled(localizationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingLocalization)
                    }
                }
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
        .sheet(item: $bulkLocalizationRoute) { route in
            NavigationStack {
                Form {
                    Section("Selection") {
                        Text("\(route.blockers.count) blockers selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Canonical ingredient") {
                        Text(route.blockers.first?.canonicalCandidateName ?? route.blockers.first?.canonicalCandidateSlug ?? "—")
                            .font(.body)
                        Text(route.blockers.first?.canonicalCandidateSlug ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Localization") {
                        TextField("Localization text", text: $bulkLocalizationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Picker("Language", selection: $bulkLocalizationLanguageCode) {
                            Text("Italiano (it)").tag("it")
                            Text("English (en)").tag("en")
                        }
                    }
                }
                .navigationTitle("Bulk add localization")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            bulkLocalizationRoute = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            Task { await addLocalizationBulk(for: route.blockers) }
                        }
                        .disabled(bulkLocalizationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingLocalization)
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
            unifiedIngredients = []
            return
        }

        coverageBlockers = await supabaseService.fetchCatalogCoverageBlockers(
            limit: 30,
            focusAliasLocalization: true
        )
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

    @MainActor
    private func addLocalization(for blocker: CatalogCoverageBlockerRecord) async {
        guard isAdminUser else { return }
        guard let ingredientID = blocker.canonicalCandidateIngredientID else { return }
        isAddingLocalization = true
        defer { isAddingLocalization = false }

        do {
            let status = try await supabaseService.addIngredientLocalization(
                ingredientID: ingredientID,
                text: localizationText,
                languageCode: localizationLanguageCode
            )

            switch status {
            case "inserted":
                actionMessage = "Localization added for \(blocker.normalizedText)."
            case "already_exists", "language_already_present":
                actionMessage = "Localization already present for \(blocker.normalizedText)."
            default:
                actionMessage = "Localization request completed (\(status))."
            }

            localizationRoute = nil
            await loadCandidates()
        } catch {
            errorMessage = "Failed to add localization."
            print("[SEASON_CATALOG_ADMIN] phase=add_localization_failed normalized_text=\(blocker.normalizedText) error=\(error)")
        }
    }

    @MainActor
    private func approveAliasBulk(for candidates: [CatalogResolutionCandidateRecord]) async {
        guard isAdminUser else { return }
        guard let ingredientID = bulkSelectedIngredientID else { return }
        isApproving = true
        defer { isApproving = false }

        var successCount = 0
        var failureCount = 0
        for candidate in candidates {
            do {
                try await supabaseService.approveCatalogAlias(
                    normalizedText: candidate.normalizedText,
                    ingredientID: ingredientID
                )
                successCount += 1
            } catch {
                failureCount += 1
                print("[SEASON_CATALOG_ADMIN] phase=bulk_approve_alias_failed normalized_text=\(candidate.normalizedText) error=\(error)")
            }
        }

        actionMessage = "Bulk alias: \(successCount) applied, \(failureCount) failed."
        bulkAliasRoute = nil
        clearSelections()
        await loadCandidates()
    }

    @MainActor
    private func addLocalizationBulk(for blockers: [CatalogCoverageBlockerRecord]) async {
        guard isAdminUser else { return }
        isAddingLocalization = true
        defer { isAddingLocalization = false }

        var successCount = 0
        var failureCount = 0

        for blocker in blockers {
            guard let ingredientID = blocker.canonicalCandidateIngredientID else {
                failureCount += 1
                continue
            }

            do {
                let status = try await supabaseService.addIngredientLocalization(
                    ingredientID: ingredientID,
                    text: bulkLocalizationText,
                    languageCode: bulkLocalizationLanguageCode
                )
                if status == "inserted" || status == "already_exists" || status == "language_already_present" {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            } catch {
                failureCount += 1
                print("[SEASON_CATALOG_ADMIN] phase=bulk_add_localization_failed normalized_text=\(blocker.normalizedText) error=\(error)")
            }
        }

        actionMessage = "Bulk localization: \(successCount) applied, \(failureCount) failed."
        bulkLocalizationRoute = nil
        clearSelections()
        await loadCandidates()
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

    private var selectedLocalizationBlockers: [CatalogCoverageBlockerRecord] {
        selectedCoverageBlockers.filter {
            $0.likelyFixType == "localization" && $0.canonicalCandidateIngredientID != nil
        }
    }

    private var canRunBulkLocalization: Bool {
        guard !selectedLocalizationBlockers.isEmpty else { return false }
        let ids = Set(selectedLocalizationBlockers.compactMap { $0.canonicalCandidateIngredientID })
        return ids.count == 1
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
