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
    @AppStorage("linkedSocialAccountsRaw") private var linkedSocialAccountsRaw = ""
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var mediaLink = ""
    @State private var instagramURL = ""
    @State private var tiktokURL = ""
    @State private var uploadedImages: [RecipeImage] = []
    @State private var coverImageID: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCameraPicker = false
    @State private var importLink = ""
    @State private var importCaptionRaw = ""
    @State private var detectedSourcePlatform: SocialSourcePlatform?
    @State private var ingredientDrafts: [CreateIngredientDraft] = [CreateIngredientDraft()]
    @State private var stepDrafts: [CreateStepDraft] = [CreateStepDraft()]
    @State private var showPublishError = false
    @State private var importFeedbackText = ""
    @State private var showImportTools = false
    @State private var selectedImportProviderRaw = SocialAuthProvider.instagram.rawValue
    @State private var selectedOwnedPostURL = ""
    @State private var selectedServings = 2
    @State private var showCameraUnavailableAlert = false
    @State private var currentDraftRecipeID: String?
    @State private var lastSavedDraftFingerprint = ""
    @State private var showDraftSavedFeedback = false
    @State private var hasAttemptedInitialDraftLoad = false
    @State private var draftLoadFailed = false
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
                        Text("Draft not found")
                            .font(.headline)
                        Text("The draft could not be loaded.")
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
                if let firstProvider = importableLinkedAccounts.first?.provider.rawValue {
                    selectedImportProviderRaw = firstProvider
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
                    if importableLinkedAccounts.isEmpty {
                        Text(localizer.text(.socialImportConnectAccountsHint))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(localizer.text(.socialImportProviderLabel), selection: $selectedImportProviderRaw) {
                            ForEach(importableLinkedAccounts) { account in
                                Text(providerDisplayName(account.provider))
                                    .tag(account.provider.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedImportableAccount?.eligiblePostURLs.isEmpty == true {
                            Text(localizer.text(.socialImportNoEligiblePostsHint))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(selectedImportableAccount?.eligiblePostURLs ?? [], id: \.self) { url in
                                        Button {
                                            selectedOwnedPostURL = url
                                            importLink = url
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: selectedOwnedPostURL == url ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedOwnedPostURL == url ? .green : .secondary)
                                                Text(url)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color(.secondarySystemGroupedBackground))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }

                    TextField(localizer.text(.socialCaptionRaw), text: $importCaptionRaw, axis: .vertical)
                        .lineLimit(3...5)
                        .textInputAutocapitalization(.sentences)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        applySocialImport()
                    } label: {
                        Label(localizer.text(.importDraft), systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canImportFromConnectedAccount)

                    if !importFeedbackText.isEmpty {
                        Text(importFeedbackText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            sectionTitle("Social links")

            TextField("Instagram URL", text: $instagramURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            TextField("TikTok URL", text: $tiktokURL)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                localizer.text(.ingredientName),
                                text: bindingForIngredientSearch(id: ingredient.id)
                            )
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedIngredientID, equals: ingredient.id)

                            if ingredientIsCustom(ingredient) {
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
                        .disabled(!canPublish)
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
                        .disabled(!canPublish)
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
            return RecipeIngredient(
                produceID: nil,
                basicIngredientID: nil,
                quality: .basic,
                name: customName,
                quantityValue: value,
                quantityUnit: draft.quantityUnit
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

    private var normalizedImportLink: String? {
        let trimmed = selectedOwnedPostURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
            sourceURL: normalizedImportLink,
            sourcePlatform: detectedSourcePlatform,
            sourceCaptionRaw: normalizedImportCaption,
            importedFromSocial: normalizedImportLink != nil,
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
            instagramURL: normalizedInstagramURL,
            tiktokURL: normalizedTikTokURL,
            sourceURL: normalizedImportLink,
            sourcePlatform: detectedSourcePlatform,
            sourceCaptionRaw: normalizedImportCaption,
            importedFromSocial: normalizedImportLink != nil,
            servings: selectedServings,
            prepTimeMinutes: prefillDraft?.prepTimeMinutes,
            cookTimeMinutes: prefillDraft?.cookTimeMinutes,
            difficulty: prefillDraft?.difficulty,
            existingRecipeID: currentDraftRecipeID,
            isRemix: prefillDraft?.isRemix ?? false,
            originalRecipeID: prefillDraft?.originalRecipeID,
            originalRecipeTitle: prefillDraft?.originalRecipeTitle,
            originalAuthorName: prefillDraft?.originalAuthorName
        )

        if published == nil {
            showPublishError = true
            return
        }

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

    private func applySocialImport() {
        guard canImportFromConnectedAccount else {
            importFeedbackText = localizer.text(.socialImportOwnAccountOnly)
            return
        }

        let suggestion = SocialImportParser.parse(
            sourceURLRaw: selectedOwnedPostURL,
            captionRaw: importCaptionRaw,
            produceItems: viewModel.produceItems,
            basicIngredients: BasicIngredientCatalog.all,
            languageCode: localizer.languageCode
        )

        detectedSourcePlatform = suggestion.sourcePlatform

        if let suggestedTitle = suggestion.suggestedTitle, !suggestedTitle.isEmpty {
            title = suggestedTitle
        }

        if !suggestion.suggestedIngredients.isEmpty {
            ingredientDrafts = suggestion.suggestedIngredients.map {
                CreateIngredientDraft(
                    produceID: $0.produceID ?? "",
                    basicIngredientID: $0.basicIngredientID ?? "",
                    customName: ($0.produceID == nil && $0.basicIngredientID == nil) ? $0.name : "",
                    searchText: $0.name,
                    quantityValue: quantityValueString($0.quantityValue),
                    quantityUnit: $0.quantityUnit
                )
            }
            importFeedbackText = localizer.text(.importApplied)
        } else {
            importFeedbackText = localizer.text(.importNoMatches)
        }

        if let sourceURL = suggestion.sourceURL,
           mediaLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mediaLink = sourceURL
        }
    }

    private var linkedSocialAccounts: [LinkedSocialAccount] {
        SocialAccountLinkStore.decode(linkedSocialAccountsRaw)
    }

    private var importableLinkedAccounts: [LinkedSocialAccount] {
        linkedSocialAccounts.filter { $0.provider.supportsRecipeImport }
    }

    private var selectedImportProvider: SocialAuthProvider? {
        SocialAuthProvider(rawValue: selectedImportProviderRaw)
    }

    private var selectedImportableAccount: LinkedSocialAccount? {
        guard let selectedImportProvider else { return importableLinkedAccounts.first }
        return importableLinkedAccounts.first(where: { $0.provider == selectedImportProvider })
    }

    private var canImportFromConnectedAccount: Bool {
        guard let account = selectedImportableAccount else { return false }
        let trimmed = selectedOwnedPostURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return account.eligiblePostURLs.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmed) == .orderedSame
        })
    }

    private func providerDisplayName(_ provider: SocialAuthProvider) -> String {
        switch provider {
        case .instagram:
            return "Instagram"
        case .tiktok:
            return "TikTok"
        case .apple:
            return "Apple"
        }
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
