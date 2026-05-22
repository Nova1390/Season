package it.seasonapp.season.features.fridge

import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient

data class FridgeItem(
    val id: String,
    val ingredientType: String,
    val ingredientId: String?,
    val customName: String?,
    val quantity: Double?,
    val unit: String?,
    val updatedAt: String?,
) {
    val isCustom: Boolean
        get() = ingredientType == "custom" || ingredientId.isNullOrBlank()

    val stableKey: String
        get() = if (isCustom) {
            "custom:${customName.orEmpty().normalized()}"
        } else {
            "catalog:${ingredientId.orEmpty()}"
        }
}

data class FridgeItemUi(
    val item: FridgeItem,
    val displayName: String,
    val label: String,
    val isPending: Boolean = false,
    val isFailed: Boolean = false,
)

enum class FridgeOutboxAction {
    Add,
    Delete,
    ;
}

data class FridgeOutboxIntent(
    val action: FridgeOutboxAction,
    val item: FridgeItem,
    val createdAtMillis: Long,
    val attemptCount: Int = 0,
    val lastErrorType: String? = null,
) {
    val mergeKey: String
        get() = "${action.name}:${item.stableKey}"
}

data class FridgeUiState(
    val userId: String? = null,
    val items: List<FridgeItemUi> = emptyList(),
    val catalogIngredients: List<CatalogIngredient> = emptyList(),
    val recipeGroups: FridgeRecipeGroups = FridgeRecipeGroups(),
    val query: String = "",
    val customName: String = "",
    val isLoading: Boolean = false,
    val isMutating: Boolean = false,
    val errorMessage: String? = null,
) {
    val filteredCatalogIngredients: List<CatalogIngredient>
        get() {
            val normalizedQuery = query.normalized()
            val existingIngredientIds = items.mapNotNull { it.item.ingredientId }.toSet()
            return catalogIngredients
                .asSequence()
                .filterNot { it.id in existingIngredientIds }
                .filter { ingredient ->
                    normalizedQuery.isBlank() || ingredient.searchText.normalized().contains(normalizedQuery)
                }
                .take(12)
                .toList()
        }
}

data class FridgeRecipeGroups(
    val ready: List<FridgeRecipeMatch> = emptyList(),
    val missingFew: List<FridgeRecipeMatch> = emptyList(),
    val almostReady: List<FridgeRecipeMatch> = emptyList(),
) {
    val total: Int
        get() = ready.size + missingFew.size + almostReady.size
}

data class FridgeRecipeMatch(
    val recipe: SeasonRecipe,
    val missingIngredients: List<SeasonRecipeIngredient>,
    val matchedCount: Int,
    val totalCount: Int,
) {
    val missingCount: Int
        get() = missingIngredients.size

    val progressLabel: String
        get() = "$matchedCount/$totalCount ingredienti"
}

internal fun String.normalized(): String {
    return trim()
        .lowercase()
        .replace(Regex("\\s+"), " ")
}
