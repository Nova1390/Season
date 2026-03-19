import SwiftUI

struct RecipeDetailView: View {
    let rankedRecipe: RankedRecipe
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    let isFollowingAuthor: Bool
    let onToggleFollow: () -> Void
    @State private var addIngredientsMessage = ""
    @State private var showingAddIngredientsAlert = false
    @State private var showingRemixComposer = false
    @State private var saveButtonPulse = false
    @State private var crispyButtonPulse = false
    @State private var addIngredientsPulse = false
    @State private var followButtonPulse = false
    @State private var hasTrackedView = false
    @State private var showingTimingExplanation = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            ScrollView {
            VStack(spacing: SeasonSpacing.sm) {
                recipeHeroImage

                VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                    Text(rankedRecipe.recipe.title)
                        .font(.title3.weight(.semibold))

                    HStack {
                        NavigationLink {
                            AuthorProfileView(
                                authorName: rankedRecipe.recipe.author,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            Text(rankedRecipe.recipe.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            onToggleFollow()
                            pulse(.follow)
                        } label: {
                            Text(isFollowingAuthor ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .scaleEffect(followButtonPulse ? 0.96 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: followButtonPulse)

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

                    HStack {
                        Text(socialSignalText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()
                    }

                }

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
                                    shoppingListViewModel: shoppingListViewModel,
                                    isFollowingAuthor: false,
                                    onToggleFollow: {}
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
                                Text(ingredient.quantity)
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

                if let nutritionSummary = viewModel.recipeNutritionSummary(for: rankedRecipe.recipe) {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.localizer.text(.recipeNutritionSummaryTitle))
                            .font(.subheadline.weight(.semibold))
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
        .navigationTitle(rankedRecipe.recipe.title)
        .navigationBarTitleDisplayMode(.inline)
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
        }
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
        guard let item = ingredient.item else { return false }
        return fridgeViewModel.contains(item)
    }

    private func ingredientStatusText(for ingredient: IngredientRow) -> String {
        hasIngredientInFridge(ingredient)
        ? viewModel.localizer.text(.youHave)
        : viewModel.localizer.text(.missing)
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let remoteURLString = image.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
                quantity: ingredient.quantity,
                item: item
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
            RecipeIngredient(
                produceID: ingredient.produceID,
                basicIngredientID: ingredient.basicIngredientID,
                quality: ingredient.quality,
                name: viewModel.recipeIngredientDisplayName(ingredient),
                quantityValue: ingredient.quantityValue,
                quantityUnit: ingredient.quantityUnit
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
    let quantity: String
    let item: ProduceItem?
}
