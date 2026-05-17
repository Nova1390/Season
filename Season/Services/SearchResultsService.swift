import Foundation

enum SearchResultsService {
    struct RecipeRankingContext {
        let fridgeIngredientIDs: Set<String>
        let personalizationProfile: FeedPersonalizationProfile
        let crispyScore: (Recipe) -> Double
        let viewsScore: (Recipe) -> Double
        let fridgeMatchScore: (Recipe, Set<String>) -> Double
    }

    static func rankRecipes(
        _ baseResults: [RankedRecipe],
        context: RecipeRankingContext
    ) -> [RankedRecipe] {
        guard !baseResults.isEmpty else { return [] }

        let denominator = Double(max(1, baseResults.count - 1))
        return baseResults.enumerated()
            .map { index, ranked in
                let textScore = max(0.0, 1.0 - (Double(index) / denominator))
                let seasonalScore = Double(ranked.seasonalMatchPercent) / 100.0
                let popularityScore = (0.6 * context.crispyScore(ranked.recipe))
                    + (0.4 * context.viewsScore(ranked.recipe))
                let fridgeScore = context.fridgeIngredientIDs.isEmpty
                    ? 0.0
                    : context.fridgeMatchScore(ranked.recipe, context.fridgeIngredientIDs)
                let personalization = context.personalizationProfile
                    .evaluation(for: ranked, fridgeMatchScore: fridgeScore)
                    .adjustment

                // Text relevance stays dominant; the other signals only break ties gently.
                let score = (0.72 * textScore)
                    + (0.10 * seasonalScore)
                    + (0.10 * popularityScore)
                    + (0.06 * fridgeScore)
                    + (0.06 * personalization)
                return (ranked: ranked, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.ranked.recipe.title.localizedCaseInsensitiveCompare(rhs.ranked.recipe.title) == .orderedAscending
            }
            .map(\.ranked)
    }

    static func filterRecipes(
        _ recipes: [RankedRecipe],
        filter: SearchResultFilter?,
        fridgeIngredientIDs: Set<String>,
        fridgeMatchScore: (Recipe, Set<String>) -> Double
    ) -> [RankedRecipe] {
        guard let filter else { return recipes }

        switch filter {
        case .seasonal:
            return recipes.filter { $0.seasonalMatchPercent >= 80 }
        case .fridgeReady:
            guard !fridgeIngredientIDs.isEmpty else { return [] }
            return recipes.filter { fridgeMatchScore($0.recipe, fridgeIngredientIDs) >= 0.50 }
        }
    }

    static func filterIngredients(
        _ ingredients: [IngredientSearchResult],
        filter: SearchResultFilter?,
        currentMonth: Int,
        containsProduce: (ProduceItem) -> Bool,
        containsBasic: (BasicIngredient) -> Bool
    ) -> [IngredientSearchResult] {
        guard let filter else { return ingredients }

        switch filter {
        case .fridgeReady:
            return ingredients.filter { result in
                switch result.source {
                case .produce(let item):
                    return containsProduce(item)
                case .basic(let basic):
                    return containsBasic(basic)
                }
            }
        case .seasonal:
            return ingredients.filter { result in
                switch result.source {
                case .produce(let item):
                    return item.seasonalityScore(month: currentMonth) >= 0.22
                case .basic:
                    return false
                }
            }
        }
    }
}

enum SearchResultFilter {
    case fridgeReady
    case seasonal
}
