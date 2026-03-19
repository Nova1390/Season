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

private struct DietarySupport {
    let glutenFree: Bool?
    let vegetarian: Bool?
    let vegan: Bool?
}

final class ProduceViewModel: ObservableObject {
    @Published private(set) var produceItems: [ProduceItem] = []
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var userProfiles: [UserProfile] = []
    @Published private(set) var savedRecipeIDs: Set<String> = []
    @Published private(set) var crispiedRecipeIDs: Set<String> = []
    @Published private(set) var archivedRecipeIDs: Set<String> = []
    @Published private(set) var deletedRecipeIDs: Set<String> = []
    @Published private(set) var recipeViewCounts: [String: Int] = [:]
    @Published private(set) var languageCode: String
    @Published private(set) var nutritionGoals: Set<NutritionGoal> = []
    @Published private(set) var nutritionPriorities: [NutritionPriorityDimension: Double] = ProduceViewModel.defaultNutritionPriorities
    private let nutritionGoalsStorageKey = "nutritionGoalsRaw"
    private let savedRecipeIDsStorageKey = "savedRecipeIDsRaw"
    private let crispiedRecipeIDsStorageKey = "crispiedRecipeIDsRaw"
    private let archivedRecipeIDsStorageKey = "archivedRecipeIDsRaw"
    private let deletedRecipeIDsStorageKey = "deletedRecipeIDsRaw"
    private let recipeViewCountsStorageKey = "recipeViewCountsData"
    private let basicIngredients: [BasicIngredient]

    var localizer: AppLocalizer {
        AppLocalizer(languageCode: languageCode)
    }

