import Foundation
import Combine

struct RankedInSeasonItem: Identifiable {
    let item: ProduceItem
    let score: Double
    let reasons: [String]

    var id: String { item.id }
}

final class ProduceViewModel: ObservableObject {
    @Published private(set) var produceItems: [ProduceItem] = []
    @Published private(set) var languageCode: String
    @Published private(set) var nutritionGoals: Set<NutritionGoal> = []
    private let nutritionGoalsStorageKey = "nutritionGoalsRaw"

    var localizer: AppLocalizer {
        AppLocalizer(languageCode: languageCode)
    }

    init(languageCode: String = "en") {
        self.languageCode = AppLanguage(rawValue: languageCode)?.rawValue ?? AppLanguage.english.rawValue
        self.produceItems = ProduceStore.loadFromBundle()
        self.nutritionGoals = Self.parseNutritionGoals(from: UserDefaults.standard.string(forKey: nutritionGoalsStorageKey) ?? "")
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

        return filtered.sorted(by: compareItems)
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

        return filtered.sorted(by: compareItems)
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

    func rankedInSeasonTodayItems() -> [RankedInSeasonItem] {
        let inSeasonItems = produceItems.filter { $0.isInSeason(month: currentMonth) }

        return inSeasonItems
            .map { item in
                let score = combinedRankingScore(for: item)
                let reasons = rankingReasons(for: item)
                return RankedInSeasonItem(item: item, score: score, reasons: reasons)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.item.displayName(languageCode: localizer.languageCode)
                    < rhs.item.displayName(languageCode: localizer.languageCode)
            }
    }

    @discardableResult
    func setNutritionGoalsRaw(_ rawValue: String) -> String {
        let goals = Self.parseNutritionGoals(from: rawValue)
        let normalized = Self.normalizedNutritionGoalsRaw(from: goals)
        if nutritionGoals != goals {
            nutritionGoals = goals
        }
        return normalized
    }

    private func compareItems(_ lhs: ProduceItem, _ rhs: ProduceItem) -> Bool {
        let leftScore = nutritionScore(for: lhs)
        let rightScore = nutritionScore(for: rhs)

        if leftScore != rightScore {
            return leftScore > rightScore
        }

        return lhs.displayName(languageCode: localizer.languageCode)
            < rhs.displayName(languageCode: localizer.languageCode)
    }

    private func combinedRankingScore(for item: ProduceItem) -> Double {
        seasonalityScore(for: item) + nutritionScore(for: item)
    }

    private func seasonalityScore(for item: ProduceItem) -> Double {
        let seasonWindow = max(1, item.seasonMonths.count)
        // Fewer in-season months means it's more seasonal right now.
        return (13.0 - Double(seasonWindow)) * 0.4
    }

    private func nutritionScore(for item: ProduceItem) -> Double {
        guard let nutrition = item.nutrition else { return 0 }

        var score = 0.0
        for goal in nutritionGoals {
            switch goal {
            case .moreProtein:
                score += nutrition.protein
            case .moreFiber:
                score += nutrition.fiber
            case .moreVitaminC:
                score += nutrition.vitaminC / 10.0
            case .lowerSugar:
                // Keep it simple for beginners: we use carbs as a rough proxy for sugars.
                score += max(0, 30.0 - nutrition.carbs) / 3.0
            }
        }
        return score
    }

    private func rankingReasons(for item: ProduceItem) -> [String] {
        guard let nutrition = item.nutrition else {
            return [localizer.text(.reasonInSeasonNow)]
        }

        var reasons: [String] = []

        if nutritionGoals.contains(.moreFiber), nutrition.fiber >= 2 {
            reasons.append(localizer.text(.reasonHighFiber))
        }

        if nutritionGoals.contains(.moreProtein), nutrition.protein >= 2 {
            reasons.append(localizer.text(.reasonHighProtein))
        }

        if nutritionGoals.contains(.moreVitaminC), nutrition.vitaminC >= 15 {
            reasons.append(localizer.text(.reasonHighVitaminC))
        }

        if reasons.isEmpty {
            reasons.append(localizer.text(.reasonInSeasonNow))
        }

        return Array(reasons.prefix(2))
    }

    private static func parseNutritionGoals(from raw: String) -> Set<NutritionGoal> {
        Set(
            raw.split(separator: ",")
                .compactMap { NutritionGoal(rawValue: String($0)) }
        )
    }

    private static func normalizedNutritionGoalsRaw(from goals: Set<NutritionGoal>) -> String {
        goals.map(\.rawValue).sorted().joined(separator: ",")
    }
}
