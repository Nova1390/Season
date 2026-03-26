import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var query = ""
    @State private var selectedSmartChip: SearchSmartChip?

    var body: some View {
        List {
            if isQueryEmpty, let decision = decisionHook {
                decisionHookRow(decision)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            smartSuggestionChipsRow
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isQueryEmpty {
                discoverySections
            } else {
                let ingredientResults = viewModel.searchIngredientResults(query: query)
                let recipeResults = smartRankedRecipeResults(query: query)
                let primaryType = viewModel.searchPrimaryType(for: query)

                if ingredientResults.isEmpty && recipeResults.isEmpty {
                    noResultsSection
                } else {
                    if primaryType == .recipes {
                        recipesSection(results: recipeResults)
                        ingredientsSection(results: ingredientResults)
                    } else {
                        ingredientsSection(results: ingredientResults)
                        recipesSection(results: recipeResults)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SeasonColors.primarySurface)
        .navigationTitle(viewModel.localizer.text(.searchTab))
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .searchable(text: $query, prompt: viewModel.localizer.text(.searchPlaceholder))
    }

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var smartSuggestionChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SeasonSpacing.xs) {
                ForEach(SearchSmartChip.allCases) { chip in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSmartChip = (selectedSmartChip == chip) ? nil : chip
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: chip.iconName)
                                .font(.caption.weight(.semibold))
                            Text(chip.title(localizer: viewModel.localizer))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedSmartChip == chip ? .primary : .secondary)
                        .seasonCapsuleChipStyle(
                            horizontalPadding: 11,
                            verticalPadding: 8,
                            background: selectedSmartChip == chip
                                ? SeasonColors.secondarySurface
                                : SeasonColors.subtleSurface
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var discoverySections: some View {
        let homeRanked = presentableRecipes(from: viewModel.homeRankedRecipes(limit: 120))
        let filtered = applySmartChipFilter(to: homeRanked)

        if let selectedSmartChip {
            Section(header: SectionTitleCountRow(
                title: selectedSmartChip.discoverySectionTitle(localizer: viewModel.localizer),
                countText: recipeCountText(filtered.count)
            ).textCase(nil)) {
                ForEach(Array(filtered.prefix(8))) { ranked in
                    discoveryRecipeRow(ranked)
                }
            }
        } else {
            let fridge = Array(recipesFromFridge(limit: 4))
            let recent = Array(recentlyViewedRecipes(limit: 4))
            let quick = Array(quickMealRecipes(from: filtered, limit: 4))
            let seasonal = Array(seasonalRecipes(from: filtered, limit: 4))
            let trending = Array(presentableRecipes(from: viewModel.rankedTrendingNowRecipes(limit: 4)))

            let sections = buildDiscoverySections(
                fridge: fridge,
                recent: recent,
                quick: quick,
                seasonal: seasonal,
                trending: trending
            )
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                recipeDiscoverySection(
                    title: section.title,
                    results: section.results,
                    emphasizeFirst: section.emphasizeFirst,
                    topPadding: index == 0 ? SeasonSpacing.sm : 0
                )
            }
        }
    }

    @ViewBuilder
    private func recipeDiscoverySection(
        title: String,
        results: [RankedRecipe],
        emphasizeFirst: Bool = false,
        topPadding: CGFloat = 0
    ) -> some View {
        Section(header: SectionTitleCountRow(
            title: title,
            countText: recipeCountText(results.count)
        ).textCase(nil)) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, ranked in
                discoveryRecipeRow(ranked, bestMatch: emphasizeFirst && index == 0)
            }
        }
        .padding(.top, topPadding)
    }

    @ViewBuilder
    private func discoveryRecipeRow(_ ranked: RankedRecipe, bestMatch: Bool = false) -> some View {
        NavigationLink {
            RecipeDetailView(
                rankedRecipe: ranked,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        } label: {
            SearchRecipeRow(
                ranked: ranked,
                viewModel: viewModel,
                bestMatch: bestMatch
            )
        }
        .buttonStyle(.plain)
        .listRowSeparator(.visible)
        .listRowBackground(Color.clear)
        .padding(.vertical, 4)
    }

    private var noResultsSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            EmptyStateCard(
                symbol: "magnifyingglass.circle",
                title: viewModel.localizer.text(.searchEmptyTitle),
                subtitle: "Try a smart suggestion like In season or 15 min."
            )

            Text("Suggestions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SeasonSpacing.xs) {
                    ForEach(SearchSmartChip.allCases) { chip in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedSmartChip = chip
                                query = ""
                            }
                        } label: {
                            SeasonBadge(
                                text: chip.title(localizer: viewModel.localizer),
                                icon: chip.iconName,
                                horizontalPadding: 10,
                                verticalPadding: 6,
                                cornerRadius: SeasonRadius.small,
                                foreground: .secondary,
                                background: SeasonColors.subtleSurface
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, SeasonSpacing.sm)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func smartRankedRecipeResults(query: String) -> [RankedRecipe] {
        let baseResults = presentableRecipes(from: viewModel.searchRecipeResults(query: query))
        guard !baseResults.isEmpty else { return [] }

        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        let personalizationProfile = FeedPersonalizationService.shared.buildProfile(
            from: viewModel.homeRankedRecipes(limit: 120)
        )
        let denominator = Double(max(1, baseResults.count - 1))

        return baseResults.enumerated()
            .map { index, ranked in
                let textScore = denominator == 0 ? 1.0 : max(0.0, 1.0 - (Double(index) / denominator))
                let seasonalScore = Double(ranked.seasonalMatchPercent) / 100.0
                let popularityScore = (0.6 * viewModel.crispyScore(for: ranked.recipe)) + (0.4 * viewModel.viewsScore(for: ranked.recipe))
                let fridgeScore = fridgeIDs.isEmpty ? 0.0 : viewModel.fridgeMatchScore(for: ranked.recipe, fridgeItemIDs: fridgeIDs)
                let personalization = personalizationProfile.evaluation(for: ranked, fridgeMatchScore: fridgeScore).adjustment
                let chipBoost = selectedSmartChip.map {
                    smartChipBoost(
                        for: $0,
                        ranked: ranked,
                        fridgeScore: fridgeScore
                    )
                } ?? 0

                // Text relevance remains dominant.
                let score = (0.72 * textScore)
                    + (0.10 * seasonalScore)
                    + (0.10 * popularityScore)
                    + (0.06 * fridgeScore)
                    + (0.06 * personalization)
                    + chipBoost
                return (ranked: ranked, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }
            .map(\.ranked)
    }

    private func smartChipBoost(
        for chip: SearchSmartChip,
        ranked: RankedRecipe,
        fridgeScore: Double
    ) -> Double {
        let totalMinutes = (ranked.recipe.prepTimeMinutes ?? 0) + (ranked.recipe.cookTimeMinutes ?? 0)
        let quickness = totalMinutes > 0 ? max(0.0, 1.0 - (Double(totalMinutes) / 35.0)) : 0.25
        let seasonal = Double(ranked.seasonalMatchPercent) / 100.0
        let popularity = (0.6 * viewModel.crispyScore(for: ranked.recipe)) + (0.4 * viewModel.viewsScore(for: ranked.recipe))

        switch chip {
        case .inSeason:
            return 0.12 * seasonal
        case .under15:
            return 0.14 * quickness
        case .fromFridge:
            return 0.14 * fridgeScore
        case .highProtein:
            guard let summary = viewModel.recipeNutritionSummary(for: ranked.recipe) else { return 0 }
            return 0.12 * min(max(summary.protein / 20.0, 0), 1)
        case .trending:
            return 0.12 * popularity
        }
    }

    private func applySmartChipFilter(to recipes: [RankedRecipe]) -> [RankedRecipe] {
        guard let selectedSmartChip else { return recipes }

        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        switch selectedSmartChip {
        case .inSeason:
            return recipes.filter { $0.seasonalMatchPercent >= 70 }
        case .under15:
            return recipes.filter {
                let total = ($0.recipe.prepTimeMinutes ?? 0) + ($0.recipe.cookTimeMinutes ?? 0)
                return total > 0 && total <= 15
            }
        case .fromFridge:
            guard !fridgeIDs.isEmpty else { return [] }
            return recipes
                .filter { viewModel.fridgeMatchScore(for: $0.recipe, fridgeItemIDs: fridgeIDs) >= 0.35 }
        case .highProtein:
            return recipes.filter {
                guard let summary = viewModel.recipeNutritionSummary(for: $0.recipe) else { return false }
                return summary.protein >= 12
            }
        case .trending:
            let trendingIDs = Set(viewModel.rankedTrendingNowRecipes(limit: 80).map(\.recipe.id))
            return recipes.filter { trendingIDs.contains($0.recipe.id) }
        }
    }

    private func recentlyViewedRecipes(limit: Int) -> [RankedRecipe] {
        let events = UserInteractionTracker.shared.recentEvents()
            .reversed()
            .filter { $0.eventType == .recipeOpened || $0.eventType == .recipeViewed }
        var seen = Set<String>()
        var results: [RankedRecipe] = []
        for event in events {
            guard let recipeID = event.recipeID else { continue }
            guard !seen.contains(recipeID) else { continue }
            guard let ranked = viewModel.rankedRecipe(forID: recipeID), isPresentableRecipe(ranked.recipe) else { continue }
            seen.insert(recipeID)
            results.append(ranked)
            if results.count >= limit { break }
        }
        return results
    }

    private func recipesFromFridge(limit: Int) -> [RankedRecipe] {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        guard !fridgeIDs.isEmpty else { return [] }
        return presentableRecipes(from: viewModel
            .rankedRecipesForFridge(fridgeItemIDs: fridgeIDs, limit: max(1, limit))
            .map(\.rankedRecipe))
    }

    private func quickMealRecipes(from recipes: [RankedRecipe], limit: Int) -> [RankedRecipe] {
        Array(
            recipes
                .filter {
                    let total = ($0.recipe.prepTimeMinutes ?? 0) + ($0.recipe.cookTimeMinutes ?? 0)
                    return total > 0 && total <= 15
                }
                .prefix(limit)
        )
    }

    private func seasonalRecipes(from recipes: [RankedRecipe], limit: Int) -> [RankedRecipe] {
        Array(recipes.filter { $0.seasonalMatchPercent >= 80 }.prefix(limit))
    }

    private var decisionHook: SearchDecisionHook? {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        let fridgeMatches = viewModel.matchedRecipesForFridge(fridgeItemIDs: fridgeIDs)
            .filter { isPresentableRecipe($0.rankedRecipe.recipe) }
        let readyCount = fridgeMatches.filter { $0.missingCount == 0 }.count

        if readyCount > 0 {
            let noun = readyCount == 1 ? "recipe" : "recipes"
            let verb = readyCount == 1 ? "is" : "are"
            return SearchDecisionHook(
                title: "You can cook tonight",
                subtitle: "\(readyCount) \(noun) \(verb) ready with your fridge"
            )
        }

        guard let best = presentableRecipes(from: viewModel.homeRankedRecipes(limit: 1)).first else { return nil }
        return SearchDecisionHook(
            title: "Best match right now",
            subtitle: "\(best.recipe.title) • \(best.seasonalMatchPercent)% match"
        )
    }

    @ViewBuilder
    private func decisionHookRow(_ hook: SearchDecisionHook) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hook.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(hook.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, SeasonSpacing.xs)
        .padding(.bottom, SeasonSpacing.xs)
    }

    private func buildDiscoverySections(
        fridge: [RankedRecipe],
        recent: [RankedRecipe],
        quick: [RankedRecipe],
        seasonal: [RankedRecipe],
        trending: [RankedRecipe]
    ) -> [SearchDiscoverySection] {
        var sections: [SearchDiscoverySection] = []

        if !fridge.isEmpty {
            sections.append(
                SearchDiscoverySection(
                    title: "From your fridge",
                    results: fridge,
                    emphasizeFirst: true,
                    isPriority: true
                )
            )
        }
        if !quick.isEmpty {
            sections.append(
                SearchDiscoverySection(
                    title: "Quick meals",
                    results: quick,
                    emphasizeFirst: false,
                    isPriority: true
                )
            )
        } else if !seasonal.isEmpty {
            sections.append(
                SearchDiscoverySection(
                    title: "Seasonal picks",
                    results: seasonal,
                    emphasizeFirst: false,
                    isPriority: true
                )
            )
        }

        if !recent.isEmpty {
            sections.append(
                SearchDiscoverySection(
                    title: "Recently viewed",
                    results: recent,
                    emphasizeFirst: false,
                    isPriority: false
                )
            )
        }
        if !seasonal.isEmpty && !sections.contains(where: { $0.title == "Seasonal picks" }) {
            sections.append(
                SearchDiscoverySection(
                    title: "Seasonal picks",
                    results: seasonal,
                    emphasizeFirst: false,
                    isPriority: false
                )
            )
        }
        if !trending.isEmpty {
            sections.append(
                SearchDiscoverySection(
                    title: viewModel.localizer.text(.trendingNowTitle),
                    results: trending,
                    emphasizeFirst: false,
                    isPriority: false
                )
            )
        }

        // Keep the first viewport focused: at most two priority sections first.
        let priority = sections.filter(\.isPriority).prefix(2)
        let rest = sections.filter { !$0.isPriority }
        let prioritizedTitles = Set(priority.map(\.title))
        let nonPriorityUnique = rest.filter { !prioritizedTitles.contains($0.title) }
        return Array(priority) + nonPriorityUnique
    }

    private func presentableRecipes(from recipes: [RankedRecipe]) -> [RankedRecipe] {
        recipes.filter { isPresentableRecipe($0.recipe) }
    }

    private func isPresentableRecipe(_ recipe: Recipe) -> Bool {
        recipe.isFeedEligible
    }

    @ViewBuilder
    private func ingredientsSection(results: [IngredientSearchResult]) -> some View {
        if !results.isEmpty {
            Section(header: SectionTitleCountRow(
                title: viewModel.localizer.text(.ingredients),
                countText: ingredientCountText(results.count)
            ).textCase(nil)) {
                ForEach(results) { result in
                    HStack(alignment: .center, spacing: 12) {
                        ingredientThumbnail(for: result)

                        NavigationLink {
                            ingredientDestination(for: result)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if case .produce(let item) = result.source {
                            SeasonalStatusBadge(
                                score: item.seasonalityScore(month: viewModel.currentMonth),
                                delta: item.seasonalityDelta(month: viewModel.currentMonth),
                                localizer: viewModel.localizer
                            )
                        }

                        quickAddIngredientButton(for: result)
                    }
                    .padding(.vertical, 6)
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    @ViewBuilder
    private func recipesSection(results: [RankedRecipe]) -> some View {
        if !results.isEmpty {
            Section(header: SectionTitleCountRow(
                title: viewModel.localizer.text(.recipes),
                countText: recipeCountText(results.count)
            ).textCase(nil)) {
                ForEach(results) { ranked in
                    VStack(alignment: .leading, spacing: 6) {
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: ranked,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            SearchRecipeRow(
                                ranked: ranked,
                                viewModel: viewModel,
                                bestMatch: false
                            )
                        }
                        .buttonStyle(.plain)

                        let confirmedDietaryTags = viewModel.confirmedDietaryTags(for: ranked.recipe)
                        if !confirmedDietaryTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(confirmedDietaryTags) { tag in
                                        RecipeDietaryTagPill(tag: tag, localizer: viewModel.localizer)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func recipeCountText(_ count: Int) -> String {
        "\(count.compactFormatted()) \(viewModel.localizer.text(.recipes).lowercased())"
    }

    private func ingredientCountText(_ count: Int) -> String {
        "\(count.compactFormatted()) \(viewModel.localizer.text(.ingredients).lowercased())"
    }

    @ViewBuilder
    private func quickAddIngredientButton(for result: IngredientSearchResult) -> some View {
        let isInList = ingredientIsInList(result)

        Button {
            switch result.source {
            case .produce(let item):
                shoppingListViewModel.add(item)
            case .basic(let basic):
                shoppingListViewModel.add(basic)
            }
        } label: {
            Image(systemName: isInList ? "checkmark" : "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(isInList ? Color.green : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(SeasonColors.subtleSurface)
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .disabled(isInList)
    }

    private func ingredientIsInList(_ result: IngredientSearchResult) -> Bool {
        switch result.source {
        case .produce(let item):
            return shoppingListViewModel.contains(item)
        case .basic(let basic):
            return shoppingListViewModel.contains(basic)
        }
    }

    @ViewBuilder
    private func ingredientDestination(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceDetailView(
                item: item,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        case .basic(let basic):
            ProduceDetailView(
                basicIngredient: basic,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    @ViewBuilder
    private func ingredientThumbnail(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceThumbnailView(item: item, size: 46)
        case .basic:
            Image(systemName: "leaf")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        }
    }

}

private enum SearchSmartChip: String, CaseIterable, Identifiable {
    case inSeason
    case under15
    case fromFridge
    case highProtein
    case trending

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .inSeason: return "leaf"
        case .under15: return "timer"
        case .fromFridge: return "snowflake"
        case .highProtein: return "bolt"
        case .trending: return "flame"
        }
    }

    func title(localizer: AppLocalizer) -> String {
        switch self {
        case .inSeason:
            return "In season now"
        case .under15:
            return "Ready in 15 min"
        case .fromFridge:
            return "From your fridge"
        case .highProtein:
            return localizer.text(.reasonHighProtein)
        case .trending:
            return "Trending now"
        }
    }

    func discoverySectionTitle(localizer: AppLocalizer) -> String {
        switch self {
        case .inSeason:
            return "In season"
        case .under15:
            return "Quick meals"
        case .fromFridge:
            return "From your fridge"
        case .highProtein:
            return "High protein"
        case .trending:
            return localizer.text(.trendingNowTitle)
        }
    }
}

private struct SearchRecipeRow: View {
    let ranked: RankedRecipe
    let viewModel: ProduceViewModel
    let bestMatch: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RecipeThumbnailView(recipe: ranked.recipe, size: 44)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(ranked.recipe.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(ranked.recipe.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if bestMatch {
                    SeasonBadge(
                        text: "Best match",
                        horizontalPadding: 7,
                        verticalPadding: 3,
                        cornerRadius: SeasonRadius.small,
                        foreground: .primary,
                        background: SeasonColors.secondarySurface
                    )
                }

                SeasonBadge(
                    text: "\(ranked.seasonalMatchPercent)%",
                    horizontalPadding: 7,
                    verticalPadding: 4,
                    cornerRadius: 7,
                    foreground: .secondary,
                    background: SeasonColors.subtleSurface
                )
            }
        }
    }
}

private struct SearchDiscoverySection {
    let title: String
    let results: [RankedRecipe]
    let emphasizeFirst: Bool
    let isPriority: Bool
}

private struct SearchDecisionHook {
    let title: String
    let subtitle: String
}
