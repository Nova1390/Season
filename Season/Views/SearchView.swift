import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var searchQuery = ""
    @State private var selectedMode: SearchMode = .recipes
    @State private var selectedFilter: SearchFilterChip?
    @State private var searchResultsCache: [SearchResultsCacheKey: SearchResultsSnapshot] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                searchHeaderArea

                if isSearching {
                    activeSearchContent
                } else {
                    idleDiscoveryContent
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance + DS.Spacing.xl)
        }
        .background(DS.Color.bg)
        .seasonTopBar(
            produceViewModel: viewModel,
            shoppingListViewModel: shoppingListViewModel
        )
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .onChange(of: selectedMode) { _, mode in
            if let activeFilter = selectedFilter, !availableFilters(for: mode).contains(activeFilter) {
                selectedFilter = nil
            }
        }
        .task(id: searchRequestKey) {
            await refreshSearchResults(for: searchRequestKey)
        }
    }

    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchRequestKey: SearchResultsCacheKey {
        SearchResultsCacheKey(
            query: normalizedSearchQuery,
            mode: selectedMode,
            filter: selectedFilter,
            languageCode: viewModel.languageCode,
            currentMonth: viewModel.currentMonth,
            rankingDataVersion: viewModel.rankingDataVersion,
            fridgeFingerprint: fridgeViewModel.allIngredientIDSet.sorted().joined(separator: "|")
        )
    }

    private var searchHeaderArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text(viewModel.localizer.localized("search.screen.title"))
                    .font(DS.Font.displayTitle)
                    .foregroundStyle(DS.Color.ink)

                Spacer()

                Text(viewModel.currentMonthName.uppercased())
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.8)
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Color.inkMuted)
                TextField(viewModel.localizer.localized("search.input.placeholder"), text: $searchQuery)
                    .font(DS.Font.sans(15, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                if isSearching {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Color.inkMuted)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(DS.Color.bgSub)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isSearching ? DS.Color.sage.opacity(0.32) : DS.Color.border, lineWidth: 1)
            )
            .dsShadow(.s1)

            searchScopeSelector

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableFilters(for: selectedMode)) { filter in
                        filterChip(title: filterTitle(for: filter), filter: filter)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var searchScopeSelector: some View {
        HStack(spacing: 8) {
            searchScopeButton(
                title: viewModel.localizer.localized("search.scope.recipes"),
                mode: .recipes,
                icon: "fork.knife"
            )
            searchScopeButton(
                title: viewModel.localizer.localized("search.scope.ingredients"),
                mode: .ingredients,
                icon: "leaf"
            )
        }
    }

    private func searchScopeButton(title: String, mode: SearchMode, icon: String) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(DS.Font.sans(13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? DS.Color.sageDeep : DS.Color.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? DS.Color.sageSoft.opacity(0.82) : DS.Color.cardSoft)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? DS.Color.sage.opacity(0.24) : DS.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    @ViewBuilder
    private var activeSearchContent: some View {
        let key = searchRequestKey

        if let snapshot = searchResultsCache[key] {
            switch snapshot.mode {
            case .recipes:
                if snapshot.recipeResults.isEmpty {
                    noResultsSection
                } else {
                    activeResultsContainer(query: snapshot.query) {
                        recipesSection(results: snapshot.recipeResults)
                    }
                }
            case .ingredients:
                if snapshot.ingredientResults.isEmpty {
                    noResultsSection
                } else {
                    activeResultsContainer(query: snapshot.query) {
                        ingredientsSection(results: snapshot.ingredientResults)
                    }
                }
            }
        } else {
            pendingSearchSection(query: key.query)
        }
    }

    private func refreshSearchResults(for key: SearchResultsCacheKey) async {
        guard !key.query.isEmpty else {
            searchResultsCache.removeAll(keepingCapacity: true)
            return
        }
        guard searchResultsCache[key] == nil else { return }

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
        } catch {
            return
        }

        guard !Task.isCancelled, key == searchRequestKey else { return }
        await Task.yield()

        let snapshot = buildSearchSnapshot(for: key)
        guard !Task.isCancelled, key == searchRequestKey else { return }

        searchResultsCache[key] = snapshot
        pruneSearchResultsCache(keeping: key)
    }

    private func buildSearchSnapshot(for key: SearchResultsCacheKey) -> SearchResultsSnapshot {
        switch key.mode {
        case .recipes:
            return SearchResultsSnapshot(
                key: key,
                recipeResults: filteredRecipeSearchResults(query: key.query, filter: key.filter),
                ingredientResults: []
            )
        case .ingredients:
            return SearchResultsSnapshot(
                key: key,
                recipeResults: [],
                ingredientResults: filteredIngredientSearchResults(query: key.query, filter: key.filter)
            )
        }
    }

    private func pruneSearchResultsCache(keeping activeKey: SearchResultsCacheKey) {
        guard searchResultsCache.count > 8 else { return }
        searchResultsCache = searchResultsCache.filter { key, _ in key == activeKey }
    }

    private func activeResultsContainer<Content: View>(
        query: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
            searchResultsHeader(query: query)
            content()
        }
    }

    private func pendingSearchSection(query: String) -> some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            searchResultsHeader(query: query)
            ProgressView()
                .controlSize(.small)
                .padding(.vertical, SeasonSpacing.xs)
        }
    }

    private func searchResultsHeader(query: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                String(
                    format: viewModel.localizer.localized("search.results_for_format"),
                    query
                )
            )
            .font(DS.Font.serif(22, weight: .medium))
            .foregroundStyle(DS.Color.ink)
            .lineLimit(2)

            Spacer()

            Text(selectedMode == .recipes
                 ? viewModel.localizer.localized("search.scope.recipes")
                 : viewModel.localizer.localized("search.scope.ingredients"))
                .font(DS.Font.mono(10, weight: .medium))
                .kerning(0.7)
                .textCase(.uppercase)
                .foregroundStyle(DS.Color.inkMuted)
        }
    }

    @ViewBuilder
    private var idleDiscoveryContent: some View {
        let fridgeRecipes = Array(recipesFromFridge(limit: 1))
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if selectedMode == .ingredients {
                peakSeasonNowSection
                if !fridgeRecipes.isEmpty {
                    fromYourFridgeSection(fridgeRecipes: fridgeRecipes)
                }
                trendingNowSection
            } else {
                if !fridgeRecipes.isEmpty {
                    fromYourFridgeSection(fridgeRecipes: fridgeRecipes)
                }
                peakSeasonNowSection
                trendingNowSection
            }
        }
    }

    private func filterChip(title: String, filter: SearchFilterChip) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = isSelected ? nil : filter
        } label: {
            Text(title)
                .font(DS.Font.sans(12, weight: .semibold))
                .foregroundStyle(isSelected ? DS.Color.sageDeep : DS.Color.inkSoft)
                .seasonCapsuleChipStyle(
                    horizontalPadding: 12,
                    verticalPadding: 8,
                    background: isSelected ? DS.Color.sageSoft.opacity(0.78) : DS.Color.card
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? DS.Color.sage.opacity(0.24) : DS.Color.borderM, lineWidth: 1)
                )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private func availableFilters(for mode: SearchMode) -> [SearchFilterChip] {
        switch mode {
        case .recipes:
            return [.fridgeReady, .seasonal]
        case .ingredients:
            return [.seasonal]
        }
    }

    private func filterTitle(for filter: SearchFilterChip) -> String {
        switch (selectedMode, filter) {
        case (.ingredients, .fridgeReady):
            return viewModel.localizer.localized("search.filter.in_fridge")
        case (_, .fridgeReady):
            return viewModel.localizer.localized("search.filter.fridge_ready")
        case (_, .seasonal):
            return viewModel.localizer.localized("search.filter.seasonal")
        }
    }

    private var peakSeasonNowSection: some View {
        let rankedIngredients = Array(viewModel.bestPicksToday(limit: 12))
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            HStack {
                Text(viewModel.localizer.localized("search.discovery.peak_season_now"))
                    .font(DS.Font.serif(24, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                Text(viewModel.currentMonthName.uppercased())
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.9)
                    .foregroundStyle(DS.Color.inkMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rankedIngredients) { ranked in
                        NavigationLink {
                            ProduceDetailView(
                                item: ranked.item,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            VStack(spacing: 6) {
                                peakSeasonIngredientThumbnail(for: ranked.item)
                                Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                                    .font(DS.Font.sans(11.5, weight: .semibold))
                                    .foregroundStyle(DS.Color.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                Text(
                                    String(
                                        format: viewModel.localizer.localized("search.discovery.recipes_count_format"),
                                        recipeCountForIngredient(ranked.item.id)
                                    )
                                )
                                    .font(DS.Font.mono(9, weight: .regular))
                                    .kerning(0.3)
                                    .foregroundStyle(DS.Color.inkMuted)
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(PressableCardButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.sageSoft.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Color.sage.opacity(0.12), lineWidth: 1)
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
                ProduceThumbnailView(item: item, size: 66)
            } else {
                VStack(spacing: 4) {
                    CategoryIconView(category: item.category, size: 24)
                        .foregroundStyle(DS.Color.sageDeep.opacity(0.72))
                }
            }
        }
        .frame(width: 72, height: 72)
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func fromYourFridgeSection(fridgeRecipes: [RankedRecipe]) -> some View {
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            sectionHeader(
                title: viewModel.localizer.localized("search.discovery.from_fridge"),
                countText: viewModel.localizer.localized("search.badge.from_fridge"),
                subtitle: nil
            )

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
                    title: viewModel.localizer.localized("search.discovery.empty_fridge.title"),
                    subtitle: viewModel.localizer.localized("search.discovery.empty_fridge.subtitle")
                )
            }
        }
    }

    private var trendingNowSection: some View {
        let trending = presentableRecipes(from: viewModel.rankedTrendingNowRecipes(limit: 6))
        return VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            sectionHeader(
                title: viewModel.localizer.text(.trendingNowTitle),
                countText: recipeCountText(trending.count),
                subtitle: viewModel.localizer.localized("search.section.recipes.subtitle")
            )

            VStack(spacing: 10) {
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
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
    }

    private var noResultsSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            EmptyStateCard(
                symbol: "magnifyingglass.circle",
                title: noResultsTitle,
                subtitle: viewModel.localizer.localized("search.no_results.subtitle")
            )

            HStack(spacing: SeasonSpacing.xs) {
                Button {
                    searchQuery = ""
                } label: {
                    Text(viewModel.localizer.localized("search.action.clear_query"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .seasonCapsuleChipStyle(
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            background: SeasonColors.subtleSurface
                        )
                }
                .buttonStyle(.plain)

                Button {
                    selectedMode = selectedMode == .recipes ? .ingredients : .recipes
                } label: {
                    Text(selectedMode == .recipes
                        ? viewModel.localizer.localized("search.action.switch_to_ingredients")
                        : viewModel.localizer.localized("search.action.switch_to_recipes")
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .seasonCapsuleChipStyle(
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            background: SeasonColors.subtleSurface
                        )
                }
                .buttonStyle(.plain)

                if selectedFilter != nil {
                    Button {
                        selectedFilter = nil
                    } label: {
                        Text(viewModel.localizer.localized("search.action.clear_filter"))
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
        }
        .padding(.vertical, SeasonSpacing.sm)
    }

    private var noResultsTitle: String {
        switch selectedMode {
        case .recipes:
            return viewModel.localizer.localized("search.no_results.recipes_title")
        case .ingredients:
            return viewModel.localizer.localized("search.no_results.ingredients_title")
        }
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

    private func filteredRecipeSearchResults(query: String, filter: SearchFilterChip?) -> [RankedRecipe] {
        let base = smartRankedRecipeResults(query: query)
        guard let filter else { return base }

        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        switch filter {
        case .seasonal:
            return base.filter { $0.seasonalMatchPercent >= 80 }
        case .fridgeReady:
            guard !fridgeIDs.isEmpty else { return [] }
            return base.filter { viewModel.fridgeMatchScore(for: $0.recipe, fridgeItemIDs: fridgeIDs) >= 0.50 }
        }
    }

    private func filteredIngredientSearchResults(query: String, filter: SearchFilterChip?) -> [IngredientSearchResult] {
        let base = viewModel.searchIngredientResults(query: query)
        guard let filter else { return base }

        switch filter {
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
                    return false
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
                    subtitle: viewModel.localizer.localized("search.section.ingredients.subtitle")
                )
                ForEach(results) { result in
                    HStack(alignment: .center, spacing: 12) {
                        NavigationLink {
                            ingredientDestination(for: result)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                ingredientThumbnail(for: result)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(DS.Font.sans(14, weight: .semibold))
                                        .foregroundStyle(DS.Color.ink)
                                    Text(result.subtitle)
                                        .font(DS.Font.sans(11.5))
                                        .foregroundStyle(DS.Color.inkMuted)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if case .produce(let item) = result.source {
                            searchIngredientSeasonBadge(for: item)
                        }

                        quickAddIngredientButton(for: result)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Color.cardSoft)
                    )
                    .contentShape(Rectangle())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 1)
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
                    subtitle: viewModel.localizer.localized("search.section.recipes.subtitle")
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
                        .buttonStyle(PressableCardButtonStyle())

                        let confirmedDietaryTags = Array(viewModel.confirmedDietaryTags(for: ranked.recipe).prefix(2))
                        if !confirmedDietaryTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(confirmedDietaryTags) { tag in
                                        SearchDietaryTagMiniPill(tag: tag, localizer: viewModel.localizer)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
        }
    }

    private func sectionHeader(title: String, countText: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DS.Font.serif(23, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                Text(countText)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkMuted)
            }
            if let subtitle {
                Text(subtitle)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.inkMuted)
            }
        }
    }

    private func recipeCountText(_ count: Int) -> String {
        "\(count.compactFormatted()) \(viewModel.localizer.text(.recipes).lowercased())"
    }

    private func ingredientCountText(_ count: Int) -> String {
        "\(count.compactFormatted()) \(viewModel.localizer.text(.ingredients).lowercased())"
    }

    private func recipeSeasonBadgeText(percent: Int) -> String {
        percent >= 70
            ? viewModel.localizer.localized("home.filter.peak_season")
            : viewModel.localizer.localized("search.filter.seasonal")
    }

    @ViewBuilder
    private func searchIngredientSeasonBadge(for item: ProduceItem) -> some View {
        let score = item.seasonalityScore(month: viewModel.currentMonth)
        let delta = item.seasonalityDelta(month: viewModel.currentMonth)
        let phase = ProduceItem.seasonalityPhase(score: score, delta: delta)

        if phase != .outOfSeason {
            SeasonBadge(
                text: viewModel.localizer.seasonalityPhaseTitle(phase),
                semantic: .positive,
                horizontalPadding: 7,
                verticalPadding: 4,
                cornerRadius: 8,
                foreground: DS.Color.sageDeep,
                background: DS.Color.sageSoft.opacity(0.58)
            )
            .fixedSize(horizontal: true, vertical: false)
        }
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
            Image(systemName: isInList ? "checkmark" : "bag.badge.plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isInList ? DS.Color.sageDeep : DS.Color.inkSoft)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isInList ? DS.Color.sageSoft.opacity(0.7) : DS.Color.card)
                )
                .overlay(
                    Circle()
                        .stroke(DS.Color.border, lineWidth: 0.8)
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
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
                .foregroundStyle(DS.Color.sageDeep.opacity(0.74))
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(DS.Color.sageSoft.opacity(0.48))
                )
        }
    }

}

private struct SearchResultsCacheKey: Hashable {
    let query: String
    let mode: SearchMode
    let filter: SearchFilterChip?
    let languageCode: String
    let currentMonth: Int
    let rankingDataVersion: Int
    let fridgeFingerprint: String
}

private struct SearchResultsSnapshot {
    let key: SearchResultsCacheKey
    let recipeResults: [RankedRecipe]
    let ingredientResults: [IngredientSearchResult]

    var query: String { key.query }
    var mode: SearchMode { key.mode }
}

private enum SearchMode: String, CaseIterable, Identifiable, Hashable {
    case recipes
    case ingredients

    var id: String { rawValue }
}

private enum SearchFilterChip: String, CaseIterable, Identifiable, Hashable {
    case fridgeReady
    case seasonal

    var id: String { rawValue }
}

private struct SearchDietaryTagMiniPill: View {
    let tag: RecipeDietaryTag
    let localizer: AppLocalizer

    var body: some View {
        Text(localizer.dietaryTagTitle(tag))
            .font(DS.Font.sans(10.5, weight: .medium))
            .foregroundStyle(DS.Color.inkMuted)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.Color.bgSub.opacity(0.7))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DS.Color.borderS, lineWidth: 0.6)
            )
    }
}

private struct SearchRecipeRow: View {
    let ranked: RankedRecipe
    let viewModel: ProduceViewModel
    let bestMatch: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RecipeThumbnailView(recipe: ranked.recipe, size: 54)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(ranked.recipe.title)
                    .font(DS.Font.sans(14.5, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(DS.Color.ink)

                Text(ranked.recipe.author)
                    .font(DS.Font.sans(11.5))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if bestMatch {
                    SeasonBadge(
                        text: viewModel.localizer.localized("search.badge.best_match"),
                        semantic: .neutral,
                        horizontalPadding: 7,
                        verticalPadding: 3,
                        cornerRadius: SeasonRadius.small
                    )
                }

                SeasonBadge(
                    text: recipeSeasonBadgeText(percent: ranked.seasonalMatchPercent),
                    icon: "leaf.fill",
                    semantic: .positive,
                    horizontalPadding: 7,
                    verticalPadding: 4,
                    cornerRadius: 7
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.cardSoft)
        )
        .contentShape(Rectangle())
    }

    private func recipeSeasonBadgeText(percent: Int) -> String {
        percent >= 70
            ? viewModel.localizer.localized("home.filter.peak_season")
            : viewModel.localizer.localized("search.filter.seasonal")
    }
}

private struct SearchFridgeRecipeCard: View {
    let ranked: RankedRecipe
    let viewModel: ProduceViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeThumbnailView(recipe: ranked.recipe, size: 88)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(ranked.recipe.title)
                    .font(DS.Font.serif(21, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)

                Text(ranked.recipe.author)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    SeasonBadge(
                        text: viewModel.localizer.localized("search.badge.from_fridge"),
                        icon: "snowflake",
                        semantic: .positive,
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: SeasonRadius.small
                    )
                    SeasonBadge(
                        text: viewModel.localizer.localized("search.filter.seasonal"),
                        icon: "leaf.fill",
                        semantic: .positive,
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: SeasonRadius.small
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.sageSoft.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Color.sage.opacity(0.14), lineWidth: 1)
        )
    }
}
