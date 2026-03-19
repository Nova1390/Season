import Foundation

enum ProduceCategoryKey: String, Codable, CaseIterable {
    case fruit
    case vegetable
    case tuber
    case legume
}

enum SeasonalityLevel: String, Hashable {
    case peak
    case good
    case low
    case out
}

enum SeasonalityPhase: String, Hashable {
    case inSeason
    case earlySeason
    case endingSoon
    case outOfSeason
}

enum NutritionGoal: String, CaseIterable, Identifiable {
    case moreProtein
    case moreFiber
    case moreVitaminC
    case lowerSugar

    var id: String { rawValue }
}

enum NutritionPriorityDimension: String, CaseIterable, Identifiable, Hashable {
    case protein
    case carbs
    case fat
    case fiber
    case vitaminC
    case potassium

    var id: String { rawValue }
}

enum NutritionBasis: String, Codable, Hashable {
    case per100g = "per_100g"
}

enum IngredientQualityLevel: String, Codable, Hashable {
    case core
    case basic
}

struct ProduceNutrition: Codable, Hashable {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let vitaminC: Double
    let potassium: Double
}

struct ProduceItem: Identifiable, Codable, Hashable {
    let id: String
    let category: ProduceCategoryKey
    let ingredientQualityLevel: IngredientQualityLevel
    let seasonMonths: [Int]
    let localizedNames: [String: String]
    let imageName: String?
    let nutrition: ProduceNutrition?
    let nutritionSource: String?
    let nutritionBasis: NutritionBasis?
    let nutritionReference: String?
    let nutritionMappingNote: String?
    let defaultUnit: RecipeQuantityUnit?
    let supportedUnits: [RecipeQuantityUnit]?
    let gramsPerUnit: [String: Double]?
    let mlPerUnit: [String: Double]?
    let gramsPerMl: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case ingredientQualityLevel
        case seasonMonths
        case localizedNames
        case imageName
        case nutrition
        case nutritionSource
        case nutritionBasis
        case nutritionReference
        case nutritionMappingNote
        case defaultUnit
        case supportedUnits
        case gramsPerUnit
        case mlPerUnit
        case gramsPerMl
    }

    init(
        id: String,
        category: ProduceCategoryKey,
        ingredientQualityLevel: IngredientQualityLevel,
        seasonMonths: [Int],
        localizedNames: [String: String],
        imageName: String?,
        nutrition: ProduceNutrition?,
        nutritionSource: String?,
        nutritionBasis: NutritionBasis?,
        nutritionReference: String?,
        nutritionMappingNote: String?,
        defaultUnit: RecipeQuantityUnit?,
        supportedUnits: [RecipeQuantityUnit]?,
        gramsPerUnit: [String: Double]?,
        mlPerUnit: [String: Double]?,
        gramsPerMl: Double?
    ) {
        self.id = id
        self.category = category
        self.ingredientQualityLevel = ingredientQualityLevel
        self.seasonMonths = seasonMonths
        self.localizedNames = localizedNames
        self.imageName = imageName
        self.nutrition = nutrition
        self.nutritionSource = nutritionSource
        self.nutritionBasis = nutritionBasis
        self.nutritionReference = nutritionReference
        self.nutritionMappingNote = nutritionMappingNote
        self.defaultUnit = defaultUnit
        self.supportedUnits = supportedUnits
        self.gramsPerUnit = gramsPerUnit
        self.mlPerUnit = mlPerUnit
        self.gramsPerMl = gramsPerMl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(ProduceCategoryKey.self, forKey: .category)
        ingredientQualityLevel = try container.decodeIfPresent(IngredientQualityLevel.self, forKey: .ingredientQualityLevel) ?? .core
        seasonMonths = try container.decode([Int].self, forKey: .seasonMonths)
        localizedNames = try container.decode([String: String].self, forKey: .localizedNames)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        nutrition = try container.decodeIfPresent(ProduceNutrition.self, forKey: .nutrition)
        nutritionSource = try container.decodeIfPresent(String.self, forKey: .nutritionSource)
        nutritionBasis = try container.decodeIfPresent(NutritionBasis.self, forKey: .nutritionBasis)
        nutritionReference = try container.decodeIfPresent(String.self, forKey: .nutritionReference)
        nutritionMappingNote = try container.decodeIfPresent(String.self, forKey: .nutritionMappingNote)
        defaultUnit = try container.decodeIfPresent(RecipeQuantityUnit.self, forKey: .defaultUnit)
        supportedUnits = try container.decodeIfPresent([RecipeQuantityUnit].self, forKey: .supportedUnits)
        gramsPerUnit = try container.decodeIfPresent([String: Double].self, forKey: .gramsPerUnit)
        mlPerUnit = try container.decodeIfPresent([String: Double].self, forKey: .mlPerUnit)
        gramsPerMl = try container.decodeIfPresent(Double.self, forKey: .gramsPerMl)
    }

    func displayName(languageCode: String) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? id
    }

    func isInSeason(month: Int) -> Bool {
        seasonalityScore(month: month) >= 0.55
    }

    func seasonalityLevel(month: Int) -> SeasonalityLevel {
        let score = seasonalityScore(month: month)
        if score >= 0.82 { return .peak }
        if score >= 0.55 { return .good }
        if score >= 0.22 { return .low }
        return .out
    }

    func seasonalityDelta(month: Int) -> Double {
        let clampedMonth = max(1, min(12, month))
        let previousMonth = clampedMonth == 1 ? 12 : (clampedMonth - 1)
        return seasonalityScore(month: clampedMonth) - seasonalityScore(month: previousMonth)
    }

    func seasonalityPhase(month: Int) -> SeasonalityPhase {
        let score = seasonalityScore(month: month)
        let delta = seasonalityDelta(month: month)
        return Self.seasonalityPhase(score: score, delta: delta)
    }

    static func seasonalityPhase(score: Double, delta: Double) -> SeasonalityPhase {
        let normalizedScore = min(1.0, max(0.0, score))
        if normalizedScore >= 0.70 {
            return .inSeason
        }
        if normalizedScore >= 0.32 {
            return delta >= 0 ? .earlySeason : .endingSoon
        }
        return .outOfSeason
    }

    func seasonalityScore(month: Int) -> Double {
        Self.seasonalityScore(for: seasonMonths, month: month)
    }

    static func seasonalityScore(for seasonMonths: [Int], month: Int) -> Double {
        let validSeasonMonths = Set(seasonMonths.filter { (1...12).contains($0) })
        guard !validSeasonMonths.isEmpty else { return 0 }

        let clampedMonth = max(1, min(12, month))
        let allMonths = Set(1...12)

        if validSeasonMonths.contains(clampedMonth) {
            let offSeasonMonths = allMonths.subtracting(validSeasonMonths)
            guard !offSeasonMonths.isEmpty else { return 1 }

            let edgeDistance = offSeasonMonths
                .map { circularMonthDistance(from: clampedMonth, to: $0) }
                .min() ?? 1

            // In-season values are strong, and improve toward the center of season windows.
            let centeredBoost = min(0.28, max(0, Double(edgeDistance - 1)) * 0.14)
            return min(1.0, 0.72 + centeredBoost)
        }

        let nearestSeasonDistance = validSeasonMonths
            .map { circularMonthDistance(from: clampedMonth, to: $0) }
            .min() ?? 6

        // Out-of-season values decay smoothly by month distance.
        let base = 0.42 * exp(-0.7 * Double(max(0, nearestSeasonDistance - 1)))
        return max(0.02, min(0.50, base))
    }

    private static func circularMonthDistance(from lhs: Int, to rhs: Int) -> Int {
        let direct = abs(lhs - rhs)
        return min(direct, 12 - direct)
    }
}
