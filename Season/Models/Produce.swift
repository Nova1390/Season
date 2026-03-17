import Foundation

enum ProduceCategoryKey: String, Codable, CaseIterable {
    case fruit
    case vegetable
    case tuber
}

struct ProduceItem: Identifiable, Codable, Hashable {
    let id: String
    let category: ProduceCategoryKey
    let seasonMonths: [Int]
    let localizedNames: [String: String]
    let imageName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case seasonMonths
        case localizedNames
        case imageName
    }

    init(
        id: String,
        category: ProduceCategoryKey,
        seasonMonths: [Int],
        localizedNames: [String: String],
        imageName: String?
    ) {
        self.id = id
        self.category = category
        self.seasonMonths = seasonMonths
        self.localizedNames = localizedNames
        self.imageName = imageName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(ProduceCategoryKey.self, forKey: .category)
        seasonMonths = try container.decode([Int].self, forKey: .seasonMonths)
        localizedNames = try container.decode([String: String].self, forKey: .localizedNames)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
    }

    func displayName(languageCode: String) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? id
    }

    func isInSeason(month: Int) -> Bool {
        seasonMonths.contains(month)
    }
}
