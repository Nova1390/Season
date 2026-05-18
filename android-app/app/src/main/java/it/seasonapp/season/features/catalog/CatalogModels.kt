package it.seasonapp.season.features.catalog

data class CatalogIngredient(
    val id: String,
    val slug: String,
    val type: String?,
    val italianName: String?,
    val italianShortName: String?,
    val englishName: String?,
    val englishShortName: String?,
    val isSeasonal: Boolean,
    val seasonMonths: List<Int>,
    val caloriesPer100g: Double?,
    val proteinPer100g: Double?,
) {
    val displayName: String
        get() = italianName?.takeIf { it.isNotBlank() }
            ?: italianShortName?.takeIf { it.isNotBlank() }
            ?: englishName?.takeIf { it.isNotBlank() }
            ?: slug.replace('_', ' ')

    val searchText: String
        get() = listOf(slug, italianName, italianShortName, englishName, englishShortName)
            .filterNotNull()
            .joinToString(" ")
            .lowercase()
}

enum class SeasonalPhase(val label: String) {
    Peak("Al meglio"),
    Early("Primizia"),
    Ending("Fine stagione"),
}

data class SeasonalIngredient(
    val ingredient: CatalogIngredient,
    val phase: SeasonalPhase,
    val score: Int,
)
