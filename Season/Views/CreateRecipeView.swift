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

private enum SmartImportLocalSpecificityStatus: String {
    case exactSpecific = "exact_specific"
    case acceptableParentFallback = "acceptable_parent_fallback"
    case tooGeneric = "too_generic"
    case customUnresolved = "custom_unresolved"
}

private struct ImportQualityBadge: View {
    let confidence: SocialImportConfidence
    let localizer: AppLocalizer

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
        case .high: return localizer.localized("create.import.quality.high")
        case .medium: return localizer.localized("create.import.quality.medium")
        case .low: return localizer.localized("create.import.quality.low")
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
    private enum ComposerStateKind {
        case start
        case editing
        case ready
        case draft
    }

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
    @State private var publishErrorMessage = ""
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
                        VStack(alignment: .leading, spacing: 20) {
                            composerStateSummary
                            heroComposerSection
                            importFromLinkSection
                            titleSection
                            servingsSection
                            ingredientsSection
                            stepsSection
                            socialLinksSection
                            previewSection
                            Color.clear.frame(height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
            .background(SeasonColors.primarySurface)
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
            .alert(localizer.text(.publishFailedTitle), isPresented: $showPublishError) {
                Button(localizer.text(.commonOK), role: .cancel) {}
            } message: {
                Text(publishErrorMessage.isEmpty ? localizer.text(.publishFailedMessage) : publishErrorMessage)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(localizer.localized("create.composer.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                composerStateBadge
            }

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
                    .buttonStyle(SeasonPrimaryButtonStyle())

                    Button {
                        openCameraIfAvailable()
                    } label: {
                        Label(localizer.text(.mediaUseCamera), systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(SeasonSecondaryButtonStyle())
                }
                .padding(12)
            }

            TextField(localizer.text(.mediaExternalLink), text: $mediaLink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
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
        .padding(14)
        .background(createSectionContainer(priority: .primary))
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
                    .buttonStyle(SeasonSecondaryButtonStyle())
                    .disabled(!canRunSmartImport || isImportAnalyzing)

                    if let importConfidence {
                        ImportQualityBadge(confidence: importConfidence, localizer: localizer)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizer.text(.importFromLinkSectionTitle))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(localizer.localized("create.import.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "wand.and.stars")
                    .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.33, green: 0.38, blue: 0.28))
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(createSectionContainer(priority: .secondary))
        .tint(SeasonColors.seasonGreen)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(localizer.text(.titleSectionTitle))
            TextField(recipeTitlePlaceholder, text: $title, axis: .vertical)
                .font(.system(size: 34, weight: .bold, design: .default))
                .lineLimit(2...3)
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
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
        .padding(14)
        .background(createSectionContainer(priority: .tertiary))
    }

    private var servingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(localizer.localized("create.servings.title"))
            HStack {
                Text(String(format: localizer.text(.servesFormat), selectedServings))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Stepper(value: $selectedServings, in: 1...12) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
        .padding(14)
        .background(createSectionContainer(priority: .secondary))
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(localizer.text(.ingredientsSectionTitle))

            ForEach($ingredientDrafts) { $ingredient in
                let isSubsectionHeader = isSubsectionHeaderDraft(ingredient)
                let hideQuantityControls = shouldHideQuantityControls(for: ingredient)

                VStack(alignment: .leading, spacing: 10) {
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
                                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.78))
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
                .padding(.vertical, 6)
            }

            Button {
                let draft = CreateIngredientDraft()
                ingredientDrafts.append(draft)
                focusedIngredientID = draft.id
            } label: {
                Label(localizer.text(.addIngredient), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SeasonSecondaryButtonStyle())
        }
        .padding(14)
        .background(createSectionContainer(priority: .primary))
        .tint(SeasonColors.seasonGreen)
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
                .padding(.vertical, 6)
            }

            Button {
                stepDrafts.append(CreateStepDraft())
            } label: {
                Label(localizer.text(.addStep), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SeasonSecondaryButtonStyle())
        }
        .padding(14)
        .background(createSectionContainer(priority: .primary))
        .tint(SeasonColors.seasonGreen)
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
        .padding(14)
        .background(createSectionContainer(priority: .tertiary))
    }

    private var publishBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if enableDraftMode {
                    HStack(spacing: 10) {
                        Button {
                            persistDraftIfNeeded(showFeedback: true)
                        } label: {
                            Text(localizer.text(.saveDraft))
                                .frame(maxWidth: .infinity)
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(SeasonSecondaryButtonStyle())
                        .disabled(!canSaveDraft)

                        Button {
                            publish()
                        } label: {
                            Text(localizer.text(.publishRecipe))
                                .frame(maxWidth: .infinity)
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(SeasonPrimaryButtonStyle())
                        .disabled(!canPublish || isPublishing)
                    }
                } else {
                    HStack {
                        Button {
                            publish()
                        } label: {
                            Text(localizer.text(.publishRecipe))
                                .frame(maxWidth: .infinity)
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(SeasonPrimaryButtonStyle())
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
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(
                SeasonColors.primarySurface.opacity(0.94)
                    .overlay(
                        Rectangle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(height: 0.6),
                        alignment: .top
                    )
            )
        }
    }

    private var composerStateSummary: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(composerStateTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(composerStateSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            composerStateBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SeasonColors.secondarySurface.opacity(0.64))
        )
    }

    private var composerStateBadge: some View {
        Text(composerStateTitle)
            .font(.caption2.weight(.bold))
            .foregroundStyle(composerStateColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(composerStateColor.opacity(0.14))
            )
    }

    @ViewBuilder
    private var heroImageContent: some View {
        if let cover = uploadedImages.first,
           recipeImageFileURL(for: cover.localPath) != nil {
            RecipeLocalImageView(
                image: cover,
                targetSize: CGSize(width: 900, height: 420),
                contentMode: .fill
            ) {
                heroImageFallbackContent
            }
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

    @ViewBuilder
    private var heroImageFallbackContent: some View {
        if let legacyName = prefillDraft?.imageAssetName, hasAsset(named: legacyName) {
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

    private var recipeTitlePlaceholder: String {
        localizer.localized("create.recipe_title.placeholder")
    }

    private var hasMeaningfulIngredientsForComposer: Bool {
        !recipeIngredientsForPublish.isEmpty
    }

    private var hasMeaningfulStepsForComposer: Bool {
        !stepTextsForPublish.isEmpty
    }

    private var hasLoadedDraftForComposer: Bool {
        enableDraftMode && currentDraftRecipeID != nil && !draftLoadFailed
    }

    private var composerStateTitle: String {
        switch composerStateKind {
        case .draft:
            return localizer.localized("create.composer.state.draft")
        case .ready:
            return localizer.localized("create.composer.state.ready")
        case .editing:
            return localizer.localized("create.composer.state.editing")
        case .start:
            return localizer.localized("create.composer.state.start")
        }
    }

    private var composerStateSubtitle: String {
        switch composerStateKind {
        case .draft:
            return localizer.localized("create.composer.subtitle.draft")
        case .ready:
            return localizer.localized("create.composer.subtitle.ready")
        case .editing:
            return localizer.localized("create.composer.subtitle.editing")
        case .start:
            return localizer.localized("create.composer.subtitle.start")
        }
    }

    private var composerStateKind: ComposerStateKind {
        if hasLoadedDraftForComposer {
            return .draft
        }
        if canPublish {
            return .ready
        }
        if hasMeaningfulIngredientsForComposer || hasMeaningfulStepsForComposer || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .editing
        }
        return .start
    }

    private var composerStateColor: Color {
        switch composerStateKind {
        case .ready:
            return Color(red: 0.16, green: 0.65, blue: 0.30)
        case .draft:
            return Color(red: 0.43, green: 0.50, blue: 0.38)
        case .editing:
            return Color(red: 0.84, green: 0.58, blue: 0.18)
        case .start:
            return Color(red: 0.33, green: 0.38, blue: 0.28)
        }
    }

    private func persistDraftIfNeeded(showFeedback: Bool = false) {
        guard enableDraftMode else { return }
        if currentDraftRecipeID == nil, !draftLoadFailed {
            let createdDraft = viewModel.createEmptyDraftRecipe(author: accountUsername)
            currentDraftRecipeID = createdDraft.id
        }
        guard let currentDraftRecipeID else { return }
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

        let currentAuthUserID = SupabaseService.shared.currentAuthenticatedUserID()?.uuidString.lowercased()
        print("[SEASON_RECIPE] phase=publish_auth_check current_auth_user_id=\(currentAuthUserID ?? "nil")")
        guard currentAuthUserID != nil else {
            print("[SEASON_RECIPE] phase=publish_blocked reason=unauthenticated")
            publishErrorMessage = localizer.text(.publishAuthRequiredMessage)
            showPublishError = true
            return
        }

        let recipeID = currentDraftRecipeID ?? "recipe_\(UUID().uuidString.lowercased())"
        let existingRecipeImageURL = viewModel.recipe(forID: recipeID)?.imageURL
        var uploadedRecipeImageURL: String? = nil

        if let cover = uploadedImages.first,
           let jpegData = await SeasonImageProcessor.jpegData(
            fromRecipeImageLocalPath: cover.localPath,
            compressionQuality: 0.9
           ) {
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
        guard let published = viewModel.publishRecipe(
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
            originalAuthorName: prefillDraft?.originalAuthorName,
            commitLocally: false
        ) else {
            publishErrorMessage = localizer.text(.publishFailedMessage)
            showPublishError = true
            return
        }

        print("[SEASON_RECIPE] phase=publish_tap_remote_persist_started recipe_id=\(published.id)")
        do {
            try await SupabaseService.shared.createRecipe(published)
            viewModel.commitPublishedRecipeLocally(published)
            print("[SEASON_RECIPE] phase=local_publish_committed_after_remote recipe_id=\(published.id)")
            print("[SEASON_SUPABASE] phase=remote_publish_succeeded recipe_id=\(published.id)")
        } catch {
            print("[SEASON_SUPABASE] phase=remote_publish_failed recipe_id=\(published.id) error=\(error)")
            if case SupabaseServiceError.unauthenticated = error {
                publishErrorMessage = localizer.text(.publishAuthRequiredMessage)
            } else {
                publishErrorMessage = localizer.text(.publishFailedMessage)
            }
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
        guard canRunSmartImport else {
            importConfidence = nil
            importServerNoticeText = ""
            importFeedbackText = localizer.text(.importMissingSource)
            return
        }
        importConfidence = nil
        importServerNoticeText = ""

        let sourceURL = normalizedImportSourceURL ?? ""
        let cleanedCaption = removingEmojis(from: importCaptionRaw)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: sourceURL,
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )
        let smartImportCandidates = smartImportIngredientCandidates(from: cleanedCaption)
        let candidatesRequiringLLM = smartImportCandidates.filter(\.requiresLLM).count
        let smartImportAudit = SocialImportParser.computeAuditMetrics(candidates: smartImportCandidates)

        print("[SEASON_IMPORT] phase=local_parse_done source_url=\(sourceURL) confidence=\(localSuggestion.confidence.rawValue)")
        print("[SEASON_IMPORT] phase=smart_import_decision candidates=\(smartImportCandidates.count) requires_llm=\(candidatesRequiringLLM)")
        if SeasonLog.verbose {
            print(
                "[SEASON_SMART_IMPORT_AUDIT] phase=client_preparse " +
                "total=\(smartImportAudit.totalCandidates) " +
                "exact=\(smartImportAudit.exactMatches) " +
                "alias=\(smartImportAudit.aliasMatches) " +
                "ambiguous=\(smartImportAudit.ambiguousMatches) " +
                "none=\(smartImportAudit.noMatches) " +
                "requires_llm=\(smartImportAudit.requiresLLMCount)"
            )
        }

        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let localDraftsForFallbackGate = localSuggestion.suggestedIngredients.map {
            normalizedImportedIngredientDraft(from: $0, sourceCaptionRaw: cleanedCaption)
        }
        let completenessFallback = shouldTriggerFallback(
            parserCandidates: smartImportCandidates,
            finalDraftIngredients: localDraftsForFallbackGate
        )
        let shouldAttemptServerFallback = localSuggestion.confidence == .low
            || refinement.needsRefinement
            || completenessFallback
        let refinementReasonsLog = refinement.reasons.isEmpty ? "[]" : "[\(refinement.reasons.joined(separator: ","))]"
        print("[SEASON_IMPORT] phase=refinement_check needs_refinement=\(refinement.needsRefinement) reasons=\(refinementReasonsLog)")
        print(
            "[SEASON_IMPORT] phase=fallback_completeness_gate " +
            "trigger=\(completenessFallback) candidates=\(smartImportCandidates.count) " +
            "final_drafts=\(localDraftsForFallbackGate.count)"
        )
        if refinement.reasons.contains("unit_prefix_in_name") {
            print("[SEASON_IMPORT] phase=refinement_check reason=unit_prefix_in_name")
        }

        if shouldAttemptServerFallback {
            isImportAnalyzing = true
            importFeedbackText = localizer.text(.importAnalyzing)
            defer { isImportAnalyzing = false }

            let fallbackTrigger = localSuggestion.confidence == .low
                ? "low_confidence"
                : (completenessFallback ? "completeness_gate" : "refinement_gate")
            print("[SEASON_IMPORT] phase=server_fallback_attempted source_url=\(sourceURL) trigger=\(fallbackTrigger) reasons=\(refinementReasonsLog)")
            do {
                let serverResponse = try await SupabaseService.shared.parseRecipeCaption(
                    caption: cleanedCaption,
                    url: sourceURL,
                    languageCode: localizer.languageCode,
                    ingredientCandidates: smartImportCandidates.isEmpty ? nil : smartImportCandidates
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

    private func smartImportIngredientCandidates(from caption: String) -> [SmartImportIngredientCandidate] {
        SocialImportParser.preparseIngredientCandidates(
            captionRaw: caption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        ).map { candidate in
            guard candidate.requiresLLM,
                  let match = resolveImportedIngredientMatch(query: candidate.normalizedText) else {
                return candidate
            }

            let matchedIngredientId: String
            switch match {
            case .produce(let item):
                matchedIngredientId = "produce:\(item.id)"
            case .basic(let item):
                matchedIngredientId = "basic:\(item.id)"
            }

            // Compatibility note: this is a local draft-resolution hint, not a governed/approved
            // catalog alias. Catalog truth still flows through governance/autopilot SQL paths.
            return SmartImportIngredientCandidate(
                rawText: candidate.rawText,
                normalizedText: candidate.normalizedText,
                possibleQuantity: candidate.possibleQuantity,
                possibleUnit: candidate.possibleUnit,
                catalogMatch: SmartImportCatalogMatch(
                    matchType: .alias,
                    matchedIngredientId: matchedIngredientId,
                    confidence: 0.88
                )
            )
        }
    }

    private func shouldTriggerFallback(
        parserCandidates: [SmartImportIngredientCandidate],
        finalDraftIngredients: [CreateIngredientDraft]
    ) -> Bool {
        if finalDraftIngredients.isEmpty {
            return true
        }
        if parserCandidates.count <= 1 && finalDraftIngredients.count <= 1 {
            return true
        }
        if parserCandidates.count > finalDraftIngredients.count
            && distinctResolvedCandidateCount(parserCandidates) > finalDraftIngredients.count {
            return true
        }
        return parserCandidates.contains { candidate in
            candidateLooksCollapsed(candidate.rawText)
        }
    }

    private func candidateLooksCollapsed(_ rawText: String) -> Bool {
        let normalized = " \(normalizedIngredientMatchText(rawText)) "
        if normalized.contains(" e ") {
            return true
        }
        if rawText.filter({ $0 == "," }).count > 1 {
            return true
        }
        if rawText.filter({ $0 == "/" }).count > 1 {
            return true
        }
        return false
    }

    private func distinctResolvedCandidateCount(_ parserCandidates: [SmartImportIngredientCandidate]) -> Int {
        let keys = parserCandidates.map { candidate in
            candidate.catalogMatch.matchedIngredientId
                ?? normalizedIngredientMatchText(candidate.normalizedText)
        }
        return Set(keys.filter { !$0.isEmpty }).count
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

    private func normalizedImportedIngredientDraft(
        from ingredient: RecipeIngredient,
        sourceCaptionRaw: String? = nil
    ) -> CreateIngredientDraft {
        print("[SEASON_IMPORT] stage=A_raw_imported name=\(ingredient.name) quantity=\(ingredient.quantityValue) unit=\(ingredient.quantityUnit.rawValue)")
        let hasCatalogMapping = ingredient.produceID != nil || ingredient.basicIngredientID != nil
        if hasCatalogMapping {
            if let produceID = ingredient.produceID,
               let item = viewModel.produceItem(forID: produceID) {
                let draft = catalogMatchedImportedDraft(
                    from: .produce(item),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    importedSurfaceName: ingredient.rawIngredientLine ?? ingredient.name
                )
                print("[SEASON_IMPORT] stage=C_match_decision decision=pre_mapped")
                print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
                return draft
            }
            if let basicIngredientID = ingredient.basicIngredientID,
               let item = viewModel.basicIngredient(forID: basicIngredientID) {
                let draft = catalogMatchedImportedDraft(
                    from: .basic(item),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    importedSurfaceName: ingredient.rawIngredientLine ?? ingredient.name
                )
                print("[SEASON_IMPORT] stage=C_match_decision decision=pre_mapped")
                print("[SEASON_IMPORT] stage=D_final_draft searchText=\(draft.searchText) customName=\(draft.customName) quantityValue=\(draft.quantityValue) quantityUnit=\(draft.quantityUnit.rawValue)")
                return draft
            }
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
            let cleanedName = normalizedCommonIngredientPhrase(cleanedQuantoBastaName(from: trimmedName))
            if let resolved = resolveImportedIngredientMatch(query: cleanedName) {
                print("[SEASON_IMPORT] phase=ingredient_matched_to_catalog raw=\(trimmedName) normalized=\(cleanedName) match=\(resolvedDecisionLabel(resolved))")
                return catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: 1,
                    quantityUnit: .piece
                )
            }
            return customImportedIngredientDraft(name: cleanedName)
        }

        let rawSourceLine = ingredient.rawIngredientLine?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedName
        let explicitRecovery = explicitQuantityRecoveryCandidate(
            ingredientName: trimmedName,
            rawSourceLine: rawSourceLine,
            caption: sourceCaptionRaw ?? importCaptionRaw
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
                    quantityUnit: recovered.quantityUnit,
                    importedSurfaceName: trimmedName
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
                        quantityUnit: recovered.quantityUnit,
                        importedSurfaceName: trimmedName
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
                        quantityUnit: recovered.quantityUnit,
                        importedSurfaceName: trimmedName
                    )
                    print("[SEASON_IMPORT] stage=D_final_draft searchText=\(recoveredDraft.searchText) customName=\(recoveredDraft.customName) quantityValue=\(recoveredDraft.quantityValue) quantityUnit=\(recoveredDraft.quantityUnit.rawValue)")
                    return recoveredDraft
                }
                let draft = catalogMatchedImportedDraft(
                    from: resolved,
                    quantityValue: preservedQuantity,
                    quantityUnit: preservedUnit,
                    importedSurfaceName: trimmedName
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
                    quantityUnit: .piece,
                    importedSurfaceName: fractional.coreName
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
                    quantityUnit: ingredient.quantityUnit,
                    importedSurfaceName: trimmedName
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
                    quantityUnit: ingredient.quantityUnit,
                    importedSurfaceName: trimmedName
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
                    quantityUnit: .piece,
                    importedSurfaceName: trimmedName
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
                quantityUnit: quantityUnit,
                importedSurfaceName: trimmedName
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
        quantityUnit: RecipeQuantityUnit,
        importedSurfaceName: String? = nil
    ) -> CreateIngredientDraft {
        let explicitQuantityProvided = importedSurfaceHasExplicitQuantity(importedSurfaceName)
            || (importedSurfaceName == nil && (quantityUnit != .piece || abs(quantityValue - 1) > 0.001))
        switch resolved {
        case .produce(let item):
            let canonicalName = item.displayName(languageCode: localizer.languageCode)
            let surface = preservedSpecificImportSurfaceName(
                importedSurfaceName,
                resolved: resolved,
                canonicalName: canonicalName
            )
            let profile = viewModel.quantityProfile(forProduceID: item.id)
            let normalizedMeasurement = explicitQuantityProvided
                ? normalizedSyntheticMeasurement(
                    quantityValue: quantityValue,
                    quantityUnit: quantityUnit,
                    profile: profile,
                    explicitQuantityProvided: true
                )
                : (quantityValue: quantityValue, quantityUnit: quantityUnit)
            let draft = CreateIngredientDraft(
                produceID: item.id,
                basicIngredientID: "",
                customName: surface ?? "",
                searchText: surface ?? canonicalName,
                quantityValue: explicitQuantityProvided ? quantityValueString(normalizedMeasurement.quantityValue) : "",
                quantityUnit: normalizedMeasurement.quantityUnit
            )
            logImportSpecificityStatus(
                importedSurfaceName: importedSurfaceName,
                preservedSurfaceName: surface,
                resolved: resolved,
                canonicalName: canonicalName
            )
            return applyingNonCountableQuantitySemantics(
                to: draft,
                ingredientName: canonicalName,
                explicitQuantityProvided: explicitQuantityProvided
            )
        case .basic(let item):
            let canonicalName = item.displayName(languageCode: localizer.languageCode)
            let surface = preservedSpecificImportSurfaceName(
                importedSurfaceName,
                resolved: resolved,
                canonicalName: canonicalName
            )
            let normalizedMeasurement = explicitQuantityProvided
                ? normalizedSyntheticMeasurement(
                    quantityValue: quantityValue,
                    quantityUnit: quantityUnit,
                    profile: item.unitProfile,
                    explicitQuantityProvided: true
                )
                : (quantityValue: quantityValue, quantityUnit: quantityUnit)
            let draft = CreateIngredientDraft(
                produceID: "",
                basicIngredientID: item.id,
                customName: surface ?? "",
                searchText: surface ?? canonicalName,
                quantityValue: explicitQuantityProvided ? quantityValueString(normalizedMeasurement.quantityValue) : "",
                quantityUnit: normalizedMeasurement.quantityUnit
            )
            logImportSpecificityStatus(
                importedSurfaceName: importedSurfaceName,
                preservedSurfaceName: surface,
                resolved: resolved,
                canonicalName: canonicalName
            )
            return applyingNonCountableQuantitySemantics(
                to: draft,
                ingredientName: canonicalName,
                explicitQuantityProvided: explicitQuantityProvided
            )
        }
    }

    private func preservedSpecificImportSurfaceName(
        _ rawSurfaceName: String?,
        resolved: ImportedIngredientMatch,
        canonicalName: String
    ) -> String? {
        let surface = cleanedImportSurfaceName(rawSurfaceName)
        guard !surface.isEmpty else { return nil }

        // Governed compound aliases can be exact identity matches while still carrying useful
        // preparation specificity in the draft surface.
        if shouldPreserveExactAliasSurface(surface, resolved: resolved) {
            return surface
        }

        let status = localSpecificityStatus(
            importedSurfaceName: surface,
            resolved: resolved,
            canonicalName: canonicalName
        )
        guard status != .exactSpecific else { return nil }
        return surface
    }

    private func shouldPreserveExactAliasSurface(
        _ surface: String,
        resolved: ImportedIngredientMatch
    ) -> Bool {
        let normalized = normalizedIngredientMatchText(surface)
        switch resolved {
        case .basic(let item) where item.id == "capers":
            return normalized == "capperi sotto sale"
        default:
            return false
        }
    }

    private func logImportSpecificityStatus(
        importedSurfaceName: String?,
        preservedSurfaceName: String?,
        resolved: ImportedIngredientMatch,
        canonicalName: String
    ) {
        let surface = cleanedImportSurfaceName(importedSurfaceName)
        guard !surface.isEmpty else { return }

        let status = localSpecificityStatus(
            importedSurfaceName: surface,
            resolved: resolved,
            canonicalName: canonicalName
        )
        let finalDisplayName = preservedSurfaceName ?? canonicalName
        print(
            "[SEASON_IMPORT] phase=specificity_status " +
            "raw=\(surface) matched_entity_id=\(matchedEntityID(for: resolved)) " +
            "final_display_name=\(finalDisplayName) status=\(status.rawValue)"
        )
    }

    private func localSpecificityStatus(
        importedSurfaceName: String,
        resolved: ImportedIngredientMatch,
        canonicalName: String
    ) -> SmartImportLocalSpecificityStatus {
        let surface = normalizedIngredientMatchText(importedSurfaceName)
        let canonical = normalizedIngredientMatchText(canonicalName)
        guard !surface.isEmpty else { return .exactSpecific }
        guard surface != canonical else { return .exactSpecific }

        switch resolved {
        case .basic(let item) where item.id == "flour":
            return flourSurfaceIsSpecific(surface) ? .tooGeneric : .exactSpecific
        case .produce(let item) where item.id == "onion":
            return onionSurfaceIsSpecific(surface) ? .tooGeneric : .exactSpecific
        case .basic(let item) where item.id == "pasta":
            return pastaSurfaceIsSpecificShape(surface) ? .acceptableParentFallback : .exactSpecific
        case .produce(let item) where item.id == "tomato":
            return tomatoSurfaceIsSpecificVariant(importedSurfaceName) ? .acceptableParentFallback : .exactSpecific
        default:
            return .exactSpecific
        }
    }

    private func matchedEntityID(for resolved: ImportedIngredientMatch) -> String {
        switch resolved {
        case .produce(let item):
            return "produce:\(item.id)"
        case .basic(let item):
            return "basic:\(item.id)"
        }
    }

    private func cleanedImportSurfaceName(_ raw: String?) -> String {
        guard let raw else { return "" }
        var cleaned = removingEmojis(from: raw)
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\bingredienti\s*:"#,
            with: "",
            options: .regularExpression
        )
        if let colonIndex = cleaned.lastIndex(of: ":") {
            let suffix = String(cleaned[cleaned.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty {
                cleaned = suffix
            }
        }
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\bq\s*\.?\s*b\s*\.?\b|\bqb\b|\bquanto basta\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\b\d+(?:[.,]\d+)?\s*(g|kg|ml|l)\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\b\d+\s*(spicchio|spicchi|costa|coste|foglia|foglie)\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = normalizedIngredientMatchText(cleaned)
        if normalized.contains("farina 00") {
            return "farina 00"
        }
        if normalized.contains("cipolla rossa") {
            return "cipolla rossa"
        }
        if normalized.contains("cipolla dorata") {
            return "cipolla dorata"
        }
        if normalized.contains("cipolla bianca") {
            return "cipolla bianca"
        }
        if let tomatoSurface = cleanedTomatoFamilySurface(from: cleaned) {
            return tomatoSurface
        }
        if normalized.range(of: #"^farina\s+(00|tipo\s+\d+)$"#, options: .regularExpression) != nil {
            return cleaned
        }

        cleaned = cleaned.replacingOccurrences(
            of: #"\s+\d+$"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func flourSurfaceIsSpecific(_ normalizedSurface: String) -> Bool {
        normalizedSurface.range(of: #"^farina\s+(00|0|1|2|tipo|integrale)\b"#, options: .regularExpression) != nil
            || normalizedSurface.contains("whole wheat flour")
    }

    private func onionSurfaceIsSpecific(_ normalizedSurface: String) -> Bool {
        normalizedSurface.range(of: #"\bcipolla\s+(rossa|rosso|dorata|dorato|bianca|bianco)\b"#, options: .regularExpression) != nil
            || normalizedSurface.range(of: #"\b(red|white|yellow)\s+onion\b"#, options: .regularExpression) != nil
    }

    private func pastaSurfaceIsSpecificShape(_ normalizedSurface: String) -> Bool {
        let shapes = Set([
            "spaghetti", "bucatini", "rigatoni", "trofie",
            "penne", "penne rigate", "fusilli"
        ])
        return shapes.contains(normalizedSurface)
    }

    private func tomatoSurfaceIsSpecificVariant(_ rawSurfaceName: String) -> Bool {
        cleanedTomatoFamilySurface(from: rawSurfaceName).map { surface in
            let normalized = normalizedImportSurfaceWithoutLexical(surface)
            return normalized != "pomodoro" && normalized != "pomodori"
        } ?? false
    }

    private func cleanedTomatoFamilySurface(from raw: String) -> String? {
        var cleaned = removingEmojis(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\b\d+(?:[.,]\d+)?\s*(g|kg|ml|l)?\b"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = normalizedImportSurfaceWithoutLexical(cleaned)
        if normalized.range(of: #"^pomodoro\s+san\s+marzano$"#, options: .regularExpression) != nil {
            return "pomodoro san marzano"
        }
        if normalized == "pomodorini" || normalized == "pomodorino" {
            return normalized
        }
        if normalized == "pomodori" || normalized == "pomodoro" {
            return nil
        }
        return nil
    }

    private func normalizedImportSurfaceWithoutLexical(_ raw: String) -> String {
        strippedParentheticalText(raw)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSyntheticMeasurement(
        quantityValue: Double,
        quantityUnit: RecipeQuantityUnit,
        profile: IngredientUnitProfile,
        explicitQuantityProvided: Bool
    ) -> (quantityValue: Double, quantityUnit: RecipeQuantityUnit) {
        guard !explicitQuantityProvided,
              !profile.supportedUnits.contains(quantityUnit) else {
            return (quantityValue, quantityUnit)
        }

        let fallbackUnit = profile.supportedUnits.contains(profile.defaultUnit)
            ? profile.defaultUnit
            : (profile.supportedUnits.first ?? profile.defaultUnit)
        return (parsedQuantityValue(defaultQuantityValueString(for: fallbackUnit)), fallbackUnit)
    }

    private func importedSurfaceHasExplicitQuantity(_ rawSurfaceName: String?) -> Bool {
        guard let rawSurfaceName else { return false }
        let normalized = normalizedImportSurfaceWithoutLexical(rawSurfaceName)
        guard !normalized.isEmpty else { return false }
        if isQuantoBastaIngredient(rawSurfaceName) { return false }

        let explicitUnitPattern = #"(?i)\b\d+(?:[.,]\d+)?\s*(kg|g|ml|l|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|piece|pieces|pezzo|pezzi)\b"#
        if rawSurfaceName.range(of: explicitUnitPattern, options: .regularExpression) != nil {
            return true
        }

        let leadingBareCountPattern = #"^\s*(\d+(?:[.,]\d+)?)\s+[a-zÀ-ÖØ-öø-ÿ]"#
        if let quantity = firstRegexCapture(in: rawSurfaceName, pattern: leadingBareCountPattern),
           parsedPositiveQuantityToken(quantity) != nil {
            return true
        }

        if normalized.range(of: #"\b(?:tipo|type)\s+\d+(?:[.,]\d+)?$"#, options: .regularExpression) != nil {
            return false
        }

        let trailingBareCountPattern = #"(?i)\b(\d+(?:[.,]\d+)?)\s*$"#
        if let quantity = firstRegexCapture(in: rawSurfaceName, pattern: trailingBareCountPattern),
           parsedPositiveQuantityToken(quantity) != nil {
            return true
        }

        return false
    }

    private func firstRegexCapture(in raw: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: raw) else {
            return nil
        }
        return String(raw[captureRange])
    }

    private func parsedPositiveQuantityToken(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
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
            "oil", "olive oil", "olio", "olio evo", "olio d oliva", "olio extravergine",
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
        guard draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || abs(parsedQuantityValue(draft.quantityValue) - 1) < 0.001
            || abs(parsedQuantityValue(draft.quantityValue) - 100) < 0.001 else { return draft }
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

        if let tomatoMeasurement = normalizedTomatoFamilyMeasurement(
            from: cleaned,
            providedQuantityValue: quantityValue,
            quantityUnit: quantityUnit
        ) {
            return tomatoMeasurement
        }

        let normalized = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized.isEmpty ? rawName : normalized, quantityValue)
    }

    private func normalizedTomatoFamilyMeasurement(
        from rawName: String,
        providedQuantityValue: Double,
        quantityUnit: RecipeQuantityUnit
    ) -> (cleanedName: String, quantityValue: Double)? {
        let unitPattern: String
        switch quantityUnit {
        case .g, .ml:
            unitPattern = #"(?:\s*(?:g|kg|ml|l))?"#
        default:
            unitPattern = #"(?:\s*(?:piece|pieces|pezzo|pezzi))?"#
        }

        let pattern = #"(?i)^\s*((?:pomodoro|pomodori|pomodorino|pomodorini)(?:\s+san\s+marzano)?)\s+(\d+(?:[.,]\d+)?)"# + unitPattern + #"\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(location: 0, length: rawName.utf16.count)
        guard let match = regex.firstMatch(in: rawName, options: [], range: range),
              match.numberOfRanges >= 3 else { return nil }

        let rawTomatoName = nsRangeString(match.range(at: 1), in: rawName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard isTomatoFamilyImportName(rawTomatoName) else { return nil }

        let quantityText = nsRangeString(match.range(at: 2), in: rawName)
            .replacingOccurrences(of: ",", with: ".")
        let parsedQuantity = Double(quantityText).flatMap { $0 > 0 ? $0 : nil } ?? providedQuantityValue
        return (rawTomatoName, parsedQuantity)
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
        let forwardPattern = #"(?i)(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|piece|pieces|pezzo|pezzi)\s+([^,;\n]+)"#
        let reversedPattern = #"(?i)^([^,;\n]+?)\s+(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|piece|pieces|pezzo|pezzi)\s*$"#
        let tomatoBareCountPattern = #"(?i)^((?:pomodoro|pomodori|pomodorino|pomodorini)(?:\s+san\s+marzano)?)\s+(\d+(?:[.,]\d+)?)\s*$"#
        let bareCountPattern = #"(?i)^([[:alpha:]'’ ]+?)\s+(\d+(?:[.,]\d+)?)\s*$"#

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
            case "cucchiaio", "cucchiai":
                return (baseQuantity, .tbsp)
            case "cucchiaino", "cucchiaini":
                return (baseQuantity, .tsp)
            case "spicchio", "spicchi", "clove", "cloves":
                return (baseQuantity, .clove)
            case "piece", "pieces", "pezzo", "pezzi":
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

        // Tomato-family bare counts are common in Italian captions ("pomodori 3").
        // Keep this scoped to tomato inputs so generic ingredient parsing stays unchanged.
        if let regex = try? NSRegularExpression(pattern: tomatoBareCountPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: cleanedLine, options: [], range: fullRange),
           match.numberOfRanges == 3 {
            let recoveredName = normalizedRecoveredName(nsRangeString(match.range(at: 1), in: cleanedLine))
            let quantityRaw = nsRangeString(match.range(at: 2), in: cleanedLine)
                .replacingOccurrences(of: ",", with: ".")
            guard !recoveredName.isEmpty,
                  isTomatoFamilyImportName(recoveredName),
                  let quantityValue = Double(quantityRaw),
                  quantityValue > 0 else { return nil }

            print(
                "[SEASON_IMPORT] phase=explicit_quantity_recovered_tomato_bare_count " +
                "line=\(cleanedLine) name=\(recoveredName) " +
                "quantity=\(quantityValueString(quantityValue)) unit=\(RecipeQuantityUnit.piece.rawValue)"
            )

            return ExplicitQuantityRecovery(
                quantityValue: quantityValue,
                quantityUnit: .piece,
                cleanedName: recoveredName,
                sourceLine: cleanedLine
            )
        }

        // Ingredient-section fragments such as "zucchine 2" or "uova 4" carry an
        // explicit count even without a unit. Keep this anchored and catalog-backed
        // so procedural text does not become a guessed ingredient.
        if let regex = try? NSRegularExpression(pattern: bareCountPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: cleanedLine, options: [], range: fullRange),
           match.numberOfRanges == 3 {
            let recoveredName = normalizedRecoveredName(nsRangeString(match.range(at: 1), in: cleanedLine))
            let quantityRaw = nsRangeString(match.range(at: 2), in: cleanedLine)
                .replacingOccurrences(of: ",", with: ".")
            guard !recoveredName.isEmpty,
                  recoveredName.range(of: #"\b(?:tipo|type)\s+\d+(?:[.,]\d+)?$"#, options: .regularExpression) == nil,
                  !isNonCountableIngredientName(recoveredName),
                  resolveImportedIngredientMatch(query: recoveredName) != nil,
                  let quantityValue = Double(quantityRaw),
                  quantityValue > 0 else { return nil }

            print(
                "[SEASON_IMPORT] phase=explicit_quantity_recovered_bare_count " +
                "line=\(cleanedLine) name=\(recoveredName) " +
                "quantity=\(quantityValueString(quantityValue)) unit=\(RecipeQuantityUnit.piece.rawValue)"
            )

            return ExplicitQuantityRecovery(
                quantityValue: quantityValue,
                quantityUnit: .piece,
                cleanedName: recoveredName,
                sourceLine: cleanedLine
            )
        }

        return nil
    }

    private func isTomatoFamilyImportName(_ raw: String) -> Bool {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        return normalized == "pomodoro"
            || normalized == "pomodori"
            || normalized == "pomodorino"
            || normalized == "pomodorini"
            || normalized == "pomodoro san marzano"
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
        guard recoveredQuantityCandidate(
            recovery.cleanedName,
            isCompatibleWith: ingredient.name
        ) else {
            print(
                "[SEASON_IMPORT] phase=explicit_quantity_candidate_rejected " +
                "source=caption reason=target_mismatch target=\(ingredient.name) recovered=\(recovery.cleanedName)"
            )
            return false
        }
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

    private func recoveredQuantityCandidate(
        _ recoveredName: String,
        isCompatibleWith ingredientName: String
    ) -> Bool {
        let recovered = normalizedIngredientMatchText(recoveredName)
        let target = normalizedIngredientMatchText(ingredientName)
        guard !recovered.isEmpty, !target.isEmpty else { return false }

        let targetQueries = Set(importedIngredientMatchQueries(from: ingredientName))
        if recovered == target || targetQueries.contains(recovered) {
            return true
        }

        // Quantity recovery must not borrow the measured left side from
        // "X 400g con Y e Z" for trailing ingredients like curry or coconut milk.
        let recoveredTokens = Set(recovered.split(separator: " ").map(String.init))
        let targetTokens = Set(targetQueries.flatMap { $0.split(separator: " ").map(String.init) })
        return recoveredTokens.isSubset(of: targetTokens)
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

    private var canRunSmartImport: Bool {
        normalizedImportCaption != nil || normalizedImportSourceURL != nil
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    private enum CreateSectionPriority {
        case primary
        case secondary
        case tertiary
    }

    @ViewBuilder
    private func createSectionContainer(priority: CreateSectionPriority) -> some View {
        switch priority {
        case .primary:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.93))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 0.65)
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.035), lineWidth: 0.6)
                )
        case .tertiary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.34))
        }
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
        if draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
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
        if let forcedSpiceMatch = forcedBlackPepperMatch(for: query) {
            return forcedSpiceMatch
        }
        if let forcedVegetableMatch = forcedBellPepperMatch(for: query) {
            return forcedVegetableMatch
        }
        if let forcedEggplantMatch = forcedEggplantMatch(for: query) {
            return forcedEggplantMatch
        }
        if isProtectedEggplantSurface(query) {
            return nil
        }
        if let forcedCoconutMilk = forcedCoconutMilkMatch(for: query) {
            return forcedCoconutMilk
        }
        if isProtectedCoconutMilkSurface(query) {
            return nil
        }
        if let forcedFish = forcedFishMatch(for: query) {
            return forcedFish
        }
        if isProtectedFishSurface(query) {
            return nil
        }
        if let forcedMeat = forcedMeatMatch(for: query) {
            return forcedMeat
        }
        if let forcedPastaMatch = forcedPastaOverCondimentMatch(for: query) {
            return forcedPastaMatch
        }

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

    private func forcedBlackPepperMatch(for raw: String) -> ImportedIngredientMatch? {
        var normalized = normalizedImportSurfaceWithoutLexical(raw)
        normalized = normalized.replacingOccurrences(
            of: #"\bquanto\s+basta\b|\bq\s*b\b|\bqb\b"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized == "pepe"
            || normalized == "pepe nero"
            || normalized == "black pepper" else {
            return nil
        }

        guard let blackPepper = BasicIngredientCatalog.all.first(where: { $0.id == "black_pepper" }) else {
            return nil
        }
        return .basic(blackPepper)
    }

    private func forcedBellPepperMatch(for raw: String) -> ImportedIngredientMatch? {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        guard normalized == "peperone"
            || normalized == "peperoni"
            || normalized == "bell pepper"
            || normalized == "bell peppers" else {
            return nil
        }

        guard let bellPepper = viewModel.produceItems.first(where: { $0.id == "bell_pepper" }) else {
            return nil
        }
        return .produce(bellPepper)
    }

    private func forcedEggplantMatch(for raw: String) -> ImportedIngredientMatch? {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        guard protectedImportSurface(normalized, contains: ["melanzana", "melanzane"]) else {
            return nil
        }
        guard let eggplant = viewModel.produceItems.first(where: { $0.id == "eggplant" }) else {
            return nil
        }
        return .produce(eggplant)
    }

    private func forcedPastaOverCondimentMatch(for raw: String) -> ImportedIngredientMatch? {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        guard protectedImportSurface(normalized, contains: ["pasta"]),
              protectedImportSurface(normalized, contains: ["capperi", "capers"]) else {
            return nil
        }
        guard let pasta = BasicIngredientCatalog.all.first(where: { $0.id == "pasta" }) else {
            return nil
        }
        return .basic(pasta)
    }

    private func forcedCoconutMilkMatch(for raw: String) -> ImportedIngredientMatch? {
        guard isProtectedCoconutMilkSurface(raw),
              let coconutMilk = localImportBasicIngredient(forID: "coconut_milk") else {
            return nil
        }
        return .basic(coconutMilk)
    }

    private func forcedFishMatch(for raw: String) -> ImportedIngredientMatch? {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        let targetID: String?
        if protectedImportSurface(normalized, contains: ["orata", "sea bream"]) {
            targetID = "sea_bream"
        } else if protectedImportSurface(normalized, contains: ["pesce spada", "swordfish"]) {
            targetID = "swordfish"
        } else if protectedImportSurface(normalized, contains: ["salmone", "salmon"]) {
            targetID = "salmon"
        } else {
            targetID = nil
        }
        guard let targetID,
              let fish = localImportBasicIngredient(forID: targetID) else {
            return nil
        }
        return .basic(fish)
    }

    private func forcedMeatMatch(for raw: String) -> ImportedIngredientMatch? {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        guard normalized == "pollo"
            || normalized == "chicken"
            || normalized == "petto di pollo" else {
            return nil
        }
        guard let chicken = BasicIngredientCatalog.all.first(where: { $0.id == "chicken" }) else {
            return nil
        }
        return .basic(chicken)
    }

    private func localImportBasicIngredient(forID id: String) -> BasicIngredient? {
        viewModel.basicIngredient(forID: id)
            ?? BasicIngredientCatalog.all.first(where: { $0.id == id })
    }

    private func isProtectedCoconutMilkSurface(_ raw: String) -> Bool {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        return protectedImportSurface(normalized, contains: ["latte di cocco", "coconut milk"])
    }

    private func isProtectedEggplantSurface(_ raw: String) -> Bool {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        return protectedImportSurface(normalized, contains: ["melanzana", "melanzane"])
    }

    private func isProtectedFishSurface(_ raw: String) -> Bool {
        let normalized = normalizedImportSurfaceWithoutLexical(raw)
        return protectedImportSurface(normalized, contains: ["salmone", "salmon", "orata", "pesce spada", "swordfish"])
    }

    private func protectedImportSurface(_ normalized: String, contains phrases: [String]) -> Bool {
        phrases.contains { phrase in
            normalized.range(
                of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: phrase))(?![a-z0-9])"#,
                options: .regularExpression
            ) != nil
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
            (#"^black\s+pepper$"#, "black pepper"),
            (#"^pepe\s+nero$"#, "black pepper"),
            (#"^brodo\s+vegetale(?:\s+caldo)?$"#, "broth"),
            (#"^passata\s+di\s+pomodoro$"#, "passata"),
            (#"^pecorino\s+romano$"#, "pecorino"),
            (#"^parmigiano\s+reggiano$"#, "parmesan"),
            (#"^cipoll[ae]\s+dorat[ae]$"#, "cipolla")
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
            "dorata", "dorate",
            "intero", "intera", "interi", "intere",
            "fino", "fina", "fini", "fine",
            "secco", "secca", "secchi", "secche",
            "tritato", "tritata", "tritati", "tritate",
            "grattugiato", "grattugiata",
            "fresco", "fresca", "freschi", "fresche", "caldo", "calda", "fresh",
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

    private func strippedParentheticalText(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
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
        let normalized = strippedParentheticalText(raw)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return italianSmartImportLexicalNormalized(normalized)
    }

    private func italianSmartImportLexicalNormalized(_ raw: String) -> String {
        let variants = [
            "uova": "uovo",
            "carote": "carota",
            "zucchine": "zucchina",
            "patate": "patata",
            "cipolle": "cipolla",
            "funghi": "fungo",
            "dorate": "dorata"
        ]
        return raw
            .split(separator: " ")
            .map { variants[String($0)] ?? String($0) }
            .joined(separator: " ")
    }

    private func removingEmojis(from text: String) -> String {
        text.unicodeScalars
            .filter { scalar in
                !scalar.properties.isEmojiPresentation
                    && scalar.value != 0xFE0F
                    && scalar.value != 0x20E3
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
            "zucchini": ["courgette", "zucchina", "zucchine"],
            "bell_pepper": ["bell pepper", "pepper", "peperone"],
            "chickpeas": ["ceci", "garbanzo", "garbanzo beans"],
            "lentils": ["lenticchie"],
            "beans": ["fagioli"],
            "green_beans": ["fagiolini", "string beans"],
            "cream_cheese": ["formaggio spalmabile"],
            "greek_yogurt": ["yogurt greco"],
            "onion": ["cipolla", "cipolle", "cipolla bianca", "cipolla rossa", "cipolla dorata", "cipolle dorate"],
            "carrot": ["carota", "carote"],
            "mushroom": ["fungo", "funghi"],
            "potato": ["patata", "patate"],
            "celery": ["sedano", "costa di sedano"],
            "milk": ["latte", "latte intero"],
            "flour": ["farina", "farina 00", "wheat flour"],
            "butter": ["burro"],
            "white_wine": ["vino bianco", "vino bianco secco"],
            "pasta": ["pasta", "pasta secca", "spaghetti", "bucatini"],
            "rice": ["riso", "riso secco"],
            "tomato": ["pomodoro", "pomodori", "pomodorino", "pomodorini", "pomodoro san marzano", "cherry tomato", "cherry tomatoes"],
            "tomato_sauce": ["salsa di pomodoro", "passata di pomodoro", "tomato sauce"],
            "passata": ["passata di pomodoro"],
            "olive_oil": ["olio evo", "olio extravergine", "olio extra vergine", "extra virgin olive oil", "olive oil"],
            "broth": ["brodo", "brodo vegetale", "brodo vegetale caldo", "vegetable broth", "vegetable stock"],
            "beef_broth": ["brodo di manzo", "beef broth", "beef stock"],
            "lemon": ["limone"],
            "egg": ["uovo", "uova", "eggs"],
            "eggs": ["uovo", "uova", "eggs"],
            "pecorino": ["pecorino romano"],
            "parmesan": ["parmigiano", "parmigiano reggiano", "parmesan", "parmesan cheese"],
            "guanciale": ["guanciale"],
            "tuna": ["tonno", "tonno sott olio", "tonno sottolio"],
            "anchovies": ["acciughe", "acciughe sott olio", "acciughe sottolio"],
            "capers": ["capperi", "capperi sotto sale"],
            "green_olives": ["olive", "olive verdi"],
            "black_olives": ["olive nere"],
            "garlic": ["aglio", "garlic clove", "garlic cloves"],
            "basil": ["basilico", "fresh basil"],
            "parsley": ["prezzemolo", "fresh parsley"],
            "oregano": ["origano"],
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
            "cipolla dorata": ["onion"],
            "onion": ["cipolla"],
            "carota": ["carrot"],
            "carrot": ["carota"],
            "zucchina": ["zucchini"],
            "zucchini": ["zucchina"],
            "fungo": ["mushroom"],
            "mushroom": ["fungo"],
            "patata": ["potato"],
            "potato": ["patata"],
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
            "spaghetti": ["pasta"],
            "bucatini": ["pasta"],
            "pasta": ["spaghetti", "bucatini"],
            "riso": ["rice"],
            "rice": ["riso"],
            "pomodoro": ["tomato"],
            "pomodori": ["tomato"],
            "pomodorino": ["tomato"],
            "pomodorini": ["tomato"],
            "pomodoro san marzano": ["tomato"],
            "tomato": ["pomodoro"],
            "salsa di pomodoro": ["tomato sauce", "passata di pomodoro"],
            "passata": ["passata di pomodoro", "tomato sauce"],
            "passata di pomodoro": ["passata", "tomato sauce", "salsa di pomodoro"],
            "tomato sauce": ["salsa di pomodoro", "passata di pomodoro"],
            "olio evo": ["olive oil", "extra virgin olive oil", "olio extravergine"],
            "olio extravergine": ["olive oil", "extra virgin olive oil", "olio evo"],
            "olio extra vergine": ["olive oil", "extra virgin olive oil", "olio evo"],
            "olive oil": ["olio evo", "olio extravergine", "olio extra vergine"],
            "extra virgin olive oil": ["olio evo", "olio extravergine", "olio extra vergine"],
            "brodo": ["broth"],
            "brodo vegetale": ["broth"],
            "brodo vegetale caldo": ["broth"],
            "vegetable broth": ["broth"],
            "vegetable stock": ["broth"],
            "vino bianco": ["white wine"],
            "vino bianco secco": ["white wine"],
            "white wine": ["vino bianco"],
            "brodo di manzo": ["beef broth", "beef stock"],
            "beef broth": ["brodo di manzo"],
            "beef stock": ["brodo di manzo"],
            "limone": ["lemon"],
            "lemon": ["limone"],
            "uovo": ["egg", "eggs"],
            "eggs": ["uova"],
            "egg": ["uovo", "uova"],
            "parmigiano": ["parmesan", "parmigiano reggiano"],
            "pecorino romano": ["pecorino"],
            "pecorino": ["pecorino romano"],
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
            "pepe nero": ["black pepper"],
            "guanciale": ["guanciale"],
            "tonno": ["tuna"],
            "tonno sott olio": ["tuna"],
            "tonno sottolio": ["tuna"],
            "tuna": ["tonno"],
            "acciughe": ["anchovies"],
            "acciughe sott olio": ["anchovies"],
            "acciughe sottolio": ["anchovies"],
            "anchovies": ["acciughe"],
            "capperi": ["capers"],
            "capperi sotto sale": ["capers"],
            "capers": ["capperi"],
            "olive": ["green olives"],
            "olive verdi": ["green olives"],
            "olive nere": ["black olives"],
            "green olives": ["olive"],
            "black olives": ["olive nere"],
            "origano": ["oregano"],
            "oregano": ["origano"]
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
        let preservedImportSurfaceName = draft.customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if (!draft.produceID.isEmpty || !draft.basicIngredientID.isEmpty),
           !preservedImportSurfaceName.isEmpty {
            return preservedImportSurfaceName
        }
        if let item = viewModel.produceItem(forID: draft.produceID) {
            return item.displayName(languageCode: localizer.languageCode)
        }
        if let basic = viewModel.basicIngredient(forID: draft.basicIngredientID) {
            return basic.displayName(languageCode: localizer.languageCode)
        }
        if !preservedImportSurfaceName.isEmpty {
            return preservedImportSurfaceName
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
                  let savedPath = await SeasonImageProcessor.saveRecipeImageDataToDocuments(data) else {
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
        Task {
            guard let savedPath = await SeasonImageProcessor.saveRecipeUIImageToDocuments(image, compressionQuality: 0.9) else {
                return
            }

            await MainActor.run {
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
        }
    }

    private func openCameraIfAvailable() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }
        showingCameraPicker = true
    }

    @ViewBuilder
    private func mediaItemCard(image: RecipeImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if recipeImageFileURL(for: image.localPath) != nil {
                        RecipeLocalImageView(
                            image: image,
                            targetSize: CGSize(width: 120, height: 120),
                            contentMode: .fill
                        ) {
                            mediaItemFallback
                        }
                    } else {
                        mediaItemFallback
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

    private var mediaItemFallback: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
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

#if DEBUG
private struct SmartImportRealFlowAuditSample {
    let id: String
    let caption: String
}

private struct SmartImportRealFlowCandidateRow: Codable {
    let rawText: String
    let normalizedText: String
    let possibleQuantity: Double?
    let possibleUnit: String?
    let matchType: String
    let matchedIngredientID: String?
    let requiresLLM: Bool
    let matchedDraftIndex: Int?
}

private struct SmartImportRealFlowDraftRow: Codable {
    let index: Int
    let name: String
    let produceID: String?
    let basicIngredientID: String?
    let quantityValue: String
    let quantityUnit: String
    let isCustom: Bool
}

private struct SmartImportDifficultAuditSample {
    let id: String
    let caption: String
    let expectedIngredients: [String]
}

private struct SmartImportStructuredCandidateRow: Codable {
    let rawText: String
    let normalizedText: String
    let requiresLLM: Bool
    let localMatchID: String?
    let localMatchType: String
}

private struct SmartImportStructuredDraftRow: Codable {
    let displayName: String
    let matchedEntityID: String
    let quantityValue: String
    let quantityUnit: String
    let specificityStatus: String
    let isCustom: Bool
}

private struct SmartImportStructuredDifficultSampleReport: Codable {
    let sampleID: String
    let caption: String
    let parserCandidatesCount: Int
    let parserCandidates: [SmartImportStructuredCandidateRow]
    let finalDraftIngredientsCount: Int
    let finalDraftIngredients: [SmartImportStructuredDraftRow]
    let lostExpectedIngredients: [String]
    let customIngredients: [String]
    let fallbackGateDecision: String
    let fallbackShouldBeConsidered: Bool
    let contaminationNotes: [String]
    let verdict: String
}

private struct SmartImportCaptionHarnessSample: Codable {
    let sampleID: String
    let caption: String
    let sourceURL: String?
    let expectedIngredients: [String]?
}

private struct SmartImportCaptionHarnessInput: Codable {
    let samples: [SmartImportCaptionHarnessSample]
}

private struct SmartImportCaptionHarnessReport: Codable {
    let generatedAt: String
    let inputSource: String
    let samples: [SmartImportStructuredDifficultSampleReport]
    let summary: SmartImportCaptionHarnessSummary
}

private struct SmartImportCaptionHarnessSummary: Codable {
    let totalSamples: Int
    let passCount: Int
    let partialCount: Int
    let failCount: Int
    let missingIngredientsCount: Int
    let customIngredientsCount: Int
    let wrongMatchRiskCount: Int
    let inventedQuantityCount: Int
    let fallbackTriggeredCount: Int
}

private struct SmartImportRealFlowAuditSampleReport: Codable {
    let sampleID: String
    let caption: String
    let localConfidence: String
    let fallbackDecision: String
    let refinementReasons: [String]
    let candidates: [SmartImportRealFlowCandidateRow]
    let finalDraftIngredients: [SmartImportRealFlowDraftRow]
    let lostCandidateTexts: [String]
    let quantityUnitDrifts: [String]
    let customDraftNames: [String]
}

private struct SmartImportRealFlowAuditSummary: Codable {
    let sampleCount: Int
    let totalCandidates: Int
    let totalFinalDraftIngredients: Int
    let lostCandidateCount: Int
    let quantityUnitDriftCount: Int
    let customDraftIngredientCount: Int
    let fallbackAttemptCount: Int
    let fallbackSkippedAllResolvedCount: Int
}

private struct SmartImportRealFlowAuditReport: Codable {
    let samples: [SmartImportRealFlowAuditSampleReport]
    let summary: SmartImportRealFlowAuditSummary
}

extension CreateRecipeView {
    @MainActor
    static func runSmartImportCaptionHarnessIfRequested() async {
        guard ProcessInfo.processInfo.environment["SEASON_RUN_SMART_IMPORT_CAPTION_HARNESS"] == "1" else {
            return
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inputURL = documentsURL.appendingPathComponent("smart-import-batch-input.json")
        let outputURL = documentsURL.appendingPathComponent("smart-import-batch-report.json")
        let loaded = loadSmartImportCaptionHarnessSamples(from: inputURL)
        let samples = loaded.samples.isEmpty ? defaultSmartImportCaptionHarnessSamples : loaded.samples

        let viewModel = ProduceViewModel(languageCode: AppLanguage.italian.rawValue)
        let auditView = CreateRecipeView(viewModel: viewModel)
        var sampleReports: [SmartImportStructuredDifficultSampleReport] = []
        let inputSource = loaded.samples.isEmpty ? "built_in_default_samples" : inputURL.path
        for sample in samples {
            sampleReports.append(auditView.smartImportCaptionHarnessReport(for: sample))
            if sampleReports.count == samples.count || sampleReports.count.isMultiple(of: 25) {
                writeSmartImportCaptionHarnessReport(
                    sampleReports,
                    generatedAt: ISO8601DateFormatter().string(from: Date()),
                    inputSource: inputSource,
                    outputURL: outputURL,
                    phase: sampleReports.count == samples.count ? "wrote_report" : "wrote_partial_report"
                )
            }
            await Task.yield()
        }
    }

    private static func writeSmartImportCaptionHarnessReport(
        _ sampleReports: [SmartImportStructuredDifficultSampleReport],
        generatedAt: String,
        inputSource: String,
        outputURL: URL,
        phase: String
    ) {
        let report = SmartImportCaptionHarnessReport(
            generatedAt: generatedAt,
            inputSource: inputSource,
            samples: sampleReports,
            summary: smartImportCaptionHarnessSummary(for: sampleReports)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(report)
            try data.write(to: outputURL, options: [.atomic])
            print("[SEASON_SMART_IMPORT_CAPTION_HARNESS] phase=\(phase) path=\(outputURL.path) samples=\(sampleReports.count)")
            if phase == "wrote_report",
               let summaryData = try? encoder.encode(report.summary),
               let summary = String(data: summaryData, encoding: .utf8) {
                print("[SEASON_SMART_IMPORT_CAPTION_HARNESS_SUMMARY] \(summary)")
            }
        } catch {
            print("[SEASON_SMART_IMPORT_CAPTION_HARNESS] phase=write_failed error=\(error)")
        }
    }

    @MainActor
    static func runSmartImportRealFlowAuditIfRequested() async {
        guard ProcessInfo.processInfo.environment["SEASON_RUN_SMART_IMPORT_REAL_FLOW_AUDIT"] == "1" else {
            return
        }

        let report = smartImportRealFlowAuditReport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        print("[SEASON_SMART_IMPORT_REAL_FLOW_AUDIT] phase=begin samples=\(report.samples.count)")
        for sample in report.samples {
            if let data = try? encoder.encode(sample),
               let json = String(data: data, encoding: .utf8) {
                print("[SEASON_SMART_IMPORT_REAL_FLOW_AUDIT_ROW] \(json)")
            }
        }
        for sample in smartImportStructuredDifficultAuditReport() {
            if let data = try? encoder.encode(sample),
               let json = String(data: data, encoding: .utf8) {
                print("[SEASON_SMART_IMPORT_CREATOR_DIFFICULT_AUDIT_ROW] \(json)")
            }
        }
        if let data = try? encoder.encode(report.summary),
           let json = String(data: data, encoding: .utf8) {
            print("[SEASON_SMART_IMPORT_REAL_FLOW_AUDIT_SUMMARY] \(json)")
        }
        print("[SEASON_SMART_IMPORT_REAL_FLOW_AUDIT] phase=end")
    }

    @MainActor
    private static func smartImportRealFlowAuditReport() -> SmartImportRealFlowAuditReport {
        let viewModel = ProduceViewModel(languageCode: AppLanguage.italian.rawValue)
        let auditView = CreateRecipeView(viewModel: viewModel)
        let reports = smartImportRealFlowAuditSamples.map { sample in
            auditView.smartImportRealFlowAuditSampleReport(for: sample)
        }

        let summary = SmartImportRealFlowAuditSummary(
            sampleCount: reports.count,
            totalCandidates: reports.reduce(0) { $0 + $1.candidates.count },
            totalFinalDraftIngredients: reports.reduce(0) { $0 + $1.finalDraftIngredients.count },
            lostCandidateCount: reports.reduce(0) { $0 + $1.lostCandidateTexts.count },
            quantityUnitDriftCount: reports.reduce(0) { $0 + $1.quantityUnitDrifts.count },
            customDraftIngredientCount: reports.reduce(0) { $0 + $1.customDraftNames.count },
            fallbackAttemptCount: reports.filter { $0.fallbackDecision == "attempt_server_fallback" }.count,
            fallbackSkippedAllResolvedCount: reports.filter { $0.fallbackDecision == "skip_server_fallback_all_candidates_resolved" }.count
        )

        return SmartImportRealFlowAuditReport(samples: reports, summary: summary)
    }

    @MainActor
    private static func smartImportStructuredDifficultAuditReport() -> [SmartImportStructuredDifficultSampleReport] {
        let viewModel = ProduceViewModel(languageCode: AppLanguage.italian.rawValue)
        let auditView = CreateRecipeView(viewModel: viewModel)
        return smartImportStructuredDifficultAuditSamples.map { sample in
            auditView.smartImportStructuredDifficultSampleReport(for: sample)
        }
    }

    private static func loadSmartImportCaptionHarnessSamples(
        from inputURL: URL
    ) -> (samples: [SmartImportCaptionHarnessSample], source: String) {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            return ([], "built_in_default_samples")
        }

        do {
            let data = try Data(contentsOf: inputURL)
            let decoder = JSONDecoder()
            if let wrapped = try? decoder.decode([SmartImportCaptionHarnessSample].self, from: data) {
                return (wrapped, inputURL.path)
            }
            let report = try decoder.decode(SmartImportCaptionHarnessInput.self, from: data)
            return (report.samples, inputURL.path)
        } catch {
            print("[SEASON_SMART_IMPORT_CAPTION_HARNESS] phase=input_decode_failed path=\(inputURL.path) error=\(error)")
            return ([], "built_in_default_samples")
        }
    }

    private static func smartImportCaptionHarnessSummary(
        for reports: [SmartImportStructuredDifficultSampleReport]
    ) -> SmartImportCaptionHarnessSummary {
        SmartImportCaptionHarnessSummary(
            totalSamples: reports.count,
            passCount: reports.filter { $0.verdict == "pass" }.count,
            partialCount: reports.filter { $0.verdict == "partial" }.count,
            failCount: reports.filter { $0.verdict == "fail" }.count,
            missingIngredientsCount: reports.reduce(0) { $0 + $1.lostExpectedIngredients.count },
            customIngredientsCount: reports.reduce(0) { $0 + $1.customIngredients.count },
            wrongMatchRiskCount: reports.reduce(0) { total, report in
                total
                    + report.contaminationNotes.count
                    + report.finalDraftIngredients.filter { $0.specificityStatus == SmartImportLocalSpecificityStatus.tooGeneric.rawValue }.count
            },
            inventedQuantityCount: reports.reduce(0) { $0 + smartImportInventedQuantityCount(for: $1) },
            fallbackTriggeredCount: reports.filter { $0.fallbackGateDecision == "attempt_server_fallback" }.count
        )
    }

    private static func smartImportInventedQuantityCount(
        for report: SmartImportStructuredDifficultSampleReport
    ) -> Int {
        report.finalDraftIngredients.filter { draft in
            guard !draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            return !report.parserCandidates.contains { candidate in
                candidate.localMatchID == draft.matchedEntityID
            }
        }.count
    }

    private func smartImportRealFlowAuditSampleReport(
        for sample: SmartImportRealFlowAuditSample
    ) -> SmartImportRealFlowAuditSampleReport {
        let cleanedCaption = removingEmojis(from: sample.caption)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: "",
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )
        let candidates = smartImportIngredientCandidates(from: cleanedCaption)
        let candidatesRequiringLLM = candidates.filter(\.requiresLLM).count
        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let drafts = localSuggestion.suggestedIngredients.map {
            normalizedImportedIngredientDraft(from: $0, sourceCaptionRaw: cleanedCaption)
        }
        let completenessFallback = shouldTriggerFallback(
            parserCandidates: candidates,
            finalDraftIngredients: drafts
        )
        let shouldAttemptServerFallback = localSuggestion.confidence == .low
            || refinement.needsRefinement
            || completenessFallback
        let fallbackDecision: String
        if shouldAttemptServerFallback && !completenessFallback && !candidates.isEmpty && candidatesRequiringLLM == 0 {
            fallbackDecision = "skip_server_fallback_all_candidates_resolved"
        } else if shouldAttemptServerFallback {
            fallbackDecision = "attempt_server_fallback"
        } else {
            fallbackDecision = "keep_local_result"
        }

        let finalRows = drafts.enumerated().map { index, draft in
            SmartImportRealFlowDraftRow(
                index: index,
                name: ingredientDraftDisplayName(draft),
                produceID: draft.produceID.isEmpty ? nil : draft.produceID,
                basicIngredientID: draft.basicIngredientID.isEmpty ? nil : draft.basicIngredientID,
                quantityValue: draft.quantityValue,
                quantityUnit: draft.quantityUnit.rawValue,
                isCustom: draft.produceID.isEmpty && draft.basicIngredientID.isEmpty
            )
        }

        let candidateRows = candidates.map { candidate in
            SmartImportRealFlowCandidateRow(
                rawText: candidate.rawText,
                normalizedText: candidate.normalizedText,
                possibleQuantity: candidate.possibleQuantity,
                possibleUnit: candidate.possibleUnit,
                matchType: candidate.catalogMatch.matchType.rawValue,
                matchedIngredientID: candidate.catalogMatch.matchedIngredientId,
                requiresLLM: candidate.requiresLLM,
                matchedDraftIndex: matchedDraftIndex(for: candidate, drafts: drafts)
            )
        }

        return SmartImportRealFlowAuditSampleReport(
            sampleID: sample.id,
            caption: sample.caption,
            localConfidence: localSuggestion.confidence.rawValue,
            fallbackDecision: fallbackDecision,
            refinementReasons: refinement.reasons,
            candidates: candidateRows,
            finalDraftIngredients: finalRows,
            lostCandidateTexts: candidateRows
                .filter { $0.matchedDraftIndex == nil }
                .map(\.rawText),
            quantityUnitDrifts: quantityUnitDrifts(candidates: candidates, drafts: drafts),
            customDraftNames: finalRows
                .filter(\.isCustom)
                .map(\.name)
        )
    }

    private func smartImportCaptionHarnessReport(
        for sample: SmartImportCaptionHarnessSample
    ) -> SmartImportStructuredDifficultSampleReport {
        let cleanedCaption = removingEmojis(from: sample.caption)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: sample.sourceURL ?? "",
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )
        let candidates = smartImportIngredientCandidates(from: cleanedCaption)
        let candidatesRequiringLLM = candidates.filter(\.requiresLLM).count
        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let drafts = localSuggestion.suggestedIngredients.map {
            normalizedImportedIngredientDraft(from: $0, sourceCaptionRaw: cleanedCaption)
        }
        let completenessFallback = shouldTriggerFallback(
            parserCandidates: candidates,
            finalDraftIngredients: drafts
        )
        let shouldAttemptServerFallback = localSuggestion.confidence == .low
            || refinement.needsRefinement
            || completenessFallback
        let fallbackGateDecision: String
        if shouldAttemptServerFallback {
            fallbackGateDecision = "attempt_server_fallback"
        } else {
            fallbackGateDecision = "keep_local_result"
        }

        let parserCandidates = candidates.map { candidate in
            SmartImportStructuredCandidateRow(
                rawText: candidate.rawText,
                normalizedText: candidate.normalizedText,
                requiresLLM: candidate.requiresLLM,
                localMatchID: candidate.catalogMatch.matchedIngredientId,
                localMatchType: candidate.catalogMatch.matchType.rawValue
            )
        }
        let finalDraftIngredients = drafts.map { structuredDraftRow(for: $0) }
        let lostExpectedIngredients = (sample.expectedIngredients ?? []).filter { expected in
            !smartImportExpectedIngredientArrived(expected: expected, drafts: drafts)
        }
        let customIngredients = finalDraftIngredients
            .filter(\.isCustom)
            .map(\.displayName)
        let contaminationNotes = smartImportContaminationNotes(
            candidates: candidates,
            finalDraftIngredients: finalDraftIngredients
        )
        let fallbackShouldBeConsidered = !lostExpectedIngredients.isEmpty
            || !customIngredients.isEmpty
            || candidatesRequiringLLM > 0
            || completenessFallback
        let verdict: String
        if lostExpectedIngredients.isEmpty && customIngredients.isEmpty && contaminationNotes.isEmpty {
            verdict = "pass"
        } else if !finalDraftIngredients.isEmpty {
            verdict = "partial"
        } else {
            verdict = "fail"
        }

        return SmartImportStructuredDifficultSampleReport(
            sampleID: sample.sampleID,
            caption: sample.caption,
            parserCandidatesCount: candidates.count,
            parserCandidates: parserCandidates,
            finalDraftIngredientsCount: finalDraftIngredients.count,
            finalDraftIngredients: finalDraftIngredients,
            lostExpectedIngredients: lostExpectedIngredients,
            customIngredients: customIngredients,
            fallbackGateDecision: fallbackGateDecision,
            fallbackShouldBeConsidered: fallbackShouldBeConsidered,
            contaminationNotes: contaminationNotes,
            verdict: verdict
        )
    }

    private func smartImportStructuredDifficultSampleReport(
        for sample: SmartImportDifficultAuditSample
    ) -> SmartImportStructuredDifficultSampleReport {
        let cleanedCaption = removingEmojis(from: sample.caption)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: "",
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )
        let candidates = smartImportIngredientCandidates(from: cleanedCaption)
        let candidatesRequiringLLM = candidates.filter(\.requiresLLM).count
        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let drafts = localSuggestion.suggestedIngredients.map {
            normalizedImportedIngredientDraft(from: $0, sourceCaptionRaw: cleanedCaption)
        }
        let completenessFallback = shouldTriggerFallback(
            parserCandidates: candidates,
            finalDraftIngredients: drafts
        )
        let shouldAttemptServerFallback = localSuggestion.confidence == .low
            || refinement.needsRefinement
            || completenessFallback
        let fallbackGateDecision: String
        if shouldAttemptServerFallback {
            fallbackGateDecision = "attempt_server_fallback"
        } else {
            fallbackGateDecision = "keep_local_result"
        }

        let parserCandidates = candidates.map { candidate in
            SmartImportStructuredCandidateRow(
                rawText: candidate.rawText,
                normalizedText: candidate.normalizedText,
                requiresLLM: candidate.requiresLLM,
                localMatchID: candidate.catalogMatch.matchedIngredientId,
                localMatchType: candidate.catalogMatch.matchType.rawValue
            )
        }
        let finalDraftIngredients = drafts.map { structuredDraftRow(for: $0) }
        let lostExpectedIngredients = sample.expectedIngredients.filter { expected in
            !smartImportExpectedIngredientArrived(expected: expected, drafts: drafts)
        }
        let customIngredients = finalDraftIngredients
            .filter(\.isCustom)
            .map(\.displayName)
        let contaminationNotes = smartImportContaminationNotes(
            candidates: candidates,
            finalDraftIngredients: finalDraftIngredients
        )
        let fallbackShouldBeConsidered = !lostExpectedIngredients.isEmpty
            || !customIngredients.isEmpty
            || candidatesRequiringLLM > 0
        let verdict: String
        if lostExpectedIngredients.isEmpty && customIngredients.isEmpty && contaminationNotes.isEmpty {
            verdict = "pass"
        } else if !finalDraftIngredients.isEmpty {
            verdict = "partial"
        } else {
            verdict = "fail"
        }

        return SmartImportStructuredDifficultSampleReport(
            sampleID: sample.id,
            caption: sample.caption,
            parserCandidatesCount: candidates.count,
            parserCandidates: parserCandidates,
            finalDraftIngredientsCount: finalDraftIngredients.count,
            finalDraftIngredients: finalDraftIngredients,
            lostExpectedIngredients: lostExpectedIngredients,
            customIngredients: customIngredients,
            fallbackGateDecision: fallbackGateDecision,
            fallbackShouldBeConsidered: fallbackShouldBeConsidered,
            contaminationNotes: contaminationNotes,
            verdict: verdict
        )
    }

    private func structuredDraftRow(for draft: CreateIngredientDraft) -> SmartImportStructuredDraftRow {
        let quantityValue = draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return SmartImportStructuredDraftRow(
            displayName: ingredientDraftDisplayName(draft),
            matchedEntityID: specificityEntityID(for: draft),
            quantityValue: quantityValue,
            quantityUnit: quantityValue.isEmpty ? "" : draft.quantityUnit.rawValue,
            specificityStatus: structuredSpecificityStatus(for: draft),
            isCustom: draft.produceID.isEmpty && draft.basicIngredientID.isEmpty
        )
    }

    private func structuredSpecificityStatus(for draft: CreateIngredientDraft) -> String {
        if draft.produceID.isEmpty && draft.basicIngredientID.isEmpty {
            return SmartImportLocalSpecificityStatus.customUnresolved.rawValue
        }
        if let item = viewModel.produceItem(forID: draft.produceID) {
            return localSpecificityStatus(
                importedSurfaceName: ingredientDraftDisplayName(draft),
                resolved: .produce(item),
                canonicalName: item.displayName(languageCode: localizer.languageCode)
            ).rawValue
        }
        if let item = viewModel.basicIngredient(forID: draft.basicIngredientID) {
            return localSpecificityStatus(
                importedSurfaceName: ingredientDraftDisplayName(draft),
                resolved: .basic(item),
                canonicalName: item.displayName(languageCode: localizer.languageCode)
            ).rawValue
        }
        return SmartImportLocalSpecificityStatus.customUnresolved.rawValue
    }

    private func smartImportStructuredDraftContains(
        expected: String,
        drafts: [CreateIngredientDraft]
    ) -> Bool {
        let expectedTokens = Set(normalizedIngredientMatchText(expected).split(separator: " ").map(String.init))
        guard !expectedTokens.isEmpty else { return false }

        return drafts.contains { draft in
            let displayName = ingredientDraftDisplayName(draft)
            if smartImportText(displayName, containsAll: expectedTokens) {
                return true
            }
            return importedIngredientMatchQueries(from: displayName).contains { query in
                smartImportText(query, containsAll: expectedTokens)
            }
        }
    }

    private func smartImportExpectedIngredientArrived(
        expected: String,
        drafts: [CreateIngredientDraft]
    ) -> Bool {
        if let expectedEntityID = smartImportExpectedEntityID(expected) {
            return drafts.contains { specificityEntityID(for: $0) == expectedEntityID }
        }
        return smartImportStructuredDraftContains(expected: expected, drafts: drafts)
    }

    private func smartImportExpectedEntityID(_ expected: String) -> String? {
        let normalized = normalizedCommonIngredientPhrase(expected)
        guard let resolved = resolveImportedIngredientMatch(query: normalized) else {
            return nil
        }
        return matchedEntityID(for: resolved)
    }

    private func smartImportText(_ raw: String, containsAll tokens: Set<String>) -> Bool {
        let normalized = normalizedIngredientMatchText(raw)
        guard !normalized.isEmpty else { return false }
        let textTokens = Set(normalized.split(separator: " ").map(String.init))
        return tokens.isSubset(of: textTokens)
    }

    private func smartImportContaminationNotes(
        candidates: [SmartImportIngredientCandidate],
        finalDraftIngredients: [SmartImportStructuredDraftRow]
    ) -> [String] {
        let noisePattern = #"(?i)\b(taglia|aggiungi|poi|forno|doratura|questa|nasce|avevo|fine|raffredda|condisci|rosola|spegni|tosta|sfuma)\b"#
        var notes: [String] = []
        for candidate in candidates {
            if candidate.rawText.range(of: noisePattern, options: .regularExpression) != nil {
                notes.append("candidate_noise:\(candidate.rawText)")
            }
        }
        for ingredient in finalDraftIngredients {
            if ingredient.displayName.range(of: noisePattern, options: .regularExpression) != nil {
                notes.append("draft_noise:\(ingredient.displayName)")
            }
        }
        return notes
    }

    private func matchedDraftIndex(
        for candidate: SmartImportIngredientCandidate,
        drafts: [CreateIngredientDraft]
    ) -> Int? {
        if let matchedIngredientID = candidate.catalogMatch.matchedIngredientId {
            for (index, draft) in drafts.enumerated() {
                if !draft.produceID.isEmpty && matchedIngredientID == "produce:\(draft.produceID)" {
                    return index
                }
                if !draft.basicIngredientID.isEmpty && matchedIngredientID == "basic:\(draft.basicIngredientID)" {
                    return index
                }
            }
        }

        let normalizedCandidate = normalizedIngredientMatchText(candidate.normalizedText)
        guard !normalizedCandidate.isEmpty else { return nil }
        for (index, draft) in drafts.enumerated() {
            let normalizedDraft = normalizedIngredientMatchText(ingredientDraftDisplayName(draft))
            let draftQueries = Set(importedIngredientMatchQueries(from: ingredientDraftDisplayName(draft)))
            if normalizedDraft == normalizedCandidate || draftQueries.contains(normalizedCandidate) {
                return index
            }
        }
        return nil
    }

    private func quantityUnitDrifts(
        candidates: [SmartImportIngredientCandidate],
        drafts: [CreateIngredientDraft]
    ) -> [String] {
        candidates.compactMap { candidate in
            guard let draftIndex = matchedDraftIndex(for: candidate, drafts: drafts),
                  drafts.indices.contains(draftIndex) else { return nil }
            let draft = drafts[draftIndex]
            var drifts: [String] = []

            if let candidateQuantity = candidate.possibleQuantity {
                let draftQuantity = parsedQuantityValue(draft.quantityValue)
                if draft.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || abs(candidateQuantity - draftQuantity) > 0.001 {
                    drifts.append("quantity \(candidateQuantity)->\(draft.quantityValue.isEmpty ? "empty" : draft.quantityValue)")
                }
            }

            if let candidateUnit = candidate.possibleUnit,
               candidateUnit != draft.quantityUnit.rawValue {
                drifts.append("unit \(candidateUnit)->\(draft.quantityUnit.rawValue)")
            }

            guard !drifts.isEmpty else { return nil }
            return "\(candidate.rawText): \(drifts.joined(separator: ", "))"
        }
    }

    private static let smartImportRealFlowAuditSamples: [SmartImportRealFlowAuditSample] = [
        SmartImportRealFlowAuditSample(
            id: "inline_pomodoro",
            caption: "Ingredienti: 200g spaghetti / passata di pomodoro 250g / olio evo q.b. / sale q.b."
        ),
        SmartImportRealFlowAuditSample(
            id: "bare_count_veg",
            caption: "zucchine 2 / patate 3 / cipolle dorate 1 / olio evo q.b."
        ),
        SmartImportRealFlowAuditSample(
            id: "frittata_bare_count",
            caption: "4 uova / zucchine 2 / parmigiano 30g / sale q.b. / pepe q.b."
        ),
        SmartImportRealFlowAuditSample(
            id: "farina_dough",
            caption: "farina 00 500g / acqua 350 ml / olio evo q.b. / sale q.b."
        ),
        SmartImportRealFlowAuditSample(
            id: "pasta_al_volo",
            caption: "pasta al volo: 200g pasta, 1 spicchio aglio, olio evo q.b., acciughe sott'olio 2, capperi sotto sale"
        ),
        SmartImportRealFlowAuditSample(
            id: "carbonara",
            caption: "Carbonara cremosa: spaghetti 200g / guanciale 80g / 2 uova / pecorino romano 40g / pepe nero q.b."
        ),
        SmartImportRealFlowAuditSample(
            id: "tonno_capperi_acciughe",
            caption: "Pasta tonno e capperi Ingredienti: pasta 200g; tonno sott'olio 120g; capperi sotto sale; acciughe sott'olio 2; prezzemolo"
        ),
        SmartImportRealFlowAuditSample(
            id: "risotto_funghi",
            caption: "Risotto ai funghi Ingredienti: riso 180g, funghi 250g, brodo vegetale, burro, parmigiano reggiano 30g"
        ),
        SmartImportRealFlowAuditSample(
            id: "noisy_zucchine",
            caption: "SALVA il video! In 5 min: zucchine 2, pasta 200g, olio evo q.b., pepe nero"
        ),
        SmartImportRealFlowAuditSample(
            id: "patate_funghi",
            caption: "Patate e funghi in padella: patate 3 / funghi 200g / aglio 1 spicchio / rosmarino / sale q.b."
        )
    ]

    private static let smartImportStructuredDifficultAuditSamples: [SmartImportDifficultAuditSample] = [
        SmartImportDifficultAuditSample(
            id: "SI-CVP-019",
            caption: "Taglia zucchine 2 e patate 3, aggiungi cipolla dorata 1 e olio evo q.b., poi in forno fino a doratura.",
            expectedIngredients: ["zucchine", "patate", "cipolla dorata", "olio evo"]
        ),
        SmartImportDifficultAuditSample(
            id: "SI-CVP-025",
            caption: "Questa pasta nasce con quello che avevo: spaghetti, pomodoro, olio buono, aglio e basilico. Fine.",
            expectedIngredients: ["spaghetti", "pomodoro", "olio", "aglio", "basilico"]
        )
    ]

    private static let defaultSmartImportCaptionHarnessSamples: [SmartImportCaptionHarnessSample] = [
        SmartImportCaptionHarnessSample(
            sampleID: "harness_001_structured_easy",
            caption: "Ingredienti: 200g spaghetti / passata di pomodoro 250g / olio evo q.b. / sale q.b.",
            sourceURL: nil,
            expectedIngredients: ["spaghetti", "passata", "olio evo", "sale"]
        ),
        SmartImportCaptionHarnessSample(
            sampleID: "harness_002_quantityless",
            caption: "Ingredienti: riso 180g / funghi 250g / brodo vegetale / burro / parmigiano reggiano 30g",
            sourceURL: nil,
            expectedIngredients: ["riso", "funghi", "brodo vegetale", "burro", "parmigiano reggiano"]
        ),
        SmartImportCaptionHarnessSample(
            sampleID: "harness_003_noisy",
            caption: "SALVA il video! In 5 min: zucchine 2, pasta 200g, olio evo q.b., pepe nero",
            sourceURL: nil,
            expectedIngredients: ["zucchine", "pasta", "olio evo", "pepe nero"]
        ),
        SmartImportCaptionHarnessSample(
            sampleID: "SI-CVP-019",
            caption: "Taglia zucchine 2 e patate 3, aggiungi cipolla dorata 1 e olio evo q.b., poi in forno fino a doratura.",
            sourceURL: nil,
            expectedIngredients: ["zucchine", "patate", "cipolla dorata", "olio evo"]
        ),
        SmartImportCaptionHarnessSample(
            sampleID: "SI-CVP-025",
            caption: "Questa pasta nasce con quello che avevo: spaghetti, pomodoro, olio buono, aglio e basilico. Fine.",
            sourceURL: nil,
            expectedIngredients: ["spaghetti", "pomodoro", "olio", "aglio", "basilico"]
        )
    ]
}

private struct SmartImportSpecificityExpected {
    let sourceText: String
    let normalizedNeedle: String
    let expectedSpecificTarget: String
    let exactEntityID: String?
    let parentEntityIDs: Set<String>
    let wrongEntityIDs: Set<String>
    let allowParentFallback: Bool
    let requiresSpecificVariant: Bool
}

private struct SmartImportSpecificitySample {
    let id: String
    let caption: String
    let expected: [SmartImportSpecificityExpected]
}

private struct SmartImportSpecificityIngredientResult: Codable {
    let rawText: String
    let normalizedText: String
    let expectedSpecificTarget: String
    let actualFinalName: String
    let actualMatchType: String
    let matchedEntityType: String
    let matchedEntityID: String
    let extractedQuantity: String
    let extractedUnit: String
    let specificityResult: String
}

private struct SmartImportSpecificitySampleReport: Codable {
    let sampleID: String
    let caption: String
    let parserCandidatesCount: Int
    let finalDraftIngredientsCount: Int
    let finalDraftIngredients: [SmartImportRealFlowDraftRow]
    let lostIngredients: [String]
    let customIngredientsCount: Int
    let serverFallbackAttempted: Bool
    let serverFallbackSkippedAllResolved: Bool
    let ingredientResults: [SmartImportSpecificityIngredientResult]
}

private struct SmartImportSpecificitySummary: Codable {
    let sampleCount: Int
    let ingredientResultCount: Int
    let exactSpecificCount: Int
    let acceptableParentFallbackCount: Int
    let tooGenericCount: Int
    let wrongSpecificMatchCount: Int
    let customUnresolvedCount: Int
    let missingFromDraftCount: Int
    let customIngredientsCount: Int
    let fallbackAttemptCount: Int
    let fallbackSkippedAllResolvedCount: Int
}

extension CreateRecipeView {
    @MainActor
    static func runSmartImportSpecificityAuditIfRequested() async {
        guard ProcessInfo.processInfo.environment["SEASON_RUN_SMART_IMPORT_SPECIFICITY_AUDIT"] == "1" else {
            return
        }

        let report = smartImportSpecificityAuditReports()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT] phase=begin samples=\(report.samples.count)")
        var jsonLines: [String] = []
        for sample in report.samples {
            if let data = try? encoder.encode(sample),
               let json = String(data: data, encoding: .utf8) {
                jsonLines.append(json)
                print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT_ROW] \(json)")
            }
        }
        if let data = try? encoder.encode(report.summary),
           let json = String(data: data, encoding: .utf8) {
            jsonLines.append(json)
            print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT_SUMMARY] \(json)")
        }
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let outputURL = documentsURL.appendingPathComponent("smart-import-specificity-audit.jsonl")
            do {
                try jsonLines.joined(separator: "\n").write(to: outputURL, atomically: true, encoding: .utf8)
                print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT] phase=file_written path=\(outputURL.path)")
            } catch {
                print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT] phase=file_write_failed error=\(error)")
            }
        }
        print("[SEASON_SMART_IMPORT_SPECIFICITY_AUDIT] phase=end")
    }

    @MainActor
    private static func smartImportSpecificityAuditReports() -> (samples: [SmartImportSpecificitySampleReport], summary: SmartImportSpecificitySummary) {
        let viewModel = ProduceViewModel(languageCode: AppLanguage.italian.rawValue)
        let auditView = CreateRecipeView(viewModel: viewModel)
        let sampleReports = smartImportSpecificitySamples.map {
            auditView.smartImportSpecificityReport(for: $0)
        }
        let allResults = sampleReports.flatMap(\.ingredientResults)
        let summary = SmartImportSpecificitySummary(
            sampleCount: sampleReports.count,
            ingredientResultCount: allResults.count,
            exactSpecificCount: allResults.filter { $0.specificityResult == "exact_specific" }.count,
            acceptableParentFallbackCount: allResults.filter { $0.specificityResult == "acceptable_parent_fallback" }.count,
            tooGenericCount: allResults.filter { $0.specificityResult == "too_generic" }.count,
            wrongSpecificMatchCount: allResults.filter { $0.specificityResult == "wrong_specific_match" }.count,
            customUnresolvedCount: allResults.filter { $0.specificityResult == "custom_unresolved" }.count,
            missingFromDraftCount: allResults.filter { $0.specificityResult == "missing_from_draft" }.count,
            customIngredientsCount: sampleReports.reduce(0) { $0 + $1.customIngredientsCount },
            fallbackAttemptCount: sampleReports.filter(\.serverFallbackAttempted).count,
            fallbackSkippedAllResolvedCount: sampleReports.filter(\.serverFallbackSkippedAllResolved).count
        )
        return (sampleReports, summary)
    }

    private func smartImportSpecificityReport(
        for sample: SmartImportSpecificitySample
    ) -> SmartImportSpecificitySampleReport {
        let cleanedCaption = removingEmojis(from: sample.caption)
        let localSuggestion = SocialImportParser.parse(
            sourceURLRaw: "",
            captionRaw: cleanedCaption,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )
        let candidates = smartImportIngredientCandidates(from: cleanedCaption)
        let candidatesRequiringLLM = candidates.filter(\.requiresLLM).count
        let refinement = shouldRefineImportedSuggestion(localSuggestion, sourceCaption: cleanedCaption)
        let drafts = localSuggestion.suggestedIngredients.map {
            normalizedImportedIngredientDraft(from: $0, sourceCaptionRaw: cleanedCaption)
        }
        let completenessFallback = shouldTriggerFallback(
            parserCandidates: candidates,
            finalDraftIngredients: drafts
        )
        let shouldAttemptServerFallback = localSuggestion.confidence == .low
            || refinement.needsRefinement
            || completenessFallback
        let serverFallbackSkippedAllResolved = shouldAttemptServerFallback
            && !completenessFallback
            && !candidates.isEmpty
            && candidatesRequiringLLM == 0
        let serverFallbackAttempted = shouldAttemptServerFallback && !serverFallbackSkippedAllResolved
        let finalDraftIngredients = drafts.enumerated().map { index, draft in
            SmartImportRealFlowDraftRow(
                index: index,
                name: ingredientDraftDisplayName(draft),
                produceID: draft.produceID.isEmpty ? nil : draft.produceID,
                basicIngredientID: draft.basicIngredientID.isEmpty ? nil : draft.basicIngredientID,
                quantityValue: draft.quantityValue,
                quantityUnit: draft.quantityUnit.rawValue,
                isCustom: draft.produceID.isEmpty && draft.basicIngredientID.isEmpty
            )
        }

        var usedDraftIndexes = Set<Int>()
        var lostIngredients: [String] = []
        let ingredientResults = sample.expected.map { expected in
            let candidate = bestSpecificityCandidate(for: expected, candidates: candidates)
            let draftIndex = bestSpecificityDraftIndex(
                for: expected,
                candidate: candidate,
                drafts: drafts,
                usedDraftIndexes: usedDraftIndexes
            )
            if let draftIndex {
                usedDraftIndexes.insert(draftIndex)
            }
            let draft = draftIndex.flatMap { drafts.indices.contains($0) ? drafts[$0] : nil }
            if draft == nil {
                lostIngredients.append(expected.sourceText)
            }
            return specificityIngredientResult(
                expected: expected,
                candidate: candidate,
                draft: draft
            )
        }

        return SmartImportSpecificitySampleReport(
            sampleID: sample.id,
            caption: sample.caption,
            parserCandidatesCount: candidates.count,
            finalDraftIngredientsCount: drafts.count,
            finalDraftIngredients: finalDraftIngredients,
            lostIngredients: lostIngredients,
            customIngredientsCount: drafts.filter { $0.produceID.isEmpty && $0.basicIngredientID.isEmpty }.count,
            serverFallbackAttempted: serverFallbackAttempted,
            serverFallbackSkippedAllResolved: serverFallbackSkippedAllResolved,
            ingredientResults: ingredientResults
        )
    }

    private func bestSpecificityCandidate(
        for expected: SmartImportSpecificityExpected,
        candidates: [SmartImportIngredientCandidate]
    ) -> SmartImportIngredientCandidate? {
        let needle = normalizedIngredientMatchText(expected.normalizedNeedle)
        if let exactRaw = candidates.first(where: { normalizedIngredientMatchText($0.rawText) == needle }) {
            return exactRaw
        }
        if let containsRaw = candidates.first(where: { normalizedIngredientMatchText($0.rawText).contains(needle) }) {
            return containsRaw
        }
        if let containsNormalized = candidates.first(where: { normalizedIngredientMatchText($0.normalizedText).contains(needle) }) {
            return containsNormalized
        }
        let expectedEntityIDs = Set(([expected.exactEntityID].compactMap { $0 }) + Array(expected.parentEntityIDs))
        return candidates.first { candidate in
            guard let matched = candidate.catalogMatch.matchedIngredientId else { return false }
            return expectedEntityIDs.contains(matched)
        }
    }

    private func bestSpecificityDraftIndex(
        for expected: SmartImportSpecificityExpected,
        candidate: SmartImportIngredientCandidate?,
        drafts: [CreateIngredientDraft],
        usedDraftIndexes: Set<Int>
    ) -> Int? {
        if let candidate,
           let matchedIngredientID = candidate.catalogMatch.matchedIngredientId {
            for (index, draft) in drafts.enumerated() where !usedDraftIndexes.contains(index) {
                if !draft.produceID.isEmpty && matchedIngredientID == "produce:\(draft.produceID)" {
                    return index
                }
                if !draft.basicIngredientID.isEmpty && matchedIngredientID == "basic:\(draft.basicIngredientID)" {
                    return index
                }
            }
        }

        let expectedEntityIDs = Set(([expected.exactEntityID].compactMap { $0 }) + Array(expected.parentEntityIDs))
        for (index, draft) in drafts.enumerated() where !usedDraftIndexes.contains(index) {
            let draftEntityID = specificityEntityID(for: draft)
            if expectedEntityIDs.contains(draftEntityID) {
                return index
            }
        }

        let needle = normalizedIngredientMatchText(expected.normalizedNeedle)
        for (index, draft) in drafts.enumerated() where !usedDraftIndexes.contains(index) {
            let displayName = normalizedIngredientMatchText(ingredientDraftDisplayName(draft))
            let queries = Set(importedIngredientMatchQueries(from: ingredientDraftDisplayName(draft)))
            if displayName.contains(needle) || queries.contains(needle) {
                return index
            }
        }

        return nil
    }

    private func specificityIngredientResult(
        expected: SmartImportSpecificityExpected,
        candidate: SmartImportIngredientCandidate?,
        draft: CreateIngredientDraft?
    ) -> SmartImportSpecificityIngredientResult {
        let actualName = draft.map(ingredientDraftDisplayName) ?? ""
        let entityType = draft.map(specificityEntityType) ?? "none"
        let entityID = draft.map(specificityEntityID) ?? ""
        let result: String
        if draft == nil {
            result = "missing_from_draft"
        } else if draft?.produceID.isEmpty == true && draft?.basicIngredientID.isEmpty == true {
            result = "custom_unresolved"
        } else if let exact = expected.exactEntityID, entityID == exact {
            result = "exact_specific"
        } else if expected.wrongEntityIDs.contains(entityID) {
            result = "wrong_specific_match"
        } else if expected.parentEntityIDs.contains(entityID) {
            if expected.requiresSpecificVariant {
                result = "too_generic"
            } else if expected.allowParentFallback {
                result = "acceptable_parent_fallback"
            } else {
                result = "too_generic"
            }
        } else if expected.exactEntityID == nil && expected.allowParentFallback {
            result = "acceptable_parent_fallback"
        } else {
            result = "wrong_specific_match"
        }

        return SmartImportSpecificityIngredientResult(
            rawText: candidate?.rawText ?? expected.sourceText,
            normalizedText: candidate?.normalizedText ?? normalizedIngredientMatchText(expected.normalizedNeedle),
            expectedSpecificTarget: expected.expectedSpecificTarget,
            actualFinalName: actualName,
            actualMatchType: candidate?.catalogMatch.matchType.rawValue ?? "none",
            matchedEntityType: entityType,
            matchedEntityID: entityID,
            extractedQuantity: draft?.quantityValue ?? "",
            extractedUnit: draft?.quantityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (draft?.quantityUnit.rawValue ?? "")
                : "",
            specificityResult: result
        )
    }

    private func specificityEntityType(for draft: CreateIngredientDraft) -> String {
        if !draft.produceID.isEmpty { return "produce" }
        if !draft.basicIngredientID.isEmpty { return "basic" }
        return "custom"
    }

    private func specificityEntityID(for draft: CreateIngredientDraft) -> String {
        if !draft.produceID.isEmpty { return "produce:\(draft.produceID)" }
        if !draft.basicIngredientID.isEmpty { return "basic:\(draft.basicIngredientID)" }
        return draft.customName.isEmpty ? draft.searchText : draft.customName
    }

    private static func expect(
        _ sourceText: String,
        needle: String? = nil,
        target: String,
        exact: String? = nil,
        parents: [String] = [],
        wrong: [String] = [],
        allowParent: Bool = false,
        requiresSpecific: Bool = false
    ) -> SmartImportSpecificityExpected {
        SmartImportSpecificityExpected(
            sourceText: sourceText,
            normalizedNeedle: needle ?? sourceText,
            expectedSpecificTarget: target,
            exactEntityID: exact,
            parentEntityIDs: Set(parents),
            wrongEntityIDs: Set(wrong),
            allowParentFallback: allowParent,
            requiresSpecificVariant: requiresSpecific
        )
    }

    private static let smartImportSpecificitySamples: [SmartImportSpecificitySample] = [
        SmartImportSpecificitySample(id: "spec_001_farina_00", caption: "Ingredienti: farina 00 500g / acqua 300 ml / sale q.b. / olio evo q.b.", expected: [
            expect("farina 00 500g", needle: "farina 00", target: "farina 00", parents: ["basic:flour"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_002_cipolla_dorata", caption: "Ingredienti: cipolla dorata 1 / olio evo q.b. / sale q.b.", expected: [
            expect("cipolla dorata 1", needle: "cipolla dorata", target: "cipolla dorata", parents: ["produce:onion"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_003_cipolla_rossa", caption: "Ingredienti: cipolla rossa 1 / aceto / sale", expected: [
            expect("cipolla rossa 1", needle: "cipolla rossa", target: "cipolla rossa", parents: ["produce:onion"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_004_cipolla_bianca", caption: "Ingredienti: cipolla bianca 1 / burro / sale", expected: [
            expect("cipolla bianca 1", needle: "cipolla bianca", target: "cipolla bianca", parents: ["produce:onion"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_005_pecorino_romano", caption: "Ingredienti: pecorino romano 50g / pepe nero q.b. / pasta 200g", expected: [
            expect("pecorino romano 50g", needle: "pecorino romano", target: "pecorino romano", exact: "basic:pecorino", wrong: ["basic:parmesan"])
        ]),
        SmartImportSpecificitySample(id: "spec_006_parmigiano_reggiano", caption: "Ingredienti: parmigiano reggiano 40g / burro / pasta 200g", expected: [
            expect("parmigiano reggiano 40g", needle: "parmigiano reggiano", target: "parmigiano reggiano", exact: "basic:parmesan", wrong: ["basic:pecorino"])
        ]),
        SmartImportSpecificitySample(id: "spec_007_spaghetti", caption: "Ingredienti: spaghetti 200g / olio evo q.b. / aglio 1 spicchio", expected: [
            expect("spaghetti 200g", needle: "spaghetti", target: "spaghetti", parents: ["basic:pasta"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_008_bucatini", caption: "Ingredienti: bucatini 200g / guanciale 80g / pecorino romano 40g", expected: [
            expect("bucatini 200g", needle: "bucatini", target: "bucatini", parents: ["basic:pasta"], allowParent: true),
            expect("pecorino romano 40g", needle: "pecorino romano", target: "pecorino romano", exact: "basic:pecorino", wrong: ["basic:parmesan"])
        ]),
        SmartImportSpecificitySample(id: "spec_009_pomodorini", caption: "Ingredienti: pomodorini 250g / basilico / olio evo q.b.", expected: [
            expect("pomodorini 250g", needle: "pomodorini", target: "pomodorini", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_010_pomodori", caption: "Ingredienti: pomodori 3 / tonno sott'olio 120g / basilico", expected: [
            expect("pomodori 3", needle: "pomodori", target: "pomodori", exact: "produce:tomato", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_011_funghi", caption: "Ingredienti: funghi 250g / aglio 1 spicchio / prezzemolo", expected: [
            expect("funghi 250g", needle: "funghi", target: "funghi", exact: "produce:mushroom", parents: ["produce:mushroom"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_012_erbe_aromatiche", caption: "Ingredienti: erbe aromatiche / olio evo / sale", expected: [
            expect("erbe aromatiche", needle: "erbe aromatiche", target: "erbe aromatiche", parents: ["herbs"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_013_pasta_passata", caption: "Ingredienti: pasta 200g / passata di pomodoro 250g", expected: [
            expect("pasta 200g", needle: "pasta", target: "pasta", exact: "basic:pasta", parents: ["basic:pasta"], allowParent: true),
            expect("passata di pomodoro 250g", needle: "passata di pomodoro", target: "passata di pomodoro", exact: "basic:passata", wrong: ["basic:tomato_sauce", "produce:tomato"])
        ]),
        SmartImportSpecificitySample(id: "spec_014_creator_carbonara", caption: "Carbonara fatta bene 😤 ingredienti: spaghetti 200g / guanciale 100g / 2 uova / pecorino romano 40g / pepe nero q.b. salva il video", expected: [
            expect("spaghetti 200g", needle: "spaghetti", target: "spaghetti", parents: ["basic:pasta"], allowParent: true),
            expect("pecorino romano 40g", needle: "pecorino romano", target: "pecorino romano", exact: "basic:pecorino", wrong: ["basic:parmesan"])
        ]),
        SmartImportSpecificitySample(id: "spec_015_creator_pasta_al_volo", caption: "Pasta al volo: 200g pasta, 1 spicchio aglio, olio evo q.b., acciughe sott'olio 2, capperi sotto sale", expected: [
            expect("200g pasta", needle: "pasta", target: "pasta", exact: "basic:pasta", parents: ["basic:pasta"], allowParent: true),
            expect("acciughe sott'olio 2", needle: "acciughe sott olio", target: "acciughe sott'olio", exact: "basic:anchovies"),
            expect("capperi sotto sale", needle: "capperi sotto sale", target: "capperi sotto sale", exact: "basic:capers")
        ]),
        SmartImportSpecificitySample(id: "spec_016_creator_focaccia", caption: "Focaccia barese: farina 00 500g / acqua 350 ml / olio evo q.b. / sale q.b. / origano", expected: [
            expect("farina 00 500g", needle: "farina 00", target: "farina 00", parents: ["basic:flour"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_017_creator_insalata", caption: "Insalata veloce con cipolla rossa 1, pomodorini 200g, tonno sott’olio 120g, olive, sale", expected: [
            expect("cipolla rossa 1", needle: "cipolla rossa", target: "cipolla rossa", parents: ["produce:onion"], requiresSpecific: true),
            expect("pomodorini 200g", needle: "pomodorini", target: "pomodorini", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_018_creator_risotto", caption: "Risotto ai funghi: riso 180g, funghi 250g, brodo vegetale, burro, parmigiano reggiano 30g", expected: [
            expect("funghi 250g", needle: "funghi", target: "funghi", exact: "produce:mushroom", parents: ["produce:mushroom"], allowParent: true),
            expect("parmigiano reggiano 30g", needle: "parmigiano reggiano", target: "parmigiano reggiano", exact: "basic:parmesan", wrong: ["basic:pecorino"])
        ]),
        SmartImportSpecificitySample(id: "spec_019_farina_integrale", caption: "Ingredienti: farina integrale 400g / acqua 300 ml / sale q.b.", expected: [
            expect("farina integrale 400g", needle: "farina integrale", target: "farina integrale", parents: ["basic:flour"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_020_farina_tipo_1", caption: "Ingredienti: farina tipo 1 400g / acqua 280 ml / olio evo q.b.", expected: [
            expect("farina tipo 1 400g", needle: "farina tipo 1", target: "farina tipo 1", parents: ["basic:flour"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_021_rigatoni", caption: "Ingredienti: rigatoni 200g / passata di pomodoro 250g / pecorino romano 30g", expected: [
            expect("rigatoni 200g", needle: "rigatoni", target: "rigatoni", parents: ["basic:pasta"], allowParent: true),
            expect("pecorino romano 30g", needle: "pecorino romano", target: "pecorino romano", exact: "basic:pecorino", wrong: ["basic:parmesan"])
        ]),
        SmartImportSpecificitySample(id: "spec_022_trofie", caption: "Ingredienti: trofie 200g / pesto / parmigiano reggiano 30g", expected: [
            expect("trofie 200g", needle: "trofie", target: "trofie", parents: ["basic:pasta"], allowParent: true),
            expect("parmigiano reggiano 30g", needle: "parmigiano reggiano", target: "parmigiano reggiano", exact: "basic:parmesan", wrong: ["basic:pecorino"])
        ]),
        SmartImportSpecificitySample(id: "spec_023_penne_pomodorini", caption: "Ingredienti: penne rigate 200g / pomodorini 250g / basilico", expected: [
            expect("penne rigate 200g", needle: "penne rigate", target: "penne rigate", parents: ["basic:pasta"], allowParent: true),
            expect("pomodorini 250g", needle: "pomodorini", target: "pomodorini", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_024_fusilli", caption: "Ingredienti: fusilli 200g / tonno sott'olio 120g / cipolla rossa 1", expected: [
            expect("fusilli 200g", needle: "fusilli", target: "fusilli", parents: ["basic:pasta"], allowParent: true),
            expect("cipolla rossa 1", needle: "cipolla rossa", target: "cipolla rossa", parents: ["produce:onion"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_025_san_marzano", caption: "Ingredienti: pomodoro San Marzano 300g / basilico / olio evo q.b.", expected: [
            expect("pomodoro San Marzano 300g", needle: "pomodoro san marzano", target: "pomodoro San Marzano", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_026_datterini", caption: "Ingredienti: datterini 250g / mozzarella / basilico", expected: [
            expect("datterini 250g", needle: "datterini", target: "datterini", parents: ["produce:tomato"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_027_porcini", caption: "Ingredienti: porcini 200g / riso 180g / burro", expected: [
            expect("porcini 200g", needle: "porcini", target: "porcini", exact: "produce:porcini_mushroom", parents: ["produce:mushroom"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_028_pleurotus", caption: "Ingredienti: pleurotus 250g / aglio 1 spicchio / prezzemolo", expected: [
            expect("pleurotus 250g", needle: "pleurotus", target: "pleurotus", exact: "produce:oyster_mushroom", parents: ["produce:mushroom"], requiresSpecific: true)
        ]),
        SmartImportSpecificitySample(id: "spec_029_pomodoro_single", caption: "Ingredienti: pomodoro 1 / sale / olio evo", expected: [
            expect("pomodoro 1", needle: "pomodoro", target: "pomodoro", exact: "produce:tomato", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_030_pomodori_300g", caption: "Ingredienti: pomodori 300 g / cipolla rossa 1 / olio evo", expected: [
            expect("pomodori 300 g", needle: "pomodori", target: "pomodori", exact: "produce:tomato", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_031_pomodorini_200g_mozzarella", caption: "Ingredienti: pomodorini 200 g / mozzarella 250g / basilico", expected: [
            expect("pomodorini 200 g", needle: "pomodorini", target: "pomodorini", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_032_pasta_fredda_pomodori", caption: "Pasta fredda: pasta 200g, pomodori 3, tonno sott'olio 120g, capperi, basilico", expected: [
            expect("pomodori 3", needle: "pomodori", target: "pomodori", exact: "produce:tomato", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_033_sugo_san_marzano", caption: "Sugo veloce: pomodoro san marzano 300g / aglio 1 spicchio / olio evo", expected: [
            expect("pomodoro san marzano 300g", needle: "pomodoro san marzano", target: "pomodoro san marzano", parents: ["produce:tomato"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_034_quantityless_risotto", caption: "Risotto ai funghi: riso 180g, funghi 250g, brodo vegetale, burro, parmigiano reggiano 30g", expected: [
            expect("riso 180g", needle: "riso", target: "riso", exact: "basic:rice"),
            expect("funghi 250g", needle: "funghi", target: "funghi", exact: "produce:mushroom", parents: ["produce:mushroom"], allowParent: true),
            expect("brodo vegetale", needle: "brodo vegetale", target: "brodo vegetale", exact: "basic:broth"),
            expect("burro", needle: "burro", target: "burro", exact: "basic:butter"),
            expect("parmigiano reggiano 30g", needle: "parmigiano reggiano", target: "parmigiano reggiano", exact: "basic:parmesan", wrong: ["basic:pecorino"])
        ]),
        SmartImportSpecificitySample(id: "spec_035_quantityless_pasta_fredda", caption: "Pasta fredda: pasta 200g, pomodori 3, tonno sott'olio 120g, capperi, basilico. Raffredda e condisci.", expected: [
            expect("pasta 200g", needle: "pasta", target: "pasta", exact: "basic:pasta", parents: ["basic:pasta"], allowParent: true),
            expect("pomodori 3", needle: "pomodori", target: "pomodori", exact: "produce:tomato", parents: ["produce:tomato"], allowParent: true),
            expect("tonno sott'olio 120g", needle: "tonno sott olio", target: "tonno sott'olio", exact: "basic:tuna"),
            expect("capperi", needle: "capperi", target: "capperi", exact: "basic:capers"),
            expect("basilico", needle: "basilico", target: "basilico", exact: "produce:basil")
        ]),
        SmartImportSpecificitySample(id: "spec_036_quantityless_carbonara_noisy", caption: "Carbonara: guanciale 100g, pasta 200g, 2 uova, pecorino romano 50g, pepe nero. Rosola il guanciale e spegni il fuoco.", expected: [
            expect("guanciale 100g", needle: "guanciale", target: "guanciale", exact: "basic:guanciale"),
            expect("pasta 200g", needle: "pasta", target: "pasta", exact: "basic:pasta", parents: ["basic:pasta"], allowParent: true),
            expect("2 uova", needle: "uova", target: "uova", exact: "basic:eggs"),
            expect("pecorino romano 50g", needle: "pecorino romano", target: "pecorino romano", exact: "basic:pecorino", wrong: ["basic:parmesan"]),
            expect("pepe nero", needle: "pepe nero", target: "pepe nero", exact: "basic:black_pepper")
        ]),
        SmartImportSpecificitySample(id: "spec_037_quantityless_insalata_olive", caption: "Insalata veloce con cipolla rossa 1, pomodorini 200g, tonno sott’olio 120g, olive, sale", expected: [
            expect("cipolla rossa 1", needle: "cipolla rossa", target: "cipolla rossa", parents: ["produce:onion"], requiresSpecific: true),
            expect("pomodorini 200g", needle: "pomodorini", target: "pomodorini", parents: ["produce:tomato"], allowParent: true),
            expect("tonno sott’olio 120g", needle: "tonno sott olio", target: "tonno sott'olio", exact: "basic:tuna"),
            expect("olive", needle: "olive", target: "olive", exact: "basic:green_olives"),
            expect("sale", needle: "sale", target: "sale", exact: "basic:salt")
        ]),
        SmartImportSpecificitySample(id: "spec_038_quantityless_focaccia_origano", caption: "Focaccia barese: farina 00 500g / acqua 350 ml / olio evo q.b. / sale q.b. / origano", expected: [
            expect("farina 00 500g", needle: "farina 00", target: "farina 00", parents: ["basic:flour"], requiresSpecific: true),
            expect("origano", needle: "origano", target: "origano", exact: "produce:oregano")
        ]),
        SmartImportSpecificitySample(id: "spec_039_quantityless_risotto_noisy", caption: "Per il risotto: riso 180g, brodo vegetale caldo, funghi 250g. Tosta, sfuma e alla fine burro + parmigiano.", expected: [
            expect("riso 180g", needle: "riso", target: "riso", exact: "basic:rice"),
            expect("brodo vegetale caldo", needle: "brodo vegetale", target: "brodo vegetale", exact: "basic:broth"),
            expect("funghi 250g", needle: "funghi", target: "funghi", exact: "produce:mushroom", parents: ["produce:mushroom"], allowParent: true),
            expect("burro", needle: "burro", target: "burro", exact: "basic:butter"),
            expect("parmigiano", needle: "parmigiano", target: "parmigiano", exact: "basic:parmesan")
        ]),
        SmartImportSpecificitySample(id: "spec_040_quantityless_capperi_sotto_sale", caption: "In padella: aglio 1 spicchio, acciughe sott'olio 3, capperi sotto sale, tonno 120g, pasta 200g.", expected: [
            expect("aglio 1 spicchio", needle: "aglio", target: "aglio", exact: "produce:garlic"),
            expect("acciughe sott'olio 3", needle: "acciughe sott olio", target: "acciughe sott'olio", exact: "basic:anchovies"),
            expect("capperi sotto sale", needle: "capperi sotto sale", target: "capperi sotto sale", exact: "basic:capers"),
            expect("tonno 120g", needle: "tonno", target: "tonno", exact: "basic:tuna"),
            expect("pasta 200g", needle: "pasta", target: "pasta", exact: "basic:pasta", parents: ["basic:pasta"], allowParent: true)
        ]),
        SmartImportSpecificitySample(id: "spec_041_quantityless_ingredienti_noisy", caption: "Non buttare le zucchine! Ingredienti: zucchine 2; uova 3; parmigiano reggiano 40g; pepe nero; basilico", expected: [
            expect("zucchine 2", needle: "zucchine", target: "zucchine", exact: "produce:zucchini", parents: ["produce:zucchini"], allowParent: true),
            expect("uova 3", needle: "uova", target: "uova", exact: "basic:eggs"),
            expect("parmigiano reggiano 40g", needle: "parmigiano reggiano", target: "parmigiano reggiano", exact: "basic:parmesan", wrong: ["basic:pecorino"]),
            expect("pepe nero", needle: "pepe nero", target: "pepe nero", exact: "basic:black_pepper"),
            expect("basilico", needle: "basilico", target: "basilico", exact: "produce:basil")
        ])
    ]
}
#endif

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
