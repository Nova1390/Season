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

final class ProduceViewModel: ObservableObject {
    private struct UnifiedIngredientParityEntry {
        let ingredientID: String
        let slug: String
        let ingredientType: String
        let enName: String?
        let itName: String?
        let legacyProduceID: String?
        let legacyBasicID: String?
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
        nextRemoteRecipeOffset = 0
        hasMoreRemoteRecipePages = true
        isFetchingRemoteRecipePage = false
        didCompleteInitialRemoteRecipeHydration = false
        invalidateRecipeCaches()
        loadBootstrapContent()
    }

    private func loadBootstrapContent() {
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
                self.fetchRemoteRecipesAndMerge(resetPagination: true)
                self.fetchRemoteIngredientAliases()
                self.fetchUnifiedIngredientParityData()
            }
        }
    }

    private func fetchRemoteIngredientAliases() {
        Task { [weak self] in
            guard let self else { return }
            let aliases = await supabaseService.fetchActiveIngredientAliases()
            let lookup = self.aliasLookupMap(from: aliases)
            await MainActor.run {
                self.remoteIngredientAliasLookup = lookup
                self.recipes = self.reconciledRecipesOnRead(self.recipes)
                self.invalidateRecipeCaches()
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
                legacyBasicID: record.legacyBasicID
            )
            entriesByID[ingredientID] = entry

            guard let match = ingredientAliasMatch(from: entry) else { continue }
            appendUnifiedLookup(slug, match: match, into: &nameLookup)
            appendUnifiedLookup(record.enName, match: match, into: &nameLookup)
            appendUnifiedLookup(record.itName, match: match, into: &nameLookup)
        }

        var aliasLookup: [String: IngredientAliasMatch] = [:]
        var aliasConfidenceLookup: [String: Double] = [:]
        for alias in aliases where alias.isActive {
            let normalized = normalizedSearchText(alias.normalizedAliasText)
            guard !normalized.isEmpty else { continue }
            guard let entry = entriesByID[alias.ingredientID],
                  let match = ingredientAliasMatch(from: entry) else { continue }
            let candidateConfidence = alias.confidence ?? -1
            let currentConfidence = aliasConfidenceLookup[normalized] ?? -1
            if aliasLookup[normalized] == nil || candidateConfidence >= currentConfidence {
                aliasLookup[normalized] = match
                aliasConfidenceLookup[normalized] = candidateConfidence
            }
        }

        unifiedIngredientByID = entriesByID
        unifiedAliasLookup = aliasLookup
        unifiedNameLookup = nameLookup

        print(
            "[SEASON_UNIFIED_PARITY] phase=parity_cache_ready catalog_count=\(entriesByID.count) alias_count=\(aliasLookup.count) name_lookup_count=\(nameLookup.count)"
        )
    }

    private func appendUnifiedLookup(
        _ raw: String?,
        match: IngredientAliasMatch,
        into lookup: inout [String: IngredientAliasMatch]
    ) {
        guard let raw else { return }
        let normalized = normalizedSearchText(raw)
        guard !normalized.isEmpty else { return }
        lookup[normalized] = match
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
        recipes.map { reconcileRecipeOnRead($0) }
    }

    private func reconcileRecipeOnRead(_ recipe: Recipe) -> Recipe {
        let unresolvedCount = recipe.ingredients.filter { !$0.hasCatalogIdentity }.count
        guard unresolvedCount > 0 else {
            print("[SEASON_RECONCILE] phase=reconciliation_skipped recipe_id=\(recipe.id) reason=no_unresolved_custom")
            return recipe
        }

        print("[SEASON_RECONCILE] phase=reconciliation_attempt recipe_id=\(recipe.id) unresolved_count=\(unresolvedCount)")

        var successCount = 0
        let reconciledIngredients = recipe.ingredients.map { ingredient -> RecipeIngredient in
            guard !ingredient.hasCatalogIdentity else { return ingredient }

            let sourceText = ingredient.rawIngredientLine?
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? ingredient.rawIngredientLine!.trimmingCharacters(in: .whitespacesAndNewlines)
                : ingredient.name
            let normalizedQuery = normalizedSearchText(sourceText)
            guard !normalizedQuery.isEmpty else { return ingredient }

            let matched = resolveIngredientAlias(query: normalizedQuery)
                ?? resolveCatalogMatchForCustomIngredient(query: normalizedQuery)
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
            print("[SEASON_RECONCILE] phase=reconciliation_skipped recipe_id=\(recipe.id) reason=no_match_found")
            return recipe
        }

        print("[SEASON_RECONCILE] phase=reconciliation_succeeded recipe_id=\(recipe.id) reconciled_count=\(successCount)")
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

    func loadNextRecipePageIfNeeded(isNearEnd: Bool) {
        guard isNearEnd else { return }
        fetchRemoteRecipesAndMerge()
    }

    private func fetchRemoteRecipesAndMerge(resetPagination: Bool = false) {
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
                }
            } catch {
                await MainActor.run {
                    self.isFetchingRemoteRecipePage = false
                }
                print("[SEASON_SUPABASE] request=fetchRecipes phase=request_failed local_fallback=true error=\(error)")
            }
        }
    }

    private func bumpHomeFeedDataVersion(reason: String) {
        homeFeedDataVersion &+= 1
        print("[SEASON_HOME_FEED] phase=data_version_bumped reason=\(reason) value=\(homeFeedDataVersion)")
    }

    private func bumpRankingDataVersion(reason: String) {
        rankingDataVersion &+= 1
        print("[SEASON_HOME_FEED] phase=ranking_version_bumped reason=\(reason) value=\(rankingDataVersion)")
    }

    private func mergedRecipes(local: [Recipe], remote: [Recipe]) -> [Recipe] {
        var seen = Set<String>()
        return (local + remote).filter { recipe in
            seen.insert(recipe.id).inserted
        }
    }

    private func debugLoadTimingIfNeeded(label: String, count: Int, elapsedMs: Int) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SEASON_LOAD_DEBUG"] == "1" {
            print("LOAD DEBUG [\(label)] count=\(count) time_ms=\(elapsedMs)")
        }
        #endif
    }

    private func invalidateRecipeCaches(reason: String = "recipe_data_changed") {
        cachedDiscoverableRankedRecipes = []
        cachedDiscoverableRankedByID = [:]
        cachedDiscoverableRankedMonth = nil
        nutritionService.invalidateCaches()
        cachedMaxCrispy = nil
        cachedMaxViews = nil
        bumpRankingDataVersion(reason: reason)
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
                let score = bestPickScore(for: item) * 100.0
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
        print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=local_update_done")
        print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=task_started")
        Task { [supabaseService] in
            print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=service_call")
            do {
                try await supabaseService.setRecipeCrispiedState(recipeID: recipe.id, isCrispied: isCrispied, traceID: traceID)
            } catch {
                print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipe.id) target=\(isCrispied) phase=write_failed error=\(error)")
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
        print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=local_update_done")
        print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=task_started")

        Task { [supabaseService] in
            print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=service_call")
            do {
                try await supabaseService.setRecipeSavedState(recipeID: recipe.id, isSaved: isSaved, traceID: traceID)
            } catch {
                print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipe.id) target=\(isSaved) phase=write_failed error=\(error)")
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
            print("[SEASON_UNIFIED_PARITY] phase=unified_resolution_used path=import query=\(normalized) value=\(unifiedKey)")
            print("[SEASON_UNIFIED_PARITY] phase=unified_resolution_mapped_to_legacy path=import query=\(normalized) value=\(unifiedKey)")
            return unified
        }

        let legacy = resolveLegacyAliasMatch(query: normalized)
            ?? resolveLegacyCatalogMatch(query: normalized)
        if let legacy {
            print("[SEASON_UNIFIED_PARITY] phase=unified_resolution_failed_fallback_legacy path=import query=\(normalized) legacy=\(parityMatchKey(legacy))")
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
            print("[SEASON_UNIFIED_PARITY] phase=parity_match_same path=\(path) query=\(query) value=\(legacyKey)")
            return
        }

        if legacyKey == "none" {
            print("[SEASON_UNIFIED_PARITY] phase=parity_missing_legacy path=\(path) query=\(query) unified=\(unifiedKey)")
            return
        }

        if unifiedKey == "none" {
            print("[SEASON_UNIFIED_PARITY] phase=parity_missing_unified path=\(path) query=\(query) legacy=\(legacyKey)")
            return
        }

        print("[SEASON_UNIFIED_PARITY] phase=parity_match_diff path=\(path) query=\(query) legacy=\(legacyKey) unified=\(unifiedKey)")
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
        print("[SEASON_RECIPE] phase=draft_created id=\(draft.id)")
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
        print("[SEASON_RECIPE] phase=draft_saved id=\(recipe.id)")
        return recipe
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

        if ingredient.ingredientID != nil {
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
            print("[SEASON_RECONCILE] phase=reconciliation_kept_original name=\(ingredient.name) reason=empty_query")
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: ingredient.name,
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        print("[SEASON_RECONCILE] phase=reconciliation_attempt name=\(ingredient.name)")

        let match = resolveUnifiedAliasMatch(query: normalizedQuery)
            ?? resolveUnifiedCatalogMatch(query: normalizedQuery)
            ?? resolveIngredientForImport(query: normalizedQuery)
        guard let match else {
            print("[SEASON_RECONCILE] phase=reconciliation_kept_original name=\(ingredient.name) reason=no_match")
            return ResolvedIngredient(
                recipeIngredient: ingredient,
                displayName: ingredient.name,
                produceItem: nil,
                basicIngredient: nil,
                isReconciled: false
            )
        }

        switch match {
        case .produce(let item):
            print("[SEASON_RECONCILE] phase=reconciliation_upgraded from=custom to=produce name=\(ingredient.name) produce_id=\(item.id)")
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
            print("[SEASON_RECONCILE] phase=reconciliation_upgraded from=custom to=basic name=\(ingredient.name) basic_id=\(item.id)")
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
            print("[SEASON_RECIPE] phase=local_publish_succeeded recipe_id=\(recipe.id)")
        } else {
            print("[SEASON_RECIPE] phase=publish_recipe_built recipe_id=\(recipe.id) local_commit=false")
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
            fallbackUnitProfile: fallbackUnitProfile,
            quantityProfileForProduceID: { [unowned self] produceID in
                self.quantityProfile(forProduceID: produceID)
            }
        )
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

    private func rankedHomeRecipes(from source: [Recipe]) -> [RankedRecipe] {
        source
            .map { recipe in
                let creatorIDForLog = recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
                let creatorDisplayForLog = recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                print("[SEASON_CREATOR_CHAIN] phase=ranked_identity recipe_id=\(recipe.id) creator_id=\(creatorIDForLog.isEmpty ? "nil" : creatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(recipe.author)")
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
        let seasonality = recipeSeasonalityScore(for: recipe)
        let crispy = crispyScore(for: recipe)
        let views = viewsScore(for: recipe)
        let nutrition = nutritionPreferenceScore(for: recipe)
        let score =
            (0.50 * seasonality)
            + (0.20 * crispy)
            + (0.15 * views)
            + (0.15 * nutrition)
        debugRankingIfNeeded(
            recipeName: recipe.title,
            channel: "home",
            finalScore: score,
            seasonality: seasonality,
            fridgeMatch: nil,
            crispy: crispy,
            views: views,
            nutrition: nutrition
        )
        return score
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

    func fridgeMatchScore(for recipe: Recipe, fridgeItemIDs: Set<String>) -> Double {
        weightedFridgeMatch(for: recipe, fridgeItemIDs: fridgeItemIDs).score
    }

    func isRecipeIngredientAvailable(
        _ ingredient: RecipeIngredient,
        fridgeIngredientIDs: Set<String>
    ) -> Bool {
        guard let ingredientID = ingredient.produceID ?? ingredient.basicIngredientID else {
            return false
        }
        return fridgeIngredientIDs.contains(ingredientID)
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
        print(
            "RANK DEBUG [\(channel)] recipe=\(recipeName) score=\(String(format: "%.3f", finalScore)) seasonality=\(String(format: "%.3f", seasonality)) fridgeMatch=\(fridgePart) crispy=\(String(format: "%.3f", crispy)) views=\(String(format: "%.3f", views)) nutrition=\(String(format: "%.3f", nutrition))"
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

        let perIngredientSignals: [(score: Double, trend: Double)] = recipe.ingredients.map { ingredient in
            guard let produceID = ingredient.produceID,
                  let item = produceItem(forID: produceID) else {
                // Non-seasonal/basic ingredients stay neutral in recipe timing.
                return (score: 0.5, trend: 0.0)
            }

            let currentScore = item.seasonalityScore(month: currentMonth)
            let nextScore = item.seasonalityScore(month: nextMonth)
            return (score: currentScore, trend: nextScore - currentScore)
        }

        if perIngredientSignals.isEmpty {
            let fallbackScore = Double(fallbackSeasonalPercent ?? recipe.seasonalMatchPercent) / 100.0
            return RecipeTimingInsight(
                score: fallbackScore,
                trend: 0.0,
                label: recipeTimingLabel(score: fallbackScore, trend: 0.0)
            )
        }

        let score = perIngredientSignals.map(\.score).reduce(0, +) / Double(perIngredientSignals.count)
        let trend = perIngredientSignals.map(\.trend).reduce(0, +) / Double(perIngredientSignals.count)

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
        let ingredientIDs = recipe.ingredients.compactMap { ingredient in
            ingredient.produceID ?? ingredient.basicIngredientID
        }
        let totalCount = ingredientIDs.count
        guard totalCount > 0 else {
            return (score: 0, availableWeight: 0, totalWeight: 0, matchingCount: 0, totalCount: 0)
        }

        let hasWeightMetadata = recipe.ingredients.contains { $0.quality == .coreSeasonal || $0.quality == .basic }
        let fallbackEqualWeight = !hasWeightMetadata

        var availableWeight = 0.0
        var totalWeight = 0.0
        var matchingCount = 0

        for ingredient in recipe.ingredients {
            guard ingredient.produceID != nil || ingredient.basicIngredientID != nil else { continue }
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
