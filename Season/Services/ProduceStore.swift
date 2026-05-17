import Foundation

struct ProduceStore {
    static func loadFromBundle(fileName: String = "produce") -> [ProduceItem] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            SeasonLog.debug("Missing JSON file: \(fileName).json")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ProduceItem].self, from: data)
        } catch {
            SeasonLog.debug("Failed to load produce JSON: \(error)")
            return []
        }
    }
}
