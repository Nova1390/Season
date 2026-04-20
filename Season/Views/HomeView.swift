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
    @State private var appliedCacheSignature: String?
    private let homeQuickFilters: [HomeQuickFilter] = [.following, .readyNow, .under15, .highProtein, .peakSeason, .trending]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SeasonColors.primarySurface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    fixedHeaderRow(safeAreaTopInset: proxy.safeAreaInsets.top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                            alwaysOnHeroSection
                            if hasFridgeMatches {
                                readyToCookNowSection
                            }
                            belowFoldSections
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, SeasonSpacing.lg)
                        .padding(.top, SeasonSpacing.sm)
                        .padding(.bottom, SeasonLayout.bottomBarContentClearance + SeasonSpacing.sm)
                    }
                    .refreshable {
                        await viewModel.refreshHomeFeed()
                    }
                }
            }
        }
        .task(id: cacheSignature) {
            await refreshHomeFeedCache(for: cacheSignature)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
    }

    @ViewBuilder
    private var alwaysOnHeroSection: some View {
        // Keep hero permanently visible regardless of feed state.
        cookNowHeroSection
    }

    @ViewBuilder
    private var belowFoldSections: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
            seasonalNowSection
                .padding(.top, 0)

            demotedHomeSections
                .padding(.top, SeasonSpacing.sm)
        }
    }

    private func fixedHeaderRow(safeAreaTopInset: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.localizer.text(.homeTab))
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Text(homeMastheadLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            topRightActions
        }
        .padding(.top, safeAreaTopInset + 6)
        .padding(.horizontal, SeasonSpacing.md)
        .padding(.bottom, SeasonSpacing.sm)
        .background(SeasonColors.primarySurface)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(SeasonColors.secondarySurface.opacity(0.95))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                    )
                    .contentShape(Rectangle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            NavigationLink {
                ShoppingListView(
                    produceViewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                Image(systemName: "bag")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(SeasonColors.secondarySurface.opacity(0.95))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                    )
                    .contentShape(Rectangle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SeasonColors.secondarySurface.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.6)
        )
    }

    private var heroContextLabel: String {
        switch homeHeroState {
        case .readyNow:
            return "Use up your ingredients"
        case .almostReady:
            return "One ingredient away"
        case .seasonal:
            return "Peak season pick"
        }
    }

    private var bestMatchBadgeText: String {
        if let topMatch = fridgeMatches.first {
            return "(\(topMatch.matchingCount)/\(topMatch.totalCount))"
        }
        if let featured = featuredRecipe {
            return "(\(featured.seasonalMatchPercent)%)"
        }
        return ""
    }

    @ViewBuilder
    private var cookNowHeroSection: some View {
        NavigationLink {
            if let topRecipe = cookNowTopRecipe {
                RecipeDetailView(
                    rankedRecipe: topRecipe,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } else {
                FridgeView(
                    produceViewModel: viewModel,
                    fridgeViewModel: fridgeViewModel
                )
            }
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let topRecipe = cookNowTopRecipe {
                            recipeImage(
                                for: topRecipe.recipe,
                                height: hasFridgeMatches ? 214 : 184
                            )
                        } else {
                            RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.44, blue: 0.31),
                                            Color(red: 0.29, green: 0.35, blue: 0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: hasFridgeMatches ? 214 : 184)
                        }
                    }

                    if !bestMatchBadgeText.isEmpty {
                        Text(bestMatchBadgeText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(red: 0.24, green: 0.29, blue: 0.20))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.92))
                            )
                            .padding(12)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(heroContextLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.30))

                    Text(cookNowTopRecipe?.recipe.title ?? cookNowHeroTitle)
                        .font(.system(size: hasFridgeMatches ? 31 : 28, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(cookNowHeroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(cookNowHeroCTA)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(SeasonColors.seasonGreen)
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(SeasonColors.secondarySurface.opacity(0.95))
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private var cookNowTopRecipe: RankedRecipe? {
        guard !fridgeMatches.isEmpty else { return nil }
        return fridgeMatches.first?.rankedRecipe
    }

    private var hasFridgeMatches: Bool {
        !fridgeMatches.isEmpty
    }

    private var homeCopyFromYourFridgeTitle: String {
        viewModel.localizer.localized("home.section.from_fridge.title")
    }

    private var homeCopyFridgeSubtitle: String {
        viewModel.localizer.localized("home.section.from_fridge.subtitle")
    }

    private var homeCopySeeAllMatches: String {
        viewModel.localizer.localized("home.section.from_fridge.cta")
    }

    private var homeCopySeasonalTitle: String {
        viewModel.localizer.localized("home.section.seasonal.title")
    }

    private var homeCopySeasonalSubtitle: String {
        viewModel.localizer.localized("home.section.seasonal.subtitle")
    }

    private var homeCopySeasonalCTA: String {
        viewModel.localizer.localized("home.section.seasonal.cta")
    }

    private var homeCopyMoreIdeas: String {
        viewModel.localizer.localized("home.section.more_ideas")
    }

    private var homeCopyWeeklyLabel: String {
        viewModel.localizer.localized("home.section.weekly.label")
    }

    private var homeCopyWeeklyTitle: String {
        viewModel.localizer.localized("home.section.weekly.title")
    }

    private var homeCopyInStockBadge: String {
        viewModel.localizer.localized("home.badge.in_stock")
    }

    private var homeCopyRecipesCountSuffix: String {
        viewModel.localizer.localized("home.badge.recipes")
    }

    private var homeMastheadLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return formatter.string(from: Date())
    }

    private var topLaneRecipeIDs: Set<String> {
        var ids = Set(fridgeMatches.map { $0.rankedRecipe.recipe.id })
        if let heroID = cookNowTopRecipe?.recipe.id {
            ids.insert(heroID)
        }
        return ids
    }

    private var cookNowHeroTitle: String {
        guard hasFridgeMatches else {
            return viewModel.localizer.localized("home.hero.empty_title")
        }
        return viewModel.localizer.localized("home.hero.title")
    }

    private var cookNowHeroSubtitle: String {
        guard hasFridgeMatches else {
            return viewModel.localizer.localized("home.hero.empty_subtitle")
        }

        let readyCount = fridgeMatches.filter { $0.missingCount == 0 }.count
        if readyCount > 0 {
            return String(
                format: viewModel.localizer.localized("home.hero.ready_count_format"),
                readyCount
            )
        }
        return viewModel.localizer.localized("home.hero.subtitle.closest_matches")
    }

    private var cookNowHeroCTA: String {
        if hasFridgeMatches {
            return viewModel.localizer.localized("home.hero.cta.cook_now")
        }
        return viewModel.localizer.localized("home.hero.cta.add_ingredients")
    }

    @ViewBuilder
    private var readyToCookNowSection: some View {
        let heroRecipeID = cookNowTopRecipe?.recipe.id
        let fridgeMatchesExcludingHero = fridgeMatches.filter { match in
            guard let heroRecipeID else { return true }
            return match.rankedRecipe.recipe.id != heroRecipeID
        }

        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(homeCopyFromYourFridgeTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(homeCopyFridgeSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                NavigationLink {
                    FridgeRecipeMatchesView(
                        produceViewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel,
                        fridgeViewModel: fridgeViewModel
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text(homeCopySeeAllMatches)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.32, green: 0.38, blue: 0.28))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SeasonColors.secondarySurface.opacity(0.8))
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
            }

            if fridgeMatchesExcludingHero.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.localizer.text(.quickActionNoMatchesYet))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(viewModel.localizer.text(.quickActionAddIngredientsHint))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(fridgeMatchesExcludingHero.prefix(4)).indices, id: \.self) { index in
                        let match = fridgeMatchesExcludingHero[index]
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: match.rankedRecipe,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            HStack(spacing: 10) {
                                recipeImage(for: match.rankedRecipe.recipe, height: 66, width: 82)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(match.rankedRecipe.recipe.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(fridgePrimaryMessage(for: match))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    Text("\(match.matchingCount)/\(match.totalCount) \(homeCopyInStockBadge)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color(red: 0.34, green: 0.42, blue: 0.30))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableCardButtonStyle())

                        if index < min(3, fridgeMatchesExcludingHero.prefix(4).count - 1) {
                            Divider()
                                .overlay(Color.primary.opacity(0.07))
                                .padding(.leading, 92)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SeasonColors.secondarySurface.opacity(0.74))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
                )
            }
        }
    }

    private var seasonalNowSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            HStack(alignment: .center) {
                Text(homeCopySeasonalTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                NavigationLink {
                    InSeasonTodayView(
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    Text(homeCopySeasonalCTA)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(seasonalSpotlightItems.prefix(8)), id: \.item.id) { ranked in
                        NavigationLink {
                            ProduceDetailView(
                                item: ranked.item,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                            .environmentObject(fridgeViewModel)
                        } label: {
                            VStack(alignment: .center, spacing: 3) {
                                ProduceThumbnailView(item: ranked.item, size: 44)
                                    .frame(width: 44, height: 44)

                                Text(ranked.item.displayName(languageCode: viewModel.languageCode))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)

                                Text("\(ingredientUsageCountByID[ranked.item.id] ?? 0) \(homeCopyRecipesCountSuffix)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(width: 72)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, SeasonSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var demotedHomeSections: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
            Text(homeCopyMoreIdeas)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(.secondary)

            weeklyDiscoveriesSection
            if hasSmartSuggestionContent {
                smartSuggestionsFeedArea
            }
        }
        .padding(.top, SeasonSpacing.sm)
        .opacity(0.94)
    }

    private var seasonalSpotlightItems: [RankedInSeasonItem] {
        buildSeasonalSpotlight(usageCountByID: ingredientUsageCountByID)
    }

    private var discoveryCards: [HookedRecipeCard] {
        var seen: Set<String> = []
        let combined = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> HookedRecipeCard? in
                if case .recipe(let card, _) = item { return card }
                return nil
            }
            .filter { card in
                if seen.contains(card.ranked.recipe.id) {
                    return false
                }
                if topLaneRecipeIDs.contains(card.ranked.recipe.id) {
                    return false
                }
                seen.insert(card.ranked.recipe.id)
                return true
            }
        return Array(combined.prefix(8))
    }

    private var hasSmartSuggestionContent: Bool {
        if selectedQuickFilter != nil {
            return !activeFilteredFeedItems.isEmpty
        }
        return !(activeMiniFeedItems.isEmpty && remainingFeedItems.isEmpty)
    }

    @ViewBuilder
    private var weeklyDiscoveriesSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            Text(homeCopyWeeklyLabel)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Color(red: 0.32, green: 0.38, blue: 0.28))

            Text(homeCopyWeeklyTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            if let lead = discoveryCards.first {
                NavigationLink {
                    RecipeDetailView(
                        rankedRecipe: lead.ranked,
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        recipeImage(for: lead.ranked.recipe, height: 252)
                            .opacity(0.97)
                        LinearGradient(
                            colors: [Color.black.opacity(0.72), .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(lead.ranked.recipe.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.98))
                                .lineLimit(2)
                            Text(lead.ranked.recipe.author)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.84))
                                .lineLimit(1)
                        }
                        .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
                    )
                }
                .buttonStyle(PressableCardButtonStyle())
            }

            let secondaryCards = Array(discoveryCards.dropFirst().prefix(4))
            if !secondaryCards.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(secondaryCards, id: \.ranked.recipe.id) { card in
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: card.ranked,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                recipeImage(for: card.ranked.recipe, height: 110)
                                    .opacity(0.96)

                                Text(card.ranked.recipe.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(SeasonColors.secondarySurface.opacity(0.62))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(PressableCardButtonStyle())
                    }
                }
            }
        }
        .opacity(0.95)
    }

    @ViewBuilder
    private var quickHorizontalStrip: some View {
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
                                    ? SeasonColors.seasonGreen.opacity(0.92)
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
        .padding(.top, 2)
        .padding(.bottom, 0)
        .background(Color(.systemGroupedBackground))
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    private var smartSuggestionsFeedArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SeasonSectionHeader(title: viewModel.localizer.text(.smartSuggestionsTitle))
                Spacer()
                Text(viewModel.localizer.localized("home.smart_suggestions.filter_hint"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            quickHorizontalStrip
            mixedFeedSection
        }
    }

    @ViewBuilder
    private var mixedFeedSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
            if let selectedQuickFilter {
                filterContextHeader(for: selectedQuickFilter)

                if selectedQuickFilter == .following && activeFilteredFeedItems.isEmpty {
                    followingFeedEmptyState
                }

                VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                    ForEach(Array(activeFilteredFeedItems.enumerated()), id: \.element.id) { index, item in
                        switch item {
                        case .recipe(let card, let style):
                            homeRecipeItem(card: card, style: style)
                                .padding(.top, style == .large ? SeasonSpacing.xs : 0)
                                .padding(.bottom, style == .large ? SeasonSpacing.sm : 0)
                                .onAppear {
                                    let nearEndThreshold = max(0, activeFilteredFeedItems.count - 3)
                                    viewModel.loadNextRecipePageIfNeeded(isNearEnd: index >= nearEndThreshold)
                                }
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

                ForEach(Array(remainingFeedItems.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .recipe(let card, let style):
                        homeRecipeItem(card: card, style: style)
                            .padding(.top, style == .large ? SeasonSpacing.sm : 0)
                            .padding(.bottom, style == .large ? SeasonSpacing.sm : 0)
                            .onAppear {
                                let nearEndThreshold = max(0, remainingFeedItems.count - 3)
                                viewModel.loadNextRecipePageIfNeeded(isNearEnd: index >= nearEndThreshold)
                            }
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
                withAnimation(quickFilterSelectionAnimation) {
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

    private func filterContextHeader(for filter: HomeQuickFilter) -> some View {
        Group {
            if filter == .following {
                followingFeedContextHeader
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: filter.iconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(filter.title(using: viewModel.localizer))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text(filterContextSubtitle(for: filter))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterContextSubtitle(for filter: HomeQuickFilter) -> String {
        let recipeCount = activeFilteredFeedItems.reduce(into: 0) { count, item in
            if case .recipe = item {
                count += 1
            }
        }
        let countPrefix = String(
            format: viewModel.localizer.localized("home.filter.count_prefix_format"),
            recipeCount
        )

        switch filter {
        case .following:
            return countPrefix
        case .readyNow:
            return String(
                format: viewModel.localizer.localized("home.filter.subtitle.ready_now_format"),
                countPrefix
            )
        case .under15:
            return String(
                format: viewModel.localizer.localized("home.filter.subtitle.quick_format"),
                countPrefix
            )
        case .highProtein:
            return String(
                format: viewModel.localizer.localized("home.filter.subtitle.high_protein_format"),
                countPrefix
            )
        case .peakSeason:
            return String(
                format: viewModel.localizer.localized("home.filter.subtitle.seasonal_format"),
                countPrefix
            )
        case .trending:
            return String(
                format: viewModel.localizer.localized("home.filter.subtitle.trending_format"),
                countPrefix
            )
        }
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
        let mini = guaranteedMiniBlock(from: Array(recipeOnlySeed.prefix(3)))
        let filtered = filterFeedItems(mini, excludingRecipeIDs: topLaneRecipeIDs)
        return deduplicatedRenderableFeedItems(filtered)
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
        } else {
            let recipeCount = filtered.reduce(into: 0) { count, item in
                if case .recipe = item {
                    count += 1
                }
            }
            debugHomeFeed("phase=filter_resolved filter=\(selectedQuickFilter.rawValue) total_items=\(filtered.count) recipe_items=\(recipeCount)")
        }
        let visible = filterFeedItems(filtered, excludingRecipeIDs: topLaneRecipeIDs)
        return deduplicatedRenderableFeedItems(visible)
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
        let topLaneFiltered = filterFeedItems(mainContinuousFeedItems, excludingRecipeIDs: topLaneRecipeIDs)
        let deduplicated = topLaneFiltered.filter { item in
            miniRecipeIDs.isDisjoint(with: recipeIDs(in: item))
        }

        // Keep Home feed deep: if strict dedupe makes it too short, prefer continuity over perfect uniqueness.
        if deduplicated.count >= 8 {
            return deduplicatedRenderableFeedItems(deduplicated)
        }
        return deduplicatedRenderableFeedItems(topLaneFiltered)
    }

    private var fridgeMatches: [FridgeMatchedRecipe] {
        fridgeMatchesCache
    }

    private var cacheSignature: String {
        let fridgeIDs = fridgeViewModel.allIngredientIDSet.sorted().joined(separator: "|")
        let followingIDs = followStore.followingIds.sorted().joined(separator: "|")
        // Rebuild feed only on semantic data/version changes, not raw recipe count churn.
        return "\(viewModel.languageCode)|\(fridgeIDs)|\(viewModel.currentMonth)|\(viewModel.homeFeedRefreshID)|\(viewModel.rankingDataVersion)|\(followingIDs)"
    }

    private func refreshHomeFeedCache(for signature: String) async {
        guard appliedCacheSignature != signature else { return }

        // Let navigation/scroll rendering finish and allow superseded refreshes to cancel
        // before doing the heavier feed assembly.
        await Task.yield()
        guard !Task.isCancelled, signature == cacheSignature else { return }

        let feed = buildHomeFeed()
        guard !Task.isCancelled, signature == cacheSignature else { return }

        applyHomeFeedBuild(feed, signature: signature)
    }

    private func applyHomeFeedBuild(_ feed: HomeFeedBuild, signature: String) {
        featuredRecipeCache = feed.featured
        fridgeMatchesCache = feed.fridgeMatches
        ingredientUsageCountByID = feed.ingredientUsageCountByID
        mainContinuousFeedItems = feed.defaultFeedItems
        cachedMiniFeeds = feed.filteredMiniFeeds
        cachedFilteredFeeds = feed.filteredFeeds
        appliedCacheSignature = signature
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
        var usedLeadRecipeIDs: Set<String> = []
        for filter in homeQuickFilters {
            let miniFeed = buildMiniFeedBlock(
                for: filter,
                baseRecipes: personalizedContinuousRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: personalizedBackupRecipes,
                trendingIDs: trendingIDs,
                fridgeItemIDs: fridgeIDs,
                personalization: personalizationProfile
            )
            miniFeeds[filter] = deduplicatedRenderableFeedItems(miniFeed)

            let filteredFeed = buildFilteredFeed(
                for: filter,
                baseRecipes: personalizedContinuousRecipes,
                trendingRecipes: trendingRecipes,
                backupRecipes: personalizedBackupRecipes,
                trendingIDs: trendingIDs,
                fridgeItemIDs: fridgeIDs,
                personalization: personalizationProfile,
                leadAvoidingRecipeIDs: usedLeadRecipeIDs
            )
            let deduplicatedFeed = deduplicatedRenderableFeedItems(filteredFeed)
            filteredFeeds[filter] = deduplicatedFeed
            if let leadID = firstRecipeID(in: deduplicatedFeed) {
                usedLeadRecipeIDs.insert(leadID)
            }
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
        personalization: FeedPersonalizationProfile,
        leadAvoidingRecipeIDs: Set<String>
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
            let hardGatedCandidates = applyHardGateCandidates(
                for: filter,
                candidates: mergedCandidates,
                fridgeItemIDs: fridgeItemIDs
            )
            let candidatesForReranking = hardGatedCandidates.count >= 8 ? hardGatedCandidates : mergedCandidates
            let reranked = smartBoostedRanking(
                for: filter,
                candidates: candidatesForReranking,
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
        let leadDiversifiedCards = diversifiedLeadCards(
            from: cards,
            filter: filter,
            avoidingLeadRecipeIDs: leadAvoidingRecipeIDs
        )
        return buildEditorialFilteredItems(from: leadDiversifiedCards, targetCount: 18)
    }

    private func applyHardGateCandidates(
        for filter: HomeQuickFilter,
        candidates: [RankedRecipe],
        fridgeItemIDs: Set<String>
    ) -> [RankedRecipe] {
        switch filter {
        case .following, .trending:
            return candidates
        case .readyNow:
            guard !fridgeItemIDs.isEmpty else { return [] }
            return candidates.filter { ranked in
                viewModel.fridgeMatchScore(for: ranked.recipe, fridgeItemIDs: fridgeItemIDs) >= 0.55
            }
        case .under15:
            return candidates.filter { ranked in
                let prep = ranked.recipe.prepTimeMinutes ?? 0
                let cook = ranked.recipe.cookTimeMinutes ?? 0
                let total = prep + cook
                return total > 0 && total <= 15
            }
        case .highProtein:
            return candidates.filter { ranked in
                guard let summary = viewModel.recipeNutritionSummary(for: ranked.recipe) else { return false }
                return summary.protein >= 12.0
            }
        case .peakSeason:
            return candidates.filter { ranked in
                ranked.seasonalMatchPercent >= 80
            }
        }
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

    private func diversifiedLeadCards(
        from cards: [HookedRecipeCard],
        filter: HomeQuickFilter,
        avoidingLeadRecipeIDs: Set<String>
    ) -> [HookedRecipeCard] {
        guard cards.count > 1 else { return cards }

        let topPoolSize = min(5, cards.count)
        let seed = smartVariationSeed(for: filter)
        let rankedPool = Array(cards.prefix(topPoolSize))
            .enumerated()
            .map { index, card in
                let key = stableHash64("\(seed)|lead|\(card.ranked.recipe.id)")
                return (index: index, card: card, key: key)
            }
            .sorted { lhs, rhs in
                if lhs.key != rhs.key {
                    return lhs.key < rhs.key
                }
                return lhs.card.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.card.ranked.recipe.title) == .orderedAscending
            }

        let preferred = rankedPool.first { candidate in
            !avoidingLeadRecipeIDs.contains(candidate.card.ranked.recipe.id)
        } ?? rankedPool.first

        guard let preferred, preferred.index != 0 else { return cards }

        var reordered: [HookedRecipeCard] = [cards[preferred.index]]
        for (index, card) in cards.enumerated() where index != preferred.index {
            reordered.append(card)
        }
        return reordered
    }

    private func deduplicatedFollowingFeedItems(_ items: [HomeFeedItem]) -> [HomeFeedItem] {
        deduplicatedRenderableFeedItems(items)
    }

    private func deduplicatedRenderableFeedItems(_ items: [HomeFeedItem]) -> [HomeFeedItem] {
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

    private func firstRecipeID(in items: [HomeFeedItem]) -> String? {
        for item in items {
            if case .recipe(let card, _) = item {
                return card.ranked.recipe.id
            }
        }
        return nil
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

    private func filterFeedItems(_ items: [HomeFeedItem], excludingRecipeIDs excluded: Set<String>) -> [HomeFeedItem] {
        guard !excluded.isEmpty else { return items }
        return items.filter { item in
            recipeIDs(in: item).isDisjoint(with: excluded)
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

        let ordered = scored.map(\.ranked)
        return applyTopWindowVariation(for: filter, ranked: ordered)
    }

    private func applyTopWindowVariation(
        for filter: HomeQuickFilter,
        ranked: [RankedRecipe]
    ) -> [RankedRecipe] {
        guard ranked.count > 2 else { return ranked }

        let topWindowSize = min(5, ranked.count)
        let seed = smartVariationSeed(for: filter)
        let topWindow = Array(ranked.prefix(topWindowSize))
        let variedTopWindow = topWindow
            .map { recipe in
                // Deterministic pseudo-random key for controlled rotation inside the top window.
                let key = stableHash64("\(seed)|\(recipe.recipe.id)")
                return (recipe: recipe, key: key)
            }
            .sorted { lhs, rhs in
                if lhs.key != rhs.key {
                    return lhs.key < rhs.key
                }
                return lhs.recipe.recipe.title.localizedCaseInsensitiveCompare(rhs.recipe.recipe.title) == .orderedAscending
            }
            .map(\.recipe)

        return variedTopWindow + Array(ranked.dropFirst(topWindowSize))
    }

    private func smartVariationSeed(for filter: HomeQuickFilter) -> String {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let hourBlock = calendar.component(.hour, from: now) / 6
        return "\(filter.rawValue)|\(year)-\(dayOfYear)-\(hourBlock)|\(viewModel.languageCode)"
    }

    private func stableHash64(_ value: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
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
        withAnimation(quickFilterSelectionAnimation) {
            selectedQuickFilter = selectedQuickFilter == filter ? nil : filter
            if selectedQuickFilter == .following {
                print("[SEASON_HOME_FOLLOWING] phase=filter_selected filter=following")
            }
        }
    }

    private var quickFilterSelectionAnimation: Animation {
        .easeOut(duration: 0.14)
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
            return HookedRecipeCard(ranked: ranked, hook: chosen.text, hookKind: chosen.kind)
        }
    }

    @ViewBuilder
    private func recipeImage(for recipe: Recipe, height: CGFloat, width: CGFloat? = nil) -> some View {
        Group {
            if let remoteURLString = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !remoteURLString.isEmpty,
               let remoteURL = URL(string: remoteURLString) {
                RemoteImageView(
                    url: remoteURL,
                    fallbackAssetName: trimmedFallbackAssetName(for: recipe)
                )
            } else if let cover = resolvedRecipeCoverImage(for: recipe),
                      recipeImageFileURL(for: cover.localPath) != nil {
                RecipeLocalImageView(
                    image: cover,
                    targetSize: CGSize(width: width ?? height * 1.6, height: height),
                    contentMode: .fill
                ) {
                    recipeImageFallback(for: recipe)
                }
            } else if let cover = resolvedRecipeCoverImage(for: recipe),
                      let remoteURLString = cover.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                RemoteImageView(
                    url: remoteURL,
                    fallbackAssetName: trimmedFallbackAssetName(for: recipe)
                )
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
        .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous))
    }

    @ViewBuilder
    private func recipeImageFallback(for recipe: Recipe) -> some View {
        if let cover = resolvedRecipeCoverImage(for: recipe),
           let remoteURLString = cover.remoteURL,
           let remoteURL = URL(string: remoteURLString) {
            RemoteImageView(
                url: remoteURL,
                fallbackAssetName: trimmedFallbackAssetName(for: recipe)
            )
        } else if let imageName = recipe.coverImageName,
                  UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            recipeFallbackImage
        }
    }

    private func trimmedFallbackAssetName(for recipe: Recipe) -> String? {
        let trimmed = recipe.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, hasAsset(named: trimmed) else { return nil }
        return trimmed
    }

    private var recipeFallbackImage: some View {
        RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray6),
                        Color(.systemGray5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
                        RoundedRectangle(cornerRadius: SeasonRadius.small, style: .continuous)
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
        .padding(SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
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
        let recommendationData = fridgeRecommendationData

        ScrollView {
            LazyVStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(produceViewModel.localizer.text(.fromYourFridge))
                        .font(.title2.weight(.bold))
                    Text(headerSubtitle(recommendations: recommendationData.recommendations))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(SeasonSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.7)
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitleCountRow(
                        title: produceViewModel.localizer.text(.fridgePreviewTitle),
                        countText: fridgePreviewItems.count.compactFormatted()
                    )

                    if fridgeViewModel.allItemCount == 0 {
                        Text(produceViewModel.localizer.text(.fromFridgeSubtitleEmpty))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(fridgePreviewItems) { item in
                                    HStack(spacing: 6) {
                                        fridgePreviewIcon(item: item, size: 22)
                                        Text(item.title)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color(.tertiarySystemGroupedBackground).opacity(0.96))
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(SeasonColors.seasonGreen.opacity(0.1), lineWidth: 0.5)
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
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption.weight(.semibold))
                            Text(produceViewModel.localizer.text(.editFridge))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SeasonColors.secondarySurface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(SeasonColors.seasonGreen.opacity(0.12), lineWidth: 0.7)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.86))
                )

                VStack(alignment: .leading, spacing: 10) {
                    bestMatchesHeader(count: recommendationData.bestMatches.count)

                    if recommendationData.bestMatches.isEmpty {
                        EmptyStateCard(
                            symbol: "fork.knife",
                            title: produceViewModel.localizer.text(.noMatchingRecipesYetTitle),
                            subtitle: produceViewModel.localizer.text(.noMatchingRecipesYetSubtitle)
                        )
                    } else {
                        ForEach(recommendationData.bestMatches) { match in
                            fridgeRecipeRow(match, emphasize: true)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.86))
                )

                if !recommendationData.quickOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitleCountRow(
                            title: produceViewModel.localizer.text(.quickOptions),
                            countText: recommendationData.quickOptions.count.compactFormatted()
                        )
                        ForEach(recommendationData.quickOptions) { match in
                            fridgeRecipeRow(match, emphasize: false)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.84))
                    )
                }

                if !recommendationData.needsIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(produceViewModel.localizer.text(.needsIngredients))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        ForEach(recommendationData.needsIngredients) { match in
                            fridgeRecipeRow(match, emphasize: false)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.82))
                    )
                }

                if recommendationData.recommendations.isEmpty {
                    EmptyStateCard(
                        symbol: "snowflake",
                        title: produceViewModel.localizer.text(.cookWithWhatYouHave),
                        subtitle: produceViewModel.localizer.text(.fromFridgeSubtitleEmpty)
                    )
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance)
        }
        .background(SeasonColors.primarySurface)
        .navigationTitle(produceViewModel.localizer.text(.fromYourFridge))
        .navigationBarTitleDisplayMode(.inline)
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

    private func bestMatchesHeader(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitleCountRow(
                title: produceViewModel.localizer.text(.bestMatches),
                countText: count.compactFormatted()
            )
            Text(produceViewModel.localizer.localized("home.best_matches.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fridgeRecipeRow(_ match: FridgeMatchedRecipe, emphasize: Bool) -> some View {
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

                    if emphasize {
                        VStack(alignment: .trailing, spacing: 5) {
                            if missingIngredientNames(for: match).isEmpty {
                                SeasonBadge(
                                    text: produceViewModel.localizer.text(.readyNow),
                                    semantic: .positive,
                                    horizontalPadding: 7,
                                    verticalPadding: 4
                                )
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(String(
                    format: produceViewModel.localizer.text(.ingredientMatchCountFormat),
                    match.matchingCount,
                    match.totalCount
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(emphasize ? Color.secondary : Color.primary.opacity(0.86))

                if emphasize, match.rankedRecipe.seasonalityScore >= 0.55 {
                    SeasonBadge(
                        text: "In season",
                        semantic: .positive,
                        horizontalPadding: 7,
                        verticalPadding: 3,
                        foreground: SeasonColors.seasonGreen.opacity(0.78),
                        background: SeasonColors.seasonGreenSoft.opacity(0.26)
                    )
                }

                if !emphasize {
                    Text(produceViewModel.recipeTimingTitle(for: match.rankedRecipe))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !missingIngredientNames(for: match).isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(produceViewModel.localizer.text(.missingIngredients)): \(missingIngredientNames(for: match).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.75))
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Button {
                        addMissingIngredients(for: match)
                    } label: {
                        Text(produceViewModel.localizer.text(.addMissingAction))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(emphasize ? Color(red: 0.22, green: 0.49, blue: 0.24) : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(emphasize ? SeasonColors.seasonGreenSoft.opacity(0.52) : Color(.tertiarySystemGroupedBackground))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        emphasize ? SeasonColors.seasonGreen.opacity(0.22) : Color.primary.opacity(0.08),
                                        lineWidth: 0.6
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    emphasize
                    ? SeasonColors.seasonGreenSoft.opacity(0.34)
                    : Color(.systemBackground).opacity(0.82)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    emphasize ? SeasonColors.seasonGreen.opacity(0.14) : Color.primary.opacity(0.045),
                    lineWidth: 0.6
                )
        )
    }

    private var fridgeRecommendationData: FridgeRecommendationData {
        let recommendations = produceViewModel.rankedFridgeRecommendations(
            fridgeItemIDs: fridgeViewModel.allIngredientIDSet
        )
        .prefix(30)
        .map { $0 }

        let matchingRecommendations = recommendations.filter { $0.matchingCount > 0 }
        let bestMatches: [FridgeMatchedRecipe]
        let preferred = matchingRecommendations.filter { match in
            match.matchRatio >= 0.66 && match.missingCount <= 2
        }
        if preferred.isEmpty {
            bestMatches = Array(matchingRecommendations.prefix(4))
        } else {
            bestMatches = Array(preferred.prefix(4))
        }

        let excludedIDs = Set(bestMatches.map(\.id))
        let quickOptions = matchingRecommendations.filter { match in
            !excludedIDs.contains(match.id)
        }

        let needsIngredients = recommendations.filter { $0.matchingCount == 0 }
        return FridgeRecommendationData(
            recommendations: recommendations,
            bestMatches: bestMatches,
            quickOptions: quickOptions,
            needsIngredients: needsIngredients
        )
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

    private func headerSubtitle(recommendations: [FridgeMatchedRecipe]) -> String {
        guard fridgeViewModel.allItemCount > 0 else {
            return produceViewModel.localizer.text(.fromFridgeSubtitleEmpty)
        }
        let readyNowCount = recommendations.filter { $0.matchingCount > 0 && $0.missingCount == 0 }.count
        let completableCount = recommendations.filter { $0.matchingCount > 0 && $0.missingCount > 0 }.count

        switch (readyNowCount, completableCount) {
        case (0, 0):
            return produceViewModel.localizer.text(.fromFridgeSubtitleEmpty)
        case (_, 0):
            return String(
                format: produceViewModel.localizer.localized("home.fridge.header.ready_now_format"),
                readyNowCount
            )
        case (0, _):
            return String(
                format: produceViewModel.localizer.localized("home.fridge.header.completable_format"),
                completableCount
            )
        default:
            return String(
                format: produceViewModel.localizer.localized("home.fridge.header.ready_and_completable_format"),
                readyNowCount,
                completableCount
            )
        }
    }

    private struct FridgeRecommendationData {
        let recommendations: [FridgeMatchedRecipe]
        let bestMatches: [FridgeMatchedRecipe]
        let quickOptions: [FridgeMatchedRecipe]
        let needsIngredients: [FridgeMatchedRecipe]
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
