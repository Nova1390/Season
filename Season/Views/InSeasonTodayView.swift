import SwiftUI

struct InSeasonTodayView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @State private var selectedCategory: TodayCategoryFilter = .all

    var body: some View {
        ScrollView {
            let rankedItems = viewModel.rankedInSeasonTodayItems()
            let filteredItems = filtered(rankedItems)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if rankedItems.isEmpty {
                    todayEmptyState
                } else {
                    todayGreeting(items: rankedItems)
                    monthInsightCard(items: rankedItems)

                    if let heroItem = rankedItems.first {
                        featuredPeakCard(heroItem, pairings: Array(rankedItems.dropFirst().prefix(3)))
                    }

                    categoryFilters
                    rankedListSection(items: filteredItems, totalCount: rankedItems.count)
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
    }

    private func todayGreeting(items: [RankedInSeasonItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(DS.Color.fresh)
                    .frame(width: 6, height: 6)
                Text("\(viewModel.currentMonthName.uppercased()) · \(viewModel.localizer.text(.inSeasonTodayTitle).uppercased())")
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.9)
                    .foregroundStyle(DS.Color.inkMuted)
            }

            Text(greetingTitle(for: items))
                .font(DS.Font.serif(32, weight: .medium))
                .foregroundStyle(DS.Color.ink)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func monthInsightCard(items: [RankedInSeasonItem]) -> some View {
        let peakCount = items.filter { todaySeasonStage(for: $0.item) == .best }.count
        let arrivingCount = items.filter { todaySeasonStage(for: $0.item) == .firstOfSeason }.count
        let leavingCount = items.filter { todaySeasonStage(for: $0.item) == .endOfSeason }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(DS.Color.fresh)
                    .frame(width: 6, height: 6)
                    .shadow(color: DS.Color.fresh.opacity(0.28), radius: 5)
                Text(monthInsightLabel)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.9)
                    .foregroundStyle(DS.Color.sageDeep)
            }

            Text(monthInsightTitle(peak: peakCount, arriving: arrivingCount, leaving: leavingCount))
                .font(DS.Font.serif(19, weight: .medium))
                .foregroundStyle(DS.Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                todayStat(value: peakCount, label: localizedPeakLabel)
                todayStat(value: arrivingCount, label: localizedArrivingLabel)
                todayStat(value: leavingCount, label: localizedLeavingLabel)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Color.sageSoft.opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.sage.opacity(0.14), lineWidth: 1)
        )
    }

    private func todayStat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(DS.Font.sans(17, weight: .bold))
                .foregroundStyle(DS.Color.sageDeep)
                .monospacedDigit()
            Text(label.uppercased())
                .font(DS.Font.mono(9, weight: .medium))
                .kerning(0.7)
                .foregroundStyle(DS.Color.inkMuted)
        }
    }

    private func featuredPeakCard(
        _ ranked: RankedInSeasonItem,
        pairings: [RankedInSeasonItem]
    ) -> some View {
        NavigationLink {
            ProduceDetailView(
                item: ranked.item,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    IngredientVisualView(
                        name: ranked.item.displayName(languageCode: viewModel.localizer.languageCode),
                        produceCategory: ranked.item.category,
                        basicCategory: nil,
                        imageName: resolvedProduceImageName(for: ranked.item),
                        cornerRadius: DS.Radius.xl,
                        imageContentMode: .fit,
                        imagePaddingRatio: 0.08,
                        iconScale: 0.26,
                        showsNameInFallback: false
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 236)
                    .clipped()

                    HStack(spacing: 7) {
                        Circle()
                            .fill(DS.Color.fresh)
                            .frame(width: 5, height: 5)
                        Text(featuredBadgeText(for: ranked.item))
                            .font(DS.Font.mono(10, weight: .medium))
                            .kerning(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.58))
                    )
                    .padding(14)

                    HStack(spacing: 5) {
                        Image(systemName: scoreDeltaIcon(for: ranked.item))
                            .font(.system(size: 9, weight: .bold))
                        Text(scoreText(for: ranked))
                            .font(DS.Font.sans(13, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(DS.Color.sageDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Color.card.opacity(0.94))
                    )
                    .dsShadow(.s1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(featuredEyebrow(for: ranked.item))
                        .font(DS.Font.mono(10, weight: .medium))
                        .kerning(0.9)
                        .foregroundStyle(DS.Color.inkMuted)

                    Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                        .font(DS.Font.serif(26, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(2)

                    Text(featuredReasonText(for: ranked))
                        .font(DS.Font.sans(13))
                        .foregroundStyle(DS.Color.inkSoft)
                        .lineSpacing(2)
                        .lineLimit(3)

                    reasonChipRow(reasons: Array(ranked.reasons.prefix(3)))

                    if !pairings.isEmpty {
                        pairingRow(pairings)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .dsShadow(.s2)
        }
        .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TodayCategoryFilter.allCases) { filter in
                    Button {
                        selectedCategory = filter
                    } label: {
                        Text(filter.title(languageCode: viewModel.localizer.languageCode))
                            .font(DS.Font.sans(12, weight: .semibold))
                            .foregroundStyle(selectedCategory == filter ? DS.Color.sageDeep : DS.Color.inkSoft)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedCategory == filter ? DS.Color.sageSoft.opacity(0.82) : DS.Color.card)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(selectedCategory == filter ? DS.Color.sage.opacity(0.24) : DS.Color.borderM, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func rankedListSection(items: [RankedInSeasonItem], totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.localizer.text(.inSeasonTodayTitle))
                    .font(DS.Font.serif(23, weight: .medium))
                    .foregroundStyle(DS.Color.ink)

                Spacer()

                Text(String(format: viewModel.localizer.text(.ingredientsCountFormat), items.count).uppercased())
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(0.7)
                    .foregroundStyle(DS.Color.inkMuted)
            }

            LazyVStack(spacing: 10) {
                ForEach(items) { ranked in
                    NavigationLink {
                        ProduceDetailView(
                            item: ranked.item,
                            viewModel: viewModel,
                            shoppingListViewModel: shoppingListViewModel
                        )
                    } label: {
                        todayRankRow(ranked)
                    }
                    .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
                }
            }
        }
    }

    private func todayRankRow(_ ranked: RankedInSeasonItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ProduceThumbnailView(item: ranked.item, size: 50)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                    .font(DS.Font.serif(17, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)

                reasonChipRow(reasons: Array(ranked.reasons.prefix(2)), compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(scoreText(for: ranked))
                    .font(DS.Font.sans(13, weight: .bold))
                    .foregroundStyle(scoreColor(for: ranked))
                    .monospacedDigit()

                Text(deltaText(for: ranked.item))
                    .font(DS.Font.mono(9, weight: .medium))
                    .kerning(0.4)
                    .foregroundStyle(deltaColor(for: ranked.item))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func reasonChipRow(reasons: [String], compact: Bool = false) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                Text(reason)
                    .font(DS.Font.sans(compact ? 9.5 : 10.5, weight: .medium))
                    .foregroundStyle(DS.Color.sageDeep)
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 7 : 8)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Color.sageSoft.opacity(compact ? 0.42 : 0.52))
                    )
            }
        }
    }

    private func pairingRow(_ pairings: [RankedInSeasonItem]) -> some View {
        HStack(spacing: 8) {
            Text(pairingLabel)
                .font(DS.Font.mono(10, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(DS.Color.inkMuted)

            HStack(spacing: -8) {
                ForEach(pairings) { pairing in
                    ProduceThumbnailView(item: pairing.item, size: 28)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DS.Color.card))
                        .clipShape(Circle())
                }
            }

            Text(pairings.map { $0.item.displayName(languageCode: viewModel.localizer.languageCode) }.joined(separator: ", "))
                .font(DS.Font.sans(12))
                .foregroundStyle(DS.Color.inkSoft)
                .lineLimit(1)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DS.Color.border)
                .frame(height: 1)
        }
    }

    private var todayEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DS.Color.sageDeep)
                .frame(width: 62, height: 62)
                .background(Circle().fill(DS.Color.sageSoft.opacity(0.5)))

            Text(viewModel.localizer.text(.inSeasonTodayTitle))
                .font(DS.Font.serif(26, weight: .medium))
                .foregroundStyle(DS.Color.ink)

            Text(viewModel.localizer.text(.noResults))
                .font(DS.Font.sans(13))
                .foregroundStyle(DS.Color.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.card)
        )
    }

    private func filtered(_ items: [RankedInSeasonItem]) -> [RankedInSeasonItem] {
        guard let category = selectedCategory.category else { return items }
        return items.filter { $0.item.category == category }
    }

    private func seasonalityPhase(for item: ProduceItem) -> SeasonalityPhase {
        item.seasonalityPhase(month: viewModel.currentMonth)
    }

    private func todaySeasonStage(for item: ProduceItem) -> TodaySeasonStage {
        if item.isYearRoundSeasonal() {
            return .stable
        }

        switch seasonalityPhase(for: item) {
        case .earlySeason:
            return .firstOfSeason
        case .endingSoon:
            return .endOfSeason
        case .inSeason:
            return .best
        case .outOfSeason:
            return .out
        }
    }

    private func scoreText(for ranked: RankedInSeasonItem) -> String {
        "\(Int(min(100, max(0, ranked.score)).rounded()))%"
    }

    private func scoreColor(for ranked: RankedInSeasonItem) -> Color {
        ranked.score >= 94 ? DS.Color.terracotta : DS.Color.sageDeep
    }

    private func deltaText(for item: ProduceItem) -> String {
        let delta = item.seasonalityDelta(month: viewModel.currentMonth)
        if abs(delta) < 0.01 { return localizedStableLabel }
        let value = Int((delta * 100).rounded())
        return value > 0 ? "+\(value)%" : "\(value)%"
    }

    private func deltaColor(for item: ProduceItem) -> Color {
        item.seasonalityDelta(month: viewModel.currentMonth) >= 0 ? DS.Color.fresh : DS.Color.ochre
    }

    private func scoreDeltaIcon(for item: ProduceItem) -> String {
        item.seasonalityDelta(month: viewModel.currentMonth) >= 0 ? "arrow.up" : "arrow.down"
    }

    private func featuredReasonText(for ranked: RankedInSeasonItem) -> String {
        let name = ranked.item.displayName(languageCode: viewModel.localizer.languageCode)
        let firstReason = ranked.reasons.first ?? viewModel.localizer.text(.reasonInSeasonNow)
        let stage = todaySeasonStage(for: ranked.item)

        if viewModel.localizer.languageCode.hasPrefix("it") {
            switch stage {
            case .firstOfSeason:
                return "\(name) è una primizia di stagione: arriva ora sui banchi ed è interessante quando è fresco e ben scelto."
            case .endOfSeason:
                return "\(name) è in fine stagione: usalo ora, prima che qualità e disponibilità inizino a calare."
            case .best:
                return "\(name) è al meglio adesso: \(firstReason.lowercased())."
            case .stable:
                return "\(name) ha una presenza stabile durante l’anno: utile in cucina, ma meno legato a un picco stagionale."
            case .out:
                return "\(name) è una scelta possibile, ma non è nel suo momento migliore."
            }
        }

        switch stage {
        case .firstOfSeason:
            return "\(name) is a first-of-season pick: it is just arriving and is worth using while fresh."
        case .endOfSeason:
            return "\(name) is near the end of its season: use it before quality and availability taper off."
        case .best:
            return "\(name) is at its best right now: \(firstReason.lowercased())."
        case .stable:
            return "\(name) has a steady year-round presence: useful, but less tied to a seasonal peak."
        case .out:
            return "\(name) is usable, but not in its strongest seasonal moment."
        }
    }

    private func greetingTitle(for items: [RankedInSeasonItem]) -> String {
        if viewModel.localizer.languageCode.hasPrefix("it") {
            return "Il meglio di stagione, proprio ora."
        }
        return "The best of the season, right now."
    }

    private var monthInsightLabel: String {
        if viewModel.localizer.languageCode.hasPrefix("it") {
            return "\(viewModel.currentMonthName) ora"
        }
        return "\(viewModel.currentMonthName) right now"
    }

    private func monthInsightTitle(peak: Int, arriving: Int, leaving: Int) -> String {
        if viewModel.localizer.languageCode.hasPrefix("it") {
            return "\(peak) al meglio, \(arriving) primizie, \(leaving) in fine stagione."
        }
        return "\(peak) at their best, \(arriving) first-of-season, \(leaving) end-of-season."
    }

    private var localizedPeakLabel: String {
        viewModel.localizer.languageCode.hasPrefix("it") ? "al meglio" : "at best"
    }

    private var localizedArrivingLabel: String {
        viewModel.localizer.languageCode.hasPrefix("it") ? "primizie" : "first-of-season"
    }

    private var localizedLeavingLabel: String {
        viewModel.localizer.languageCode.hasPrefix("it") ? "fine stagione" : "end-of-season"
    }

    private var localizedStableLabel: String {
        viewModel.localizer.languageCode.hasPrefix("it") ? "stagione stabile" : "steady season"
    }

    private func featuredEyebrow(for item: ProduceItem) -> String {
        switch todaySeasonStage(for: item) {
        case .firstOfSeason:
            return viewModel.localizer.languageCode.hasPrefix("it") ? "Primizia di stagione" : "First of the season"
        case .endOfSeason:
            return viewModel.localizer.languageCode.hasPrefix("it") ? "Fine stagione" : "End of season"
        case .best:
            return viewModel.localizer.languageCode.hasPrefix("it") ? "Al meglio adesso" : "Best right now"
        case .stable:
            return viewModel.localizer.languageCode.hasPrefix("it") ? "Stagione stabile" : "Steady season"
        case .out:
            return viewModel.localizer.languageCode.hasPrefix("it") ? "Scelto per adesso" : "Picked for right now"
        }
    }

    private var pairingLabel: String {
        viewModel.localizer.languageCode.hasPrefix("it") ? "Abbina con" : "Pair with"
    }

    private func featuredBadgeText(for item: ProduceItem) -> String {
        let isItalian = viewModel.localizer.languageCode.hasPrefix("it")
        let stageTitle: String
        switch todaySeasonStage(for: item) {
        case .firstOfSeason:
            stageTitle = isItalian ? "Primizia" : "First of season"
        case .best:
            stageTitle = isItalian ? "Al meglio" : "At its best"
        case .endOfSeason:
            stageTitle = isItalian ? "Fine stagione" : "End of season"
        case .stable:
            stageTitle = isItalian ? "Stagione stabile" : "Steady season"
        case .out:
            stageTitle = viewModel.localizer.seasonalityPhaseTitle(seasonalityPhase(for: item))
        }
        return "\(stageTitle) · \(viewModel.currentMonthName)"
    }
}

private enum TodaySeasonStage: Hashable {
    case best
    case firstOfSeason
    case endOfSeason
    case stable
    case out
}

private enum TodayCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case vegetable
    case fruit
    case tuber
    case legume

    var id: String { rawValue }

    var category: ProduceCategoryKey? {
        switch self {
        case .all:
            return nil
        case .vegetable:
            return .vegetable
        case .fruit:
            return .fruit
        case .tuber:
            return .tuber
        case .legume:
            return .legume
        }
    }

    func title(languageCode: String) -> String {
        let isItalian = languageCode.hasPrefix("it")
        switch self {
        case .all:
            return isItalian ? "Tutto" : "All"
        case .vegetable:
            return isItalian ? "Verdura" : "Vegetables"
        case .fruit:
            return isItalian ? "Frutta" : "Fruit"
        case .tuber:
            return isItalian ? "Tuberi" : "Tubers"
        case .legume:
            return isItalian ? "Legumi" : "Legumes"
        }
    }
}
