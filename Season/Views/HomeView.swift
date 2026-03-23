import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var selectedQuickFilter: HomeQuickFilter?
    @State private var cachedMiniFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
    @State private var mainContinuousFeedItems: [HomeFeedItem] = []
    @State private var continuousEditorialBlocks: [HomeContinuousBlock] = []
    @State private var featuredRecipeCache: RankedRecipe?
    @State private var fridgeMatchesCache: [FridgeMatchedRecipe] = []
    @State private var ingredientUsageCountByID: [String: Int] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    fixedHeaderRow(safeAreaTopInset: proxy.safeAreaInsets.top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                            fridgeCookingHeroCard
                            featuredSection
                            quickHorizontalStrip
                                .zIndex(2)
                            mixedFeedSection
                                .zIndex(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, SeasonSpacing.sm)
                        .padding(.top, 8)
                        .padding(.bottom, SeasonSpacing.md)
                    }
                    .refreshable {
                        await viewModel.refreshHomeFeed()
                    }
                }
            }
        }
        .onAppear(perform: refreshHomeFeedCache)
        .onChange(of: cacheSignature) {
            refreshHomeFeedCache()
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
    }

    private func fixedHeaderRow(safeAreaTopInset: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(viewModel.localizer.text(.homeTab))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            topRightActions
        }
        .padding(.top, safeAreaTopInset + 4)
        .padding(.horizontal, SeasonSpacing.md)
        .padding(.bottom, 8)
    }

    private var fridgeCookingHeroCard: some View {
        NavigationLink {
            FridgeRecipeMatchesView(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel,
                fridgeViewModel: fridgeViewModel
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.localizer.homeCookWithWhatYouHaveTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(viewModel.localizer.homeCookWithWhatYouHaveSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(viewModel.localizer.homeCookWithWhatYouHaveCTA)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
            .padding(SeasonSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator).opacity(0.16), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardButtonStyle())
        .padding(.top, SeasonSpacing.xs)
        .padding(.bottom, SeasonSpacing.lg)
    }

    private var topRightActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                FridgeView(
                    produceViewModel: viewModel,
                    fridgeViewModel: fridgeViewModel
                )
            } label: {
                Image(systemName: "snowflake")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                ShoppingListView(
                    produceViewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                Image(systemName: "bag")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private var featuredSection: some View {
        if let featured = featuredRecipe {
            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                Text(viewModel.localizer.text(.featuredRecipe))
                    .font(.headline)
                    .foregroundStyle(.primary)

                SeasonCard {
                    NavigationLink {
                        RecipeDetailView(
                            rankedRecipe: featured,
                            viewModel: viewModel,
                            shoppingListViewModel: shoppingListViewModel
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            recipeImage(for: featured.recipe, height: 210)

                            Text(featured.recipe.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(featured.recipe.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(featuredHook(for: featured))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 10) {
                                if !featuredHookIncludesMinutes(for: featured) {
                                    Text(featuredTimeText(for: featured.recipe))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var quickHorizontalStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.localizer.text(.smartSuggestionsTitle))
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HomeQuickFilter.allCases) { filter in
                        Button {
                            selectQuickFilter(filter)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.iconName)
                                    .font(.caption.weight(.semibold))
                                Text(filter.title(using: viewModel.localizer))
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedQuickFilter == filter ? Color.white : Color.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedQuickFilter == filter ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            )
                            .contentShape(Rectangle())
                        }
                        .frame(minHeight: 34)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 2)
        .background(Color(.systemGroupedBackground))
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var mixedFeedSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                ForEach(activeMiniFeedItems) { item in
                    switch item {
                    case .recipe(let card, let style):
                        if style == .large {
                            largeRecipeCard(ranked: card.ranked, hook: card.hook)
                        } else {
                            compactRecipeCard(ranked: card.ranked, hook: card.hook)
                        }
                    case .recipePair(let first, let second):
                        twoUpRecipeRow(first: first, second: second)
                    case .fridge(let match):
                        fridgeSuggestionCard(match)
                    case .spotlight(let ingredient):
                        spotlightCard(for: ingredient)
                    }
                }
            }
            .id(selectedQuickFilter?.rawValue ?? "default-mini")
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            .animation(.easeInOut(duration: 0.18), value: selectedQuickFilter)

            ForEach(indexedContinuousEditorialBlocks) { indexedBlock in
                switch indexedBlock.block {
                case .largeRecipe(let card):
                    largeRecipeCard(ranked: card.ranked, hook: card.hook)
                case .compactPair(let first, let second):
                    twoUpRecipeRow(first: first, second: second)
                case .compactSingle(let card):
                    compactRecipeCard(ranked: card.ranked, hook: card.hook)
                case .spotlight(let ingredient):
                    spotlightCard(for: ingredient)
                case .fridgeRecipe(let match):
                    fridgeSuggestionCard(match)
                }
            }
        }
    }

    private var indexedContinuousEditorialBlocks: [IndexedContinuousBlock] {
        continuousEditorialBlocks.enumerated().map { index, block in
            IndexedContinuousBlock(id: "\(index)-\(block.identityKey)", block: block)
        }
    }

    private var featuredRecipe: RankedRecipe? {
        featuredRecipeCache
    }

    private var activeMiniFeedItems: [HomeFeedItem] {
        if let selectedQuickFilter {
            let mini = cachedMiniFeeds[selectedQuickFilter] ?? []
            return guaranteedMiniBlock(from: mini)
        }
        let recipeOnlySeed = mainContinuousFeedItems.filter {
            if case .recipe = $0 { return true }
            return false
        }
        return guaranteedMiniBlock(from: Array(recipeOnlySeed.prefix(3)))
    }

    private var remainingFeedItems: [HomeFeedItem] {
        let miniRecipeIDs = Set(activeMiniFeedItems.flatMap(recipeIDs(in:)))
        let deduplicated = mainContinuousFeedItems.filter { item in
            miniRecipeIDs.isDisjoint(with: recipeIDs(in: item))
        }

        // Keep Home feed deep: if strict dedupe makes it too short, prefer continuity over perfect uniqueness.
        if deduplicated.count >= 8 {
            return deduplicated
        }
        return mainContinuousFeedItems
    }

    private var fridgeMatches: [FridgeMatchedRecipe] {
        fridgeMatchesCache
    }

    private var cacheSignature: String {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet.sorted().joined(separator: "|")
        return "\(viewModel.languageCode)|\(viewModel.recipes.count)|\(fridgeIDs)|\(viewModel.currentMonth)|\(viewModel.homeFeedRefreshID)"
    }

    private func refreshHomeFeedCache() {
        let feed = buildHomeFeed()
        featuredRecipeCache = feed.featured
        fridgeMatchesCache = feed.fridgeMatches
        ingredientUsageCountByID = feed.ingredientUsageCountByID
        mainContinuousFeedItems = feed.defaultFeedItems
        continuousEditorialBlocks = feed.continuousBlocks
        cachedMiniFeeds = feed.filteredMiniFeeds
    }

    private func buildHomeFeed() -> HomeFeedBuild {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        let homeRecipes = viewModel.homeRankedRecipes(limit: 120)
        let trendingIDs = Set(viewModel.rankedTrendingNowRecipes(limit: 60).map(\.recipe.id))

        let ingredientUsageCount = computeIngredientUsageCount(from: homeRecipes)
        let featured = pickFeaturedRecipe(from: homeRecipes, fridgeItemIDs: fridgeIDs)
        let fridgeMatches = buildFridgeSection(featuredID: featured?.recipe.id, fridgeItemIDs: fridgeIDs)
        let spotlight = buildSeasonalSpotlight(usageCountByID: ingredientUsageCount)
        debugHomeFeed("featured=\(featured?.recipe.id ?? "nil") fridge=\(fridgeMatches.map { $0.rankedRecipe.recipe.id })")

        let usedTopIDs = Set(
            ([featured?.recipe.id]
             + fridgeMatches.map { Optional($0.rankedRecipe.recipe.id) }).compactMap { $0 }
        )

        let baseRecipes = homeRecipes.filter { !usedTopIDs.contains($0.recipe.id) }
        let trendingRecipes = buildTrendingSection(from: baseRecipes, trendingIDs: trendingIDs)
        let usedWithTrending = usedTopIDs.union(trendingRecipes.map(\.recipe.id))
        let continuousRecipes = baseRecipes.filter { !usedWithTrending.contains($0.recipe.id) }

        let continuousBuild = buildContinuousFeed(
            recipes: continuousRecipes,
            trendingRecipes: trendingRecipes,
            spotlight: spotlight,
            fridgeMatches: fridgeMatches,
            trendingIDs: trendingIDs,
            backupRecipes: homeRecipes
        )
        debugHomeFeed("default feed count=\(continuousBuild.defaultFeedItems.count)")

        var miniFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
        for filter in HomeQuickFilter.allCases {
            miniFeeds[filter] = buildMiniFeedBlock(
                for: filter,
                baseRecipes: continuousRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: homeRecipes,
                trendingIDs: trendingIDs,
                fridgeItemIDs: fridgeIDs
            )
        }

        return HomeFeedBuild(
            featured: featured,
            fridgeMatches: fridgeMatches,
            defaultFeedItems: continuousBuild.defaultFeedItems,
            continuousBlocks: continuousBuild.continuousBlocks,
            filteredMiniFeeds: miniFeeds,
            ingredientUsageCountByID: ingredientUsageCount
        )
    }

    private func buildMiniFeedBlock(
        for filter: HomeQuickFilter,
        baseRecipes: [RankedRecipe],
        trendingRecipes: [RankedRecipe],
        backupRecipes: [RankedRecipe],
        trendingIDs: Set<String>,
        fridgeItemIDs: Set<String>
    ) -> [HomeFeedItem] {
        let mergedCandidates = mergedCandidateRecipes(
            baseRecipes: baseRecipes,
            trendingRecipes: trendingRecipes,
            backupRecipes: backupRecipes
        )
        let reranked = smartBoostedRanking(
            for: filter,
            candidates: mergedCandidates,
            fridgeItemIDs: fridgeItemIDs
        )

        let cards = enforceFeedDiversity(
            cards: buildHookedCards(
                from: reranked,
                preferTrending: filter == .trending,
                trendingIDs: trendingIDs,
                previousHook: nil
            ),
            trendingCards: buildHookedCards(
                from: trendingRecipes,
                preferTrending: true,
                trendingIDs: trendingIDs,
                previousHook: nil
            ),
            targetCount: 8
        )

        let miniItems = cards.prefix(3).map { card in
            HomeFeedItem.recipe(card, style: .compact)
        }
        return guaranteedMiniBlock(from: Array(miniItems))
    }

    private func guaranteedMiniBlock(from candidates: [HomeFeedItem]) -> [HomeFeedItem] {
        var mini = candidates.compactMap { item -> HomeFeedItem? in
            if case .recipe = item { return item }
            return nil
        }
        mini = Array(mini.prefix(3))
        if mini.count >= 3 { return mini }

        var existingRecipeIDs = Set(mini.compactMap { item -> String? in
            if case .recipe(let card, _) = item { return card.ranked.recipe.id }
            return nil
        })
        for item in mainContinuousFeedItems where mini.count < 3 {
            guard case .recipe(let card, _) = item else { continue }
            guard !existingRecipeIDs.contains(card.ranked.recipe.id) else { continue }
            mini.append(.recipe(card, style: .compact))
            existingRecipeIDs.insert(card.ranked.recipe.id)
        }

        if mini.count < 3 {
            let backupCards = buildHookedCards(
                from: viewModel.homeRankedRecipes(limit: 12),
                preferTrending: false,
                trendingIDs: Set(viewModel.rankedTrendingNowRecipes(limit: 24).map(\.recipe.id)),
                previousHook: nil
            )
            for card in backupCards where mini.count < 3 {
                let item = HomeFeedItem.recipe(card, style: .compact)
                if !existingRecipeIDs.contains(card.ranked.recipe.id) {
                    mini.append(item)
                    existingRecipeIDs.insert(card.ranked.recipe.id)
                }
            }
        }

        return Array(mini.prefix(3))
    }

    private func feedIdentityKey(for item: HomeFeedItem) -> String {
        switch item {
        case .recipe(let card, _):
            return "recipe-\(card.ranked.recipe.id)"
        case .recipePair(let first, let second):
            return "pair-\(first.ranked.recipe.id)-\(second.ranked.recipe.id)"
        case .fridge(let match):
            return "fridge-\(match.rankedRecipe.recipe.id)"
        case .spotlight(let ingredient):
            return "spotlight-\(ingredient.item.id)"
        }
    }

    private func recipeIDs(in item: HomeFeedItem) -> Set<String> {
        switch item {
        case .recipe(let card, _):
            return [card.ranked.recipe.id]
        case .recipePair(let first, let second):
            return [first.ranked.recipe.id, second.ranked.recipe.id]
        case .fridge(let match):
            return [match.rankedRecipe.recipe.id]
        case .spotlight:
            return []
        }
    }

    private func mergedCandidateRecipes(
        baseRecipes: [RankedRecipe],
        trendingRecipes: [RankedRecipe],
        backupRecipes: [RankedRecipe]
    ) -> [RankedRecipe] {
        var merged: [RankedRecipe] = []
        var seen: Set<String> = []
        for ranked in (baseRecipes + trendingRecipes + backupRecipes)
        where !seen.contains(ranked.recipe.id) {
            seen.insert(ranked.recipe.id)
            merged.append(ranked)
            if merged.count >= 160 { break }
        }
        return merged
    }

    private func smartBoostedRanking(
        for filter: HomeQuickFilter,
        candidates: [RankedRecipe],
        fridgeItemIDs: Set<String>
    ) -> [RankedRecipe] {
        candidates
            .map { ranked in
                let baseScore = min(1.0, max(0.0, ranked.score / 100.0))
                let boost = smartSuggestionBoost(for: filter, ranked: ranked, fridgeItemIDs: fridgeItemIDs)
                return (ranked: ranked, score: baseScore + boost)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }
            .map(\.ranked)
    }

    private func smartSuggestionBoost(
        for filter: HomeQuickFilter,
        ranked: RankedRecipe,
        fridgeItemIDs: Set<String>
    ) -> Double {
        let recipe = ranked.recipe
        let seasonal = Double(ranked.seasonalMatchPercent) / 100.0
        let crispy = viewModel.crispyScore(for: recipe)
        let views = viewModel.viewsScore(for: recipe)
        let fridgeMatch = fridgeItemIDs.isEmpty ? 0.0 : viewModel.fridgeMatchScore(for: recipe, fridgeItemIDs: fridgeItemIDs)
        let totalMinutes = (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0)
        let quickness = totalMinutes > 0 ? max(0, 1.0 - (Double(totalMinutes) / 35.0)) : 0.25
        let nutrition = viewModel.nutritionPreferenceScore(for: recipe)
        let proteinSignal: Double = {
            guard let summary = viewModel.recipeNutritionSummary(for: recipe) else { return 0 }
            return min(max(summary.protein / 20.0, 0), 1.0)
        }()

        switch filter {
        case .readyNow:
            return (0.20 * quickness) + (0.14 * fridgeMatch) + (0.06 * seasonal)
        case .under15:
            return (0.24 * quickness) + (0.05 * seasonal)
        case .highProtein:
            return (0.18 * proteinSignal) + (0.08 * nutrition)
        case .peakSeason:
            return (0.22 * seasonal) + (0.06 * nutrition)
        case .trending:
            return (0.20 * crispy) + (0.12 * views)
        }
    }

    private func pickFeaturedRecipe(
        from rankedRecipes: [RankedRecipe],
        fridgeItemIDs: Set<String>
    ) -> RankedRecipe? {
        let sorted = rankedRecipes
            .sorted { lhs, rhs in
                let left = featuredSelectionScore(for: lhs, fridgeItemIDs: fridgeItemIDs)
                let right = featuredSelectionScore(for: rhs, fridgeItemIDs: fridgeItemIDs)
                if left != right {
                    return left > right
                }
                return lhs.recipe.title.localizedCaseInsensitiveCompare(rhs.recipe.title) == .orderedAscending
            }

        guard !sorted.isEmpty else { return nil }

        let candidatePoolSize = min(12, sorted.count)
        let candidatePool = Array(sorted.prefix(candidatePoolSize))
        var selectedIndex = viewModel.featuredRecipeRotationIndex(poolCount: candidatePool.count)

        if let previousFeaturedID = featuredRecipeCache?.recipe.id,
           candidatePool.count > 1,
           candidatePool[selectedIndex].recipe.id == previousFeaturedID {
            selectedIndex = (selectedIndex + 1) % candidatePool.count
        }

        return candidatePool[selectedIndex]
    }

    private func featuredSelectionScore(for ranked: RankedRecipe, fridgeItemIDs: Set<String>) -> Double {
        let recipe = ranked.recipe
        let home = min(1.0, max(0.0, ranked.score / 100.0))
        let seasonal = Double(ranked.seasonalMatchPercent) / 100.0
        let trending = (0.6 * viewModel.crispyScore(for: recipe)) + (0.4 * viewModel.viewsScore(for: recipe))
        let fridge = fridgeItemIDs.isEmpty ? 0.0 : viewModel.fridgeMatchScore(for: recipe, fridgeItemIDs: fridgeItemIDs)
        let totalMinutes = (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0)
        let convenience = totalMinutes > 0 ? max(0, 1.0 - (Double(totalMinutes) / 45.0)) : 0.35
        return (0.45 * home) + (0.20 * seasonal) + (0.15 * fridge) + (0.10 * trending) + (0.10 * convenience)
    }

    private func buildFridgeSection(
        featuredID: String?,
        fridgeItemIDs: Set<String>
    ) -> [FridgeMatchedRecipe] {
        guard !fridgeItemIDs.isEmpty else { return [] }
        return viewModel
            .rankedFridgeRecommendations(fridgeItemIDs: fridgeItemIDs)
            .filter { $0.matchingCount > 0 && $0.rankedRecipe.recipe.id != featuredID }
            .prefix(2)
            .map { $0 }
    }

    private func buildTrendingSection(
        from recipes: [RankedRecipe],
        trendingIDs: Set<String>
    ) -> [RankedRecipe] {
        recipes
            .filter { trendingIDs.contains($0.recipe.id) }
            .sorted { lhs, rhs in
                let left = (0.6 * viewModel.crispyScore(for: lhs.recipe)) + (0.4 * viewModel.viewsScore(for: lhs.recipe))
                let right = (0.6 * viewModel.crispyScore(for: rhs.recipe)) + (0.4 * viewModel.viewsScore(for: rhs.recipe))
                if left != right { return left > right }
                return lhs.recipe.title.localizedCaseInsensitiveCompare(rhs.recipe.title) == .orderedAscending
            }
            .prefix(18)
            .map { $0 }
    }

    private func buildSeasonalSpotlight(usageCountByID: [String: Int]) -> [RankedInSeasonItem] {
        viewModel
            .bestPicksToday(limit: 16)
            .sorted { lhs, rhs in
                let lUsage = usageCountByID[lhs.item.id] ?? 0
                let rUsage = usageCountByID[rhs.item.id] ?? 0
                if lUsage != rUsage { return lUsage > rUsage }
                return lhs.score > rhs.score
            }
    }

    private func buildContinuousFeed(
        recipes: [RankedRecipe],
        trendingRecipes: [RankedRecipe],
        spotlight: [RankedInSeasonItem],
        fridgeMatches: [FridgeMatchedRecipe],
        trendingIDs: Set<String>,
        backupRecipes: [RankedRecipe],
        preferTrending: Bool = false
    ) -> ContinuousFeedBuild {
        let minimumFeedItems = 12
        let maxRecipeCards = max(40, min(180, recipes.count * 3))
        let diversifiedRecipeCards = enforceFeedDiversity(
            cards: buildHookedCards(
                from: recipes,
                preferTrending: preferTrending,
                trendingIDs: trendingIDs,
                previousHook: nil
            ),
            trendingCards: buildHookedCards(
                from: trendingRecipes,
                preferTrending: true,
                trendingIDs: trendingIDs,
                previousHook: nil
            ),
            targetCount: maxRecipeCards
        )
        debugHomeFeed("continuous before=\(recipes.count) after_diversity=\(diversifiedRecipeCards.count)")
        let backupCards = enforceFeedDiversity(
            cards: buildHookedCards(
                from: backupRecipes,
                preferTrending: false,
                trendingIDs: trendingIDs,
                previousHook: diversifiedRecipeCards.last?.hookKind
            ),
            trendingCards: [],
            targetCount: max(30, min(120, backupRecipes.count))
        )

        let editorialBlocks = buildEditorialContinuousBlocks(
            primaryRecipes: diversifiedRecipeCards,
            backupRecipes: backupCards,
            spotlightItems: spotlight,
            fridgeMatches: fridgeMatches
        )

        var flatItems = flattenEditorialBlocks(editorialBlocks)

        if flatItems.count < minimumFeedItems {
            let existingRecipeIDs = Set(flatItems.flatMap(recipeIDs(in:)))
            for card in backupCards where flatItems.count < minimumFeedItems {
                guard !existingRecipeIDs.contains(card.ranked.recipe.id) else { continue }
                flatItems.append(.recipe(card, style: .compact))
            }
        }

        debugHomeFeed("continuous final=\(flatItems.count)")
        return ContinuousFeedBuild(defaultFeedItems: flatItems, continuousBlocks: editorialBlocks)
    }

    private func buildEditorialContinuousBlocks(
        primaryRecipes: [HookedRecipeCard],
        backupRecipes: [HookedRecipeCard],
        spotlightItems: [RankedInSeasonItem],
        fridgeMatches: [FridgeMatchedRecipe]
    ) -> [HomeContinuousBlock] {
        enum Slot {
            case largeRecipe
            case compactPair
            case spotlight
            case fridgeRecipe
        }

        let template: [Slot] = [
            .largeRecipe,
            .compactPair,
            .spotlight,
            .fridgeRecipe,
            .largeRecipe,
            .compactPair
        ]

        var primaryPool = primaryRecipes
        var backupPool = backupRecipes
        var spotlightIndex = 0
        var fridgeIndex = 0
        var templateIndex = 0
        var recentRecipeIDs: [String] = []
        var blocks: [HomeContinuousBlock] = []
        let targetBlockCount = max(14, min(70, (primaryRecipes.count / 2) + 8))

        func markRecent(_ id: String) {
            recentRecipeIDs.append(id)
            if recentRecipeIDs.count > 10 {
                recentRecipeIDs.removeFirst(recentRecipeIDs.count - 10)
            }
        }

        func pullRecipe(preferPrimary: Bool = true) -> HookedRecipeCard? {
            func removeFromPool(_ pool: inout [HookedRecipeCard]) -> HookedRecipeCard? {
                guard !pool.isEmpty else { return nil }
                let lookahead = min(12, pool.count)
                if let idx = pool.prefix(lookahead).firstIndex(where: { !recentRecipeIDs.contains($0.ranked.recipe.id) }) {
                    return pool.remove(at: idx)
                }
                return pool.removeFirst()
            }

            if preferPrimary, let card = removeFromPool(&primaryPool) { return card }
            if let card = removeFromPool(&backupPool) { return card }
            if !preferPrimary, let card = removeFromPool(&primaryPool) { return card }
            return nil
        }

        func largeFallbackBlock() -> HomeContinuousBlock? {
            guard let card = pullRecipe() else { return nil }
            markRecent(card.ranked.recipe.id)
            return .largeRecipe(card)
        }

        func compactPairFallbackBlock() -> HomeContinuousBlock? {
            if let pair = buildCompactPair() { return pair }
            return largeFallbackBlock()
        }

        func buildCompactPair() -> HomeContinuousBlock? {
            guard let first = pullRecipe() else { return nil }
            markRecent(first.ranked.recipe.id)

            if let second = pullRecipe() {
                markRecent(second.ranked.recipe.id)
                return .compactPair(first: first, second: second)
            }

            // Last resort for incomplete pair after trying backup pools.
            return .compactSingle(first)
        }

        func buildFridgeBlock() -> HomeContinuousBlock? {
            guard !fridgeMatches.isEmpty else { return compactPairFallbackBlock() }

            let count = fridgeMatches.count
            for offset in 0..<count {
                let candidate = fridgeMatches[(fridgeIndex + offset) % count]
                if !recentRecipeIDs.contains(candidate.rankedRecipe.recipe.id) {
                    fridgeIndex = (fridgeIndex + offset + 1) % count
                    markRecent(candidate.rankedRecipe.recipe.id)
                    return .fridgeRecipe(candidate)
                }
            }

            return compactPairFallbackBlock()
        }

        while blocks.count < targetBlockCount {
            let slot = template[templateIndex % template.count]
            templateIndex += 1
            let countBefore = blocks.count

            switch slot {
            case .largeRecipe:
                if let block = largeFallbackBlock() { blocks.append(block) }
            case .compactPair:
                if let block = buildCompactPair() { blocks.append(block) }
            case .spotlight:
                if spotlightIndex < spotlightItems.count {
                    blocks.append(.spotlight(spotlightItems[spotlightIndex]))
                    spotlightIndex += 1
                } else if let fallback = largeFallbackBlock() ?? compactPairFallbackBlock() {
                    blocks.append(fallback)
                }
            case .fridgeRecipe:
                if let fridgeBlock = buildFridgeBlock() {
                    blocks.append(fridgeBlock)
                } else if let fallback = compactPairFallbackBlock() ?? largeFallbackBlock() {
                    blocks.append(fallback)
                }
            }

            if blocks.count == countBefore {
                break
            }

            if primaryPool.isEmpty,
               backupPool.isEmpty,
               spotlightIndex >= spotlightItems.count,
               fridgeMatches.isEmpty {
                break
            }
        }

        return blocks
    }

    private func flattenEditorialBlocks(_ blocks: [HomeContinuousBlock]) -> [HomeFeedItem] {
        blocks.flatMap { block -> [HomeFeedItem] in
            switch block {
            case .largeRecipe(let card):
                return [.recipe(card, style: .large)]
            case .compactPair(let first, let second):
                return [.recipePair(first: first, second: second)]
            case .compactSingle(let card):
                return [.recipe(card, style: .compact)]
            case .spotlight(let item):
                return [.spotlight(item)]
            case .fridgeRecipe(let match):
                return [.fridge(match)]
            }
        }
    }

    private func enforceFeedDiversity(
        cards: [HookedRecipeCard],
        trendingCards: [HookedRecipeCard],
        targetCount: Int
    ) -> [HookedRecipeCard] {
        guard !cards.isEmpty else { return [] }

        var result: [HookedRecipeCard] = []
        var cardPool = cards
        var trendingPool = trendingCards
        var fallbackIndex = 0

        while result.count < targetCount {
            let preferTrendingSlot = result.count.isMultiple(of: 4)
            let selected: HookedRecipeCard?
            if preferTrendingSlot {
                selected = pullBestCard(
                    from: &trendingPool,
                    fallback: &cardPool,
                    recent: result
                )
            } else {
                selected = pullBestCard(
                    from: &cardPool,
                    fallback: &trendingPool,
                    recent: result
                )
            }

            if let selected {
                result.append(selected)
                continue
            }

            // Near-infinite fallback: recycle diversified pool with cooldown.
            guard !cards.isEmpty else { break }
            let recycled = cards[fallbackIndex % cards.count]
            fallbackIndex += 1
            if canAppend(candidate: recycled, to: result, strict: false) {
                result.append(recycled)
            } else if fallbackIndex > cards.count * 6 {
                break
            }
        }

        return result
    }

    private func pullBestCard(
        from primary: inout [HookedRecipeCard],
        fallback secondary: inout [HookedRecipeCard],
        recent: [HookedRecipeCard]
    ) -> HookedRecipeCard? {
        if let index = primary.firstIndex(where: { canAppend(candidate: $0, to: recent, strict: true) }) {
            return primary.remove(at: index)
        }
        if let index = secondary.firstIndex(where: { canAppend(candidate: $0, to: recent, strict: true) }) {
            return secondary.remove(at: index)
        }
        if let first = primary.first {
            primary.removeFirst()
            return first
        }
        if let first = secondary.first {
            secondary.removeFirst()
            return first
        }
        return nil
    }

    private func canAppend(candidate: HookedRecipeCard, to current: [HookedRecipeCard], strict: Bool) -> Bool {
        guard let last = current.last else { return true }
        if candidate.hookKind == last.hookKind { return false }

        if strict {
            let recentCreators = current.suffix(3).map { $0.ranked.recipe.author }
            if recentCreators.contains(candidate.ranked.recipe.author) { return false }
            let recentRecipeIDs = current.suffix(8).map { $0.ranked.recipe.id }
            if recentRecipeIDs.contains(candidate.ranked.recipe.id) { return false }
        } else {
            let recentRecipeIDs = current.suffix(4).map { $0.ranked.recipe.id }
            if recentRecipeIDs.contains(candidate.ranked.recipe.id) { return false }
        }

        return true
    }

    private func computeIngredientUsageCount(from recipes: [RankedRecipe]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for ranked in recipes {
            let uniqueIngredientIDs = Set(ranked.recipe.ingredients.compactMap(\.produceID))
            for id in uniqueIngredientIDs {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    private func debugHomeFeed(_ message: String) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SEASON_HOME_DEBUG"] == "1" {
            print("HOME FEED DEBUG: \(message)")
        }
        #endif
    }

    private var fridgeMatchByRecipeID: [String: FridgeMatchedRecipe] {
        Dictionary(uniqueKeysWithValues: fridgeMatches.map { ($0.rankedRecipe.recipe.id, $0) })
    }

    private func selectQuickFilter(_ filter: HomeQuickFilter) {
        withAnimation(.easeInOut(duration: 0.12)) {
            selectedQuickFilter = selectedQuickFilter == filter ? nil : filter
        }
    }

    private func featuredTimeText(for recipe: Recipe) -> String {
        let prep = recipe.prepTimeMinutes ?? 0
        let cook = recipe.cookTimeMinutes ?? 0
        let total = prep + cook
        if total > 0 {
            return "\(total) \(viewModel.localizer.text(.minutesShort))"
        }
        if let prepOnly = recipe.prepTimeMinutes {
            return "\(prepOnly) \(viewModel.localizer.text(.minutesShort))"
        }
        if let cookOnly = recipe.cookTimeMinutes {
            return "\(cookOnly) \(viewModel.localizer.text(.minutesShort))"
        }
        return "--"
    }

    private func featuredHook(for ranked: RankedRecipe) -> String {
        if let fridgeMatch = fridgeMatchByRecipeID[ranked.recipe.id] {
            if fridgeMatch.missingCount > 0 {
                return viewModel.localizer.text(.bestWithWhatYouHave)
            }
            return viewModel.localizer.text(.quickActionReadyToCook)
        }

        if ranked.seasonalMatchPercent >= 85 {
            return viewModel.localizer.recipeTimingTitle(.perfectNow)
        }

        let total = (ranked.recipe.prepTimeMinutes ?? 0) + (ranked.recipe.cookTimeMinutes ?? 0)
        if total > 0 {
            return String(format: viewModel.localizer.text(.readyInMinutesFormat), total)
        }
        return viewModel.localizer.text(.readyNow)
    }

    private func featuredHookIncludesMinutes(for ranked: RankedRecipe) -> Bool {
        featuredHook(for: ranked).contains(viewModel.localizer.text(.minutesShort))
    }

    @ViewBuilder
    private func largeRecipeCard(ranked: RankedRecipe, hook: String) -> some View {
        SeasonCard {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: ranked,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    recipeImage(for: ranked.recipe, height: 186)
                    Text(hook)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(ranked.recipe.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(ranked.recipe.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    @ViewBuilder
    private func compactRecipeCard(ranked: RankedRecipe, hook: String) -> some View {
        SeasonCard {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: ranked,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                HStack(spacing: 10) {
                    recipeImage(for: ranked.recipe, height: 94, width: 108)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ranked.recipe.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(ranked.recipe.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(hook)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    @ViewBuilder
    private func twoUpRecipeRow(first: HookedRecipeCard, second: HookedRecipeCard) -> some View {
        HStack(spacing: SeasonSpacing.sm) {
            twoUpRecipeCard(ranked: first.ranked, hook: first.hook)
            twoUpRecipeCard(ranked: second.ranked, hook: second.hook)
        }
    }

    @ViewBuilder
    private func twoUpRecipeCard(ranked: RankedRecipe, hook: String) -> some View {
        SeasonCard {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: ranked,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    recipeImage(for: ranked.recipe, height: 94)
                    Text(ranked.recipe.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(hook)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PressableCardButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fridgeSuggestionCard(_ match: FridgeMatchedRecipe, emphasize: Bool = false) -> some View {
        SeasonCard {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: match.rankedRecipe,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                HStack(spacing: 10) {
                    recipeImage(for: match.rankedRecipe.recipe, height: 90, width: 102)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.rankedRecipe.recipe.title)
                            .font(emphasize ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(fridgePrimaryMessage(for: match))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(emphasize ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, emphasize ? 1 : 0)
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private func fridgePrimaryMessage(for match: FridgeMatchedRecipe) -> String {
        if match.missingCount == 0 {
            return viewModel.localizer.text(.quickActionYouHaveEverything)
        }
        if match.missingCount == 1 {
            return viewModel.localizer.text(.quickActionOnlyOneIngredientMissing)
        }
        if match.missingCount == 2 {
            return viewModel.localizer.text(.almostReady)
        }
        return String(
            format: viewModel.localizer.text(.quickActionOnlyIngredientsMissingFormat),
            match.missingCount
        )
    }

    @ViewBuilder
    private func spotlightCard(for ranked: RankedInSeasonItem) -> some View {
        SeasonCard {
            NavigationLink {
                ProduceDetailView(
                    item: ranked.item,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
                .environmentObject(fridgeViewModel)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProduceThumbnailView(item: ranked.item, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ranked.item.displayName(languageCode: viewModel.languageCode))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(seasonalSpotlightStateText(for: ranked.item))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    Text(viewModel.shortBenefitText(for: ranked))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let relevance = ingredientRelevanceText(for: ranked.item) {
                        Text(relevance)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private func ingredientRelevanceText(for item: ProduceItem) -> String? {
        let usageCount = ingredientUsageCountByID[item.id] ?? 0
        guard usageCount > 0 else { return nil }
        return String(format: viewModel.localizer.text(.usedInRecipesFormat), usageCount)
    }

    private func seasonalSpotlightStateText(for item: ProduceItem) -> String {
        switch item.seasonalityPhase(month: viewModel.currentMonth) {
        case .inSeason:
            return viewModel.localizer.text(.seasonPeakNow)
        case .earlySeason:
            return viewModel.localizer.text(.seasonPhaseEarlySeason)
        case .endingSoon:
            return viewModel.localizer.text(.seasonPhaseEndingSoon)
        case .outOfSeason:
            return viewModel.localizer.text(.seasonOutOfSeason)
        }
    }

    private func hookCandidates(
        for ranked: RankedRecipe,
        preferTrending: Bool,
        trendingIDs: Set<String>
    ) -> [RecipePrimaryHook] {
        var hooks: [String] = []
        var mapped: [RecipePrimaryHook] = []

        if let match = fridgeMatchByRecipeID[ranked.recipe.id] {
            mapped.append(.init(
                kind: .almostReady,
                text: String(
                format: viewModel.localizer.text(.ingredientMatchCountFormat),
                match.matchingCount,
                match.totalCount
                )
            ))
        }

        let total = (ranked.recipe.prepTimeMinutes ?? 0) + (ranked.recipe.cookTimeMinutes ?? 0)
        if total > 0 && total <= 15 {
            mapped.append(.init(
                kind: .quickMeal,
                text: String(format: viewModel.localizer.text(.readyInMinutesFormat), total)
            ))
        }

        if ranked.seasonalMatchPercent >= 88 {
            mapped.append(.init(
                kind: .peakSeason,
                text: viewModel.localizer.text(.seasonPeakNow)
            ))
        }

        if preferTrending || trendingIDs.contains(ranked.recipe.id) {
            mapped.append(.init(
                kind: .trending,
                text: viewModel.localizer.text(.trendingNowTitle)
            ))
        }

        switch viewModel.recipeTimingLabel(for: ranked) {
        case .perfectNow:
            mapped.append(.init(
                kind: .readyNow,
                text: viewModel.localizer.recipeTimingTitle(.perfectNow)
            ))
        case .betterSoon:
            mapped.append(.init(
                kind: .peakSeason,
                text: viewModel.localizer.recipeTimingTitle(.betterSoon)
            ))
        case .endingSoon:
            mapped.append(.init(
                kind: .peakSeason,
                text: viewModel.localizer.recipeTimingTitle(.endingSoon)
            ))
        case .goodNow:
            break
        }

        if mapped.isEmpty {
            mapped.append(.init(
                kind: .readyNow,
                text: viewModel.localizer.text(.seasonBestThisMonth)
            ))
        }

        for hook in mapped.map(\.text) where !hooks.contains(hook) {
            hooks.append(hook)
        }

        var unique: [String] = []
        for hook in hooks where !unique.contains(hook) {
            unique.append(hook)
        }

        return unique.compactMap { text in
            mapped.first(where: { $0.text == text })
        }
    }

    private func buildHookedCards(
        from recipes: [RankedRecipe],
        preferTrending: Bool,
        trendingIDs: Set<String>,
        previousHook: HookKind?
    ) -> [HookedRecipeCard] {
        var lastHookKind = previousHook
        return recipes.map { ranked in
            let candidates = hookCandidates(
                for: ranked,
                preferTrending: preferTrending,
                trendingIDs: trendingIDs
            )
            let chosen = candidates.first(where: { $0.kind != lastHookKind }) ?? candidates.first ?? .init(kind: .readyNow, text: viewModel.localizer.text(.readyNow))
            lastHookKind = chosen.kind
            return HookedRecipeCard(ranked: ranked, hook: chosen.text, hookKind: chosen.kind)
        }
    }

    @ViewBuilder
    private func recipeImage(for recipe: Recipe, height: CGFloat, width: CGFloat? = nil) -> some View {
        Group {
            if let cover = resolvedRecipeCoverImage(for: recipe),
               let localImage = recipeUIImage(from: cover) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let cover = resolvedRecipeCoverImage(for: recipe),
                      let remoteURLString = cover.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        recipeFallbackImage
                    }
                }
            } else if let imageName = recipe.coverImageName,
                      UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                recipeFallbackImage
            }
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var recipeFallbackImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
        }
    }
}

private enum HomeQuickFilter: String, CaseIterable, Identifiable {
    case readyNow
    case under15
    case highProtein
    case peakSeason
    case trending

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .readyNow:
            return "checkmark.circle"
        case .under15:
            return "timer"
        case .highProtein:
            return "bolt"
        case .peakSeason:
            return "leaf"
        case .trending:
            return "flame"
        }
    }

    func title(using localizer: AppLocalizer) -> String {
        switch self {
        case .readyNow:
            return localizer.text(.quickActionReadyToCook)
        case .under15:
            return "15 \(localizer.text(.minutesShort))"
        case .highProtein:
            return localizer.text(.reasonHighProtein)
        case .peakSeason:
            return localizer.text(.seasonPeakNow)
        case .trending:
            return localizer.text(.trendingNowTitle)
        }
    }

}

private struct HomeFeedBuild {
    let featured: RankedRecipe?
    let fridgeMatches: [FridgeMatchedRecipe]
    let defaultFeedItems: [HomeFeedItem]
    let continuousBlocks: [HomeContinuousBlock]
    let filteredMiniFeeds: [HomeQuickFilter: [HomeFeedItem]]
    let ingredientUsageCountByID: [String: Int]
}

private struct ContinuousFeedBuild {
    let defaultFeedItems: [HomeFeedItem]
    let continuousBlocks: [HomeContinuousBlock]
}

private enum HomeRecipeCardStyle {
    case compact
    case large
}

private enum HomeFeedItem: Identifiable {
    case recipe(HookedRecipeCard, style: HomeRecipeCardStyle)
    case recipePair(first: HookedRecipeCard, second: HookedRecipeCard)
    case fridge(FridgeMatchedRecipe)
    case spotlight(RankedInSeasonItem)

    var id: String {
        switch self {
        case .recipe(let card, let style):
            return "recipe-\(style)-\(card.ranked.recipe.id)"
        case .recipePair(let first, let second):
            return "recipe-pair-\(first.ranked.recipe.id)-\(second.ranked.recipe.id)"
        case .fridge(let match):
            return "fridge-\(match.rankedRecipe.recipe.id)"
        case .spotlight(let item):
            return "spotlight-\(item.item.id)"
        }
    }
}

private enum HomeContinuousBlock {
    case largeRecipe(HookedRecipeCard)
    case compactPair(first: HookedRecipeCard, second: HookedRecipeCard)
    case compactSingle(HookedRecipeCard)
    case spotlight(RankedInSeasonItem)
    case fridgeRecipe(FridgeMatchedRecipe)

    var identityKey: String {
        switch self {
        case .largeRecipe(let card):
            return "large-\(card.ranked.recipe.id)"
        case .compactPair(let first, let second):
            return "pair-\(first.ranked.recipe.id)-\(second.ranked.recipe.id)"
        case .compactSingle(let card):
            return "compact-\(card.ranked.recipe.id)"
        case .spotlight(let item):
            return "spotlight-\(item.item.id)"
        case .fridgeRecipe(let match):
            return "fridge-\(match.rankedRecipe.recipe.id)"
        }
    }
}

private struct IndexedContinuousBlock: Identifiable {
    let id: String
    let block: HomeContinuousBlock
}

private struct HookedRecipeCard: Identifiable {
    let ranked: RankedRecipe
    let hook: String
    let hookKind: HookKind

    var id: String { ranked.id }
}

private enum HookKind: Hashable {
    case readyNow
    case trending
    case almostReady
    case peakSeason
    case quickMeal
}

private struct RecipePrimaryHook {
    let kind: HookKind
    let text: String
}

private extension Array where Element == HomeFeedItem {
    var lastRecipeHookKind: HookKind? {
        for item in reversed() {
            if case .recipe(let card, _) = item {
                return card.hookKind
            }
            if case .recipePair(let first, _) = item {
                return first.hookKind
            }
        }
        return nil
    }
}

private struct QuickActionTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemBackground))
                    )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 112, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
                )
        )
    }
}

private struct FridgeRecipeMatchesView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @ObservedObject var fridgeViewModel: FridgeViewModel
    @State private var feedbackMessage = ""
    @State private var showingFeedbackAlert = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(produceViewModel.localizer.text(.fromYourFridge))
                        .font(.title3.weight(.semibold))
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section(header: Text(produceViewModel.localizer.text(.fridgePreviewTitle)).textCase(nil)) {
                VStack(alignment: .leading, spacing: 10) {
                    if fridgeViewModel.allItemCount == 0 {
                        Text(produceViewModel.localizer.text(.fromFridgeSubtitleEmpty))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(fridgePreviewItems) { item in
                                    HStack(spacing: 6) {
                                        fridgePreviewIcon(item: item, size: 26)
                                        Text(item.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(.tertiarySystemGroupedBackground))
                                    )
                                }
                            }
                        }
                    }

                    NavigationLink {
                        FridgeView(
                            produceViewModel: produceViewModel,
                            fridgeViewModel: fridgeViewModel
                        )
                    } label: {
                        Text(produceViewModel.localizer.text(.editFridge))
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 2)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section(header: SectionTitleCountRow(
                title: produceViewModel.localizer.text(.bestMatches),
                countText: "\(bestMatches.count)"
            ).textCase(nil)) {
                if bestMatches.isEmpty {
                    EmptyStateCard(
                        symbol: "fork.knife",
                        title: produceViewModel.localizer.text(.noMatchingRecipesYetTitle),
                        subtitle: produceViewModel.localizer.text(.noMatchingRecipesYetSubtitle)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bestMatches) { match in
                        fridgeRecipeRow(match)
                    }
                }
            }

            if !quickOptions.isEmpty {
                Section(header: SectionTitleCountRow(
                    title: produceViewModel.localizer.text(.quickOptions),
                    countText: "\(quickOptions.count)"
                ).textCase(nil)) {
                    ForEach(quickOptions) { match in
                        fridgeRecipeRow(match)
                    }
                }
            }

            if !needsIngredients.isEmpty {
                Section(header: Text(produceViewModel.localizer.text(.needsIngredients)).textCase(nil)) {
                    ForEach(needsIngredients) { match in
                        fridgeRecipeRow(match)
                    }
                }
            }

            if recommendations.isEmpty {
                EmptyStateCard(
                    symbol: "snowflake",
                    title: produceViewModel.localizer.text(.cookWithWhatYouHave),
                    subtitle: produceViewModel.localizer.text(.fromFridgeSubtitleEmpty)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(produceViewModel.localizer.text(.fromYourFridge))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .toolbar {
            CartToolbarItems(
                produceViewModel: produceViewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .alert(feedbackMessage, isPresented: $showingFeedbackAlert) {
            Button(produceViewModel.localizer.text(.commonOK), role: .cancel) {}
        }
    }

    @ViewBuilder
    private func fridgeRecipeRow(_ match: FridgeMatchedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: match.rankedRecipe,
                    viewModel: produceViewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                HStack(spacing: 10) {
                    RecipeThumbnailView(recipe: match.rankedRecipe.recipe, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.rankedRecipe.recipe.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(match.rankedRecipe.recipe.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    SeasonalStatusBadge(
                        score: match.rankedRecipe.seasonalityScore,
                        localizer: produceViewModel.localizer
                    )
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(String(
                    format: produceViewModel.localizer.text(.ingredientMatchCountFormat),
                    match.matchingCount,
                    match.totalCount
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

                Text(produceViewModel.recipeTimingTitle(for: match.rankedRecipe))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if missingIngredientNames(for: match).isEmpty {
                Text(produceViewModel.localizer.text(.readyNow))
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(produceViewModel.localizer.text(.missingIngredients)): \(missingIngredientNames(for: match).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Button {
                        addMissingIngredients(for: match)
                    } label: {
                        Text(produceViewModel.localizer.text(.addMissingAction))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowSeparator(.visible)
        .listRowBackground(Color.clear)
    }

    private var recommendations: [FridgeMatchedRecipe] {
        produceViewModel.rankedFridgeRecommendations(fridgeItemIDs: fridgeViewModel.allIngredientIDSet)
            .prefix(30)
            .map { $0 }
    }

    private var matchingRecommendations: [FridgeMatchedRecipe] {
        recommendations.filter { $0.matchingCount > 0 }
    }

    private var bestMatches: [FridgeMatchedRecipe] {
        let preferred = matchingRecommendations.filter { match in
            match.matchRatio >= 0.66 && match.missingCount <= 2
        }
        if preferred.isEmpty {
            return Array(matchingRecommendations.prefix(4))
        }
        return Array(preferred.prefix(4))
    }

    private var quickOptions: [FridgeMatchedRecipe] {
        let excludedIDs = Set(bestMatches.map(\.id))
        return matchingRecommendations.filter { match in
            !excludedIDs.contains(match.id)
        }
    }

    private var needsIngredients: [FridgeMatchedRecipe] {
        recommendations.filter { $0.matchingCount == 0 }
    }

    private var fridgePreviewItems: [FridgePreviewItem] {
        let produce = fridgeViewModel.produceItems.prefix(4).map {
            FridgePreviewItem.produce($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer)
        }
        let basic = fridgeViewModel.basicItems.prefix(4).map {
            FridgePreviewItem.basic($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer)
        }
        return Array((produce + basic).prefix(8))
    }

    private var headerSubtitle: String {
        guard fridgeViewModel.allItemCount > 0 else {
            return produceViewModel.localizer.text(.fromFridgeSubtitleEmpty)
        }
        let cookableCount = recommendations.filter { $0.matchingCount > 0 }.count
        return String(format: produceViewModel.localizer.text(.fromFridgeSubtitleCountFormat), cookableCount)
    }

    private func missingIngredientNames(for match: FridgeMatchedRecipe) -> [String] {
        var names: [String] = []
        for ingredient in match.rankedRecipe.recipe.ingredients {
            if produceViewModel.isRecipeIngredientAvailable(
                ingredient,
                fridgeIngredientIDs: fridgeViewModel.allIngredientIDSet
            ) {
                continue
            }
            names.append(produceViewModel.recipeIngredientDisplayName(ingredient))
        }
        return Array(names.prefix(4))
    }

    private func addMissingIngredients(for match: FridgeMatchedRecipe) {
        var added = 0
        for ingredient in match.rankedRecipe.recipe.ingredients {
            if produceViewModel.isRecipeIngredientAvailable(
                ingredient,
                fridgeIngredientIDs: fridgeViewModel.allIngredientIDSet
            ) {
                continue
            }
            if let produceID = ingredient.produceID,
               let item = produceViewModel.produceItem(forID: produceID) {
                if shoppingListViewModel.contains(item) {
                    continue
                }
                shoppingListViewModel.add(item, sourceRecipeID: match.rankedRecipe.recipe.id, sourceRecipeTitle: match.rankedRecipe.recipe.title)
                added += 1
            } else if let basicID = ingredient.basicIngredientID,
                      let basic = produceViewModel.basicIngredient(forID: basicID) {
                if shoppingListViewModel.contains(basic) {
                    continue
                }
                shoppingListViewModel.add(
                    basic,
                    quantity: ingredient.quantity,
                    sourceRecipeID: match.rankedRecipe.recipe.id,
                    sourceRecipeTitle: match.rankedRecipe.recipe.title
                )
                added += 1
            } else {
                let name = produceViewModel.recipeIngredientDisplayName(ingredient)
                if shoppingListViewModel.containsCustom(named: name) {
                    continue
                }
                shoppingListViewModel.addCustom(
                    name: name,
                    quantity: ingredient.quantity,
                    sourceRecipeID: match.rankedRecipe.recipe.id,
                    sourceRecipeTitle: match.rankedRecipe.recipe.title
                )
                added += 1
            }
        }

        if added == 0 {
            feedbackMessage = produceViewModel.localizer.text(.ingredientsAlreadyInList)
        } else {
            feedbackMessage = String(format: produceViewModel.localizer.text(.addedMissingItemsFormat), added)
        }
        showingFeedbackAlert = true
    }

    @ViewBuilder
    private func fridgePreviewIcon(item: FridgePreviewItem, size: CGFloat) -> some View {
        switch item.source {
        case .produce(let produce):
            ProduceThumbnailView(item: produce, size: size)
        case .basic:
            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "leaf")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                )
        }
    }

}

private struct FridgePreviewItem: Identifiable {
    enum Source {
        case produce(ProduceItem)
        case basic(BasicIngredient)
    }

    let id: String
    let title: String
    let source: Source

    static func produce(_ item: ProduceItem, languageCode: String, localizer: AppLocalizer) -> FridgePreviewItem {
        FridgePreviewItem(
            id: "produce-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            source: .produce(item)
        )
    }

    static func basic(_ item: BasicIngredient, languageCode: String, localizer: AppLocalizer) -> FridgePreviewItem {
        FridgePreviewItem(
            id: "basic-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            source: .basic(item)
        )
    }
}

#if DEBUG
extension ProduceViewModel {
    static var mock: ProduceViewModel {
        ProduceViewModel(languageCode: "en")
    }
}

extension ShoppingListViewModel {
    static var mock: ShoppingListViewModel {
        ShoppingListViewModel()
    }
}

extension FridgeViewModel {
    static var mock: FridgeViewModel {
        FridgeViewModel()
    }
}

#Preview("Empty state") {
    NavigationStack {
        HomeView(
            viewModel: .mock,
            shoppingListViewModel: .mock
        )
        .environmentObject(FridgeViewModel.mock)
    }
}

#Preview("With fridge items") {
    let vm = ProduceViewModel.mock
    let list = ShoppingListViewModel.mock
    let fridge = FridgeViewModel.mock

    if let first = vm.searchResults(query: "").first {
        fridge.add(first)
    }
    if vm.searchResults(query: "").count > 1 {
        fridge.add(vm.searchResults(query: "")[1])
    }

    return NavigationStack {
        HomeView(
            viewModel: vm,
            shoppingListViewModel: list
        )
        .environmentObject(fridge)
    }
}
#endif
