import SwiftUI
import PhotosUI
import UIKit

private struct CreateIngredientDraft: Identifiable {
    let id = UUID()
    var produceID: String = ""
    var basicIngredientID: String = ""
    var customName: String = ""
    var searchText: String = ""
    var quantityValue: String = "100"
    var quantityUnit: RecipeQuantityUnit = .g
}

private struct CreateStepDraft: Identifiable {
    let id = UUID()
    var text: String = ""
}

private enum ImportedIngredientMatch {
    case produce(ProduceItem)
    case basic(BasicIngredient)
}

private struct ImportQualityBadge: View {
    let confidence: SocialImportConfidence

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }

    private var label: String {
        switch confidence {
        case .high: return "High quality"
        case .medium: return "Good start"
        case .low: return "Needs review"
        }
    }

    private var color: Color {
        switch confidence {
        case .high: return Color.green
        case .medium: return Color.orange
        case .low: return Color.red
        }
    }
}

struct CreateRecipeView: View {
    struct PrefillDraft {
        let title: String
        let imageAssetName: String?
        let externalMedia: [RecipeExternalMedia]
        let images: [RecipeImage]
        let coverImageID: String?
        let mediaLinkURL: String?
        let instagramURL: String?
        let tiktokURL: String?
        let ingredients: [RecipeIngredient]
        let steps: [String]
        let prepTimeMinutes: Int?
        let cookTimeMinutes: Int?
        let difficulty: RecipeDifficulty?
        let servings: Int
        let isRemix: Bool
        let originalRecipeID: String?
        let originalRecipeTitle: String?
        let originalAuthorName: String?
    }

    @ObservedObject var viewModel: ProduceViewModel
    private let prefillDraft: PrefillDraft?
    private let initialDraftRecipeID: String?
    private let enableDraftMode: Bool
    @AppStorage("accountUsername") private var accountUsername = "Anna"
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var mediaLink = ""
    @State private var instagramURL = ""
    @State private var tiktokURL = ""
    @State private var uploadedImages: [RecipeImage] = []
    @State private var coverImageID: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCameraPicker = false
    @State private var importSourceURL = ""
    @State private var importCaptionRaw = ""
    @State private var detectedSourcePlatform: SocialSourcePlatform?
    @State private var ingredientDrafts: [CreateIngredientDraft] = [CreateIngredientDraft()]
    @State private var stepDrafts: [CreateStepDraft] = [CreateStepDraft()]
    @State private var showPublishError = false
    @State private var importFeedbackText = ""
    @State private var importConfidence: SocialImportConfidence?
    @State private var importServerNoticeText = ""
    @State private var isImportAnalyzing = false
    @State private var showCaptionImportHint = false
    @State private var showImportTools = false
    @State private var selectedServings = 2
    @State private var showCameraUnavailableAlert = false
    @State private var currentDraftRecipeID: String?
    @State private var lastSavedDraftFingerprint = ""
    @State private var showDraftSavedFeedback = false
    @State private var hasAttemptedInitialDraftLoad = false
    @State private var draftLoadFailed = false
    @State private var isPublishing = false
    @FocusState private var focusedIngredientID: UUID?

    private var localizer: AppLocalizer { viewModel.localizer }

