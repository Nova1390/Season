import SwiftUI

enum FridgeViewMode {
    case inventory
    case recipes
}

struct FridgeView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var fridgeViewModel: FridgeViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @State private var query = ""
    @State private var selectedSortControl: FridgeSortControl = .freshness
    @State private var selectedMode: FridgeViewMode
    @State private var showSearchField = false
    @State private var addMissingMessage = ""
    @State private var showingAddMissingAlert = false
    private let emptyQueryAddableLimit = 10

    init(
        produceViewModel: ProduceViewModel,
        fridgeViewModel: FridgeViewModel,
        shoppingListViewModel: ShoppingListViewModel,
        initialMode: FridgeViewMode = .inventory
    ) {
        self.produceViewModel = produceViewModel
        self.fridgeViewModel = fridgeViewModel
        self.shoppingListViewModel = shoppingListViewModel
        _selectedMode = State(initialValue: initialMode)
    }

    var body: some View {
        let addableResults = resolvedAddableResults
        let isAddSearchMode = isAddIngredientSearchMode

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                fridgeTopHeader

                if isAddSearchMode {
                    addIngredientSection(addableResults: addableResults)
                } else {
                    modePicker

                    switch selectedMode {
                    case .inventory:
                        fridgeSection
                        addIngredientSection(addableResults: addableResults)
                    case .recipes:
                        fridgeRecipesSection
                    }
                }
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance)
        }
        .background(SeasonColors.primarySurface)
        .seasonTopBar(
            produceViewModel: produceViewModel,
            shoppingListViewModel: shoppingListViewModel,
            leading: .back
        )
        .searchable(
            text: $query,
            isPresented: $showSearchField,
            prompt: produceViewModel.localizer.text(.searchPlaceholder)
        )
        .alert(addMissingMessage, isPresented: $showingAddMissingAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private var resolvedAddableResults: [IngredientSearchResult] {
        let results = produceViewModel.searchIngredientResults(query: query)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty else { return results }
        return Array(results.prefix(emptyQueryAddableLimit))
    }

    private var isAddIngredientSearchMode: Bool {
        showSearchField || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var fridgeEntries: [FridgeEntry] {
        let produce = fridgeViewModel.produceItems.map { FridgeEntry.produce($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer) }
        let basic = fridgeViewModel.basicItems.map { FridgeEntry.basic($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer) }
        let catalog = fridgeViewModel.catalogFridgeItems.map { FridgeEntry.catalog($0, localizer: produceViewModel.localizer) }
        let custom = fridgeViewModel.customFridgeItems.map { FridgeEntry.custom($0, localizer: produceViewModel.localizer) }

        switch selectedSortControl {
        case .alphabetical:
            return (produce + basic + catalog + custom)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .freshness:
            // Approximate freshness using local insertion order (most recently added first).
            return Array(produce.reversed()) + Array(basic.reversed()) + Array(catalog.reversed()) + Array(custom.reversed())
        }
    }

    private var fridgeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitleCountRow(
                    title: produceViewModel.localizer.text(.fridgePreviewTitle),
                    countText: "\(fridgeEntries.count)"
                )
                Spacer(minLength: 8)
                sortControl
            }

            if fridgeEntries.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateCard(
                        symbol: "snowflake",
                        title: produceViewModel.localizer.text(.fridgeEmptyTitle),
                        subtitle: produceViewModel.localizer.text(.fridgeEmptySubtitle)
                    )

                    Button {
                        showSearchField = true
                    } label: {
                        Text(produceViewModel.localizer.text(.addIngredients))
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(SeasonPrimaryButtonStyle())
                }
                .padding(SeasonSpacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.92))
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(fridgeEntries) { entry in
                        fridgeEntryRow(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            modePickerButton(
                mode: .inventory,
                title: produceViewModel.localizer.text(.fridgeTab),
                systemImage: "snowflake"
            )
            modePickerButton(
                mode: .recipes,
                title: produceViewModel.localizer.text(.recipes),
                systemImage: "fork.knife"
            )
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.88))
        )
    }

    private func modePickerButton(mode: FridgeViewMode, title: String, systemImage: String) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? DS.Color.sageDeep : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var fridgeRecipeMatches: [FridgeMatchedRecipe] {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        guard !fridgeIDs.isEmpty else { return [] }
        return produceViewModel
            .rankedFridgeRecommendations(fridgeItemIDs: fridgeIDs)
            .filter { $0.totalCount > 0 && $0.matchingCount > 0 }
    }

    private var readyNowMatches: [FridgeMatchedRecipe] {
        fridgeRecipeMatches.filter { $0.missingCount == 0 }
    }

    private var oneMissingMatches: [FridgeMatchedRecipe] {
        fridgeRecipeMatches.filter { $0.missingCount == 1 }
    }

    private var almostReadyMatches: [FridgeMatchedRecipe] {
        fridgeRecipeMatches.filter { $0.missingCount > 1 }
    }

    private var fridgeRecipesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitleCountRow(
                    title: produceViewModel.localizer.localized("fridge.recipes.title"),
                    countText: "\(fridgeRecipeMatches.count)"
                )
                Text(produceViewModel.localizer.localized("fridge.recipes.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if fridgeViewModel.allItemCount == 0 {
                fridgeRecipesEmptyState(
                    title: produceViewModel.localizer.localized("fridge.recipes.empty_fridge.title"),
                    subtitle: produceViewModel.localizer.localized("fridge.recipes.empty_fridge.subtitle"),
                    actionTitle: produceViewModel.localizer.text(.addIngredients)
                ) {
                    selectedMode = .inventory
                    showSearchField = true
                }
            } else if fridgeRecipeMatches.isEmpty {
                fridgeRecipesEmptyState(
                    title: produceViewModel.localizer.localized("fridge.recipes.no_matches.title"),
                    subtitle: produceViewModel.localizer.localized("fridge.recipes.no_matches.subtitle"),
                    actionTitle: produceViewModel.localizer.text(.addIngredients)
                ) {
                    selectedMode = .inventory
                    showSearchField = true
                }
            } else {
                fridgeRecipeGroup(
                    title: produceViewModel.localizer.text(.readyNow),
                    matches: readyNowMatches
                )
                fridgeRecipeGroup(
                    title: produceViewModel.localizer.localized("fridge.recipes.one_missing"),
                    matches: oneMissingMatches
                )
                fridgeRecipeGroup(
                    title: produceViewModel.localizer.localized("fridge.recipes.almost_ready"),
                    matches: almostReadyMatches
                )
            }
        }
    }

    private func fridgeRecipeGroup(title: String, matches: [FridgeMatchedRecipe]) -> some View {
        Group {
            if !matches.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    LazyVStack(spacing: 12) {
                        ForEach(matches) { match in
                            fridgeRecipeCard(match)
                        }
                    }
                }
            }
        }
    }

    private func fridgeRecipeCard(_ match: FridgeMatchedRecipe) -> some View {
        let ranked = match.rankedRecipe
        let missingIngredients = missingIngredients(for: ranked.recipe)
        return VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: ranked,
                    viewModel: produceViewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                HStack(spacing: 12) {
                    RecipeThumbnailView(recipe: ranked.recipe, size: 66)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(ranked.recipe.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(fridgeMatchSummary(for: match))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        if !missingIngredients.isEmpty {
                            Text(missingPreviewText(for: missingIngredients))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !missingIngredients.isEmpty {
                Button {
                    addMissingIngredients(missingIngredients, for: ranked.recipe)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.badge.plus")
                            .font(.caption.weight(.bold))
                        Text(produceViewModel.localizer.text(.addMissingAction))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(DS.Color.sageDeep)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Color.sageSoft.opacity(0.72))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func fridgeRecipesEmptyState(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            EmptyStateCard(
                symbol: "fork.knife.circle",
                title: title,
                subtitle: subtitle
            )

            Button(action: action) {
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SeasonPrimaryButtonStyle())
        }
        .padding(SeasonSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
        )
    }

    private func addIngredientSection(addableResults: [IngredientSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleCountRow(
                title: produceViewModel.localizer.text(.addIngredient),
                countText: String(
                    format: produceViewModel.localizer.text(.ingredientsCountFormat),
                    addableResults.count
                )
            )

            if addableResults.isEmpty {
                EmptyStateCard(
                    symbol: "magnifyingglass",
                    title: produceViewModel.localizer.text(.searchTab),
                    subtitle: produceViewModel.localizer.text(.searchPlaceholder)
                )
                .padding(SeasonSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SeasonColors.secondarySurface.opacity(0.62))
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(addableResults) { item in
                        addIngredientRow(item)
                    }
                }
                .padding(SeasonSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SeasonColors.secondarySurface.opacity(0.62))
                )
            }
        }
    }

    @ViewBuilder
    private func fridgeEntryRow(_ entry: FridgeEntry) -> some View {
        HStack(spacing: 12) {
            switch entry.source {
            case .produce(let item):
                ProduceThumbnailView(item: item, size: 46)
            case .basic, .catalog:
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "leaf")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            case .custom:
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "text.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive) {
                removeFromFridge(entry)
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title3)
                    .frame(width: 28, height: 28)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(produceViewModel.localizer.text(.remove))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.7)
        )
        .contentShape(Rectangle())
    }

    private var fridgeTopHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(produceViewModel.localizer.localized("fridge.header.harvest"))
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                    .foregroundStyle(.secondary)
                    Text(produceViewModel.localizer.text(.fridgeTab))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button {
                    showSearchField = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text(produceViewModel.localizer.text(.addIngredients))
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(SeasonPrimaryButtonStyle())
            }

            HStack {
                Text(
                    String(
                        format: produceViewModel.localizer.localized("fridge.header.items_count_format"),
                        fridgeEntries.count
                    )
                )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(SeasonSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .padding(.top, 2)
    }

    private var sortControl: some View {
        Menu {
            Button {
                selectedSortControl = .freshness
            } label: {
                Label(
                    produceViewModel.localizer.localized("fridge.sort.default"),
                    systemImage: selectedSortControl == .freshness ? "checkmark" : ""
                )
            }
            Button {
                selectedSortControl = .alphabetical
            } label: {
                Label(
                    produceViewModel.localizer.localized("fridge.sort.az"),
                    systemImage: selectedSortControl == .alphabetical ? "checkmark" : ""
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                Text(selectedSortControl.label(localizer: produceViewModel.localizer))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(SeasonColors.secondarySurface)
            )
        }
    }

    @ViewBuilder
    private func addIngredientRow(_ item: IngredientSearchResult) -> some View {
        HStack(spacing: 12) {
            ingredientThumbnail(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let hasItem = isInFridge(item)

            Button {
                addToFridge(item)
            } label: {
                Image(systemName: hasItem ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(hasItem ? SeasonColors.seasonGreen : Color.primary.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .disabled(hasItem)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.7)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func ingredientThumbnail(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceThumbnailView(item: item, size: 46)
        case .basic:
            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "leaf")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private func isInFridge(_ result: IngredientSearchResult) -> Bool {
        switch result.source {
        case .produce(let item):
            return fridgeViewModel.contains(item)
        case .basic(let basic):
            return fridgeViewModel.contains(basic)
        }
    }

    private func addToFridge(_ result: IngredientSearchResult) {
        switch result.source {
        case .produce(let item):
            fridgeViewModel.add(item)
        case .basic(let basic):
            fridgeViewModel.add(basic)
        }
    }

    private func isAvailableInFridge(_ ingredient: RecipeIngredient) -> Bool {
        if let ingredientID = ingredient.ingredientID,
           fridgeViewModel.allIngredientIDSet.contains(ingredientID) {
            return true
        }

        if let produceID = ingredient.produceID,
           fridgeViewModel.allIngredientIDSet.contains(produceID) {
            return true
        }

        if let basicID = ingredient.basicIngredientID,
           fridgeViewModel.allIngredientIDSet.contains(basicID) {
            return true
        }

        return false
    }

    private func missingIngredients(for recipe: Recipe) -> [RecipeIngredient] {
        recipe.ingredients.filter { !isAvailableInFridge($0) }
    }

    private func fridgeMatchSummary(for match: FridgeMatchedRecipe) -> String {
        if match.missingCount == 0 {
            return produceViewModel.localizer.text(.readyNow)
        }

        return String(
            format: produceViewModel.localizer.text(.onlyMissingFormat),
            match.missingCount
        )
    }

    private func missingPreviewText(for ingredients: [RecipeIngredient]) -> String {
        let names = ingredients
            .prefix(3)
            .map { $0.name }
            .joined(separator: ", ")
        if ingredients.count > 3 {
            return "\(produceViewModel.localizer.text(.missing)): \(names) +\(ingredients.count - 3)"
        }
        return "\(produceViewModel.localizer.text(.missing)): \(names)"
    }

    private func addMissingIngredients(_ ingredients: [RecipeIngredient], for recipe: Recipe) {
        let result = shoppingListViewModel.addAllRecipeIngredients(
            ingredients,
            sourceRecipeID: recipe.id,
            sourceRecipeTitle: recipe.title,
            produceLookup: { produceID in
                produceViewModel.produceItem(forID: produceID)
            },
            basicLookup: { basicID in
                produceViewModel.basicIngredient(forID: basicID)
            }
        )
        addMissingMessage = produceViewModel.ingredientsAddFeedbackText(
            added: result.added,
            alreadyInList: result.alreadyInList
        )
        showingAddMissingAlert = true
    }

    private func removeFromFridge(_ entry: FridgeEntry) {
        switch entry.source {
        case .produce(let item):
            fridgeViewModel.remove(item)
        case .basic(let basic):
            fridgeViewModel.remove(basic)
        case .catalog(let catalog):
            fridgeViewModel.removeCatalog(ingredientID: catalog.ingredientID)
        case .custom(let custom):
            fridgeViewModel.removeCustom(named: custom.name)
        }
    }
}

private struct FridgeEntry: Identifiable {
    enum Source {
        case produce(ProduceItem)
        case basic(BasicIngredient)
        case catalog(FridgeCatalogItem)
        case custom(FridgeCustomItem)
    }

    let id: String
    let title: String
    let subtitle: String
    let source: Source

    static func produce(_ item: ProduceItem, languageCode: String, localizer: AppLocalizer) -> FridgeEntry {
        return FridgeEntry(
            id: "produce-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            subtitle: localizer.categoryTitle(for: item.category),
            source: .produce(item)
        )
    }

    static func basic(_ item: BasicIngredient, languageCode: String, localizer: AppLocalizer) -> FridgeEntry {
        return FridgeEntry(
            id: "basic-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            subtitle: localizer.text(.basicIngredient),
            source: .basic(item)
        )
    }

    static func custom(_ item: FridgeCustomItem, localizer: AppLocalizer) -> FridgeEntry {
        let subtitle = item.quantity?.isEmpty == false ? item.quantity! : localizer.text(.customIngredient)
        return FridgeEntry(
            id: item.id,
            title: item.name,
            subtitle: subtitle,
            source: .custom(item)
        )
    }

    static func catalog(_ item: FridgeCatalogItem, localizer: AppLocalizer) -> FridgeEntry {
        let subtitle = item.quantity?.isEmpty == false ? item.quantity! : localizer.text(.basicIngredient)
        return FridgeEntry(
            id: item.id,
            title: item.name,
            subtitle: subtitle,
            source: .catalog(item)
        )
    }
}

private enum FridgeSortControl {
    case freshness
    case alphabetical

    func label(localizer: AppLocalizer) -> String {
        switch self {
        case .freshness: return localizer.localized("fridge.sort.default")
        case .alphabetical: return localizer.localized("fridge.sort.az")
        }
    }
}
