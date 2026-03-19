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
        let ingredients: [RecipeIngredient]
        let steps: [String]
        let prepTimeMinutes: Int?
        let cookTimeMinutes: Int?
        let difficulty: RecipeDifficulty?
        let isRemix: Bool
        let originalRecipeID: String?
        let originalRecipeTitle: String?
        let originalAuthorName: String?
    }

    @ObservedObject var viewModel: ProduceViewModel
    private let prefillDraft: PrefillDraft?
    @AppStorage("accountUsername") private var accountUsername = "Anna"
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var mediaLink = ""
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
    @FocusState private var focusedIngredientID: UUID?

    private var localizer: AppLocalizer { viewModel.localizer }

    init(viewModel: ProduceViewModel, prefillDraft: PrefillDraft? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.prefillDraft = prefillDraft

        _title = State(initialValue: prefillDraft?.title ?? "")
        let initialMediaLink = prefillDraft?.mediaLinkURL
            ?? prefillDraft?.externalMedia.first?.url
            ?? ""
        _mediaLink = State(initialValue: initialMediaLink)
        _uploadedImages = State(initialValue: prefillDraft?.images ?? [])
        _coverImageID = State(initialValue: prefillDraft?.coverImageID ?? prefillDraft?.images.first?.id)

        if let prefillDraft {
            _ingredientDrafts = State(initialValue: prefillDraft.ingredients.map {
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
            })
            _stepDrafts = State(initialValue: prefillDraft.steps.map { CreateStepDraft(text: $0) })
        } else {
            _ingredientDrafts = State(initialValue: [CreateIngredientDraft()])
            _stepDrafts = State(initialValue: [CreateStepDraft()])
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    importFromLinkSection
                    mediaSection
                    titleSection
                    ingredientsSection
                    stepsSection
                    previewSection
                    publishButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizer.text(.createRecipe))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.text(.done)) {
                        dismiss()
                    }
                }
            }
            .alert(localizer.text(.createRecipeSubtitle), isPresented: $showPublishError) {
                Button("OK", role: .cancel) {}
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
                if detectedSourcePlatform == nil {
                    detectedSourcePlatform = detectedPlatform(for: mediaLink)
                }
            }
        }
    }

    private var mediaSection: some View {
        SeasonCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(localizer.text(.mediaSectionTitle))

                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 8,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(localizer.text(.mediaAddPhotos), systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingCameraPicker = true
                    } label: {
                        Label(localizer.text(.mediaUseCamera), systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                TextField(localizer.text(.mediaExternalLink), text: $mediaLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: mediaLink) { _, newValue in
                        detectedSourcePlatform = detectedPlatform(for: newValue)
                    }

                if let platform = detectedSourcePlatform,
                   let platformLabel = platformDisplayName(platform) {
                    Text(String(format: localizer.text(.detectedPlatformFormat), platformLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if uploadedImages.isEmpty {
                    if let legacyName = prefillDraft?.imageAssetName,
                       hasAsset(named: legacyName) {
                        Image(legacyName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text(localizer.text(.mediaNoImagesYet))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
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
    }

    private var importFromLinkSection: some View {
        SeasonCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(localizer.text(.importFromLinkSectionTitle))

                TextField(localizer.text(.socialLink), text: $importLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField(localizer.text(.socialCaptionRaw), text: $importCaptionRaw, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .textFieldStyle(.roundedBorder)

                Button {
                    applySocialImport()
                } label: {
                    Label(localizer.text(.importDraft), systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)

                if !importFeedbackText.isEmpty {
                    Text(importFeedbackText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var titleSection: some View {
        SeasonCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(localizer.text(.titleSectionTitle))

                TextField(localizer.text(.createRecipe), text: $title, axis: .vertical)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2...3)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
        }
    }

    private var ingredientsSection: some View {
        SeasonCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(localizer.text(.ingredientsSectionTitle))

                ForEach($ingredientDrafts) { $ingredient in
                    VStack(alignment: .leading, spacing: 8) {
                        // Line 1: ingredient selection / custom input
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
                                            Capsule(style: .continuous)
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

                        // Line 2: quantity and unit
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
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
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
    }

    private var stepsSection: some View {
        SeasonCard {
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
    }

    private var previewSection: some View {
        SeasonCard {
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
    }

    private var publishButton: some View {
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
        let trimmed = importLink.trimmingCharacters(in: .whitespacesAndNewlines)
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
            sourceURL: normalizedImportLink,
            sourcePlatform: detectedSourcePlatform,
            sourceCaptionRaw: normalizedImportCaption,
            importedFromSocial: normalizedImportLink != nil,
            prepTimeMinutes: prefillDraft?.prepTimeMinutes,
            cookTimeMinutes: prefillDraft?.cookTimeMinutes,
            difficulty: prefillDraft?.difficulty,
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
        ingredientDrafts.removeAll { $0.id == id }
        if ingredientDrafts.isEmpty {
            ingredientDrafts = [CreateIngredientDraft()]
        }
    }

    private func removeStep(id: UUID) {
        stepDrafts.removeAll { $0.id == id }
        if stepDrafts.isEmpty {
            stepDrafts = [CreateStepDraft()]
        }
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
        let suggestion = SocialImportParser.parse(
            sourceURLRaw: importLink,
            captionRaw: importCaptionRaw,
            produceItems: viewModel.produceItems,
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
        case .piece, .clove, .tbsp, .tsp:
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
