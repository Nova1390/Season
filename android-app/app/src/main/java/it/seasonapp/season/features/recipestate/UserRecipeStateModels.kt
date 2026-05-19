package it.seasonapp.season.features.recipestate

data class UserRecipeState(
    val recipeId: String,
    val isSaved: Boolean,
    val isCrispied: Boolean,
    val isArchived: Boolean,
    val updatedAt: String?,
) {
    companion object {
        fun empty(recipeId: String) = UserRecipeState(
            recipeId = recipeId,
            isSaved = false,
            isCrispied = false,
            isArchived = false,
            updatedAt = null,
        )
    }
}

data class UserRecipeStateUi(
    val recipeId: String,
    val isSaved: Boolean = false,
    val isCrispied: Boolean = false,
    val isPending: Boolean = false,
    val isFailed: Boolean = false,
) {
    companion object {
        fun empty(recipeId: String) = UserRecipeStateUi(recipeId = recipeId)
    }
}

enum class RecipeStateField(val remoteName: String) {
    Saved("is_saved"),
    Crispied("is_crispied"),
    ;
}

data class RecipeStateOutboxIntent(
    val recipeId: String,
    val stateField: RecipeStateField,
    val targetValue: Boolean,
    val createdAtMillis: Long,
    val attemptCount: Int = 0,
    val lastErrorType: String? = null,
) {
    val mergeKey: String
        get() = "$recipeId:${stateField.remoteName}"
}
