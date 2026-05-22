package it.seasonapp.season.features.shopping

import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient

data class ShoppingItem(
    val id: String,
    val ingredientType: String,
    val ingredientId: String?,
    val customName: String?,
    val quantity: Double?,
    val unit: String?,
    val sourceRecipeId: String?,
    val isChecked: Boolean,
    val updatedAt: String?,
) {
    val isCustom: Boolean
        get() = ingredientType == "custom" || ingredientId.isNullOrBlank()

    val stableKey: String
        get() = listOf(
            if (isCustom) "custom:${customName.orEmpty().normalized()}" else "catalog:${ingredientId.orEmpty()}",
            quantity?.cleanFormat().orEmpty(),
            unit.orEmpty().normalized(),
            sourceRecipeId.orEmpty(),
        ).joinToString("|")
}

data class ShoppingItemUi(
    val item: ShoppingItem,
    val displayName: String,
    val label: String,
    val isPending: Boolean = false,
    val isFailed: Boolean = false,
) {
    val quantityText: String?
        get() {
            val quantity = item.quantity ?: return item.unit
            val unit = item.unit?.takeIf { it.isNotBlank() }
            return if (unit == null) quantity.cleanFormat() else "${quantity.cleanFormat()} $unit"
        }
}

enum class ShoppingOutboxAction {
    Add,
    Check,
    Delete,
    ;
}

data class ShoppingOutboxIntent(
    val action: ShoppingOutboxAction,
    val item: ShoppingItem,
    val targetChecked: Boolean? = null,
    val createdAtMillis: Long,
    val attemptCount: Int = 0,
    val lastErrorType: String? = null,
) {
    val mergeKey: String
        get() = when (action) {
            ShoppingOutboxAction.Check -> "check:${item.id}"
            ShoppingOutboxAction.Delete -> "delete:${item.id}"
            ShoppingOutboxAction.Add -> "add:${item.stableKey}"
        }
}

data class ShoppingUiState(
    val userId: String? = null,
    val items: List<ShoppingItemUi> = emptyList(),
    val catalogIngredients: List<CatalogIngredient> = emptyList(),
    val query: String = "",
    val customName: String = "",
    val quantity: String = "",
    val unit: String = "",
    val isLoading: Boolean = false,
    val isMutating: Boolean = false,
    val feedbackMessage: String? = null,
    val errorMessage: String? = null,
) {
    val uncheckedCount: Int
        get() = items.count { !it.item.isChecked }

    val filteredCatalogIngredients: List<CatalogIngredient>
        get() {
            val normalizedQuery = query.normalized()
            return catalogIngredients
                .asSequence()
                .filter { ingredient ->
                    normalizedQuery.isBlank() || ingredient.searchText.normalized().contains(normalizedQuery)
                }
                .take(12)
                .toList()
        }
}

data class ShoppingAddRequest(
    val ingredientType: String,
    val ingredientId: String?,
    val customName: String?,
    val displayName: String,
    val quantity: Double?,
    val unit: String?,
    val sourceRecipeId: String?,
)

data class ShoppingRecipeAddResult(
    val added: Int,
    val skipped: Int,
    val failed: Int,
) {
    val message: String
        get() = when {
            failed > 0 -> "$added ingredienti aggiunti, $skipped già presenti, $failed non aggiunti."
            added == 0 && skipped > 0 -> "Ingredienti già presenti nella lista."
            else -> "$added ingredienti aggiunti alla lista."
        }
}

fun SeasonRecipe.toShoppingRequests(): List<ShoppingAddRequest> {
    return ingredients.mapNotNull { ingredient ->
        ingredient.toShoppingRequest(sourceRecipeId = id)
    }
}

fun SeasonRecipeIngredient.toShoppingRequest(sourceRecipeId: String?): ShoppingAddRequest? {
    val cleanName = name.trim().takeIf { it.isNotEmpty() } ?: return null
    val cleanUnit = quantityUnit?.trim()?.takeIf { it.isNotEmpty() }
    val cleanIngredientId = ingredientId?.trim()?.takeIf { it.isNotEmpty() }
    return ShoppingAddRequest(
        ingredientType = if (cleanIngredientId == null) "custom" else "catalog",
        ingredientId = cleanIngredientId,
        customName = if (cleanIngredientId == null) cleanName else null,
        displayName = cleanName,
        quantity = quantityValue?.takeIf { it > 0 },
        unit = cleanUnit,
        sourceRecipeId = sourceRecipeId,
    )
}

internal fun String.normalized(): String {
    return trim()
        .lowercase()
        .replace(Regex("\\s+"), " ")
}

internal fun Double.cleanFormat(): String {
    val rounded = toLong()
    return if (kotlin.math.abs(this - rounded.toDouble()) < 0.001) {
        rounded.toString()
    } else {
        "%.1f".format(this)
    }
}
