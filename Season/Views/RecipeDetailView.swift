import SwiftUI

struct RecipeDetailView: View {
    let rankedRecipe: RankedRecipe
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @State private var addIngredientsMessage = ""
    @State private var showingAddIngredientsAlert = false
    @State private var showingRemixComposer = false
    @State private var saveButtonPulse = false
    @State private var crispyButtonPulse = false
    @State private var addIngredientsPulse = false
    @State private var followButtonPulse = false
    @State private var hasTrackedView = false
    @State private var showingTimingExplanation = false
    @State private var selectedServings = 2
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: SeasonSpacing.sm) {
                    recipeHeroImage
                    identityAndMetaBlock

                    let confirmedDietaryTags = viewModel.confirmedDietaryTags(for: rankedRecipe.recipe)
                    if !confirmedDietaryTags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.localizer.text(.recipeDietaryTags))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(confirmedDietaryTags) { tag in
                                        RecipeDietaryTagPill(tag: tag, localizer: viewModel.localizer)
                                    }
                                }
                            }

                            Text(viewModel.localizer.text(.dietaryTagClassificationNote))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if rankedRecipe.recipe.isRemix,
                       let originalTitle = rankedRecipe.recipe.originalRecipeTitle {
                        VStack(alignment: .leading, spacing: 4) {
                            if let originalID = rankedRecipe.recipe.originalRecipeID,
                               let originalRanked = viewModel.rankedRecipe(forID: originalID) {
                                NavigationLink {
                                    RecipeDetailView(
                                        rankedRecipe: originalRanked,
                                        viewModel: viewModel,
                                        shoppingListViewModel: shoppingListViewModel
                                    )
                                } label: {
                                    Text(String(format: viewModel.localizer.text(.remixOfFormat), originalTitle))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(String(format: viewModel.localizer.text(.remixOfFormat), originalTitle))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        let remixCount = viewModel.remixCount(forOriginalRecipeID: rankedRecipe.recipe.id)
                        if remixCount > 0 {
                            Text(String(format: viewModel.localizer.text(.remixesCountFormat), remixCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            EmptyView()
                        }
                    }

                    Divider()

                    if hasPreparationInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.text(.preparation))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text(preparationSummaryLine)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    HStack {
                        Text(String(format: viewModel.localizer.text(.servesFormat), selectedServings))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Stepper("", value: $selectedServings, in: 1...12)
                            .labelsHidden()
                    }

                    if !rankedRecipe.recipe.externalMedia.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.text(.watchVideo))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(rankedRecipe.recipe.externalMedia, id: \.id) { media in
                                Button {
                                    guard let url = URL(string: media.url) else { return }
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: media.platform == .instagram ? "camera.circle.fill" : "play.tv.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)

                                        Text(mediaTitle(for: media))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Image(systemName: "arrow.up.right.square")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.localizer.text(.ingredients))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(ingredientRows, id: \.id) { ingredient in
                            HStack(spacing: 10) {
                                if let item = ingredient.item {
                                    ProduceThumbnailView(item: item, size: 30)
                                } else {
                                    Image(systemName: "leaf")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, height: 30)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color(.tertiarySystemGroupedBackground))
                                        )
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ingredient.name)
                                        .font(.body)
                                    Text(displayQuantityText(for: ingredient.recipeIngredient))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(ingredientStatusText(for: ingredient))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(hasIngredientInFridge(ingredient) ? .green : .secondary)
                            }
                        }
                    }

                    if let nutritionSummary = perServingNutritionSummary {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.text(.recipeNutritionSummaryTitle))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(String(format: viewModel.localizer.text(.recipeNutritionPerServingBasisFormat), baseServingsCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            nutritionRow(
                                title: viewModel.localizer.text(.calories),
                                value: "\(Int(nutritionSummary.calories.rounded()))"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.protein),
                                value: "\(formattedNumber(nutritionSummary.protein)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.carbs),
                                value: "\(formattedNumber(nutritionSummary.carbs)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.fat),
                                value: "\(formattedNumber(nutritionSummary.fat)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.fiber),
                                value: "\(formattedNumber(nutritionSummary.fiber)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.vitaminC),
                                value: "\(formattedNumber(nutritionSummary.vitaminC)) mg"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.potassium),
                                value: "\(formattedNumber(nutritionSummary.potassium)) mg"
                            )

                            if selectedServings != 1 {
                                Divider()
                                nutritionRow(
                                    title: "Total (\(selectedServings) servings)",
                                    value: "\(Int((nutritionSummary.calories * Double(selectedServings)).rounded())) kcal"
                                )
                            }

                            Text(viewModel.localizer.text(.recipeNutritionEstimatedNote))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(SeasonSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.localizer.text(.steps))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(rankedRecipe.recipe.preparationSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .leading)

                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            addIngredients()
                            pulse(.addIngredients)
                        } label: {
                            Text(viewModel.localizer.text(.addIngredients))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .scaleEffect(addIngredientsPulse ? 0.97 : 1.0)
                        .animation(.spring(response: 0.24, dampingFraction: 0.75), value: addIngredientsPulse)

                        Button {
                            showingRemixComposer = true
                        } label: {
                            Text(viewModel.localizer.text(.remixRecipe))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, SeasonSpacing.xs)
                .animation(.easeInOut(duration: 0.2), value: selectedServings)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in
                        if showingTimingExplanation {
                            withAnimation(.easeOut(duration: 0.16)) {
                                showingTimingExplanation = false
                            }
                        }
                    }
            )

            if showingTimingExplanation {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showingTimingExplanation = false
                        }
                    }
                    .zIndex(1)
            }
        }
        .background(Color(.systemGroupedBackground))
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
        .alert(addIngredientsMessage, isPresented: $showingAddIngredientsAlert) {
            Button("OK", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingRemixComposer) {
            CreateRecipeView(
                viewModel: viewModel,
                prefillDraft: CreateRecipeView.PrefillDraft(
                    title: rankedRecipe.recipe.title,
                    imageAssetName: rankedRecipe.recipe.coverImageName,
                    externalMedia: rankedRecipe.recipe.externalMedia,
                    images: rankedRecipe.recipe.images,
                    coverImageID: rankedRecipe.recipe.coverImageID,
                    mediaLinkURL: rankedRecipe.recipe.mediaLinkURL,
                    ingredients: rankedRecipe.recipe.ingredients,
                    steps: rankedRecipe.recipe.preparationSteps,
                    prepTimeMinutes: rankedRecipe.recipe.prepTimeMinutes,
                    cookTimeMinutes: rankedRecipe.recipe.cookTimeMinutes,
                    difficulty: rankedRecipe.recipe.difficulty,
                    servings: rankedRecipe.recipe.servings,
                    isRemix: true,
                    originalRecipeID: rankedRecipe.recipe.id,
                    originalRecipeTitle: rankedRecipe.recipe.title,
                    originalAuthorName: rankedRecipe.recipe.author
                )
            )
        }
        .onAppear {
            if !hasTrackedView {
                viewModel.registerRecipeView(rankedRecipe.recipe)
                hasTrackedView = true
            }
            selectedServings = max(1, rankedRecipe.recipe.servings)
        }
    }

    private var identityAndMetaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rankedRecipe.recipe.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if showsUserAuthorshipMetadata {
                HStack(alignment: .center, spacing: 10) {
                    if let author = trimmedAuthorName {
                        NavigationLink {
                            AuthorProfileView(
                                authorName: author,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        toggleFollowAuthor()
                        pulse(.follow)
                    } label: {
                        Text(isFollowingAuthor ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .scaleEffect(followButtonPulse ? 0.96 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: followButtonPulse)
                }
            } else if let seedAttributionLine {
                Text(seedAttributionLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                SeasonalStatusBadge(
                    score: rankedRecipe.seasonalityScore,
                    localizer: viewModel.localizer
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Timing")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showingTimingExplanation = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.recipeTimingTitle(for: rankedRecipe))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "info.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showingTimingExplanation {
                        timingTooltip
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }

                    Text("\(viewModel.localizer.text(.seasonalMatch)): \(rankedRecipe.seasonalMatchPercent)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Text(socialSignalText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        viewModel.toggleRecipeCrispy(rankedRecipe.recipe)
                        pulse(.crispy)
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.isRecipeCrispied(rankedRecipe.recipe) ? Color.orange : .secondary)
                            .frame(width: 28, height: 28)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        viewModel.isRecipeCrispied(rankedRecipe.recipe)
                                        ? Color.orange.opacity(0.16)
                                        : Color(.tertiarySystemGroupedBackground)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(crispyButtonPulse ? 0.94 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.68), value: crispyButtonPulse)
                    .accessibilityLabel(viewModel.localizer.text(.crispyAction))

                    Button {
                        viewModel.toggleSavedRecipe(rankedRecipe.recipe)
                        pulse(.save)
                    } label: {
                        Image(systemName: viewModel.isRecipeSaved(rankedRecipe.recipe) ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .scaleEffect(saveButtonPulse ? 0.94 : 1.0)
                    .animation(.spring(response: 0.24, dampingFraction: 0.7), value: saveButtonPulse)
                    .accessibilityLabel(
                        viewModel.isRecipeSaved(rankedRecipe.recipe)
                        ? viewModel.localizer.text(.saved)
                        : viewModel.localizer.text(.saveRecipe)
                    )
                }
            }
        }
        .padding(SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 0.5)
        )
    }

    private var socialSignalText: String {
        let crispyText = String(
            format: viewModel.localizer.text(.crispyCountFormat),
            viewModel.crispyCount(for: rankedRecipe.recipe)
        )
        let viewsCompact = viewModel.compactCountText(viewModel.viewCount(for: rankedRecipe.recipe))
        let viewsText = "\(viewsCompact) \(viewModel.localizer.text(.viewsLabel))"
        return "\(crispyText) · \(viewsText)"
    }

    private var showsUserAuthorshipMetadata: Bool {
        rankedRecipe.recipe.isUserGenerated || rankedRecipe.recipe.sourceType == .userGenerated
    }

    private var trimmedAuthorName: String? {
        guard showsUserAuthorshipMetadata else { return nil }
        let trimmed = rankedRecipe.recipe.author.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var seedAttributionLine: String? {
        guard !showsUserAuthorshipMetadata else { return nil }
        let attribution = rankedRecipe.recipe.attributionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let attribution, !attribution.isEmpty {
            return "via \(attribution)"
        }
        let source = rankedRecipe.recipe.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let source, !source.isEmpty {
            return "via \(source)"
        }
        return nil
    }

    private var followedAuthorsSet: Set<String> {
        Set(
            followedAuthorsRaw
                .split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private var isFollowingAuthor: Bool {
        followedAuthorsSet.contains(rankedRecipe.recipe.author)
    }

    private func toggleFollowAuthor() {
        var updated = followedAuthorsSet
        let author = rankedRecipe.recipe.author
        if updated.contains(author) {
            updated.remove(author)
        } else {
            updated.insert(author)
        }
        followedAuthorsRaw = updated.sorted().joined(separator: "|")
    }

    private var preparationSummaryLine: String {
        var parts: [String] = []
        let totalTime = (rankedRecipe.recipe.prepTimeMinutes ?? 0) + (rankedRecipe.recipe.cookTimeMinutes ?? 0)
        if totalTime > 0 {
            parts.append("\(totalTime) \(viewModel.localizer.text(.minutesShort))")
        } else if let prep = rankedRecipe.recipe.prepTimeMinutes {
            parts.append("\(prep) \(viewModel.localizer.text(.minutesShort))")
        } else if let cook = rankedRecipe.recipe.cookTimeMinutes {
            parts.append("\(cook) \(viewModel.localizer.text(.minutesShort))")
        }
        if let difficulty = rankedRecipe.recipe.difficulty {
            parts.append(viewModel.localizer.recipeDifficultyTitle(difficulty))
        }
        return parts.joined(separator: " · ")
    }

    private var baseServingsCount: Int {
        max(1, rankedRecipe.recipe.servings)
    }

    private var perServingNutritionSummary: RecipeNutritionSummary? {
        guard let total = viewModel.recipeNutritionSummary(for: rankedRecipe.recipe) else { return nil }
        let divisor = Double(baseServingsCount)
        return RecipeNutritionSummary(
            calories: total.calories / divisor,
            protein: total.protein / divisor,
            carbs: total.carbs / divisor,
            fat: total.fat / divisor,
            fiber: total.fiber / divisor,
            vitaminC: total.vitaminC / divisor,
            potassium: total.potassium / divisor
        )
    }

    private var timingExplanationText: String {
        switch viewModel.recipeTimingLabel(for: rankedRecipe) {
        case .perfectNow:
            return "This recipe is at its best seasonal moment right now."
        case .goodNow:
            return "This recipe is a good choice now, even if some ingredients are not at peak season."
        case .betterSoon:
            return "This recipe will become more seasonal in the coming weeks."
        case .endingSoon:
            return "This recipe is still good now, but some ingredients are moving out of season."
        }
    }

    private var timingTooltip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.recipeTimingTitle(for: rankedRecipe))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(timingExplanationText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: 230, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .zIndex(2)
    }

    private func hasIngredientInFridge(_ ingredient: IngredientRow) -> Bool {
        viewModel.isRecipeIngredientAvailable(
            ingredient.recipeIngredient,
            fridgeIngredientIDs: fridgeViewModel.allIngredientIDSet
        )
    }

    private func ingredientStatusText(for ingredient: IngredientRow) -> String {
        if hasIngredientInFridge(ingredient) {
            return viewModel.localizer.text(.youHave)
        }
        return "\(viewModel.localizer.text(.missing)) · \(displayQuantityText(for: ingredient.recipeIngredient))"
    }

    private var servingsScaleFactor: Double {
        Double(selectedServings) / Double(baseServingsCount)
    }

    private func isScalable(_ ingredient: RecipeIngredient) -> Bool {
        if ingredient.quantityValue <= 0 {
            return false
        }

        let raw = ingredient.rawIngredientLine?.lowercased() ?? ""
        if raw.contains("to taste") || raw.contains("as needed") || raw.contains("q.b.") || raw.contains("qb") {
            return false
        }
        return true
    }

    private func scaledQuantityValue(for ingredient: RecipeIngredient) -> Double {
        guard isScalable(ingredient) else { return ingredient.quantityValue }
        let scaled = ingredient.quantityValue * servingsScaleFactor
        return roundedScaledQuantity(scaled, unit: ingredient.quantityUnit)
    }

    private func roundedScaledQuantity(_ value: Double, unit: RecipeQuantityUnit) -> Double {
        switch unit {
        case .g, .ml:
            if value >= 10 { return value.rounded() }
            return (value * 10).rounded() / 10
        case .tbsp, .tsp, .cup:
            return (value * 4).rounded() / 4
        case .piece, .slice, .clove:
            return roundedToSupportedFractions(value)
        }
    }

    private func roundedToSupportedFractions(_ value: Double) -> Double {
        let whole = floor(value)
        let fractional = value - whole
        let supported: [Double] = [0.0, 0.25, 1.0 / 3.0, 0.5, 2.0 / 3.0, 0.75]
        let closest = supported.min(by: { abs($0 - fractional) < abs($1 - fractional) }) ?? 0
        let result = whole + closest
        return result <= 0 ? max(0.25, result) : result
    }

    private func displayQuantityText(for ingredient: RecipeIngredient) -> String {
        if !isScalable(ingredient),
           let raw = ingredient.rawIngredientLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return raw
        }

        let value = scaledQuantityValue(for: ingredient)
        let valueText: String
        switch ingredient.quantityUnit {
        case .piece, .clove, .slice:
            valueText = formattedFractionValue(value)
        case .g, .ml:
            valueText = value.rounded() == value ? "\(Int(value))" : formattedNumber(value)
        case .tbsp, .tsp, .cup:
            let rounded = value.rounded()
            if abs(value - rounded) < 0.001 {
                valueText = "\(Int(rounded))"
            } else {
                valueText = String(format: "%.2f", value)
                    .replacingOccurrences(of: #"(\.\d*?[1-9])0+$"#, with: "$1", options: .regularExpression)
                    .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
            }
        }
        return "\(valueText) \(viewModel.localizer.quantityUnitTitle(ingredient.quantityUnit))"
    }

    private func formattedFractionValue(_ value: Double) -> String {
        let whole = Int(floor(value))
        let fractional = value - Double(whole)

        let options: [(value: Double, symbol: String)] = [
            (0.25, "¼"),
            (1.0 / 3.0, "⅓"),
            (0.5, "½"),
            (2.0 / 3.0, "⅔"),
            (0.75, "¾")
        ]

        let best = options.min(by: { abs($0.value - fractional) < abs($1.value - fractional) })
        let fractionSymbol = (best != nil && abs((best?.value ?? 0) - fractional) <= 0.13) ? (best?.symbol ?? "") : ""

        if whole == 0 {
            return fractionSymbol.isEmpty ? "0" : fractionSymbol
        }
        return fractionSymbol.isEmpty ? "\(whole)" : "\(whole)\(fractionSymbol)"
    }

    private enum PulseTarget {
        case save
        case crispy
        case addIngredients
        case follow
    }

    private func pulse(_ target: PulseTarget) {
        switch target {
        case .save:
            saveButtonPulse = true
        case .crispy:
            crispyButtonPulse = true
        case .addIngredients:
            addIngredientsPulse = true
        case .follow:
            followButtonPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            switch target {
            case .save:
                saveButtonPulse = false
            case .crispy:
                crispyButtonPulse = false
            case .addIngredients:
                addIngredientsPulse = false
            case .follow:
                followButtonPulse = false
            }
        }
    }

    private var hasPreparationInfo: Bool {
        rankedRecipe.recipe.prepTimeMinutes != nil
        || rankedRecipe.recipe.cookTimeMinutes != nil
        || rankedRecipe.recipe.difficulty != nil
    }

    private var recipeHeroImage: some View {
        let galleryImages = orderedGalleryImages

        return Group {
            if galleryImages.count > 1 {
                TabView {
                    ForEach(galleryImages, id: \.id) { image in
                        recipeHeroPage(image)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            } else if let image = galleryImages.first {
                recipeHeroPage(image)
            } else {
                recipeHeroLegacyOrFallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 208)
    }

    private var orderedGalleryImages: [RecipeImage] {
        guard !rankedRecipe.recipe.images.isEmpty else { return [] }

        if let coverID = rankedRecipe.recipe.coverImageID,
           let coverIndex = rankedRecipe.recipe.images.firstIndex(where: { $0.id == coverID }) {
            var reordered = rankedRecipe.recipe.images
            let cover = reordered.remove(at: coverIndex)
            reordered.insert(cover, at: 0)
            return reordered
        }

        return rankedRecipe.recipe.images
    }

    @ViewBuilder
    private func recipeHeroPage(_ image: RecipeImage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let localImage = recipeUIImage(from: image) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let remoteURLString = image.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recipeHeroLegacyOrFallback: some View {
        let trimmedName = rankedRecipe.recipe.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasImage = !trimmedName.isEmpty && hasAsset(named: trimmedName)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if hasImage {
                Image(trimmedName)
                    .resizable()
                    .scaledToFit()
                    .padding(SeasonSpacing.md)
            } else {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ingredientRows: [IngredientRow] {
        rankedRecipe.recipe.ingredients.map { ingredient in
            let item = ingredient.produceID.flatMap { viewModel.produceItem(forID: $0) }
            let name = viewModel.recipeIngredientDisplayName(ingredient)
            return IngredientRow(
                id: ingredient.id,
                name: name,
                item: item,
                recipeIngredient: ingredient
            )
        }
    }

    @ViewBuilder
    private func nutritionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func addIngredients() {
        let resolvedIngredients = rankedRecipe.recipe.ingredients.map { ingredient in
            let scaledValue = scaledQuantityValue(for: ingredient)
            return RecipeIngredient(
                produceID: ingredient.produceID,
                basicIngredientID: ingredient.basicIngredientID,
                quality: ingredient.quality,
                name: viewModel.recipeIngredientDisplayName(ingredient),
                quantityValue: scaledValue,
                quantityUnit: ingredient.quantityUnit,
                rawIngredientLine: ingredient.rawIngredientLine,
                mappingConfidence: ingredient.mappingConfidence
            )
        }

        let result = shoppingListViewModel.addAllRecipeIngredients(
            resolvedIngredients,
            sourceRecipeID: rankedRecipe.recipe.id,
            sourceRecipeTitle: rankedRecipe.recipe.title,
            produceLookup: { produceID in
                viewModel.produceItem(forID: produceID)
            },
            basicLookup: { basicID in
                viewModel.basicIngredient(forID: basicID)
            }
        )
        addIngredientsMessage = viewModel.ingredientsAddFeedbackText(
            added: result.added,
            alreadyInList: result.alreadyInList
        )
        showingAddIngredientsAlert = true
    }

    private func mediaTitle(for media: RecipeExternalMedia) -> String {
        switch media.platform {
        case .instagram:
            return viewModel.localizer.text(.openOnInstagram)
        case .tiktok:
            return viewModel.localizer.text(.openOnTikTok)
        }
    }
}

private struct IngredientRow {
    let id: String
    let name: String
    let item: ProduceItem?
    let recipeIngredient: RecipeIngredient
}
