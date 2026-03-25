import SwiftUI

struct ProduceDetailView: View {
    private let produceItem: ProduceItem?
    private let basicIngredient: BasicIngredient?
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var shoppingButtonPulse = false
    @State private var fridgeButtonPulse = false

    init(
        item: ProduceItem,
        viewModel: ProduceViewModel,
        shoppingListViewModel: ShoppingListViewModel
    ) {
        self.produceItem = item
        self.basicIngredient = nil
        self.viewModel = viewModel
        self.shoppingListViewModel = shoppingListViewModel
    }

    init(
        basicIngredient: BasicIngredient,
        viewModel: ProduceViewModel,
        shoppingListViewModel: ShoppingListViewModel
    ) {
        self.produceItem = nil
        self.basicIngredient = basicIngredient
        self.viewModel = viewModel
        self.shoppingListViewModel = shoppingListViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                heroSection
                identityBlock
                if let produceItem {
                    seasonalitySection(for: produceItem)
                }
                actionsBlock
                if let nutrition = ingredientNutrition {
                    nutritionSection(nutrition)
                }
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.vertical, SeasonSpacing.sm)
        }
        .background(SeasonColors.primarySurface)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let produceItem {
            ProduceHeroImageView(item: produceItem, height: 228)
                .overlay(alignment: .bottomLeading) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.42), location: 0),
                                .init(color: Color.black.opacity(0.18), location: 0.55),
                                .init(color: Color.clear, location: 1)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .allowsHitTesting(false)

                        Text(ingredientDisplayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(2)
                            .padding(.horizontal, SeasonSpacing.sm)
                            .padding(.bottom, SeasonSpacing.sm)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous))
        } else if let basicIngredient {
            basicHeroImage(for: basicIngredient)
                .overlay(alignment: .bottomLeading) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.36), location: 0),
                                .init(color: Color.black.opacity(0.12), location: 0.58),
                                .init(color: Color.clear, location: 1)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .allowsHitTesting(false)

                        Text(ingredientDisplayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(2)
                            .padding(.horizontal, SeasonSpacing.sm)
                            .padding(.bottom, SeasonSpacing.sm)
                    }
                }
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SeasonSpacing.xs) {
                Text(ingredientDisplayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if let produceItem {
                    SeasonalStatusBadge(
                        score: produceItem.seasonalityScore(month: viewModel.currentMonth),
                        delta: produceItem.seasonalityDelta(month: viewModel.currentMonth),
                        localizer: viewModel.localizer
                    )
                }
            }

            if let produceItem {
                Text(viewModel.localizer.categoryTitle(for: produceItem.category))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.localizer.text(.basicIngredient))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private var actionsBlock: some View {
        HStack(spacing: SeasonSpacing.xs) {
            Button {
                toggleShoppingListState()
                pulseShoppingButton()
            } label: {
                actionToggleLabel(
                    text: isInShoppingList ? "In List" : "Add to List",
                    systemImage: isInShoppingList ? "checkmark" : "plus",
                    foreground: isInShoppingList ? Color.green.opacity(0.98) : .primary,
                    background: isInShoppingList ? Color.green.opacity(0.16) : SeasonColors.subtleSurface
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(shoppingButtonPulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: shoppingButtonPulse)

            if supportsFridgeState {
                Button {
                    toggleFridgeState()
                    pulseFridgeButton()
                } label: {
                    actionToggleLabel(
                        text: isInFridge ? "In Fridge" : "Add to Fridge",
                        systemImage: isInFridge ? "snowflake" : "plus",
                        foreground: isInFridge ? Color(red: 0.15, green: 0.55, blue: 0.72) : .primary,
                        background: isInFridge
                            ? Color(red: 0.15, green: 0.55, blue: 0.72).opacity(0.16)
                            : SeasonColors.subtleSurface
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(fridgeButtonPulse ? 0.97 : 1.0)
                .animation(.spring(response: 0.24, dampingFraction: 0.75), value: fridgeButtonPulse)
            }
        }
    }

    private func actionToggleLabel(
        text: String,
        systemImage: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }

    private func seasonalitySection(for produceItem: ProduceItem) -> some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            HStack(alignment: .center, spacing: SeasonSpacing.xs) {
                Text(viewModel.localizer.text(.seasonalityChart))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                CategoryIconView(category: produceItem.category, size: 18)
            }

            HStack(spacing: SeasonSpacing.xs) {
                SeasonBadge(
                    text: viewModel.localizer.categoryTitle(for: produceItem.category),
                    icon: symbolName(for: produceItem.category),
                    horizontalPadding: SeasonSpacing.xs,
                    verticalPadding: 5,
                    cornerRadius: SeasonRadius.small,
                    foreground: .secondary,
                    background: SeasonColors.subtleSurface
                )
                SeasonBadge(
                    text: viewModel.monthNames(for: produceItem.seasonMonths),
                    icon: "calendar",
                    horizontalPadding: SeasonSpacing.xs,
                    verticalPadding: 5,
                    cornerRadius: SeasonRadius.small,
                    foreground: .secondary,
                    background: SeasonColors.subtleSurface
                )
            }

            StylizedSeasonalityChart(
                inSeasonMonths: produceItem.seasonMonths,
                currentMonth: viewModel.currentMonth,
                languageCode: viewModel.languageCode
            )
        }
    }

    private func nutritionSection(_ nutrition: ProduceNutrition) -> some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            Text(viewModel.localizer.text(.nutrition))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                nutritionRow(
                    title: viewModel.localizer.text(.calories),
                    value: "\(nutrition.calories) kcal"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.protein),
                    value: "\(formatted(nutrition.protein)) g"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.carbs),
                    value: "\(formatted(nutrition.carbs)) g"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.fat),
                    value: "\(formatted(nutrition.fat)) g"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.fiber),
                    value: "\(formatted(nutrition.fiber)) g"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.vitaminC),
                    value: "\(formatted(nutrition.vitaminC)) mg"
                )
                nutritionRow(
                    title: viewModel.localizer.text(.potassium),
                    value: "\(formatted(nutrition.potassium)) mg"
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.localizer.text(.nutritionSourceCaption))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let nutritionReference = validNutritionReference {
                    Text(nutritionReference)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func nutritionRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SeasonSpacing.sm) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }

    private func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var ingredientDisplayName: String {
        if let produceItem {
            return produceItem.displayName(languageCode: viewModel.localizer.languageCode)
        }
        if let basicIngredient {
            return basicIngredient.displayName(languageCode: viewModel.localizer.languageCode)
        }
        return ""
    }

    private var ingredientNutrition: ProduceNutrition? {
        if let produceItem {
            return produceItem.nutrition
        }
        if let basicIngredient {
            return basicIngredient.nutrition
        }
        return nil
    }

    private var supportsFridgeState: Bool {
        produceItem != nil || basicIngredient != nil
    }

    private var isInShoppingList: Bool {
        if let produceItem {
            return shoppingListViewModel.contains(produceItem)
        }
        if let basicIngredient {
            return shoppingListViewModel.contains(basicIngredient)
        }
        return false
    }

    private var isInFridge: Bool {
        if let produceItem {
            return fridgeViewModel.contains(produceItem)
        }
        if let basicIngredient {
            return fridgeViewModel.contains(basicIngredient)
        }
        return false
    }

    private func toggleShoppingListState() {
        if let produceItem {
            withAnimation(.easeInOut(duration: 0.18)) {
                if shoppingListViewModel.contains(produceItem) {
                    shoppingListViewModel.remove(produceItem)
                } else {
                    shoppingListViewModel.add(produceItem)
                }
            }
            return
        }

        if let basicIngredient {
            withAnimation(.easeInOut(duration: 0.18)) {
                if shoppingListViewModel.contains(basicIngredient) {
                    shoppingListViewModel.remove(basicIngredient)
                } else {
                    shoppingListViewModel.add(basicIngredient)
                }
            }
        }
    }

    private func toggleFridgeState() {
        withAnimation(.easeInOut(duration: 0.18)) {
            if let produceItem {
                if fridgeViewModel.contains(produceItem) {
                    fridgeViewModel.remove(produceItem)
                } else {
                    fridgeViewModel.add(produceItem)
                }
                return
            }
            if let basicIngredient {
                if fridgeViewModel.contains(basicIngredient) {
                    fridgeViewModel.remove(basicIngredient)
                } else {
                    fridgeViewModel.add(basicIngredient)
                }
            }
        }
    }

    private func pulseShoppingButton() {
        shoppingButtonPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            shoppingButtonPulse = false
        }
    }

    private func pulseFridgeButton() {
        fridgeButtonPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            fridgeButtonPulse = false
        }
    }

    @ViewBuilder
    private func statusChip(text: String, systemImage: String, isActive: Bool) -> some View {
        SeasonBadge(
            text: text,
            icon: systemImage,
            horizontalPadding: SeasonSpacing.xs,
            verticalPadding: 5,
            cornerRadius: SeasonRadius.small,
            foreground: isActive ? Color.green.opacity(0.95) : .secondary,
            background: isActive ? Color.green.opacity(0.13) : SeasonColors.subtleSurface
        )
    }

    @ViewBuilder
    private func basicHeroImage(for ingredient: BasicIngredient) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemGroupedBackground),
                            Color(.tertiarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(String(ingredient.displayName(languageCode: viewModel.localizer.languageCode).prefix(1)))
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)
                .offset(y: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 228)
        .overlay(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous))
    }

    private var validNutritionReference: String? {
        guard let produceItem,
              let rawReference = produceItem.nutritionReference else {
            return nil
        }

        let trimmedReference = rawReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            return nil
        }

        guard !trimmedReference.uppercased().contains("TODO") else {
            return nil
        }

        return trimmedReference
    }

}

