import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var searchQuery = ""
    @State private var selectedScope: SearchResultScope = .recipes
    @State private var selectedFilter: SearchFilterChip?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                searchHeaderArea

                if isSearching {
                    activeSearchContent
                } else {
                    idleDiscoveryContent
                }
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.sm)
            .padding(.bottom, SeasonSpacing.xl)
        }
        .background(SeasonColors.primarySurface)
        .navigationTitle("Discovery")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var searchHeaderArea: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search recipes or ingredients...", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SeasonColors.subtleSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(isSearching ? 0.14 : 0.06), lineWidth: 0.8)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SeasonSpacing.xs) {
                    scopeChip(title: "Recipes", scope: .recipes)
                    scopeChip(title: "Ingredients", scope: .ingredients)
                    filterChip(title: "Fridge Ready", filter: .fridgeReady)
                    filterChip(title: "Seasonal", filter: .seasonal)
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private var activeSearchContent: some View {
        let ingredientResults = filteredIngredientSearchResults(query: searchQuery)
        let recipeResults = filteredRecipeSearchResults(query: searchQuery)

        if ingredientResults.isEmpty && recipeResults.isEmpty {
            noResultsSection
        } else {
            VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                Text("Results for \"\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if selectedScope == .recipes {
                    recipesSection(results: recipeResults)
                    ingredientsSection(results: ingredientResults)
                } else {
                    ingredientsSection(results: ingredientResults)
                    recipesSection(results: recipeResults)
                }
            }
        }
    }

    @ViewBuilder
    private var idleDiscoveryContent: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xl) {
            peakSeasonNowSection
            fromYourFridgeSection
            trendingNowSection
        }
    }

    private func scopeChip(title: String, scope: SearchResultScope) -> some View {
        Button {
            selectedScope = scope
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedScope == scope ? Color.white : .secondary)
                .seasonCapsuleChipStyle(
                    horizontalPadding: 14,
                    verticalPadding: 9,
                    background: selectedScope == scope ? SeasonColors.seasonGreen : SeasonColors.subtleSurface
                )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(title: String, filter: SearchFilterChip) -> some View {
        Button {
            selectedFilter = selectedFilter == filter ? nil : filter
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedFilter == filter ? Color.white : .secondary)
                .seasonCapsuleChipStyle(
                    horizontalPadding: 14,
                    verticalPadding: 9,
                    background: selectedFilter == filter ? SeasonColors.seasonGreen : SeasonColors.subtleSurface
                )
        }
        .buttonStyle(.plain)
    }

    private var peakSeasonNowSection: some View {
        let rankedIngredients = Array(viewModel.bestPicksToday(limit: 12))
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            HStack {
                Text("Peak Season Now")
                    .font(.title3.weight(.bold))
                Spacer()
                Text(viewModel.currentMonthName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color(red: 0.33, green: 0.38, blue: 0.28))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SeasonSpacing.md) {
                    ForEach(rankedIngredients) { ranked in
                        NavigationLink {
                            ProduceDetailView(
                                item: ranked.item,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            VStack(spacing: 7) {
                                peakSeasonIngredientThumbnail(for: ranked.item)
                                Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(recipeCountForIngredient(ranked.item.id)) recipes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 82)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.84))
        )
    }

    private func peakSeasonIngredientThumbnail(for item: ProduceItem) -> some View {
        let hasImage = resolvedProduceImageName(for: item) != nil

        return ZStack {
            if !hasImage {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.94, blue: 0.90),
                                Color(red: 0.90, green: 0.89, blue: 0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            if hasImage {
                ProduceThumbnailView(item: item, size: 68)
            } else {
                VStack(spacing: 4) {
                    CategoryIconView(category: item.category, size: 24)
                        .foregroundStyle(Color(red: 0.38, green: 0.42, blue: 0.34))
                    Text("Season Pick")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(red: 0.44, green: 0.47, blue: 0.40))
                }
            }
        }
        .frame(width: 74, height: 74)
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var fromYourFridgeSection: some View {
        let fridgeRecipes = Array(recipesFromFridge(limit: 1))
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            Text("From Your Fridge")
                .font(.title3.weight(.bold))

            if let ranked = fridgeRecipes.first {
                NavigationLink {
                    RecipeDetailView(
                        rankedRecipe: ranked,
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    SearchFridgeRecipeCard(
                        ranked: ranked,
                        viewModel: viewModel
                    )
                }
                .buttonStyle(.plain)
            } else {
                EmptyStateCard(
                    symbol: "snowflake",
                    title: "Add ingredients to your fridge",
                    subtitle: "We'll suggest recipes you can cook right away."
                )
            }
        }
    }

    private var trendingNowSection: some View {
        let trending = presentableRecipes(from: viewModel.rankedTrendingNowRecipes(limit: 6))
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            Text(viewModel.localizer.text(.trendingNowTitle))
                .font(.title3.weight(.bold))

            VStack(spacing: SeasonSpacing.xs) {
                ForEach(trending) { ranked in
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
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.84))
        )
    }

    private var noResultsSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            EmptyStateCard(
                symbol: "magnifyingglass.circle",
                title: viewModel.localizer.text(.searchEmptyTitle),
                subtitle: "Try adjusting scope or filters."
            )

            if selectedFilter != nil {
                Button {
                    selectedFilter = nil
                } label: {
                    Text("Clear filter")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .seasonCapsuleChipStyle(
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            background: SeasonColors.subtleSurface
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, SeasonSpacing.sm)
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

                // Text relevance remains dominant.
                let score = (0.72 * textScore)
                    + (0.10 * seasonalScore)
                    + (0.10 * popularityScore)
                    + (0.06 * fridgeScore)
                    + (0.06 * personalization)
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

    private func filteredRecipeSearchResults(query: String) -> [RankedRecipe] {
        let base = smartRankedRecipeResults(query: query)
        guard let selectedFilter else { return base }

        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        switch selectedFilter {
        case .seasonal:
            return base.filter { $0.seasonalMatchPercent >= 70 }
        case .fridgeReady:
            guard !fridgeIDs.isEmpty else { return [] }
            return base.filter { viewModel.fridgeMatchScore(for: $0.recipe, fridgeItemIDs: fridgeIDs) >= 0.35 }
        }
    }

    private func filteredIngredientSearchResults(query: String) -> [IngredientSearchResult] {
        let base = viewModel.searchIngredientResults(query: query)
        guard let selectedFilter else { return base }

        switch selectedFilter {
        case .fridgeReady:
            return base.filter { result in
                switch result.source {
                case .produce(let item):
                    return fridgeViewModel.contains(item)
                case .basic(let basic):
                    return fridgeViewModel.contains(basic)
                }
            }
        case .seasonal:
            return base.filter { result in
                switch result.source {
                case .produce(let item):
                    return item.seasonalityScore(month: viewModel.currentMonth) >= 0.22
                case .basic:
                    return true
                }
            }
        }
    }

    private func recipesFromFridge(limit: Int) -> [RankedRecipe] {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        guard !fridgeIDs.isEmpty else { return [] }
        return presentableRecipes(from: viewModel
            .rankedRecipesForFridge(fridgeItemIDs: fridgeIDs, limit: max(1, limit))
            .map(\.rankedRecipe))
    }

    private func recipeCountForIngredient(_ ingredientID: String) -> Int {
        viewModel.homeRankedRecipes(limit: 400)
            .filter { ranked in
                ranked.recipe.ingredients.contains { ingredient in
                    ingredient.produceID == ingredientID || ingredient.basicIngredientID == ingredientID
                }
            }
            .count
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
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                sectionHeader(
                    title: viewModel.localizer.text(.ingredients),
                    countText: ingredientCountText(results.count),
                    subtitle: "Ingredients matching your query"
                )
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
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.84))
            )
        }
    }

    @ViewBuilder
    private func recipesSection(results: [RankedRecipe]) -> some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                sectionHeader(
                    title: viewModel.localizer.text(.recipes),
                    countText: recipeCountText(results.count),
                    subtitle: "Recipe results ranked for relevance"
                )
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
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.84))
            )
        }
    }

    private func sectionHeader(title: String, countText: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(countText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private enum SearchResultScope: String, CaseIterable, Identifiable {
    case recipes
    case ingredients

    var id: String { rawValue }
}

private enum SearchFilterChip: String, CaseIterable, Identifiable {
    case fridgeReady
    case seasonal

    var id: String { rawValue }
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
                        semantic: .neutral,
                        horizontalPadding: 7,
                        verticalPadding: 3,
                        cornerRadius: SeasonRadius.small
                    )
                }

                SeasonBadge(
                    text: "Seasonal \(ranked.seasonalMatchPercent)%",
                    icon: "leaf.fill",
                    semantic: .positive,
                    horizontalPadding: 7,
                    verticalPadding: 4,
                    cornerRadius: 7
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}

private struct SearchFridgeRecipeCard: View {
    let ranked: RankedRecipe
    let viewModel: ProduceViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeThumbnailView(recipe: ranked.recipe, size: 96)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(ranked.recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(ranked.recipe.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    SeasonBadge(
                        text: "From fridge",
                        icon: "snowflake",
                        semantic: .positive,
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: 8
                    )
                    SeasonBadge(
                        text: "Seasonal \(ranked.seasonalMatchPercent)%",
                        icon: "leaf.fill",
                        semantic: .positive,
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: 8
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.6)
        )
    }
}
