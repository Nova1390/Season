import Foundation

enum RecipeIngredientQuality: String, Codable, Hashable {
    case coreSeasonal
    case basic
}

enum BasicIngredientCategory: String, Hashable {
    case proteins
    case dairy
    case carbs
    case legumes
    case pantry
    case herbsAromatics
    case condiments
}

struct BasicIngredientDietaryFlags: Hashable {
    let isGlutenFree: Bool?
    let isVegetarian: Bool?
    let isVegan: Bool?
}

struct IngredientUnitProfile: Hashable {
    let defaultUnit: RecipeQuantityUnit
    let supportedUnits: [RecipeQuantityUnit]
    let gramsPerUnit: [RecipeQuantityUnit: Double]
    let mlPerUnit: [RecipeQuantityUnit: Double]
    let gramsPerMl: Double?
}

struct BasicIngredient: Identifiable, Hashable {
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
