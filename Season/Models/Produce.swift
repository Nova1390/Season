import Foundation

enum ProduceCategoryKey: String, Codable, CaseIterable {
    case fruit
    case vegetable
    case tuber
}

enum NutritionGoal: String, CaseIterable, Identifiable {
    case moreProtein
    case moreFiber
    case moreVitaminC
    case lowerSugar

    var id: String { rawValue }
}

enum NutritionBasis: String, Codable, Hashable {
    case per100g = "per_100g"
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
    let seasonMonths: [Int]
    let localizedNames: [String: String]
    let imageName: String?
    let nutrition: ProduceNutrition?
    let nutritionSource: String?
    let nutritionBasis: NutritionBasis?
    let nutritionReference: String?
    let nutritionMappingNote: String?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case seasonMonths
        case localizedNames
        case imageName
        case nutrition
        case nutritionSource
        case nutritionBasis
        case nutritionReference
        case nutritionMappingNote
    }

    init(
        id: String,
        category: ProduceCategoryKey,
        seasonMonths: [Int],
        localizedNames: [String: String],
        imageName: String?,
        nutrition: ProduceNutrition?,
        nutritionSource: String?,
        nutritionBasis: NutritionBasis?,
        nutritionReference: String?,
        nutritionMappingNote: String?
    ) {
        self.id = id
        self.category = category
        self.seasonMonths = seasonMonths
        self.localizedNames = localizedNames
        self.imageName = imageName
        self.nutrition = nutrition
        self.nutritionSource = nutritionSource
        self.nutritionBasis = nutritionBasis
        self.nutritionReference = nutritionReference
        self.nutritionMappingNote = nutritionMappingNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(ProduceCategoryKey.self, forKey: .category)
        seasonMonths = try container.decode([Int].self, forKey: .seasonMonths)
        localizedNames = try container.decode([String: String].self, forKey: .localizedNames)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        nutrition = try container.decodeIfPresent(ProduceNutrition.self, forKey: .nutrition)
        nutritionSource = try container.decodeIfPresent(String.self, forKey: .nutritionSource)
        nutritionBasis = try container.decodeIfPresent(NutritionBasis.self, forKey: .nutritionBasis)
        nutritionReference = try container.decodeIfPresent(String.self, forKey: .nutritionReference)
        nutritionMappingNote = try container.decodeIfPresent(String.self, forKey: .nutritionMappingNote)
    }

    func displayName(languageCode: String) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? id
    }

    func isInSeason(month: Int) -> Bool {
        seasonMonths.contains(month)
    }
}
