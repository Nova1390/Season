import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @ObservedObject private var followStore = FollowStore.shared
    @State private var selectedQuickFilter: HomeQuickFilter?
    @State private var cachedMiniFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
    @State private var cachedFilteredFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
    @State private var mainContinuousFeedItems: [HomeFeedItem] = []
    @State private var featuredRecipeCache: RankedRecipe?
    @State private var fridgeMatchesCache: [FridgeMatchedRecipe] = []
    @State private var ingredientUsageCountByID: [String: Int] = [:]
    private let homeQuickFilters: [HomeQuickFilter] = [.following, .readyNow, .under15, .highProtein, .peakSeason, .trending]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    fixedHeaderRow(safeAreaTopInset: proxy.safeAreaInsets.top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
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
            VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                HStack(spacing: SeasonSpacing.sm) {
                    Image(systemName: "snowflake")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.43, blue: 0.56))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.52))
                        )

                    Text(homeHeroTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                .fixedSize(horizontal: false, vertical: true)

                Text(homeHeroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(homeHeroCTA)
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.65))
                )

                if let supportLine = homeHeroSupportingSignal {
                    Text(supportLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(SeasonSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.92, blue: 0.86).opacity(0.96),
                                Color(red: 0.92, green: 0.89, blue: 0.84).opacity(0.88),
                                Color(red: 0.89, green: 0.87, blue: 0.82).opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator).opacity(0.18), lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardButtonStyle())
        .padding(.top, SeasonSpacing.sm)
        .padding(.bottom, SeasonSpacing.sm)
    }

    private var homeHeroState: HomeHeroState {
        let readyNowCount = fridgeMatches.filter { $0.missingCount == 0 }.count
        if readyNowCount > 0 {
            return .readyNow(count: readyNowCount)
        }

        let almostReadyCount = fridgeMatches.filter { $0.missingCount == 1 }.count
        if almostReadyCount > 0 {
            return .almostReady(count: almostReadyCount)
        }

        let seasonalCount: Int
        if let featuredRecipe, featuredRecipe.seasonalMatchPercent > 80 {
            seasonalCount = 1
        } else {
            seasonalCount = 0
        }
        return .seasonal(count: seasonalCount)
    }

    private var homeHeroTitle: String {
        switch homeHeroState {
        case .readyNow(let count):
            if let topReady = fridgeMatches.first(where: { $0.missingCount == 0 }) {
                let totalMinutes = recipeTotalMinutes(topReady.rankedRecipe.recipe)
                if totalMinutes > 0, totalMinutes <= 18 {
                    return String(format: viewModel.localizer.text(.readyInMinutesFormat), totalMinutes)
                }
            }

            let format = count == 1
                ? viewModel.localizer.text(.homeHeroReadySubtitleSingularFormat)
                : viewModel.localizer.text(.homeHeroReadySubtitlePluralFormat)
            return String(format: format, count)
        case .almostReady(let count):
            if let topAlmost = fridgeMatches.first(where: { $0.missingCount == 1 }) {
                let totalMinutes = recipeTotalMinutes(topAlmost.rankedRecipe.recipe)
                if totalMinutes > 0, totalMinutes <= 20 {
                    return String(format: viewModel.localizer.text(.readyInMinutesFormat), totalMinutes)
                }
            }
            if count == 1 {
                return viewModel.localizer.text(.quickActionOnlyOneIngredientMissing)
            }
            return String(format: viewModel.localizer.text(.homeHeroAlmostReadySubtitlePluralFormat), count)
        case .seasonal:
            if let featuredRecipe {
                let totalMinutes = recipeTotalMinutes(featuredRecipe.recipe)
                if totalMinutes > 0, totalMinutes <= 20 {
                    return String(format: viewModel.localizer.text(.readyInMinutesFormat), totalMinutes)
                }
                if featuredRecipe.seasonalMatchPercent >= 90 {
                    return viewModel.localizer.recipeTimingTitle(.perfectNow)
                }
            }
            return viewModel.localizer.text(.homeHeroSeasonalTitle)
        }
    }

    private var homeHeroSubtitle: String {
        switch homeHeroState {
        case .readyNow(let count):
            let format = count == 1
                ? viewModel.localizer.text(.homeHeroReadySubtitleSingularFormat)
                : viewModel.localizer.text(.homeHeroReadySubtitlePluralFormat)
            return String(format: format, count)
        case .almostReady(let count):
            let format = count == 1
                ? viewModel.localizer.text(.homeHeroAlmostReadySubtitleSingularFormat)
                : viewModel.localizer.text(.homeHeroAlmostReadySubtitlePluralFormat)
            return String(format: format, count)
        case .seasonal:
            if let featuredRecipe {
                return String(
                    format: viewModel.localizer.text(.recipeReasonSeasonalMatchFormat),
                    featuredRecipe.seasonalMatchPercent
                )
            }
            return viewModel.localizer.text(.homeHeroSeasonalSubtitle)
        }
    }

    private var homeHeroCTA: String {
        switch homeHeroState {
        case .readyNow:
            return localizedReadyNowHeroCTA(for: homeHeroDaypart)
        case .almostReady:
            return viewModel.localizer.text(.homeHeroAlmostReadyCTA)
        case .seasonal:
            return viewModel.localizer.text(.homeHeroSeasonalCTA)
        }
    }

    private var homeHeroDaypart: HomeHeroDaypart {
        HomeHeroDaypart(currentHour: Calendar.current.component(.hour, from: Date()))
    }

    private func localizedReadyNowHeroTitle(for daypart: HomeHeroDaypart) -> String {
        switch daypart {
        case .morning:
            return viewModel.localizer.text(.homeHeroReadyMorningTitle)
        case .lunch:
            return viewModel.localizer.text(.homeHeroReadyLunchTitle)
        case .afternoon:
            return viewModel.localizer.text(.homeHeroReadyAfternoonTitle)
        case .evening:
            return viewModel.localizer.text(.homeHeroReadyEveningTitle)
        case .lateNight:
            return viewModel.localizer.text(.homeHeroReadyLateNightTitle)
        }
    }

    private func localizedReadyNowHeroCTA(for daypart: HomeHeroDaypart) -> String {
        switch daypart {
        case .morning:
            return viewModel.localizer.text(.homeHeroReadyMorningCTA)
        case .lunch:
            return viewModel.localizer.text(.homeHeroReadyLunchCTA)
        case .afternoon:
            return viewModel.localizer.text(.homeHeroReadyAfternoonCTA)
        case .evening:
            return viewModel.localizer.text(.homeHeroReadyEveningCTA)
        case .lateNight:
            return viewModel.localizer.text(.homeHeroReadyLateNightCTA)
        }
    }

    private var homeHeroSupportingSignal: String? {
        switch homeHeroState {
        case .readyNow:
            guard
                let topReady = fridgeMatches.first(where: { $0.missingCount == 0 }),
                let title = cleanedHeroSupportingTitle(from: topReady.rankedRecipe.recipe.title)
            else { return nil }
            return String(format: viewModel.localizer.text(.homeHeroSupportBestMatchFormat), title)
        case .almostReady:
            guard
                let topAlmost = fridgeMatches.first(where: { $0.missingCount == 1 }),
                let title = cleanedHeroSupportingTitle(from: topAlmost.rankedRecipe.recipe.title)
            else { return nil }
            return String(format: viewModel.localizer.text(.homeHeroSupportOneMissingFormat), title)
        case .seasonal:
            guard
                let featuredRecipe,
                featuredRecipe.seasonalMatchPercent > 80,
                let title = cleanedHeroSupportingTitle(from: featuredRecipe.recipe.title)
            else { return nil }
            return String(format: viewModel.localizer.text(.homeHeroSupportBestMatchFormat), title)
        }
    }

    private func cleanedHeroSupportingTitle(from rawTitle: String) -> String? {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        let blockedTitles: Set<String> = [
            "test",
            "test jpg",
            "test recipe",
            "debug",
            "placeholder"
        ]
        guard !blockedTitles.contains(normalized) else { return nil }
        guard !normalized.hasPrefix("test ") else { return nil }

        return trimmed
    }

    private func recipeTotalMinutes(_ recipe: Recipe) -> Int {
        let prep = recipe.prepTimeMinutes ?? 0
        let cook = recipe.cookTimeMinutes ?? 0
        return prep + cook
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
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                SeasonSectionHeader(title: viewModel.localizer.text(.featuredRecipe))

                NavigationLink {
                    RecipeDetailView(
                        rankedRecipe: featured,
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        recipeImage(for: featured.recipe, height: 244)
                            .overlay(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.black.opacity(0.82), location: 0.0),
                                        .init(color: Color.black.opacity(0.46), location: 0.45),
                                        .init(color: Color.clear, location: 1.0)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(featured.recipe.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                Text(featured.recipe.author)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)

                                Text("·")
                                    .foregroundStyle(.white.opacity(0.6))

                                Text(featuredHook(for: featured))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, SeasonSpacing.md)
                        .padding(.bottom, SeasonSpacing.md)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
                    )
                }
                .buttonStyle(PressableCardButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var quickHorizontalStrip: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
            SeasonSectionHeader(title: viewModel.localizer.text(.smartSuggestionsTitle))

            SeasonCardContainer(
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SeasonSpacing.xs) {
                            ForEach(homeQuickFilters) { filter in
                                Button {
                                    selectQuickFilter(filter)
                                } label: {
                                    SeasonBadge(
                                        text: filter.title(using: viewModel.localizer),
                                        icon: filter.iconName,
                                        horizontalPadding: SeasonSpacing.xs + 2,
                                        verticalPadding: SeasonSpacing.xs,
                                        cornerRadius: SeasonRadius.small,
                                        foreground: selectedQuickFilter == filter ? .white : .primary,
                                        background: selectedQuickFilter == filter
                                        ? Color.accentColor.opacity(0.9)
                                        : SeasonColors.subtleSurface
                                    )
                                    .contentShape(Rectangle())
                                }
                                .frame(minHeight: 34)
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, SeasonSpacing.xs + 2)
                        .padding(.vertical, SeasonSpacing.xs + 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                },
                cornerRadius: SeasonRadius.large,
                background: SeasonColors.subtleSurface,
                backgroundOpacity: 0.72,
                borderOpacity: 0.06,
                shadowOpacity: 0.01,
                shadowRadius: 5,
                shadowY: 2
            )
        }
        .padding(.vertical, SeasonSpacing.xs)
        .background(Color(.systemGroupedBackground))
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var mixedFeedSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            if let selectedQuickFilter {
                if selectedQuickFilter == .following && activeFilteredFeedItems.isEmpty {
                    followingFeedEmptyState
                }

                VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                    if selectedQuickFilter == .following && !activeFilteredFeedItems.isEmpty {
                        followingFeedContextHeader
                    }

                    ForEach(Array(activeFilteredFeedItems.enumerated()), id: \.element.id) { _, item in
                        switch item {
                        case .recipe(let card, let style):
                            homeRecipeItem(card: card, style: style)
                                .padding(.top, style == .large ? SeasonSpacing.xs : 0)
                                .padding(.bottom, style == .large ? SeasonSpacing.sm : 0)
                        case .followingFallbackSeparator:
                            followingFallbackSeparatorLabel
                                .padding(.top, SeasonSpacing.xs)
                        case .fridge:
                            EmptyView()
                        case .spotlight:
                            EmptyView()
                        }
                    }
                }
                .id("filtered-\(selectedQuickFilter.rawValue)")
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
                .animation(.easeInOut(duration: 0.18), value: selectedQuickFilter)
            } else {
                VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                    ForEach(Array(activeMiniFeedItems.enumerated()), id: \.element.id) { _, item in
                        switch item {
                        case .recipe(let card, let style):
                            homeRecipeItem(card: card, style: style)
                                .padding(.bottom, style == .large ? SeasonSpacing.xs : 0)
                        case .followingFallbackSeparator:
                            EmptyView()
                        case .fridge(let match):
                            fridgeSuggestionCard(match)
                                .padding(.top, SeasonSpacing.xs)
                                .padding(.bottom, SeasonSpacing.xs)
                        case .spotlight(let ingredient):
                            spotlightCard(for: ingredient)
                                .padding(.top, SeasonSpacing.xs)
                                .padding(.bottom, SeasonSpacing.xs)
                        }
                    }
                }
                .id("default-mini")
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
                .animation(.easeInOut(duration: 0.18), value: selectedQuickFilter)

                ForEach(remainingFeedItems) { item in
                    switch item {
                    case .recipe(let card, let style):
                        homeRecipeItem(card: card, style: style)
                            .padding(.top, style == .large ? SeasonSpacing.sm : 0)
                            .padding(.bottom, style == .large ? SeasonSpacing.sm : 0)
                    case .followingFallbackSeparator:
                        EmptyView()
                    case .fridge(let match):
                        fridgeSuggestionCard(match)
                            .padding(.top, SeasonSpacing.xs)
                            .padding(.bottom, SeasonSpacing.xs)
                    case .spotlight(let ingredient):
                        spotlightCard(for: ingredient)
                            .padding(.top, SeasonSpacing.xs)
                            .padding(.bottom, SeasonSpacing.xs)
                    }
                }
            }
        }
    }

    private var followingFeedEmptyState: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            EmptyStateCard(
                symbol: "person.2.circle",
                title: viewModel.localizer.text(.followingFeedEmptyTitle),
                subtitle: viewModel.localizer.text(.followingFeedEmptySubtitle)
            )

            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    selectedQuickFilter = nil
                }
            } label: {
                Text(viewModel.localizer.text(.followingFeedEmptyCTA))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SeasonColors.subtleSurface)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, SeasonSpacing.xs)
    }

    private var followingFeedContextHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "person.2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.localizer.text(.fromPeopleYouFollow))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text(
                String(
                    format: viewModel.localizer.text(.followingFeedContextFormat),
                    followingPrimaryVisibleCount,
                    followStore.followingIds.count
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private var followingFallbackSeparatorLabel: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.8)
            Text(viewModel.localizer.text(.followingFeedFallbackLabel))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.8)
        }
        .padding(.vertical, 2)
    }

    private var featuredRecipe: RankedRecipe? {
        featuredRecipeCache
    }

    private var activeMiniFeedItems: [HomeFeedItem] {
        let recipeOnlySeed = mainContinuousFeedItems.filter {
            if case .recipe = $0 { return true }
            return false
        }
        return guaranteedMiniBlock(from: Array(recipeOnlySeed.prefix(3)))
    }

    private var activeFilteredFeedItems: [HomeFeedItem] {
        guard let selectedQuickFilter else { return [] }
        let filtered = cachedFilteredFeeds[selectedQuickFilter] ?? []
        if selectedQuickFilter == .following {
            if cachedFilteredFeeds[selectedQuickFilter] != nil {
                print("[SEASON_HOME_FOLLOWING] phase=cache_hit filter=following")
            } else {
                print("[SEASON_HOME_FOLLOWING] phase=cache_miss filter=following")
            }
            let followingRecipeItems = filtered.flatMap { item -> [HookedRecipeCard] in
                switch item {
                case .recipe(let card, _):
                    return [card]
                case .fridge(let match):
                    let card = HookedRecipeCard(
                        ranked: match.rankedRecipe,
                        hook: fridgePrimaryMessage(for: match),
                        hookKind: .almostReady
                    )
                    return [card]
                case .spotlight:
                    return []
                case .followingFallbackSeparator:
                    return []
                }
            }
            print("[SEASON_HOME_FOLLOWING] phase=feed_resolved filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRecipeItems.count)")
            for card in followingRecipeItems.prefix(5) {
                let creatorID = card.ranked.recipe.canonicalCreatorID ?? "nil"
                print("[SEASON_HOME_FOLLOWING] phase=feed_item recipe_id=\(card.ranked.recipe.id) creator_id=\(creatorID)")
            }
        }
        return filtered
    }

    private var followingPrimaryVisibleCount: Int {
        guard selectedQuickFilter == .following else { return 0 }
        let followedIDs = followStore.followingIds
        return activeFilteredFeedItems.reduce(into: 0) { partial, item in
            guard case .recipe(let card, _) = item else { return }
            if let creatorID = card.ranked.recipe.canonicalCreatorID,
               followedIDs.contains(creatorID) {
                partial += 1
            }
        }
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
        let followingIDs = followStore.followingIds.sorted().joined(separator: "|")
        return "\(viewModel.languageCode)|\(viewModel.recipes.count)|\(fridgeIDs)|\(viewModel.currentMonth)|\(viewModel.homeFeedRefreshID)|\(followingIDs)"
    }

    private func refreshHomeFeedCache() {
        let feed = buildHomeFeed()
        featuredRecipeCache = feed.featured
        fridgeMatchesCache = feed.fridgeMatches
        ingredientUsageCountByID = feed.ingredientUsageCountByID
        mainContinuousFeedItems = feed.defaultFeedItems
        cachedMiniFeeds = feed.filteredMiniFeeds
        cachedFilteredFeeds = feed.filteredFeeds
    }

    private func buildHomeFeed() -> HomeFeedBuild {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet
        let homeRecipes = viewModel.homeRankedRecipes(limit: 120)
        let personalizationProfile = FeedPersonalizationService.shared.buildProfile(from: homeRecipes)
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
        let personalizedContinuousRecipes = personalizedRanking(
            candidates: continuousRecipes,
            personalization: personalizationProfile,
            fridgeItemIDs: fridgeIDs
        )

        let maxRecipeCards = max(40, min(180, personalizedContinuousRecipes.count * 3))
        let primaryCards = enforceFeedDiversity(
            cards: buildHookedCards(
                from: personalizedContinuousRecipes,
                preferTrending: false,
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
        let personalizedBackupRecipes = personalizedRanking(
            candidates: homeRecipes,
            personalization: personalizationProfile,
            fridgeItemIDs: fridgeIDs
        )
        let backupCards = enforceFeedDiversity(
            cards: buildHookedCards(
                from: personalizedBackupRecipes,
                preferTrending: false,
                trendingIDs: trendingIDs,
                previousHook: primaryCards.last?.hookKind
            ),
            trendingCards: [],
            targetCount: max(30, min(120, homeRecipes.count))
        )
        let mergedCards = mergeCards(primary: primaryCards, backup: backupCards)
        let defaultFeedTargetCount = max(14, min(70, (mergedCards.count / 2) + 8))
        let defaultFeedItems = buildSimpleFeed(
            cards: mergedCards,
            spotlightItems: spotlight,
            fridgeMatches: fridgeMatches,
            targetCount: defaultFeedTargetCount
        )
        debugHomeFeed("default feed count=\(defaultFeedItems.count)")

        var miniFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
        var filteredFeeds: [HomeQuickFilter: [HomeFeedItem]] = [:]
        for filter in homeQuickFilters {
            miniFeeds[filter] = buildMiniFeedBlock(
                for: filter,
                baseRecipes: personalizedContinuousRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: personalizedBackupRecipes,
                trendingIDs: trendingIDs,
                fridgeItemIDs: fridgeIDs,
                personalization: personalizationProfile
            )
            filteredFeeds[filter] = buildFilteredFeed(
                for: filter,
                baseRecipes: personalizedContinuousRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: personalizedBackupRecipes,
                trendingIDs: trendingIDs,
                fridgeItemIDs: fridgeIDs,
                personalization: personalizationProfile
            )
        }

        return HomeFeedBuild(
            featured: featured,
            fridgeMatches: fridgeMatches,
            defaultFeedItems: defaultFeedItems,
            filteredMiniFeeds: miniFeeds,
            filteredFeeds: filteredFeeds,
            ingredientUsageCountByID: ingredientUsageCount
        )
    }

    private func buildFilteredFeed(
        for filter: HomeQuickFilter,
        baseRecipes: [RankedRecipe],
        trendingRecipes: [RankedRecipe],
        backupRecipes: [RankedRecipe],
        trendingIDs: Set<String>,
        fridgeItemIDs: Set<String>,
        personalization: FeedPersonalizationProfile
    ) -> [HomeFeedItem] {
        let cards: [HookedRecipeCard]

        if filter == .following {
            let followedCreatorIDs = followStore.followingIds
            let followingRanked = viewModel.rankedFollowingRecipes(
                followedCreatorIDs: Array(followedCreatorIDs),
                limit: 60
            )
            print("[SEASON_HOME_FOLLOWING] phase=feed_computed filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRanked.count)")
            guard !followingRanked.isEmpty else { return [] }
            let followingCards = enforceFeedDiversity(
                cards: buildHookedCards(
                    from: followingRanked,
                    preferTrending: false,
                    trendingIDs: trendingIDs,
                    previousHook: nil
                ),
                trendingCards: [],
                targetCount: 30
            )
            let primaryItems = buildEditorialFilteredItems(from: followingCards, targetCount: 14)

            let primaryRecipeIDs: Set<String> = Set(
                primaryItems.compactMap { item -> String? in
                    guard case .recipe(let card, _) = item else { return nil }
                    return card.ranked.recipe.id
                }
            )
            let fallbackCandidates = mergedCandidateRecipes(
                baseRecipes: baseRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: backupRecipes
            ).filter { ranked in
                guard !primaryRecipeIDs.contains(ranked.recipe.id) else { return false }
                if let creatorID = ranked.recipe.canonicalCreatorID,
                   followedCreatorIDs.contains(creatorID) {
                    return false
                }
                return true
            }

            let minimumTargetCount = 8
            let fallbackTarget = min(4, max(0, minimumTargetCount - primaryItems.count))
            if fallbackTarget > 0 {
                let fallbackCards = enforceFeedDiversity(
                    cards: buildHookedCards(
                        from: fallbackCandidates,
                        preferTrending: false,
                        trendingIDs: trendingIDs,
                        previousHook: followingCards.last?.hookKind
                    ),
                    trendingCards: [],
                    targetCount: fallbackTarget
                )
                let fallbackItems = fallbackCards.prefix(fallbackTarget).map { HomeFeedItem.recipe($0, style: .compact) }
                return deduplicatedFollowingFeedItems(primaryItems + [.followingFallbackSeparator] + fallbackItems)
            }
            return deduplicatedFollowingFeedItems(primaryItems)
        } else {
            let mergedCandidates = mergedCandidateRecipes(
                baseRecipes: baseRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: backupRecipes
            )
            let reranked = smartBoostedRanking(
                for: filter,
                candidates: mergedCandidates,
                fridgeItemIDs: fridgeItemIDs,
                personalization: personalization
            )
            cards = enforceFeedDiversity(
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
                targetCount: 30
            )
        }

        return buildEditorialFilteredItems(from: cards, targetCount: 18)
    }

    private func buildEditorialFilteredItems(
        from cards: [HookedRecipeCard],
        targetCount: Int
    ) -> [HomeFeedItem] {
        guard !cards.isEmpty else { return [] }
        var items: [HomeFeedItem] = []
        for (index, card) in cards.prefix(targetCount).enumerated() {
            items.append(.recipe(card, style: index == 0 ? .large : .compact))
        }

        return items
    }

    private func deduplicatedFollowingFeedItems(_ items: [HomeFeedItem]) -> [HomeFeedItem] {
        var seenRecipeIDs = Set<String>()
        var deduplicated: [HomeFeedItem] = []
        var separatorIndex: Int?

        for item in items {
            switch item {
            case .recipe(let card, _):
                guard !seenRecipeIDs.contains(card.ranked.recipe.id) else { continue }
                seenRecipeIDs.insert(card.ranked.recipe.id)
                deduplicated.append(item)
            case .followingFallbackSeparator:
                guard separatorIndex == nil else { continue }
                separatorIndex = deduplicated.count
                deduplicated.append(item)
            case .fridge, .spotlight:
                deduplicated.append(item)
            }
        }

        if let separatorIndex {
            let hasRecipesAfterSeparator = deduplicated.dropFirst(separatorIndex + 1).contains { item in
                if case .recipe = item { return true }
                return false
            }
            if !hasRecipesAfterSeparator {
                deduplicated.remove(at: separatorIndex)
            }
        }

        return deduplicated
    }

    private func buildMiniFeedBlock(
        for filter: HomeQuickFilter,
        baseRecipes: [RankedRecipe],
        trendingRecipes: [RankedRecipe],
        backupRecipes: [RankedRecipe],
        trendingIDs: Set<String>,
        fridgeItemIDs: Set<String>,
        personalization: FeedPersonalizationProfile
    ) -> [HomeFeedItem] {
        if filter == .following {
            let followingRanked = viewModel.rankedFollowingRecipes(
                followedCreatorIDs: Array(followStore.followingIds),
                limit: 24
            )
            print("[SEASON_HOME_FOLLOWING] phase=feed_computed filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRanked.count)")
            guard !followingRanked.isEmpty else { return [] }
            let cards = buildHookedCards(
                from: followingRanked,
                preferTrending: false,
                trendingIDs: trendingIDs,
                previousHook: nil
            )
            return cards.prefix(3).map { HomeFeedItem.recipe($0, style: .compact) }
        }

        let mergedCandidates = mergedCandidateRecipes(
            baseRecipes: baseRecipes,
            trendingRecipes: trendingRecipes,
            backupRecipes: backupRecipes
        )
        let reranked = smartBoostedRanking(
            for: filter,
            candidates: mergedCandidates,
            fridgeItemIDs: fridgeItemIDs,
            personalization: personalization
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
        case .fridge(let match):
            return "fridge-\(match.rankedRecipe.recipe.id)"
        case .spotlight(let ingredient):
            return "spotlight-\(ingredient.item.id)"
        case .followingFallbackSeparator:
            return "following-fallback-separator"
        }
    }

    private func recipeIDs(in item: HomeFeedItem) -> Set<String> {
        switch item {
        case .recipe(let card, _):
            return [card.ranked.recipe.id]
        case .fridge(let match):
            return [match.rankedRecipe.recipe.id]
        case .spotlight, .followingFallbackSeparator:
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
        fridgeItemIDs: Set<String>,
        personalization: FeedPersonalizationProfile
    ) -> [RankedRecipe] {
        let scored = candidates
            .map { ranked in
                let baseScore = min(1.0, max(0.0, ranked.score / 100.0))
                let boost = smartSuggestionBoost(for: filter, ranked: ranked, fridgeItemIDs: fridgeItemIDs)
                let fridgeMatch = fridgeItemIDs.isEmpty ? 0.0 : viewModel.fridgeMatchScore(for: ranked.recipe, fridgeItemIDs: fridgeItemIDs)
                let personalizationEval = personalization.evaluation(for: ranked, fridgeMatchScore: fridgeMatch)
                let score = baseScore + boost + personalizationEval.adjustment
                return (ranked: ranked, score: score, reasons: personalizationEval.reasons)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }

        if isFeedIntelligenceDebugEnabled {
            let summary = scored
                .prefix(3)
                .map { "\($0.ranked.recipe.id):\(String(format: "%.3f", $0.score)):\($0.reasons.joined(separator: ","))" }
                .joined(separator: " | ")
            debugFeedIntelligence("phase=filter_ranked filter=\(filter.rawValue) count=\(scored.count) top=\(summary)")
        }

        return scored.map(\.ranked)
    }

    private func personalizedRanking(
        candidates: [RankedRecipe],
        personalization: FeedPersonalizationProfile,
        fridgeItemIDs: Set<String>
    ) -> [RankedRecipe] {
        guard personalization.isActive else { return candidates }

        let ranked = candidates
            .map { ranked in
                let baseScore = min(1.0, max(0.0, ranked.score / 100.0))
                let fridgeMatch = fridgeItemIDs.isEmpty ? 0.0 : viewModel.fridgeMatchScore(for: ranked.recipe, fridgeItemIDs: fridgeItemIDs)
                let personalizationEval = personalization.evaluation(for: ranked, fridgeMatchScore: fridgeMatch)
                return (ranked: ranked, score: baseScore + personalizationEval.adjustment, reasons: personalizationEval.reasons)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }
            .map(\.ranked)

        if isFeedIntelligenceDebugEnabled {
            debugFeedIntelligence("phase=personalization_active quick=\(String(format: "%.2f", personalization.quickRecipePreference)) seasonal=\(String(format: "%.2f", personalization.seasonalPreference)) fridge=\(String(format: "%.2f", personalization.fridgeActionAffinity)) saved_crispy=\(String(format: "%.2f", personalization.savedCrispiedAffinity))")
        }

        return ranked
    }

    private var isFeedIntelligenceDebugEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SEASON_FEED_INTEL_DEBUG"] == "1"
        #else
        false
        #endif
    }

    private func debugFeedIntelligence(_ message: String) {
        guard isFeedIntelligenceDebugEnabled else { return }
        print("[SEASON_FEED_INTEL] \(message)")
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
        case .following:
            return 0
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

    private func mergeCards(
        primary: [HookedRecipeCard],
        backup: [HookedRecipeCard]
    ) -> [HookedRecipeCard] {
        var merged: [HookedRecipeCard] = []
        var seen: Set<String> = []
        for card in (primary + backup) where !seen.contains(card.ranked.recipe.id) {
            seen.insert(card.ranked.recipe.id)
            merged.append(card)
        }
        return merged
    }

    private func buildSimpleFeed(
        cards: [HookedRecipeCard],
        spotlightItems: [RankedInSeasonItem],
        fridgeMatches: [FridgeMatchedRecipe],
        targetCount: Int
    ) -> [HomeFeedItem] {
        guard !cards.isEmpty else { return [] }

        var result: [HomeFeedItem] = []
        var cardIndex = 0
        var spotlightIndex = 0
        var fridgeIndex = 0
        var breakCycle = 0

        while result.count < targetCount && cardIndex < cards.count {
            let rowsBeforeBreak = (breakCycle % 2 == 0) ? 3 : 4
            var rowsAdded = 0

            while rowsAdded < rowsBeforeBreak, cardIndex < cards.count, result.count < targetCount {
                result.append(.recipe(cards[cardIndex], style: .compact))
                cardIndex += 1
                rowsAdded += 1
            }

            guard result.count < targetCount else { break }

            // Editorial cadence:
            // first break is a large highlight, then spotlight/fridge,
            // then large appears again occasionally (every 3 cycles).
            let prefersLargeBreak = (breakCycle == 0 || breakCycle.isMultiple(of: 3))
            var insertedBreak = false

            if prefersLargeBreak, cardIndex < cards.count {
                result.append(.recipe(cards[cardIndex], style: .large))
                cardIndex += 1
                insertedBreak = true
            } else if spotlightIndex < spotlightItems.count {
                result.append(.spotlight(spotlightItems[spotlightIndex]))
                spotlightIndex += 1
                insertedBreak = true
            } else if fridgeIndex < fridgeMatches.count {
                result.append(.fridge(fridgeMatches[fridgeIndex]))
                fridgeIndex += 1
                insertedBreak = true
            } else if spotlightIndex < spotlightItems.count {
                result.append(.spotlight(spotlightItems[spotlightIndex]))
                spotlightIndex += 1
                insertedBreak = true
            } else if fridgeIndex < fridgeMatches.count {
                result.append(.fridge(fridgeMatches[fridgeIndex]))
                fridgeIndex += 1
                insertedBreak = true
            } else if cardIndex < cards.count, prefersLargeBreak {
                result.append(.recipe(cards[cardIndex], style: .large))
                cardIndex += 1
                insertedBreak = true
            }

            if !insertedBreak {
                break
            }
            breakCycle += 1
        }

        return result
    }

    @ViewBuilder
    private func homeRecipeItem(card: HookedRecipeCard, style: HomeRecipeCardStyle) -> some View {
        let followedCreator = isFollowedCreator(card.ranked.recipe.canonicalCreatorID)
        if style == .large {
            largeRecipeCard(
                ranked: card.ranked,
                hook: card.hook,
                showFollowingSignal: selectedQuickFilter == .following && followedCreator
            )
                .padding(.top, SeasonSpacing.sm)
                .padding(.bottom, SeasonSpacing.sm)
        } else {
            compactRecipeCard(
                ranked: card.ranked,
                hook: card.hook,
                showFollowingSignal: selectedQuickFilter == .following && followedCreator
            )
        }
    }

    private func isFollowedCreator(_ creatorID: String?) -> Bool {
        guard let creatorID else { return false }
        return followStore.followingIds.contains(creatorID)
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
            if selectedQuickFilter == .following {
                print("[SEASON_HOME_FOLLOWING] phase=filter_selected filter=following")
            }
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
    private func largeRecipeCard(ranked: RankedRecipe, hook: String, showFollowingSignal: Bool) -> some View {
        NavigationLink {
            RecipeDetailView(
                rankedRecipe: ranked,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        } label: {
            VStack(alignment: .leading, spacing: SeasonSpacing.xs + 2) {
                recipeImage(for: ranked.recipe, height: 172)

                Text(ranked.recipe.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(ranked.recipe.author)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if showFollowingSignal {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(viewModel.localizer.text(.following))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    SeasonBadge(
                        text: hook,
                        horizontalPadding: SeasonSpacing.xs,
                        verticalPadding: 4,
                        cornerRadius: SeasonRadius.small,
                        foreground: .secondary,
                        background: SeasonColors.subtleSurface
                    )

                    Spacer(minLength: 0)

                    SeasonalStatusBadge(score: ranked.seasonalityScore, localizer: viewModel.localizer)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func compactRecipeCard(ranked: RankedRecipe, hook: String, showFollowingSignal: Bool) -> some View {
        let emphasizeAuthor = selectedQuickFilter == .following
        NavigationLink {
            RecipeDetailView(
                rankedRecipe: ranked,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        } label: {
            HomeEditorialRecipeRow(
                recipe: ranked.recipe,
                hook: hook,
                seasonalityScore: ranked.seasonalityScore,
                localizer: viewModel.localizer,
                emphasizeAuthor: emphasizeAuthor,
                showFollowingSignal: showFollowingSignal
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fridgeSuggestionCard(_ match: FridgeMatchedRecipe, emphasize: Bool = false) -> some View {
        NavigationLink {
            RecipeDetailView(
                rankedRecipe: match.rankedRecipe,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        } label: {
            RecipeCardView(
                recipe: match.rankedRecipe.recipe,
                title: match.rankedRecipe.recipe.title,
                subtitle: emphasize ? nil : match.rankedRecipe.recipe.author,
                metadataText: fridgePrimaryMessage(for: match),
                seasonalityScore: emphasize ? match.rankedRecipe.seasonalityScore : nil,
                localizer: emphasize ? viewModel.localizer : nil,
                variant: .feedCompact,
                cardBackground: SeasonColors.secondarySurface,
                cardBackgroundOpacity: emphasize ? 0.88 : 0.84,
                cardBorderOpacity: 0.055,
                cardShadowOpacity: emphasize ? 0.018 : 0.013,
                cardShadowRadius: emphasize ? 6 : 5,
                cardShadowY: 2
            )
            .padding(.vertical, emphasize ? 1 : 0)
        }
        .buttonStyle(PressableCardButtonStyle())
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
        SeasonCardContainer(
            content: {
            NavigationLink {
                ProduceDetailView(
                    item: ranked.item,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
                .environmentObject(fridgeViewModel)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    ProduceThumbnailView(item: ranked.item, size: 54)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(ranked.item.displayName(languageCode: viewModel.languageCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.caption2.weight(.semibold))
                            Text(seasonalSpotlightStateText(for: ranked.item))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SeasonSpacing.sm)
                .padding(.vertical, SeasonSpacing.xs + 2)
            }
            .buttonStyle(PressableCardButtonStyle())
            },
            cornerRadius: SeasonRadius.large,
            background: Color(red: 0.95, green: 0.94, blue: 0.90),
            backgroundOpacity: 0.72,
            borderOpacity: 0.04,
            shadowOpacity: 0.008,
            shadowRadius: 3,
            shadowY: 1
        )
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

    private func primaryHook(for ranked: RankedRecipe) -> RecipePrimaryHook {
        if let match = fridgeMatchByRecipeID[ranked.recipe.id] {
            if match.missingCount == 0 {
                return .init(
                    kind: .readyNow,
                    text: viewModel.localizer.text(.readyNow)
                )
            }

            if match.missingCount == 1 {
                return .init(
                    kind: .almostReady,
                    text: viewModel.localizer.text(.homeHookOneIngredientMissing)
                )
            }
        }

        if let prepMinutes = ranked.recipe.prepTimeMinutes, prepMinutes > 0, prepMinutes <= 20 {
            return .init(
                kind: .quickMeal,
                text: String(format: viewModel.localizer.text(.readyInMinutesFormat), prepMinutes)
            )
        }

        if ranked.seasonalMatchPercent >= 75 {
            return .init(
                kind: .peakSeason,
                text: viewModel.localizer.recipeTimingTitle(.perfectNow)
            )
        }

        return .init(
            kind: .trending,
            text: viewModel.localizer.text(.homeHookTrendingFallback)
        )
    }

    private func buildHookedCards(
        from recipes: [RankedRecipe],
        preferTrending: Bool,
        trendingIDs: Set<String>,
        previousHook: HookKind?
    ) -> [HookedRecipeCard] {
        var lastHookKind = previousHook
        var consecutiveTrendingCount = 0
        return recipes.map { ranked in
            let primary = primaryHook(for: ranked)

            var chosen = primary

            // Soft anti-repetition guard: avoid 3 "Trending now" hooks in a row when possible.
            if chosen.kind == .trending, consecutiveTrendingCount >= 2 {
                if let match = fridgeMatchByRecipeID[ranked.recipe.id], match.missingCount <= 2 {
                    chosen = match.missingCount == 0
                        ? .init(kind: .readyNow, text: viewModel.localizer.text(.readyNow))
                        : .init(kind: .almostReady, text: viewModel.localizer.text(.homeHookOneIngredientMissing))
                } else if let prepMinutes = ranked.recipe.prepTimeMinutes, prepMinutes > 0, prepMinutes <= 20 {
                    chosen = .init(
                        kind: .quickMeal,
                        text: String(format: viewModel.localizer.text(.readyInMinutesFormat), prepMinutes)
                    )
                } else if ranked.seasonalMatchPercent >= 80 {
                    chosen = .init(
                        kind: .peakSeason,
                        text: viewModel.localizer.recipeTimingTitle(.perfectNow)
                    )
                }
            }

            if chosen.kind == .trending {
                consecutiveTrendingCount += 1
            } else {
                consecutiveTrendingCount = 0
            }
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

private struct HomeEditorialRecipeRow: View {
    let recipe: Recipe
    let hook: String
    let seasonalityScore: Double
    let localizer: AppLocalizer
    let emphasizeAuthor: Bool
    let showFollowingSignal: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeThumbnailView(recipe: recipe, size: 72)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recipe.author)
                    .font(emphasizeAuthor ? .caption.weight(.semibold) : .caption.weight(.medium))
                    .foregroundStyle(
                        emphasizeAuthor
                        ? AnyShapeStyle(.primary.opacity(0.88))
                        : AnyShapeStyle(.secondary)
                    )
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(hook)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if showFollowingSignal {
                        Text("•")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Text(localizer.text(.following))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SeasonalStatusBadge(score: seasonalityScore, localizer: localizer)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private enum HomeQuickFilter: String, CaseIterable, Identifiable {
    case following
    case readyNow
    case under15
    case highProtein
    case peakSeason
    case trending

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .following:
            return "person.2"
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
        case .following:
            return localizer.text(.fromPeopleYouFollow)
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

private enum HomeHeroState {
    case readyNow(count: Int)
    case almostReady(count: Int)
    case seasonal(count: Int)
}

private enum HomeHeroDaypart {
    case morning
    case lunch
    case afternoon
    case evening
    case lateNight

    init(currentHour: Int) {
        switch currentHour {
        case 6...10:
            self = .morning
        case 11...14:
            self = .lunch
        case 15...17:
            self = .afternoon
        case 18...22:
            self = .evening
        default:
            self = .lateNight
        }
    }
}

private struct HomeFeedBuild {
    let featured: RankedRecipe?
    let fridgeMatches: [FridgeMatchedRecipe]
    let defaultFeedItems: [HomeFeedItem]
    let filteredMiniFeeds: [HomeQuickFilter: [HomeFeedItem]]
    let filteredFeeds: [HomeQuickFilter: [HomeFeedItem]]
    let ingredientUsageCountByID: [String: Int]
}

private enum HomeRecipeCardStyle {
    case compact
    case large
}

private enum HomeFeedItem: Identifiable {
    case recipe(HookedRecipeCard, style: HomeRecipeCardStyle)
    case fridge(FridgeMatchedRecipe)
    case spotlight(RankedInSeasonItem)
    case followingFallbackSeparator

    var id: String {
        switch self {
        case .recipe(let card, let style):
            return "recipe-\(style)-\(card.ranked.recipe.id)"
        case .fridge(let match):
            return "fridge-\(match.rankedRecipe.recipe.id)"
        case .spotlight(let item):
            return "spotlight-\(item.item.id)"
        case .followingFallbackSeparator:
            return "following-fallback-separator"
        }
    }
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
                countText: bestMatches.count.compactFormatted()
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
                    countText: quickOptions.count.compactFormatted()
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
