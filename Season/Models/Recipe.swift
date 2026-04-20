import Foundation

enum RecipeExternalPlatform: String, Codable, Hashable {
    case instagram
    case tiktok
}

struct RecipeExternalMedia: Identifiable, Codable, Hashable {
    let id: String
    let platform: RecipeExternalPlatform
    let url: String
}

struct RecipeImage: Identifiable, Codable, Hashable {
    let id: String
    let localPath: String?
    let remoteURL: String?
}

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
}

enum RecipeDifficulty: String, Codable, Hashable {
    case easy
    case medium
    case hard
}

enum SocialSourcePlatform: String, Codable, Hashable {
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
    case slice
    case clove
    case tbsp
    case tsp
    case cup

    var id: String { rawValue }
}

enum RecipeIngredientMappingConfidence: String, Codable, Hashable {
    case high
    case medium
    case low
    case unmapped
}

struct RecipeIngredient: Identifiable, Codable, Hashable {
    var id: String {
        let base = ingredientID ?? produceID ?? basicIngredientID ?? name.lowercased()
        return "\(quality.rawValue)-\(base)-\(quantityValue)-\(quantityUnit.rawValue)"
    }
    let ingredientID: String?
    let produceID: String?
    let basicIngredientID: String?
    let quality: RecipeIngredientQuality
    let name: String
    let quantityValue: Double
    let quantityUnit: RecipeQuantityUnit
    var rawIngredientLine: String? = nil
    var mappingConfidence: RecipeIngredientMappingConfidence = .high

    nonisolated var hasCatalogIdentity: Bool {
        ingredientID != nil || produceID != nil || basicIngredientID != nil
    }

    init(
        ingredientID: String? = nil,
        produceID: String?,
        basicIngredientID: String?,
        quality: RecipeIngredientQuality,
        name: String,
        quantityValue: Double,
        quantityUnit: RecipeQuantityUnit,
        rawIngredientLine: String? = nil,
        mappingConfidence: RecipeIngredientMappingConfidence = .high
    ) {
        self.ingredientID = ingredientID
        self.produceID = produceID
        self.basicIngredientID = basicIngredientID
        self.quality = quality
        self.name = name
        self.quantityValue = quantityValue
        self.quantityUnit = quantityUnit
        self.rawIngredientLine = rawIngredientLine
        self.mappingConfidence = mappingConfidence
    }

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

enum RecipeSourceType: String, Codable, Hashable {
    case userGenerated = "user_generated"
    case seedWeb = "seed_web"
    case curatedImport = "curated_import"
}

enum RecipePublicationStatus: String, Codable, Hashable {
    case draft
    case published
}

enum RecipeCreatorIdentityState: Hashable {
    case canonicalUUID(String)
    case legacyUnmigrated(String)
    case unknown
}

struct Recipe: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    // Legacy compatibility name for older local data and author-based screens.
    // Canonical identity is creatorId + creatorDisplayName.
    let author: String
    // Canonical creator identity used by follow/profile/navigation logic.
    var creatorId: String = "unknown"
    // Canonical visible creator name when available from current domain model.
    var creatorDisplayName: String? = nil
    // Optional creator avatar URL for remote profile image rendering.
    // Keep nil-safe for backward compatibility with older local/remote data.
    var creatorAvatarURL: String? = nil
    let ingredients: [RecipeIngredient]
    let preparationSteps: [String]
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let difficulty: RecipeDifficulty?
    var servings: Int = 2
    let crispy: Int
    var viewCount: Int = 0
    let dietaryTags: [RecipeDietaryTag]
    // Fixed at recipe creation time (0...100), not recalculated by current month.
    let seasonalMatchPercent: Int
    let createdAt: Date
    let externalMedia: [RecipeExternalMedia]
    let images: [RecipeImage]
    let coverImageID: String?
    let coverImageName: String?
    let mediaLinkURL: String?
    var instagramURL: String? = nil
    var tiktokURL: String? = nil
    let sourceURL: String?
    var sourceName: String? = nil
    let sourcePlatform: SocialSourcePlatform?
    let sourceCaptionRaw: String?
    let importedFromSocial: Bool
    var sourceType: RecipeSourceType? = nil
    var isUserGenerated: Bool = true
    var imageURL: String? = nil
    var imageSource: String? = nil
    var attributionText: String? = nil
    var publicationStatus: RecipePublicationStatus = .published
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

    // Canonical creator id accessor for identity flows.
    // Returns nil for missing/legacy placeholder values.
    var canonicalCreatorID: String? {
        let cleaned = creatorId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Invalid creator ids are treated as unavailable identity.
        // This keeps follow/profile identity logic safe and explicit.
        guard !cleaned.isEmpty else { return nil }
        guard cleaned != "unknown" else { return nil }
        guard UUID(uuidString: cleaned) != nil else { return nil }
        return cleaned
    }

    // Helper to make creator identity handling explicit across UI/sync.
    var creatorIdentityState: RecipeCreatorIdentityState {
        if let canonicalCreatorID {
            return .canonicalUUID(canonicalCreatorID)
        }

        let raw = creatorId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.isEmpty || raw == "unknown" {
            return .unknown
        }
        return .legacyUnmigrated(raw)
    }

    var hasDisplayableCreatorIdentity: Bool {
        let display = displayCreatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !display.isEmpty && display.lowercased() != "unknown"
    }

    // Canonical display fallback for recipe UI:
    // creatorDisplayName -> author (legacy) -> "Unknown"
    var displayCreatorName: String {
        let trimmedCreatorDisplay = creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCreatorDisplay.isEmpty {
            return trimmedCreatorDisplay
        }

        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAuthor.isEmpty {
            return trimmedAuthor
        }

        return "Unknown"
    }

    // Product-quality gate for primary discovery surfaces (Home/Search/Following).
    // This intentionally does not delete or mutate recipes; it only controls feed eligibility.
    var isFeedEligible: Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedTitle.count >= 3 else { return false }

        let normalizedTitle = cleanedTitle.lowercased()
        let blockedSnippets = [
            "test",
            "debug",
            "placeholder",
            "tmp",
            "sample",
            "lorem",
            "untitled"
        ]
        guard !blockedSnippets.contains(where: { normalizedTitle.contains($0) }) else { return false }

        let creatorName = displayCreatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !creatorName.isEmpty else { return false }
        guard creatorName.lowercased() != "unknown" else { return false }

        let hasIngredients = !ingredients.isEmpty
        let hasSteps = preparationSteps.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard hasIngredients, hasSteps else { return false }

        // Visual viability for feed rows/hero surfaces.
        let hasCover = (coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || (imageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || images.contains {
                ($0.localPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    || ($0.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            }
        let hasRenderableFallback = !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasCover || hasRenderableFallback
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
