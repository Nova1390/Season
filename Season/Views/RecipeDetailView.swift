import SwiftUI
import Translation

struct RecipeDetailView: View {
    let rankedRecipe: RankedRecipe
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
    @ObservedObject private var followStore = FollowStore.shared
    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @State private var addIngredientsMessage = ""
    @State private var showingAddIngredientsAlert = false
    @State private var showingRemixComposer = false
    @State private var saveButtonPulse = false
    @State private var crispyButtonPulse = false
    @State private var addIngredientsPulse = false
    @State private var hasTrackedView = false
    @State private var selectedServings = 2
    @State private var translationResult: RecipeTranslationResult?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var hasAttemptedTranslation = false
    @State private var translationFailed = false
    @State private var hasLoggedCreatorEvaluation = false
    @State private var hasLoggedCreatorRowRender = false
    @State private var showingCreatorProfile = false
    @State private var showingShoppingList = false
    @State private var emphasizeStepsSection = false
    @State private var hasLoggedLayoutContract = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: SeasonSpacing.lg) {
                        recipeHeroImage

                        titleAndMetadataBlock

                        CreatorBarView(
                            creatorName: displayedCreatorName,
                            creatorSubtitle: creatorSubtitleText,
                            followerCountText: creatorFollowerCountText,
                            avatarURL: rankedRecipe.recipe.creatorAvatarURL,
                            creatorID: validRecipeCreatorID,
                            isFollowing: isFollowingAuthor,
                            followLabel: viewModel.localizer.localized("recipe.detail.follow"),
                            followingLabel: viewModel.localizer.localized("recipe.detail.following"),
                            canShowFollowButton: canShowFollowButton,
                            onCreatorTap: {
                                guard showsUserAuthorshipMetadata else { return }
                                print("[SEASON_FOLLOW_IDENTITY] phase=push_profile recipe_id=\(rankedRecipe.recipe.id) creator_id=\(validRecipeCreatorID ?? "nil") creator_name=\(displayedCreatorName)")
                                showingCreatorProfile = true
                            },
                            onFollowTap: {
                                if let creatorID = validRecipeCreatorID {
                                    let stateBefore = followStore.isFollowing(creatorID)
                                    toggleFollowAuthor()
                                    let stateAfter = followStore.isFollowing(creatorID)
                                    print("[SEASON_FOLLOW_RECIPE] phase=top_icon_tap recipe_id=\(rankedRecipe.recipe.id) creator_id=\(creatorID) state_before=\(stateBefore) state_after=\(stateAfter)")
                                }
                            }
                        )

                        identityAndMetaBlock

                        RecipeIntelligenceCard(
                            fridgeMatchText: "\(availableIngredientCount)/\(ingredientRows.count) ingredients",
                            fridgeDetailText: untreatedMissingIngredientCount == 0
                                ? viewModel.localizer.text(.recipeDetailAllMissingHandled)
                                : String(format: viewModel.localizer.text(.recipeDetailStillMissingItemsFormat), untreatedMissingIngredientCount),
                            seasonalTitle: viewModel.recipeTimingTitle(for: rankedRecipe),
                            seasonalDetail: "\(viewModel.localizer.text(.seasonalMatch)): \(rankedRecipe.seasonalMatchPercent)%",
                            readinessTitle: readinessTitle,
                            readinessDetail: readinessDetail,
                            isReadyToCook: isReadyToCook,
                            statusLabel: viewModel.localizer.localized("recipe.detail.status"),
                            fridgeLabel: viewModel.localizer.localized("recipe.detail.fridge"),
                            seasonLabel: viewModel.localizer.localized("recipe.detail.season")
                        )

                        WhyThisRecipeView(
                            reasons: whyThisRecipeReasons,
                            title: viewModel.localizer.localized("recipe.detail.why_this_recipe")
                        )

                        SmartCTAButton(
                            title: primaryCTATitle,
                            subtitle: primaryCTASubtitle,
                            icon: primaryCTAIcon,
                            style: .primary
                        ) {
                            handlePrimaryCTA(scrollProxy: proxy)
                        }
                        .padding(.top, 2)

                        let confirmedDietaryTags = viewModel.confirmedDietaryTags(for: rankedRecipe.recipe)
                        if !confirmedDietaryTags.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(viewModel.localizer.text(.recipeDietaryTags))
                                    .font(.caption.weight(.semibold))
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
                                    .foregroundStyle(.secondary.opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if hasPreparationInfo {
                            RecipeMetaRow(
                                label: viewModel.localizer.text(.preparation),
                                value: preparationSummaryLine
                            )
                        }

                        HStack {
                            Text(String(format: viewModel.localizer.text(.servesFormat), selectedServings))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Stepper("", value: $selectedServings, in: 1...12)
                                .labelsHidden()
                        }

                        ingredientSummaryRow

                        IngredientsListView(
                            title: nil,
                            ingredients: sortedIngredientRows,
                            displayName: { displayIngredientName(for: $0) },
                            quantityText: { displayQuantityText(for: $0.recipeIngredient) },
                            statusText: { ingredientStatusText(for: $0) },
                            availabilityText: { ingredientAvailabilityLabel(for: $0) },
                            availabilityState: { ingredientAvailability(for: $0) },
                            hasInFridge: { hasIngredientInFridge($0) },
                            destinationFor: { ingredientDestination(for: $0) },
                            destinationView: { AnyView(ingredientDestinationView($0)) }
                        )
                        .id("recipe_ingredients_section")

                        if let nutritionSummary = perServingNutritionSummary {
                            nutritionSection(summary: nutritionSummary)
                        }

                        MethodSectionView(
                            title: viewModel.localizer.text(.steps),
                            steps: displayedPreparationSteps,
                            highlight: emphasizeStepsSection
                        )
                        .id("recipe_steps_section")

                        mediaAndSourceSection

                        remixSection
                    }
                    .padding(.horizontal)
                    .padding(.top, SeasonSpacing.sm)
                    .padding(.bottom, SeasonLayout.bottomBarContentClearance + SeasonSpacing.sm)
                    .animation(.easeInOut(duration: 0.2), value: selectedServings)
                }
            }
        }
        .background(SeasonColors.primarySurface)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(SeasonColors.primarySurface, for: .navigationBar)
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
            #if DEBUG
            if !hasLoggedLayoutContract {
                debugLogLayoutContract()
                hasLoggedLayoutContract = true
            }
            #endif
            selectedServings = max(1, rankedRecipe.recipe.servings)
            resetTranslationStateAndRefresh()
            if !hasLoggedCreatorEvaluation {
                logCreatorEvaluation()
                logDetailIdentity()
                hasLoggedCreatorEvaluation = true
            }
        }
        .onChange(of: effectiveTranslationTargetLanguageCode) { _, _ in
            resetTranslationStateAndRefresh()
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
        .navigationDestination(isPresented: $showingShoppingList) {
            ShoppingListView(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    private var identityAndMetaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .scaleEffect(saveButtonPulse ? SeasonMotion.pressScale : 1.0)
                    .opacity(saveButtonPulse ? SeasonMotion.pressOpacity : 1.0)
                    .animation(SeasonMotion.pressAnimation, value: saveButtonPulse)
                    .accessibilityLabel(
                        viewModel.isRecipeSaved(rankedRecipe.recipe)
                        ? viewModel.localizer.text(.saved)
                        : viewModel.localizer.text(.saveRecipe)
                    )

                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var titleAndMetadataBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayedRecipeTitle)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                if let metadata = heroMetadataLine {
                    Label(metadata, systemImage: "person")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let totalTime = totalRecipeMinutes, totalTime > 0 {
                    Label(
                        String(
                            format: viewModel.localizer.localized("home.time.minutes_compact_format"),
                            totalTime
                        ),
                        systemImage: "clock"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
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

    private var isCuratedImportedRecipe: Bool {
        rankedRecipe.recipe.sourceType == .curatedImport
    }

    private var creatorSubtitleText: String {
        if isCuratedImportedRecipe {
            return viewModel.localizer.text(.sourceAttributionLabel)
        }
        guard validRecipeCreatorID != nil else {
            return viewModel.localizer.localized("recipe.detail.creator_subtitle.creator")
        }
        return canShowFollowButton
            ? viewModel.localizer.localized("recipe.detail.creator_subtitle.creator")
            : viewModel.localizer.localized("recipe.detail.creator_subtitle.you")
    }

    private var normalizedCreatorDisplayName: String {
        creatorMetadataResolution.displayName
    }

    private var heroMetadataLine: String? {
        normalizedCreatorDisplayName
    }

    private var displayedCreatorName: String {
        normalizedCreatorDisplayName
    }

    private enum CreatorMetadataPath: String {
        case source
        case creatorName
        case authorName
        case neutralFallback
    }

    private var creatorMetadataResolution: (displayName: String, path: CreatorMetadataPath) {
        if let sourceLabel = curatedSourceLabel {
            return (sourceLabel, .source)
        }
        if let creatorName = cleanedPersonName(from: rankedRecipe.recipe.displayCreatorName) {
            return (creatorName, .creatorName)
        }
        if let authorName = cleanedPersonName(from: rankedRecipe.recipe.author) {
            return (authorName, .authorName)
        }
        return (viewModel.localizer.localized("recipe.detail.creator_subtitle.creator"), .neutralFallback)
    }

    private var originalSourceURL: URL? {
        guard isCuratedImportedRecipe else { return nil }
        guard let raw = rankedRecipe.recipe.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    private var curatedSourceDisplayName: String? {
        guard isCuratedImportedRecipe else { return nil }
        let sourceCandidate = rankedRecipe.recipe.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hostCandidate = originalSourceURL?.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let bestDomain = [sourceCandidate, hostCandidate]
            .first(where: { $0.contains(".") && !$0.isEmpty })
            ?? hostCandidate
        guard !bestDomain.isEmpty else { return nil }

        let lowered = bestDomain.lowercased().replacingOccurrences(of: "www.", with: "")
        var parts = lowered.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }
        if parts.count >= 2 {
            let weakSecondLevel = Set(["co", "com", "org", "net", "gov", "edu", "ac"])
            if parts.count >= 3, weakSecondLevel.contains(parts[parts.count - 2]) {
                parts = [parts[parts.count - 3]]
            } else {
                parts = [parts[parts.count - 2]]
            }
        }

        let token = parts[0]
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        return token
            .split(separator: " ")
            .map { word in
                let value = String(word)
                return value.prefix(1).uppercased() + value.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private var curatedSourceLabel: String? {
        guard let sourceName = curatedSourceDisplayName else { return nil }
        return String(
            format: viewModel.localizer.localized("recipe.detail.source_via_format"),
            sourceName
        )
    }

    private func cleanedPersonName(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        let blockedValues: Set<String> = ["unknown", "autore sconosciuto", "sconosciuto", "n/a", "-"]
        guard !blockedValues.contains(lowered) else { return nil }
        return trimmed
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
            .buttonStyle(PressableCardButtonStyle())
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

    private var creatorFollowerCountText: String? {
        guard showsUserAuthorshipMetadata else { return nil }
        return String(
            format: viewModel.localizer.text(.followersCountFormat),
            followerCountValue
        )
    }

    private var crispyButton: some View {
        Button {
            viewModel.toggleRecipeCrispy(rankedRecipe.recipe)
            pulse(.crispy)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(
                        viewModel.isRecipeCrispied(rankedRecipe.recipe)
                        ? Color.orange
                        : Color(red: 0.70, green: 0.47, blue: 0.19)
                    )
                    .frame(width: 14, alignment: .center)
                Text(
                    "\(viewModel.crispyCount(for: rankedRecipe.recipe).compactFormatted()) \(viewModel.localizer.text(.crispyAction).lowercased())"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(
                    viewModel.isRecipeCrispied(rankedRecipe.recipe)
                    ? Color.orange
                    : Color(red: 0.41, green: 0.29, blue: 0.10)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        viewModel.isRecipeCrispied(rankedRecipe.recipe)
                        ? Color.orange.opacity(0.18)
                        : Color(red: 0.98, green: 0.93, blue: 0.86)
                    )
            )
        }
        .buttonStyle(PressableCardButtonStyle())
        .scaleEffect(crispyButtonPulse ? SeasonMotion.pressScale : 1.0)
        .opacity(crispyButtonPulse ? SeasonMotion.pressOpacity : 1.0)
        .animation(SeasonMotion.pressAnimation, value: crispyButtonPulse)
        .accessibilityLabel(viewModel.localizer.text(.crispyAction))
    }

    private var viewsStatLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "eye")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary.opacity(0.72))
            Text("\(viewModel.compactCountText(viewModel.viewCount(for: rankedRecipe.recipe))) \(viewModel.localizer.text(.viewsLabel))")
                .font(.caption.weight(.regular))
                .foregroundStyle(.secondary.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
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

    private func hasIngredientInFridge(_ ingredient: IngredientRow) -> Bool {
        viewModel.isRecipeIngredientAvailable(
            ingredient.recipeIngredient,
            fridgeIngredientIDs: fridgeViewModel.allIngredientIDSet
        )
    }

    private func shoppingListComparableIngredient(for ingredient: IngredientRow) -> RecipeIngredient {
        let scaledValue = scaledQuantityValue(for: ingredient.recipeIngredient)
        return RecipeIngredient(
            produceID: ingredient.recipeIngredient.produceID,
            basicIngredientID: ingredient.recipeIngredient.basicIngredientID,
            quality: ingredient.recipeIngredient.quality,
            name: viewModel.recipeIngredientDisplayName(ingredient.recipeIngredient),
            quantityValue: scaledValue,
            quantityUnit: ingredient.recipeIngredient.quantityUnit,
            rawIngredientLine: ingredient.recipeIngredient.rawIngredientLine,
            mappingConfidence: ingredient.recipeIngredient.mappingConfidence
        )
    }

    private func ingredientAvailability(for ingredient: IngredientRow) -> IngredientAvailability {
        if hasIngredientInFridge(ingredient) {
            return .inFridge
        }
        if isIngredientInShoppingList(ingredient) {
            return .inList
        }
        return .missing
    }

    private func isIngredientInShoppingList(_ ingredient: IngredientRow) -> Bool {
        let comparable = shoppingListComparableIngredient(for: ingredient)

        if let produceID = comparable.produceID {
            if let produceItem = viewModel.produceItem(forID: produceID),
               shoppingListViewModel.contains(produceItem) {
                return true
            }
            return shoppingListViewModel.items.contains { $0.produceID == produceID }
        }

        if let basicID = comparable.basicIngredientID {
            if let basicItem = viewModel.basicIngredient(forID: basicID) {
                let basicEntry = ShoppingListEntry.basic(basicItem, quantity: comparable.quantity)
                if shoppingListViewModel.contains(basicItem) || shoppingListViewModel.contains(basicEntry) {
                    return true
                }
            }
            return shoppingListViewModel.items.contains { $0.basicIngredientID == basicID }
        }

        let customEntry = ShoppingListEntry.custom(name: comparable.name, quantity: comparable.quantity)
        return shoppingListViewModel.contains(customEntry)
            || shoppingListViewModel.containsCustom(named: comparable.name)
    }

    private func ingredientStatusText(for ingredient: IngredientRow) -> String {
        switch ingredientAvailability(for: ingredient) {
        case .inFridge:
            return viewModel.localizer.text(.youHave)
        case .inList:
            return viewModel.localizer.localized("recipe.detail.ingredient_status.in_list")
        case .missing:
            break
        }

        let quantityText = displayQuantityText(for: ingredient.recipeIngredient)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quantityText.isEmpty else {
            return viewModel.localizer.text(.missing)
        }
        return "\(viewModel.localizer.text(.missing)) · \(quantityText)"
    }

    private func ingredientAvailabilityLabel(for ingredient: IngredientRow) -> String {
        switch ingredientAvailability(for: ingredient) {
        case .inFridge:
            return viewModel.localizer.localized("recipe.detail.ingredient_availability.in_fridge")
        case .inList:
            return viewModel.localizer.localized("recipe.detail.ingredient_availability.in_list")
        case .missing:
            return viewModel.localizer.localized("recipe.detail.ingredient_availability.missing")
        }
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

        if ingredient.mappingConfidence == .unmapped {
            return true
        }

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

    private var availableIngredientCount: Int {
        ingredientRows.filter { ingredientAvailability(for: $0) == .inFridge }.count
    }

    private var inListIngredientCount: Int {
        ingredientRows.filter { ingredientAvailability(for: $0) == .inList }.count
    }

    private var missingIngredientCount: Int {
        ingredientRows.filter { ingredientAvailability(for: $0) == .missing }.count
    }

    private var untreatedMissingIngredientCount: Int {
        missingIngredientCount
    }

    private enum PrimaryCTAState {
        case readyToCook
        case coveredByShoppingList
        case missingIngredients
    }

    private var primaryCTAState: PrimaryCTAState {
        if isReadyToCook {
            return .readyToCook
        }
        if untreatedMissingIngredientCount == 0 && inListIngredientCount > 0 {
            return .coveredByShoppingList
        }
        return .missingIngredients
    }

    private var isReadyToCook: Bool {
        untreatedMissingIngredientCount == 0 && inListIngredientCount == 0 && !ingredientRows.isEmpty
    }

    private var readinessTitle: String {
        if isReadyToCook {
            return viewModel.localizer.text(.readyNow)
        }
        if untreatedMissingIngredientCount == 0 && inListIngredientCount > 0 {
            return viewModel.localizer.text(.almostReady)
        }
        return viewModel.localizer.text(.missingIngredients)
    }

    private var readinessDetail: String {
        if isReadyToCook {
            return viewModel.localizer.text(.quickActionYouHaveEverything)
        }
        if untreatedMissingIngredientCount == 0 && inListIngredientCount > 0 {
            return viewModel.localizer.text(.recipeDetailEverythingElseInList)
        }
        return String(format: viewModel.localizer.text(.recipeDetailStillMissingItemsFormat), untreatedMissingIngredientCount)
    }

    private var primaryCTATitle: String {
        switch primaryCTAState {
        case .readyToCook:
            return "Inizia a cucinare"
        case .coveredByShoppingList:
            return "Vai alla lista"
        case .missingIngredients:
            return "Aggiungi ingredienti"
        }
    }

    private var primaryCTAIcon: String? {
        switch primaryCTAState {
        case .readyToCook:
            return "flame.fill"
        case .coveredByShoppingList:
            return "cart.fill"
        case .missingIngredients:
            return "cart.badge.plus"
        }
    }

    private var primaryCTASubtitle: String? {
        switch primaryCTAState {
        case .readyToCook:
            return "Vai direttamente ai passaggi"
        case .coveredByShoppingList:
            return "Ingredienti già pronti nella tua lista"
        case .missingIngredients:
            return String(
                format: viewModel.localizer.localized("recipe.detail.cta.subtitle.missing_format"),
                untreatedMissingIngredientCount
            )
        }
    }

    private func handlePrimaryCTA(scrollProxy: ScrollViewProxy) {
        switch primaryCTAState {
        case .readyToCook:
            withAnimation(.easeInOut(duration: 0.26)) {
                scrollProxy.scrollTo("recipe_steps_section", anchor: .top)
            }
            triggerStepsHighlight()
        case .coveredByShoppingList:
            showingShoppingList = true
        case .missingIngredients:
            addIngredients()
            pulse(.addIngredients)
        }
    }

    private func triggerStepsHighlight() {
        emphasizeStepsSection = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            emphasizeStepsSection = false
        }
    }

    private var whyThisRecipeReasons: [String] {
        var reasons: [String] = []
        if rankedRecipe.seasonalMatchPercent >= 80 {
            reasons.append(viewModel.localizer.localized("recipe.detail.reason.season_now"))
        }

        let crispyCount = viewModel.crispyCount(for: rankedRecipe.recipe)
        if crispyCount > 0 {
            reasons.append(
                String(
                    format: viewModel.localizer.localized("recipe.detail.reason.popular_format"),
                    crispyCount
                )
            )
        }

        let totalTime = (rankedRecipe.recipe.prepTimeMinutes ?? 0) + (rankedRecipe.recipe.cookTimeMinutes ?? 0)
        if totalTime > 0 && totalTime <= 30 {
            reasons.append(
                String(
                    format: viewModel.localizer.localized("recipe.detail.reason.ready_in_format"),
                    totalTime
                )
            )
        }

        if reasons.count < 3 && inListIngredientCount > 0 && untreatedMissingIngredientCount == 0 {
            reasons.append(viewModel.localizer.localized("recipe.detail.reason.in_list"))
        }

        if reasons.count < 2 && isReadyToCook {
            reasons.append(viewModel.localizer.localized("recipe.detail.reason.ready_now"))
        }

        return Array(reasons.prefix(3))
    }

    #if DEBUG
    private func debugLogLayoutContract() {
        print("[SEASON_RECIPE_LAYOUT] phase=render_order recipe_id=\(rankedRecipe.recipe.id) order=hero>title_meta>creator>identity_meta>status>why>cta>tags>preparation>servings>ingredient_summary>ingredients_list>nutrition>steps>media>remix")
        print("[SEASON_RECIPE_LAYOUT] phase=creator_metadata recipe_id=\(rankedRecipe.recipe.id) path=\(creatorMetadataResolution.path.rawValue) display_name=\(creatorMetadataResolution.displayName)")
    }
    #endif

    private var totalRecipeMinutes: Int? {
        let prep = rankedRecipe.recipe.prepTimeMinutes ?? 0
        let cook = rankedRecipe.recipe.cookTimeMinutes ?? 0
        let total = prep + cook
        return total > 0 ? total : nil
    }

    private var recipeHeroImage: some View {
        RecipeHeroView(
            galleryImages: orderedGalleryImages,
            legacyCoverImageName: rankedRecipe.recipe.coverImageName,
            remoteImageURLString: rankedRecipe.recipe.imageURL,
            title: heroTitleText
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
                    targetLanguageCode: effectiveTranslationTargetLanguageCode
                )
                await MainActor.run {
                    translationConfiguration = config
                    print(
                        "[SEASON_TRANSLATION] phase=config_resolved recipe_id=\(rankedRecipe.recipe.id) selected_language=\(selectedLanguage) viewmodel_language=\(viewModel.languageCode) target_language=\(effectiveTranslationTargetLanguageCode) has_config=\(config != nil)"
                    )
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
                targetLanguageCode: effectiveTranslationTargetLanguageCode,
                session: session
            )
            translationResult = translated
            print(
                "[SEASON_TRANSLATION] phase=translation_completed recipe_id=\(rankedRecipe.recipe.id) target_language=\(effectiveTranslationTargetLanguageCode) translated=\(translated?.isAutomaticallyTranslated == true)"
            )
        } catch {
            translationFailed = true
            print("[SEASON_TRANSLATION] phase=failed error=\(error)")
        }
    }

    private var effectiveTranslationTargetLanguageCode: String {
        if let selected = AppLanguage(rawValue: selectedLanguage)?.rawValue {
            return selected
        }
        if let modelLanguage = AppLanguage(rawValue: viewModel.languageCode)?.rawValue {
            return modelLanguage
        }
        return AppLanguage.english.rawValue
    }

    private func resetTranslationStateAndRefresh() {
        hasAttemptedTranslation = false
        translationFailed = false
        translationResult = nil
        translationConfiguration = nil
        refreshTranslationConfiguration()
    }

    private var ingredientRows: [IngredientRow] {
        rankedRecipe.recipe.ingredients.map { ingredient in
            let resolved = viewModel.resolveIngredientForDisplay(ingredient)
            return IngredientRow(
                id: resolved.recipeIngredient.id,
                name: resolved.displayName,
                item: resolved.produceItem,
                basic: resolved.basicIngredient,
                recipeIngredient: resolved.recipeIngredient,
                isReconciled: resolved.isReconciled
            )
        }
    }

    private var sortedIngredientRows: [IngredientRow] {
        ingredientRows.sorted { lhs, rhs in
            let lhsRank = ingredientSortRank(lhs)
            let rhsRank = ingredientSortRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return displayIngredientName(for: lhs).localizedCaseInsensitiveCompare(displayIngredientName(for: rhs)) == .orderedAscending
        }
    }

    private func ingredientSortRank(_ ingredient: IngredientRow) -> Int {
        switch ingredientAvailability(for: ingredient) {
        case .missing:
            return 0
        case .inList:
            return 1
        case .inFridge:
            return 2
        }
    }

    @ViewBuilder
    private func nutritionSection(summary nutritionSummary: RecipeNutritionSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.localizer.text(.recipeNutritionSummaryTitle))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(String(format: viewModel.localizer.text(.recipeNutritionPerServingBasisFormat), baseServingsCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                NutritionRow(
                    title: viewModel.localizer.text(.calories),
                    value: "\(Int(nutritionSummary.calories.rounded()))"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.protein),
                    value: "\(formattedNumber(nutritionSummary.protein)) g"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.carbs),
                    value: "\(formattedNumber(nutritionSummary.carbs)) g"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.fat),
                    value: "\(formattedNumber(nutritionSummary.fat)) g"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.fiber),
                    value: "\(formattedNumber(nutritionSummary.fiber)) g"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.vitaminC),
                    value: "\(formattedNumber(nutritionSummary.vitaminC)) mg"
                )
                NutritionRow(
                    title: viewModel.localizer.text(.potassium),
                    value: "\(formattedNumber(nutritionSummary.potassium)) mg"
                )
            }

            if selectedServings != 1 {
                Divider()
                    .overlay(Color.primary.opacity(0.08))
                NutritionRow(
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

    private var ingredientSummaryRow: some View {
        HStack(spacing: 8) {
            Text(
                String(
                    format: viewModel.localizer.localized("recipe.detail.ingredient_summary.missing_format"),
                    untreatedMissingIngredientCount
                )
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )

            Text(
                String(
                    format: viewModel.localizer.localized("recipe.detail.ingredient_summary.available_format"),
                    availableIngredientCount + inListIngredientCount
                )
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.green.opacity(0.12))
                )

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var mediaAndSourceSection: some View {
        if !rankedRecipe.recipe.externalMedia.isEmpty || !recipeSocialLinks.isEmpty || originalSourceURL != nil {
            VStack(alignment: .leading, spacing: 10) {
                if !rankedRecipe.recipe.externalMedia.isEmpty {
                    Text(viewModel.localizer.text(.watchVideo))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(rankedRecipe.recipe.externalMedia, id: \.id) { media in
                        Button {
                            guard let url = URL(string: media.url) else { return }
                            openURL(url)
                        } label: {
                            HStack(spacing: 10) {
                                brandIcon(for: media.platform)
                                    .frame(width: 18, height: 18)
                                    .frame(minWidth: 28, minHeight: 28)

                                Text(mediaTitle(for: media))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }

                if !recipeSocialLinks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recipeSocialLinks, id: \.platform) { link in
                                Button {
                                    guard let url = URL(string: link.url) else { return }
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 6) {
                                        brandIcon(for: link.platform)
                                            .frame(width: 14, height: 14)
                                        Text(link.label)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(SeasonColors.mutedChipSurface)
                                    )
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let sourceURL = originalSourceURL {
                    Button {
                        openURL(sourceURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                            Text(viewModel.localizer.text(.openOriginalRecipe))
                                .font(.caption.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var remixSection: some View {
        if rankedRecipe.recipe.isRemix,
           let originalTitle = rankedRecipe.recipe.originalRecipeTitle {
            VStack(alignment: .leading, spacing: 8) {
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

                Button {
                    showingRemixComposer = true
                } label: {
                    Label(viewModel.localizer.text(.remixRecipe), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        } else {
            let remixCount = viewModel.remixCount(forOriginalRecipeID: rankedRecipe.recipe.id)
            if remixCount > 0 {
                Text(String(format: viewModel.localizer.text(.remixesCountFormat), remixCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
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
                        RoundedRectangle(cornerRadius: SeasonRadius.small, style: .continuous)
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
            IngredientDetailView(
                ingredient: ingredient,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
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
        let resolvedIngredients = ingredientRows.map(shoppingListComparableIngredient(for:))

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
    let isReconciled: Bool
}

private enum IngredientAvailability {
    case inFridge
    case inList
    case missing
}

private struct RecipeHeroView: View {
    let galleryImages: [RecipeImage]
    let legacyCoverImageName: String?
    let remoteImageURLString: String?
    let title: String

    var body: some View {
        imageLayer
            .frame(maxWidth: .infinity)
            .frame(height: 268)
            .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous))
            .accessibilityLabel(safeTitle)
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.52), location: 0.0),
                        .init(color: Color.black.opacity(0.30), location: 0.32),
                        .init(color: Color.black.opacity(0.12), location: 0.56),
                        .init(color: Color.black.opacity(0.04), location: 0.78),
                        .init(color: Color.black.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
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
        if recipeImageFileURL(for: image.localPath) != nil {
            RecipeLocalImageView(image: image, contentMode: .fill) {
                resolvedRemoteImageView(for: image)
            }
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

    @ViewBuilder
    private func resolvedRemoteImageView(for image: RecipeImage) -> some View {
        if let remoteURLString = image.remoteURL,
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

    private var safeTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Recipe" : cleaned
    }
}

private struct MatchBadgeView: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title.uppercased(), systemImage: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct RecipeMetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

private struct CreatorBarView: View {
    let creatorName: String
    let creatorSubtitle: String
    let followerCountText: String?
    let avatarURL: String?
    let creatorID: String?
    let isFollowing: Bool
    let followLabel: String
    let followingLabel: String
    let canShowFollowButton: Bool
    let onCreatorTap: () -> Void
    let onFollowTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCreatorTap) {
                HStack(spacing: 10) {
                    AvatarView(
                        avatarURL: avatarURL,
                        size: 30,
                        creatorID: creatorID,
                        displayName: creatorName
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(creatorName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(creatorSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let followerCountText {
                            Text(followerCountText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableCardButtonStyle())

            Spacer(minLength: 10)

            if canShowFollowButton {
                Button(action: onFollowTap) {
                    Text(isFollowing ? followingLabel : followLabel)
                        .font(.caption2.weight(.semibold))
                        .tracking(0.3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isFollowing
                                    ? SeasonColors.subtleSurface
                                    : SeasonColors.secondarySurface
                                )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.6)
                        )
                }
                .buttonStyle(PressableCardButtonStyle())
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

private struct RecipeIntelligenceCard: View {
    let fridgeMatchText: String
    let fridgeDetailText: String
    let seasonalTitle: String
    let seasonalDetail: String
    let readinessTitle: String
    let readinessDetail: String
    let isReadyToCook: Bool
    let statusLabel: String
    let fridgeLabel: String
    let seasonLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isReadyToCook ? "bolt.fill" : "cart.badge.plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isReadyToCook ? Color.green : Color(red: 0.62, green: 0.34, blue: 0.18))
                Text(statusLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(readinessTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(readinessDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                MatchBadgeView(
                    title: fridgeLabel,
                    value: fridgeMatchText,
                    detail: fridgeDetailText,
                    tint: Color(red: 0.33, green: 0.43, blue: 0.30),
                    icon: "snowflake"
                )
                MatchBadgeView(
                    title: seasonLabel,
                    value: seasonalTitle,
                    detail: seasonalDetail,
                    tint: SeasonColors.seasonGreen,
                    icon: "leaf.fill"
                )
            }
            Divider()
                .overlay(Color.primary.opacity(0.08))
        }
    }
}

private struct SmartCTAButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let subtitle: String?
    let icon: String?
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon, subtitle == nil {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                }

                VStack(alignment: .center, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle((style == .primary ? Color.white : Color.secondary).opacity(0.88))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .foregroundStyle(style == .primary ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: subtitle == nil ? 50 : 58)
            .background(background)
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    @ViewBuilder
    private var background: some View {
        if style == .primary {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.33, green: 0.38, blue: 0.28), Color(red: 0.42, green: 0.49, blue: 0.37)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SeasonColors.secondarySurface.opacity(0.88))
        }
    }
}

private struct NutritionRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct IngredientRowView: View {
    let ingredient: IngredientRow
    let displayName: String
    let quantityText: String
    let statusText: String
    let availabilityText: String
    let availabilityState: IngredientAvailability
    let isInFridge: Bool
    let isInteractive: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let item = ingredient.item {
                ProduceThumbnailView(item: item, size: 30)
            } else {
                Image(systemName: "leaf")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: SeasonRadius.small, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                if !quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(quantityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text(availabilityText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(availabilityPillForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(availabilityPillBackground)
                    )

                if isInteractive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } else if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    private var availabilityPillForeground: Color {
        availabilityChipSemantic.foreground
    }

    private var availabilityPillBackground: Color {
        availabilityChipSemantic.background
    }

    private var availabilityChipSemantic: SeasonChipSemantic {
        switch availabilityState {
        case .inFridge, .inList:
            return .positive
        case .missing:
            return .warning
        }
    }
}

private struct IngredientsListView<Destination>: View {
    let title: String?
    let ingredients: [IngredientRow]
    let displayName: (IngredientRow) -> String
    let quantityText: (IngredientRow) -> String
    let statusText: (IngredientRow) -> String
    let availabilityText: (IngredientRow) -> String
    let availabilityState: (IngredientRow) -> IngredientAvailability
    let hasInFridge: (IngredientRow) -> Bool
    let destinationFor: (IngredientRow) -> Destination?
    let destinationView: (Destination) -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    if let destination = destinationFor(ingredient) {
                        NavigationLink {
                            destinationView(destination)
                        } label: {
                            IngredientRowView(
                                ingredient: ingredient,
                                displayName: displayName(ingredient),
                                quantityText: quantityText(ingredient),
                                statusText: statusText(ingredient),
                                availabilityText: availabilityText(ingredient),
                                availabilityState: availabilityState(ingredient),
                                isInFridge: hasInFridge(ingredient),
                                isInteractive: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        IngredientRowView(
                            ingredient: ingredient,
                            displayName: displayName(ingredient),
                            quantityText: quantityText(ingredient),
                            statusText: statusText(ingredient),
                            availabilityText: availabilityText(ingredient),
                            availabilityState: availabilityState(ingredient),
                            isInFridge: hasInFridge(ingredient),
                            isInteractive: false
                        )
                    }

                    if index < ingredients.count - 1 {
                        Divider()
                            .overlay(Color.primary.opacity(0.07))
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }
}

private struct RecipeStepView: View {
    let index: Int
    let step: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.66, green: 0.72, blue: 0.58))
                .frame(width: 30, alignment: .leading)

            Text(step)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1). \(step)")
    }
}

private struct MethodSectionView: View {
    let title: String
    let steps: [String]
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    RecipeStepView(index: index, step: step)

                    if index < steps.count - 1 {
                        Divider()
                            .overlay(Color.primary.opacity(0.07))
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: highlight)
    }
}

private struct WhyThisRecipeView: View {
    let reasons: [String]
    let title: String

    var body: some View {
        if !reasons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(red: 0.49, green: 0.58, blue: 0.42))
                            .padding(.top, 2)
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
