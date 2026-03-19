import Foundation

struct FridgeMatchedRecipe: Identifiable {
    let rankedRecipe: RankedRecipe
    let matchingCount: Int
    let totalCount: Int
    let availableIngredientWeight: Double
    let totalIngredientWeight: Double

    var id: String { rankedRecipe.id }
    var missingCount: Int { max(0, totalCount - matchingCount) }
    var fridgeMatchScore: Double {
        guard totalIngredientWeight > 0 else { return 0 }
        return min(1.0, max(0.0, availableIngredientWeight / totalIngredientWeight))
    }
    var matchRatio: Double {
        fridgeMatchScore
    }
}
