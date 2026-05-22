package it.seasonapp.season.features.smartimport

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

data class SmartImportDraft(
    val title: String,
    val servings: Int,
    val ingredients: List<SmartImportIngredient>,
    val steps: List<String>,
    val confidence: String,
    val inferredDish: String?,
) {
    val hasCriticalMissingData: Boolean
        get() = ingredients.isEmpty() || steps.isEmpty() || title.isBlank()

    val qualityLabel: String
        get() = when (confidence.lowercase()) {
            "high" -> "Alta qualità"
            "medium" -> "Da controllare"
            else -> "Servono dettagli"
        }

    val publishBlockReason: String?
        get() = when {
            title.isBlank() -> "Manca il titolo."
            ingredients.isEmpty() -> "Mancano ingredienti strutturati."
            steps.isEmpty() -> "Mancano i passaggi di preparazione."
            else -> null
        }
}

data class SmartImportIngredient(
    val name: String,
    val quantity: Double?,
    val unit: String?,
    val status: String?,
    val matchType: String?,
    val matchedIngredientId: String?,
) {
    val quantityText: String?
        get() {
            val value = quantity ?: return unit
            val cleanUnit = unit?.takeIf { it.isNotBlank() }
            return if (cleanUnit == null) value.cleanFormat() else "${value.cleanFormat()} $cleanUnit"
        }
}

data class SmartImportUiState(
    val caption: String = "",
    val sourceUrl: String = "",
    val isLoading: Boolean = false,
    val draft: SmartImportDraft? = null,
    val errorMessage: String? = null,
)

@Serializable
data class ParseRecipeCaptionRequest(
    val caption: String? = null,
    val url: String? = null,
    val languageCode: String = "it",
)

@Serializable
data class ParseRecipeCaptionResponse(
    val ok: Boolean,
    val result: ParseRecipeCaptionResult? = null,
    val error: ParseRecipeCaptionError? = null,
)

@Serializable
data class ParseRecipeCaptionResult(
    val title: String? = null,
    val ingredients: List<ParseRecipeCaptionIngredient> = emptyList(),
    val steps: List<String> = emptyList(),
    val servings: Int? = null,
    val confidence: String = "low",
    val inferredDish: String? = null,
)

@Serializable
data class ParseRecipeCaptionIngredient(
    val name: String,
    val quantity: Double? = null,
    val unit: String? = null,
    val status: String? = null,
    val confidence: Double? = null,
    val matchType: String? = null,
    @SerialName("matchedIngredientId") val matchedIngredientId: String? = null,
)

@Serializable
data class ParseRecipeCaptionError(
    val code: String,
    val message: String,
)

fun ParseRecipeCaptionResult.toDraft(): SmartImportDraft {
    val normalizedIngredients = ingredients
        .mapNotNull { ingredient ->
            val name = ingredient.name.trim().takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            SmartImportIngredient(
                name = name,
                quantity = ingredient.quantity?.takeIf { it > 0 },
                unit = ingredient.unit?.trim()?.takeIf { it.isNotEmpty() },
                status = ingredient.status,
                matchType = ingredient.matchType,
                matchedIngredientId = ingredient.matchedIngredientId,
            )
        }
        .deduped()
    return SmartImportDraft(
        title = title?.trim()?.takeIf { it.isNotEmpty() } ?: inferredDish?.trim()?.takeIf { it.isNotEmpty() } ?: "Untitled recipe",
        servings = (servings ?: 2).coerceAtLeast(1),
        ingredients = normalizedIngredients,
        steps = steps.mapNotNull { it.trim().takeIf(String::isNotEmpty) },
        confidence = confidence,
        inferredDish = inferredDish?.trim()?.takeIf { it.isNotEmpty() },
    )
}

private fun List<SmartImportIngredient>.deduped(): List<SmartImportIngredient> {
    val byKey = linkedMapOf<String, SmartImportIngredient>()
    forEach { ingredient ->
        val key = listOf(
            ingredient.matchedIngredientId?.trim()?.lowercase().orEmpty(),
            ingredient.name.normalized(),
            ingredient.quantity?.cleanFormat().orEmpty(),
            ingredient.unit.normalized(),
        ).joinToString("|")
        val existing = byKey[key]
        if (existing == null || (existing.quantity == null && ingredient.quantity != null)) {
            byKey[key] = ingredient
        }
    }
    return byKey.values.toList()
}

private fun String?.normalized(): String = this?.trim()?.lowercase()?.replace(Regex("\\s+"), " ").orEmpty()

private fun Double.cleanFormat(): String {
    val rounded = toLong()
    return if (kotlin.math.abs(this - rounded.toDouble()) < 0.001) {
        rounded.toString()
    } else {
        "%.1f".format(this)
    }
}