    init(
        viewModel: ProduceViewModel,
        prefillDraft: PrefillDraft? = nil,
        initialDraftRecipeID: String? = nil,
        enableDraftMode: Bool = false
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.initialDraftRecipeID = initialDraftRecipeID
        self.enableDraftMode = enableDraftMode
        self.prefillDraft = prefillDraft
            ?? initialDraftRecipeID.flatMap { recipeID in
                guard let draftRecipe = viewModel.recipe(forID: recipeID) else { return nil }
                return Self.prefillDraft(from: draftRecipe)
            }
        _currentDraftRecipeID = State(initialValue: initialDraftRecipeID)

        _title = State(initialValue: self.prefillDraft?.title ?? "")
        let initialMediaLink = self.prefillDraft?.mediaLinkURL
            ?? self.prefillDraft?.externalMedia.first?.url
            ?? ""
        _mediaLink = State(initialValue: initialMediaLink)
        _instagramURL = State(initialValue: self.prefillDraft?.instagramURL ?? "")
        _tiktokURL = State(initialValue: self.prefillDraft?.tiktokURL ?? "")
        _uploadedImages = State(initialValue: self.prefillDraft?.images ?? [])
        _coverImageID = State(initialValue: self.prefillDraft?.coverImageID ?? self.prefillDraft?.images.first?.id)
        _selectedServings = State(initialValue: max(1, self.prefillDraft?.servings ?? 2))

        if let prefillDraft = self.prefillDraft {
            let mappedIngredientDrafts = prefillDraft.ingredients.map {
                let mappedSearchText: String
                if let produceID = $0.produceID,
                   let item = viewModel.produceItem(forID: produceID) {
                    mappedSearchText = item.displayName(languageCode: viewModel.localizer.languageCode)
                } else if let basicID = $0.basicIngredientID,
                          let basic = viewModel.basicIngredient(forID: basicID) {
                    mappedSearchText = basic.displayName(languageCode: viewModel.localizer.languageCode)
                } else {
                    mappedSearchText = $0.name
                }

                return CreateIngredientDraft(
                    produceID: $0.produceID ?? "",
                    basicIngredientID: $0.basicIngredientID ?? "",
                    customName: ($0.produceID == nil && $0.basicIngredientID == nil) ? $0.name : "",
                    searchText: mappedSearchText,
                    quantityValue: quantityValueStringStatic($0.quantityValue),
                    quantityUnit: $0.quantityUnit
                )
            }
            _ingredientDrafts = State(initialValue: mappedIngredientDrafts.isEmpty ? [CreateIngredientDraft()] : mappedIngredientDrafts)
            let mappedStepDrafts = prefillDraft.steps.map { CreateStepDraft(text: $0) }
            _stepDrafts = State(initialValue: mappedStepDrafts.isEmpty ? [CreateStepDraft()] : mappedStepDrafts)
        } else {
            _ingredientDrafts = State(initialValue: [CreateIngredientDraft()])
            _stepDrafts = State(initialValue: [CreateStepDraft()])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if draftLoadFailed {
                    VStack(spacing: 10) {
                        Text(localizer.recipeDraftNotFoundTitle)
                            .font(.headline)
                        Text(localizer.recipeDraftNotFoundMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            heroComposerSection
                            titleSection
                            socialLinksSection
                            servingsSection
                            importFromLinkSection
                            ingredientsSection
                            stepsSection
                            previewSection
                            Color.clear.frame(height: 12)
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(localizer.text(.createRecipe))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                publishBar
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if enableDraftMode {
                            persistDraftIfNeeded()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert(localizer.text(.createRecipeSubtitle), isPresented: $showPublishError) {
                Button(localizer.text(.commonOK), role: .cancel) {}
            }
            .alert(localizer.text(.cameraUnavailableTitle), isPresented: $showCameraUnavailableAlert) {
                Button(localizer.text(.commonOK), role: .cancel) {}
            } message: {
                Text(localizer.text(.cameraUnavailableMessage))
            }
            .sheet(isPresented: $showingCameraPicker) {
                CameraImagePicker { image in
                    guard let image else { return }
                    addCameraImage(image)
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await importPhotoItems(newItems)
                }
            }
            .onAppear {
                loadExistingDraftIfNeeded()
                if enableDraftMode, currentDraftRecipeID == nil, !draftLoadFailed {
                    let createdDraft = viewModel.createEmptyDraftRecipe(author: accountUsername)
                    currentDraftRecipeID = createdDraft.id
                }
                if detectedSourcePlatform == nil {
                    detectedSourcePlatform = detectedPlatform(for: mediaLink)
                }
                if enableDraftMode, !draftLoadFailed {
                    lastSavedDraftFingerprint = persistedDraftFingerprint()
                }
            }
        }
    }

    private var heroComposerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                heroImageContent
                    .frame(maxWidth: .infinity)
                    .frame(height: 208)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.34)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 8) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 8,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(localizer.text(.mediaAddPhotos), systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.92))

                    Button {
                        openCameraIfAvailable()
                    } label: {
                        Label(localizer.text(.mediaUseCamera), systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.92))
                }
                .padding(12)
            }

            TextField(localizer.text(.mediaExternalLink), text: $mediaLink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.4))
                        .frame(height: 1)
                }
                .onChange(of: mediaLink) { _, newValue in
                    detectedSourcePlatform = detectedPlatform(for: newValue)
                }

            if let platform = detectedSourcePlatform,
               let platformLabel = platformDisplayName(platform) {
                Text(String(format: localizer.text(.detectedPlatformFormat), platformLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !uploadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(uploadedImages, id: \.id) { image in
                            mediaItemCard(image: image)
                        }
                    }
                }
            }
        }
    }

    private var importFromLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showImportTools) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(localizer.text(.mediaExternalLink), text: $importSourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField(localizer.text(.socialCaptionImportPrompt), text: $importCaptionRaw, axis: .vertical)
                        .lineLimit(3...5)
                        .textInputAutocapitalization(.sentences)
                        .textFieldStyle(.roundedBorder)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(showCaptionImportHint ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
                        }
                        .onChange(of: importCaptionRaw) { _, newValue in
                            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showCaptionImportHint = false
                            }
                        }

                    if showCaptionImportHint {
                        Text(localizer.text(.socialImportCaptionNudge))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await applySocialImport()
                        }
                    } label: {
                        Label(localizer.text(.importDraft), systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canImportFromAnyLink || isImportAnalyzing)

                    if let importConfidence {
                        ImportQualityBadge(confidence: importConfidence)
                            .padding(.top, 4)
                            .scaleEffect(importConfidence == .low ? 1.02 : 1.0)
                    }

                    if !importServerNoticeText.isEmpty {
                        Text(importServerNoticeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !importFeedbackText.isEmpty {
                        if isImportAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(localizer.text(.importAnalyzing))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(importFeedbackText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text(localizer.text(.importFromLinkSectionTitle))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var titleSection: some View {
        TextField(localizer.text(.createRecipe), text: $title, axis: .vertical)
            .font(.system(size: 32, weight: .semibold, design: .default))
            .lineLimit(2...3)
            .textFieldStyle(.plain)
            .padding(.vertical, 6)
    }

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(localizer.recipeSocialLinksSectionTitle)
            Text(localizer.text(.recipePublicSocialLinksHint))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(localizer.recipeInstagramURLField, text: $instagramURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            TextField(localizer.recipeTikTokURLField, text: $tiktokURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var servingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $selectedServings, in: 1...12) {
                Text(String(format: localizer.text(.servesFormat), selectedServings))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(localizer.text(.ingredientsSectionTitle))

            ForEach($ingredientDrafts) { $ingredient in
                let isSubsectionHeader = isSubsectionHeaderDraft(ingredient)
                let hideQuantityControls = shouldHideQuantityControls(for: ingredient)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                localizer.text(.ingredientName),
                                text: bindingForIngredientSearch(id: ingredient.id)
                            )
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedIngredientID, equals: ingredient.id)
                            .font(isSubsectionHeader ? .subheadline.weight(.semibold) : .body)

                            if ingredientIsCustom(ingredient) && !isSubsectionHeader {
                                Text(localizer.text(.customIngredient))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                            }

                            let matches = ingredientMatches(for: ingredient)
                            if shouldShowIngredientSuggestions(for: ingredient) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(matches.prefix(6))) { result in
                                        Button {
                                            applyIngredientSelection(result, for: ingredient.id)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text(result.title)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Spacer()
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if matches.isEmpty {
                                        Button {
                                            applyCustomIngredientFallback(for: ingredient.id)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "plus.circle")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                Text(localizer.text(.cantFindAddCustom))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }
                        }

                        Button(role: .destructive) {
                            removeIngredient(id: ingredient.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if !hideQuantityControls {
                        HStack(spacing: 8) {
                            TextField(localizer.text(.quantity), text: $ingredient.quantityValue)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)

                            Picker(localizer.text(.quantity), selection: $ingredient.quantityUnit) {
                                ForEach(supportedUnits(for: ingredient)) { unit in
                                    Text(localizer.quantityUnitTitle(unit)).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 2)

                if ingredient.id != ingredientDrafts.last?.id {
                    Divider()
                }
            }

            Button {
                let draft = CreateIngredientDraft()
                ingredientDrafts.append(draft)
                focusedIngredientID = draft.id
            } label: {
                Label(localizer.text(.addIngredient), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(localizer.text(.stepsSectionTitle))

            ForEach(Array(stepDrafts.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .leading)

                    TextField(localizer.text(.stepPlaceholder), text: bindingForStep(step.id), axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button(role: .destructive) {
                        removeStep(id: step.id)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if step.id != stepDrafts.last?.id {
                    Divider()
                }
            }

            Button {
                stepDrafts.append(CreateStepDraft())
            } label: {
                Label(localizer.text(.addStep), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(localizer.text(.previewSectionTitle))

            if validIngredientProduceIDs.isEmpty {
                Text(localizer.text(.seasonalFeedbackEmpty))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(localizer.text(.seasonalMatch)): \(seasonalMatchPercent)%")
                    .font(.headline)

                Text(seasonalFeedbackLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(seasonalFeedbackColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(seasonalFeedbackColor.opacity(0.14))
                    )
            }
        }
    }

    private var publishBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(0.25))
                .frame(height: 1)

            VStack(spacing: 0) {
                if enableDraftMode {
                    HStack(spacing: 10) {
                        Button {
                            persistDraftIfNeeded(showFeedback: true)
                        } label: {
                            Text(localizer.text(.saveDraft))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canSaveDraft)

                        Button {
                            publish()
                        } label: {
                            Text(localizer.text(.publishRecipe))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canPublish || isPublishing)
                    }
                } else {
                    HStack {
                        Button {
                            publish()
                        } label: {
                            Text(localizer.text(.publishRecipe))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canPublish || isPublishing)
                    }
                }
                if enableDraftMode && showDraftSavedFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(localizer.text(.saved))
                            .font(.caption.weight(.semibold))
                    }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var heroImageContent: some View {
        if let cover = uploadedImages.first, let uiImage = recipeUIImage(from: cover) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let legacyName = prefillDraft?.imageAssetName, hasAsset(named: legacyName) {
            Image(legacyName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(.secondarySystemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(localizer.text(.mediaNoImagesYet))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var validIngredientProduceIDs: [String] {
        var seen = Set<String>()
        return resolvedPreviewIngredients.compactMap { resolved in
            guard let produceID = resolved.recipeIngredient.produceID?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !produceID.isEmpty else { return nil }
            guard seen.insert(produceID).inserted else { return nil }
            return produceID
        }
    }

    private var resolvedPreviewIngredients: [ResolvedIngredient] {
        recipeIngredientsForPublish.map { ingredient in
            viewModel.resolveIngredientForDisplay(ingredient)
        }
    }

    private var recipeIngredientsForPublish: [RecipeIngredient] {
        ingredientDrafts.compactMap { draft in
            let produceID = draft.produceID.trimmingCharacters(in: .whitespacesAndNewlines)
            let basicIngredientID = draft.basicIngredientID.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parsedQuantityValue(draft.quantityValue)
            let nonCountableNoQuantity = isNonCountableDraftWithoutSyntheticQuantity(draft)
            guard value > 0 || nonCountableNoQuantity else { return nil }

            if nonCountableNoQuantity {
                let naturalName = ingredientDraftDisplayName(draft).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !naturalName.isEmpty else { return nil }
                return RecipeIngredient(
                    produceID: nil,
                    basicIngredientID: nil,
                    quality: .basic,
                    name: naturalName,
                    quantityValue: 1,
                    quantityUnit: .piece,
                    rawIngredientLine: naturalName,
                    mappingConfidence: .unmapped
                )
            }

            if !produceID.isEmpty {
                let name = viewModel.produceItem(forID: produceID)?
                    .displayName(languageCode: localizer.languageCode)
                    ?? produceID
                return RecipeIngredient(
                    produceID: produceID,
                    basicIngredientID: nil,
                    quality: .coreSeasonal,
                    name: name,
                    quantityValue: value,
                    quantityUnit: draft.quantityUnit
                )
            }

            if !basicIngredientID.isEmpty {
                let name = viewModel.basicIngredient(forID: basicIngredientID)?
                    .displayName(languageCode: localizer.languageCode)
                    ?? basicIngredientID
                return RecipeIngredient(
                    produceID: nil,
                    basicIngredientID: basicIngredientID,
                    quality: .basic,
                    name: name,
                    quantityValue: value,
                    quantityUnit: draft.quantityUnit
                )
            }

            let customName = draft.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? draft.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                : draft.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !customName.isEmpty else { return nil }
            // Keep subsection labels visible in draft editing, but exclude them from final publish payload.
            if isIngredientSubsectionHeader(customName) {
                return nil
            }

            let isSyntheticFallback = isSyntheticCustomFallbackIngredientDraft(
                draft,
                resolvedName: customName
            )
            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: nil,
                quality: .basic,
                name: customName,
                quantityValue: value,
                quantityUnit: draft.quantityUnit,
                rawIngredientLine: isSyntheticFallback ? customName : nil,
                mappingConfidence: isSyntheticFallback ? .unmapped : .high
            )
        }
    }

    private var stepTextsForPublish: [String] {
        stepDrafts
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var seasonalMatchPercent: Int {
        viewModel.seasonalMatchPercent(for: validIngredientProduceIDs)
    }

    private var seasonalFeedbackLabel: String {
        switch Double(seasonalMatchPercent) / 100.0 {
        case 0.82...:
            return localizer.text(.seasonPeakNow)
        case 0.55...:
            return localizer.text(.seasonBestThisMonth)
        case 0.22...:
            return localizer.text(.seasonEndOfSeason)
        default:
            return localizer.text(.seasonOutOfSeason)
        }
    }

    private var seasonalFeedbackColor: Color {
        switch Double(seasonalMatchPercent) / 100.0 {
        case 0.82...:
            return Color(red: 0.16, green: 0.65, blue: 0.30)
        case 0.55...:
            return Color(red: 0.24, green: 0.58, blue: 0.25)
        case 0.22...:
            return Color(red: 0.84, green: 0.58, blue: 0.18)
        default:
            return Color(red: 0.78, green: 0.36, blue: 0.33)
        }
    }

    private var normalizedImportSourceURL: String? {
        let trimmed = importSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var resolvedSourceURLForPublish: String? {
        normalizedMediaLink
    }

    private var resolvedSourcePlatformForPublish: SocialSourcePlatform? {
        guard let sourceURL = resolvedSourceURLForPublish else { return nil }
        return detectedPlatform(for: sourceURL)
    }

    private var normalizedImportCaption: String? {
        let trimmed = importCaptionRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !recipeIngredientsForPublish.isEmpty
        && !stepTextsForPublish.isEmpty
    }

    private var canSaveDraft: Bool {
        currentDraftRecipeID != nil && !draftLoadFailed
    }

    private func persistDraftIfNeeded(showFeedback: Bool = false) {
        guard enableDraftMode, let currentDraftRecipeID else { return }
        let fingerprint = persistedDraftFingerprint()
        guard fingerprint != lastSavedDraftFingerprint else {
            if showFeedback {
                flashDraftSavedFeedback()
            }
            return
        }
        let ingredientsForDraftSave = recipeIngredientsForPublish
        _ = viewModel.saveRecipeDraft(
            recipeID: currentDraftRecipeID,
            title: title,
            author: accountUsername,
            ingredients: ingredientsForDraftSave,
            steps: stepTextsForPublish,
            externalMedia: externalMediaForPublish,
            images: uploadedImages,
            coverImageID: selectedCoverImageID,
            coverImageName: prefillDraft?.imageAssetName,
            mediaLinkURL: mediaLink,
            instagramURL: normalizedInstagramURL,
            tiktokURL: normalizedTikTokURL,
            sourceURL: resolvedSourceURLForPublish,
            sourcePlatform: resolvedSourcePlatformForPublish,
            sourceCaptionRaw: normalizedImportCaption,
            importedFromSocial: false,
            servings: selectedServings,
            prepTimeMinutes: prefillDraft?.prepTimeMinutes,
            cookTimeMinutes: prefillDraft?.cookTimeMinutes,
            difficulty: prefillDraft?.difficulty,
            isRemix: prefillDraft?.isRemix ?? false,
            originalRecipeID: prefillDraft?.originalRecipeID,
            originalRecipeTitle: prefillDraft?.originalRecipeTitle,
            originalAuthorName: prefillDraft?.originalAuthorName
        )
        observeUnresolvedCustomIngredients(latestRecipeID: currentDraftRecipeID)
        lastSavedDraftFingerprint = fingerprint
        if showFeedback {
            flashDraftSavedFeedback()
        }
    }

    private func loadExistingDraftIfNeeded() {
        guard enableDraftMode,
              let initialDraftRecipeID,
              !hasAttemptedInitialDraftLoad else { return }
        hasAttemptedInitialDraftLoad = true
        print("[SEASON_RECIPE] phase=draft_load_started id=\(initialDraftRecipeID)")
        guard let recipe = viewModel.recipe(forID: initialDraftRecipeID) else {
            draftLoadFailed = true
            print("[SEASON_RECIPE] phase=draft_load_failed id=\(initialDraftRecipeID)")
            return
        }
        applyDraftPrefill(Self.prefillDraft(from: recipe))
        currentDraftRecipeID = initialDraftRecipeID
        draftLoadFailed = false
        print("[SEASON_RECIPE] phase=draft_load_succeeded id=\(initialDraftRecipeID)")
    }

    private func applyDraftPrefill(_ prefill: PrefillDraft) {
        title = prefill.title
        mediaLink = prefill.mediaLinkURL
            ?? prefill.externalMedia.first?.url
            ?? ""
        instagramURL = prefill.instagramURL ?? ""
        tiktokURL = prefill.tiktokURL ?? ""
        uploadedImages = prefill.images
        coverImageID = prefill.coverImageID ?? prefill.images.first?.id
        selectedServings = max(1, prefill.servings)

        let mappedIngredientDrafts = prefill.ingredients.map { ingredient -> CreateIngredientDraft in
            let mappedSearchText: String
            if let produceID = ingredient.produceID,
               let item = viewModel.produceItem(forID: produceID) {
                mappedSearchText = item.displayName(languageCode: viewModel.localizer.languageCode)
            } else if let basicID = ingredient.basicIngredientID,
                      let basic = viewModel.basicIngredient(forID: basicID) {
                mappedSearchText = basic.displayName(languageCode: viewModel.localizer.languageCode)
            } else {
                mappedSearchText = ingredient.name
            }

            return CreateIngredientDraft(
                produceID: ingredient.produceID ?? "",
                basicIngredientID: ingredient.basicIngredientID ?? "",
                customName: (ingredient.produceID == nil && ingredient.basicIngredientID == nil) ? ingredient.name : "",
                searchText: mappedSearchText,
                quantityValue: quantityValueStringStatic(ingredient.quantityValue),
                quantityUnit: ingredient.quantityUnit
            )
        }
        ingredientDrafts = mappedIngredientDrafts.isEmpty ? [CreateIngredientDraft()] : mappedIngredientDrafts

        let mappedStepDrafts = prefill.steps.map { CreateStepDraft(text: $0) }
        stepDrafts = mappedStepDrafts.isEmpty ? [CreateStepDraft()] : mappedStepDrafts
    }

    private func persistedDraftFingerprint() -> String {
        let titleValue = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientsValue = recipeIngredientsForPublish
            .map {
                "\($0.produceID ?? ""):\($0.basicIngredientID ?? ""):\($0.name.lowercased()):\($0.quantityValue):\($0.quantityUnit.rawValue)"
            }
            .joined(separator: "|")
        let stepsValue = stepTextsForPublish.joined(separator: "|")
        let imagesValue = uploadedImages
            .map { "\($0.id):\($0.localPath ?? ""):\($0.remoteURL ?? "")" }
            .joined(separator: "|")
        let mediaValue = mediaLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let instagramValue = instagramURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let tiktokValue = tiktokURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverValue = selectedCoverImageID ?? ""

        return [
            titleValue,
            ingredientsValue,
            stepsValue,
            imagesValue,
            mediaValue,
            instagramValue,
            tiktokValue,
            coverValue,
            "\(selectedServings)"
        ].joined(separator: "||")
    }

    private func flashDraftSavedFeedback() {
        showDraftSavedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showDraftSavedFeedback = false
        }
    }

    private func publish() {
        guard !isPublishing else { return }

        Task {
            await publishAsync()
        }
    }

    @MainActor
    private func publishAsync() async {
        isPublishing = true
        defer { isPublishing = false }

        let recipeID = currentDraftRecipeID ?? "recipe_\(UUID().uuidString.lowercased())"
        let existingRecipeImageURL = viewModel.recipe(forID: recipeID)?.imageURL
        var uploadedRecipeImageURL: String? = nil

        if let cover = uploadedImages.first,
           let coverImage = recipeUIImage(from: cover),
           let jpegData = coverImage.jpegData(compressionQuality: 0.9) {
            do {
                uploadedRecipeImageURL = try await SupabaseService.shared.uploadRecipeImage(
                    imageData: jpegData,
                    recipeID: recipeID
                )
                print("[SEASON_SUPABASE] request=uploadRecipeImage phase=request_ok recipe_id=\(recipeID)")
            } catch let SupabaseServiceError.requestTimedOut(requestName, seconds) {
                print("[SEASON_SUPABASE] request=\(requestName) phase=request_timeout duration_s=\(Int(seconds)) recipe_id=\(recipeID)")
                print("[SEASON_RECIPE] phase=publish_continue_without_image reason=upload_timeout recipe_id=\(recipeID)")
            } catch {
                print("[SEASON_SUPABASE] request=uploadRecipeImage phase=request_failed recipe_id=\(recipeID) error=\(error)")
                print("[SEASON_RECIPE] phase=publish_continue_without_image reason=upload_failed recipe_id=\(recipeID)")
            }
        }

        let ingredientsForPublish = recipeIngredientsForPublish
        let published = viewModel.publishRecipe(
            title: title,
            author: accountUsername,
            ingredients: ingredientsForPublish,
            steps: stepTextsForPublish,
            externalMedia: externalMediaForPublish,
            images: uploadedImages,
            coverImageID: selectedCoverImageID,
            coverImageName: prefillDraft?.imageAssetName,
            mediaLinkURL: mediaLink,
            imageURL: uploadedRecipeImageURL ?? existingRecipeImageURL,
            instagramURL: normalizedInstagramURL,
            tiktokURL: normalizedTikTokURL,
            sourceURL: resolvedSourceURLForPublish,
            sourcePlatform: resolvedSourcePlatformForPublish,
            sourceCaptionRaw: normalizedImportCaption,
            importedFromSocial: false,
            servings: selectedServings,
            prepTimeMinutes: prefillDraft?.prepTimeMinutes,
            cookTimeMinutes: prefillDraft?.cookTimeMinutes,
            difficulty: prefillDraft?.difficulty,
            existingRecipeID: recipeID,
            isRemix: prefillDraft?.isRemix ?? false,
            originalRecipeID: prefillDraft?.originalRecipeID,
            originalRecipeTitle: prefillDraft?.originalRecipeTitle,
            originalAuthorName: prefillDraft?.originalAuthorName
        )

        if published == nil {
            showPublishError = true
            return
        }

        observeUnresolvedCustomIngredients(latestRecipeID: recipeID)

        currentDraftRecipeID = recipeID
        dismiss()
    }

    private func removeIngredient(id: UUID) {
        if ingredientDrafts.count == 1,
           let index = ingredientDrafts.firstIndex(where: { $0.id == id }) {
            ingredientDrafts[index].produceID = ""
            ingredientDrafts[index].basicIngredientID = ""
            ingredientDrafts[index].customName = ""
            ingredientDrafts[index].searchText = ""
            ingredientDrafts[index].quantityValue = "100"
            ingredientDrafts[index].quantityUnit = .g
            focusedIngredientID = ingredientDrafts[index].id
            return
        }
        ingredientDrafts.removeAll { $0.id == id }
    }

    private func removeStep(id: UUID) {
        if stepDrafts.count == 1,
           let index = stepDrafts.firstIndex(where: { $0.id == id }) {
            stepDrafts[index].text = ""
            return
        }
        stepDrafts.removeAll { $0.id == id }
    }

    private func bindingForStep(_ id: UUID) -> Binding<String> {
        Binding(
            get: { stepDrafts.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
                stepDrafts[index].text = newValue
            }
        )
    }

    @MainActor
    private func applySocialImport() async {
        guard let sourceURL = normalizedImportSourceURL else {
            importConfidence = nil
            importServerNoticeText = ""
            importFeedbackText = localizer.text(.importNoMatches)
            return
        }
        importConfidence = nil
        importServerNoticeText = ""

        let cleanedCaption = removingEmojis(from: importCaptionRaw)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: sourceURL,
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )

        print("[SEASON_IMPORT] phase=local_parse_done source_url=\(sourceURL) confidence=\(localSuggestion.confidence.rawValue)")

        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let shouldAttemptServerFallback = localSuggestion.confidence == .low || refinement.needsRefinement
        let refinementReasonsLog = refinement.reasons.isEmpty ? "[]" : "[\(refinement.reasons.joined(separator: ","))]"
        print("[SEASON_IMPORT] phase=refinement_check needs_refinement=\(refinement.needsRefinement) reasons=\(refinementReasonsLog)")
        if refinement.reasons.contains("unit_prefix_in_name") {
            print("[SEASON_IMPORT] phase=refinement_check reason=unit_prefix_in_name")
        }

        if shouldAttemptServerFallback {
            isImportAnalyzing = true
            importFeedbackText = localizer.text(.importAnalyzing)
            defer { isImportAnalyzing = false }

            print("[SEASON_IMPORT] phase=server_fallback_attempted source_url=\(sourceURL) trigger=\(localSuggestion.confidence == .low ? "low_confidence" : "refinement_gate") reasons=\(refinementReasonsLog)")
            do {
                let serverResponse = try await SupabaseService.shared.parseRecipeCaption(
                    caption: cleanedCaption,
                    url: sourceURL,
                    languageCode: localizer.languageCode
                )
                if let serverSuggestion = socialImportSuggestionFromServerResponse(
                    serverResponse,
                    sourceURL: sourceURL,
                    fallbackCaption: cleanedCaption
                ), isServerSuggestionUseful(serverSuggestion) {
                    importServerNoticeText = ""
                    print("[SEASON_IMPORT] phase=server_fallback_succeeded source_url=\(sourceURL) confidence=\(serverSuggestion.confidence.rawValue)")
                    applyImportedSuggestion(serverSuggestion, sourceURL: sourceURL)
                    return
                }
                print("[SEASON_IMPORT] phase=server_fallback_not_useful source_url=\(sourceURL)")
            } catch let rateLimitError as ParseRecipeCaptionInvokeError {
                switch rateLimitError {
                case .tooFrequent(let retryAfterSeconds):
                    print("[SEASON_IMPORT] phase=server_fallback_rate_limited error_code=TOO_FREQUENT_REQUESTS retry_after_seconds=\(retryAfterSeconds ?? -1)")
                    importServerNoticeText = localizer.text(.importRateLimitCooldown)
                case .dailyLimitReached:
                    print("[SEASON_IMPORT] phase=server_fallback_rate_limited error_code=RATE_LIMIT_EXCEEDED retry_after_seconds=-1")
                    importServerNoticeText = localizer.text(.importRateLimitDaily)
                }
            } catch {
                print("[SEASON_IMPORT] phase=server_fallback_failed source_url=\(sourceURL) error=\(error)")
            }
        }

        print("[SEASON_IMPORT] phase=kept_local_result source_url=\(sourceURL) confidence=\(localSuggestion.confidence.rawValue)")
        applyImportedSuggestion(localSuggestion, sourceURL: sourceURL)
    }

    private func shouldRefineImportedSuggestion(
        _ suggestion: SocialImportSuggestion,
        sourceCaption: String
    ) -> (needsRefinement: Bool, reasons: [String]) {
        var reasons: [String] = []

        let suspiciousUnitNamePattern = #"^(g|kg|ml|l)\s+\S+"#
        let malformedUnitOnlyPattern = #"^(g|kg|ml|l)$"#

        let ingredients = suggestion.suggestedIngredients
        let customIngredients = ingredients.filter { $0.produceID == nil && $0.basicIngredientID == nil }

        for ingredient in ingredients {
            let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = name.lowercased()

            // High-priority rule: explicit measured-unit prefix in name indicates degraded parsing
            // (e.g. "g pasta"), regardless of parsed quantity/unit fields.
            if lowered.range(of: suspiciousUnitNamePattern, options: .regularExpression) != nil {
                reasons.append("unit_prefix_in_name")
            }
            if lowered.range(of: malformedUnitOnlyPattern, options: .regularExpression) != nil || name.count < 2 {
                reasons.append("malformed_ingredient_name")
            }
        }

        if reasons.contains("unit_prefix_in_name") {
            return (true, ["unit_prefix_in_name"])
        }

        if !ingredients.isEmpty {
            let syntheticPieceCustomCount = ingredients.filter { ingredient in
                ingredient.produceID == nil
                    && ingredient.basicIngredientID == nil
                    && ingredient.quantityUnit == .piece
                    && abs(ingredient.quantityValue - 1) < 0.001
            }.count
            let ratio = Double(syntheticPieceCustomCount) / Double(ingredients.count)
            if syntheticPieceCustomCount >= 2 && ratio >= 0.6 {
                reasons.append("too_many_synthetic_piece_customs")
            }

            let lowInformationSyntheticCount = ingredients.filter { ingredient in
                guard ingredient.produceID == nil && ingredient.basicIngredientID == nil else { return false }
                guard ingredient.quantityUnit == .piece && abs(ingredient.quantityValue - 1) < 0.001 else { return false }
                let cleaned = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let tokenCount = cleaned.split(whereSeparator: { $0.isWhitespace }).count
                return tokenCount <= 1 || cleaned.count <= 3
            }.count
            if lowInformationSyntheticCount >= 2 {
                reasons.append("low_info_synthetic_customs")
            }

            let customRatio = Double(customIngredients.count) / Double(ingredients.count)
            if ingredients.count >= 4 && customRatio >= 0.75 {
                reasons.append("too_many_unmatched_customs")
            }
        }

        let normalizedCaption = sourceCaption
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let explicitMeasuredPattern = #"\b\d+(?:[.,]\d+)?\s*(g|kg|ml|l)\b"#
        let explicitMeasuredCount: Int = {
            guard let regex = try? NSRegularExpression(pattern: explicitMeasuredPattern, options: []) else { return 0 }
            let range = NSRange(normalizedCaption.startIndex..<normalizedCaption.endIndex, in: normalizedCaption)
            return regex.numberOfMatches(in: normalizedCaption, options: [], range: range)
        }()
        let importedMeasuredWithQuantity = ingredients.filter { ingredient in
            ingredient.quantityValue > 0 && (ingredient.quantityUnit == .g || ingredient.quantityUnit == .ml)
        }.count
        if explicitMeasuredCount > 0 && importedMeasuredWithQuantity == 0 {
            reasons.append("explicit_measured_missing_quantity")
        }

        if let title = suggestion.suggestedTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            if title.hasSuffix("?") || title.hasSuffix("!") {
                reasons.append("title_punctuation_garbage")
            }
            if title.range(of: #"[^\p{ASCII}]"#, options: .regularExpression) != nil,
               title.range(of: #"[!?]"#, options: .regularExpression) != nil {
                reasons.append("title_residue_garbage")
            }
        }

        if ingredients.count >= 4 {
            let steps = suggestion.suggestedSteps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            let sparse = steps.count <= 1
            let genericTokens = ["mix", "cook", "done", "combine", "stir", "cuoci", "mescola", "fatto"]
            let genericSingleStep = steps.count == 1
                && genericTokens.contains { token in steps[0].contains(token) }
            if sparse || genericSingleStep {
                reasons.append("steps_too_sparse")
            }
        }

        let uniqueReasons = Array(Set(reasons)).sorted()
        return (!uniqueReasons.isEmpty, uniqueReasons)
    }

    @MainActor
    private func applyImportedSuggestion(_ suggestion: SocialImportSuggestion, sourceURL: String) {
        detectedSourcePlatform = suggestion.sourcePlatform ?? detectedPlatform(for: sourceURL)
        mediaLink = sourceURL
        importConfidence = suggestion.confidence
        title = cleanedTitle(suggestion.suggestedTitle ?? "")

        let mappedSteps = suggestion.suggestedSteps
            .map { removingEmojis(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { CreateStepDraft(text: $0) }
        stepDrafts = mappedSteps.isEmpty ? [CreateStepDraft()] : mappedSteps

        if !suggestion.suggestedIngredients.isEmpty {
            let mappedIngredientDrafts = suggestion.suggestedIngredients.map {
                normalizedImportedIngredientDraft(from: $0)
            }
            ingredientDrafts = mappedIngredientDrafts
            for draft in mappedIngredientDrafts {
                let displayName = ingredientDraftDisplayName(draft).trimmingCharacters(in: .whitespacesAndNewlines)
                print("[SEASON_IMPORT] phase=draft_ingredient_mapped name=\(displayName) quantity_value=\(draft.quantityValue) quantity_unit=\(draft.quantityUnit.rawValue)")
            }
            importFeedbackText = importQualityFeedbackText(for: suggestion.confidence)
            showCaptionImportHint = suggestion.confidence == .low
        } else {
            ingredientDrafts = [CreateIngredientDraft()]
            importFeedbackText = importQualityFeedbackText(for: .low)
            showCaptionImportHint = true
        }

        print("[SEASON_IMPORT] phase=import_applied source_url=\(sourceURL) extracted_ingredients=\(suggestion.suggestedIngredients.count) extracted_steps=\(mappedSteps.count) confidence=\(suggestion.confidence.rawValue)")
    }

    private func socialImportSuggestionFromServerResponse(
        _ response: ParseRecipeCaptionFunctionResponse,
        sourceURL: String,
        fallbackCaption: String
    ) -> SocialImportSuggestion? {
        guard response.ok, let result = response.result else { return nil }

        let mappedIngredients: [RecipeIngredient] = result.ingredients.compactMap { item in
            let cleanedName = removingEmojis(from: item.name).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedName.isEmpty else { return nil }
            print(
                "[SEASON_IMPORT] stage=A_raw_imported " +
                "name=\(cleanedName) quantity=\(item.quantity.map { String($0) } ?? "nil") unit=\(item.unit ?? "nil")"
            )

            var unit = RecipeQuantityUnit(rawValue: (item.unit ?? "").lowercased()) ?? .piece
            var quantity: Double = {
                if let provided = item.quantity {
                    return max(0.0001, provided)
                }
                // Preserve unknown measured quantities from LLM (e.g. unit=g/ml with null quantity)
                // instead of forcing synthetic "1".
                if unit == .g || unit == .ml {
                    return -1
                }
                // Keep piece-like natural fallback behavior unchanged.
                return 1
            }()
            var rawLine = cleanedName
            var mappedName = normalizedCommonIngredientPhrase(cleanedName)

            if let recovered = recoverExplicitQuantityFromCaption(
                ingredientName: cleanedName,
                caption: fallbackCaption
            ) {
                print(
                    "[SEASON_IMPORT] phase=explicit_quantity_recovered_from_raw " +
                    "name=\(cleanedName) recovered_name=\(recovered.cleanedName) " +
                    "quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                )
                rawLine = recovered.sourceLine
                let shouldOverride = shouldOverrideServerQuantityWithRaw(
                    ingredient: RecipeIngredient(
                        produceID: nil,
                        basicIngredientID: nil,
                        quality: .basic,
                        name: mappedName,
                        quantityValue: quantity,
                        quantityUnit: unit,
                        rawIngredientLine: rawLine,
                        mappingConfidence: .unmapped
                    ),
                    recovery: recovered
                )
                if shouldOverride {
                    print(
                        "[SEASON_IMPORT] phase=server_quantity_overridden_from_raw " +
                        "name=\(cleanedName) old_quantity=\(quantityValueString(quantity)) old_unit=\(unit.rawValue) " +
                        "new_quantity=\(quantityValueString(recovered.quantityValue)) new_unit=\(recovered.quantityUnit.rawValue)"
                    )
                    quantity = recovered.quantityValue
                    unit = recovered.quantityUnit
                }
                mappedName = recovered.cleanedName
            }

            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: nil,
                quality: .basic,
                name: mappedName,
                quantityValue: quantity,
                quantityUnit: unit,
                rawIngredientLine: rawLine,
                mappingConfidence: .unmapped
            )
        }

        let mappedSteps = result.steps
            .map { removingEmojis(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return SocialImportSuggestion(
            sourceURL: sourceURL,
            sourcePlatform: detectedPlatform(for: sourceURL),
            sourceCaptionRaw: fallbackCaption.isEmpty ? nil : fallbackCaption,
            suggestedTitle: cleanedTitle(result.title ?? ""),
            suggestedIngredients: mappedIngredients,
            suggestedSteps: mappedSteps,
            confidence: socialImportConfidence(from: result.confidence)
        )
    }

    private func socialImportConfidence(from rawValue: String) -> SocialImportConfidence {
        SocialImportConfidence(rawValue: rawValue.lowercased()) ?? .low
    }

    private func isServerSuggestionUseful(_ suggestion: SocialImportSuggestion) -> Bool {
        if !suggestion.suggestedIngredients.isEmpty || !suggestion.suggestedSteps.isEmpty {
            return true
        }

        let titleCandidate = suggestion.suggestedTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return !titleCandidate.isEmpty && titleCandidate != "untitled recipe"
    }

    private func importQualityFeedbackText(for confidence: SocialImportConfidence) -> String {
        switch confidence {
        case .high:
            return localizer.text(.importQualityHigh)
        case .medium:
            return localizer.text(.importQualityMedium)
        case .low:
            return localizer.text(.importQualityLow)
        }
    }

    private func normalizedImportedIngredientDraft(from ingredient: RecipeIngredient) -> CreateIngredientDraft {
        print("[SEASON_IMPORT] stage=A_raw_imported name=\(ingredient.name) quantity=\(ingredient.quantityValue) unit=\(ingredient.quantityUnit.rawValue)")
        let hasCatalogMapping = ingredient.produceID != nil || ingredient.basicIngredientID != nil
        if hasCatalogMapping {
            // Preserve existing mapped behavior for produce/basic ingredients.
            let draft = CreateIngredientDraft(
                produceID: ingredient.produceID ?? "",
                basicIngredientID: ingredient.basicIngredientID ?? "",
                customName: "",
                searchText: removingEmojis(from: ingredient.name).trimmingCharacters(in: .whitespacesAndNewlines),
                quantityValue: quantityValueString(ingredient.quantityValue),
                quantityUnit: ingredient.quantityUnit
            )
            print("[SEASON_IMPORT] stage=C_match_decision decision=pre_mapped")
            print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
            return draft
        }

        let trimmedName = removingEmojis(from: ingredient.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return customImportedIngredientDraft(name: "")
        }

        if isIngredientSubsectionHeader(trimmedName) {
            // Keep subsection labels editable but avoid treating them as measured ingredients.
            return customImportedIngredientDraft(name: trimmedName)
        }

        if isQuantoBastaIngredient(trimmedName) {
            // Preserve natural "q.b." lines without forcing numeric measurement semantics.
            return customImportedIngredientDraft(name: cleanedQuantoBastaName(from: trimmedName))
        }

        let rawSourceLine = ingredient.rawIngredientLine?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedName
        let explicitRecovery = explicitQuantityRecoveryCandidate(
            ingredientName: trimmedName,
            rawSourceLine: rawSourceLine,
            caption: importCaptionRaw
        )

        if let recovered = explicitRecovery,
           shouldOverrideServerQuantityWithRaw(ingredient: ingredient, recovery: recovered) {
            let recoveredQuery = normalizedCommonIngredientPhrase(recovered.cleanedName)
            print(
                "[SEASON_IMPORT] phase=explicit_quantity_recovered_from_raw " +
                "name=\(trimmedName) recovered_name=\(recoveredQuery) " +
                "quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
            )
            print(
                "[SEASON_IMPORT] phase=server_quantity_overridden_from_raw " +
                "name=\(trimmedName) old_quantity=\(quantityValueString(ingredient.quantityValue)) old_unit=\(ingredient.quantityUnit.rawValue) " +
                "new_quantity=\(quantityValueString(recovered.quantityValue)) new_unit=\(recovered.quantityUnit.rawValue)"
            )

            if let resolved = resolveImportedIngredientMatch(query: recoveredQuery) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(recoveredQuery) match=\(resolvedDecisionLabel(resolved))")
                print(
                    "[SEASON_IMPORT] phase=explicit_quantity_applied_to_final_draft " +
                    "name=\(recoveredQuery) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                )
                print(
                    "[SEASON_IMPORT] phase=final_measured_quantity_value " +
                    "name=\(recoveredQuery) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                )
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: recovered.quantityValue,
                    quantityUnit: recovered.quantityUnit
                )
            }

            print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(recoveredQuery)")
            return CreateIngredientDraft(
                produceID: "",
                basicIngredientID: "",
                customName: recoveredQuery,
                searchText: recoveredQuery,
                quantityValue: quantityValueString(recovered.quantityValue),
                quantityUnit: recovered.quantityUnit
            )
        }

        // Unknown measured quantity from LLM (quantity null + unit g/ml) should stay empty in draft
        // instead of being forced to synthetic "1".
        if ingredient.quantityValue < 0, ingredient.quantityUnit == .g || ingredient.quantityUnit == .ml {
            let cleanedName = normalizedCommonIngredientPhrase(
                normalizedImportedNameWithoutLeadingUnit(trimmedName, unit: ingredient.quantityUnit)
            )
            if let resolved = resolveImportedIngredientMatch(query: cleanedName) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(cleanedName) match=\(resolvedDecisionLabel(resolved))")
                if let recovered = explicitRecovery {
                    print(
                        "[SEASON_IMPORT] phase=explicit_quantity_applied_to_final_draft " +
                        "name=\(cleanedName) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                    )
                    print(
                        "[SEASON_IMPORT] phase=final_measured_quantity_value " +
                        "name=\(cleanedName) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                    )
                    return catalogMatchedImportedDraft(
                        from: resolved,
                        quantityValue: recovered.quantityValue,
                        quantityUnit: recovered.quantityUnit
                    )
                }
                let draft: CreateIngredientDraft
                switch resolved {
                case .produce(let item):
                    draft = CreateIngredientDraft(
                        produceID: item.id,
                        basicIngredientID: "",
                        customName: "",
                        searchText: item.displayName(languageCode: localizer.languageCode),
                        quantityValue: "",
                        quantityUnit: ingredient.quantityUnit
                    )
                case .basic(let item):
                    draft = CreateIngredientDraft(
                        produceID: "",
                        basicIngredientID: item.id,
                        customName: "",
                        searchText: item.displayName(languageCode: localizer.languageCode),
                        quantityValue: "",
                        quantityUnit: ingredient.quantityUnit
                    )
                }
                print("[SEASON_IMPORT] stage=B_after_normalization cleanedName=\(cleanedName) quantityValue=empty quantityUnit=\(ingredient.quantityUnit.rawValue)")
                print("[SEASON_IMPORT] stage=C_match_decision decision=\(resolvedDecisionLabel(resolved))")
                print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
                return draft
            }

            print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(cleanedName)")
            let draft = CreateIngredientDraft(
                produceID: "",
                basicIngredientID: "",
                customName: cleanedName,
                searchText: cleanedName,
                quantityValue: "",
                quantityUnit: ingredient.quantityUnit
            )
            print("[SEASON_IMPORT] stage=B_after_normalization cleanedName=\(cleanedName) quantityValue=empty quantityUnit=\(ingredient.quantityUnit.rawValue)")
            print("[SEASON_IMPORT] stage=C_match_decision decision=custom")
            print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
            return draft
        }

        // Preserve trusted quantity/unit coming from import suggestions (especially server fallback),
        // then still try to resolve catalog matching without resetting semantics.
        if shouldPreserveProvidedImportedQuantity(ingredient, normalizedName: trimmedName) {
            let providedQuantity = max(0.0001, ingredient.quantityValue)
            let preservedUnit = ingredient.quantityUnit
            let normalizedMeasured = normalizedImportedMeasurement(
                trimmedName,
                providedQuantityValue: providedQuantity,
                quantityUnit: preservedUnit
            )
            let preservedQuantity = normalizedMeasured.quantityValue
            let cleanedName = normalizedMeasured.cleanedName
            let matchQuery = normalizedCommonIngredientPhrase(cleanedName.isEmpty ? trimmedName : cleanedName)
            print("[SEASON_IMPORT] stage=B_after_normalization cleanedName=\(matchQuery) quantityValue=\(quantityValueString(preservedQuantity)) quantityUnit=\(preservedUnit.rawValue)")
            if let resolved = resolveImportedIngredientMatch(query: matchQuery) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(matchQuery) match=\(resolvedDecisionLabel(resolved))")
                print("[SEASON_IMPORT] stage=C_match_decision decision=\(resolvedDecisionLabel(resolved))")
                if let recovered = explicitRecovery,
                   shouldOverrideServerQuantityWithRaw(ingredient: ingredient, recovery: recovered) {
                    print(
                        "[SEASON_IMPORT] phase=explicit_quantity_applied_to_final_draft " +
                        "name=\(matchQuery) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                    )
                    print(
                        "[SEASON_IMPORT] phase=final_measured_quantity_value " +
                        "name=\(matchQuery) quantity=\(quantityValueString(recovered.quantityValue)) unit=\(recovered.quantityUnit.rawValue)"
                    )
                    let recoveredDraft = catalogMatchedImportedDraft(
                        from: resolved,
                        quantityValue: recovered.quantityValue,
                        quantityUnit: recovered.quantityUnit
                    )
                    print("[SEASON_IMPORT] stage=D_final_draft searchText=\(recoveredDraft.searchText) customName=\(recoveredDraft.customName) quantityValue=\(recoveredDraft.quantityValue) quantityUnit=\(recoveredDraft.quantityUnit.rawValue)")
                    return recoveredDraft
                }
                let draft = catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: preservedQuantity,
                    quantityUnit: preservedUnit
                )
                print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
                return draft
            }
            print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(matchQuery)")
            print("[SEASON_IMPORT] stage=C_match_decision decision=custom")
            let draft = CreateIngredientDraft(
                produceID: "",
                basicIngredientID: "",
                customName: matchQuery,
                searchText: matchQuery,
                quantityValue: quantityValueString(preservedQuantity),
                quantityUnit: preservedUnit
            )
            print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
            return draft
        }

        if let fractional = parsedFractionalPieceIngredient(from: trimmedName) {
            let normalizedFractionalCore = normalizedCommonIngredientPhrase(fractional.coreName)
            if let resolved = resolveImportedIngredientMatch(query: normalizedFractionalCore) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(normalizedFractionalCore) match=\(resolvedDecisionLabel(resolved))")
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: fractional.quantity,
                    quantityUnit: .piece
                )
            }
            print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(normalizedFractionalCore)")
            return CreateIngredientDraft(
                produceID: "",
                basicIngredientID: "",
                customName: trimmedName,
                searchText: trimmedName,
                quantityValue: quantityValueString(fractional.quantity),
                quantityUnit: .piece
            )
        }

        let pattern = #"^(\d+)\s*(g|kg|ml|l)?\s*(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            let normalizedBare = normalizedCommonIngredientPhrase(trimmedName)
            let logPieceFlow = isNormalizedPiecePhraseCandidate(original: trimmedName, normalized: normalizedBare)
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_sent_to_unified raw=\(trimmedName) normalized=\(normalizedBare)")
            }
            if let resolved = resolveImportedIngredientMatch(query: normalizedBare) {
                if logPieceFlow {
                    print("[SEASON_IMPORT] phase=normalized_piece_phrase_matched_unified normalized=\(normalizedBare) match=\(resolvedDecisionLabel(resolved))")
                }
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: max(1, ingredient.quantityValue),
                    quantityUnit: ingredient.quantityUnit
                )
            }
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_fell_back_custom normalized=\(normalizedBare)")
            }
            return customImportedIngredientDraft(name: normalizedBare)
        }

        let fullRange = NSRange(location: 0, length: trimmedName.utf16.count)
        guard let match = regex.firstMatch(in: trimmedName, options: [], range: fullRange),
              match.numberOfRanges == 4 else {
            let normalizedBare = normalizedCommonIngredientPhrase(trimmedName)
            let logPieceFlow = isNormalizedPiecePhraseCandidate(original: trimmedName, normalized: normalizedBare)
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_sent_to_unified raw=\(trimmedName) normalized=\(normalizedBare)")
            }
            if let resolved = resolveImportedIngredientMatch(query: normalizedBare) {
                if logPieceFlow {
                    print("[SEASON_IMPORT] phase=normalized_piece_phrase_matched_unified normalized=\(normalizedBare) match=\(resolvedDecisionLabel(resolved))")
                }
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: max(1, ingredient.quantityValue),
                    quantityUnit: ingredient.quantityUnit
                )
            }
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_fell_back_custom normalized=\(normalizedBare)")
            }
            return customImportedIngredientDraft(name: normalizedBare)
        }

        let quantityText = nsRangeString(match.range(at: 1), in: trimmedName)
        let unitToken = nsRangeString(match.range(at: 2), in: trimmedName)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedName = nsRangeString(match.range(at: 3), in: trimmedName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = parsedName.isEmpty ? trimmedName : parsedName

        guard let baseQuantity = Int(quantityText) else {
            return customImportedIngredientDraft(name: fallbackName)
        }

        // Natural phrase like "1 carota": attempt catalog match using parsed name,
        // then fall back to preserving original line as editable custom text.
        if unitToken.isEmpty {
            let normalizedFallback = normalizedCommonIngredientPhrase(fallbackName)
            let logPieceFlow = isNormalizedPiecePhraseCandidate(original: fallbackName, normalized: normalizedFallback)
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_sent_to_unified raw=\(fallbackName) normalized=\(normalizedFallback)")
            }
            if let resolved = resolveImportedIngredientMatch(query: normalizedFallback) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(normalizedFallback) match=\(resolvedDecisionLabel(resolved))")
                if logPieceFlow {
                    print("[SEASON_IMPORT] phase=normalized_piece_phrase_matched_unified normalized=\(normalizedFallback) match=\(resolvedDecisionLabel(resolved))")
                }
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: Double(baseQuantity),
                    quantityUnit: .piece
                )
            }
            if logPieceFlow {
                print("[SEASON_IMPORT] phase=normalized_piece_phrase_fell_back_custom normalized=\(normalizedFallback)")
            }
            print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(normalizedFallback)")
            return customImportedIngredientDraft(name: trimmedName)
        }

        let unitForMapping = unitToken
        let (quantityValue, quantityUnit): (Double, RecipeQuantityUnit) = {
            switch unitForMapping {
            case "g":
                return (Double(baseQuantity), .g)
            case "kg":
                return (Double(baseQuantity * 1000), .g)
            case "ml":
                return (Double(baseQuantity), .ml)
            case "l":
                return (Double(baseQuantity * 1000), .ml)
            case "piece":
                return (Double(baseQuantity), .piece)
            default:
                return (Double(baseQuantity), .g)
            }
        }()

        let normalizedFallbackName = normalizedCommonIngredientPhrase(fallbackName)
        if let resolved = resolveImportedIngredientMatch(query: normalizedFallbackName) {
            print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(normalizedFallbackName) match=\(resolvedDecisionLabel(resolved))")
            return catalogMatchedImportedDraft(
                from: resolved,
                quantityValue: quantityValue,
                quantityUnit: quantityUnit
            )
        }

        print("[SEASON_IMPORT] phase=ingredient_kept_custom raw=\(trimmedName) normalized=\(normalizedFallbackName)")
        return CreateIngredientDraft(
            produceID: "",
            basicIngredientID: "",
            customName: normalizedFallbackName,
            searchText: normalizedFallbackName,
            quantityValue: quantityValueString(quantityValue),
            quantityUnit: quantityUnit
        )
    }

    private func catalogMatchedImportedDraft(
        from resolved: ImportedIngredientMatch,
        quantityValue: Double,
        quantityUnit: RecipeQuantityUnit
    ) -> CreateIngredientDraft {
        let explicitQuantityProvided = quantityUnit != .piece || abs(quantityValue - 1) > 0.001
        switch resolved {
        case .produce(let item):
            let draft = CreateIngredientDraft(
                produceID: item.id,
                basicIngredientID: "",
                customName: "",
                searchText: item.displayName(languageCode: localizer.languageCode),
                quantityValue: quantityValueString(quantityValue),
                quantityUnit: quantityUnit
            )
            return applyingNonCountableQuantitySemantics(
                to: draft,
                ingredientName: item.displayName(languageCode: localizer.languageCode),
                explicitQuantityProvided: explicitQuantityProvided
            )
        case .basic(let item):
            let draft = CreateIngredientDraft(
                produceID: "",
                basicIngredientID: item.id,
                customName: "",
                searchText: item.displayName(languageCode: localizer.languageCode),
                quantityValue: quantityValueString(quantityValue),
                quantityUnit: quantityUnit
            )
            return applyingNonCountableQuantitySemantics(
                to: draft,
                ingredientName: item.displayName(languageCode: localizer.languageCode),
                explicitQuantityProvided: explicitQuantityProvided
            )
        }
    }

    private func customImportedIngredientDraft(name: String) -> CreateIngredientDraft {
        let normalized = removingEmojis(from: name).trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = CreateIngredientDraft(
            produceID: "",
            basicIngredientID: "",
            customName: normalized,
            searchText: normalized,
            quantityValue: quantityValueString(1),
            quantityUnit: .piece
        )
        return applyingNonCountableQuantitySemantics(
            to: draft,
            ingredientName: normalized,
            explicitQuantityProvided: false
        )
    }

    private var nonCountableIngredientKeywords: Set<String> {
        [
            "salt", "sale",
            "pepper", "black pepper", "pepe nero",
            "basil", "basilico",
            "parsley", "prezzemolo",
            "spice", "spices", "spezia", "spezie",
            "herb", "herbs", "erba", "erbe"
        ]
    }

    private func isNonCountableIngredientName(_ raw: String) -> Bool {
        let normalized = normalizedIngredientMatchText(raw)
        guard !normalized.isEmpty else { return false }
        if nonCountableIngredientKeywords.contains(normalized) {
            return true
        }
        return nonCountableIngredientKeywords.contains { keyword in
            queryContainsPhrase(normalized, phrase: keyword)
        }
    }

    private func applyingNonCountableQuantitySemantics(
        to draft: CreateIngredientDraft,
        ingredientName: String,
        explicitQuantityProvided: Bool
    ) -> CreateIngredientDraft {
        guard !explicitQuantityProvided else { return draft }
        guard draft.quantityUnit == .piece else { return draft }
        guard abs(parsedQuantityValue(draft.quantityValue) - 1) < 0.001 else { return draft }
        guard isNonCountableIngredientName(ingredientName) else { return draft }

        print("[SEASON_IMPORT] phase=non_countable_detected ingredient=\(ingredientName)")
        var updated = draft
        updated.quantityValue = ""
        print("[SEASON_IMPORT] phase=non_countable_quantity_removed ingredient=\(ingredientName)")
        return updated
    }

    private func shouldPreserveProvidedImportedQuantity(
        _ ingredient: RecipeIngredient,
        normalizedName: String
    ) -> Bool {
        let quantity = ingredient.quantityValue
        guard quantity > 0 else { return false }

        if hasExplicitPieceToken(normalizedName) {
            return true
        }

        if ingredient.quantityUnit != .piece {
            return true
        }

        return abs(quantity - 1) > 0.001
    }

    private func normalizedImportedMeasurement(
        _ rawName: String,
        providedQuantityValue: Double,
        quantityUnit: RecipeQuantityUnit
    ) -> (cleanedName: String, quantityValue: Double) {
        var cleaned = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return (rawName, providedQuantityValue) }

        var quantityValue = providedQuantityValue

        let unitToken = quantityUnit.rawValue
        let escapedUnit = NSRegularExpression.escapedPattern(for: unitToken)
        let quantityPrefix = quantityValueString(providedQuantityValue)
        let escapedQuantity = NSRegularExpression.escapedPattern(for: quantityPrefix)

        // Remove duplicated leading "<quantity><unit>" fragments when quantity/unit are already structured.
        let explicitMeasuredPrefix = #"^\s*"# + escapedQuantity + #"\s*"# + escapedUnit + #"\s+"#
        cleaned = cleaned.replacingOccurrences(
            of: explicitMeasuredPrefix,
            with: "",
            options: .regularExpression
        )

        // Also handle "g pasta" style remnants where quantity was stripped but unit stayed in front.
        let unitOnlyPrefix = #"^\s*"# + escapedUnit + #"\s+"#
        cleaned = cleaned.replacingOccurrences(
            of: unitOnlyPrefix,
            with: "",
            options: .regularExpression
        )

        // If the name still starts with "<number><unit>", recover quantity from text.
        let measuredPrefixPattern = #"^\s*(\d+(?:[.,]\d+)?)\s*"# + escapedUnit + #"\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: measuredPrefixPattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            if let match = regex.firstMatch(in: cleaned, options: [], range: range),
               match.numberOfRanges == 3 {
                let quantityText = nsRangeString(match.range(at: 1), in: cleaned)
                    .replacingOccurrences(of: ",", with: ".")
                let remainingName = nsRangeString(match.range(at: 2), in: cleaned)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = Double(quantityText), parsed > 0 {
                    quantityValue = parsed
                }
                cleaned = remainingName
            }
        }

        let normalized = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized.isEmpty ? rawName : normalized, quantityValue)
    }

    private struct ExplicitQuantityRecovery {
        let quantityValue: Double
        let quantityUnit: RecipeQuantityUnit
        let cleanedName: String
        let sourceLine: String
    }

    private func parsedExplicitQuantityRecovery(from rawLine: String) -> ExplicitQuantityRecovery? {
        let cleanedLine = rawLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[\-\*\•\·]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedLine.isEmpty else { return nil }
        guard !isQuantoBastaIngredient(cleanedLine) else { return nil }
        let forwardPattern = #"(?i)(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|clove|cloves|piece|pieces)\s+([^,;\n]+)"#
        let reversedPattern = #"(?i)^([^,;\n]+?)\s+(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|clove|cloves|piece|pieces)\s*$"#

        func mappedUnitAndQuantity(_ quantityRawValue: String, unitRawValue: String) -> (value: Double, unit: RecipeQuantityUnit)? {
            let normalizedQuantity = quantityRawValue
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let baseQuantity = Double(normalizedQuantity), baseQuantity > 0 else { return nil }

            let unitRaw = unitRawValue
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch unitRaw {
            case "g":
                return (baseQuantity, .g)
            case "kg":
                return (baseQuantity * 1000, .g)
            case "ml":
                return (baseQuantity, .ml)
            case "l":
                return (baseQuantity * 1000, .ml)
            case "tbsp":
                return (baseQuantity, .tbsp)
            case "tsp":
                return (baseQuantity, .tsp)
            case "clove", "cloves", "piece", "pieces":
                return (baseQuantity, .piece)
            default:
                return nil
            }
        }

        func normalizedRecoveredName(_ raw: String) -> String {
            var nameRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            nameRaw = nameRaw.replacingOccurrences(
                of: #"(?i)^(di|of)\s+"#,
                with: "",
                options: .regularExpression
            )
            nameRaw = nameRaw.replacingOccurrences(
                of: #"(?i)^(ingredienti|ingredients)\s*:\s*"#,
                with: "",
                options: .regularExpression
            )
            let normalizedName = normalizedCommonIngredientPhrase(nameRaw)
            return normalizedName.isEmpty ? nameRaw : normalizedName
        }

        let fullRange = NSRange(location: 0, length: cleanedLine.utf16.count)

        // Pass 1: existing forward format.
        if let regex = try? NSRegularExpression(pattern: forwardPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: cleanedLine, options: [], range: fullRange),
           match.numberOfRanges == 4 {
            let quantityRaw = nsRangeString(match.range(at: 1), in: cleanedLine)
            let unitRaw = nsRangeString(match.range(at: 2), in: cleanedLine)
            let recoveredName = normalizedRecoveredName(nsRangeString(match.range(at: 3), in: cleanedLine))
            guard !recoveredName.isEmpty,
                  let mapped = mappedUnitAndQuantity(quantityRaw, unitRawValue: unitRaw) else { return nil }
            return ExplicitQuantityRecovery(
                quantityValue: mapped.value,
                quantityUnit: mapped.unit,
                cleanedName: recoveredName,
                sourceLine: cleanedLine
            )
        }

        // Pass 2: reversed format "<ingredient> <number> <unit>".
        if let regex = try? NSRegularExpression(pattern: reversedPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: cleanedLine, options: [], range: fullRange),
           match.numberOfRanges == 4 {
            let recoveredName = normalizedRecoveredName(nsRangeString(match.range(at: 1), in: cleanedLine))
            let quantityRaw = nsRangeString(match.range(at: 2), in: cleanedLine)
            let unitRaw = nsRangeString(match.range(at: 3), in: cleanedLine)
            guard !recoveredName.isEmpty,
                  let mapped = mappedUnitAndQuantity(quantityRaw, unitRawValue: unitRaw) else { return nil }

            print(
                "[SEASON_IMPORT] phase=explicit_quantity_recovered_reversed_format " +
                "line=\(cleanedLine) name=\(recoveredName) " +
                "quantity=\(quantityValueString(mapped.value)) unit=\(mapped.unit.rawValue)"
            )

            return ExplicitQuantityRecovery(
                quantityValue: mapped.value,
                quantityUnit: mapped.unit,
                cleanedName: recoveredName,
                sourceLine: cleanedLine
            )
        }

        return nil
    }

    private func explicitQuantityRecoveryCandidate(
        ingredientName: String,
        rawSourceLine: String,
        caption: String
    ) -> ExplicitQuantityRecovery? {
        let normalizedIngredient = normalizedIngredientMatchText(ingredientName)
        print(
            "[SEASON_IMPORT] phase=explicit_quantity_recovery_start " +
            "ingredient=\(ingredientName) normalized=\(normalizedIngredient) raw_source=\(rawSourceLine)"
        )

        // Prioritize exact line match (raw source line) before caption-wide scan.
        if let direct = parsedExplicitQuantityRecovery(from: rawSourceLine) {
            print(
                "[SEASON_IMPORT] phase=explicit_quantity_candidate_found " +
                "source=raw_line line=\(direct.sourceLine) name=\(direct.cleanedName) " +
                "quantity=\(quantityValueString(direct.quantityValue)) unit=\(direct.quantityUnit.rawValue)"
            )
            return direct
        } else {
            print("[SEASON_IMPORT] phase=explicit_quantity_candidate_rejected source=raw_line reason=regex_no_match line=\(rawSourceLine)")
        }

        let lines = caption
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        print("[SEASON_IMPORT] phase=explicit_quantity_caption_scan line_count=\(lines.count)")

        for line in lines {
            if let candidate = parsedExplicitQuantityRecovery(from: line) {
                print(
                    "[SEASON_IMPORT] phase=explicit_quantity_candidate_found " +
                    "source=caption_line line=\(candidate.sourceLine) name=\(candidate.cleanedName) " +
                    "quantity=\(quantityValueString(candidate.quantityValue)) unit=\(candidate.quantityUnit.rawValue)"
                )
            } else {
                print("[SEASON_IMPORT] phase=explicit_quantity_candidate_rejected source=caption_line reason=regex_no_match line=\(line)")
            }
        }

        if let fromCaption = recoverExplicitQuantityFromCaption(
            ingredientName: ingredientName,
            caption: caption
        ) {
            return fromCaption
        }

        print("[SEASON_IMPORT] phase=explicit_quantity_candidate_rejected source=caption reason=no_candidate_accepted")
        return nil
    }

    private func shouldOverrideServerQuantityWithRaw(
        ingredient: RecipeIngredient,
        recovery: ExplicitQuantityRecovery
    ) -> Bool {
        if ingredient.quantityValue <= 0 {
            return true
        }
        if ingredient.quantityUnit != recovery.quantityUnit {
            return true
        }
        if abs(ingredient.quantityValue - recovery.quantityValue) > 0.001 {
            return true
        }
        return false
    }

    private func recoverExplicitQuantityFromCaption(
        ingredientName: String,
        caption: String
    ) -> ExplicitQuantityRecovery? {
        let target = normalizedIngredientMatchText(ingredientName)
        guard !target.isEmpty else { return nil }
        let targetQueries = Set(importedIngredientMatchQueries(from: ingredientName))

        let lines = caption
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var best: (recovery: ExplicitQuantityRecovery, score: Int)?
        for line in lines {
            guard let recovery = parsedExplicitQuantityRecovery(from: line) else { continue }
            let recoveredName = normalizedIngredientMatchText(recovery.cleanedName)
            guard !recoveredName.isEmpty else { continue }

            var score = 0
            if recoveredName == target || targetQueries.contains(recoveredName) {
                score = 3
            } else if targetQueries.contains(where: { $0.contains(recoveredName) || recoveredName.contains($0) }) {
                score = 2
            } else {
                let targetTokens = Set(targetQueries.flatMap { $0.split(separator: " ").map(String.init) })
                let recoveredTokens = Set(recoveredName.split(separator: " ").map(String.init))
                if !targetTokens.isDisjoint(with: recoveredTokens) {
                    score = 1
                }
            }

            guard score > 0 else {
                print(
                    "[SEASON_IMPORT] phase=explicit_quantity_candidate_rejected " +
                    "source=caption_line reason=name_mismatch line=\(recovery.sourceLine) " +
                    "target=\(target) recovered=\(recoveredName)"
                )
                continue
            }
            if best == nil || score > best!.score {
                best = (recovery, score)
            }
        }

        if let best {
            print(
                "[SEASON_IMPORT] phase=explicit_quantity_candidate_accepted " +
                "line=\(best.recovery.sourceLine) name=\(best.recovery.cleanedName) " +
                "quantity=\(quantityValueString(best.recovery.quantityValue)) unit=\(best.recovery.quantityUnit.rawValue)"
            )
        }

        return best?.recovery
    }

    private func normalizedImportedNameWithoutLeadingUnit(_ rawName: String, unit: RecipeQuantityUnit) -> String {
        let escapedUnit = NSRegularExpression.escapedPattern(for: unit.rawValue)
        let cleaned = rawName.replacingOccurrences(
            of: #"^\s*"# + escapedUnit + #"\s+"#,
            with: "",
            options: .regularExpression
        )
        let normalized = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? rawName : normalized
    }

    private func resolvedDecisionLabel(_ resolved: ImportedIngredientMatch) -> String {
        switch resolved {
        case .produce:
            return "produce"
        case .basic:
            return "basic"
        }
    }

    private func isQuantoBastaIngredient(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.contains("quanto basta") { return true }
        let pattern = #"\bq\s*\.?\s*b\s*\.?\b|\bqb\b"#
        return lowered.range(of: pattern, options: .regularExpression) != nil
    }

    private func cleanedQuantoBastaName(from line: String) -> String {
        var cleaned = line.replacingOccurrences(
            of: #"(?i)\bquanto basta\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\bq\s*\.?\s*b\s*\.?\b|\bqb\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-"))
        return cleaned.isEmpty ? line.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    private func parsedFractionalPieceIngredient(from line: String) -> (quantity: Double, coreName: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Keep explicit measured-unit parsing in the existing flow.
        if trimmed.range(of: #"(?i)\b(g|kg|ml|l)\b"#, options: .regularExpression) != nil {
            return nil
        }

        let lower = trimmed.lowercased()
        let patterns: [(pattern: String, quantity: Double)] = [
            (#"^(mezza|mezzo)\s+(.+)$"#, 0.5),
            (#"^(half)\s+(.+)$"#, 0.5),
            (#"^(quarter)\s+(.+)$"#, 0.25),
            (#"^(1/2)\s+(.+)$"#, 0.5),
            (#"^(1/4)\s+(.+)$"#, 0.25),
            (#"^(3/4)\s+(.+)$"#, 0.75)
        ]

        for entry in patterns {
            guard let regex = try? NSRegularExpression(pattern: entry.pattern, options: [.caseInsensitive]) else {
                continue
            }
            let fullRange = NSRange(location: 0, length: lower.utf16.count)
            guard let match = regex.firstMatch(in: lower, options: [], range: fullRange),
                  match.numberOfRanges >= 3 else {
                continue
            }

            let core = nsRangeString(match.range(at: 2), in: trimmed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !core.isEmpty else { return nil }
            if core.range(of: #"(?i)\b(g|kg|ml|l)\b"#, options: .regularExpression) != nil {
                return nil
            }
            return (entry.quantity, core)
        }

        return nil
    }

    private func isIngredientSubsectionHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(":") else { return false }
        let body = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 2 else { return false }
        return body.rangeOfCharacter(from: .letters) != nil
    }

    private func nsRangeString(_ range: NSRange, in source: String) -> String {
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: source) else {
            return ""
        }
        return String(source[swiftRange])
    }

    private var canImportFromAnyLink: Bool {
        guard let sourceURL = normalizedImportSourceURL else { return false }
        guard let parsed = URL(string: sourceURL) else { return false }
        guard let scheme = parsed.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return parsed.host?.isEmpty == false
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func supportedUnits(for draft: CreateIngredientDraft) -> [RecipeQuantityUnit] {
        if !draft.produceID.isEmpty {
            return viewModel.quantityProfile(forProduceID: draft.produceID).supportedUnits
        }
        if let basic = viewModel.basicIngredient(forID: draft.basicIngredientID) {
            return basic.unitProfile.supportedUnits
        }
        return [.g, .piece]
    }

    private func ingredientMatches(for draft: CreateIngredientDraft) -> [IngredientSearchResult] {
        let query = draft.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return viewModel.searchIngredientResults(query: query)
    }

    private func ingredientIsCustom(_ draft: CreateIngredientDraft) -> Bool {
        draft.produceID.isEmpty
        && draft.basicIngredientID.isEmpty
        && !draft.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func shouldHideQuantityControls(for draft: CreateIngredientDraft) -> Bool {
        if isSubsectionHeaderDraft(draft) { return true }
        if isNonCountableDraftWithoutSyntheticQuantity(draft) { return true }
        return isSyntheticCustomFallbackIngredientDraft(draft)
    }

    private func isSubsectionHeaderDraft(_ draft: CreateIngredientDraft) -> Bool {
        let displayName = ingredientDraftDisplayName(draft).trimmingCharacters(in: .whitespacesAndNewlines)
        return ingredientIsCustom(draft) && isIngredientSubsectionHeader(displayName)
    }

    private func looksNaturalPieceLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^\d+\s+[^\d].+$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return false }
        let lower = trimmed.lowercased()
        let explicitUnitPattern = #"^\d+\s*(g|kg|ml|l)\b"#
        return lower.range(of: explicitUnitPattern, options: .regularExpression) == nil
    }

    private func containsMultipleWords(_ line: String) -> Bool {
        line
            .split(whereSeparator: { $0.isWhitespace })
            .count > 1
    }

    private func isSyntheticCustomFallbackIngredientDraft(
        _ draft: CreateIngredientDraft,
        resolvedName: String? = nil
    ) -> Bool {
        guard ingredientIsCustom(draft) else { return false }
        let displayName = (resolvedName ?? ingredientDraftDisplayName(draft))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else { return false }
        guard !isIngredientSubsectionHeader(displayName) else { return false }

        let hasSyntheticPieceQuantity = draft.quantityUnit == .piece
            && abs(parsedQuantityValue(draft.quantityValue) - 1) < 0.001
        guard hasSyntheticPieceQuantity else { return false }

        if hasExplicitPieceToken(displayName) {
            return false
        }
        if isQuantoBastaIngredient(displayName) { return true }
        if looksNaturalPieceLine(displayName) { return true }
        if !looksExplicitMeasuredLine(displayName) { return true }
        return containsMultipleWords(displayName)
    }

    private func isNonCountableDraftWithoutSyntheticQuantity(_ draft: CreateIngredientDraft) -> Bool {
        guard draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let name = ingredientDraftDisplayName(draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return isNonCountableIngredientName(name)
    }

    private func observeUnresolvedCustomIngredients(latestRecipeID: String?) {
        let ingredients = recipeIngredientsForPublish
        print("[SEASON_OBSERVATION] phase=observation_pipeline_stage=final_draft ingredient_count=\(ingredients.count)")
        let observations = unresolvedCustomIngredientObservations(
            from: ingredients,
            latestRecipeID: latestRecipeID
        )
        guard !observations.isEmpty else { return }

        Task {
            await SupabaseService.shared.observeCustomIngredientObservations(observations)
        }
    }

    private func unresolvedCustomIngredientObservations(
        from ingredients: [RecipeIngredient],
        latestRecipeID: String?
    ) -> [CustomIngredientObservation] {
        var seen = Set<String>()
        var observations: [CustomIngredientObservation] = []

        for ingredient in ingredients {
            let finalName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let ingredientType: String
            if ingredient.produceID != nil {
                ingredientType = "produce"
            } else if ingredient.basicIngredientID != nil {
                ingredientType = "basic"
            } else {
                ingredientType = "custom"
            }

            print("[SEASON_OBSERVATION] phase=observation_evaluated_final ingredient=\(finalName) type=\(ingredientType)")

            if ingredientType != "custom" {
                print("[SEASON_OBSERVATION] phase=observation_skipped_final_resolved ingredient=\(finalName) type=\(ingredientType)")
                continue
            }

            let normalized = normalizedCustomIngredientObservationText(finalName)
            guard !normalized.isEmpty else { continue }
            guard seen.insert(normalized).inserted else { continue }

            let source = customIngredientObservationSource(for: ingredient)
            observations.append(
                CustomIngredientObservation(
                    normalizedText: normalized,
                    rawExample: finalName,
                    languageCode: localizer.languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : localizer.languageCode,
                    source: source,
                    latestRecipeID: latestRecipeID
                )
            )
            print("[SEASON_OBSERVATION] phase=observation_logged_final_unresolved ingredient=\(finalName)")
        }

        return observations
    }

    private func customIngredientObservationSource(for ingredient: RecipeIngredient) -> String {
        if ingredient.mappingConfidence == .unmapped || ingredient.rawIngredientLine != nil {
            return "import"
        }
        return "manual"
    }

    private func normalizedCustomIngredientObservationText(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    private func hasExplicitPieceToken(_ line: String) -> Bool {
        line.range(
            of: #"(?i)\b(piece|pieces|pezzo|pezzi)\b"#,
            options: .regularExpression
        ) != nil
    }

    private func looksExplicitMeasuredLine(_ line: String) -> Bool {
        line.range(
            of: #"(?i)\b\d+\s*(g|kg|ml|l|tbsp|tsp|cup)\b"#,
            options: .regularExpression
        ) != nil
    }

    private func resolveImportedIngredientMatch(query: String) -> ImportedIngredientMatch? {
        let normalizedQueries = importedIngredientMatchQueries(from: query)
        guard !normalizedQueries.isEmpty else { return nil }

        for normalizedQuery in normalizedQueries {
            if let match = viewModel.resolveIngredientForImport(query: normalizedQuery) {
                switch match {
                case .produce(let item):
                    return .produce(item)
                case .basic(let item):
                    return .basic(item)
                }
            }
        }

        var bestProduce: (item: ProduceItem, score: Int, length: Int)?
        for item in viewModel.produceItems {
            for term in importSearchTerms(
                id: item.id,
                localizedNames: item.localizedNames
            ) {
                guard let score = bestIngredientMatchScore(queries: normalizedQueries, term: term) else { continue }
                let candidate = (item: item, score: score, length: term.count)
                if bestProduce == nil
                    || candidate.score > bestProduce!.score
                    || (candidate.score == bestProduce!.score && candidate.length > bestProduce!.length) {
                    bestProduce = candidate
                }
            }
        }

        var bestBasic: (item: BasicIngredient, score: Int, length: Int)?
        for item in BasicIngredientCatalog.all {
            for term in importSearchTerms(
                id: item.id,
                localizedNames: item.localizedNames
            ) {
                guard let score = bestIngredientMatchScore(queries: normalizedQueries, term: term) else { continue }
                let candidate = (item: item, score: score, length: term.count)
                if bestBasic == nil
                    || candidate.score > bestBasic!.score
                    || (candidate.score == bestBasic!.score && candidate.length > bestBasic!.length) {
                    bestBasic = candidate
                }
            }
        }

        switch (bestProduce, bestBasic) {
        case (.none, .none):
            return nil
        case let (.some(produce), .none):
            return .produce(produce.item)
        case let (.none, .some(basic)):
            return .basic(basic.item)
        case let (.some(produce), .some(basic)):
            if produce.score != basic.score {
                return produce.score > basic.score ? .produce(produce.item) : .basic(basic.item)
            }
            if produce.length != basic.length {
                return produce.length > basic.length ? .produce(produce.item) : .basic(basic.item)
            }
            return .produce(produce.item)
        }
    }

    private func importedIngredientMatchQueries(from raw: String) -> [String] {
        let normalizedRaw = normalizedIngredientMatchText(raw)
        guard !normalizedRaw.isEmpty else { return [] }

        var seen = Set<String>()
        var queries: [String] = []

        func appendQuery(_ candidate: String) {
            let normalized = normalizedIngredientMatchText(candidate)
            guard !normalized.isEmpty else { return }
            if seen.insert(normalized).inserted {
                queries.append(normalized)
            }
        }

        appendQuery(normalizedRaw)
        appendQuery(normalizedCommonIngredientPhrase(normalizedRaw))
        appendQuery(strippedIngredientDescriptors(normalizedRaw))
        appendQuery(extractCoreIngredientQuery(raw))

        for query in queries {
            let aliases = expandedIngredientQueryAliases(for: query)
            for alias in aliases {
                appendQuery(alias)
            }
        }

        return queries
    }

    private func normalizedCommonIngredientPhrase(_ raw: String) -> String {
        let normalized = normalizedIngredientMatchText(raw)
        guard !normalized.isEmpty else { return raw }

        let replacements: [(pattern: String, replacement: String)] = [
            (#"^garlic\s+cloves?$"#, "garlic"),
            (#"^cloves?\s+garlic$"#, "garlic"),
            (#"^fresh\s+basil$"#, "basil"),
            (#"^fresh\s+parsley$"#, "parsley"),
            (#"^black\s+pepper$"#, "black pepper")
        ]

        for entry in replacements {
            if normalized.range(of: entry.pattern, options: .regularExpression) != nil {
                print("[SEASON_IMPORT] phase=normalized_common_phrase raw=\(normalized) normalized=\(entry.replacement)")
                return entry.replacement
            }
        }

        return normalized
    }

    private func isNormalizedPiecePhraseCandidate(original: String, normalized: String) -> Bool {
        if normalized != normalizedIngredientMatchText(original) {
            return true
        }
        let tracked = Set(["garlic", "basil", "salt", "parsley", "black pepper"])
        return tracked.contains(normalized)
    }

    private func bestIngredientMatchScore(queries: [String], term: String) -> Int? {
        var bestScore: Int?
        for query in queries {
            guard let score = ingredientMatchScore(query: query, term: term) else { continue }
            bestScore = max(bestScore ?? score, score)
        }
        return bestScore
    }

    private func strippedIngredientDescriptors(_ normalized: String) -> String {
        // Keep this intentionally conservative: remove lightweight descriptors,
        // preserve the core noun (e.g. "cipolla bianca" -> "cipolla").
        let descriptorTokens = Set([
            "bianca", "bianco", "rosse", "rossa", "rosso", "verde",
            "intero", "intera", "interi", "intere",
            "secco", "secca", "secchi", "secche",
            "grattugiato", "grattugiata",
            "fresco", "fresca", "fresh",
            "whole", "dry", "grated",
            "tipo", "quality"
        ])

        let stripped = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { token in !descriptorTokens.contains(token) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped.isEmpty ? normalized : stripped
    }

    private func expandedIngredientQueryAliases(for normalizedQuery: String) -> [String] {
        var aliases: [String] = []
        for (pattern, mappedAliases) in importQueryAliases {
            if queryContainsPhrase(normalizedQuery, phrase: pattern) {
                aliases.append(contentsOf: mappedAliases)
            }
        }
        return aliases
    }

    private func queryContainsPhrase(_ query: String, phrase: String) -> Bool {
        if query == phrase { return true }
        let pattern = #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: phrase))(?![a-z0-9])"#
        return query.range(of: pattern, options: .regularExpression) != nil
    }

    private func importSearchTerms(id: String, localizedNames: [String: String]) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []
        let candidates = localizedNames.values + [
            id,
            id.replacingOccurrences(of: "_", with: " ")
        ] + (importIngredientAliases[id] ?? [])

        for candidate in candidates {
            let normalized = normalizedIngredientMatchText(candidate)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                terms.append(normalized)
            }
        }
        return terms
    }

    private func ingredientMatchScore(query: String, term: String) -> Int? {
        guard !query.isEmpty, !term.isEmpty else { return nil }
        if query == term {
            return 3
        }
        if query.hasPrefix(term) || term.hasPrefix(query) {
            return 2
        }
        if term.count >= 4 && query.contains(term) {
            return 1
        }
        return nil
    }

    private func normalizedIngredientMatchText(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removingEmojis(from text: String) -> String {
        text.unicodeScalars
            .filter { scalar in
                !scalar.properties.isEmojiPresentation
                && !scalar.properties.isEmoji
            }
            .map { String($0) }
            .joined()
    }

    private func cleanedTitle(_ raw: String) -> String {
        var cleaned = removingEmojis(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(
            of: #"[!?.,:\-–—…\s]+$"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.isEmpty ? "Untitled recipe" : cleaned
    }

    private func extractCoreIngredientQuery(_ raw: String) -> String {
        let normalized = normalizedIngredientMatchText(raw)
        guard !normalized.isEmpty else { return "" }

        var working = normalized
        // Drop quantity + common units at line start.
        working = working.replacingOccurrences(
            of: #"^\d+\s*(g|kg|ml|l)?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove frequent filler tokens used in imported natural-language ingredient lines.
        let fillers = [
            "una", "un", "uno", "mezza", "mezzo", "mezze",
            "di", "da", "con", "per",
            "qb", "q b", "quanto", "basta",
            "costa", "spicchio", "pezzo",
            "bianca", "bianco", "rossa", "rosso",
            "intero", "intera", "secco", "secca",
            "grattugiato", "grattugiata", "fresco", "fresca"
        ]
        let filteredTokens = working
            .split(separator: " ")
            .map(String.init)
            .filter { token in !fillers.contains(token) && token.count >= 2 }

        guard !filteredTokens.isEmpty else { return "" }
        // Heuristic: last meaningful token usually carries the core ingredient identity.
        return filteredTokens.last ?? ""
    }

    private var importIngredientAliases: [String: [String]] {
        [
            "rocket": ["arugula", "rucola"],
            "eggplant": ["aubergine", "melanzana"],
            "zucchini": ["courgette", "zucchina"],
            "bell_pepper": ["bell pepper", "pepper", "peperone"],
            "chickpeas": ["ceci", "garbanzo", "garbanzo beans"],
            "lentils": ["lenticchie"],
            "beans": ["fagioli"],
            "green_beans": ["fagiolini", "string beans"],
            "cream_cheese": ["formaggio spalmabile"],
            "greek_yogurt": ["yogurt greco"],
            "onion": ["cipolla", "cipolla bianca", "cipolla rossa"],
            "carrot": ["carota", "carote"],
            "celery": ["sedano", "costa di sedano"],
            "milk": ["latte", "latte intero"],
            "flour": ["farina", "farina 00", "wheat flour"],
            "butter": ["burro"],
            "white_wine": ["vino bianco", "vino bianco secco"],
            "tomato_sauce": ["salsa di pomodoro", "passata di pomodoro", "tomato sauce"],
            "olive_oil": ["olio evo", "olio extravergine", "olio extra vergine", "extra virgin olive oil", "olive oil"],
            "beef_broth": ["brodo di manzo", "beef broth", "beef stock"],
            "lemon": ["limone"],
            "egg": ["uovo", "uova", "eggs"],
            "parmesan": ["parmigiano", "parmigiano reggiano", "parmesan", "parmesan cheese"],
            "garlic": ["aglio", "garlic clove", "garlic cloves"],
            "basil": ["basilico", "fresh basil"],
            "parsley": ["prezzemolo", "fresh parsley"],
            "salt": ["sale", "sea salt"],
            "black_pepper": ["black pepper", "pepe nero"]
        ]
    }

    private var importQueryAliases: [String: [String]] {
        [
            // Italian ↔ English high-value kitchen aliases used in social captions.
            "cipolla": ["onion"],
            "cipolla bianca": ["onion"],
            "cipolla rossa": ["onion"],
            "onion": ["cipolla"],
            "carota": ["carrot"],
            "carote": ["carrot"],
            "carrot": ["carota"],
            "sedano": ["celery"],
            "costa di sedano": ["celery"],
            "celery": ["sedano"],
            "latte": ["milk"],
            "latte intero": ["milk"],
            "milk": ["latte"],
            "farina": ["flour"],
            "farina 00": ["flour"],
            "wheat flour": ["flour"],
            "flour": ["farina"],
            "burro": ["butter"],
            "butter": ["burro"],
            "salsa di pomodoro": ["tomato sauce", "passata di pomodoro"],
            "passata di pomodoro": ["tomato sauce", "salsa di pomodoro"],
            "tomato sauce": ["salsa di pomodoro", "passata di pomodoro"],
            "olio evo": ["olive oil", "extra virgin olive oil", "olio extravergine"],
            "olio extravergine": ["olive oil", "extra virgin olive oil", "olio evo"],
            "olio extra vergine": ["olive oil", "extra virgin olive oil", "olio evo"],
            "olive oil": ["olio evo", "olio extravergine", "olio extra vergine"],
            "extra virgin olive oil": ["olio evo", "olio extravergine", "olio extra vergine"],
            "vino bianco": ["white wine"],
            "vino bianco secco": ["white wine"],
            "white wine": ["vino bianco"],
            "brodo di manzo": ["beef broth", "beef stock"],
            "beef broth": ["brodo di manzo"],
            "beef stock": ["brodo di manzo"],
            "limone": ["lemon"],
            "lemon": ["limone"],
            "uova": ["egg", "eggs"],
            "uovo": ["egg"],
            "eggs": ["uova"],
            "egg": ["uovo", "uova"],
            "parmigiano": ["parmesan", "parmigiano reggiano"],
            "parmigiano reggiano": ["parmesan"],
            "parmesan": ["parmigiano", "parmigiano reggiano"],
            "parmigiano grattugiato": ["parmigiano", "parmesan"],
            "garlic clove": ["garlic", "aglio"],
            "garlic cloves": ["garlic", "aglio"],
            "fresh basil": ["basil", "basilico"],
            "fresh parsley": ["parsley", "prezzemolo"],
            "salt": ["sale"],
            "sale": ["salt"],
            "black pepper": ["pepe nero"],
            "pepe nero": ["black pepper"]
        ]
    }

    private func shouldShowIngredientSuggestions(for draft: CreateIngredientDraft) -> Bool {
        focusedIngredientID == draft.id
        && !draft.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func bindingForIngredientSearch(id: UUID) -> Binding<String> {
        Binding(
            get: { ingredientDrafts.first(where: { $0.id == id })?.searchText ?? "" },
            set: { newValue in
                guard let index = ingredientDrafts.firstIndex(where: { $0.id == id }) else { return }
                let oldDisplayName = ingredientDraftDisplayName(ingredientDrafts[index]).lowercased()
                ingredientDrafts[index].searchText = newValue
                let newNormalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                if !oldDisplayName.isEmpty && newNormalized != oldDisplayName {
                    ingredientDrafts[index].produceID = ""
                    ingredientDrafts[index].basicIngredientID = ""
                    ingredientDrafts[index].customName = ""
                }
            }
        )
    }

    private func ingredientDraftDisplayName(_ draft: CreateIngredientDraft) -> String {
        if let item = viewModel.produceItem(forID: draft.produceID) {
            return item.displayName(languageCode: localizer.languageCode)
        }
        if let basic = viewModel.basicIngredient(forID: draft.basicIngredientID) {
            return basic.displayName(languageCode: localizer.languageCode)
        }
        if !draft.customName.isEmpty {
            return draft.customName
        }
        return draft.searchText
    }

    private func applyIngredientSelection(_ result: IngredientSearchResult, for ingredientID: UUID) {
        guard let index = ingredientDrafts.firstIndex(where: { $0.id == ingredientID }) else { return }

        ingredientDrafts[index].customName = ""

        switch result.source {
        case .produce(let item):
            ingredientDrafts[index].produceID = item.id
            ingredientDrafts[index].basicIngredientID = ""
            ingredientDrafts[index].searchText = item.displayName(languageCode: localizer.languageCode)
            let profile = viewModel.quantityProfile(forProduceID: item.id)
            ingredientDrafts[index].quantityUnit = profile.defaultUnit
            ingredientDrafts[index].quantityValue = defaultQuantityValueString(for: profile.defaultUnit)
        case .basic(let basic):
            ingredientDrafts[index].produceID = ""
            ingredientDrafts[index].basicIngredientID = basic.id
            ingredientDrafts[index].searchText = basic.displayName(languageCode: localizer.languageCode)
            ingredientDrafts[index].quantityUnit = basic.unitProfile.defaultUnit
            ingredientDrafts[index].quantityValue = defaultQuantityValueString(for: basic.unitProfile.defaultUnit)
        }

        focusedIngredientID = nil
    }

    private func applyCustomIngredientFallback(for ingredientID: UUID) {
        guard let index = ingredientDrafts.firstIndex(where: { $0.id == ingredientID }) else { return }
        let typed = ingredientDrafts[index].searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }

        ingredientDrafts[index].produceID = ""
        ingredientDrafts[index].basicIngredientID = ""
        ingredientDrafts[index].customName = typed
        focusedIngredientID = nil
    }

    private func parsedQuantityValue(_ raw: String) -> Double {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func quantityValueString(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func defaultQuantityValueString(for unit: RecipeQuantityUnit) -> String {
        switch unit {
        case .g, .ml:
            return "100"
        case .piece, .slice, .clove, .tbsp, .tsp, .cup:
            return "1"
        }
    }

    private var selectedCoverImageID: String? {
        guard !uploadedImages.isEmpty else { return nil }
        if let explicitID = coverImageID,
           uploadedImages.contains(where: { $0.id == explicitID }) {
            return explicitID
        }
        return uploadedImages.first?.id
    }

    private var normalizedMediaLink: String? {
        let trimmed = mediaLink.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedInstagramURL: String? {
        let trimmed = instagramURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedTikTokURL: String? {
        let trimmed = tiktokURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var externalMediaForPublish: [RecipeExternalMedia] {
        if let normalizedMediaLink,
           let platform = recipeExternalPlatform(for: normalizedMediaLink) {
            return [
                RecipeExternalMedia(
                    id: UUID().uuidString.lowercased(),
                    platform: platform,
                    url: normalizedMediaLink
                )
            ]
        }

        if let prefillDraft, !prefillDraft.externalMedia.isEmpty {
            return prefillDraft.externalMedia
        }

        return []
    }

    private static func prefillDraft(from recipe: Recipe) -> PrefillDraft {
        PrefillDraft(
            title: recipe.title,
            imageAssetName: recipe.coverImageName,
            externalMedia: recipe.externalMedia,
            images: recipe.images,
            coverImageID: recipe.coverImageID,
            mediaLinkURL: recipe.mediaLinkURL,
            instagramURL: recipe.instagramURL,
            tiktokURL: recipe.tiktokURL,
            ingredients: recipe.ingredients,
            steps: recipe.preparationSteps,
            prepTimeMinutes: recipe.prepTimeMinutes,
            cookTimeMinutes: recipe.cookTimeMinutes,
            difficulty: recipe.difficulty,
            servings: recipe.servings,
            isRemix: recipe.isRemix,
            originalRecipeID: recipe.originalRecipeID,
            originalRecipeTitle: recipe.originalRecipeTitle,
            originalAuthorName: recipe.originalAuthorName
        )
    }

    private func importPhotoItems(_ items: [PhotosPickerItem]) async {
        var imported: [RecipeImage] = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let savedPath = saveImageDataToDocuments(data) else {
                continue
            }

            imported.append(
                RecipeImage(
                    id: UUID().uuidString.lowercased(),
                    localPath: savedPath,
                    remoteURL: nil
                )
            )
        }

        await MainActor.run {
            uploadedImages.append(contentsOf: imported)
            if coverImageID == nil {
                coverImageID = uploadedImages.first?.id
            }
            selectedPhotoItems = []
        }
    }

    private func addCameraImage(_ image: UIImage) {
        guard let savedPath = saveUIImageToDocuments(image) else { return }
        uploadedImages.append(
            RecipeImage(
                id: UUID().uuidString.lowercased(),
                localPath: savedPath,
                remoteURL: nil
            )
        )
        if coverImageID == nil {
            coverImageID = uploadedImages.first?.id
        }
    }

    private func openCameraIfAvailable() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }
        showingCameraPicker = true
    }

    private func saveImageDataToDocuments(_ data: Data) -> String? {
        let filename = "recipe_\(UUID().uuidString.lowercased()).jpg"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func saveUIImageToDocuments(_ image: UIImage) -> String? {
        guard let jpegData = image.jpegData(compressionQuality: 0.9) else { return nil }
        return saveImageDataToDocuments(jpegData)
    }

    @ViewBuilder
    private func mediaItemCard(image: RecipeImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let uiImage = recipeUIImage(from: image) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(role: .destructive) {
                    let wasCover = isCoverImage(image.id)
                    uploadedImages.removeAll { $0.id == image.id }
                    if wasCover {
                        coverImageID = uploadedImages.first?.id
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.45))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }

            Button {
                moveImageToCover(image.id)
            } label: {
                Text(isCoverImage(image.id) ? localizer.text(.mediaCoverTag) : localizer.text(.mediaSetCover))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCoverImage(image.id) ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func moveImageToCover(_ imageID: String) {
        guard let index = uploadedImages.firstIndex(where: { $0.id == imageID }) else { return }
        let selected = uploadedImages.remove(at: index)
        uploadedImages.insert(selected, at: 0)
        coverImageID = imageID
    }

    private func isCoverImage(_ imageID: String) -> Bool {
        selectedCoverImageID == imageID
    }

    private func detectedPlatform(for url: String) -> SocialSourcePlatform? {
        let lower = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }
        if lower.contains("tiktok.com") {
            return .tiktok
        }
        if lower.contains("instagram.com") {
            return .instagram
        }
        return nil
    }

    private func recipeExternalPlatform(for url: String) -> RecipeExternalPlatform? {
        switch detectedPlatform(for: url) {
        case .instagram:
            return .instagram
        case .tiktok:
            return .tiktok
        default:
            return nil
        }
    }

    private func platformDisplayName(_ platform: SocialSourcePlatform) -> String? {
        switch platform {
        case .instagram:
            return "Instagram"
        case .tiktok:
            return "TikTok"
        default:
            return nil
        }
    }
}

private func quantityValueStringStatic(_ value: Double) -> String {
    if value.rounded() == value {
        return "\(Int(value))"
    }
    return String(format: "%.1f", value)
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            dismiss()
        }
    }
}
