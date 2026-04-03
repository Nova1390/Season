import SwiftUI

struct IngredientDetailView: View {
    let ingredient: IngredientReference
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    private let localizer = AppLocalizer(
        languageCode: Locale.current.language.languageCode?.identifier.hasPrefix("it") == true ? "it" : "en"
    )
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @State private var fridgeButtonPulse = false
    @State private var shoppingButtonPulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                heroSection
                identitySection
                actionsBlock
                if let produce = resolvedProduceItem {
                    lightSeasonalitySection(for: produce)
                }
                relatedRecipesSection
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.sm)
            .padding(.bottom, SeasonSpacing.xl)
        }
        .background(SeasonColors.primarySurface)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .navigationTitle("Ingredient")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var heroSection: some View {
        if let produce = resolvedProduceItem {
            ProduceHeroImageView(item: produce, height: 284)
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

                        Text(displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(2)
                            .padding(.horizontal, SeasonSpacing.md)
                            .padding(.bottom, SeasonSpacing.md)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous))
        } else {
            IngredientVisualView(
                name: displayName,
                produceCategory: nil,
                basicCategory: resolvedBasicIngredient?.category,
                imageName: nil,
                cornerRadius: SeasonRadius.xl,
                imageContentMode: .fit,
                imagePaddingRatio: 0.08,
                iconScale: 0.24,
                showsNameInFallback: true
            )
                .frame(height: 284)
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

                        Text(displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(2)
                            .padding(.horizontal, SeasonSpacing.md)
                            .padding(.bottom, SeasonSpacing.md)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.xl, style: .continuous))
        }
    }

    private var identitySection: some View {
        HStack(alignment: .top, spacing: SeasonSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(.primary)

                Text(identitySubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: SeasonSpacing.sm)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var actionsBlock: some View {
        VStack(spacing: SeasonSpacing.xs) {
            Button {
                toggleFridgeState()
                pulseFridgeButton()
            } label: {
                primaryActionLabel(
                    text: isInFridge ? "In Fridge" : "Add to Fridge",
                    systemImage: isInFridge ? "snowflake" : "plus"
                )
            }
            .buttonStyle(PressableCardButtonStyle())
            .scaleEffect(fridgeButtonPulse ? SeasonMotion.pressScale : 1.0)
            .opacity(fridgeButtonPulse ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: fridgeButtonPulse)

            Button {
                toggleShoppingListState()
                pulseShoppingButton()
            } label: {
                secondaryActionLabel(
                    text: isInShoppingList ? "In List" : "Add to List",
                    systemImage: isInShoppingList ? "checkmark" : "plus",
                    foreground: isInShoppingList ? SeasonColors.seasonGreen.opacity(0.96) : .primary,
                    background: isInShoppingList ? SeasonColors.seasonGreenSoft.opacity(0.55) : SeasonColors.secondarySurface
                )
            }
            .buttonStyle(PressableCardButtonStyle())
            .scaleEffect(shoppingButtonPulse ? SeasonMotion.pressScale : 1.0)
            .opacity(shoppingButtonPulse ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: shoppingButtonPulse)
        }
        .padding(.top, 2)
    }

    private func primaryActionLabel(
        text: String,
        systemImage: String
    ) -> some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SeasonColors.seasonGreen, SeasonColors.seasonGreen.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private func secondaryActionLabel(
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
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
    }

    private var isInFridge: Bool {
        if let produce = resolvedProduceItem {
            return fridgeViewModel.contains(produce)
        }
        if let basic = resolvedBasicIngredient {
            return fridgeViewModel.contains(basic)
        }
        return fridgeViewModel.containsCustom(named: ingredient.name)
    }

    private var isInShoppingList: Bool {
        if let produce = resolvedProduceItem {
            return shoppingListViewModel.contains(produce)
        }
        if let basic = resolvedBasicIngredient {
            return shoppingListViewModel.contains(basic)
        }
        return shoppingListViewModel.containsCustom(named: ingredient.name)
    }

    private func toggleFridgeState() {
        withAnimation(.easeInOut(duration: 0.18)) {
            if let produce = resolvedProduceItem {
                if fridgeViewModel.contains(produce) {
                    fridgeViewModel.remove(produce)
                } else {
                    fridgeViewModel.add(produce)
                }
                return
            }
            if let basic = resolvedBasicIngredient {
                if fridgeViewModel.contains(basic) {
                    fridgeViewModel.remove(basic)
                } else {
                    fridgeViewModel.add(basic)
                }
                return
            }
            if fridgeViewModel.containsCustom(named: ingredient.name) {
                fridgeViewModel.removeCustom(named: ingredient.name)
            } else {
                fridgeViewModel.addCustom(name: ingredient.name)
            }
        }
    }

    private func toggleShoppingListState() {
        withAnimation(.easeInOut(duration: 0.18)) {
            if let produce = resolvedProduceItem {
                if shoppingListViewModel.contains(produce) {
                    shoppingListViewModel.remove(produce)
                } else {
                    shoppingListViewModel.add(produce)
                }
                return
            }
            if let basic = resolvedBasicIngredient {
                if shoppingListViewModel.contains(basic) {
                    shoppingListViewModel.remove(basic)
                } else {
                    shoppingListViewModel.add(basic)
                }
                return
            }
            if shoppingListViewModel.containsCustom(named: ingredient.name) {
                shoppingListViewModel.removeCustom(named: ingredient.name)
            } else {
                shoppingListViewModel.addCustom(name: ingredient.name, quantity: nil)
            }
        }
    }

    private func pulseFridgeButton() {
        fridgeButtonPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            fridgeButtonPulse = false
        }
    }

    private func pulseShoppingButton() {
        shoppingButtonPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            shoppingButtonPulse = false
        }
    }

    private func lightSeasonalitySection(for produce: ProduceItem) -> some View {
        SeasonCardContainer(
            content: {
                VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                    Text("Seasonality")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .center, spacing: 8) {
                        SeasonalStatusBadge(
                            score: produce.seasonalityScore(month: Calendar.current.component(.month, from: Date())),
                            delta: produce.seasonalityDelta(month: Calendar.current.component(.month, from: Date())),
                            localizer: localizer
                        )

                        Text(monthsText(for: produce))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(SeasonSpacing.md)
            },
            cornerRadius: SeasonRadius.large,
            background: Color(.systemBackground),
            backgroundOpacity: 0.84,
            borderOpacity: 0.01,
            shadowOpacity: 0.001,
            shadowRadius: 1.2,
            shadowY: 1
        )
    }

    @ViewBuilder
    private var relatedRecipesSection: some View {
        if !rankedRelatedRecipes.isEmpty {
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                HStack {
                    Text("What to cook with this")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(rankedRelatedRecipes.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let featured = rankedRelatedRecipes.first {
                    NavigationLink {
                        RecipeDetailView(
                            rankedRecipe: featured,
                            viewModel: viewModel,
                            shoppingListViewModel: shoppingListViewModel
                        )
                    } label: {
                        recipeHeroCard(featured.recipe)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }

                if rankedRelatedRecipes.count > 1 {
                    VStack(spacing: SeasonSpacing.xs) {
                        ForEach(Array(rankedRelatedRecipes.dropFirst()), id: \.recipe.id) { ranked in
                            NavigationLink {
                                RecipeDetailView(
                                    rankedRecipe: ranked,
                                    viewModel: viewModel,
                                    shoppingListViewModel: shoppingListViewModel
                                )
                            } label: {
                                recipeCompactCard(ranked.recipe)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableCardButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func recipeHeroCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RecipeThumbnailView(recipe: recipe, size: 280)
                .frame(maxWidth: .infinity)
                .frame(height: 172)
                .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous))

            Text(recipe.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            recipeMetaLine(recipe)
        }
        .padding(SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
                .fill(SeasonColors.secondarySurface.opacity(0.78))
        )
    }

    private func recipeCompactCard(_ recipe: Recipe) -> some View {
        HStack(spacing: SeasonSpacing.sm) {
            RecipeThumbnailView(recipe: recipe, size: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                recipeMetaLine(recipe)
            }
            Spacer(minLength: 0)
        }
        .padding(SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
    }

    @ViewBuilder
    private func recipeMetaLine(_ recipe: Recipe) -> some View {
        HStack(spacing: 8) {
            if let minutes = totalRecipeMinutes(for: recipe) {
                Label("\(minutes) min", systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if let difficulty = difficultyLabel(for: recipe) {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.55))
                Text(difficulty)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var typeLabel: String {
        switch ingredient.type {
        case .produce:
            return "produce"
        case .basic:
            return "basic"
        case .custom:
            return "custom"
        }
    }

    private var displayName: String {
        if let produce = resolvedProduceItem {
            return produce.displayName(languageCode: localizer.languageCode)
        }
        if let basic = resolvedBasicIngredient {
            return basic.displayName(languageCode: localizer.languageCode)
        }
        return ingredient.name
    }

    private var resolvedProduceItem: ProduceItem? {
        guard let produceID = ingredient.produceID,
              !produceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return ProduceStore.loadFromBundle().first { $0.id == produceID }
    }

    private var resolvedBasicIngredient: BasicIngredient? {
        guard ingredient.type == .basic else { return nil }
        if ingredient.id.hasPrefix("basic:") {
            let id = String(ingredient.id.dropFirst("basic:".count))
            if let found = BasicIngredientCatalog.all.first(where: { $0.id == id }) {
                return found
            }
        }
        let normalizedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return BasicIngredientCatalog.all.first {
            $0.displayName(languageCode: localizer.languageCode)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == normalizedName
        }
    }

    private var relatedRecipes: [Recipe] {
        let keyProduceID = resolvedProduceItem?.id
        let keyBasicID = resolvedBasicIngredient?.id
        let normalizedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return Array(
            RecipeStore.loadRecipes()
                .filter(\.isFeedEligible)
                .filter { recipe in
                    recipe.ingredients.contains { item in
                        if let keyProduceID, item.produceID == keyProduceID { return true }
                        if let keyBasicID, item.basicIngredientID == keyBasicID { return true }
                        return item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
                    }
                }
                .prefix(4)
        )
    }

    private var rankedRelatedRecipes: [RankedRecipe] {
        relatedRecipes.compactMap { viewModel.rankedRecipe(forID: $0.id) }
    }

    private func monthsText(for produce: ProduceItem) -> String {
        let formatter = DateFormatter()
        let shortNames = formatter.shortMonthSymbols ?? []
        let sortedMonths = produce.seasonMonths.filter { (1...12).contains($0) }.sorted()
        let labels = sortedMonths.compactMap { month -> String? in
            guard month - 1 < shortNames.count else { return nil }
            return shortNames[month - 1]
        }
        return labels.isEmpty ? "Seasonality unavailable" : labels.joined(separator: " · ")
    }

    private func totalRecipeMinutes(for recipe: Recipe) -> Int? {
        let prep = recipe.prepTimeMinutes ?? 0
        let cook = recipe.cookTimeMinutes ?? 0
        let total = prep + cook
        return total > 0 ? total : nil
    }

    private func difficultyLabel(for recipe: Recipe) -> String? {
        guard let difficulty = recipe.difficulty else { return nil }
        switch difficulty {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    private var identitySubtitle: String {
        if let produce = resolvedProduceItem {
            return localizer.categoryTitle(for: produce.category)
        }
        return typeLabel.capitalized
    }
}