    init(languageCode: String = "en") {
        self.languageCode = AppLanguage(rawValue: languageCode)?.rawValue ?? AppLanguage.english.rawValue
        self.produceItems = ProduceStore.loadFromBundle()
        self.basicIngredients = BasicIngredientCatalog.all
        self.recipes = RecipeStore.loadRecipes()
        self.userProfiles = RecipeStore.loadProfiles()
        let rawNutritionGoals = UserDefaults.standard.string(forKey: nutritionGoalsStorageKey) ?? ""
        self.nutritionPriorities = Self.parseNutritionPriorities(from: rawNutritionGoals)
        self.nutritionGoals = Self.legacyGoals(from: self.nutritionPriorities)
        self.savedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: savedRecipeIDsStorageKey) ?? "")
        self.crispiedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: crispiedRecipeIDsStorageKey) ?? "")
        self.archivedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: archivedRecipeIDsStorageKey) ?? "")
        self.deletedRecipeIDs = Self.parseStringSet(from: UserDefaults.standard.string(forKey: deletedRecipeIDsStorageKey) ?? "")
        self.recipeViewCounts = Self.parseViewCounts(from: UserDefaults.standard.data(forKey: recipeViewCountsStorageKey))
    }

    @discardableResult
    func setLanguage(_ newCode: String) -> String {
        let resolved = AppLanguage(rawValue: newCode)?.rawValue ?? AppLanguage.english.rawValue
        if languageCode != resolved {
            languageCode = resolved
        }
        return resolved
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
        let ranked = rankedHomeRecipes(from: discoverableRecipes)
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
        Array(rankedHomeRecipes(from: discoverableRecipes).prefix(max(1, limit)))
    }

    func homeRankedRecipes(limit: Int = 12) -> [RankedRecipe] {
        Array(rankedHomeRecipes(from: discoverableRecipes).prefix(max(1, limit)))
    }

    func rankedTrendingNowRecipes(limit: Int = 6) -> [RankedRecipe] {
        let homeResolved = Dictionary(
            uniqueKeysWithValues: rankedHomeRecipes(from: discoverableRecipes).map { ($0.recipe.id, $0) }
        )

        return discoverableRecipes
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
        rankedHomeRecipes(from: discoverableRecipes)
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
        let followed = discoverableRecipes.filter { followedAuthors.contains($0.author) }
        return Array(rankedHomeRecipes(from: followed).prefix(max(1, limit)))
    }

    func rankedRecipesByAuthor(_ author: String) -> [RankedRecipe] {
        let authored = discoverableRecipes.filter { $0.author == author }
        return rankedHomeRecipes(from: authored)
    }

    func rankedRecipe(forID id: String) -> RankedRecipe? {
        rankedHomeRecipes(from: nonDeletedRecipes).first { $0.recipe.id == id }
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
        var updated = crispiedRecipeIDs
        if updated.contains(recipe.id) {
            updated.remove(recipe.id)
        } else {
            updated.insert(recipe.id)
        }
        crispiedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: crispiedRecipeIDsStorageKey)
    }

    func toggleSavedRecipe(_ recipe: Recipe) {
        var updated = savedRecipeIDs
        if updated.contains(recipe.id) {
            updated.remove(recipe.id)
        } else {
            updated.insert(recipe.id)
        }
        savedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: savedRecipeIDsStorageKey)
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
    }

    func unarchiveRecipe(_ recipe: Recipe) {
        var updated = archivedRecipeIDs
        updated.remove(recipe.id)
        archivedRecipeIDs = updated
        UserDefaults.standard.set(Self.normalizedStringSetRaw(from: updated), forKey: archivedRecipeIDsStorageKey)
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
    }

    func compactCountText(_ value: Int) -> String {
        if value >= 1_000_000 {
            let compact = Double(value) / 1_000_000.0
            return "\(compactRoundedText(compact))M"
        }
        if value >= 1_000 {
            let compact = Double(value) / 1_000.0
            return "\(compactRoundedText(compact))K"
        }
        return "\(value)"
    }

    private func compactRoundedText(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }

    func confirmedDietaryTags(for recipe: Recipe) -> [RecipeDietaryTag] {
        confirmedDietaryTags(forIngredients: recipe.ingredients)
    }

    func rankedRecipesForFridge(fridgeItemIDs: Set<String>, limit: Int = 6) -> [FridgeMatchedRecipe] {
        let ranked = matchedRecipesForFridge(fridgeItemIDs: fridgeItemIDs)

        return Array(ranked.prefix(max(1, limit)))
    }

    func matchedRecipesForFridge(fridgeItemIDs: Set<String>) -> [FridgeMatchedRecipe] {
        rankedHomeRecipes(from: discoverableRecipes)
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
        produceItems.first { $0.id == id }
    }

    func basicIngredient(forID id: String) -> BasicIngredient? {
        basicIngredients.first { $0.id == id }
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
        if let produceID = ingredient.produceID,
           let item = produceItem(forID: produceID) {
            return item.displayName(languageCode: localizer.languageCode)
        }

        if let basicID = ingredient.basicIngredientID,
           let basic = basicIngredient(forID: basicID) {
            return basic.displayName(languageCode: localizer.languageCode)
        }

        return ingredient.name
    }

    func recipeNutritionSummary(for recipe: Recipe) -> RecipeNutritionSummary? {
        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalFiber = 0.0
        var totalVitaminC = 0.0
        var totalPotassium = 0.0
        var hasAnyNutritionData = false

        for ingredient in recipe.ingredients {
            let nutritionInfo = nutritionInfo(for: ingredient)
            guard let nutrition = nutritionInfo.nutrition else { continue }
            hasAnyNutritionData = true

            let grams = quantityInGrams(
                value: ingredient.quantityValue,
                unit: ingredient.quantityUnit,
                profile: nutritionInfo.unitProfile
            )
            let factor = grams / 100.0

            totalCalories += Double(nutrition.calories) * factor
            totalProtein += nutrition.protein * factor
            totalCarbs += nutrition.carbs * factor
            totalFat += nutrition.fat * factor
            totalFiber += nutrition.fiber * factor
            totalVitaminC += nutrition.vitaminC * factor
            totalPotassium += nutrition.potassium * factor
        }

        guard hasAnyNutritionData else { return nil }
        return RecipeNutritionSummary(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            vitaminC: totalVitaminC,
            potassium: totalPotassium
        )
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
        sourceURL: String?,
        sourcePlatform: SocialSourcePlatform?,
        sourceCaptionRaw: String?,
        importedFromSocial: Bool,
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

        guard !trimmedTitle.isEmpty, !trimmedIngredients.isEmpty, !trimmedSteps.isEmpty else {
            return nil
        }

        let seasonalPercent = seasonalMatchPercent(for: trimmedIngredients.compactMap(\.produceID))
        let confirmedDietary = confirmedDietaryTags(forIngredients: trimmedIngredients)
        let validExternalMedia = externalMedia.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let validImages = images.filter {
            ($0.localPath?.isEmpty == false) || ($0.remoteURL?.isEmpty == false)
        }
        let validCoverID = validImages.contains(where: { $0.id == coverImageID }) ? coverImageID : nil
        let trimmedImageName = coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMediaLink = mediaLinkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceCaption = sourceCaptionRaw?.trimmingCharacters(in: .whitespacesAndNewlines)

        let recipe = Recipe(
            id: "recipe_\(UUID().uuidString.lowercased())",
            title: trimmedTitle,
            author: author,
            ingredients: trimmedIngredients,
            preparationSteps: trimmedSteps,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            difficulty: difficulty,
            crispy: 0,
            dietaryTags: confirmedDietary,
            seasonalMatchPercent: seasonalPercent,
            createdAt: Date(),
            externalMedia: validExternalMedia,
            images: validImages,
            coverImageID: validCoverID,
            coverImageName: (trimmedImageName?.isEmpty == false) ? trimmedImageName : nil,
            mediaLinkURL: (trimmedMediaLink?.isEmpty == false) ? trimmedMediaLink : nil,
            sourceURL: (trimmedSourceURL?.isEmpty == false) ? trimmedSourceURL : nil,
            sourcePlatform: sourcePlatform,
            sourceCaptionRaw: (trimmedSourceCaption?.isEmpty == false) ? trimmedSourceCaption : nil,
            importedFromSocial: importedFromSocial,
            isRemix: isRemix,
            originalRecipeID: originalRecipeID,
            originalRecipeTitle: originalRecipeTitle,
            originalAuthorName: originalAuthorName
        )

        recipes.insert(recipe, at: 0)
        return recipe
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
        let normalized = Self.normalizedNutritionPrioritiesRaw(from: priorities)

        if nutritionPriorities != priorities {
            nutritionPriorities = priorities
        }

        let legacy = Self.legacyGoals(from: priorities)
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
        let normalized = Self.normalizedNutritionPrioritiesRaw(from: updated)
        _ = setNutritionGoalsRaw(normalized)
        return normalized
    }

    private var nonDeletedRecipes: [Recipe] {
        recipes.filter { !deletedRecipeIDs.contains($0.id) }
    }

    private var discoverableRecipes: [Recipe] {
        nonDeletedRecipes.filter { !archivedRecipeIDs.contains($0.id) }
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
        let maxCrispy = max(1, discoverableRecipes.map(\.crispy).max() ?? 1)
        let numerator = log(1.0 + Double(recipe.crispy))
        let denominator = log(1.0 + Double(maxCrispy))
        guard denominator > 0 else { return 0 }
        return min(1.0, max(0.0, numerator / denominator))
    }

    func viewsScore(for recipe: Recipe) -> Double {
        let allViewCounts = discoverableRecipes.map { viewCount(for: $0) }
        let maxViews = max(1, allViewCounts.max() ?? 1)
        let numerator = log(1.0 + Double(viewCount(for: recipe)))
        let denominator = log(1.0 + Double(maxViews))
        guard denominator > 0 else { return 0 }
        return min(1.0, max(0.0, numerator / denominator))
    }

    func nutritionPreferenceScore(for recipe: Recipe) -> Double {
        guard let summary = recipeNutritionSummary(for: recipe) else { return 0 }
        let weightedDimensions = nutritionPriorities.filter { $0.value > 0.0001 }
        guard !weightedDimensions.isEmpty else { return 0 }

        var weightedScore = 0.0
        var totalWeight = 0.0
        for (dimension, weight) in weightedDimensions {
            let normalized = normalizedRecipeNutritionValue(for: dimension, summary: summary)
            weightedScore += normalized * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0 }
        return min(1.0, max(0.0, weightedScore / totalWeight))
    }

    func fridgeMatchScore(for recipe: Recipe, fridgeItemIDs: Set<String>) -> Double {
        weightedFridgeMatch(for: recipe, fridgeItemIDs: fridgeItemIDs).score
    }

    func recipeTimingLabel(for recipe: Recipe) -> RecipeTimingLabel {
        recipeTimingInsight(for: recipe).label
    }

    private var rankingDebugEnabled: Bool { true }

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
            guard let ingredientID = ingredient.produceID ?? ingredient.basicIngredientID else { continue }
            let weight = fallbackEqualWeight ? 1.0 : ingredientWeight(for: ingredient)
            totalWeight += weight
            if fridgeItemIDs.contains(ingredientID) {
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
        guard let nutrition = item.nutrition else { return 0 }
        let weightedDimensions = nutritionPriorities.filter { $0.value > 0.0001 }
        guard !weightedDimensions.isEmpty else { return 0 }

        var weightedScore = 0.0
        var totalWeight = 0.0

        for (dimension, weight) in weightedDimensions {
            let normalized = normalizedNutritionValue(for: dimension, nutrition: nutrition)
            weightedScore += normalized * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        return min(1.0, max(0.0, weightedScore / totalWeight))
    }

    private func normalizedRecipeNutritionValue(
        for dimension: NutritionPriorityDimension,
        summary: RecipeNutritionSummary
    ) -> Double {
        let value: Double
        switch dimension {
        case .protein:
            value = summary.protein
        case .carbs:
            value = summary.carbs
        case .fat:
            value = summary.fat
        case .fiber:
            value = summary.fiber
        case .vitaminC:
            value = summary.vitaminC
        case .potassium:
            value = summary.potassium
        }

        let maxValue = maxRecipeNutritionValue(for: dimension)
        guard maxValue > 0 else { return 0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    private func maxRecipeNutritionValue(for dimension: NutritionPriorityDimension) -> Double {
        let values: [Double] = discoverableRecipes.compactMap { recipe in
            guard let summary = recipeNutritionSummary(for: recipe) else { return nil }
            switch dimension {
            case .protein:
                return summary.protein
            case .carbs:
                return summary.carbs
            case .fat:
                return summary.fat
            case .fiber:
                return summary.fiber
            case .vitaminC:
                return summary.vitaminC
            case .potassium:
                return summary.potassium
            }
        }
        return max(0.0001, values.max() ?? 0.0001)
    }

    private func rankingReasons(for item: ProduceItem) -> [String] {
        guard let nutrition = item.nutrition else {
            return [localizer.text(.reasonInSeasonNow)]
        }

        var reasons: [String] = []
        let topPriorities = nutritionPriorities
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .filter { $0.value > 0.05 }
            .prefix(2)

        for (dimension, _) in topPriorities {
            let normalized = normalizedNutritionValue(for: dimension, nutrition: nutrition)
            guard normalized >= 0.55 else { continue }
            reasons.append(reasonText(for: dimension))
        }

        if reasons.isEmpty {
            reasons.append(localizer.text(.reasonInSeasonNow))
        }

        return Array(reasons.prefix(2))
    }

    private func normalizedNutritionValue(
        for dimension: NutritionPriorityDimension,
        nutrition: ProduceNutrition
    ) -> Double {
        let value: Double
        switch dimension {
        case .protein:
            value = nutrition.protein
        case .carbs:
            value = nutrition.carbs
        case .fat:
            value = nutrition.fat
        case .fiber:
            value = nutrition.fiber
        case .vitaminC:
            value = nutrition.vitaminC
        case .potassium:
            value = nutrition.potassium
        }

        let maxValue = maxNutritionValue(for: dimension)
        guard maxValue > 0 else { return 0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    private func maxNutritionValue(for dimension: NutritionPriorityDimension) -> Double {
        let values: [Double] = produceItems.compactMap { item in
            guard let nutrition = item.nutrition else { return nil }
            switch dimension {
            case .protein:
                return nutrition.protein
            case .carbs:
                return nutrition.carbs
            case .fat:
                return nutrition.fat
            case .fiber:
                return nutrition.fiber
            case .vitaminC:
                return nutrition.vitaminC
            case .potassium:
                return nutrition.potassium
            }
        }
        return max(0.0001, values.max() ?? 0.0001)
    }

    private func reasonText(for dimension: NutritionPriorityDimension) -> String {
        switch dimension {
        case .protein:
            return localizer.text(.reasonHighProtein)
        case .carbs:
            return localizer.text(.reasonHighCarbs)
        case .fat:
            return localizer.text(.reasonHighFat)
        case .fiber:
            return localizer.text(.reasonHighFiber)
        case .vitaminC:
            return localizer.text(.reasonHighVitaminC)
        case .potassium:
            return localizer.text(.reasonHighPotassium)
        }
    }

    private static let defaultNutritionPriorities: [NutritionPriorityDimension: Double] = [
        .protein: 0.5,
        .carbs: 0.25,
        .fat: 0.25,
        .fiber: 0.6,
        .vitaminC: 0.45,
        .potassium: 0.35
    ]

    private static func parseNutritionPriorities(from raw: String) -> [NutritionPriorityDimension: Double] {
        var parsed = defaultNutritionPriorities
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return parsed }

        // New format example: "protein:0.75,fiber:0.50,vitaminC:0.40"
        if trimmed.contains(":") {
            for part in trimmed.split(separator: ",") {
                let pieces = part.split(separator: ":", maxSplits: 1).map(String.init)
                guard pieces.count == 2,
                      let dimension = NutritionPriorityDimension(rawValue: pieces[0]),
                      let value = Double(pieces[1]) else { continue }
                parsed[dimension] = min(1, max(0, value))
            }
            return parsed
        }

        // Legacy fallback: old comma-separated toggle goals.
        let legacyGoals = Set(
            trimmed.split(separator: ",")
                .compactMap { NutritionGoal(rawValue: String($0)) }
        )

        if !legacyGoals.isEmpty {
            parsed = Dictionary(uniqueKeysWithValues: NutritionPriorityDimension.allCases.map { ($0, 0.0) })
            if legacyGoals.contains(.moreProtein) {
                parsed[.protein] = 1.0
            }
            if legacyGoals.contains(.moreFiber) {
                parsed[.fiber] = 1.0
            }
            if legacyGoals.contains(.moreVitaminC) {
                parsed[.vitaminC] = 1.0
            }
            if legacyGoals.contains(.lowerSugar) {
                parsed[.carbs] = 0.0
            }
        }

        return parsed
    }

    private static func normalizedNutritionPrioritiesRaw(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> String {
        NutritionPriorityDimension.allCases
            .map { dimension in
                let value = min(1, max(0, priorities[dimension] ?? 0))
                return "\(dimension.rawValue):\(String(format: "%.2f", value))"
            }
            .joined(separator: ",")
    }

    private static func legacyGoals(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> Set<NutritionGoal> {
        var goals: Set<NutritionGoal> = []
        if (priorities[.protein] ?? 0) > 0.55 {
            goals.insert(.moreProtein)
        }
        if (priorities[.fiber] ?? 0) > 0.55 {
            goals.insert(.moreFiber)
        }
        if (priorities[.vitaminC] ?? 0) > 0.55 {
            goals.insert(.moreVitaminC)
        }
        if (priorities[.carbs] ?? 0) < 0.20 {
            goals.insert(.lowerSugar)
        }
        return goals
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
        guard !ingredients.isEmpty else { return [] }

        var result: [RecipeDietaryTag] = []
        for tag in RecipeDietaryTag.allCases {
            let isConfirmedForAllIngredients = ingredients.allSatisfy { ingredient in
                let support = dietarySupport(for: ingredient)
                switch tag {
                case .glutenFree:
                    return support.glutenFree == true
                case .vegetarian:
                    return support.vegetarian == true
                case .vegan:
                    return support.vegan == true
                }
            }

            if isConfirmedForAllIngredients {
                result.append(tag)
            }
        }

        return result
    }

    private func dietarySupport(for ingredient: RecipeIngredient) -> DietarySupport {
        if ingredient.produceID != nil {
            // Fresh produce in this app catalog is treated as explicitly plant-based.
            return DietarySupport(glutenFree: true, vegetarian: true, vegan: true)
        }

        guard let basicID = ingredient.basicIngredientID else {
            // Unknown custom ingredient: do not classify.
            return DietarySupport(glutenFree: nil, vegetarian: nil, vegan: nil)
        }

        if let basicIngredient = basicIngredient(forID: basicID) {
            return DietarySupport(
                glutenFree: basicIngredient.dietaryFlags.isGlutenFree,
                vegetarian: basicIngredient.dietaryFlags.isVegetarian,
                vegan: basicIngredient.dietaryFlags.isVegan
            )
        }

        return DietarySupport(glutenFree: nil, vegetarian: nil, vegan: nil)
    }

    private func nutritionInfo(for ingredient: RecipeIngredient) -> (nutrition: ProduceNutrition?, unitProfile: IngredientUnitProfile) {
        if let produceID = ingredient.produceID,
           let item = produceItem(forID: produceID) {
            return (item.nutrition, quantityProfile(forProduceID: produceID))
        }

        if let basicID = ingredient.basicIngredientID,
           let basic = basicIngredient(forID: basicID) {
            return (basic.nutrition, basic.unitProfile)
        }

        let normalizedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let fallbackBasic = basicIngredients.first(where: { basic in
            basic.localizedNames.values.map { $0.lowercased() }.contains(normalizedName)
            || basic.id.replacingOccurrences(of: "_", with: " ").lowercased() == normalizedName
        }) {
            return (fallbackBasic.nutrition, fallbackBasic.unitProfile)
        }

        return (
            nil,
            IngredientUnitProfile(
                defaultUnit: .g,
                supportedUnits: [.g, .piece],
                gramsPerUnit: [.g: 1, .piece: 100],
                mlPerUnit: [:],
                gramsPerMl: nil
            )
        )
    }

    private func quantityInGrams(value: Double, unit: RecipeQuantityUnit, profile: IngredientUnitProfile) -> Double {
        let safeValue = max(0, value)
        guard safeValue > 0 else { return 0 }

        if unit == .g {
            return safeValue
        }

        if let grams = profile.gramsPerUnit[unit] {
            return safeValue * grams
        }

        if unit == .ml {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * gramsPerMl
        }

        if let ml = profile.mlPerUnit[unit] {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * ml * gramsPerMl
        }

        if let fallbackGrams = profile.gramsPerUnit[profile.defaultUnit] {
            return safeValue * fallbackGrams
        }

        if let fallbackMl = profile.mlPerUnit[profile.defaultUnit] {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * fallbackMl * gramsPerMl
        }

        return safeValue
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

    private var ingredientAliases: [String: [String]] {
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
            "greek_yogurt": ["yogurt greco"]
        ]
    }
}
