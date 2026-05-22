package it.seasonapp.season.features.fridge

import it.seasonapp.season.features.catalog.CatalogIngredient

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
}

data class FridgeItemUi(
    val item: FridgeItem,
    val displayName: String,
    val label: String,
)

data class FridgeUiState(
    val userId: String? = null,
    val items: List<FridgeItemUi> = emptyList(),
    val catalogIngredients: List<CatalogIngredient> = emptyList(),
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

internal fun String.normalized(): String {
    return trim()
        .lowercase()
        .replace(Regex("\\s+"), " ")
}
