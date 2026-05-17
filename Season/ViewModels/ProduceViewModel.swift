import Foundation
import Combine

struct RankedInSeasonItem: Identifiable {
    let item: ProduceItem
    let score: Double
    let reasons: [String]

    var id: String { item.id }
}

struct IngredientSearchResult: Identifiable {
    enum Source {
        case produce(ProduceItem)
        case basic(BasicIngredient)
    }

    let source: Source
    let title: String
    let subtitle: String
    let relevance: Int

    var id: String {
        switch source {
        case .produce(let item):
            return "produce-\(item.id)"
        case .basic(let item):
            return "basic-\(item.id)"
        }
    }
}

enum SearchPrimaryType {
    case ingredients
    case recipes
}

enum IngredientAliasMatch {
    case produce(ProduceItem)
    case basic(BasicIngredient)
}

struct ResolvedIngredient {
    let recipeIngredient: RecipeIngredient
    let displayName: String
    let produceItem: ProduceItem?
    let basicIngredient: BasicIngredient?
    let isReconciled: Bool
}

enum RecipeTimingLabel: Hashable {
    case perfectNow
    case betterSoon
    case endingSoon
    case goodNow
}

struct RecipeTimingInsight: Hashable {
    let score: Double
    let trend: Double
    let label: RecipeTimingLabel
}

struct HomeRecipeScoreBreakdown: Hashable {
    let seasonality: Double
    let nutrition: Double
    let quality: Double
    let convenience: Double
    let engagement: Double
    let freshness: Double
    let sourceTrust: Double

    var score: Double {
        (0.30 * seasonality)
        + (0.10 * nutrition)
        + (0.18 * quality)
        + (0.13 * convenience)
        + (0.12 * engagement)
        + (0.07 * freshness)
        + (0.10 * sourceTrust)
    }
}

final class ProduceViewModel: ObservableObject {
    private struct UnifiedIngredientParityEntry {
        let ingredientID: String
        let slug: String
        let ingredientType: String
        let enName: String?
        let itName: String?
        let legacyProduceID: String?
        let legacyBasicID: String?
        let isSeasonal: Bool
        let seasonMonths: [Int]
        let nutrition: ProduceNutrition?
        let unitProfile: IngredientUnitProfile
    }

    @Published private(set) var produceItems: [ProduceItem] = []
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var userProfiles: [UserProfile] = []
    @Published private(set) var savedRecipeIDs: Set<String> = []
    @Published private(set) var crispiedRecipeIDs: Set<String> = []
    @Published private(set) var archivedRecipeIDs: Set<String> = []
    @Published private(set) var deletedRecipeIDs: Set<String> = []
    @Published private(set) var recipeViewCounts: [String: Int] = [:]
    @Published private(set) var homeFeedRefreshID: Int = 0
    @Published private(set) var homeFeedDataVersion: Int = 0
    @Published private(set) var rankingDataVersion: Int = 0
    @Published private(set) var didCompleteInitialRemoteRecipeHydration: Bool = false
    @Published private(set) var languageCode: String
    @Published private(set) var nutritionGoals: Set<NutritionGoal> = []
    @Published private(set) var nutritionPriorities: [NutritionPriorityDimension: Double] = NutritionService.defaultNutritionPriorities
    private let nutritionGoalsStorageKey = "nutritionGoalsRaw"
    private let savedRecipeIDsStorageKey = "savedRecipeIDsRaw"
    private let crispiedRecipeIDsStorageKey = "crispiedRecipeIDsRaw"
    private let archivedRecipeIDsStorageKey = "archivedRecipeIDsRaw"
    private let deletedRecipeIDsStorageKey = "deletedRecipeIDsRaw"
    private let recipeViewCountsStorageKey = "recipeViewCountsData"
    private let basicIngredients: [BasicIngredient]
    private let produceByID: [String: ProduceItem]
    private let produceByNormalizedName: [String: ProduceItem]
    private let basicByID: [String: BasicIngredient]
    private let basicByNormalizedName: [String: BasicIngredient]
    private var remoteIngredientAliasLookup: [String: IngredientAliasRecord] = [:]
    private var unifiedIngredientByID: [String: UnifiedIngredientParityEntry] = [:]
    private var unifiedAliasLookup: [String: IngredientAliasMatch] = [:]
    private var unifiedNameLookup: [String: IngredientAliasMatch] = [:]
    private var unifiedEntryAliasLookup: [String: UnifiedIngredientParityEntry] = [:]
    private var unifiedEntryNameLookup: [String: UnifiedIngredientParityEntry] = [:]
    private let nutritionService = NutritionService()
    private let supabaseService = SupabaseService.shared
    private let remoteRecipePageSize = 40
    private var nextRemoteRecipeOffset = 0
    private var hasMoreRemoteRecipePages = true
    private var isFetchingRemoteRecipePage = false
    private let fallbackUnitProfile = IngredientUnitProfile(
        defaultUnit: .g,
        supportedUnits: [.g, .piece],
        gramsPerUnit: [.g: 1, .piece: 100],
        mlPerUnit: [:],
        gramsPerMl: nil
    )

    private var cachedDiscoverableRankedRecipes: [RankedRecipe] = []
    private var cachedDiscoverableRankedByID: [String: RankedRecipe] = [:]
    private var cachedDiscoverableRankedMonth: Int?
    private var cachedMaxCrispy: Int?
    private var cachedMaxViews: Int?
    private var featuredRecipeRotationOffset: Int = 0
    private var isBootstrapping = true
    private var pendingInvalidation = false
    private var bootstrapRemoteRecipesCompleted = false
    private var bootstrapIngredientAliasesCompleted = false
    private var bootstrapGeneration = 0
    private var reconciliationInputVersion = 0
    private var reconciliationNoMatchCache: Set<String> = []
    private var ingredientDisplayResolutionCache: [String: ResolvedIngredient] = [:]

    var localizer: AppLocalizer {
        AppLocalizer(languageCode: languageCode)
    }

