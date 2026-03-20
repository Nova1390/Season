import Foundation

enum BasicIngredientCatalog {
    static let all: [BasicIngredient] = loadFromBundle()

    static func loadFromBundle(fileName: String = "basic_ingredients") -> [BasicIngredient] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Missing JSON file: \(fileName).json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([BasicIngredient].self, from: data)
        } catch {
            print("Failed to load basic ingredient JSON: \(error)")
            return []
        }
    }
}
