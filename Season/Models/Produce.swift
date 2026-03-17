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

    func displayName(languageCode: String) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? id
    }

    func isInSeason(month: Int) -> Bool {
        seasonMonths.contains(month)
    }
}
