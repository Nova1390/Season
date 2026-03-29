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
        ingredientDrafts
            .map(\.produceID)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var recipeIngredientsForPublish: [RecipeIngredient] {
        ingredientDrafts.compactMap { draft in
            let produceID = draft.produceID.trimmingCharacters(in: .whitespacesAndNewlines)
            let basicIngredientID = draft.basicIngredientID.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parsedQuantityValue(draft.quantityValue)
            guard value > 0 else { return nil }

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
        _ = viewModel.saveRecipeDraft(
            recipeID: currentDraftRecipeID,
            title: title,
            author: accountUsername,
            ingredients: recipeIngredientsForPublish,
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

        let published = viewModel.publishRecipe(
            title: title,
            author: accountUsername,
            ingredients: recipeIngredientsForPublish,
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
            importFeedbackText = localizer.text(.importNoMatches)
            return
        }
        importConfidence = nil

        let cleanedCaption = removingEmojis(from: importCaptionRaw)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: sourceURL,
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )

        print("[SEASON_IMPORT] phase=local_parse_done source_url=\(sourceURL) confidence=\(localSuggestion.confidence.rawValue)")

        if localSuggestion.confidence == .low {
            isImportAnalyzing = true
            importFeedbackText = localizer.text(.importAnalyzing)
            defer { isImportAnalyzing = false }

            print("[SEASON_IMPORT] phase=server_fallback_attempted source_url=\(sourceURL)")
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
                    print("[SEASON_IMPORT] phase=server_fallback_succeeded source_url=\(sourceURL) confidence=\(serverSuggestion.confidence.rawValue)")
                    applyImportedSuggestion(serverSuggestion, sourceURL: sourceURL)
                    return
                }
                print("[SEASON_IMPORT] phase=server_fallback_not_useful source_url=\(sourceURL)")
            } catch {
                print("[SEASON_IMPORT] phase=server_fallback_failed source_url=\(sourceURL) error=\(error)")
            }
        }

        print("[SEASON_IMPORT] phase=kept_local_result source_url=\(sourceURL) confidence=\(localSuggestion.confidence.rawValue)")
        applyImportedSuggestion(localSuggestion, sourceURL: sourceURL)
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
            ingredientDrafts = suggestion.suggestedIngredients.map {
                normalizedImportedIngredientDraft(from: $0)
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

            let unit = RecipeQuantityUnit(rawValue: (item.unit ?? "").lowercased()) ?? .piece
            let quantity = max(0.0001, item.quantity ?? 1)
            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: nil,
                quality: .basic,
                name: cleanedName,
                quantityValue: quantity,
                quantityUnit: unit,
                rawIngredientLine: cleanedName,
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
        let hasCatalogMapping = ingredient.produceID != nil || ingredient.basicIngredientID != nil
        if hasCatalogMapping {
            // Preserve existing mapped behavior for produce/basic ingredients.
            return CreateIngredientDraft(
                produceID: ingredient.produceID ?? "",
                basicIngredientID: ingredient.basicIngredientID ?? "",
                customName: "",
                searchText: removingEmojis(from: ingredient.name).trimmingCharacters(in: .whitespacesAndNewlines),
                quantityValue: quantityValueString(ingredient.quantityValue),
                quantityUnit: ingredient.quantityUnit
            )
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

        if let fractional = parsedFractionalPieceIngredient(from: trimmedName) {
            if let resolved = resolveImportedIngredientMatch(query: fractional.coreName) {
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: fractional.quantity,
                    quantityUnit: .piece
                )
            }
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
            return customImportedIngredientDraft(name: trimmedName)
        }

        let fullRange = NSRange(location: 0, length: trimmedName.utf16.count)
        guard let match = regex.firstMatch(in: trimmedName, options: [], range: fullRange),
              match.numberOfRanges == 4 else {
            return customImportedIngredientDraft(name: trimmedName)
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
            if let resolved = resolveImportedIngredientMatch(query: fallbackName) {
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: Double(baseQuantity),
                    quantityUnit: .piece
                )
            }
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

        if let resolved = resolveImportedIngredientMatch(query: fallbackName) {
            return catalogMatchedImportedDraft(
                from: resolved,
                quantityValue: quantityValue,
                quantityUnit: quantityUnit
            )
        }

        return CreateIngredientDraft(
            produceID: "",
            basicIngredientID: "",
            customName: fallbackName,
            searchText: fallbackName,
            quantityValue: quantityValueString(quantityValue),
            quantityUnit: quantityUnit
        )
    }

    private func catalogMatchedImportedDraft(
        from resolved: ImportedIngredientMatch,
        quantityValue: Double,
        quantityUnit: RecipeQuantityUnit
    ) -> CreateIngredientDraft {
        switch resolved {
        case .produce(let item):
            return CreateIngredientDraft(
                produceID: item.id,
                basicIngredientID: "",
                customName: "",
                searchText: item.displayName(languageCode: localizer.languageCode),
                quantityValue: quantityValueString(quantityValue),
                quantityUnit: quantityUnit
            )
        case .basic(let item):
            return CreateIngredientDraft(
                produceID: "",
                basicIngredientID: item.id,
                customName: "",
                searchText: item.displayName(languageCode: localizer.languageCode),
                quantityValue: quantityValueString(quantityValue),
                quantityUnit: quantityUnit
            )
        }
    }

    private func customImportedIngredientDraft(name: String) -> CreateIngredientDraft {
        let normalized = removingEmojis(from: name).trimmingCharacters(in: .whitespacesAndNewlines)
        return CreateIngredientDraft(
            produceID: "",
            basicIngredientID: "",
            customName: normalized,
            searchText: normalized,
            quantityValue: quantityValueString(1),
            quantityUnit: .piece
        )
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
            "beef_broth": ["brodo di manzo", "beef broth", "beef stock"],
            "lemon": ["limone"],
            "egg": ["uovo", "uova", "eggs"],
            "parmesan": ["parmigiano", "parmigiano reggiano", "parmesan", "parmesan cheese"]
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
            "parmigiano grattugiato": ["parmigiano", "parmesan"]
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