private struct StylizedSeasonalityChart: View {
    let inSeasonMonths: [Int]
    let currentMonth: Int
    let languageCode: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(currentSeasonLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(currentSeasonLabelColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(currentSeasonLabelColor.opacity(0.12))
                    )
                Spacer()
            }

            GeometryReader { geometry in
                let curvePoints = chartCurvePoints(size: geometry.size)
                let currentMonthPosition = CGFloat(max(0, min(11, currentMonth - 1)))
                let currentPoint = pointForMonthPosition(currentMonthPosition, size: geometry.size)
                let midY = geometry.size.height / 2
                let chartCornerRadius = SeasonRadius.large

                ZStack {
                    RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous)
                        .fill(SeasonColors.subtleSurface.opacity(0.86))

                    Rectangle()
                        .fill(Color(red: 0.82, green: 0.95, blue: 0.86).opacity(0.18))
                        .frame(height: midY)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous))

                    Rectangle()
                        .fill(Color(red: 0.98, green: 0.86, blue: 0.84).opacity(0.13))
                        .frame(height: midY)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous))

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                    }
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Path { path in
                        path.move(to: CGPoint(x: currentPoint.x, y: 0))
                        path.addLine(to: CGPoint(x: currentPoint.x, y: geometry.size.height))
                    }
                    .stroke(Color(red: 0.18, green: 0.60, blue: 0.33).opacity(0.62), lineWidth: 1.2)

                    seasonCurve(points: curvePoints)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.73, blue: 0.34).opacity(0.95),
                                    Color(red: 0.98, green: 0.86, blue: 0.33).opacity(0.92),
                                    Color(red: 0.96, green: 0.62, blue: 0.30).opacity(0.92),
                                    Color(red: 0.89, green: 0.34, blue: 0.34).opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 3.1, lineCap: .round, lineJoin: .round)
                        )

                    Circle()
                        .fill(Color(red: 0.18, green: 0.62, blue: 0.32).opacity(0.92))
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.50), lineWidth: 1.0)
                        )
                        .shadow(color: Color(red: 0.18, green: 0.62, blue: 0.32).opacity(0.24), radius: 4, x: 0, y: 1)
                        .position(currentPoint)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: chartCornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.6)
                )
            }
            .frame(height: 150)

            HStack(spacing: 0) {
                ForEach(Array(monthSymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var monthValues: [CGFloat] {
        (1...12).map { month in
            let score = ProduceItem.seasonalityScore(for: inSeasonMonths, month: month)
            return CGFloat((score * 2.0) - 1.0)
        }
    }

    // This is a stylized seasonality line for readability.
    // Underlying data is month-level, expanded into a continuous 0...1 score.
    private func seasonCurve(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func chartCurvePoints(size: CGSize) -> [CGPoint] {
        let sampleCount = 280
        return (0...sampleCount).map { index in
            let monthPosition = CGFloat(index) / CGFloat(sampleCount) * 11
            return pointForMonthPosition(monthPosition, size: size)
        }
    }

    private func pointForMonthPosition(_ monthPosition: CGFloat, size: CGSize) -> CGPoint {
        let leftPadding: CGFloat = 10
        let rightPadding: CGFloat = 10
        let topPadding: CGFloat = 14
        let bottomPadding: CGFloat = 14
        let width = size.width - leftPadding - rightPadding
        let height = size.height - topPadding - bottomPadding
        let centerY = topPadding + (height / 2)
        let amplitude = height * 0.44

        let x = leftPadding + (monthPosition / 11) * width
        let y = centerY - (seasonalityValue(at: monthPosition) * amplitude)
        return CGPoint(x: x, y: y)
    }

    private func seasonalityValue(at monthPosition: CGFloat) -> CGFloat {
        let periodicSign = smoothedSign(at: monthPosition)
        let annualPhase = (2 * CGFloat.pi * monthPosition) / 12

        // Gentle modulation keeps the curve fluid (no flat plateaus)
        // while preserving positive/negative season meaning.
        let magnitude = 0.76
            + 0.12 * sin(annualPhase - (.pi / 3))
            + 0.03 * sin((annualPhase * 2) + (.pi / 5))
            + 0.015 * sin((annualPhase * 3) + 0.7)

        return periodicSign * magnitude
    }

    private func smoothedSign(at monthPosition: CGFloat) -> CGFloat {
        let farPrevious = interpolatedSign(at: monthPosition - 0.42)
        let previous = interpolatedSign(at: monthPosition - 0.21)
        let current = interpolatedSign(at: monthPosition)
        let next = interpolatedSign(at: monthPosition + 0.21)
        let farNext = interpolatedSign(at: monthPosition + 0.42)

        return (
            (0.12 * farPrevious) +
            (0.24 * previous) +
            (0.28 * current) +
            (0.24 * next) +
            (0.12 * farNext)
        )
    }

    private func interpolatedSign(at monthPosition: CGFloat) -> CGFloat {
        let wrapped = normalizedMonthPosition(monthPosition)
        let baseIndex = Int(floor(wrapped))
        let fractional = wrapped - CGFloat(baseIndex)
        let nextIndex = (baseIndex + 1) % 12

        let currentState = safeMonthValue(at: baseIndex)
        let nextState = safeMonthValue(at: nextIndex)

        // Cosine interpolation keeps transitions soft and continuous.
        let blend = (1 - cos(.pi * fractional)) / 2
        return (currentState * (1 - blend)) + (nextState * blend)
    }

    private func normalizedMonthPosition(_ monthPosition: CGFloat) -> CGFloat {
        let cycle: CGFloat = 12
        let wrapped = monthPosition.truncatingRemainder(dividingBy: cycle)
        return wrapped >= 0 ? wrapped : (wrapped + cycle)
    }

    private func safeMonthValue(at index: Int) -> CGFloat {
        let safeIndex = max(0, min(11, index))
        return monthValues[safeIndex]
    }

    private var monthSymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        let symbols = formatter.shortMonthSymbols ?? []
        let englishFallback = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        if symbols.count == 12 {
            return symbols
        } else if symbols.count > 12 {
            return Array(symbols.prefix(12))
        } else if !symbols.isEmpty {
            return symbols + englishFallback.dropFirst(symbols.count)
        } else {
            return englishFallback
        }
    }

    private var currentSeasonLabel: String {
        localizer.seasonalityPhaseTitle(currentSeasonPhase)
    }

    private var currentSeasonLabelColor: Color {
        switch currentSeasonPhase {
        case .inSeason:
            return Color(red: 0.17, green: 0.67, blue: 0.32)
        case .earlySeason:
            return Color(red: 0.31, green: 0.61, blue: 0.29)
        case .endingSoon:
            return Color(red: 0.84, green: 0.58, blue: 0.18)
        case .outOfSeason:
            return Color(red: 0.78, green: 0.42, blue: 0.34)
        }
    }

    private var currentSeasonPhase: SeasonalityPhase {
        ProduceItem.seasonalityPhase(score: currentSeasonalityScore, delta: currentSeasonalityDelta)
    }

    private var currentSeasonalityScore: Double {
        ProduceItem.seasonalityScore(for: inSeasonMonths, month: currentMonth)
    }

    private var currentSeasonalityDelta: Double {
        let previousMonth = currentMonth == 1 ? 12 : (currentMonth - 1)
        return currentSeasonalityScore
            - ProduceItem.seasonalityScore(for: inSeasonMonths, month: previousMonth)
    }

    private var localizer: AppLocalizer {
        AppLocalizer(languageCode: languageCode)
    }
}
