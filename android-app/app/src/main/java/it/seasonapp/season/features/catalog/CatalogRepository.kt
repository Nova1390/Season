package it.seasonapp.season.features.catalog

import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class CatalogRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchCatalogIngredients(limit: Int = 200): List<CatalogIngredient> {
        val safeLimit = limit.coerceIn(1, 500)
        return client
            .from("ingredient_catalog_app_summary")
            .select {
                limit(safeLimit.toLong())
            }
            .decodeList<CatalogIngredientRow>()
            .mapNotNull { it.toDomain() }
            .sortedWith(compareBy<CatalogIngredient> { it.displayName.lowercase() }.thenBy { it.id })
    }
}

@Serializable
private data class CatalogIngredientRow(
    @SerialName("ingredient_id") val ingredientId: String? = null,
    val slug: String? = null,
    @SerialName("ingredient_type") val ingredientType: String? = null,
    @SerialName("it_name") val italianName: String? = null,
    @SerialName("it_short_name") val italianShortName: String? = null,
    @SerialName("en_name") val englishName: String? = null,
    @SerialName("en_short_name") val englishShortName: String? = null,
    @SerialName("is_seasonal") val isSeasonal: Boolean? = null,
    @SerialName("season_months") val seasonMonths: List<Int>? = null,
    @SerialName("calories_per_100g") val caloriesPer100g: Double? = null,
    @SerialName("protein_per_100g") val proteinPer100g: Double? = null,
) {
    fun toDomain(): CatalogIngredient? {
        val id = ingredientId.cleanOrNull() ?: return null
        val cleanSlug = slug.cleanOrNull() ?: id
        return CatalogIngredient(
            id = id,
            slug = cleanSlug,
            type = ingredientType.cleanOrNull(),
            italianName = italianName.cleanOrNull(),
            italianShortName = italianShortName.cleanOrNull(),
            englishName = englishName.cleanOrNull(),
            englishShortName = englishShortName.cleanOrNull(),
            isSeasonal = isSeasonal == true,
            seasonMonths = seasonMonths.orEmpty()
                .filter { it in 1..12 }
                .distinct()
                .sorted(),
            caloriesPer100g = caloriesPer100g?.takeIf { it >= 0 },
            proteinPer100g = proteinPer100g?.takeIf { it >= 0 },
        )
    }
}

private fun String?.cleanOrNull(): String? {
    val clean = this?.trim().orEmpty()
    return clean.takeIf { it.isNotEmpty() }
}
