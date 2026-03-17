import Foundation

struct ProduceStore {
    static func loadFromBundle(fileName: String = "produce") -> [ProduceItem] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Missing JSON file: \(fileName).json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ProduceItem].self, from: data)
        } catch {
            print("Failed to load produce JSON: \(error)")
            return []
        }
    }
}
