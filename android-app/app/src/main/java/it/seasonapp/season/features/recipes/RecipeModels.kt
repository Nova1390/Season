package it.seasonapp.season.features.recipes

data class SeasonRecipe(
    val id: String,
    val title: String,
    val creatorName: String,
    val sourceName: String?,
    val sourceType: String?,
    val imageUrl: String?,
    val servings: Int,
    val ingredients: List<SeasonRecipeIngredient>,
    val steps: List<String>,
    val createdAt: String?,
) {
    val displaySource: String
        get() = sourceName?.takeIf { it.isNotBlank() } ?: creatorName

    val isExternal: Boolean
        get() = sourceType != null && sourceType != "user_generated"
}

data class SeasonRecipeIngredient(
    val name: String,
    val quantityValue: Double?,
    val quantityUnit: String?,
) {
    val quantityText: String?
        get() {
            val value = quantityValue ?: return null
            val unit = quantityUnit?.takeIf { it.isNotBlank() } ?: return formatNumber(value)
            return "${formatNumber(value)} $unit"
        }

    private fun formatNumber(value: Double): String {
        val rounded = value.toLong()
        return if (kotlin.math.abs(value - rounded.toDouble()) < 0.001) {
            rounded.toString()
        } else {
            "%.1f".format(value)
        }
    }
}
