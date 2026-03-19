import Foundation

enum RecipeExternalPlatform: String, Hashable {
    case instagram
    case tiktok
}

struct RecipeExternalMedia: Identifiable, Hashable {
    let id: String
    let platform: RecipeExternalPlatform
    let url: String
}

struct RecipeImage: Identifiable, Hashable {
    let id: String
    let localPath: String?
    let remoteURL: String?
}

struct UserProfile: Identifiable, Hashable {
    let id: String
    let name: String
}

enum RecipeDifficulty: String, Hashable {
    case easy
    case medium
    case hard
}

enum SocialSourcePlatform: String, Hashable {
    case tiktok
    case instagram
    case other
}

enum RecipeDietaryTag: String, Codable, CaseIterable, Hashable, Identifiable {
    case glutenFree
    case vegetarian
    case vegan

    var id: String { rawValue }
}

enum RecipeQuantityUnit: String, Codable, CaseIterable, Hashable, Identifiable {
    case g
    case ml
    case piece
    case clove
    case tbsp
    case tsp

    var id: String { rawValue }
}

enum RecipeIngredientMappingConfidence: String, Codable, Hashable {
    case high
    case medium
    case low
    case unmapped
}

struct RecipeIngredient: Identifiable, Hashable {
    var id: String {
        let base = produceID ?? basicIngredientID ?? name.lowercased()
        return "\(quality.rawValue)-\(base)-\(quantityValue)-\(quantityUnit.rawValue)"
    }
    let produceID: String?
    let basicIngredientID: String?
    let quality: RecipeIngredientQuality
    let name: String
    let quantityValue: Double
    let quantityUnit: RecipeQuantityUnit
    var rawIngredientLine: String? = nil
    var mappingConfidence: RecipeIngredientMappingConfidence = .high

    var quantity: String {
        let rounded = quantityValue.rounded()
        let valueText: String
        if abs(quantityValue - rounded) < 0.001 {
            valueText = "\(Int(rounded))"
        } else {
            valueText = String(format: "%.1f", quantityValue)
        }
        return "\(valueText) \(quantityUnit.rawValue)"
    }
}

enum RecipeSourceType: String, Hashable {
    case userGenerated = "user_generated"
    case seedWeb = "seed_web"
}

struct Recipe: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let ingredients: [RecipeIngredient]
    let preparationSteps: [String]
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let difficulty: RecipeDifficulty?
    var servings: Int = 2
    let crispy: Int
    let viewCount: Int = 0
    let dietaryTags: [RecipeDietaryTag]
    // Fixed at recipe creation time (0...100), not recalculated by current month.
    let seasonalMatchPercent: Int
    let createdAt: Date
    let externalMedia: [RecipeExternalMedia]
    let images: [RecipeImage]
    let coverImageID: String?
    let coverImageName: String?
    let mediaLinkURL: String?
    let sourceURL: String?
    var sourceName: String? = nil
    let sourcePlatform: SocialSourcePlatform?
    let sourceCaptionRaw: String?
    let importedFromSocial: Bool
    var sourceType: RecipeSourceType = .userGenerated
    var isUserGenerated: Bool = true
    var imageURL: String? = nil
    var imageSource: String? = nil
    var attributionText: String? = nil
    let isRemix: Bool
    let originalRecipeID: String?
    let originalRecipeTitle: String?
    let originalAuthorName: String?

    var coverImage: RecipeImage? {
        if let coverImageID,
           let selected = images.first(where: { $0.id == coverImageID }) {
            return selected
        }
        return images.first
    }
}

struct RankedRecipe: Identifiable {
    let recipe: Recipe
    let score: Double
    let seasonalMatchPercent: Int

    var id: String { recipe.id }
    var seasonalityScore: Double { Double(max(0, min(100, seasonalMatchPercent))) / 100.0 }
    var isInSeason: Bool { seasonalityScore >= 0.55 }
}
