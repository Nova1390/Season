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
    @State private var selectedRecipeRoute: HomeRecipeRoute?
    private let homeQuickFilters: [HomeQuickFilter] = [.readyNow, .under15, .highProtein, .peakSeason, .trending]
    private let homeContentGutter: CGFloat = DS.Spacing.xl

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DS.Color.bg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    fixedHeaderRow(safeAreaTopInset: proxy.safeAreaInsets.top)
                        .zIndex(20)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            greetingHeroSection
                                .padding(.horizontal, homeContentGutter)
                                .padding(.bottom, DS.Spacing.md)

                            cookNowHeroSection

                            freshCreatorStripSection

                            seasonalNowSection

                            Section {
                                feedHeadingSection

                                mixedFeedSection
                                    .padding(.top, DS.Spacing.sm)
                                    .padding(.bottom, DS.Spacing.md)
                            } header: {
                                stickyFilterSection
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, DS.Spacing.xs)
                        .padding(.bottom, SeasonLayout.bottomBarContentClearance + DS.Spacing.xxxl)
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
        .navigationDestination(item: $selectedRecipeRoute) { route in
            RecipeDetailView(
                rankedRecipe: route.rankedRecipe,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance + DS.Spacing.md)
        }
    }

    /// Greeting editoriale della home v2.
    /// Due righe: eyebrow mono uppercase ("APRILE · SETTIMANA 16" + dot fresh)
    /// e un titolo serif balanced con una porzione in italic/sage-deep.
    @ViewBuilder
    private var greetingHeroSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
            HStack(spacing: 8) {
                Circle()
                    .fill(DS.Color.fresh)
                    .frame(width: 5, height: 5)
                    .overlay(
                        Circle()
                            .stroke(DS.Color.fresh.opacity(0.18), lineWidth: 3)
                    )
                    .padding(.trailing, 2)

                Text(greetingEyebrow)
                    .font(DS.Font.eyebrow)
                    .kerning(1.05) // ~0.10em on 10.5px
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkMuted)
            }

            greetingTitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.xxs)
        .padding(.bottom, DS.Spacing.xs)
    }

    /// Titolo serif del greeting. Composto da tre parti:
    /// "Buongiorno {nome}, " + *cosa cuciniamo* (italic sage-deep) + " con quello che hai?"
    private var greetingTitle: Text {
        let prefix = Text(String(format: greetingOpeningFormat, greetingName) + " ")
            .font(DS.Font.serif(28, weight: .medium))
            .foregroundStyle(DS.Color.ink)
        let middle = Text(greetingEmphasis)
            .font(DS.Font.serif(28, weight: .medium, italic: true))
            .foregroundStyle(DS.Color.sageDeep)
        let suffix = Text(" " + greetingClosing)
            .font(DS.Font.serif(28, weight: .medium))
            .foregroundStyle(DS.Color.ink)
        return Text("\(prefix)\(middle)\(suffix)")
    }

    /// "APRILE · SETTIMANA 16" formattato con la locale corrente.
    private var greetingEyebrow: String {
        let calendar = Calendar.current
        let now = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale.current
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLL")
        let monthName = monthFormatter.string(from: now)
        let weekOfYear = calendar.component(.weekOfYear, from: now)
        let format = viewModel.localizer.localized("home.eyebrow.month_week_format")
        return String(format: format, monthName, weekOfYear)
    }

    /// Saluto contestuale all'ora (buongiorno / buon pomeriggio / buonasera).
    /// Ritorna il formato con placeholder %@ per il nome utente.
    private var greetingOpeningFormat: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let key: String
        switch hour {
        case 5..<12:  key = "home.greeting.morning_format"
        case 12..<18: key = "home.greeting.afternoon_format"
        default:       key = "home.greeting.evening_format"
        }
        return viewModel.localizer.localized(key)
    }

    /// "cosa cuciniamo" — porzione con emphasis italic.
    private var greetingEmphasis: String {
        viewModel.localizer.localized("home.greeting.emphasis")
    }

    /// "con quello che hai?" — chiusura del titolo.
    private var greetingClosing: String {
        viewModel.localizer.localized("home.greeting.closing")
    }

    /// Primo nome dell'utente (fallback "tu" se non disponibile).
    private var greetingName: String {
        let raw = CurrentUser.shared.creator.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstToken = raw.split(separator: " ").first.map(String.init) ?? ""
        let cleanedToken = firstToken
            .filter { $0.isLetter }
            .map(String.init)
            .joined()
        if !cleanedToken.isEmpty,
           cleanedToken.count >= 2,
           !firstToken.contains("@"),
           cleanedToken.lowercased() != "you" {
            return cleanedToken.prefix(1).uppercased() + cleanedToken.dropFirst()
        }
        return viewModel.localizer.localized("home.greeting.fallback_name")
    }

    /// Top bar v2 — wordmark "Season." (serif, punto sage italic) + icone
    /// frigo/lista/notifiche a destra. Sostituisce la masthead precedente
    /// ("Home" + data) che viveva qui prima del refresh v2.
    private func fixedHeaderRow(safeAreaTopInset: CGFloat) -> some View {
        SeasonTopBar(
            produceViewModel: viewModel,
            shoppingListViewModel: shoppingListViewModel
        )
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

    private var heroContextLabel: String {
        switch homeHeroState {
        case .readyNow:
            return viewModel.localizer.localized("home.hero.context.ready_now")
        case .almostReady:
            return viewModel.localizer.localized("home.hero.context.almost_ready")
        case .seasonal:
            return viewModel.localizer.localized("home.hero.context.seasonal")
        }
    }

    private func openRecipe(_ rankedRecipe: RankedRecipe) {
        selectedRecipeRoute = HomeRecipeRoute(rankedRecipe: rankedRecipe)
    }

    @ViewBuilder
    private var cookNowHeroSection: some View {
        let topRecipe = cookNowTopRecipe

        VStack(spacing: 0) {
            if let topRecipe {
                ZStack(alignment: .topTrailing) {
                    Button {
                        openRecipe(topRecipe)
                    } label: {
                        heroMedia(for: topRecipe)
                    }
                    .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))

                    heroCrispyButton(for: topRecipe.recipe)
                        .padding(14)
                }
            } else {
                NavigationLink {
                    FridgeView(
                        produceViewModel: viewModel,
                        fridgeViewModel: fridgeViewModel,
                        shoppingListViewModel: shoppingListViewModel,
                        initialMode: hasFridgeMatches ? .recipes : .inventory
                        )
                } label: {
                    heroEmptyMedia
                }
                .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
            }

            heroBody(for: topRecipe)
        }
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
        .dsShadow(.s2)
        .padding(.horizontal, homeContentGutter)
        .padding(.bottom, DS.Spacing.xxl)
    }

    @ViewBuilder
    private func heroMedia(for ranked: RankedRecipe) -> some View {
        ZStack(alignment: .topLeading) {
            recipeImage(for: ranked.recipe, height: 246)

            HStack(spacing: 6) {
                Circle()
                    .fill(DS.Color.fresh)
                    .frame(width: 5, height: 5)
                Text(heroContextLabel)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.74))
            )
            .padding(14)
        }
    }

    private var heroEmptyMedia: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [DS.Color.sageSoft, DS.Color.bgSub],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 212)

            Image(systemName: "leaf")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DS.Color.sageDeep.opacity(0.62))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                Circle()
                    .fill(DS.Color.fresh)
                    .frame(width: 5, height: 5)
                Text(heroContextLabel)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.sageDeep)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.Color.card.opacity(0.86))
            )
            .padding(14)
        }
    }

    @ViewBuilder
    private func heroBody(for ranked: RankedRecipe?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let ranked {
                ReasonChip(kind: .fridge, text: heroReasonText(for: ranked))

                heroCreatorRow(for: ranked.recipe)
                    .padding(.top, 2)

                Text(ranked.recipe.title)
                    .font(DS.Font.serif(26, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)

                heroMetaRow(for: ranked.recipe)

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        openRecipe(ranked)
                    } label: {
                        heroPrimaryCTA(label: heroCTA(for: ranked))
                    }
                    .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))

                    Button {
                        viewModel.toggleSavedRecipe(ranked.recipe)
                    } label: {
                        heroSecondaryIcon(
                            systemName: viewModel.isRecipeSaved(ranked.recipe) ? "bookmark.fill" : "bookmark",
                            isActive: viewModel.isRecipeSaved(ranked.recipe)
                        )
                    }
                    .buttonStyle(PressableCardButtonStyle(pressedScale: 0.96))
                    .accessibilityLabel(viewModel.localizer.text(.saveRecipe))
                }
                .padding(.top, DS.Spacing.xs)

                if hasFridgeMatches {
                    NavigationLink {
                        FridgeView(
                            produceViewModel: viewModel,
                            fridgeViewModel: fridgeViewModel,
                            shoppingListViewModel: shoppingListViewModel,
                            initialMode: .recipes
                        )
                    } label: {
                        HStack(spacing: 5) {
                            Text(viewModel.localizer.localized("home.section.from_fridge.cta"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(DS.Font.sans(13, weight: .semibold))
                        .foregroundStyle(DS.Color.sageDeep)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(cookNowHeroTitle)
                    .font(DS.Font.serif(26, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)

                Text(cookNowHeroSubtitle)
                    .font(DS.Font.sans(13))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(2)

                NavigationLink {
                    FridgeView(
                        produceViewModel: viewModel,
                        fridgeViewModel: fridgeViewModel,
                        shoppingListViewModel: shoppingListViewModel,
                        initialMode: hasFridgeMatches ? .recipes : .inventory
                        )
                } label: {
                    heroPrimaryCTA(label: cookNowHeroCTA)
                }
                .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroPrimaryCTA(label: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(DS.Font.sans(14, weight: .semibold))
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.ink)
        )
    }

    private func heroSecondaryIcon(systemName: String, isActive: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isActive ? DS.Color.sageDeep : DS.Color.ink)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Color.bgSub)
            )
    }

    @ViewBuilder
    private func heroCrispyButton(for recipe: Recipe) -> some View {
        let crispyCount = viewModel.crispyCount(for: recipe)
        let isActive = viewModel.isRecipeCrispied(recipe)
        if crispyCount > 0 || isActive {
            Button {
                viewModel.toggleRecipeCrispy(recipe)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(crispyCount.compactFormatted())
                        .font(DS.Font.sans(12, weight: .bold))
                    Text("crispy")
                        .font(DS.Font.sans(11, weight: .medium))
                        .opacity(0.78)
                }
                .foregroundStyle(isActive ? DS.Color.Crispy.inkActive : DS.Color.Crispy.inkInactive)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? DS.Color.Crispy.bgActive : DS.Color.card.opacity(0.92))
                )
                .dsShadow(.s1)
            }
            .buttonStyle(PressableCardButtonStyle(pressedScale: 0.94))
            .accessibilityLabel("Crispy")
        }
    }

    private func heroCreatorRow(for recipe: Recipe) -> some View {
        HStack(spacing: 10) {
            if isImportedRecipe(recipe) {
                Circle()
                    .fill(DS.Color.ochreSoft.opacity(0.72))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.Color.terracotta.opacity(0.72))
                    )
                    .overlay(Circle().stroke(DS.Color.borderS, lineWidth: 1))
            } else {
                RemoteImageView(
                    url: recipe.creatorAvatarURL
                        .flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) },
                    fallbackAssetName: nil
                )
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Color.borderS, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(primaryIdentityLabel(for: recipe))
                    .font(DS.Font.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)

                Text(heroCreatorMeta(for: recipe))
                    .font(DS.Font.sans(11))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let creatorID = recipe.canonicalCreatorID {
                Button {
                    followStore.toggleFollow(creatorID)
                } label: {
                    Text(followStore.followingIds.contains(creatorID) ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                        .font(DS.Font.sans(12, weight: .semibold))
                        .foregroundStyle(followStore.followingIds.contains(creatorID) ? DS.Color.card : DS.Color.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(followStore.followingIds.contains(creatorID) ? DS.Color.ink : Color.clear)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(DS.Color.borderS, lineWidth: 1.4)
                        )
                }
                .buttonStyle(PressableCardButtonStyle(pressedScale: 0.96))
            }
        }
    }

    private func heroMetaRow(for recipe: Recipe) -> some View {
        HStack(spacing: 14) {
            heroMetaItem(value: featuredTimeText(for: recipe), label: nil)
            heroMetaItem(value: String(format: viewModel.localizer.text(.servesFormat), recipe.servings), label: nil)
            if let difficulty = recipe.difficulty {
                Text(viewModel.localizer.recipeDifficultyTitle(difficulty))
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }
        }
    }

    private func heroMetaItem(value: String, label: String?) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(DS.Font.sans(12, weight: .semibold))
                .foregroundStyle(DS.Color.ink)
            if let label {
                Text(label)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.inkMuted)
            }
        }
    }

    private func heroReasonText(for ranked: RankedRecipe) -> String {
        if let match = fridgeMatchByRecipeID[ranked.recipe.id] {
            return String(
                format: viewModel.localizer.text(.ingredientMatchCountFormat),
                match.matchingCount,
                match.totalCount
            )
        }
        return primaryHook(for: ranked).text
    }

    private func heroCreatorMeta(for recipe: Recipe) -> String {
        if isImportedRecipe(recipe) {
            return importedRecipeSubtitle
        }
        let followers = viewModel.followerCount(
            for: recipe.author,
            isFollowedByCurrentUser: recipe.canonicalCreatorID.map { followStore.followingIds.contains($0) } ?? false
        )
        let authoredCount = viewModel.activeRecipes(for: recipe.author).count
        return "\(followers.compactFormatted()) \(viewModel.localizer.text(.followers)) · \(authoredCount.compactFormatted()) \(viewModel.localizer.text(.recipes))"
    }

    @ViewBuilder
    private var freshCreatorStripSection: some View {
        let stripData = creatorStripData
        if stripData.count >= 2 {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                sectionHeader(
                    kicker: localizedCreatorStripKicker,
                    title: localizedCreatorStripSectionTitle,
                    trailing: viewModel.localizer.localized("home.common.see_all")
                )

                Button {
                    withAnimation(quickFilterSelectionAnimation) {
                        selectedQuickFilter = .following
                    }
                } label: {
                    HStack(spacing: 12) {
                        HStack(spacing: -10) {
                            ForEach(Array(stripData.prefix(4).enumerated()), id: \.offset) { _, entry in
                                RemoteImageView(url: entry.avatar.url, fallbackAssetName: entry.avatar.fallbackAssetName)
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(DS.Color.card, lineWidth: 2))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(creatorStripTitle(count: stripData.count))
                                .font(DS.Font.sans(13, weight: .semibold))
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(1)
                            Text(creatorStripMeta(from: stripData))
                                .font(DS.Font.sans(11))
                                .foregroundStyle(DS.Color.inkMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(stripData.count.compactFormatted())
                            .font(DS.Font.mono(10, weight: .medium))
                            .foregroundStyle(DS.Color.sageDeep)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DS.Color.sageSoft)
                            )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Color.inkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(DS.Color.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .stroke(DS.Color.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
            }
            .padding(.horizontal, homeContentGutter)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    @ViewBuilder
    private func sectionHeader(kicker: String?, title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let kicker, !kicker.isEmpty {
                    Text(kicker)
                        .font(DS.Font.eyebrow)
                        .kerning(1.05)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.inkMuted)
                }
                Text(title)
                    .font(DS.Font.cardTitle)
                    .foregroundStyle(DS.Color.ink)
            }
            Spacer(minLength: 12)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(DS.Font.sans(13, weight: .medium))
                    .foregroundStyle(DS.Color.inkMuted)
            }
        }
    }

    private var localizedCreatorStripKicker: String {
        viewModel.languageCode == "it"
            ? "Dalla tua rete"
            : "From your network"
    }

    private var localizedCreatorStripSectionTitle: String {
        viewModel.languageCode == "it"
            ? "Pubblicato questa settimana"
            : "Posted this week"
    }

    private var creatorStripData: [(name: String, avatar: FeedImageSource)] {
        var seen: Set<String> = []
        var result: [(name: String, avatar: FeedImageSource)] = []
        for item in activeMiniFeedItems + remainingFeedItems {
            guard case .recipe(let card) = item else { continue }
            let recipe = card.ranked.recipe
            guard recipe.canonicalCreatorID != nil else { continue }
            let key = recipe.canonicalCreatorID ?? recipe.displayCreatorName
            guard seen.insert(key).inserted else { continue }
            result.append((recipe.displayCreatorName, creatorAvatarSource(for: recipe)))
            if result.count == 6 { break }
        }
        return result
    }

    private func creatorStripTitle(count: Int) -> String {
        if viewModel.languageCode == "it" {
            return "\(count) ricette nuove da creator che segui"
        }
        return "\(count) new recipes from creators you follow"
    }

    private func creatorStripMeta(from data: [(name: String, avatar: FeedImageSource)]) -> String {
        let names = data.prefix(3).map(\.name)
        if data.count > 3 {
            return names.joined(separator: " · ") + " · +\(data.count - 3)"
        }
        return names.joined(separator: " · ")
    }

    @ViewBuilder
    private var stickyFilterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            quickHorizontalStrip
                .padding(.horizontal, homeContentGutter)
                .padding(.top, DS.Spacing.xxs)
                .padding(.bottom, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.bg.opacity(0.94))
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    DS.Color.bg.opacity(0.0),
                    DS.Color.bg.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)
        }
        .zIndex(10)
    }

    @ViewBuilder
    private var feedHeadingSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(feedKicker)
                    .font(DS.Font.eyebrow)
                    .kerning(1.05)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkMuted)
                Text(feedTitle)
                    .font(DS.Font.cardTitle)
                    .foregroundStyle(DS.Color.ink)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, homeContentGutter)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.lg)
    }

    private var feedKicker: String {
        selectedQuickFilter?.title(using: viewModel.localizer)
            ?? homeCopyWeeklyLabel
    }

    private var feedTitle: String {
        selectedQuickFilter == nil
            ? homeCopyWeeklyTitle
            : localizedFilteredFeedTitle
    }

    private var localizedFilteredFeedTitle: String {
        viewModel.languageCode == "it"
            ? "Ricette per il tuo momento"
            : "Recipes for your moment"
    }

    private var cookNowTopRecipe: RankedRecipe? {
        let feedPool = mainContinuousFeedItems.compactMap { item -> RankedRecipe? in
            if case .recipe(let card) = item { return card.ranked }
            return nil
        }
        let priorityPool = fridgeMatches.map(\.rankedRecipe)
            + [featuredRecipe].compactMap { $0 }
            + feedPool
            + viewModel.homeRankedRecipes(limit: 24)
        if let socialVisualLead = priorityPool.first(where: {
            recipeHasEditorialMedia($0.recipe) && !isImportedRecipe($0.recipe)
        }) {
            return socialVisualLead
        }
        if let visualLead = priorityPool.first(where: { recipeHasEditorialMedia($0.recipe) }) {
            return visualLead
        }
        return priorityPool.first
    }

    private var hasFridgeMatches: Bool {
        !fridgeMatches.isEmpty
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

    private var homeCopyWeeklyLabel: String {
        viewModel.localizer.localized("home.section.weekly.label")
    }

    private var homeCopyWeeklyTitle: String {
        viewModel.localizer.localized("home.section.weekly.title")
    }

    private var homeCopyRecipesCountSuffix: String {
        viewModel.localizer.localized("home.badge.recipes")
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

    private func heroCTA(for ranked: RankedRecipe) -> String {
        viewModel.localizer.localized("home.hero.cta.start")
    }

    private var seasonalNowSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(homeCopySeasonalSubtitle)
                        .font(DS.Font.eyebrow)
                        .kerning(1.05)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.inkMuted)
                    Text(homeCopySeasonalTitle)
                        .font(DS.Font.cardTitle)
                        .foregroundStyle(DS.Color.ink)
                }

                Spacer(minLength: 12)

                NavigationLink {
                    InSeasonTodayView(
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text(homeCopySeasonalCTA)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(DS.Font.sans(13, weight: .medium))
                    .foregroundStyle(DS.Color.inkMuted)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(seasonalSpotlightItems.prefix(10)), id: \.item.id) { ranked in
                        NavigationLink {
                            ProduceDetailView(
                                item: ranked.item,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                            .environmentObject(fridgeViewModel)
                        } label: {
                            VStack(alignment: .center, spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(DS.Color.bgSub)
                                        .overlay(
                                            Circle()
                                                .stroke(DS.Color.sageSoft, lineWidth: 2)
                                                .padding(1)
                                        )

                                    ProduceThumbnailView(item: ranked.item, size: 78)
                                        .clipShape(Circle())

                                    if ranked.item.seasonalityPhase(month: viewModel.currentMonth) == .inSeason {
                                        Circle()
                                            .fill(DS.Color.sage)
                                            .frame(width: 14, height: 14)
                                            .overlay(Circle().stroke(DS.Color.bg, lineWidth: 2))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                            .offset(x: -2, y: -2)
                                    }
                                }
                                .frame(width: 78, height: 78)

                                Text(ranked.item.displayName(languageCode: viewModel.languageCode))
                                    .font(DS.Font.sans(11, weight: .semibold))
                                    .foregroundStyle(DS.Color.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)

                                Text(seasonalUsageLabel(for: ranked.item.id))
                                    .font(DS.Font.mono(9, weight: .regular))
                                    .kerning(0.45)
                                    .foregroundStyle(DS.Color.inkMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(width: 78)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableCardButtonStyle(pressedScale: 0.96))
                    }
                }
                .padding(.horizontal, homeContentGutter)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -homeContentGutter)
        }
        .padding(.horizontal, homeContentGutter)
        .padding(.bottom, DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seasonalSpotlightItems: [RankedInSeasonItem] {
        buildSeasonalSpotlight(usageCountByID: ingredientUsageCountByID)
    }

    private func seasonalUsageLabel(for ingredientID: String) -> String {
        let count = ingredientUsageCountByID[ingredientID] ?? 0
        guard count > 0 else {
            return viewModel.localizer.text(.seasonPeakNow)
        }
        return "\(count) \(homeCopyRecipesCountSuffix)"
    }

    /// Filter chips v2 — pillole con bordo, sfondo sottile e stato attivo
    /// su `DS.Color.ink` (non più verde). Niente container esterno: è una
    /// riga di scroll orizzontale minimale in linea col prototipo.
    @ViewBuilder
    private var quickHorizontalStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selectedQuickFilter == .following {
                    HStack(spacing: 5) {
                        Image(systemName: HomeQuickFilter.following.iconName)
                            .font(.system(size: 11, weight: .medium))
                        Text(HomeQuickFilter.following.title(using: viewModel.localizer))
                            .font(DS.Font.chip)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Color.ink)
                    )
                }

                Button {
                    withAnimation(quickFilterSelectionAnimation) {
                        selectedQuickFilter = nil
                    }
                } label: {
                    Text(localizedAllFilterTitle)
                        .font(DS.Font.chip)
                        .foregroundStyle(selectedQuickFilter == nil ? Color.white : DS.Color.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedQuickFilter == nil ? DS.Color.ink : DS.Color.card)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(selectedQuickFilter == nil ? Color.clear : DS.Color.borderM, lineWidth: 1)
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(homeQuickFilters) { filter in
                    let isActive = selectedQuickFilter == filter
                    Button {
                        selectQuickFilter(filter)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.iconName)
                                .font(.system(size: 11, weight: .medium))
                            Text(filter.title(using: viewModel.localizer))
                                .font(DS.Font.chip)
                        }
                        .foregroundStyle(isActive ? Color.white : DS.Color.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isActive ? DS.Color.ink : DS.Color.card)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isActive ? Color.clear : DS.Color.borderM, lineWidth: 1)
                        )
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var localizedAllFilterTitle: String {
        viewModel.languageCode == "it" ? "Tutte" : "All"
    }

    @ViewBuilder
    private var mixedFeedSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
            if let selectedQuickFilter {
                filterContextHeader(for: selectedQuickFilter)
                    .padding(.horizontal, homeContentGutter)
                    .padding(.bottom, DS.Spacing.xs)

                if selectedQuickFilter == .following && activeFilteredFeedItems.isEmpty {
                    followingFeedEmptyState
                }

                // Filtered branch: rhythm-styled cards, no editorial bands.
                rhythmFeedBody(
                    items: activeFilteredFeedItems,
                    includeEditorialBands: false
                )
            } else {
                // Default branch: full v2b rhythm with editorial injections.
                rhythmFeedBody(
                    items: activeMiniFeedItems + remainingFeedItems,
                    includeEditorialBands: true
                )
            }
        }
    }

    /// Shared rendering for the mixed feed. Iterates the domain items, maps
    /// each `.recipe` to a rhythm slot (classic/split/compact) and inserts
    /// full-bleed editorial bands between recipes when `includeEditorialBands`
    /// is true.
    @ViewBuilder
    private func rhythmFeedBody(items: [HomeFeedItem], includeEditorialBands: Bool) -> some View {
        let indexed = indexedFeedItems(items)
        let paginationTotal = indexed.count

        VStack(alignment: .leading, spacing: SeasonSpacing.md) {
            ForEach(indexed) { entry in
                switch entry.item {
                case .recipe(let card):
                    let slot = rhythmSlot(for: entry.recipeIndex ?? 0)
                    rhythmRecipeItem(card: card, slot: slot)
                        .padding(.horizontal, homeContentGutter)
                        .padding(.top, slot == .classic ? SeasonSpacing.xs : 0)
                        .padding(.bottom, slot == .classic ? SeasonSpacing.sm : 0)
                        .onAppear {
                            let nearEndThreshold = max(0, paginationTotal - 3)
                            viewModel.loadNextRecipePageIfNeeded(isNearEnd: entry.position >= nearEndThreshold)
                        }

                    if includeEditorialBands,
                       let recipeIdx = entry.recipeIndex,
                       let injection = editorialInjection(afterRecipeAt: recipeIdx) {
                        editorialInjectionView(for: injection)
                    }

                case .followingFallbackSeparator:
                    if selectedQuickFilter == .following {
                        followingFallbackSeparatorLabel
                            .padding(.horizontal, homeContentGutter)
                            .padding(.top, SeasonSpacing.xs)
                    }
                }
            }
        }
    }

    /// Walk `items` once and compute, for every `.recipe`, its position in
    /// the recipe-only sub-sequence. Other cases get `recipeIndex == nil`.
    private func indexedFeedItems(_ items: [HomeFeedItem]) -> [IndexedHomeFeedItem] {
        var result: [IndexedHomeFeedItem] = []
        result.reserveCapacity(items.count)
        var recipeCounter = 0
        for (position, item) in items.enumerated() {
            if item.isRecipe {
                result.append(IndexedHomeFeedItem(item: item, recipeIndex: recipeCounter, position: position))
                recipeCounter += 1
            } else {
                result.append(IndexedHomeFeedItem(item: item, recipeIndex: nil, position: position))
            }
        }
        return result
    }

    // MARK: - Rhythm slot resolution

    /// Rhythm pattern pulled from `home-prototype-v2b.html`. Twelve-slot cycle
    /// so the cadence repeats visibly even on very long feeds.
    private func rhythmSlot(for recipeIndex: Int) -> HomeFeedRhythmSlot {
        // classic → split → classic → compact → split → compact →
        // classic → compact → split → compact → classic → compact
        let pattern: [HomeFeedRhythmSlot] = [
            .classic, .split, .classic, .compact,
            .split,   .compact, .classic, .compact,
            .split,   .compact, .classic, .compact,
        ]
        let safeIndex = max(0, recipeIndex)
        return pattern[safeIndex % pattern.count]
    }

    /// Inject each editorial module once, matching the v2b cadence: recipe
    /// rhythm first, then one seasonal recipe band, one tip, one nudge, one
    /// collection and one community pulse.
    private func editorialInjection(afterRecipeAt recipeIndex: Int) -> HomeFeedEditorialInjection? {
        guard recipeIndex >= 0 else { return nil }
        let ordinal = recipeIndex + 1 // "after the Nth recipe"
        switch ordinal {
        case 2:  return .peakCarousel
        case 4:  return .tipBand
        case 5:  return .nudgeCard
        case 7:  return .collectionTile
        case 9:  return .pulseBand
        default: return nil
        }
    }

    // MARK: - Rhythm recipe rendering

    @ViewBuilder
    private func rhythmRecipeItem(card: HookedRecipeCard, slot: HomeFeedRhythmSlot) -> some View {
        let followed = isFollowedCreator(card.ranked.recipe.canonicalCreatorID)
        let showFollowingSignal = selectedQuickFilter == .following && followed
        let resolvedSlot = resolvedRhythmSlot(for: card, proposed: slot)

        switch resolvedSlot {
        case .classic:
            largeRecipeCard(
                ranked: card.ranked,
                hook: card.hook,
                showFollowingSignal: showFollowingSignal
            )
        case .split:
            ZStack(alignment: .topLeading) {
                Button {
                    openRecipe(card.ranked)
                } label: {
                    FeedCardSplit(
                        image: feedImageSource(for: card.ranked.recipe),
                        reasonKind: reasonKind(for: card),
                        reasonText: card.hook,
                        title: card.ranked.recipe.title,
                        creatorName: feedCreatorLabel(for: card.ranked.recipe),
                        creatorAvatar: creatorAvatarSource(for: card.ranked.recipe),
                        identityKind: identityKind(for: card.ranked.recipe),
                        meta: metaLine(for: card.ranked.recipe)
                    )
                }
                .buttonStyle(.plain)

                feedCrispyButton(for: card.ranked.recipe)
                    .padding(.top, 108)
                    .padding(.leading, 86)
                    .zIndex(2)
            }
        case .compact:
            Button {
                openRecipe(card.ranked)
            } label: {
                FeedCardCompact(
                    image: feedImageSource(for: card.ranked.recipe),
                    reasonKind: reasonKind(for: card),
                    reasonText: card.hook,
                    title: card.ranked.recipe.title,
                    creatorName: feedCreatorLabel(for: card.ranked.recipe),
                    thumbnailSymbolName: thumbnailSymbolName(for: card.ranked.recipe),
                    meta: metaLine(for: card.ranked.recipe)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reason / image / meta mapping for atoms

    private func reasonKind(for card: HookedRecipeCard) -> ReasonKind {
        if fridgeMatchByRecipeID[card.ranked.recipe.id] != nil { return .fridge }
        switch card.hookKind {
        case .readyNow, .almostReady: return .fridge
        case .trending:               return .trending
        case .peakSeason:             return .peak
        case .quickMeal:              return .fresh
        }
    }

    private func feedImageSource(for recipe: Recipe) -> FeedImageSource {
        let trimmedRemote = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedRemote.isEmpty, let url = URL(string: trimmedRemote) {
            return FeedImageSource(url: url, fallbackAssetName: nil)
        }
        if let cover = resolvedRecipeCoverImage(for: recipe),
           let remoteURLString = cover.remoteURL,
           let url = URL(string: remoteURLString) {
            return FeedImageSource(url: url, fallbackAssetName: nil)
        }
        return FeedImageSource(url: nil, fallbackAssetName: nil)
    }

    private func recipeHasEditorialMedia(_ recipe: Recipe) -> Bool {
        let trimmedRemote = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedRemote.isEmpty, URL(string: trimmedRemote) != nil {
            return true
        }
        if let cover = resolvedRecipeCoverImage(for: recipe) {
            if recipeImageFileURL(for: cover.localPath) != nil {
                return true
            }
            if let remoteURLString = cover.remoteURL,
               !remoteURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               URL(string: remoteURLString) != nil {
                return true
            }
        }
        return false
    }

    private func resolvedRhythmSlot(for card: HookedRecipeCard, proposed: HomeFeedRhythmSlot) -> HomeFeedRhythmSlot {
        guard !recipeHasEditorialMedia(card.ranked.recipe) else { return proposed }
        switch proposed {
        case .classic, .split:
            return .compact
        case .compact:
            return .compact
        }
    }

    private func creatorAvatarSource(for recipe: Recipe) -> FeedImageSource {
        if isImportedRecipe(recipe) {
            return FeedImageSource(url: nil, fallbackAssetName: nil)
        }
        let trimmed = recipe.creatorAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, let url = URL(string: trimmed) {
            return FeedImageSource(url: url, fallbackAssetName: nil)
        }
        return FeedImageSource(url: nil, fallbackAssetName: nil)
    }

    private func identityKind(for recipe: Recipe) -> FeedIdentityKind {
        isImportedRecipe(recipe) ? .source : .creator
    }

    private func thumbnailSymbolName(for recipe: Recipe) -> String {
        isImportedRecipe(recipe) ? "doc.text" : "fork.knife"
    }

    private func feedCreatorLabel(for recipe: Recipe) -> String {
        if let sourceName = importedSourceName(for: recipe) {
            return sourceName
        }
        let displayName = recipe.displayCreatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty, displayName.lowercased() != "unknown" {
            return displayName
        }
        if let sourceName = recipe.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceName.isEmpty {
            return sourceName
        }
        return viewModel.languageCode == "it" ? "Season" : "Season"
    }

    private func metaLine(for recipe: Recipe) -> FeedMetaLine {
        let time = displayableTimeText(for: recipe)
        let totalMinutes = recipeTotalMinutes(recipe)
        let secondary: String?
        if totalMinutes > 0, let difficulty = recipe.difficulty {
            secondary = viewModel.localizer.recipeDifficultyTitle(difficulty)
        } else {
            secondary = nil
        }
        let fallback = isImportedRecipe(recipe) ? importedRecipeMetaFallback : localizedRecipeMetaFallback
        return FeedMetaLine(primary: time ?? secondary ?? fallback, secondary: time == nil ? nil : secondary)
    }

    private func isImportedRecipe(_ recipe: Recipe) -> Bool {
        recipe.canonicalCreatorID == nil && importedSourceName(for: recipe) != nil
    }

    private func importedSourceName(for recipe: Recipe) -> String? {
        guard let sourceName = recipe.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceName.isEmpty else {
            return nil
        }
        return sourceName
    }

    private var importedRecipeSubtitle: String {
        viewModel.languageCode == "it" ? "Fonte esterna" : "External source"
    }

    private var importedRecipeMetaFallback: String {
        viewModel.languageCode == "it" ? "Ricetta esterna" : "External recipe"
    }

    private func primaryIdentityLabel(for recipe: Recipe) -> String {
        if let sourceName = importedSourceName(for: recipe) {
            return sourceName
        }
        let displayName = recipe.displayCreatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty, displayName.lowercased() != "unknown" {
            return displayName
        }
        return "Season"
    }

    // MARK: - Editorial injections

    @ViewBuilder
    private func editorialInjectionView(for injection: HomeFeedEditorialInjection) -> some View {
        switch injection {
        case .peakCarousel:    peakCarouselBandView
        case .tipBand:        tipBandView
        case .nudgeCard:      nudgeCardView
        case .collectionTile: collectionTileView
        case .pulseBand:      pulseBandView
        }
    }

    @ViewBuilder
    private var peakCarouselBandView: some View {
        let cards = peakRecipeCards()
        if !cards.isEmpty {
            PeakCarouselBand(
                kicker: viewModel.localizer.localized("home.band.peak.kicker"),
                title: viewModel.localizer.localized("home.band.peak.title"),
                titleEmphasis: viewModel.localizer.localized("home.band.peak.title_em"),
                cards: cards,
                onSelect: { selected in
                    if let ranked = rankedRecipe(forID: selected.id) {
                        openRecipe(ranked)
                    }
                }
            )
        }
    }

    private var tipBandView: some View {
        TipCardBand(
            kicker: viewModel.localizer.localized("home.tip.kicker"),
            text: viewModel.localizer.localized("home.tip.text"),
            textEmphasis: viewModel.localizer.localized("home.tip.text_em"),
            ctaText: viewModel.localizer.localized("home.tip.cta"),
            isInteractive: false
        )
    }

    @ViewBuilder
    private var collectionTileView: some View {
        let recipes = collectionRecipes()
        let thumbs = recipes.prefix(3).map { feedImageSource(for: $0.recipe) }
        if thumbs.count >= 3 {
            let readyCount = recipes.reduce(into: 0) { partial, ranked in
                if let match = fridgeMatchByRecipeID[ranked.recipe.id], match.missingCount <= 1 {
                    partial += 1
                }
            }
            let meta = String(
                format: viewModel.localizer.localized("home.collection.meta_format"),
                readyCount
            )
            let kicker = String(
                format: viewModel.localizer.localized("home.collection.kicker"),
                recipes.count
            )
            CollectionTile(
                kicker: kicker,
                title: viewModel.localizer.localized("home.collection.title"),
                meta: meta,
                ctaText: viewModel.localizer.localized("home.collection.cta"),
                thumbs: thumbs,
                isInteractive: false
            )
        }
    }

    private var pulseBandView: some View {
        let context = pulseContext()
        return CommunityPulseBand(
            liveLabel: viewModel.localizer.localized("home.pulse.live"),
            headline: context.headline,
            emphasis: context.emphasis,
            subline: context.subline,
            avatars: context.avatars
        )
    }

    @ViewBuilder
    private var nudgeCardView: some View {
        if let suggestion = suggestedCreatorNudge() {
            NudgeCard(
                kicker: viewModel.localizer.localized("home.nudge.kicker"),
                name: suggestion.name,
                bio: suggestion.bio,
                reason: viewModel.localizer.localized("home.nudge.reason_format"),
                avatar: suggestion.avatar,
                followLabel: suggestion.isFollowing
                    ? viewModel.localizer.localized("home.nudge.following")
                    : viewModel.localizer.localized("home.nudge.follow"),
                isFollowing: suggestion.isFollowing,
                onFollow: { suggestion.toggleFollow() }
            )
        }
    }

    // MARK: - Editorial helper data

    private func collectionRecipes() -> [RankedRecipe] {
        let pool = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> RankedRecipe? in
                if case .recipe(let card) = item { return card.ranked }
                return nil
            }
        var seen: Set<String> = []
        var recipes: [RankedRecipe] = []
        for ranked in pool where ranked.seasonalMatchPercent >= 72 && recipeHasEditorialMedia(ranked.recipe) {
            guard seen.insert(ranked.recipe.id).inserted else { continue }
            recipes.append(ranked)
            if recipes.count == 5 { break }
        }
        return recipes
    }

    private func peakRecipeCards() -> [PeakIngredientCard] {
        let pool = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> RankedRecipe? in
                if case .recipe(let card) = item { return card.ranked }
                return nil
            }

        var seen: Set<String> = []
        let seasonal = pool
            .filter { $0.seasonalMatchPercent >= 70 && recipeHasEditorialMedia($0.recipe) }
            .filter { ranked in
                guard seen.insert(ranked.recipe.id).inserted else { return false }
                return true
            }
            .prefix(8)

        return seasonal.map { ranked in
            PeakIngredientCard(
                id: ranked.recipe.id,
                title: ranked.recipe.title,
                subtitle: displayableTimeText(for: ranked.recipe) ?? feedCreatorLabel(for: ranked.recipe),
                image: feedImageSource(for: ranked.recipe)
            )
        }
    }

    private func rankedRecipe(forID recipeID: String) -> RankedRecipe? {
        for item in activeMiniFeedItems + remainingFeedItems {
            if case .recipe(let card) = item, card.ranked.recipe.id == recipeID {
                return card.ranked
            }
        }
        return viewModel.rankedRecipe(forID: recipeID)
    }

    private func pulseAvatarSources() -> [FeedImageSource] {
        let pool = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> Recipe? in
                if case .recipe(let card) = item { return card.ranked.recipe }
                return nil
            }
        var seen: Set<String> = []
        var sources: [FeedImageSource] = []
        for recipe in pool {
            let avatarRaw = recipe.creatorAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !avatarRaw.isEmpty, let url = URL(string: avatarRaw) else { continue }
            let key = recipe.canonicalCreatorID ?? avatarRaw
            if seen.contains(key) { continue }
            seen.insert(key)
            sources.append(FeedImageSource(url: url, fallbackAssetName: nil))
            if sources.count == 4 { break }
        }
        if !sources.isEmpty {
            return sources
        }
        return creatorStripData.prefix(4).map(\.avatar)
    }

    private struct PulseContext {
        let emphasis: String?
        let headline: String
        let subline: String
        let avatars: [FeedImageSource]
    }

    private func pulseContext() -> PulseContext {
        let recipes = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> Recipe? in
                if case .recipe(let card) = item { return card.ranked.recipe }
                return nil
            }
        let crispyTotal = recipes.prefix(6).reduce(0) { $0 + viewModel.crispyCount(for: $1) }
        let creatorNames = Array(NSOrderedSet(array: recipes.map(primaryIdentityLabel(for:)).filter { !$0.isEmpty })) as? [String] ?? []
        let activeCreatorCount = max(creatorNames.count, pulseAvatarSources().count)
        let headline: String
        let subline: String

        if viewModel.languageCode == "it" {
            headline = activeCreatorCount == 1
                ? "voce attiva su Season"
                : "voci attive su Season"
            let names = creatorNames.prefix(3).joined(separator: " · ")
            let crispyLine = crispyTotal > 0
                ? "\(crispyTotal.compactFormatted()) crispy oggi"
                : "Ricette e fonti in movimento oggi"
            subline = names.isEmpty
                ? crispyLine
                : "\(names) — \(crispyLine)"
        } else {
            headline = activeCreatorCount == 1
                ? "active voice on Season"
                : "active voices on Season"
            let names = creatorNames.prefix(3).joined(separator: " · ")
            let crispyLine = crispyTotal > 0
                ? "\(crispyTotal.compactFormatted()) crispies today"
                : "Recipes and sources moving today"
            subline = names.isEmpty
                ? crispyLine
                : "\(names) — \(crispyLine)"
        }

        return PulseContext(
            emphasis: activeCreatorCount > 0 ? activeCreatorCount.compactFormatted() : nil,
            headline: headline,
            subline: subline,
            avatars: pulseAvatarSources()
        )
    }

    private struct NudgeSuggestion {
        let id: String
        let name: String
        let bio: String
        let avatar: FeedImageSource
        let isFollowing: Bool
        let toggleFollow: () -> Void
    }

    private func suggestedCreatorNudge() -> NudgeSuggestion? {
        let pool = (activeMiniFeedItems + remainingFeedItems)
            .compactMap { item -> Recipe? in
                if case .recipe(let card) = item { return card.ranked.recipe }
                return nil
            }
        var seenNames: Set<String> = []
        for recipe in pool {
            let creatorID = recipe.canonicalCreatorID
            if let creatorID, followStore.followingIds.contains(creatorID) { continue }
            if seenNames.contains(recipe.author) { continue }
            seenNames.insert(recipe.author)

            let avatarRaw = recipe.creatorAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let avatarURL = avatarRaw.isEmpty ? nil : URL(string: avatarRaw)
            let source = FeedImageSource(url: avatarURL, fallbackAssetName: nil)

            let id = creatorID ?? "author:\(recipe.author)"
            let isFollowing = creatorID.map { followStore.followingIds.contains($0) } ?? false
            let capturedCreatorID = creatorID
            let followers = viewModel.followerCount(for: recipe.author, isFollowedByCurrentUser: isFollowing)
            let authoredCount = max(1, viewModel.activeRecipes(for: recipe.author).count)
            let bio = "\(followers.compactFormatted()) \(viewModel.localizer.text(.followers)) · \(authoredCount.compactFormatted()) \(viewModel.localizer.text(.recipes))"
            return NudgeSuggestion(
                id: id,
                name: recipe.author,
                bio: bio,
                avatar: source,
                isFollowing: isFollowing,
                toggleFollow: {
                    guard let creatorID = capturedCreatorID else { return }
                    let store = FollowStore.shared
                    if store.followingIds.contains(creatorID) {
                        store.unfollow(creatorID)
                    } else {
                        store.follow(creatorID)
                    }
                }
            )
        }
        return nil
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
                    .font(DS.Font.sans(14, weight: .semibold))
                    .foregroundStyle(DS.Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Color.card)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(DS.Color.borderM, lineWidth: 1)
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
            if SeasonLog.verbose {
                if cachedFilteredFeeds[selectedQuickFilter] != nil {
                    print("[SEASON_HOME_FOLLOWING] phase=cache_hit filter=following")
                } else {
                    print("[SEASON_HOME_FOLLOWING] phase=cache_miss filter=following")
                }
            }
            let followingRecipeItems = filtered.flatMap { item -> [HookedRecipeCard] in
                switch item {
                case .recipe(let card):
                    return [card]
                case .followingFallbackSeparator:
                    return []
                }
            }
            if SeasonLog.verbose {
                print("[SEASON_HOME_FOLLOWING] phase=feed_resolved filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRecipeItems.count)")
                for card in followingRecipeItems.prefix(5) {
                    let creatorID = card.ranked.recipe.canonicalCreatorID ?? "nil"
                    print("[SEASON_HOME_FOLLOWING] phase=feed_item recipe_id=\(card.ranked.recipe.id) creator_id=\(creatorID)")
                }
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
            guard case .recipe(let card) = item else { return }
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
        return "\(viewModel.languageCode)|\(fridgeIDs)|\(viewModel.currentMonth)|\(viewModel.homeFeedRefreshID)|\(viewModel.homeFeedDataVersion)|\(followingIDs)"
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
            if SeasonLog.verbose {
                print("[SEASON_HOME_FOLLOWING] phase=feed_computed filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRanked.count)")
            }
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
                    guard case .recipe(let card) = item else { return nil }
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
                let fallbackItems = fallbackCards.prefix(fallbackTarget).map { HomeFeedItem.recipe($0) }
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
        for card in cards.prefix(targetCount) {
            items.append(.recipe(card))
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
            case .recipe(let card):
                guard !seenRecipeIDs.contains(card.ranked.recipe.id) else { continue }
                seenRecipeIDs.insert(card.ranked.recipe.id)
                deduplicated.append(item)
            case .followingFallbackSeparator:
                guard separatorIndex == nil else { continue }
                separatorIndex = deduplicated.count
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
            if case .recipe(let card) = item {
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
            if SeasonLog.verbose {
                print("[SEASON_HOME_FOLLOWING] phase=feed_computed filter=following followed_count=\(followStore.followingIds.count) result_count=\(followingRanked.count)")
            }
            guard !followingRanked.isEmpty else { return [] }
            let cards = buildHookedCards(
                from: followingRanked,
                preferTrending: false,
                trendingIDs: trendingIDs,
                previousHook: nil
            )
            return cards.prefix(3).map { HomeFeedItem.recipe($0) }
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
            HomeFeedItem.recipe(card)
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
            if case .recipe(let card) = item { return card.ranked.recipe.id }
            return nil
        })
        for item in mainContinuousFeedItems where mini.count < 3 {
            guard case .recipe(let card) = item else { continue }
            guard !existingRecipeIDs.contains(card.ranked.recipe.id) else { continue }
            mini.append(.recipe(card))
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
                let item = HomeFeedItem.recipe(card)
                if !existingRecipeIDs.contains(card.ranked.recipe.id) {
                    mini.append(item)
                    existingRecipeIDs.insert(card.ranked.recipe.id)
                }
            }
        }

        return Array(mini.prefix(3))
    }

    private func recipeIDs(in item: HomeFeedItem) -> Set<String> {
        switch item {
        case .recipe(let card):
            return [card.ranked.recipe.id]
        case .followingFallbackSeparator:
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
        targetCount: Int
    ) -> [HomeFeedItem] {
        guard !cards.isEmpty else { return [] }
        return cards.prefix(targetCount).map { HomeFeedItem.recipe($0) }
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
            let uniqueIngredientIDs = Set(
                ranked.recipe.ingredients.flatMap { ingredient in
                    viewModel.catalogIdentityIDs(for: ingredient)
                }
            )
            for id in uniqueIngredientIDs {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    private func debugHomeFeed(_ message: String) {
        #if DEBUG
        if SeasonLog.verbose || ProcessInfo.processInfo.environment["SEASON_HOME_DEBUG"] == "1" {
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
            if SeasonLog.verbose, selectedQuickFilter == .following {
                print("[SEASON_HOME_FOLLOWING] phase=filter_selected filter=following")
            }
        }
    }

    private var quickFilterSelectionAnimation: Animation {
        .easeOut(duration: 0.14)
    }

    private func featuredTimeText(for recipe: Recipe) -> String {
        if let time = displayableTimeText(for: recipe) {
            return time
        }
        if isImportedRecipe(recipe) {
            return importedRecipeMetaFallback
        }
        return localizedRecipeMetaFallback
    }

    private func displayableTimeText(for recipe: Recipe) -> String? {
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
        return nil
    }

    private var localizedRecipeMetaFallback: String {
        viewModel.localizer.localized("home.meta.recipe")
    }

    @ViewBuilder
    private func largeRecipeCard(ranked: RankedRecipe, hook: String, showFollowingSignal: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                feedCreatorHeader(for: ranked.recipe, showFollowingSignal: showFollowingSignal)

                recipeImage(for: ranked.recipe, height: 188)
                    .clipShape(Rectangle())

                VStack(alignment: .leading, spacing: 8) {
                    ReasonChip(kind: reasonKind(for: HookedRecipeCard(ranked: ranked, hook: hook, hookKind: primaryHook(for: ranked).kind)), text: hook)

                    Text(ranked.recipe.title)
                        .font(DS.Font.serif(20, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        feedMetaLabel(featuredTimeText(for: ranked.recipe))

                        if let difficulty = ranked.recipe.difficulty {
                            feedMetaDot
                            feedMetaLabel(viewModel.localizer.recipeDifficultyTitle(difficulty))
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(14)
            }
            .background(DS.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
            .dsShadow(.s1)
            .contentShape(Rectangle())

            Button {
                openRecipe(ranked)
            } label: {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
            .zIndex(1)

            if ranked.recipe.canonicalCreatorID != nil {
                feedFollowButton(for: ranked.recipe)
                    .padding(.top, 10)
                    .padding(.trailing, 12)
                    .zIndex(2)
            }

            if let crispyPill = feedCrispyButton(for: ranked.recipe) {
                crispyPill
                    .padding(.top, 198)
                    .padding(.trailing, 12)
                    .zIndex(2)
            }
        }
    }

    private func feedCreatorHeader(for recipe: Recipe, showFollowingSignal: Bool) -> some View {
        HStack(spacing: 10) {
            if isImportedRecipe(recipe) {
                Circle()
                    .fill(DS.Color.ochreSoft.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Color.terracotta.opacity(0.72))
                    )
                    .overlay(Circle().stroke(DS.Color.border, lineWidth: 1))
            } else {
                RemoteImageView(
                    url: recipe.creatorAvatarURL
                        .flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) },
                    fallbackAssetName: nil
                )
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Color.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(primaryIdentityLabel(for: recipe))
                    .font(DS.Font.sans(12, weight: .semibold))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                Text(feedCreatorSubtitle(for: recipe, showFollowingSignal: showFollowingSignal))
                    .font(DS.Font.sans(10.5))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if recipe.canonicalCreatorID != nil {
                Color.clear
                    .frame(width: 76, height: 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func feedFollowButton(for recipe: Recipe) -> some View {
        if let creatorID = recipe.canonicalCreatorID {
            let isFollowing = followStore.followingIds.contains(creatorID)
            Button {
                followStore.toggleFollow(creatorID)
            } label: {
                Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                    .font(DS.Font.sans(11, weight: .semibold))
                    .foregroundStyle(isFollowing ? DS.Color.inkMuted : DS.Color.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isFollowing ? Color.clear : DS.Color.card.opacity(0.92))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isFollowing ? Color.clear : DS.Color.borderS, lineWidth: 1.2)
                    )
            }
            .buttonStyle(PressableCardButtonStyle(pressedScale: 0.96))
        }
    }

    private func feedCrispyButton(for recipe: Recipe) -> AnyView? {
        let crispyCount = viewModel.crispyCount(for: recipe)
        let isActive = viewModel.isRecipeCrispied(recipe)
        guard crispyCount > 0 || isActive else { return nil }
        return AnyView(
            Button {
                viewModel.toggleRecipeCrispy(recipe)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(crispyCount.compactFormatted())
                        .font(DS.Font.mono(10.5, weight: .semibold))
                }
                .foregroundStyle(isActive ? DS.Color.Crispy.inkActive : DS.Color.Crispy.inkInactive)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? DS.Color.Crispy.bgActive : DS.Color.card.opacity(0.92))
                )
                .dsShadow(.s1)
            }
            .buttonStyle(PressableCardButtonStyle(pressedScale: 0.94))
            .accessibilityLabel("Crispy")
        )
    }

    private func feedCreatorSubtitle(for recipe: Recipe, showFollowingSignal: Bool) -> String {
        if showFollowingSignal {
            return viewModel.localizer.text(.following)
        }
        if isImportedRecipe(recipe) {
            return importedRecipeSubtitle
        }
        return heroCreatorMeta(for: recipe)
    }

    private func feedMetaLabel(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.sans(11.5))
            .foregroundStyle(DS.Color.inkMuted)
            .lineLimit(1)
    }

    private var feedMetaDot: some View {
        Circle()
            .fill(DS.Color.inkFaint)
            .frame(width: 3, height: 3)
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
                    fallbackAssetName: nil
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
                    fallbackAssetName: nil
                )
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
                fallbackAssetName: nil
            )
        } else {
            recipeFallbackImage
        }
    }

    private var recipeFallbackImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Color.bgSub,
                            DS.Color.sageSoft.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DS.Color.sageDeep.opacity(0.42))
        }
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
            return localizer.localized("home.filter.ready_now")
        case .under15:
            return "15 \(localizer.text(.minutesShort))"
        case .highProtein:
            return localizer.localized("home.filter.high_protein")
        case .peakSeason:
            return localizer.localized("home.filter.peak_season")
        case .trending:
            return localizer.localized("home.filter.trending")
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
private enum HomeFeedItem: Identifiable {
    case recipe(HookedRecipeCard)
    case followingFallbackSeparator

