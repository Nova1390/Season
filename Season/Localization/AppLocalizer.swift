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
    case todayTab
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
    case nutrition
    case calories
    case protein
    case carbs
    case fat
    case fiber
    case vitaminC
    case potassium
    case nutritionPreferences
    case nutritionPreferencesHint
    case goalMoreProtein
    case goalMoreFiber
    case goalMoreVitaminC
    case goalLowerSugar
    case inSeasonTodayTitle
    case rankingWhy
    case reasonHighFiber
    case reasonHighProtein
    case reasonHighVitaminC
    case reasonInSeasonNow
    case seasonalityChart
    case nutritionComparisonBasisNote
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

    func nutritionGoalTitle(_ goal: NutritionGoal) -> String {
        switch goal {
        case .moreProtein:
            return text(.goalMoreProtein)
        case .moreFiber:
            return text(.goalMoreFiber)
        case .moreVitaminC:
            return text(.goalMoreVitaminC)
        case .lowerSugar:
            return text(.goalLowerSugar)
        }
    }

    private static let strings: [String: [AppTextKey: String]] = [
        "en": [
            .homeTab: "Home",
            .searchTab: "Search",
            .todayTab: "Today",
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
            .seasonalStatus: "Seasonal status",
            .nutrition: "Nutrition (per 100 g)",
            .calories: "Calories",
            .protein: "Protein",
            .carbs: "Carbs",
            .fat: "Fat",
            .fiber: "Fiber",
            .vitaminC: "Vitamin C",
            .potassium: "Potassium",
            .nutritionPreferences: "Nutrition preferences",
            .nutritionPreferencesHint: "These are simple ranking preferences only.",
            .goalMoreProtein: "More protein",
            .goalMoreFiber: "More fiber",
            .goalMoreVitaminC: "More vitamin C",
            .goalLowerSugar: "Lower sugar",
            .inSeasonTodayTitle: "In Season Today",
            .rankingWhy: "Why it ranks well",
            .reasonHighFiber: "High fiber",
            .reasonHighProtein: "High protein",
            .reasonHighVitaminC: "High vitamin C",
            .reasonInSeasonNow: "In season now",
            .seasonalityChart: "Seasonality chart",
            .nutritionComparisonBasisNote: "Nutrition comparisons and ranking use values per 100 g."
        ],
        "it": [
            .homeTab: "Home",
            .searchTab: "Cerca",
            .todayTab: "Oggi",
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
            .seasonalStatus: "Stato stagionale",
            .nutrition: "Valori nutrizionali (per 100 g)",
            .calories: "Calorie",
            .protein: "Proteine",
            .carbs: "Carboidrati",
            .fat: "Grassi",
            .fiber: "Fibre",
            .vitaminC: "Vitamina C",
            .potassium: "Potassio",
            .nutritionPreferences: "Preferenze nutrizionali",
            .nutritionPreferencesHint: "Sono solo preferenze per ordinare i risultati.",
            .goalMoreProtein: "Più proteine",
            .goalMoreFiber: "Più fibre",
            .goalMoreVitaminC: "Più vitamina C",
            .goalLowerSugar: "Meno zuccheri",
            .inSeasonTodayTitle: "Di stagione oggi",
            .rankingWhy: "Perché è in alto",
            .reasonHighFiber: "Ricco di fibre",
            .reasonHighProtein: "Ricco di proteine",
            .reasonHighVitaminC: "Ricco di vitamina C",
            .reasonInSeasonNow: "Attualmente di stagione",
            .seasonalityChart: "Grafico stagionalita",
            .nutritionComparisonBasisNote: "Confronti e ranking nutrizionali usano valori per 100 g."
        ]
    ]

    func itemsInSeasonText(inSeasonCount: Int, totalCount: Int) -> String {
        let format = text(.itemsInSeasonFormat)
        return String(format: format, inSeasonCount, totalCount)
    }
}
