import Foundation
import Combine

final class ProduceViewModel: ObservableObject {
    @Published private(set) var produceItems: [ProduceItem] = []
    @Published private(set) var languageCode: String

    var localizer: AppLocalizer {
        AppLocalizer(languageCode: languageCode)
    }

    init(languageCode: String = "en") {
        self.languageCode = AppLanguage(rawValue: languageCode)?.rawValue ?? AppLanguage.english.rawValue
        self.produceItems = ProduceStore.loadFromBundle()
    }

    @discardableResult
    func setLanguage(_ newCode: String) -> String {
        let resolved = AppLanguage(rawValue: newCode)?.rawValue ?? AppLanguage.english.rawValue
        if languageCode != resolved {
            languageCode = resolved
        }
        return resolved
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        return formatter.monthSymbols[currentMonth - 1]
    }

    func items(in category: ProduceCategoryKey, inSeason: Bool? = nil) -> [ProduceItem] {
        let filtered = produceItems.filter { item in
            guard item.category == category else { return false }
            guard let inSeason else { return true }
            return item.isInSeason(month: currentMonth) == inSeason
        }

        return filtered.sorted {
            $0.displayName(languageCode: localizer.languageCode)
                < $1.displayName(languageCode: localizer.languageCode)
        }
    }

    func searchResults(query: String) -> [ProduceItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [ProduceItem]
        if trimmedQuery.isEmpty {
            filtered = produceItems
        } else {
            filtered = produceItems.filter { item in
                item.displayName(languageCode: localizer.languageCode)
                    .localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        return filtered.sorted {
            $0.displayName(languageCode: localizer.languageCode)
                < $1.displayName(languageCode: localizer.languageCode)
        }
    }

    func monthNames(for months: [Int]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        return months
            .sorted()
            .compactMap { month in
                guard month >= 1, month <= 12 else { return nil }
                return formatter.shortMonthSymbols[month - 1]
            }
            .joined(separator: ", ")
    }
}