    var id: String {
        switch self {
        case .recipe(let card):
            return "recipe-\(card.ranked.recipe.id)"
        case .followingFallbackSeparator:
            return "following-fallback-separator"
        }
    }

    var isRecipe: Bool {
        if case .recipe = self { return true }
        return false
    }
}

/// Rhythm slot for a recipe in the v2b mixed feed. Derived from the card's
/// position in the combined feed list by `HomeView.rhythmSlot(for:)`.
private enum HomeFeedRhythmSlot {
    case classic
    case split
    case compact
}

/// Editorial module injected between recipe cards to break the off-white
/// wash and give the feed visible rhythm.
private enum HomeFeedEditorialInjection {
    case peakCarousel
    case tipBand
    case nudgeCard
    case collectionTile
    case pulseBand
}

private struct HomeRecipeRoute: Identifiable, Hashable {
    let rankedRecipe: RankedRecipe
    var id: String { rankedRecipe.recipe.id }

    static func == (lhs: HomeRecipeRoute, rhs: HomeRecipeRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Feed item + its position in the "recipe-only" sub-sequence. Non-recipe
/// items (fridge, spotlight, separator) get `recipeIndex == nil`. Used by
/// `HomeView.rhythmFeedBody` to render the rhythm without mutating state
/// inside a `ForEach` body.
private struct IndexedHomeFeedItem: Identifiable {
    let item: HomeFeedItem
    let recipeIndex: Int?
    let position: Int

    var id: String { "\(position)-\(item.id)" }
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
            if case .recipe(let card) = item {
                return card.hookKind
            }
        }
        return nil
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