    init(languageCode: String = "en") {
        self.languageCode = AppLanguage(rawValue: languageCode)?.rawValue ?? AppLanguage.english.rawValue
        let loadedProduce = ProduceStore.loadFromBundle()
        self.produceItems = loadedProduce
        let loadedBasic = BasicIngredientCatalog.all
        self.basicIngredients = loadedBasic
        self.produceByID = Dictionary(uniqueKeysWithValues: loadedProduce.map { ($0.id, $0) })
        var normalizedProduceIndex: [String: ProduceItem] = [:]
        for item in loadedProduce {
            let normalizedID = item.id.replacingOccurrences(of: "_", with: " ").lowercased()
            normalizedProduceIndex[normalizedID] = item
            for localizedName in item.localizedNames.values {
                normalizedProduceIndex[localizedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = item
            }
            for alias in Self.ingredientAliasesSeed[item.id] ?? [] {
                normalizedProduceIndex[alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = item
            }
        }
        self.produceByNormalizedName = normalizedProduceIndex
        self.basicByID = Dictionary(uniqueKeysWithValues: loadedBasic.map { ($0.id, $0) })
        var normalizedNameIndex: [String: BasicIngredient] = [:]
        for ingredient in loadedBasic {
            let normalizedID = ingredient.id.replacingOccurrences(of: "_", with: " ").lowercased()
            normalizedNameIndex[normalizedID] = ingredient
            for localizedName in ingredient.localizedNames.values {
                normalizedNameIndex[localizedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = ingredient
            }
            for alias in Self.ingredientAliasesSeed[ingredient.id] ?? [] {
                normalizedNameIndex[alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = ingredient
            }
        }
        self.basicByNormalizedName = normalizedNameIndex
        self.recipes = []
        self.userProfiles = []
        let rawNutritionGoals = UserDefaults.standard.string(forKey: nutritionGoalsStorageKey) ?? ""
        self.nutritionPriorities = NutritionService.parseNutritionPriorities(from: rawNutritionGoals)
        self.nutritionGoals = NutritionService.legacyGoals(from: self.nutritionPriorities)
        self.savedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: savedRecipeIDsStorageKey) ?? "")
        self.crispiedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: crispiedRecipeIDsStorageKey) ?? "")
        self.archivedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: archivedRecipeIDsStorageKey) ?? "")
        self.deletedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: deletedRecipeIDsStorageKey) ?? "")
        self.recipeViewCounts = Self.parseViewCounts(from: UserDefaults.standard.data(forKey: recipeViewCountsStorageKey))
        loadBootstrapContent()
    }

    @discardableResult
    func setLanguage(_ newCode: String) -> String {
        let resolved = AppLanguage(rawValue: newCode)?.rawValue ?? AppLanguage.english.rawValue
        if languageCode != resolved {
            languageCode = resolved
            ingredientDisplayResolutionCache.removeAll(keepingCapacity: true)
        }
        return resolved
    }

    func resetForLogout() {
        RecipeStore.clearUserSessionData()

        savedRecipeIDs = []
        crispiedRecipeIDs = []
        archivedRecipeIDs = []
        deletedRecipeIDs = []
        recipeViewCounts = [:]
        recipes = []
        userProfiles = []

        UserDefaults.standard.removeObject(forKey: savedRecipeIDsStorageKey)
        UserDefaults.standard.removeObject(forKey: crispiedRecipeIDsStorageKey)
        UserDefaults.standard.removeObject(forKey: archivedRecipeIDsStorageKey)
        UserDefaults.standard.removeObject(forKey: deletedRecipeIDsStorageKey)
        UserDefaults.standard.removeObject(forKey: recipeViewCountsStorageKey)

        remoteIngredientAliasLookup = [:]
        unifiedIngredientByID = [:]
        unifiedAliasLookup = [:]
        unifiedNameLookup = [:]
        unifiedEntryAliasLookup = [:]
        unifiedEntryNameLookup = [:]
        markReconciliationInputsChanged()
        nextRemoteRecipeOffset = 0
        hasMoreRemoteRecipePages = true
        isFetchingRemoteRecipePage = false
        didCompleteInitialRemoteRecipeHydration = false
        invalidateRecipeCaches()
        loadBootstrapContent()
    }

    private func loadBootstrapContent() {
        let generation = beginBootstrap()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startedAt = CFAbsoluteTimeGetCurrent()
            let loadedRecipes = RecipeStore.loadRecipes()
            let loadedProfiles = RecipeStore.loadProfiles()
            DispatchQueue.main.async {
                guard let self else { return }
                self.recipes = self.reconciledRecipesOnRead(loadedRecipes)
                self.userProfiles = loadedProfiles
                self.didCompleteInitialRemoteRecipeHydration = false
                self.invalidateRecipeCaches()
                let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0).rounded())
                self.debugLoadTimingIfNeeded(label: "bootstrap recipes", count: loadedRecipes.count, elapsedMs: elapsedMs)
                self.fetchRemoteRecipesAndMerge(resetPagination: true, bootstrapGeneration: generation)
                self.fetchRemoteIngredientAliases(bootstrapGeneration: generation)
                self.fetchUnifiedIngredientParityData()
            }
        }
    }

    private func fetchRemoteIngredientAliases(bootstrapGeneration: Int? = nil) {
        Task { [weak self] in
            guard let self else { return }
            let aliases = await supabaseService.fetchActiveIngredientAliases()
            let lookup = self.aliasLookupMap(from: aliases)
            await MainActor.run {
                self.remoteIngredientAliasLookup = lookup
                self.markReconciliationInputsChanged()
                let reconciliation = self.reconciledRecipesOnReadResult(self.recipes)
                if reconciliation.didChange {
                    self.recipes = reconciliation.recipes
                    self.invalidateRecipeCaches()
                }
                if let bootstrapGeneration {
                    self.markBootstrapIngredientAliasesCompleted(generation: bootstrapGeneration)
                }
            }
        }
    }

    private func fetchUnifiedIngredientParityData() {
        Task { [weak self] in
            guard let self else { return }
            let catalog = await supabaseService.fetchUnifiedIngredientCatalogSummary()
            let aliases = await supabaseService.fetchUnifiedIngredientAliases()
            await MainActor.run {
                self.applyUnifiedIngredientParityData(catalog: catalog, aliases: aliases)
            }
        }
    }

    private func aliasLookupMap(from aliases: [IngredientAliasRecord]) -> [String: IngredientAliasRecord] {
        var lookup: [String: IngredientAliasRecord] = [:]
        for alias in aliases where alias.isActive {
            let normalized = normalizedSearchText(alias.normalizedAliasText)
            guard !normalized.isEmpty else { continue }
            if let current = lookup[normalized] {
                let currentConfidence = current.confidence ?? -1
                let candidateConfidence = alias.confidence ?? -1
                if candidateConfidence > currentConfidence {
                    lookup[normalized] = alias
                }
            } else {
                lookup[normalized] = alias
            }
        }
        return lookup
    }

    private func applyUnifiedIngredientParityData(
        catalog: [UnifiedIngredientCatalogSummaryRecord],
        aliases: [UnifiedIngredientAliasRecord]
    ) {
        var entriesByID: [String: UnifiedIngredientParityEntry] = [:]
        var nameLookup: [String: IngredientAliasMatch] = [:]
        var entryNameLookup: [String: UnifiedIngredientParityEntry] = [:]

        for record in catalog {
            let ingredientID = record.ingredientID.trimmingCharacters(in: .whitespacesAndNewlines)
            let slug = record.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            let ingredientType = record.ingredientType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ingredientID.isEmpty, !slug.isEmpty, !ingredientType.isEmpty else { continue }

            let entry = UnifiedIngredientParityEntry(
                ingredientID: ingredientID,
                slug: slug,
                ingredientType: ingredientType,
                enName: record.enName,
                itName: record.itName,
                legacyProduceID: record.legacyProduceID,
                legacyBasicID: record.legacyBasicID,
                isSeasonal: record.isSeasonal,
                seasonMonths: record.seasonMonths,
                nutrition: Self.catalogNutrition(from: record),
                unitProfile: Self.catalogUnitProfile(from: record) ?? fallbackUnitProfile
            )
            entriesByID[ingredientID] = entry

            let match = ingredientAliasMatch(from: entry)
            appendUnifiedLookup(slug, match: match, entry: entry, into: &nameLookup, entryLookup: &entryNameLookup)
            appendUnifiedLookup(record.enName, match: match, entry: entry, into: &nameLookup, entryLookup: &entryNameLookup)
            appendUnifiedLookup(record.itName, match: match, entry: entry, into: &nameLookup, entryLookup: &entryNameLookup)
        }

        var aliasLookup: [String: IngredientAliasMatch] = [:]
        var entryAliasLookup: [String: UnifiedIngredientParityEntry] = [:]
        var aliasConfidenceLookup: [String: Double] = [:]
        for alias in aliases where alias.isActive {
            let normalized = normalizedSearchText(alias.normalizedAliasText)
            guard !normalized.isEmpty else { continue }
            guard let entry = entriesByID[alias.ingredientID] else { continue }
            let candidateConfidence = alias.confidence ?? -1
            let currentConfidence = aliasConfidenceLookup[normalized] ?? -1
            if let match = ingredientAliasMatch(from: entry),
               aliasLookup[normalized] == nil || candidateConfidence >= currentConfidence {
                aliasLookup[normalized] = match
            }
            if entryAliasLookup[normalized] == nil || candidateConfidence >= currentConfidence {
                entryAliasLookup[normalized] = entry
                aliasConfidenceLookup[normalized] = candidateConfidence
            }
        }

        unifiedIngredientByID = entriesByID
        unifiedAliasLookup = aliasLookup
        unifiedNameLookup = nameLookup
        unifiedEntryAliasLookup = entryAliasLookup
        unifiedEntryNameLookup = entryNameLookup
        markReconciliationInputsChanged()

        SeasonLog.debug(
            "[SEASON_UNIFIED_PARITY] phase=parity_cache_ready catalog_count=\(entriesByID.count) alias_count=\(aliasLookup.count) name_lookup_count=\(nameLookup.count)"
        )
    }

    private static func catalogNutrition(from record: UnifiedIngredientCatalogSummaryRecord) -> ProduceNutrition? {
        guard let calories = record.caloriesPer100g,
              let protein = record.proteinPer100g,
              let carbs = record.carbsPer100g,
              let fat = record.fatPer100g else {
            return nil
        }

        return ProduceNutrition(
            calories: Int(calories.rounded()),
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: record.fiberPer100g ?? 0,
            vitaminC: record.vitaminCPer100g ?? 0,
            potassium: record.potassiumPer100g ?? 0
        )
    }

    private static func catalogUnitProfile(from record: UnifiedIngredientCatalogSummaryRecord) -> IngredientUnitProfile? {
        let defaultUnit = RecipeQuantityUnit(rawValue: record.defaultUnit ?? "") ?? .g
        let supportedUnits = record.supportedUnits.compactMap(RecipeQuantityUnit.init(rawValue:))
        let supported = supportedUnits.isEmpty ? [defaultUnit] : supportedUnits
        return IngredientUnitProfile(
            defaultUnit: defaultUnit,
            supportedUnits: supported,
            gramsPerUnit: unitMap(from: record.gramsPerUnit),
            mlPerUnit: unitMap(from: record.mlPerUnit),
            gramsPerMl: record.gramsPerMl
        )
    }

    private static func unitMap(from raw: [String: Double]) -> [RecipeQuantityUnit: Double] {
        Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            guard let unit = RecipeQuantityUnit(rawValue: key) else { return nil }
            return (unit, value)
        })
    }

    private func appendUnifiedLookup(
        _ raw: String?,
        match: IngredientAliasMatch?,
        entry: UnifiedIngredientParityEntry,
        into lookup: inout [String: IngredientAliasMatch],
        entryLookup: inout [String: UnifiedIngredientParityEntry]
    ) {
        guard let raw else { return }
        let normalized = normalizedSearchText(raw)
        guard !normalized.isEmpty else { return }
        if let match {
            lookup[normalized] = match
        }
        entryLookup[normalized] = entry
    }

    private func ingredientAliasMatch(from entry: UnifiedIngredientParityEntry) -> IngredientAliasMatch? {
        if entry.ingredientType == "produce",
           let legacyProduceID = entry.legacyProduceID,
           let produce = produceByID[legacyProduceID] {
            return .produce(produce)
        }

        if entry.ingredientType == "basic",
           let legacyBasicID = entry.legacyBasicID,
           let basic = basicByID[legacyBasicID] {
            return .basic(basic)
        }

        // Bridge case: prefer whichever legacy mapping exists.
        if let legacyProduceID = entry.legacyProduceID,
           let produce = produceByID[legacyProduceID] {
            return .produce(produce)
        }

        if let legacyBasicID = entry.legacyBasicID,
           let basic = basicByID[legacyBasicID] {
            return .basic(basic)
        }

        return nil
    }

    private func reconciledRecipesOnRead(_ recipes: [Recipe]) -> [Recipe] {
        reconciledRecipesOnReadResult(recipes).recipes
    }

    private func reconciledRecipesOnReadResult(_ recipes: [Recipe]) -> (recipes: [Recipe], didChange: Bool) {
        var didChange = false
        let reconciled = recipes.map { recipe in
            let updated = reconcileRecipeOnRead(recipe)
            if updated != recipe {
                didChange = true
            }
            return updated
        }
        return (reconciled, didChange)
    }

    private func reconcileRecipeOnRead(_ recipe: Recipe) -> Recipe {
        guard recipeHasPotentialReconciliationWork(recipe) else {
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_skipped recipe_id=\(recipe.id) reason=no_unresolved_custom")
            }
            return recipe
        }

        let cacheKey = reconciliationNoMatchCacheKey(for: recipe)
        if reconciliationNoMatchCache.contains(cacheKey) {
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_skipped recipe_id=\(recipe.id) reason=cached_no_match")
            }
            return recipe
        }

        let unresolvedCount = recipe.ingredients.reduce(into: 0) { count, ingredient in
            if !ingredient.hasCatalogIdentity {
                count += 1
            }
        }

        if SeasonLog.verbose {
            SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_attempt recipe_id=\(recipe.id) unresolved_count=\(unresolvedCount)")
        }

        var successCount = 0
        let reconciledIngredients = recipe.ingredients.map { ingredient -> RecipeIngredient in
            guard !ingredient.hasCatalogIdentity else { return ingredient }

            let sourceText = ingredient.rawIngredientLine?
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
                : ingredient.name
            let normalizedQuery = normalizedSearchText(sourceText)
            guard !normalizedQuery.isEmpty else { return ingredient }

            if let entry = resolveUnifiedCatalogEntry(query: normalizedQuery) {
                successCount += 1
                return recipeIngredient(from: entry, fallback: ingredient, confidence: .medium)
            }

            let matched = resolveIngredientAlias(query: normalizedQuery)
                ?? resolveCatalogMatchForCustomIngredient(query: normalizedQuery)
                ?? resolveCatalogMatchInIngredientText(query: normalizedQuery)
            guard let matched else { return ingredient }

            successCount += 1
            switch matched {
            case .produce(let item):
                return RecipeIngredient(
                    produceID: item.id,
                    basicIngredientID: nil,
                    quality: .coreSeasonal,
                    name: item.displayName(languageCode: localizer.languageCode),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    rawIngredientLine: ingredient.rawIngredientLine ?? ingredient.name,
                    mappingConfidence: .medium
                )
            case .basic(let item):
                return RecipeIngredient(
                    produceID: nil,
                    basicIngredientID: item.id,
                    quality: .basic,
                    name: item.displayName(languageCode: localizer.languageCode),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    rawIngredientLine: ingredient.rawIngredientLine ?? ingredient.name,
                    mappingConfidence: .medium
                )
            }
        }

        guard successCount > 0 else {
            reconciliationNoMatchCache.insert(cacheKey)
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_skipped recipe_id=\(recipe.id) reason=no_match_found")
            }
            return recipe
        }

        if SeasonLog.verbose {
            SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_succeeded recipe_id=\(recipe.id) reconciled_count=\(successCount)")
        }
        var updated = recipe
        updated = Recipe(
            id: recipe.id,
            title: recipe.title,
            author: recipe.author,
            creatorId: recipe.creatorId,
            creatorDisplayName: recipe.creatorDisplayName,
            creatorAvatarURL: recipe.creatorAvatarURL,
            ingredients: reconciledIngredients,
            preparationSteps: recipe.preparationSteps,
            prepTimeMinutes: recipe.prepTimeMinutes,
            cookTimeMinutes: recipe.cookTimeMinutes,
            difficulty: recipe.difficulty,
            servings: recipe.servings,
            crispy: recipe.crispy,
            viewCount: recipe.viewCount,
            dietaryTags: recipe.dietaryTags,
            seasonalMatchPercent: recipe.seasonalMatchPercent,
            createdAt: recipe.createdAt,
            externalMedia: recipe.externalMedia,
            images: recipe.images,
            coverImageID: recipe.coverImageID,
            coverImageName: recipe.coverImageName,
            mediaLinkURL: recipe.mediaLinkURL,
            instagramURL: recipe.instagramURL,
            tiktokURL: recipe.tiktokURL,
            sourceURL: recipe.sourceURL,
            sourceName: recipe.sourceName,
            sourcePlatform: recipe.sourcePlatform,
            sourceCaptionRaw: recipe.sourceCaptionRaw,
            importedFromSocial: recipe.importedFromSocial,
            sourceType: recipe.sourceType,
            isUserGenerated: recipe.isUserGenerated,
            imageURL: recipe.imageURL,
            imageSource: recipe.imageSource,
            attributionText: recipe.attributionText,
            publicationStatus: recipe.publicationStatus,
            isRemix: recipe.isRemix,
            originalRecipeID: recipe.originalRecipeID,
            originalRecipeTitle: recipe.originalRecipeTitle,
            originalAuthorName: recipe.originalAuthorName
        )
        return updated
    }

    private func recipeHasPotentialReconciliationWork(_ recipe: Recipe) -> Bool {
        recipe.ingredients.contains { ingredient in
            guard !ingredient.hasCatalogIdentity else { return false }
            return !reconciliationSourceText(for: ingredient).isEmpty
        }
    }

    private func reconciliationNoMatchCacheKey(for recipe: Recipe) -> String {
        [
            recipe.id,
            String(reconciliationInputVersion),
            unresolvedIngredientFingerprint(for: recipe)
        ].joined(separator: "||")
    }

    private func unresolvedIngredientFingerprint(for recipe: Recipe) -> String {
        recipe.ingredients.compactMap { ingredient -> String? in
            guard !ingredient.hasCatalogIdentity else { return nil }
            let source = reconciliationSourceText(for: ingredient)
            guard !source.isEmpty else { return nil }
            return [
                source.lowercased(),
                String(ingredient.quantityValue),
                ingredient.quantityUnit.rawValue
            ].joined(separator: "#")
        }
        .joined(separator: "|")
    }

    private func reconciliationSourceText(for ingredient: RecipeIngredient) -> String {
        let rawLine = ingredient.rawIngredientLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawLine.isEmpty {
            return rawLine
        }
        return ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveCatalogMatchForCustomIngredient(query: String) -> IngredientAliasMatch? {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return nil }

        let legacyMatch = resolveLegacyCatalogMatch(query: normalized)
        let unifiedMatch = resolveUnifiedCatalogMatch(query: normalized)
        logUnifiedParity(path: "catalog_match", query: normalized, legacy: legacyMatch, unified: unifiedMatch)
        return legacyMatch
    }

    private func resolveLegacyCatalogMatch(query: String) -> IngredientAliasMatch? {
        if let produce = produceByNormalizedName[query] {
            return .produce(produce)
        }
        if let basic = basicByNormalizedName[query] {
            return .basic(basic)
        }

        let normalizedAsID = query.replacingOccurrences(of: " ", with: "_")
        if let produce = produceByID[normalizedAsID] {
            return .produce(produce)
        }
        if let basic = basicByID[normalizedAsID] {
            return .basic(basic)
        }

        return nil
    }

    private func resolveCatalogMatchInIngredientText(query: String) -> IngredientAliasMatch? {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return nil }

        var candidates: [(term: String, match: IngredientAliasMatch)] = []
        candidates.reserveCapacity(produceByNormalizedName.count + basicByNormalizedName.count)
        candidates.append(contentsOf: produceByNormalizedName.map { ($0.key, .produce($0.value)) })
        candidates.append(contentsOf: basicByNormalizedName.map { ($0.key, .basic($0.value)) })

        return candidates
            .filter { $0.term.count >= 3 && normalizedContainsTerm($0.term, in: normalized) }
            .sorted { lhs, rhs in
                if lhs.term.count != rhs.term.count {
                    return lhs.term.count > rhs.term.count
                }
                return lhs.term < rhs.term
            }
            .first?
            .match
    }

    func loadNextRecipePageIfNeeded(isNearEnd: Bool) {
        guard isNearEnd else { return }
        fetchRemoteRecipesAndMerge()
    }

    private func fetchRemoteRecipesAndMerge(resetPagination: Bool = false, bootstrapGeneration: Int? = nil) {
        if resetPagination {
            nextRemoteRecipeOffset = 0
            hasMoreRemoteRecipePages = true
        }

        guard hasMoreRemoteRecipePages else { return }
        guard !isFetchingRemoteRecipePage else { return }

        let limit = remoteRecipePageSize
        let offset = nextRemoteRecipeOffset
        isFetchingRemoteRecipePage = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let remoteRecipes = try await supabaseService.fetchRecipes(limit: limit, offset: offset)
                await MainActor.run {
                    let previousRecipeCount = self.recipes.count
                    let wasInitialHydrationComplete = self.didCompleteInitialRemoteRecipeHydration

                    self.isFetchingRemoteRecipePage = false
                    self.nextRemoteRecipeOffset += remoteRecipes.count
                    if remoteRecipes.count < limit {
                        self.hasMoreRemoteRecipePages = false
                    }

                    let mergedRecipes = self.mergedRecipes(local: self.recipes, remote: remoteRecipes)
                    self.recipes = self.reconciledRecipesOnRead(mergedRecipes)
                    self.invalidateRecipeCaches()

                    if resetPagination && !wasInitialHydrationComplete {
                        self.didCompleteInitialRemoteRecipeHydration = true
                        self.bumpHomeFeedDataVersion(reason: "initial_remote_hydration")
                    } else if self.recipes.count != previousRecipeCount {
                        self.bumpHomeFeedDataVersion(reason: "remote_recipe_page_merge")
                    }

                    if let bootstrapGeneration {
                        self.markBootstrapRemoteRecipesCompleted(generation: bootstrapGeneration)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isFetchingRemoteRecipePage = false
                    if let bootstrapGeneration {
                        self.markBootstrapRemoteRecipesCompleted(generation: bootstrapGeneration)
                    }
                }
                SeasonLog.debug("[SEASON_SUPABASE] request=fetchRecipes phase=request_failed local_fallback=true error=\(error)")
            }
        }
    }

    private func bumpHomeFeedDataVersion(reason: String) {
        homeFeedDataVersion &+= 1
        if SeasonLog.lifecycleEnabled {
            SeasonLog.debug("[SEASON_HOME_FEED] phase=data_version_bumped reason=\(reason) value=\(homeFeedDataVersion)")
        }
    }

    private func bumpRankingDataVersion(reason: String) {
        rankingDataVersion &+= 1
        if SeasonLog.lifecycleEnabled {
            SeasonLog.debug("[SEASON_HOME_FEED] phase=ranking_version_bumped reason=\(reason) value=\(rankingDataVersion)")
        }
    }

    private func mergedRecipes(local: [Recipe], remote: [Recipe]) -> [Recipe] {
        var seen = Set<String>()
        return (remote + local).filter { recipe in
            seen.insert(recipe.id).inserted
        }
    }

    private func debugLoadTimingIfNeeded(label: String, count: Int, elapsedMs: Int) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SEASON_LOAD_DEBUG"] == "1" {
            SeasonLog.debug("LOAD DEBUG [\(label)] count=\(count) time_ms=\(elapsedMs)")
        }
        #endif
    }

    private func invalidateRecipeCaches(reason: String = "recipe_data_changed") {
        if isBootstrapping {
            pendingInvalidation = true
            return
        }

        performCacheInvalidation(reason: reason)
    }

    private func performCacheInvalidation(reason: String) {
        cachedDiscoverableRankedRecipes = []
        cachedDiscoverableRankedByID = [:]
        cachedDiscoverableRankedMonth = nil
        nutritionService.invalidateCaches()
        cachedMaxCrispy = nil
        cachedMaxViews = nil
        bumpRankingDataVersion(reason: reason)
    }

    private func beginBootstrap() -> Int {
        bootstrapGeneration &+= 1
        isBootstrapping = true
        pendingInvalidation = false
        bootstrapRemoteRecipesCompleted = false
        bootstrapIngredientAliasesCompleted = false
        return bootstrapGeneration
    }

    private func markBootstrapRemoteRecipesCompleted(generation: Int) {
        guard bootstrapGeneration == generation else { return }
        bootstrapRemoteRecipesCompleted = true
        completeBootstrapIfNeeded()
    }

    private func markBootstrapIngredientAliasesCompleted(generation: Int) {
        guard bootstrapGeneration == generation else { return }
        bootstrapIngredientAliasesCompleted = true
        completeBootstrapIfNeeded()
    }

    private func completeBootstrapIfNeeded() {
        guard isBootstrapping,
              bootstrapRemoteRecipesCompleted,
              bootstrapIngredientAliasesCompleted else { return }

        isBootstrapping = false
        if pendingInvalidation {
            pendingInvalidation = false
            performCacheInvalidation(reason: "bootstrap_coalesced")
        }
    }

    private func markReconciliationInputsChanged() {
        reconciliationInputVersion &+= 1
        reconciliationNoMatchCache.removeAll(keepingCapacity: true)
        ingredientDisplayResolutionCache.removeAll(keepingCapacity: true)
    }

    private func invalidateRankingCaches(reason: String = "ranking_inputs_changed") {
        cachedDiscoverableRankedRecipes = []
        cachedDiscoverableRankedByID = [:]
        cachedDiscoverableRankedMonth = nil
        nutritionService.invalidateCaches()
        cachedMaxCrispy = nil
        cachedMaxViews = nil
        bumpRankingDataVersion(reason: reason)
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        return formatter.monthSymbols[currentMonth - 1]
    }

    func items(in category: ProduceCategoryKey, inSeason: Bool? = nil) -> [ProduceItem] {
        let filtered = produceItems.filter { item in
            guard item.category == category else { return false }
            guard let inSeason else { return true }
            return item.isInSeason(month: currentMonth) == inSeason
        }

        return filtered.sorted(by: compareItems)
    }

    func searchResults(query: String) -> [ProduceItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [ProduceItem]
        if trimmedQuery.isEmpty {
            filtered = produceItems
        } else {
            filtered = produceItems.filter { item in
                item.displayName(languageCode: localizer.languageCode)
                    .localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        return filtered.sorted(by: compareItems)
    }

    func searchIngredientResults(query: String) -> [IngredientSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedLanguage = localizer.languageCode
        let normalizedQuery = normalizedSearchText(trimmedQuery)
        let queryTokens = normalizedQuery
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        let produceMatches = produceItems.filter { item in
            guard !trimmedQuery.isEmpty else { return true }
            let terms = searchableTerms(for: item)
            return matches(query: normalizedQuery, tokens: queryTokens, in: terms)
        }
        .map { item in
            let terms = searchableTerms(for: item)
            return IngredientSearchResult(
                source: .produce(item),
                title: item.displayName(languageCode: localizedLanguage),
                subtitle: localizer.categoryTitle(for: item.category),
                relevance: relevanceScore(query: normalizedQuery, tokens: queryTokens, terms: terms)
            )
        }

        let basicMatches = basicIngredients.filter { item in
            guard !trimmedQuery.isEmpty else { return true }
            let terms = searchableTerms(for: item)
            return matches(query: normalizedQuery, tokens: queryTokens, in: terms)
        }
        .map { item in
            let terms = searchableTerms(for: item)
            return IngredientSearchResult(
                source: .basic(item),
                title: item.displayName(languageCode: localizedLanguage),
                subtitle: localizer.text(.basicIngredient),
                relevance: relevanceScore(query: normalizedQuery, tokens: queryTokens, terms: terms)
            )
        }

        return (produceMatches + basicMatches).sorted { lhs, rhs in
            if lhs.relevance != rhs.relevance {
                return lhs.relevance > rhs.relevance
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func searchRecipeResults(query: String) -> [RankedRecipe] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = normalizedSearchText(trimmedQuery)
        let queryTokens = normalizedQuery
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        let ranked = rankedFeedEligibleDiscoverableRecipes()
        guard !trimmedQuery.isEmpty else { return ranked }

        let scoredResults: [(recipe: RankedRecipe, relevance: Int)] = ranked.compactMap { rankedRecipe -> (recipe: RankedRecipe, relevance: Int)? in
                let terms = searchableTerms(for: rankedRecipe.recipe)
                let score = relevanceScore(query: normalizedQuery, tokens: queryTokens, terms: terms)
                guard score > 0 else { return nil }
                return (recipe: rankedRecipe, relevance: score)
            }

        return scoredResults
            .sorted { lhs, rhs in
                if lhs.relevance != rhs.relevance {
                    return lhs.relevance > rhs.relevance
                }
                if lhs.recipe.score != rhs.recipe.score {
                    return lhs.recipe.score > rhs.recipe.score
                }
                return lhs.recipe.recipe.title.localizedCaseInsensitiveCompare(rhs.recipe.recipe.title) == .orderedAscending
            }
            .map(\.recipe)
    }

    func searchPrimaryType(for query: String) -> SearchPrimaryType {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return .ingredients }

        let recipeKeywords: Set<String> = [
            "recipe", "recipes", "cook", "cooking", "meal", "dinner", "lunch", "breakfast",
            "ricetta", "ricette", "cucina", "cucinare", "pranzo", "cena"
        ]

        let tokens = Set(normalized.split(separator: " ").map(String.init))
        if !tokens.isDisjoint(with: recipeKeywords) {
            return .recipes
        }

        return .ingredients
    }

    func monthNames(for months: [Int]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        return months
            .sorted()
            .compactMap { month in
                guard month >= 1, month <= 12 else { return nil }
                return formatter.shortMonthSymbols[month - 1]
            }
            .joined(separator: ", ")
    }

    func rankedInSeasonTodayItems() -> [RankedInSeasonItem] {
        let inSeasonItems = produceItems.filter { $0.seasonalityScore(month: currentMonth) >= 0.22 }

        return inSeasonItems
            .map { item in
                let score = todayPickScore(for: item) * 100.0
                let reasons = rankingReasons(for: item)
                return RankedInSeasonItem(item: item, score: score, reasons: reasons)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.item.displayName(languageCode: localizer.languageCode)
                    < rhs.item.displayName(languageCode: localizer.languageCode)
            }
    }

    func bestPicksToday(limit: Int = 6) -> [RankedInSeasonItem] {
        Array(rankedInSeasonTodayItems().prefix(max(1, limit)))
    }

    func bestPicksCount(maxCount: Int = 6) -> Int {
        let ranked = rankedInSeasonTodayItems()
        guard let topScore = ranked.first?.score else { return 0 }
        let threshold = topScore * 0.78
        let count = ranked
            .filter { $0.score >= threshold }
            .prefix(maxCount)
            .count
        return count
    }

    func shortBenefitText(for ranked: RankedInSeasonItem) -> String {
        if let firstReason = ranked.reasons.first {
            return firstReason
        }
        return localizer.text(.reasonInSeasonNow)
    }

    func rankedTrendingRecipes(limit: Int = 6) -> [RankedRecipe] {
        Array(rankedFeedEligibleDiscoverableRecipes().prefix(max(1, limit)))
    }

    func homeRankedRecipes(limit: Int = 12) -> [RankedRecipe] {
        Array(rankedFeedEligibleDiscoverableRecipes().prefix(max(1, limit)))
    }

    func rankedTrendingNowRecipes(limit: Int = 6) -> [RankedRecipe] {
        let homeResolved = rankedFeedEligibleDiscoverableByID()

        return feedEligibleDiscoverableRecipes
            .sorted { lhs, rhs in
                let leftScore = (0.6 * crispyScore(for: lhs)) + (0.4 * viewsScore(for: lhs))
                let rightScore = (0.6 * crispyScore(for: rhs)) + (0.4 * viewsScore(for: rhs))
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .compactMap { homeResolved[$0.id] }
            .prefix(max(1, limit))
            .map { $0 }
    }

    func rankedSmartSuggestionRecipes(limit: Int = 6) -> [RankedRecipe] {
        rankedFeedEligibleDiscoverableRecipes()
            .map { ranked in
                let homeScore = min(1.0, max(0.0, ranked.score / 100.0))
                let nutrition = nutritionPreferenceScore(for: ranked.recipe)
                let score = (0.75 * homeScore) + (0.25 * nutrition)
                return (ranked: ranked, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }
            .prefix(max(1, limit))
            .map(\.ranked)
    }

    func rankedFollowedRecipes(followedAuthors: Set<String>, limit: Int = 6) -> [RankedRecipe] {
        let followed = rankedFeedEligibleDiscoverableRecipes().filter { followedAuthors.contains($0.recipe.author) }
        return Array(followed.prefix(max(1, limit)))
    }

    func rankedFollowingRecipes(followedCreatorIDs: [String], limit: Int = 6) -> [RankedRecipe] {
        guard !followedCreatorIDs.isEmpty else { return [] }

        let normalizedFollowedIDs = Set(
            followedCreatorIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0 != "unknown" }
        )
        guard !normalizedFollowedIDs.isEmpty else { return [] }

        let followed = rankedFeedEligibleDiscoverableRecipes().filter { ranked in
            guard let creatorID = ranked.recipe.canonicalCreatorID else { return false }
            return normalizedFollowedIDs.contains(creatorID)
        }
        return Array(followed.prefix(max(1, limit)))
    }

    func rankedRecipesByAuthor(_ author: String) -> [RankedRecipe] {
        rankedDiscoverableRecipes().filter { $0.recipe.author == author }
    }

    func rankedRecipe(forID id: String) -> RankedRecipe? {
        if let discoverable = rankedDiscoverableByID()[id] {
            return discoverable
        }
        return rankedHomeRecipes(from: nonDeletedRecipes).first { $0.recipe.id == id }
    }

    func remixCount(forOriginalRecipeID id: String) -> Int {
        nonDeletedRecipes.filter { $0.isRemix && $0.originalRecipeID == id }.count
    }

    func isRecipeSaved(_ recipe: Recipe) -> Bool {
        savedRecipeIDs.contains(recipe.id)
    }

    func isRecipeCrispied(_ recipe: Recipe) -> Bool {
        crispiedRecipeIDs.contains(recipe.id)
    }

    func crispyCount(for recipe: Recipe) -> Int {
        let delta = isRecipeCrispied(recipe) ? 1 : 0
        return max(0, recipe.crispy + delta)
    }

    func toggleRecipeCrispy(_ recipe: Recipe) {
        let traceID = String(UUID().uuidString.prefix(8))
        var updated = crispiedRecipeIDs
        if updated.contains(recipe.id) {
            updated.remove(recipe.id)
        } else {
            updated.insert(recipe.id)
        }
        let isCrispied = updated.contains(recipe.id)
        crispiedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: crispiedRecipeIDsStorageKey)
        invalidateRankingCaches(reason: "crispy_state_changed")
        UserInteractionTracker.shared.track(
            .recipeCrispied,
            recipeID: recipe.id,
            creatorID: recipe.canonicalCreatorID,
            metadata: ["isCrispied": isCrispied ? "true" : "false"]
        )
        SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=local_update_done")
        SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=task_started")
        Task { [supabaseService] in
            SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=service_call")
            do {
                try await supabaseService.setRecipeCrispiedState(recipeID: recipe.id, isCrispied: isCrispied, traceID: traceID)
            } catch {
                SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=write_failed error=\(error)")
            }
        }
    }

    func toggleSavedRecipe(_ recipe: Recipe) {
        let traceID = String(UUID().uuidString.prefix(8))
        var updated = savedRecipeIDs
        if updated.contains(recipe.id) {
            updated.remove(recipe.id)
        } else {
            updated.insert(recipe.id)
        }
        let isSaved = updated.contains(recipe.id)
        savedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: savedRecipeIDsStorageKey)
        invalidateRankingCaches(reason: "saved_state_changed")
        UserInteractionTracker.shared.track(
            .recipeSaved,
            recipeID: recipe.id,
            creatorID: recipe.canonicalCreatorID,
            metadata: ["isSaved": isSaved ? "true" : "false"]
        )
        SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=local_update_done")
        SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=task_started")

        Task { [supabaseService] in
            SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=service_call")
            do {
                try await supabaseService.setRecipeSavedState(recipeID: recipe.id, isSaved: isSaved, traceID: traceID)
            } catch {
                SeasonLog.debug("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=write_failed error=\(error)")
            }
        }
    }

    func savedRecipesRanked() -> [RankedRecipe] {
        let saved = nonDeletedRecipes.filter { savedRecipeIDs.contains($0.id) }
        return rankedHomeRecipes(from: saved)
    }

    func isRecipeArchived(_ recipe: Recipe) -> Bool {
        archivedRecipeIDs.contains(recipe.id)
    }

    func archiveRecipe(_ recipe: Recipe) {
        var updated = archivedRecipeIDs
        updated.insert(recipe.id)
        archivedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: archivedRecipeIDsStorageKey)
        invalidateRecipeCaches(reason: "archive_state_changed")
    }

    func unarchiveRecipe(_ recipe: Recipe) {
        var updated = archivedRecipeIDs
        updated.remove(recipe.id)
        archivedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: archivedRecipeIDsStorageKey)
        invalidateRecipeCaches(reason: "archive_state_changed")
    }

    func deleteRecipe(_ recipe: Recipe) {
        var updated = deletedRecipeIDs
        updated.insert(recipe.id)
        deletedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: deletedRecipeIDsStorageKey)

        // Clean up related local state.
        var savedUpdated = savedRecipeIDs
        savedUpdated.remove(recipe.id)
        savedRecipeIDs = savedUpdated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: savedUpdated), forKey: savedRecipeIDsStorageKey)

        var crispyUpdated = crispiedRecipeIDs
        crispyUpdated.remove(recipe.id)
        crispiedRecipeIDs = crispyUpdated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: crispyUpdated), forKey: crispiedRecipeIDsStorageKey)

        var archivedUpdated = archivedRecipeIDs
        archivedUpdated.remove(recipe.id)
        archivedRecipeIDs = archivedUpdated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: archivedUpdated), forKey: archivedRecipeIDsStorageKey)
        RecipeStore.removeUserRecipe(id: recipe.id)
        invalidateRecipeCaches(reason: "delete_state_changed")
    }

    func activeRecipes(for author: String) -> [Recipe] {
        discoverableRecipes
            .filter { $0.author == author }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func relatedRecipes(
        matchingProduceID produceID: String?,
        basicIngredientID: String?,
        ingredientName: String? = nil,
        limit: Int = 4
    ) -> [Recipe] {
        guard limit > 0 else { return [] }

        let normalizedIngredientName = ingredientName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard produceID != nil || basicIngredientID != nil || normalizedIngredientName?.isEmpty == false else {
            return []
        }

        let matches = feedEligibleDiscoverableRecipes.filter { recipe in
            recipe.ingredients.contains { ingredient in
                if let produceID, ingredient.produceID == produceID { return true }
                if let basicIngredientID, ingredient.basicIngredientID == basicIngredientID { return true }
                if let normalizedIngredientName, !normalizedIngredientName.isEmpty {
                    return ingredient.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased() == normalizedIngredientName
                }
                return false
            }
        }

        return Array(matches.prefix(limit))
    }

    func archivedRecipes(for author: String) -> [Recipe] {
        nonDeletedRecipes
            .filter { $0.author == author && archivedRecipeIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func draftRecipes(for author: String) -> [Recipe] {
        nonDeletedRecipes
            .filter { $0.author == author && $0.publicationStatus == .draft }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func viewCount(for recipe: Recipe) -> Int {
        recipeViewCounts[recipe.id] ?? recipe.viewCount
    }

    func registerRecipeView(_ recipe: Recipe) {
        var updated = recipeViewCounts
        let current = updated[recipe.id] ?? recipe.viewCount
        updated[recipe.id] = current + 1
        recipeViewCounts = updated
        if let encoded = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(encoded, forKey: recipeViewCountsStorageKey)
        }
        UserInteractionTracker.shared.track(
            .recipeViewed,
            recipeID: recipe.id,
            creatorID: recipe.canonicalCreatorID
        )
        invalidateRankingCaches(reason: "recipe_view_count_changed")
    }

    func compactCountText(_ value: Int) -> String {
        value.compactFormatted()
    }

    // Canonical identity rule:
    // creatorDisplayName is primary; author is kept as legacy compatibility.
    private func resolvedCreatorDisplayName(from legacyAuthor: String, creator: Creator) -> String {
        let trimmedAuthor = legacyAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAuthor.isEmpty {
            return trimmedAuthor
        }
        return creator.displayName
    }

    func confirmedDietaryTags(for recipe: Recipe) -> [RecipeDietaryTag] {
        confirmedDietaryTags(forIngredients: recipe.ingredients)
    }

    func rankedRecipesForFridge(fridgeItemIDs: Set<String>, limit: Int = 6) -> [FridgeMatchedRecipe] {
        let ranked = matchedRecipesForFridge(fridgeItemIDs: fridgeItemIDs)

        return Array(ranked.prefix(max(1, limit)))
    }

    func matchedRecipesForFridge(fridgeItemIDs: Set<String>) -> [FridgeMatchedRecipe] {
        rankedFeedEligibleDiscoverableRecipes()
            .map { rankedRecipe in
                let weighted = weightedFridgeMatch(for: rankedRecipe.recipe, fridgeItemIDs: fridgeItemIDs)
                return FridgeMatchedRecipe(
                    rankedRecipe: rankedRecipe,
                    matchingCount: weighted.matchingCount,
                    totalCount: weighted.totalCount,
                    availableIngredientWeight: weighted.availableWeight,
                    totalIngredientWeight: weighted.totalWeight
                )
            }
            .sorted { lhs, rhs in
                let leftScore = fridgeRankingScore(for: lhs.rankedRecipe.recipe, fridgeItemIDs: fridgeItemIDs)
                let rightScore = fridgeRankingScore(for: rhs.rankedRecipe.recipe, fridgeItemIDs: fridgeItemIDs)
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return lhs.rankedRecipe.recipe.title < rhs.rankedRecipe.recipe.title
            }
    }

    func fridgeRecipeMatchCount(fridgeItemIDs: Set<String>) -> Int {
        guard !fridgeItemIDs.isEmpty else { return 0 }
        return matchedRecipesForFridge(fridgeItemIDs: fridgeItemIDs)
            .filter { $0.totalCount > 0 && $0.matchingCount > 0 }
            .count
    }

    func produceItem(forID id: String) -> ProduceItem? {
        produceByID[id]
    }

    func basicIngredient(forID id: String) -> BasicIngredient? {
        basicByID[id]
    }

    func resolveIngredientAlias(query: String) -> IngredientAliasMatch? {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return nil }
        let legacy = resolveLegacyAliasMatch(query: normalized)
        let unified = resolveUnifiedAliasMatch(query: normalized)
        logUnifiedParity(path: "alias_lookup", query: normalized, legacy: legacy, unified: unified)
        return legacy
    }

    // Import-only resolution path: unified catalog first, legacy fallback.
    // Returned type remains legacy-compatible (.produce/.basic) so write paths stay unchanged.
    func resolveIngredientForImport(query: String) -> IngredientAliasMatch? {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return nil }

        let unified = resolveUnifiedAliasMatch(query: normalized)
            ?? resolveUnifiedCatalogMatch(query: normalized)
        if let unified {
            let unifiedKey = parityMatchKey(unified)
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=unified_resolution_used path=import query=\(normalized) value=\(unifiedKey)")
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=unified_resolution_mapped_to_legacy path=import query=\(normalized) value=\(unifiedKey)")
            return unified
        }

        let legacy = resolveLegacyAliasMatch(query: normalized)
            ?? resolveLegacyCatalogMatch(query: normalized)
        if let legacy {
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=unified_resolution_failed_fallback_legacy path=import query=\(normalized) legacy=\(parityMatchKey(legacy))")
        }
        return legacy
    }

    private func resolveLegacyAliasMatch(query: String) -> IngredientAliasMatch? {
        guard let record = remoteIngredientAliasLookup[query] else { return nil }

        if let produceID = record.produceID,
           let produce = produceByID[produceID] {
            return .produce(produce)
        }

        if let basicID = record.basicIngredientID,
           let basic = basicByID[basicID] {
            return .basic(basic)
        }

        return nil
    }

    private func resolveUnifiedAliasMatch(query: String) -> IngredientAliasMatch? {
        unifiedAliasLookup[query]
    }

    private func resolveUnifiedCatalogMatch(query: String) -> IngredientAliasMatch? {
        if let alias = unifiedAliasLookup[query] {
            return alias
        }
        if let direct = unifiedNameLookup[query] {
            return direct
        }
        return nil
    }

    private func resolveUnifiedCatalogEntry(query: String) -> UnifiedIngredientParityEntry? {
        if let alias = unifiedEntryAliasLookup[query] {
            return alias
        }
        if let direct = unifiedEntryNameLookup[query] {
            return direct
        }
        return nil
    }

    private func parityMatchKey(_ match: IngredientAliasMatch?) -> String {
        guard let match else { return "none" }
        switch match {
        case .produce(let item):
            return "produce:\(item.id)"
        case .basic(let item):
            return "basic:\(item.id)"
        }
    }

    private func logUnifiedParity(
        path: String,
        query: String,
        legacy: IngredientAliasMatch?,
        unified: IngredientAliasMatch?
    ) {
        let legacyKey = parityMatchKey(legacy)
        let unifiedKey = parityMatchKey(unified)

        if legacyKey == "none", unifiedKey == "none" {
            return
        }

        if legacyKey == unifiedKey {
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=parity_match_same path=\(path) query=\(query) value=\(legacyKey)")
            return
        }

        if legacyKey == "none" {
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=parity_missing_legacy path=\(path) query=\(query) unified=\(unifiedKey)")
            return
        }

        if unifiedKey == "none" {
            SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=parity_missing_unified path=\(path) query=\(query) legacy=\(legacyKey)")
            return
        }

        SeasonLog.debug("[SEASON_UNIFIED_PARITY] phase=parity_match_diff path=\(path) query=\(query) legacy=\(legacyKey) unified=\(unifiedKey)")
    }

    func recipe(forID id: String) -> Recipe? {
        recipes.first(where: { $0.id == id })
    }

    @discardableResult
    func createEmptyDraftRecipe(author: String) -> Recipe {
        let creator = CurrentUser.shared.creator
        let resolvedCreatorName = resolvedCreatorDisplayName(from: author, creator: creator)
        let draft = Recipe(
            id: "recipe_\(UUID().uuidString.lowercased())",
            title: "",
            author: resolvedCreatorName,
            creatorId: creator.id,
            creatorDisplayName: resolvedCreatorName,
            creatorAvatarURL: creator.avatarURL,
            ingredients: [],
            preparationSteps: [],
            prepTimeMinutes: nil,
            cookTimeMinutes: nil,
            difficulty: nil,
            servings: 2,
            crispy: 0,
            dietaryTags: [],
            seasonalMatchPercent: 0,
            createdAt: Date(),
            externalMedia: [],
            images: [],
            coverImageID: nil,
            coverImageName: nil,
            mediaLinkURL: nil,
            sourceURL: nil,
            sourcePlatform: nil,
            sourceCaptionRaw: nil,
            importedFromSocial: false,
            publicationStatus: .draft,
            isRemix: false,
            originalRecipeID: nil,
            originalRecipeTitle: nil,
            originalAuthorName: nil
        )
        recipes.insert(draft, at: 0)
        invalidateRecipeCaches()
        RecipeStore.upsertUserRecipe(draft)
        SeasonLog.debug("[SEASON_RECIPE] phase=draft_created id=\(draft.id)")
        return draft
    }

    @discardableResult
    func saveRecipeDraft(
        recipeID: String,
        title: String,
        author: String,
        ingredients: [RecipeIngredient],
        steps: [String],
        externalMedia: [RecipeExternalMedia] = [],
        images: [RecipeImage],
        coverImageID: String?,
        coverImageName: String?,
        mediaLinkURL: String?,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        sourceURL: String?,
        sourcePlatform: SocialSourcePlatform?,
        sourceCaptionRaw: String?,
        importedFromSocial: Bool,
        servings: Int = 2,
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        difficulty: RecipeDifficulty? = nil,
        isRemix: Bool = false,
        originalRecipeID: String? = nil,
        originalRecipeTitle: String? = nil,
        originalAuthorName: String? = nil
    ) -> Recipe? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSteps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedIngredients = ingredients.filter { ingredient in
            !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ingredient.quantityValue > 0
        }

        let seasonalPercent = seasonalMatchPercent(for: trimmedIngredients.compactMap(\.produceID))
        let confirmedDietary = confirmedDietaryTags(forIngredients: trimmedIngredients)
        let validExternalMedia = externalMedia.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let validImages = images.filter {
            ($0.localPath?.isEmpty == false) || ($0.remoteURL?.isEmpty == false)
        }
        let normalizedServings = max(1, min(12, servings))
        let validCoverID = validImages.contains(where: { $0.id == coverImageID }) ? coverImageID : nil
        let trimmedImageName = coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMediaLink = mediaLinkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstagramURL = instagramURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTikTokURL = tiktokURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceCaption = sourceCaptionRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingCreatedAt = recipes.first(where: { $0.id == recipeID })?.createdAt ?? Date()
        let creator = CurrentUser.shared.creator
        let resolvedCreatorName = resolvedCreatorDisplayName(from: author, creator: creator)

        let recipe = Recipe(
            id: recipeID,
            title: trimmedTitle,
            author: resolvedCreatorName,
            creatorId: creator.id,
            creatorDisplayName: resolvedCreatorName,
            creatorAvatarURL: creator.avatarURL,
            ingredients: trimmedIngredients,
            preparationSteps: trimmedSteps,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            difficulty: difficulty,
            servings: normalizedServings,
            crispy: 0,
            dietaryTags: confirmedDietary,
            seasonalMatchPercent: seasonalPercent,
            createdAt: existingCreatedAt,
            externalMedia: validExternalMedia,
            images: validImages,
            coverImageID: validCoverID,
            coverImageName: (trimmedImageName?.isEmpty == false) ? trimmedImageName : nil,
            mediaLinkURL: (trimmedMediaLink?.isEmpty == false) ? trimmedMediaLink : nil,
            instagramURL: (trimmedInstagramURL?.isEmpty == false) ? trimmedInstagramURL : nil,
            tiktokURL: (trimmedTikTokURL?.isEmpty == false) ? trimmedTikTokURL : nil,
            sourceURL: (trimmedSourceURL?.isEmpty == false) ? trimmedSourceURL : nil,
            sourcePlatform: sourcePlatform,
            sourceCaptionRaw: (trimmedSourceCaption?.isEmpty == false) ? trimmedSourceCaption : nil,
            importedFromSocial: importedFromSocial,
            publicationStatus: .draft,
            isRemix: isRemix,
            originalRecipeID: originalRecipeID,
            originalRecipeTitle: originalRecipeTitle,
            originalAuthorName: originalAuthorName
        )

        if let existingIndex = recipes.firstIndex(where: { $0.id == recipeID }) {
            recipes[existingIndex] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
        invalidateRecipeCaches()
        RecipeStore.upsertUserRecipe(recipe)
        SeasonLog.debug("[SEASON_RECIPE] phase=draft_saved id=\(recipe.id)")
        return recipe
    }

    private func recipeIngredient(
        from entry: UnifiedIngredientParityEntry,
        fallback ingredient: RecipeIngredient,
        confidence: RecipeIngredientMappingConfidence
    ) -> RecipeIngredient {
        let displayName = displayName(for: entry)
        return RecipeIngredient(
            ingredientID: entry.ingredientID,
            produceID: entry.legacyProduceID,
            basicIngredientID: entry.legacyBasicID,
            quality: entry.ingredientType == "produce" ? .coreSeasonal : .basic,
            name: displayName,
            quantityValue: ingredient.quantityValue,
            quantityUnit: ingredient.quantityUnit,
            rawIngredientLine: ingredient.rawIngredientLine ?? ingredient.name,
            mappingConfidence: confidence
        )
    }

    func canonicalRecipeIngredientForImport(
        query: String,
        quantityValue: Double,
        quantityUnit: RecipeQuantityUnit,
        rawIngredientLine: String? = nil,
        confidence: RecipeIngredientMappingConfidence = .medium
    ) -> RecipeIngredient? {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return nil }
        guard let entry = resolveUnifiedCatalogEntry(query: normalizedQuery) else { return nil }

        return RecipeIngredient(
            ingredientID: entry.ingredientID,
            produceID: entry.legacyProduceID,
            basicIngredientID: entry.legacyBasicID,
            quality: entry.ingredientType == "produce" ? .coreSeasonal : .basic,
            name: displayName(for: entry),
            quantityValue: quantityValue,
            quantityUnit: quantityUnit,
            rawIngredientLine: rawIngredientLine,
            mappingConfidence: confidence
        )
    }

    private func displayName(for entry: UnifiedIngredientParityEntry) -> String {
        let localizedName = languageCode == AppLanguage.italian.rawValue
            ? (entry.itName ?? entry.enName)
            : (entry.enName ?? entry.itName)
        return localizedName ?? entry.slug.replacingOccurrences(of: "_", with: " ")
    }

    func quantityProfile(forProduceID produceID: String) -> IngredientUnitProfile {
        guard let item = produceItem(forID: produceID) else {
            return IngredientUnitProfile(
                defaultUnit: .g,
                supportedUnits: [.g, .piece],
                gramsPerUnit: [.g: 1, .piece: 100],
                mlPerUnit: [:],
                gramsPerMl: nil
            )
        }

        if let explicitDefault = item.defaultUnit,
           let explicitSupported = item.supportedUnits,
           !explicitSupported.isEmpty {
            var gramsMap: [RecipeQuantityUnit: Double] = [:]
            var mlMap: [RecipeQuantityUnit: Double] = [:]

            for (rawUnit, value) in (item.gramsPerUnit ?? [:]) {
                guard let unit = RecipeQuantityUnit(rawValue: rawUnit) else { continue }
                gramsMap[unit] = value
            }

            for (rawUnit, value) in (item.mlPerUnit ?? [:]) {
                guard let unit = RecipeQuantityUnit(rawValue: rawUnit) else { continue }
                mlMap[unit] = value
            }

            if gramsMap[.g] == nil, explicitSupported.contains(.g) {
                gramsMap[.g] = 1
            }
            if mlMap[.ml] == nil, explicitSupported.contains(.ml) {
                mlMap[.ml] = 1
            }

            return IngredientUnitProfile(
                defaultUnit: explicitDefault,
                supportedUnits: explicitSupported,
                gramsPerUnit: gramsMap,
                mlPerUnit: mlMap,
                gramsPerMl: item.gramsPerMl
            )
        }

        let pieceWeight: Double
        switch item.category {
        case .fruit:
            pieceWeight = 140
        case .vegetable:
            pieceWeight = 110
        case .tuber:
            pieceWeight = 150
        case .legume:
            pieceWeight = 90
        }

        return IngredientUnitProfile(
            defaultUnit: .g,
            supportedUnits: [.g, .piece],
            gramsPerUnit: [.g: 1, .piece: pieceWeight],
            mlPerUnit: [:],
            gramsPerMl: nil
        )
    }

    func recipeIngredientDisplayName(_ ingredient: RecipeIngredient) -> String {
        resolveIngredientForDisplay(ingredient).displayName
    }

    func resolveIngredientForDisplay(_ ingredient: RecipeIngredient) -> ResolvedIngredient {
        let cacheKey = ingredientDisplayResolutionCacheKey(for: ingredient)
        if let cached = ingredientDisplayResolutionCache[cacheKey] {
            return cached
        }

        let resolved = resolveIngredientForDisplayUncached(ingredient)
        ingredientDisplayResolutionCache[cacheKey] = resolved
        return resolved
    }

    private func ingredientDisplayResolutionCacheKey(for ingredient: RecipeIngredient) -> String {
        [
            languageCode,
            String(reconciliationInputVersion),
            ingredient.ingredientID ?? "",
            ingredient.produceID ?? "",
            ingredient.basicIngredientID ?? "",
            ingredient.quality.rawValue,
            ingredient.name,
            ingredient.rawIngredientLine ?? "",
            String(ingredient.quantityValue),
            ingredient.quantityUnit.rawValue,
            ingredient.mappingConfidence.rawValue
        ].joined(separator: "||")
    }

    private func resolveIngredientForDisplayUncached(_ ingredient: RecipeIngredient) -> ResolvedIngredient {
        if let produceID = ingredient.produceID,
           let item = produceItem(forID: produceID) {
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: item.displayName(languageCode: localizer.languageCode),
                produceItem: item,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        if let basicID = ingredient.basicIngredientID,
           let basic = basicIngredient(forID: basicID) {
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: basic.displayName(languageCode: localizer.languageCode),
                produceItem: nil,
                basicIngredient: basic,
                isReconciled: false
            )
        }

        if let ingredientID = ingredient.ingredientID,
           let entry = unifiedIngredientByID[ingredientID] {
            if let produceID = entry.legacyProduceID,
               let item = produceItem(forID: produceID) {
                return ResolvedIngredient(
                    recipeIngredient: ingredient,
                    displayName: item.displayName(languageCode: localizer.languageCode),
                    produceItem: item,
                    basicIngredient: nil,
                    isReconciled: true
                )
            }

            if let basicID = entry.legacyBasicID,
               let basic = basicIngredient(forID: basicID) {
                return ResolvedIngredient(
                    recipeIngredient: ingredient,
                    displayName: basic.displayName(languageCode: localizer.languageCode),
                    produceItem: nil,
                    basicIngredient: basic,
                    isReconciled: true
                )
            }

            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: displayName(for: entry),
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: true
            )
        }

        if ingredient.ingredientID != nil {
            let fallbackText = ingredient.rawIngredientLine?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
                : ingredient.name
            if let match = resolveCatalogMatchInIngredientText(query: fallbackText) {
                return resolvedIngredient(from: match, fallback: ingredient)
            }
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: ingredient.name,
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        let sourceText = ingredient.rawIngredientLine?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
            : ingredient.name
        let normalizedQuery = normalizedSearchText(sourceText)
        guard !normalizedQuery.isEmpty else {
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_kept_original name=\(ingredient.name) reason=empty_query")
            }
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: ingredient.name,
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        if SeasonLog.verbose {
            SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_attempt name=\(ingredient.name)")
        }

        let match = resolveUnifiedAliasMatch(query: normalizedQuery)
            ?? resolveUnifiedCatalogMatch(query: normalizedQuery)
            ?? resolveIngredientForImport(query: normalizedQuery)
            ?? resolveCatalogMatchInIngredientText(query: normalizedQuery)
        guard let match else {
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_kept_original name=\(ingredient.name) reason=no_match")
            }
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: ingredient.name,
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        return resolvedIngredient(from: match, fallback: ingredient)
    }

    private func resolvedIngredient(
        from match: IngredientAliasMatch,
        fallback ingredient: RecipeIngredient
    ) -> ResolvedIngredient {
        switch match {
        case .produce(let item):
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_upgraded from=custom to=produce name=\(ingredient.name) produce_id=\(item.id)")
            }
            return ResolvedIngredient(
                recipeIngredient: RecipeIngredient(
                    produceID: item.id,
                    basicIngredientID: nil,
                    quality: .coreSeasonal,
                    name: item.displayName(languageCode: localizer.languageCode),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    rawIngredientLine: ingredient.rawIngredientLine ?? ingredient.name,
                    mappingConfidence: .medium
                ),
                displayName: item.displayName(languageCode: localizer.languageCode),
                produceItem: item,
                basicIngredient: nil,
                isReconciled: true
            )
        case .basic(let item):
            if SeasonLog.verbose {
                SeasonLog.debug("[SEASON_RECONCILE] phase=reconciliation_upgraded from=custom to=basic name=\(ingredient.name) basic_id=\(item.id)")
            }
            return ResolvedIngredient(
                recipeIngredient: RecipeIngredient(
                    produceID: nil,
                    basicIngredientID: item.id,
                    quality: .basic,
                    name: item.displayName(languageCode: localizer.languageCode),
                    quantityValue: ingredient.quantityValue,
                    quantityUnit: ingredient.quantityUnit,
                    rawIngredientLine: ingredient.rawIngredientLine ?? ingredient.name,
                    mappingConfidence: .medium
                ),
                displayName: item.displayName(languageCode: localizer.languageCode),
                produceItem: nil,
                basicIngredient: item,
                isReconciled: true
            )
        }
    }

    func recipeNutritionSummary(for recipe: Recipe) -> RecipeNutritionSummary? {
        nutritionService.recipeNutritionSummary(for: recipe, context: nutritionContext)
    }

    func ingredientsForRecipe(_ recipe: Recipe) -> [ProduceItem] {
        var seen = Set<String>()
        return recipe.ingredients.compactMap { ingredient in
            guard let produceID = ingredient.produceID else { return nil }
            guard let item = produceItem(forID: produceID) else { return nil }
            guard seen.insert(item.id).inserted else { return nil }
            return item
        }
    }

    func seasonalMatchPercent(for produceIDs: [String]) -> Int {
        let validItems = produceIDs.compactMap { produceItem(forID: $0) }
        guard !validItems.isEmpty else { return 0 }
        let totalScore = validItems.reduce(0.0) { partial, item in
            partial + item.seasonalityScore(month: currentMonth)
        }
        let averageScore = totalScore / Double(validItems.count)
        return Int((averageScore * 100.0).rounded())
    }

    @discardableResult
    func publishRecipe(
        title: String,
        author: String,
        ingredients: [RecipeIngredient],
        steps: [String],
        externalMedia: [RecipeExternalMedia] = [],
        images: [RecipeImage],
        coverImageID: String?,
        coverImageName: String?,
        mediaLinkURL: String?,
        imageURL: String? = nil,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        sourceURL: String?,
        sourcePlatform: SocialSourcePlatform?,
        sourceCaptionRaw: String?,
        importedFromSocial: Bool,
        servings: Int = 2,
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        difficulty: RecipeDifficulty? = nil,
        existingRecipeID: String? = nil,
        isRemix: Bool = false,
        originalRecipeID: String? = nil,
        originalRecipeTitle: String? = nil,
        originalAuthorName: String? = nil,
        commitLocally: Bool = true
    ) -> Recipe? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSteps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedIngredients = ingredients.filter { ingredient in
            !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ingredient.quantityValue > 0
        }

        guard !trimmedTitle.isEmpty, !trimmedIngredients.isEmpty, !trimmedSteps.isEmpty else {
            return nil
        }

        let seasonalPercent = seasonalMatchPercent(for: trimmedIngredients.compactMap(\.produceID))
        let confirmedDietary = confirmedDietaryTags(forIngredients: trimmedIngredients)
        let validExternalMedia = externalMedia.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let validImages = images.filter {
            ($0.localPath?.isEmpty == false) || ($0.remoteURL?.isEmpty == false)
        }
        let normalizedServings = max(1, min(12, servings))
        let validCoverID = validImages.contains(where: { $0.id == coverImageID }) ? coverImageID : nil
        let trimmedImageName = coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMediaLink = mediaLinkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstagramURL = instagramURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTikTokURL = tiktokURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceCaption = sourceCaptionRaw?.trimmingCharacters(in: .whitespacesAndNewlines)

        let recipeID = existingRecipeID ?? "recipe_\(UUID().uuidString.lowercased())"
        let existingCreatedAt = recipes.first(where: { $0.id == recipeID })?.createdAt ?? Date()
        let creator = CurrentUser.shared.creator
        let resolvedCreatorName = resolvedCreatorDisplayName(from: author, creator: creator)

        var recipe = Recipe(
            id: recipeID,
            title: trimmedTitle,
            author: resolvedCreatorName,
            creatorId: creator.id,
            creatorDisplayName: resolvedCreatorName,
            creatorAvatarURL: creator.avatarURL,
            ingredients: trimmedIngredients,
            preparationSteps: trimmedSteps,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            difficulty: difficulty,
            servings: normalizedServings,
            crispy: 0,
            dietaryTags: confirmedDietary,
            seasonalMatchPercent: seasonalPercent,
            createdAt: existingCreatedAt,
            externalMedia: validExternalMedia,
            images: validImages,
            coverImageID: validCoverID,
            coverImageName: (trimmedImageName?.isEmpty == false) ? trimmedImageName : nil,
            mediaLinkURL: (trimmedMediaLink?.isEmpty == false) ? trimmedMediaLink : nil,
            instagramURL: (trimmedInstagramURL?.isEmpty == false) ? trimmedInstagramURL : nil,
            tiktokURL: (trimmedTikTokURL?.isEmpty == false) ? trimmedTikTokURL : nil,
            sourceURL: (trimmedSourceURL?.isEmpty == false) ? trimmedSourceURL : nil,
            sourcePlatform: sourcePlatform,
            sourceCaptionRaw: (trimmedSourceCaption?.isEmpty == false) ? trimmedSourceCaption : nil,
            importedFromSocial: importedFromSocial,
            publicationStatus: .published,
            isRemix: isRemix,
            originalRecipeID: originalRecipeID,
            originalRecipeTitle: originalRecipeTitle,
            originalAuthorName: originalAuthorName
        )
        recipe.imageURL = (trimmedImageURL?.isEmpty == false) ? trimmedImageURL : nil

        if commitLocally {
            commitPublishedRecipeLocally(recipe)
            SeasonLog.debug("[SEASON_RECIPE] phase=local_publish_succeeded recipe_id=\(recipe.id)")
        } else {
            SeasonLog.debug("[SEASON_RECIPE] phase=publish_recipe_built recipe_id=\(recipe.id) local_commit=false")
        }

        return recipe
    }

    func commitPublishedRecipeLocally(_ recipe: Recipe) {
        if let existingIndex = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[existingIndex] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
        invalidateRecipeCaches()
        RecipeStore.upsertUserRecipe(recipe)
    }

    func recipeReasonText(for ranked: RankedRecipe) -> String {
        let seasonalPercent = ranked.seasonalMatchPercent
        let ingredients = ingredientsForRecipe(ranked.recipe)
        let averageFiber = averageFiberValue(for: ingredients)

        if averageFiber >= 2.6 {
            return localizer.text(.recipeReasonHighFiberPick)
        }

        if ranked.seasonalMatchPercent >= 80 {
            return localizer.text(.recipeReasonFreshThisMonth)
        }

        return String(format: localizer.text(.recipeReasonSeasonalMatchFormat), seasonalPercent)
    }

    func recipeHookText(for ranked: RankedRecipe) -> String {
        let prep = ranked.recipe.prepTimeMinutes ?? 0
        let cook = ranked.recipe.cookTimeMinutes ?? 0
        let totalMinutes = prep + cook

        if totalMinutes > 0, totalMinutes <= 15 {
            return String(format: localizer.text(.recipeHookReadyInFormat), totalMinutes)
        }

        if ranked.recipe.crispy >= 140 {
            return localizer.text(.recipeHookViralThisWeek)
        }

        let ingredients = ingredientsForRecipe(ranked.recipe)
        let averageFiber = averageFiberValue(for: ingredients)
        if averageFiber >= 2.6 {
            return localizer.text(.recipeHookHighFiber)
        }

        if ranked.seasonalMatchPercent >= 80 {
            return localizer.text(.recipeHookSeasonalFavorite)
        }

        return localizer.text(.recipeHookTrendingNow)
    }

    func recipeTimingInsight(for ranked: RankedRecipe) -> RecipeTimingInsight {
        recipeTimingInsight(for: ranked.recipe, fallbackSeasonalPercent: ranked.seasonalMatchPercent)
    }

    func recipeTimingTitle(for ranked: RankedRecipe) -> String {
        localizer.recipeTimingTitle(recipeTimingInsight(for: ranked).label)
    }

    func recipeTimingLabel(for ranked: RankedRecipe) -> RecipeTimingLabel {
        recipeTimingInsight(for: ranked).label
    }

    func rankedFridgeRecommendations(fridgeItemIDs: Set<String>) -> [FridgeMatchedRecipe] {
        guard !fridgeItemIDs.isEmpty else { return [] }
        return matchedRecipesForFridge(fridgeItemIDs: fridgeItemIDs)
            .filter { $0.totalCount > 0 }
            .sorted { lhs, rhs in
                let leftScore = fridgeRankingScore(for: lhs.rankedRecipe.recipe, fridgeItemIDs: fridgeItemIDs)
                let rightScore = fridgeRankingScore(for: rhs.rankedRecipe.recipe, fridgeItemIDs: fridgeItemIDs)
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return lhs.rankedRecipe.recipe.title.localizedCaseInsensitiveCompare(rhs.rankedRecipe.recipe.title) == .orderedAscending
            }
    }

    func freshScoreLabel(for ranked: RankedRecipe) -> String {
        if ranked.score >= 82 {
            return localizer.text(.freshScoreExcellent)
        }
        if ranked.score >= 64 {
            return localizer.text(.freshScoreGreat)
        }
        return localizer.text(.freshScoreGood)
    }

    func totalCrispy(for author: String) -> Int {
        nonDeletedRecipes
            .filter { $0.author == author }
            .reduce(0) { $0 + $1.crispy }
    }

    func averageSeasonalMatch(for author: String) -> Double {
        let authored = nonDeletedRecipes.filter { $0.author == author }
        guard !authored.isEmpty else { return 0 }
        let total = authored.reduce(0) { $0 + $1.seasonalMatchPercent }
        return Double(total) / Double(authored.count)
    }

    func followerCount(for author: String, isFollowedByCurrentUser: Bool) -> Int {
        let authored = nonDeletedRecipes.filter { $0.author == author }
        guard !authored.isEmpty else { return isFollowedByCurrentUser ? 1 : 0 }

        let recipeCount = authored.count
        let crispy = totalCrispy(for: author)
        let totalViews = authored.reduce(0) { partialResult, recipe in
            partialResult + viewCount(for: recipe)
        }

        // Local estimate until a backend social graph is available.
        let estimatedBase = max(12, (recipeCount * 18) + (crispy / 6) + (totalViews / 120))
        return isFollowedByCurrentUser ? estimatedBase + 1 : estimatedBase
    }

    func badges(for author: String) -> [UserBadge] {
        let authoredRecipes = nonDeletedRecipes.filter { $0.author == author }
        let recipeCount = authoredRecipes.count
        let crispy = totalCrispy(for: author)
        let seasonalAverage = averageSeasonalMatch(for: author)

        var result: [UserBadge] = []

        if recipeCount >= 1 {
            result.append(UserBadge(kind: .seasonStarter))
        }

        if seasonalAverage >= 72 {
            result.append(UserBadge(kind: .freshCook))
        }

        if crispy >= 220 {
            result.append(UserBadge(kind: .crispyCreator))
        }

        if recipeCount >= 3, seasonalAverage >= 84 {
            result.append(UserBadge(kind: .topSeasonal))
        }

        let minDietaryRecipes = 2
        let glutenFreeCount = authoredRecipes.filter { confirmedDietaryTags(for: $0).contains(.glutenFree) }.count
        let vegetarianCount = authoredRecipes.filter { confirmedDietaryTags(for: $0).contains(.vegetarian) }.count
        let veganCount = authoredRecipes.filter { confirmedDietaryTags(for: $0).contains(.vegan) }.count

        if glutenFreeCount >= minDietaryRecipes {
            result.append(UserBadge(kind: .glutenFreeMaster))
        }

        if vegetarianCount >= minDietaryRecipes {
            result.append(UserBadge(kind: .vegetarianMaster))
        }

        if veganCount >= minDietaryRecipes {
            result.append(UserBadge(kind: .veganMaster))
        }

        return result
    }

    func primaryBadge(for author: String) -> UserBadge? {
        badges(for: author).first
    }

    func ingredientsAddFeedbackText(added: Int, alreadyInList: Int) -> String {
        if added == 0 {
            return localizer.text(.ingredientsAlreadyInList)
        }

        if alreadyInList == 0 {
            return String(format: localizer.text(.ingredientsAddedAllFormat), added)
        }

        return String(format: localizer.text(.ingredientsAddedSomeFormat), added, alreadyInList)
    }

    @discardableResult
    func setNutritionGoalsRaw(_ rawValue: String) -> String {
        let priorities = Self.parseNutritionPriorities(from: rawValue)
        let normalized = NutritionService.normalizedNutritionPrioritiesRaw(from: priorities)

        if nutritionPriorities != priorities {
            nutritionPriorities = priorities
            invalidateRankingCaches(reason: "nutrition_priorities_changed")
        }

        let legacy = NutritionService.legacyGoals(from: priorities)
        if nutritionGoals != legacy {
            nutritionGoals = legacy
        }

        return normalized
    }

    func nutritionPriorityValue(for dimension: NutritionPriorityDimension) -> Double {
        nutritionPriorities[dimension] ?? 0
    }

    func updateNutritionPriority(_ value: Double, for dimension: NutritionPriorityDimension) -> String {
        var updated = nutritionPriorities
        updated[dimension] = min(1, max(0, value))
        let normalized = NutritionService.normalizedNutritionPrioritiesRaw(from: updated)
        _ = setNutritionGoalsRaw(normalized)
        return normalized
    }

    @MainActor
    func refreshHomeFeed() async {
        // Rotate within top featured candidates to keep Home curated but fresh.
        featuredRecipeRotationOffset = (featuredRecipeRotationOffset + 1) % 10_000
        homeFeedRefreshID &+= 1
    }

    func featuredRecipeRotationIndex(poolCount: Int) -> Int {
        guard poolCount > 0 else { return 0 }
        return featuredRecipeRotationOffset % poolCount
    }

    private var nonDeletedRecipes: [Recipe] {
        recipes.filter { !deletedRecipeIDs.contains($0.id) }
    }

    private var discoverableRecipes: [Recipe] {
        nonDeletedRecipes.filter { $0.publicationStatus == .published && !archivedRecipeIDs.contains($0.id) }
    }

    private var feedEligibleDiscoverableRecipes: [Recipe] {
        discoverableRecipes.filter(\.isFeedEligible)
    }

    private var nutritionContext: NutritionService.Context {
        NutritionService.Context(
            produceItems: produceItems,
            discoverableRecipes: discoverableRecipes,
            produceByID: produceByID,
            basicByID: basicByID,
            basicByNormalizedName: basicByNormalizedName,
            catalogNutritionByIngredientID: catalogNutritionContextEntries(),
            fallbackUnitProfile: fallbackUnitProfile,
            quantityProfileForProduceID: { [unowned self] produceID in
                self.quantityProfile(forProduceID: produceID)
            }
        )
    }

    private func catalogNutritionContextEntries() -> [String: NutritionService.CatalogNutritionEntry] {
        Dictionary(uniqueKeysWithValues: unifiedIngredientByID.map { ingredientID, entry in
            (
                ingredientID,
                NutritionService.CatalogNutritionEntry(
                    nutrition: entry.nutrition,
                    unitProfile: entry.unitProfile,
                    isProduceLike: entry.ingredientType == "produce" || entry.legacyProduceID != nil
                )
            )
        })
    }

    private func compareItems(_ lhs: ProduceItem, _ rhs: ProduceItem) -> Bool {
        let leftScore = bestPickScore(for: lhs)
        let rightScore = bestPickScore(for: rhs)

        if leftScore != rightScore {
            return leftScore > rightScore
        }

        return lhs.displayName(languageCode: localizer.languageCode)
            < rhs.displayName(languageCode: localizer.languageCode)
    }

    func bestPickScore(for item: ProduceItem) -> Double {
        let seasonality = seasonalityScore(for: item)
        let nutrition = nutritionScore(for: item)
        let hasPreferenceWeight = nutritionPriorities.values.contains(where: { $0 > 0.0001 })
        if hasPreferenceWeight {
            return (seasonality * 0.60) + (nutrition * 0.40)
        }
        // Fallback: bias more to seasonality if preferences are empty.
        return (seasonality * 0.85) + (nutrition * 0.15)
    }

    private func todayPickScore(for item: ProduceItem) -> Double {
        let currentSeasonality = seasonalityScore(for: item)
        let amplitude = item.seasonalityAmplitude()
        let peakDistance = Double(min(6, item.seasonalityPeakDistance(month: currentMonth)))
        let peakProximity = max(0, 1.0 - (peakDistance / 6.0))
        let trend = min(1.0, max(0.0, 0.5 + (item.seasonalityDelta(month: currentMonth) * 1.8)))
        let freshnessPriority = todayFreshnessPriority(for: item)
        let nutrition = nutritionScore(for: item)

        var score =
            (currentSeasonality * 0.34)
            + (amplitude * 0.26)
            + (peakProximity * 0.20)
            + (freshnessPriority * 0.10)
            + (trend * 0.06)
            + (nutrition * 0.04)

        if item.isYearRoundSeasonal() {
            score -= 0.22
        }
        if isAromaticOrSpice(item) {
            score *= 0.58
        }
        if isMostlyImportedTropical(item) {
            score *= 0.72
        }
        if item.category == .legume {
            score *= 0.90
        }

        return min(1.0, max(0.0, score))
    }

    private func todayFreshnessPriority(for item: ProduceItem) -> Double {
        switch item.category {
        case .fruit:
            return 1.0
        case .vegetable:
            return 0.95
        case .tuber:
            return 0.72
        case .legume:
            return 0.58
        }
    }

    private func isAromaticOrSpice(_ item: ProduceItem) -> Bool {
        let searchText = ([item.id] + Array(item.localizedNames.values))
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let aromaticTerms = [
            "basil", "basilico", "thyme", "timo", "oregano", "origano",
            "rosemary", "rosmarino", "sage", "salvia", "mint", "menta",
            "parsley", "prezzemolo", "bay leaf", "alloro", "marjoram",
            "maggiorana", "chives", "erba cipollina", "dill", "aneto",
            "coriander", "coriandolo"
        ]
        return aromaticTerms.contains { searchText.contains($0) }
    }

    private func isMostlyImportedTropical(_ item: ProduceItem) -> Bool {
        let searchText = ([item.id] + Array(item.localizedNames.values))
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let tropicalTerms = [
            "pineapple", "ananas", "mango", "avocado", "lime",
            "banana", "coconut", "cocco", "papaya", "passion fruit",
            "frutto della passione"
        ]
        return tropicalTerms.contains { searchText.contains($0) }
    }

    private func rankedHomeRecipes(from source: [Recipe]) -> [RankedRecipe] {
        source
            .map { recipe in
                if SeasonLog.verbose {
                    let creatorIDForLog = recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
                    let creatorDisplayForLog = recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                    SeasonLog.debug("[SEASON_CREATOR_CHAIN] phase=ranked_identity recipe_id=\(recipe.id) creator_id=\(creatorIDForLog.isEmpty ? "nil" : creatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(recipe.author)")
                }
                let seasonality = recipeSeasonalityScore(for: recipe)
                let resolvedSeasonalPercent = Int((seasonality * 100.0).rounded())
                let score = homeRankingScore(for: recipe) * 100.0
                return RankedRecipe(
                    recipe: recipe,
                    score: score,
                    seasonalMatchPercent: resolvedSeasonalPercent
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.recipe.title < rhs.recipe.title
            }
    }

    private func rankedDiscoverableRecipes() -> [RankedRecipe] {
        if cachedDiscoverableRankedMonth == currentMonth {
            return cachedDiscoverableRankedRecipes
        }

        let ranked = rankedHomeRecipes(from: discoverableRecipes)
        cachedDiscoverableRankedRecipes = ranked
        cachedDiscoverableRankedByID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.recipe.id, $0) })
        cachedDiscoverableRankedMonth = currentMonth
        return ranked
    }

    private func rankedFeedEligibleDiscoverableRecipes() -> [RankedRecipe] {
        rankedDiscoverableRecipes().filter { $0.recipe.isFeedEligible }
    }

    private func rankedDiscoverableByID() -> [String: RankedRecipe] {
        if cachedDiscoverableRankedByID.isEmpty {
            _ = rankedDiscoverableRecipes()
        }
        return cachedDiscoverableRankedByID
    }

    private func rankedFeedEligibleDiscoverableByID() -> [String: RankedRecipe] {
        Dictionary(uniqueKeysWithValues: rankedFeedEligibleDiscoverableRecipes().map { ($0.recipe.id, $0) })
    }

    func homeRankingScore(for recipe: Recipe) -> Double {
        let breakdown = homeRecipeScoreBreakdown(for: recipe)
        let score = breakdown.score
        debugRankingIfNeeded(
            recipeName: recipe.title,
            channel: "home",
            finalScore: score,
            seasonality: breakdown.seasonality,
            fridgeMatch: nil,
            crispy: crispyScore(for: recipe),
            views: viewsScore(for: recipe),
            nutrition: breakdown.nutrition
        )
        debugHomeScoreBreakdownIfNeeded(recipeName: recipe.title, breakdown: breakdown)
        return score
    }

    func homeRecipeScoreBreakdown(for recipe: Recipe) -> HomeRecipeScoreBreakdown {
        let crispy = crispyScore(for: recipe)
        let views = viewsScore(for: recipe)
        let engagement = min(1.0, max(0.0, (0.55 * crispy) + (0.45 * views)))

        return HomeRecipeScoreBreakdown(
            seasonality: recipeSeasonalityScore(for: recipe),
            nutrition: nutritionPreferenceScore(for: recipe),
            quality: recipeQualityScore(for: recipe),
            convenience: recipeConvenienceScore(for: recipe),
            engagement: engagement,
            freshness: recipeFreshnessScore(for: recipe),
            sourceTrust: recipeSourceTrustScore(for: recipe)
        )
    }

    func fridgeRankingScore(for recipe: Recipe, fridgeItemIDs: Set<String>) -> Double {
        guard !fridgeItemIDs.isEmpty else { return 0 }

        let seasonality = recipeSeasonalityScore(for: recipe)
        let fridgeMatch = fridgeMatchScore(for: recipe, fridgeItemIDs: fridgeItemIDs)
        let crispy = crispyScore(for: recipe)
        let views = viewsScore(for: recipe)

        var score =
            (0.40 * seasonality)
            + (0.35 * fridgeMatch)
            + (0.15 * crispy)
            + (0.10 * views)

        if fridgeMatch == 0 {
            score *= 0.6
        } else if fridgeMatch == 1.0 && seasonality > 0.7 {
            score *= 1.2
        } else if fridgeMatch >= 0.6 {
            score *= 1.1
        }

        debugRankingIfNeeded(
            recipeName: recipe.title,
            channel: "fridge",
            finalScore: score,
            seasonality: seasonality,
            fridgeMatch: fridgeMatch,
            crispy: crispy,
            views: views,
            nutrition: nutritionPreferenceScore(for: recipe)
        )
        return score
    }

    func crispyScore(for recipe: Recipe) -> Double {
        let maxCrispy: Int
        if let cachedMaxCrispy {
            maxCrispy = cachedMaxCrispy
        } else {
            let computed = max(1, discoverableRecipes.map(\.crispy).max() ?? 1)
            cachedMaxCrispy = computed
            maxCrispy = computed
        }
        let numerator = log(1.0 + Double(recipe.crispy))
        let denominator = log(1.0 + Double(maxCrispy))
        guard denominator > 0 else { return 0 }
        return min(1.0, max(0.0, numerator / denominator))
    }

    func viewsScore(for recipe: Recipe) -> Double {
        let maxViews: Int
        if let cachedMaxViews {
            maxViews = cachedMaxViews
        } else {
            let computed = max(1, discoverableRecipes.map { viewCount(for: $0) }.max() ?? 1)
            cachedMaxViews = computed
            maxViews = computed
        }
        let numerator = log(1.0 + Double(viewCount(for: recipe)))
        let denominator = log(1.0 + Double(maxViews))
        guard denominator > 0 else { return 0 }
        return min(1.0, max(0.0, numerator / denominator))
    }

    func nutritionPreferenceScore(for recipe: Recipe) -> Double {
        nutritionService.nutritionPreferenceScore(
            for: recipe,
            priorities: nutritionPriorities,
            context: nutritionContext
        )
    }

    func recipeConvenienceScore(for recipe: Recipe) -> Double {
        let prep = recipe.prepTimeMinutes ?? 0
        let cook = recipe.cookTimeMinutes ?? 0
        let total = prep + cook

        guard total > 0 else { return 0.45 }
        if total <= 15 { return 1.0 }
        if total <= 30 { return 0.78 }
        if total <= 45 { return 0.58 }
        if total <= 75 { return 0.40 }
        return 0.25
    }

    func fridgeMatchScore(for recipe: Recipe, fridgeItemIDs: Set<String>) -> Double {
        weightedFridgeMatch(for: recipe, fridgeItemIDs: fridgeItemIDs).score
    }

    func isRecipeIngredientAvailable(
        _ ingredient: RecipeIngredient,
        fridgeIngredientIDs: Set<String>
    ) -> Bool {
        !catalogIdentityIDs(for: ingredient).isDisjoint(with: fridgeIngredientIDs)
    }

    func recipeTimingLabel(for recipe: Recipe) -> RecipeTimingLabel {
        recipeTimingInsight(for: recipe).label
    }

    private var rankingDebugEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SEASON_RANK_DEBUG"] == "1"
        #else
        false
        #endif
    }

    private func debugRankingIfNeeded(
        recipeName: String,
        channel: String,
        finalScore: Double,
        seasonality: Double,
        fridgeMatch: Double?,
        crispy: Double,
        views: Double,
        nutrition: Double
    ) {
        guard rankingDebugEnabled else { return }
        let fridgePart = fridgeMatch.map { String(format: "%.3f", $0) } ?? "-"
        SeasonLog.debug(
            "RANK DEBUG [\(channel)] recipe=\(recipeName) score=\(String(format: "%.3f", finalScore)) seasonality=\(String(format: "%.3f", seasonality)) fridgeMatch=\(fridgePart) crispy=\(String(format: "%.3f", crispy)) views=\(String(format: "%.3f", views)) nutrition=\(String(format: "%.3f", nutrition))"
        )
    }

    private func debugHomeScoreBreakdownIfNeeded(
        recipeName: String,
        breakdown: HomeRecipeScoreBreakdown
    ) {
        guard rankingDebugEnabled else { return }
        SeasonLog.debug(
            "RANK DEBUG [home_breakdown] recipe=\(recipeName) seasonality=\(String(format: "%.3f", breakdown.seasonality)) nutrition=\(String(format: "%.3f", breakdown.nutrition)) quality=\(String(format: "%.3f", breakdown.quality)) convenience=\(String(format: "%.3f", breakdown.convenience)) engagement=\(String(format: "%.3f", breakdown.engagement)) freshness=\(String(format: "%.3f", breakdown.freshness)) sourceTrust=\(String(format: "%.3f", breakdown.sourceTrust))"
        )
    }

    private func averageFiberValue(for ingredients: [ProduceItem]) -> Double {
        let fiberValues = ingredients.compactMap { $0.nutrition?.fiber }
        guard !fiberValues.isEmpty else { return 0 }
        return fiberValues.reduce(0, +) / Double(fiberValues.count)
    }

    private func recipeTimingInsight(
        for recipe: Recipe,
        fallbackSeasonalPercent: Int? = nil
    ) -> RecipeTimingInsight {
        let nextMonth = currentMonth == 12 ? 1 : (currentMonth + 1)

        let perIngredientSignals: [(score: Double, trend: Double, weight: Double)] = recipe.ingredients.compactMap { ingredient in
            guard let produceID = ingredient.produceID,
                  let item = produceItem(forID: produceID) else {
                // Non-seasonal/basic ingredients stay neutral and light-touch in recipe timing.
                return (score: 0.5, trend: 0.0, weight: max(0.15, ingredientWeight(for: ingredient) * 0.35))
            }

            let currentScore = item.seasonalityScore(month: currentMonth)
            let nextScore = item.seasonalityScore(month: nextMonth)
            let baseWeight = ingredientWeight(for: ingredient)
            let adjustedWeight: Double
            if isAromaticOrSpice(item) {
                adjustedWeight = baseWeight * 0.45
            } else if isMostlyImportedTropical(item) {
                adjustedWeight = baseWeight * 0.65
            } else {
                adjustedWeight = baseWeight
            }
            return (score: currentScore, trend: nextScore - currentScore, weight: adjustedWeight)
        }

        if perIngredientSignals.isEmpty {
            let fallbackScore = Double(fallbackSeasonalPercent ?? recipe.seasonalMatchPercent) / 100.0
            return RecipeTimingInsight(
                score: fallbackScore,
                trend: 0.0,
                label: recipeTimingLabel(score: fallbackScore, trend: 0.0)
            )
        }

        let totalWeight = perIngredientSignals.map(\.weight).reduce(0, +)
        guard totalWeight > 0 else {
            let fallbackScore = Double(fallbackSeasonalPercent ?? recipe.seasonalMatchPercent) / 100.0
            return RecipeTimingInsight(
                score: fallbackScore,
                trend: 0.0,
                label: recipeTimingLabel(score: fallbackScore, trend: 0.0)
            )
        }

        let score = perIngredientSignals.reduce(0.0) { $0 + ($1.score * $1.weight) } / totalWeight
        let trend = perIngredientSignals.reduce(0.0) { $0 + ($1.trend * $1.weight) } / totalWeight

        return RecipeTimingInsight(
            score: score,
            trend: trend,
            label: recipeTimingLabel(score: score, trend: trend)
        )
    }

    private func recipeTimingLabel(score: Double, trend: Double) -> RecipeTimingLabel {
        if score > 0.75 && abs(trend) < 0.05 {
            return .perfectNow
        }
        if trend > 0.1 {
            return .betterSoon
        }
        if trend < -0.1 {
            return .endingSoon
        }
        return .goodNow
    }

    private func recipeSeasonalityScore(for recipe: Recipe) -> Double {
        let insight = recipeTimingInsight(for: recipe, fallbackSeasonalPercent: recipe.seasonalMatchPercent)
        return min(1.0, max(0.0, insight.score))
    }

    private func recipeQualityScore(for recipe: Recipe) -> Double {
        let titleScore = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 ? 1.0 : 0.65
        let ingredientScore = min(1.0, Double(recipe.ingredients.count) / 6.0)
        let nonEmptySteps = recipe.preparationSteps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let stepScore = min(1.0, Double(nonEmptySteps.count) / 4.0)
        let hasVisual = (recipe.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || (recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || recipe.images.contains {
                ($0.localPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    || ($0.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            }
        let visualScore = hasVisual ? 1.0 : 0.55
        let hasTiming = (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0) > 0
        let metadataScore = (hasTiming ? 0.55 : 0.25) + (recipe.servings > 0 ? 0.45 : 0.20)

        return min(
            1.0,
            max(
                0.0,
                (0.18 * titleScore)
                + (0.24 * ingredientScore)
                + (0.24 * stepScore)
                + (0.20 * visualScore)
                + (0.14 * metadataScore)
            )
        )
    }

    private func recipeFreshnessScore(for recipe: Recipe) -> Double {
        let age = max(0, Calendar.current.dateComponents([.day], from: recipe.createdAt, to: Date()).day ?? 0)
        if age <= 7 { return 0.90 }
        if age <= 30 { return 0.74 }
        if age <= 90 { return 0.58 }
        if age <= 180 { return 0.46 }
        return 0.38
    }

    private func recipeSourceTrustScore(for recipe: Recipe) -> Double {
        let sourceName = recipe.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceName?.isEmpty == false {
            return 0.72
        }
        if recipe.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return 0.68
        }
        if recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return 0.64
        }
        if recipe.isUserGenerated {
            return 0.58
        }
        return 0.52
    }

    private func ingredientWeight(for ingredient: RecipeIngredient) -> Double {
        switch ingredient.quality {
        case .coreSeasonal:
            return 1.0
        case .basic:
            return 0.5
        }
    }

    private func weightedFridgeMatch(
        for recipe: Recipe,
        fridgeItemIDs: Set<String>
    ) -> (score: Double, availableWeight: Double, totalWeight: Double, matchingCount: Int, totalCount: Int) {
        let totalCount = recipe.ingredients.filter { ingredient in
            !catalogIdentityIDs(for: ingredient).isEmpty
        }.count
        guard totalCount > 0 else {
            return (score: 0, availableWeight: 0, totalWeight: 0, matchingCount: 0, totalCount: 0)
        }

        let hasWeightMetadata = recipe.ingredients.contains { $0.quality == .coreSeasonal || $0.quality == .basic }
        let fallbackEqualWeight = !hasWeightMetadata

        var availableWeight = 0.0
        var totalWeight = 0.0
        var matchingCount = 0

        for ingredient in recipe.ingredients {
            guard !catalogIdentityIDs(for: ingredient).isEmpty else { continue }
            let weight = fallbackEqualWeight ? 1.0 : ingredientWeight(for: ingredient)
            totalWeight += weight
            if isRecipeIngredientAvailable(ingredient, fridgeIngredientIDs: fridgeItemIDs) {
                availableWeight += weight
                matchingCount += 1
            }
        }

        guard totalWeight > 0 else {
            return (score: 0, availableWeight: 0, totalWeight: 0, matchingCount: matchingCount, totalCount: totalCount)
        }
        let score = min(1.0, max(0.0, availableWeight / totalWeight))
        return (score: score, availableWeight: availableWeight, totalWeight: totalWeight, matchingCount: matchingCount, totalCount: totalCount)
    }

    func catalogIdentityIDs(for ingredient: RecipeIngredient) -> Set<String> {
        var ids: Set<String> = []
        if let ingredientID = ingredient.ingredientID {
            ids.insert(ingredientID)
            if let entry = unifiedIngredientByID[ingredientID] {
                if let produceID = entry.legacyProduceID {
                    ids.insert(produceID)
                }
                if let basicID = entry.legacyBasicID {
                    ids.insert(basicID)
                }
            }
        }
        if let produceID = ingredient.produceID {
            ids.insert(produceID)
        }
        if let basicID = ingredient.basicIngredientID {
            ids.insert(basicID)
        }
        return ids
    }

    private func seasonalityScore(for item: ProduceItem) -> Double {
        item.seasonalityScore(month: currentMonth)
    }

    private func nutritionScore(for item: ProduceItem) -> Double {
        nutritionService.nutritionScore(
            for: item,
            priorities: nutritionPriorities,
            produceItems: produceItems
        )
    }

    private func normalizedRecipeNutritionValue(
        for dimension: NutritionPriorityDimension,
        summary: RecipeNutritionSummary
    ) -> Double {
        nutritionService.normalizedRecipeNutritionValue(
            for: dimension,
            summary: summary,
            priorities: nutritionPriorities,
            context: nutritionContext
        )
    }

    private func maxRecipeNutritionValue(for dimension: NutritionPriorityDimension) -> Double {
        nutritionService.maxRecipeNutritionValue(
            for: dimension,
            priorities: nutritionPriorities,
            context: nutritionContext
        )
    }

    private func rankingReasons(for item: ProduceItem) -> [String] {
        nutritionService.rankingReasons(
            for: item,
            priorities: nutritionPriorities,
            localizer: localizer,
            produceItems: produceItems
        )
    }

    private func normalizedNutritionValue(
        for dimension: NutritionPriorityDimension,
        nutrition: ProduceNutrition
    ) -> Double {
        nutritionService.normalizedNutritionValue(
            for: dimension,
            nutrition: nutrition,
            produceItems: produceItems
        )
    }

    private func maxNutritionValue(for dimension: NutritionPriorityDimension) -> Double {
        nutritionService.maxNutritionValue(for: dimension, produceItems: produceItems)
    }

    private func reasonText(for dimension: NutritionPriorityDimension) -> String {
        nutritionService.reasonText(for: dimension, localizer: localizer)
    }

    private static func parseNutritionPriorities(from raw: String) -> [NutritionPriorityDimension: Double] {
        NutritionService.parseNutritionPriorities(from: raw)
    }

    private static func normalizedNutritionPrioritiesRaw(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> String {
        NutritionService.normalizedNutritionPrioritiesRaw(from: priorities)
    }

    private static func legacyGoals(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> Set<NutritionGoal> {
        NutritionService.legacyGoals(from: priorities)
    }

    private static func parseStringSet(from raw: String) -> Set<String> {
        Set(
            raw.split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private static func normalizedStringSetRaw(from values: Set<String>) -> String {
        values.sorted().joined(separator: "|")
    }

    private static func parseViewCounts(from data: Data?) -> [String: Int] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func confirmedDietaryTags(forIngredients ingredients: [RecipeIngredient]) -> [RecipeDietaryTag] {
        nutritionService.confirmedDietaryTags(
            forIngredients: ingredients,
            context: nutritionContext
        )
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedWords(_ text: String) -> [String] {
        normalizedSearchText(text)
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    private func normalizedContainsTerm(_ term: String, in text: String) -> Bool {
        let termWords = normalizedWords(term)
        guard !termWords.isEmpty else { return false }
        let textWords = normalizedWords(text)
        guard textWords.count >= termWords.count else { return false }

        if termWords.count == 1 {
            return textWords.contains(termWords[0])
        }

        for startIndex in 0...(textWords.count - termWords.count) {
            let window = textWords[startIndex..<(startIndex + termWords.count)]
            if Array(window) == termWords {
                return true
            }
        }
        return false
    }

    private func matches(query: String, tokens: [String], in terms: [String]) -> Bool {
        relevanceScore(query: query, tokens: tokens, terms: terms) > 0
    }

    private func relevanceScore(query: String, tokens: [String], terms: [String]) -> Int {
        guard !query.isEmpty else { return 1 }

        let normalizedTerms = terms.map(normalizedSearchText).filter { !$0.isEmpty }
        guard !normalizedTerms.isEmpty else { return 0 }

        var score = 0

        if normalizedTerms.contains(query) {
            score += 120
        }

        if normalizedTerms.contains(where: { $0.hasPrefix(query) }) {
            score += 80
        }

        if normalizedTerms.contains(where: { $0.contains(query) }) {
            score += 50
        }

        for token in tokens where token.count >= 2 {
            if normalizedTerms.contains(where: { $0.hasPrefix(token) }) {
                score += 16
            } else if normalizedTerms.contains(where: { $0.contains(token) }) {
                score += 8
            }
        }

        return score
    }

    private func searchableTerms(for item: ProduceItem) -> [String] {
        var terms: [String] = []
        terms.append(contentsOf: item.localizedNames.values)
        terms.append(item.id)
        terms.append(item.id.replacingOccurrences(of: "_", with: " "))
        terms.append(contentsOf: ingredientAliases[item.id] ?? [])
        return terms
    }

    private func searchableTerms(for item: BasicIngredient) -> [String] {
        var terms: [String] = []
        terms.append(contentsOf: item.localizedNames.values)
        terms.append(item.id)
        terms.append(item.id.replacingOccurrences(of: "_", with: " "))
        terms.append(contentsOf: ingredientAliases[item.id] ?? [])
        return terms
    }

    private func searchableTerms(for recipe: Recipe) -> [String] {
        var terms: [String] = [recipe.title, recipe.author]
        terms.append(contentsOf: recipe.ingredients.map { recipeIngredientDisplayName($0) })
        terms.append(contentsOf: recipe.ingredients.map(\.name))
        return terms
    }

    private static let ingredientAliasesSeed: [String: [String]] = [
        "rocket": ["arugula", "rucola"],
        "eggplant": ["aubergine", "melanzana"],
        "zucchini": ["courgette", "zucchina"],
        "bell_pepper": ["bell pepper", "pepper", "peperone"],
        "chickpeas": ["ceci", "garbanzo", "garbanzo beans"],
        "lentils": ["lenticchie"],
        "beans": ["fagioli"],
        "green_beans": ["fagiolini", "string beans"],
        "cream_cheese": ["formaggio spalmabile"],
        "greek_yogurt": ["yogurt greco"]
    ]

    private var ingredientAliases: [String: [String]] {
        Self.ingredientAliasesSeed
    }
}
