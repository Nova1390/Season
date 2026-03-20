import Foundation

enum RecipeIngredientQuality: String, Codable, Hashable {
    case coreSeasonal
    case basic
}

enum BasicIngredientCategory: String, Codable, Hashable {
    case proteins
    case dairy
    case carbs
    case legumes
    case pantry
    case herbsAromatics
    case condiments
}

struct BasicIngredientDietaryFlags: Codable, Hashable {
    let isGlutenFree: Bool?
    let isVegetarian: Bool?
    let isVegan: Bool?
}

struct IngredientUnitProfile: Codable, Hashable {
    let defaultUnit: RecipeQuantityUnit
    let supportedUnits: [RecipeQuantityUnit]
    let gramsPerUnit: [RecipeQuantityUnit: Double]
    let mlPerUnit: [RecipeQuantityUnit: Double]
    let gramsPerMl: Double?

    private enum CodingKeys: String, CodingKey {
        case defaultUnit
        case supportedUnits
        case gramsPerUnit
        case mlPerUnit
        case gramsPerMl
    }

    init(
        defaultUnit: RecipeQuantityUnit,
        supportedUnits: [RecipeQuantityUnit],
        gramsPerUnit: [RecipeQuantityUnit: Double],
        mlPerUnit: [RecipeQuantityUnit: Double],
        gramsPerMl: Double?
    ) {
        self.defaultUnit = defaultUnit
        self.supportedUnits = supportedUnits
        self.gramsPerUnit = gramsPerUnit
        self.mlPerUnit = mlPerUnit
        self.gramsPerMl = gramsPerMl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultUnit = try container.decode(RecipeQuantityUnit.self, forKey: .defaultUnit)
        supportedUnits = try container.decode([RecipeQuantityUnit].self, forKey: .supportedUnits)
        gramsPerUnit = try Self.decodeUnitMap(from: container, key: .gramsPerUnit)
        mlPerUnit = try Self.decodeUnitMap(from: container, key: .mlPerUnit)
        gramsPerMl = try container.decodeIfPresent(Double.self, forKey: .gramsPerMl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultUnit, forKey: .defaultUnit)
        try container.encode(supportedUnits, forKey: .supportedUnits)
        try container.encode(Self.encodeUnitMap(gramsPerUnit), forKey: .gramsPerUnit)
        try container.encode(Self.encodeUnitMap(mlPerUnit), forKey: .mlPerUnit)
        try container.encodeIfPresent(gramsPerMl, forKey: .gramsPerMl)
    }

    private static func decodeUnitMap(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> [RecipeQuantityUnit: Double] {
        if let byString = try container.decodeIfPresent([String: Double].self, forKey: key) {
            var resolved: [RecipeQuantityUnit: Double] = [:]
            for (rawUnit, value) in byString {
                guard let unit = RecipeQuantityUnit(rawValue: rawUnit) else { continue }
                resolved[unit] = value
            }
            return resolved
        }

        // Backward compatibility if older payloads were encoded with enum-key dictionaries.
        if let byEnum = try container.decodeIfPresent([RecipeQuantityUnit: Double].self, forKey: key) {
            return byEnum
        }

        return [:]
    }

    private static func encodeUnitMap(_ map: [RecipeQuantityUnit: Double]) -> [String: Double] {
        var encoded: [String: Double] = [:]
        for (unit, value) in map {
            encoded[unit.rawValue] = value
        }
        return encoded
    }
}

struct BasicIngredient: Identifiable, Codable, Hashable {
    let id: String
    let localizedNames: [String: String]
    let category: BasicIngredientCategory
    let ingredientQualityLevel: IngredientQualityLevel
    let nutrition: ProduceNutrition
    let nutritionSource: String
    let nutritionBasis: NutritionBasis
    let nutritionReference: String?
    let nutritionMappingNote: String?
    let nutritionMappingConfidence: NutritionMappingConfidence
    let unitProfile: IngredientUnitProfile
    let dietaryFlags: BasicIngredientDietaryFlags

    func displayName(languageCode: String) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? id
    }
}

struct RecipeNutritionSummary: Hashable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let vitaminC: Double
    let potassium: Double
}
