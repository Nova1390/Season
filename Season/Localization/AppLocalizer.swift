import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case italian = "it"

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        }
    }
}

enum AppTextKey: String {
    case homeTab
    case searchTab
    case settingsTab
    case language
    case inSeasonNow
    case notInSeasonNow
    case currentMonth
    case fruit
    case vegetables
    case tubers
    case category
    case seasonMonths
    case noResults
    case searchPlaceholder
}

struct AppLocalizer {
    let languageCode: String

    func text(_ key: AppTextKey) -> String {
        AppLocalizer.strings[languageCode]?[key]
        ?? AppLocalizer.strings["en"]?[key]
        ?? key.rawValue
    }

    func categoryTitle(for category: ProduceCategoryKey) -> String {
        switch category {
        case .fruit:
            return text(.fruit)
        case .vegetable:
            return text(.vegetables)
        case .tuber:
            return text(.tubers)
        }
    }

    private static let strings: [String: [AppTextKey: String]] = [
        "en": [
            .homeTab: "Home",
            .searchTab: "Search",
            .settingsTab: "Settings",
            .language: "Language",
            .inSeasonNow: "In season now",
            .notInSeasonNow: "Not in season now",
            .currentMonth: "Current month",
            .fruit: "Fruit",
            .vegetables: "Vegetables",
            .tubers: "Tubers",
            .category: "Category",
            .seasonMonths: "Season months",
            .noResults: "No results",
            .searchPlaceholder: "Search produce"
        ],
        "it": [
            .homeTab: "Home",
            .searchTab: "Cerca",
            .settingsTab: "Impostazioni",
            .language: "Lingua",
            .inSeasonNow: "Di stagione ora",
            .notInSeasonNow: "Fuori stagione ora",
            .currentMonth: "Mese corrente",
            .fruit: "Frutta",
            .vegetables: "Verdure",
            .tubers: "Tuberi",
            .category: "Categoria",
            .seasonMonths: "Mesi di stagione",
            .noResults: "Nessun risultato",
            .searchPlaceholder: "Cerca prodotti"
        ]
    ]
}
