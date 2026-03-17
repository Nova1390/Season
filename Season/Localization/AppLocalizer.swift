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
    case listTab
    case settingsTab
    case language
    case inSeasonNow
    case notInSeasonNow
    case inSeason
    case notInSeason
    case currentMonth
    case fruit
    case vegetables
    case tubers
    case category
    case seasonMonths
    case noResults
    case searchPlaceholder
    case addToList
    case alreadyInList
    case shoppingListEmpty
    case seasonalScore
    case itemsInSeasonFormat
    case searchEmptyTitle
    case searchEmptySubtitle
    case shoppingListEmptyTitle
    case shoppingListEmptySubtitle
    case seasonalStatus
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
            .listTab: "List",
            .settingsTab: "Settings",
            .language: "Language",
            .inSeasonNow: "In season now",
            .notInSeasonNow: "Not in season now",
            .inSeason: "In season",
            .notInSeason: "Not in season",
            .currentMonth: "Current month",
            .fruit: "Fruit",
            .vegetables: "Vegetables",
            .tubers: "Tubers",
            .category: "Category",
            .seasonMonths: "Season months",
            .noResults: "No results",
            .searchPlaceholder: "Search produce",
            .addToList: "Add to List",
            .alreadyInList: "Already in List",
            .shoppingListEmpty: "Your shopping list is empty.",
            .seasonalScore: "Seasonal Score",
            .itemsInSeasonFormat: "%d of %d items are currently in season",
            .searchEmptyTitle: "No matching produce",
            .searchEmptySubtitle: "Try a different name or browse seasonal categories on Home.",
            .shoppingListEmptyTitle: "Your list is empty",
            .shoppingListEmptySubtitle: "Add produce from Home or Search to start planning.",
            .seasonalStatus: "Seasonal status"
        ],
        "it": [
            .homeTab: "Home",
            .searchTab: "Cerca",
            .listTab: "Lista",
            .settingsTab: "Impostazioni",
            .language: "Lingua",
            .inSeasonNow: "Di stagione ora",
            .notInSeasonNow: "Fuori stagione ora",
            .inSeason: "Di stagione",
            .notInSeason: "Fuori stagione",
            .currentMonth: "Mese corrente",
            .fruit: "Frutta",
            .vegetables: "Verdure",
            .tubers: "Tuberi",
            .category: "Categoria",
            .seasonMonths: "Mesi di stagione",
            .noResults: "Nessun risultato",
            .searchPlaceholder: "Cerca prodotti",
            .addToList: "Aggiungi alla Lista",
            .alreadyInList: "Già in Lista",
            .shoppingListEmpty: "La tua lista della spesa è vuota.",
            .seasonalScore: "Punteggio Stagionale",
            .itemsInSeasonFormat: "%d di %d elementi sono attualmente di stagione",
            .searchEmptyTitle: "Nessun prodotto trovato",
            .searchEmptySubtitle: "Prova un nome diverso o guarda le categorie stagionali nella Home.",
            .shoppingListEmptyTitle: "La tua lista è vuota",
            .shoppingListEmptySubtitle: "Aggiungi prodotti da Home o Cerca per iniziare.",
            .seasonalStatus: "Stato stagionale"
        ]
    ]

    func itemsInSeasonText(inSeasonCount: Int, totalCount: Int) -> String {
        let format = text(.itemsInSeasonFormat)
        return String(format: format, inSeasonCount, totalCount)
    }
}
