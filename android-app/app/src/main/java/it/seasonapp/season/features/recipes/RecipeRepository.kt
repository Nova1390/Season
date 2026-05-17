package it.seasonapp.season.features.recipes

import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class RecipeRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchPublishedRecipes(limit: Int = 40): List<SeasonRecipe> {
        val safeLimit = limit.coerceIn(1, 100)
        val rows = client
            .from("recipes")
            .select {
                limit(safeLimit.toLong())
            }
            .decodeList<RecipeRow>()

        return rows
            .map { it.toDomain() }
            .sortedWith(compareByDescending<SeasonRecipe> { it.createdAt.orEmpty() }.thenByDescending { it.id })
    }
}

@Serializable
private data class RecipeRow(
    val id: String,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("creator_id") val creatorId: String? = null,
    @SerialName("creator_display_name") val creatorDisplayName: String? = null,
    @SerialName("title") val title: String? = null,
    @SerialName("ingredients") val ingredients: List<RecipeIngredientRow>? = null,
    @SerialName("steps") val steps: List<String>? = null,
    @SerialName("servings") val servings: Int? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("source_name") val sourceName: String? = null,
    @SerialName("source_type") val sourceType: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
) {
    fun toDomain(): SeasonRecipe {
        val cleanTitle = title.cleanOrNull() ?: "Ricetta senza titolo"
        val cleanSource = displaySourceName(sourceName.cleanOrNull())
        val creator = creatorDisplayName.cleanOrNull()
            ?: cleanSource
            ?: creatorId.cleanOrNull()
            ?: userId.cleanOrNull()
            ?: "Season"

        return SeasonRecipe(
            id = id,
            title = cleanTitle,
            creatorName = creator,
            sourceName = cleanSource,
            sourceType = sourceType.cleanOrNull(),
            imageUrl = imageUrl.cleanOrNull(),
            servings = (servings ?: 2).coerceAtLeast(1),
            ingredients = ingredients.orEmpty().map { it.toDomain() },
            steps = steps.orEmpty().mapNotNull { it.cleanOrNull() },
            createdAt = createdAt.cleanOrNull(),
        )
    }

    private fun displaySourceName(value: String?): String? {
        val normalized = value?.lowercase() ?: return null
        return when {
            "giallozafferano" in normalized || "giallo zafferano" in normalized -> "Giallo Zafferano"
            "themealdb" in normalized || "the meal db" in normalized -> "TheMealDB"
            else -> value
        }
    }
}

@Serializable
private data class RecipeIngredientRow(
    @SerialName("ingredient_id") val ingredientId: String? = null,
    @SerialName("produce_id") val produceId: String? = null,
    @SerialName("basic_ingredient_id") val basicIngredientId: String? = null,
    @SerialName("name") val name: String? = null,
    @SerialName("quantity_value") val quantityValue: Double? = null,
    @SerialName("quantity_unit") val quantityUnit: String? = null,
) {
    fun toDomain(): SeasonRecipeIngredient {
        return SeasonRecipeIngredient(
            name = name.cleanOrNull()
                ?: ingredientId.cleanOrNull()
                ?: produceId.cleanOrNull()
                ?: basicIngredientId.cleanOrNull()
                ?: "Ingrediente",
            quantityValue = quantityValue?.takeIf { it > 0 },
            quantityUnit = quantityUnit.cleanOrNull(),
        )
    }
}

private fun String?.cleanOrNull(): String? {
    val clean = this?.trim().orEmpty()
    return clean.takeIf { it.isNotEmpty() }
}
