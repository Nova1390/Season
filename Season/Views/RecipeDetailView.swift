import SwiftUI
import Translation

struct RecipeDetailView: View {
    let rankedRecipe: RankedRecipe
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @ObservedObject private var followStore = FollowStore.shared
    @State private var addIngredientsMessage = ""
    @State private var showingAddIngredientsAlert = false
    @State private var showingRemixComposer = false
    @State private var saveButtonPulse = false
    @State private var crispyButtonPulse = false
    @State private var addIngredientsPulse = false
    @State private var hasTrackedView = false
    @State private var showingTimingExplanation = false
    @State private var selectedServings = 2
    @State private var translationResult: RecipeTranslationResult?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var hasAttemptedTranslation = false
    @State private var translationFailed = false
    @State private var hasLoggedCreatorEvaluation = false
    @State private var hasLoggedCreatorRowRender = false
    @State private var showingCreatorProfile = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: SeasonSpacing.xs) {
                    recipeHeroImage
                    identityAndMetaBlock
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    authorIdentityBlock

                    let confirmedDietaryTags = viewModel.confirmedDietaryTags(for: rankedRecipe.recipe)
                    if !confirmedDietaryTags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.localizer.text(.recipeDietaryTags))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(confirmedDietaryTags) { tag in
                                        dietaryTagChip(tag)
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
                                        brandIcon(for: media.platform)
                                            .frame(width: 20, height: 20)
                                            .frame(minWidth: 32, minHeight: 32)

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

                    if !recipeSocialLinks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.text(.watchVideo))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(recipeSocialLinks, id: \.platform) { link in
                                        Button {
                                            guard let url = URL(string: link.url) else { return }
                                            openURL(url)
                                        } label: {
                                            HStack(spacing: 8) {
                                                brandIcon(for: link.platform)
                                                    .frame(width: 16, height: 16)
                                                Text(link.label)
                                                    .font(SeasonTypography.subtitle)
                                            }
                                            .foregroundStyle(.primary)
                                            .seasonCapsuleChipStyle(
                                                horizontalPadding: 12,
                                                verticalPadding: 8,
                                                background: SeasonColors.mutedChipSurface
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
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
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.localizer.text(.ingredients))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(ingredientRows, id: \.id) { ingredient in
                            if let destination = ingredientDestination(for: ingredient) {
                                NavigationLink {
                                    ingredientDestinationView(destination)
                                } label: {
                                    ingredientRowContent(ingredient, isInteractive: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                ingredientRowContent(ingredient, isInteractive: false)
                            }
                        }
                    }

                    if let nutritionSummary = perServingNutritionSummary {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(viewModel.localizer.text(.recipeNutritionSummaryTitle))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.top, 4)
                            Text(String(format: viewModel.localizer.text(.recipeNutritionPerServingBasisFormat), baseServingsCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Divider()
                                .opacity(0.22)

                            VStack(alignment: .leading, spacing: 10) {
                                nutritionRow(
                                    title: viewModel.localizer.text(.calories),
                                    value: "\(Int(nutritionSummary.calories.rounded()))"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.protein),
                                    value: "\(formattedNumber(nutritionSummary.protein)) g"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.carbs),
                                    value: "\(formattedNumber(nutritionSummary.carbs)) g"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.fat),
                                    value: "\(formattedNumber(nutritionSummary.fat)) g"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.fiber),
                                    value: "\(formattedNumber(nutritionSummary.fiber)) g"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.vitaminC),
                                    value: "\(formattedNumber(nutritionSummary.vitaminC)) mg"
                                )
                                Divider().opacity(0.22)
                                nutritionRow(
                                    title: viewModel.localizer.text(.potassium),
                                    value: "\(formattedNumber(nutritionSummary.potassium)) mg"
                                )
                            }

                            if selectedServings != 1 {
                                Divider()
                                    .opacity(0.22)
                                nutritionRow(
                                    title: String(format: viewModel.localizer.text(.nutritionTotalForServingsFormat), selectedServings),
                                    value: "\(Int((nutritionSummary.calories * Double(selectedServings)).rounded())) kcal"
                                )
                            }

                            Text(viewModel.localizer.text(.recipeNutritionEstimatedNote))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        Text(viewModel.localizer.text(.steps))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(displayedPreparationSteps.enumerated()), id: \.offset) { index, step in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                Circle()
                                                    .fill(Color(.tertiarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.6)
                                            )

                                        Text(step)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    if index < displayedPreparationSteps.count - 1 {
                                        Divider()
                                            .padding(.leading, 40)
                                            .opacity(0.14)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            addIngredients()
                            pulse(.addIngredients)
                        } label: {
                            Label(viewModel.localizer.text(.addIngredients), systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .background(
                                    RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
                                        .fill(SeasonColors.secondarySurface)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(addIngredientsPulse ? 0.97 : 1.0)
                        .animation(.spring(response: 0.24, dampingFraction: 0.75), value: addIngredientsPulse)

                        Button {
                            showingRemixComposer = true
                        } label: {
                            Label(viewModel.localizer.text(.remixRecipe), systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .background(
                                    RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
                                        .fill(SeasonColors.secondarySurface.opacity(0.88))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
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
            Button(viewModel.localizer.text(.commonOK), role: .cancel) {}
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
                    instagramURL: rankedRecipe.recipe.instagramURL,
                    tiktokURL: rankedRecipe.recipe.tiktokURL,
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
                UserInteractionTracker.shared.track(
                    .recipeOpened,
                    recipeID: rankedRecipe.recipe.id,
                    creatorID: rankedRecipe.recipe.canonicalCreatorID
                )
                hasTrackedView = true
            }
            selectedServings = max(1, rankedRecipe.recipe.servings)
            hasAttemptedTranslation = false
            translationFailed = false
            translationResult = nil
            refreshTranslationConfiguration()
            if !hasLoggedCreatorEvaluation {
                logCreatorEvaluation()
                logDetailIdentity()
                hasLoggedCreatorEvaluation = true
            }
        }
        .translationTask(translationConfiguration) { session in
            await performRuntimeTranslation(using: session)
        }
        .navigationDestination(isPresented: $showingCreatorProfile) {
            AuthorProfileView(
                authorName: displayedCreatorName,
                creatorID: validRecipeCreatorID,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel,
                profileSocialLinks: creatorProfileLinks,
                profileAvatarURL: rankedRecipe.recipe.creatorAvatarURL
            )
        }
    }

    private var identityAndMetaBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SeasonalStatusBadge(
                    score: rankedRecipe.seasonalityScore,
                    localizer: viewModel.localizer
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showingTimingExplanation = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.recipeTimingTitle(for: rankedRecipe))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                }
            }

            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            crispyButton
                            viewsStatLabel
                        }
                        HStack(spacing: 10) {
                            crispyButton
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleSavedRecipe(rankedRecipe.recipe)
                        pulse(.save)
                    } label: {
                        Image(systemName: viewModel.isRecipeSaved(rankedRecipe.recipe) ? "bookmark.fill" : "bookmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(saveButtonPulse ? 0.94 : 1.0)
                    .animation(.spring(response: 0.24, dampingFraction: 0.7), value: saveButtonPulse)
                    .accessibilityLabel(
                        viewModel.isRecipeSaved(rankedRecipe.recipe)
                        ? viewModel.localizer.text(.saved)
                        : viewModel.localizer.text(.saveRecipe)
                    )

                    if showsUserAuthorshipMetadata {
                        followerStatLabel
                    }

                    if showsUserAuthorshipMetadata,
                       canShowFollowButton,
                       let creatorID = validRecipeCreatorID {
                        Button {
                            let stateBefore = followStore.isFollowing(creatorID)
                            toggleFollowAuthor()
                            let stateAfter = followStore.isFollowing(creatorID)
                            print("[SEASON_FOLLOW_RECIPE] phase=top_icon_tap recipe_id=\(rankedRecipe.recipe.id) creator_id=\(creatorID) state_before=\(stateBefore) state_after=\(stateAfter)")
                        } label: {
                            ZStack {
                                Color.clear
                                Image(systemName: isFollowingAuthor ? "person.fill.checkmark" : "person.badge.plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isFollowingAuthor ? .primary : .secondary)
                            }
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .zIndex(2)
                        .accessibilityLabel(isFollowingAuthor ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var recipeSocialLinks: [(platform: RecipeExternalPlatform, label: String, url: String)] {
        var links: [(RecipeExternalPlatform, String, String)] = []
        if let instagramURL = rankedRecipe.recipe.instagramURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instagramURL.isEmpty {
            links.append((.instagram, viewModel.localizer.commonInstagram, instagramURL))
        }
        if let tiktokURL = rankedRecipe.recipe.tiktokURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !tiktokURL.isEmpty {
            links.append((.tiktok, viewModel.localizer.commonTikTok, tiktokURL))
        }
        return links
    }

    @ViewBuilder
    private func brandIcon(for platform: RecipeExternalPlatform) -> some View {
        switch platform {
        case .instagram:
            Image("instagram_icon")
                .resizable()
                .scaledToFit()
        case .tiktok:
            Image("tiktok_icon")
                .resizable()
                .scaledToFit()
        }
    }

    private var showsUserAuthorshipMetadata: Bool {
        rankedRecipe.recipe.isUserGenerated || rankedRecipe.recipe.sourceType == .userGenerated
    }

    private var trimmedAuthorName: String? {
        guard showsUserAuthorshipMetadata else { return nil }
        let trimmed = rankedRecipe.recipe.displayCreatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var heroMetadataLine: String? {
        trimmedAuthorName
    }

    private var displayedCreatorName: String {
        rankedRecipe.recipe.displayCreatorName
    }

    private var authorIdentityBlock: some View {
        HStack(spacing: 10) {
            Button {
                print("[SEASON_FOLLOW_IDENTITY] phase=push_profile recipe_id=\(rankedRecipe.recipe.id) creator_id=\(validRecipeCreatorID ?? "nil") creator_name=\(displayedCreatorName)")
                showingCreatorProfile = true
            } label: {
                HStack(spacing: 10) {
                    AvatarView(
                        avatarURL: rankedRecipe.recipe.creatorAvatarURL,
                        size: 28,
                        creatorID: validRecipeCreatorID,
                        displayName: displayedCreatorName
                    )

                    Text(displayedCreatorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onAppear {
                guard !hasLoggedCreatorRowRender else { return }
                hasLoggedCreatorRowRender = true
                let rawCreatorID = rankedRecipe.recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
                let rawCreatorForLog = rawCreatorID.isEmpty ? "nil" : rawCreatorID
                let canonicalCreatorForLog = validRecipeCreatorID ?? "nil"
                print("[SEASON_RECIPE_CREATOR] phase=creator_row_rendered recipe_id=\(rankedRecipe.recipe.id) display_name=\(displayedCreatorName) raw_creator_id=\(rawCreatorForLog) canonical_creator_id=\(canonicalCreatorForLog)")
            }

            Spacer()
        }
    }

    private var heroTitleText: String {
        displayedRecipeTitle
    }

    private var followerCountValue: Int {
        followerCount(for: validRecipeCreatorID, fallbackName: displayedCreatorName)
    }

    private var crispyButton: some View {
        Button {
            viewModel.toggleRecipeCrispy(rankedRecipe.recipe)
            pulse(.crispy)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        viewModel.isRecipeCrispied(rankedRecipe.recipe)
                        ? Color.orange
                        : .secondary
                    )
                    .frame(width: 12, alignment: .center)
                Text(
                    "\(viewModel.crispyCount(for: rankedRecipe.recipe).compactFormatted()) \(viewModel.localizer.text(.crispyAction).lowercased())"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    viewModel.isRecipeCrispied(rankedRecipe.recipe)
                    ? Color.orange
                    : .primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(crispyButtonPulse ? 0.96 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: crispyButtonPulse)
        .accessibilityLabel(viewModel.localizer.text(.crispyAction))
    }

    private var viewsStatLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(viewModel.compactCountText(viewModel.viewCount(for: rankedRecipe.recipe))) \(viewModel.localizer.text(.viewsLabel))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
    }

    private var followerStatLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2")
                .font(.caption2.weight(.semibold))
            Text(formattedFollowerCount(followerCountValue))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
        .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func dietaryTagChip(_ tag: RecipeDietaryTag) -> some View {
        SeasonBadge(
            text: viewModel.localizer.dietaryTagTitle(tag),
            icon: dietaryTagIconName(tag),
            horizontalPadding: 8,
            verticalPadding: 5,
            cornerRadius: SeasonRadius.small,
            foreground: .secondary,
            background: SeasonColors.subtleSurface
        )
    }

    private func dietaryTagIconName(_ tag: RecipeDietaryTag) -> String {
        switch tag {
        case .glutenFree:
            return "checkmark.seal"
        case .vegetarian:
            return "leaf"
        case .vegan:
            return "leaf.fill"
        }
    }

    private var validRecipeCreatorID: String? {
        // Follow/profile identity must use canonical creator id, never the legacy author string.
        rankedRecipe.recipe.canonicalCreatorID
    }

    private var currentCreatorID: String {
        CurrentUser.shared.creator.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canShowFollowButton: Bool {
        guard let recipeCreatorID = validRecipeCreatorID else { return false }
        return recipeCreatorID != currentCreatorID
    }

    private var isFollowingAuthor: Bool {
        guard let recipeCreatorID = validRecipeCreatorID else { return false }
        return followStore.isFollowing(recipeCreatorID)
    }

    private func toggleFollowAuthor() {
        guard let recipeCreatorID = validRecipeCreatorID, canShowFollowButton else {
            let rawCreatorID = rankedRecipe.recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawCreatorForLog = rawCreatorID.isEmpty ? "nil" : rawCreatorID
            print("[SEASON_FOLLOW_IDENTITY] phase=button_tap_blocked_invalid_creator recipe_id=\(rankedRecipe.recipe.id) raw_creator_id=\(rawCreatorForLog) canonical_creator_id=\(validRecipeCreatorID ?? "nil")")
            return
        }
        let wasFollowing = followStore.isFollowing(recipeCreatorID)
        print("[SEASON_FOLLOW_IDENTITY] phase=recipe_toggle recipe_id=\(rankedRecipe.recipe.id) creator_id=\(recipeCreatorID) creator_name=\(displayedCreatorName) was_following=\(wasFollowing)")
        followStore.toggleFollow(recipeCreatorID)
    }

    private var creatorProfileLinks: [AuthorProfileView.CreatorSocialLink] {
        var links: [AuthorProfileView.CreatorSocialLink] = []

        let trimmedInstagram = rankedRecipe.recipe.instagramURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedInstagram.isEmpty {
            links.append(.init(platform: .instagram, url: trimmedInstagram))
        }

        let trimmedTikTok = rankedRecipe.recipe.tiktokURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTikTok.isEmpty {
            links.append(.init(platform: .tiktok, url: trimmedTikTok))
        }

        return links
    }

    private func logCreatorEvaluation() {
        let rawCreatorID = rankedRecipe.recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawCreatorForLog = rawCreatorID.isEmpty ? "nil" : rawCreatorID
        let canonicalCreatorForLog = validRecipeCreatorID ?? "nil"
        let creatorDisplay = displayedCreatorName
        let currentID = CurrentUser.shared.creator.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canShow = canShowFollowButton
        let backendSyncEligible = validRecipeCreatorID.map { FollowSyncManager.isBackendSyncableCreatorID($0) } ?? false

        print("[SEASON_FOLLOW_IDENTITY] phase=identity_eval recipe_id=\(rankedRecipe.recipe.id) raw_creator_id=\(rawCreatorForLog) canonical_creator_id=\(canonicalCreatorForLog) displayed_creator_name=\(creatorDisplay) current_creator_id=\(currentID) can_show_follow=\(canShow)")
        print("[SEASON_FOLLOW_SYNC] phase=creator_sync_eligibility recipe_id=\(rankedRecipe.recipe.id) creator_id=\(canonicalCreatorForLog) eligible=\(backendSyncEligible)")
        if let validRecipeCreatorID {
            print("[SEASON_FOLLOW_IDENTITY] phase=canonical_id_resolved recipe_id=\(rankedRecipe.recipe.id) creator_id=\(validRecipeCreatorID)")
            if canShow {
                print("[SEASON_RECIPE_CREATOR] phase=follow_visible recipe_id=\(rankedRecipe.recipe.id) creator_id=\(validRecipeCreatorID)")
            }
        } else if !rawCreatorID.isEmpty {
            print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(rawCreatorID)")
            if rawCreatorID.range(of: "^[A-Za-z0-9_\\-.]+$", options: .regularExpression) != nil &&
                !rawCreatorID.contains("-") {
                print("[SEASON_FOLLOW_IDENTITY] phase=legacy_name_rejected value=\(rawCreatorID)")
            }
            print("[SEASON_RECIPE_CREATOR] phase=follow_hidden_invalid_creator recipe_id=\(rankedRecipe.recipe.id) raw_creator_id=\(rawCreatorForLog)")
        }

        switch rankedRecipe.recipe.creatorIdentityState {
        case .canonicalUUID:
            break
        case .legacyUnmigrated(let rawLegacyID):
            print("[SEASON_RECIPE_CREATOR] phase=legacy_recipe_identity_detected recipe_id=\(rankedRecipe.recipe.id) raw_creator_id=\(rawLegacyID) display_name=\(displayedCreatorName)")
        case .unknown:
            if !rankedRecipe.recipe.hasDisplayableCreatorIdentity {
                print("[SEASON_RECIPE_CREATOR] phase=follow_hidden_invalid_creator recipe_id=\(rankedRecipe.recipe.id) raw_creator_id=nil")
            }
        }
    }

    private func logDetailIdentity() {
        let rawCreatorID = rankedRecipe.recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawCreatorForLog = rawCreatorID.isEmpty ? "nil" : rawCreatorID
        let canonicalCreatorIDForLog = rankedRecipe.recipe.canonicalCreatorID ?? "nil"
        let creatorDisplayForLog = rankedRecipe.recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
        let currentID = CurrentUser.shared.creator.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canShow = canShowFollowButton

        print("[SEASON_CREATOR_CHAIN] phase=detail_identity recipe_id=\(rankedRecipe.recipe.id) creator_id=\(rawCreatorForLog) canonical_creator_id=\(canonicalCreatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(rankedRecipe.recipe.author) current_creator_id=\(currentID) can_show_follow=\(canShow)")

        if showsUserAuthorshipMetadata && rankedRecipe.recipe.canonicalCreatorID == nil {
            print("[SEASON_CREATOR_CHAIN] phase=missing_canonical_creator_id_in_detail recipe_id=\(rankedRecipe.recipe.id) title=\(rankedRecipe.recipe.title) creator_display_name=\(creatorDisplayForLog) author=\(rankedRecipe.recipe.author)")
        }
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
            return viewModel.localizer.text(.recipeTimingExplainPerfectNow)
        case .goodNow:
            return viewModel.localizer.text(.recipeTimingExplainGoodNow)
        case .betterSoon:
            return viewModel.localizer.text(.recipeTimingExplainBetterSoon)
        case .endingSoon:
            return viewModel.localizer.text(.recipeTimingExplainEndingSoon)
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
        let quantityText = displayQuantityText(for: ingredient.recipeIngredient)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quantityText.isEmpty else {
            return viewModel.localizer.text(.missing)
        }
        return "\(viewModel.localizer.text(.missing)) · \(quantityText)"
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
        if shouldHideSyntheticFallbackQuantity(for: ingredient) {
            return ""
        }

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

    private func shouldHideSyntheticFallbackQuantity(for ingredient: RecipeIngredient) -> Bool {
        guard ingredient.produceID == nil, ingredient.basicIngredientID == nil else { return false }
        guard ingredient.quantityUnit == .piece else { return false }
        guard abs(ingredient.quantityValue - 1) < 0.001 else { return false }

        let raw = ingredient.rawIngredientLine?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return false }
        guard !raw.hasSuffix(":") else { return false }

        if raw.range(of: #"(?i)\bquanto basta\b|\bq\s*\.?\s*b\s*\.?\b|\bqb\b"#, options: .regularExpression) != nil {
            return true
        }

        if raw.range(of: #"^\d+\s+[^\d].+$"#, options: .regularExpression) != nil,
           raw.range(of: #"(?i)^\d+\s*(g|kg|ml|l)\b"#, options: .regularExpression) == nil {
            return true
        }

        return raw.split(whereSeparator: { $0.isWhitespace }).count > 1
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
        case crispy
        case save
        case addIngredients
    }

    private func pulse(_ target: PulseTarget) {
        switch target {
        case .crispy:
            crispyButtonPulse = true
        case .save:
            saveButtonPulse = true
        case .addIngredients:
            addIngredientsPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            switch target {
            case .crispy:
                crispyButtonPulse = false
            case .save:
                saveButtonPulse = false
            case .addIngredients:
                addIngredientsPulse = false
            }
        }
    }

    private var hasPreparationInfo: Bool {
        rankedRecipe.recipe.prepTimeMinutes != nil
        || rankedRecipe.recipe.cookTimeMinutes != nil
        || rankedRecipe.recipe.difficulty != nil
    }

    private var recipeHeroImage: some View {
        RecipeHeroView(
            galleryImages: orderedGalleryImages,
            legacyCoverImageName: rankedRecipe.recipe.coverImageName,
            remoteImageURLString: rankedRecipe.recipe.imageURL,
            title: heroTitleText,
            metadataLine: heroMetadataLine
        )
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

    private var baseRecipeTitle: String {
        let originalTitle = rankedRecipe.recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !originalTitle.isEmpty {
            return originalTitle
        }
        assertionFailure("[SEASON_RECIPE] Base recipe title unexpectedly empty for recipe id=\(rankedRecipe.recipe.id)")
        return "Recipe"
    }

    private var displayedRecipeTitle: String {
        let translatedTitle = translationResult?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let translatedTitle, !translatedTitle.isEmpty {
            return translatedTitle
        }
        return baseRecipeTitle
    }

    private var displayedPreparationSteps: [String] {
        translationResult?.steps ?? rankedRecipe.recipe.preparationSteps
    }

    private func displayIngredientName(for ingredient: IngredientRow) -> String {
        guard ingredient.recipeIngredient.produceID == nil,
              ingredient.recipeIngredient.basicIngredientID == nil else {
            return ingredient.name
        }
        let originalName = ingredient.recipeIngredient.name
        return translationResult?.freeTextIngredientNames[originalName] ?? ingredient.name
    }

    private func refreshTranslationConfiguration() {
        guard !hasAttemptedTranslation, !translationFailed, translationResult == nil else {
            return
        }

        if #available(iOS 18.0, *) {
            Task {
                let config = await RecipeTranslationService.shared.configuration(
                    for: rankedRecipe.recipe,
                    targetLanguageCode: viewModel.languageCode
                )
                await MainActor.run {
                    translationConfiguration = config
                    if config == nil {
                        translationResult = nil
                    }
                }
            }
        } else {
            translationConfiguration = nil
            translationResult = nil
        }
    }

    @MainActor
    @available(iOS 18.0, *)
    private func performRuntimeTranslation(using session: TranslationSession) async {
        guard !hasAttemptedTranslation, !translationFailed, translationResult == nil else {
            return
        }

        hasAttemptedTranslation = true

        do {
            let translated = try await RecipeTranslationService.shared.translate(
                recipe: rankedRecipe.recipe,
                targetLanguageCode: viewModel.languageCode,
                session: session
            )
            translationResult = translated
        } catch {
            translationFailed = true
            print("[SEASON_TRANSLATION] phase=failed error=\(error)")
        }
    }

    private var ingredientRows: [IngredientRow] {
        rankedRecipe.recipe.ingredients.map { ingredient in
            let item = ingredient.produceID.flatMap { viewModel.produceItem(forID: $0) }
            let basic = ingredient.basicIngredientID.flatMap { viewModel.basicIngredient(forID: $0) }
            let name = viewModel.recipeIngredientDisplayName(ingredient)
            return IngredientRow(
                id: ingredient.id,
                name: name,
                item: item,
                basic: basic,
                recipeIngredient: ingredient
            )
        }
    }

    @ViewBuilder
    private func ingredientRowContent(_ ingredient: IngredientRow, isInteractive: Bool) -> some View {
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
                Text(displayIngredientName(for: ingredient))
                    .font(.body)
                let quantityText = displayQuantityText(for: ingredient.recipeIngredient)
                if !quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(quantityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            } else {
                Text(ingredientStatusText(for: ingredient))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasIngredientInFridge(ingredient) ? .green : .secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private enum IngredientDestination {
        case produce(ProduceItem)
        case ingredient(IngredientReference)
    }

    private func ingredientDestination(for ingredient: IngredientRow) -> IngredientDestination? {
        if let item = ingredient.item {
            return .produce(item)
        }
        return .ingredient(ingredient.recipeIngredient.ingredientReference)
    }

    @ViewBuilder
    private func ingredientDestinationView(_ destination: IngredientDestination) -> some View {
        switch destination {
        case .produce(let item):
            ProduceDetailView(
                item: item,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        case .ingredient(let ingredient):
            IngredientDetailView(ingredient: ingredient)
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
        UserInteractionTracker.shared.track(
            .recipeAddedToList,
            recipeID: rankedRecipe.recipe.id,
            creatorID: rankedRecipe.recipe.canonicalCreatorID,
            metadata: [
                "addedCount": "\(result.added)",
                "alreadyInListCount": "\(result.alreadyInList)"
            ]
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
    let basic: BasicIngredient?
    let recipeIngredient: RecipeIngredient
}

private struct RecipeHeroView: View {
    let galleryImages: [RecipeImage]
    let legacyCoverImageName: String?
    let remoteImageURLString: String?
    let title: String
    let metadataLine: String?

    var body: some View {
        imageLayer
            .frame(maxWidth: .infinity)
            .frame(height: 208)
            .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.9), location: 0.0),
                        .init(color: Color.black.opacity(0.72), location: 0.26),
                        .init(color: Color.black.opacity(0.42), location: 0.52),
                        .init(color: Color.black.opacity(0.14), location: 0.78),
                        .init(color: Color.black.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(safeTitle)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)

                    if let line = trimmedMetadataLine {
                        Text(line)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.32), radius: 1, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
                .padding(.top, 12)
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let remoteImageURL = trimmedRemoteImageURL,
           let url = URL(string: remoteImageURL) {
            RemoteImageView(
                url: url,
                fallbackAssetName: trimmedLegacyCoverImageName
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else if galleryImages.count > 1 {
            TabView {
                ForEach(galleryImages, id: \.id) { image in
                    resolvedImageView(for: image)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        } else if let galleryImage = galleryImages.first {
            resolvedImageView(for: galleryImage)
        } else if let legacyName = trimmedLegacyCoverImageName {
            Image(legacyName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            fallbackImageView
        }
    }

    @ViewBuilder
    private func resolvedImageView(for image: RecipeImage) -> some View {
        if let localImage = recipeUIImage(from: image) {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let remoteURLString = image.remoteURL,
                  let remoteURL = URL(string: remoteURLString) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    fallbackImageView
                }
            }
        } else {
            fallbackImageView
        }
    }

    private var fallbackImageView: some View {
        Image(systemName: "fork.knife.circle.fill")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.secondary)
            .clipped()
    }

    private var trimmedLegacyCoverImageName: String? {
        let trimmed = legacyCoverImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, hasAsset(named: trimmed) else { return nil }
        return trimmed
    }

    private var trimmedRemoteImageURL: String? {
        let trimmed = remoteImageURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedMetadataLine: String? {
        let trimmed = metadataLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var safeTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Recipe" : cleaned
    }
}
