package it.seasonapp.season.features.recipestate

import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

class UserRecipeStateRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchRecipeState(userId: String, recipeId: String): UserRecipeState {
        val rows = client
            .from("user_recipe_states")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("recipe_id", recipeId)
                }
                limit(1)
            }
            .decodeList<UserRecipeStateRow>()

        return rows.firstOrNull()?.toDomain() ?: UserRecipeState.empty(recipeId)
    }

    suspend fun applyIntent(userId: String, intent: RecipeStateOutboxIntent): UserRecipeState {
        val current = fetchRecipeState(userId = userId, recipeId = intent.recipeId)
        val next = when (intent.stateField) {
            RecipeStateField.Saved -> current.copy(isSaved = intent.targetValue)
            RecipeStateField.Crispied -> current.copy(isCrispied = intent.targetValue)
        }

        val payload = UserRecipeStateUpsertPayload(
            userId = userId,
            recipeId = intent.recipeId,
            isSaved = next.isSaved,
            isCrispied = next.isCrispied,
            isArchived = next.isArchived,
            updatedAt = Instant.now().toString(),
        )

        client
            .from("user_recipe_states")
            .upsert(payload) {
                onConflict = "user_id,recipe_id"
            }

        return fetchRecipeState(userId = userId, recipeId = intent.recipeId)
    }
}

@Serializable
private data class UserRecipeStateRow(
    @SerialName("recipe_id") val recipeId: String,
    @SerialName("is_saved") val isSaved: Boolean = false,
    @SerialName("is_crispied") val isCrispied: Boolean = false,
    @SerialName("is_archived") val isArchived: Boolean = false,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    fun toDomain() = UserRecipeState(
        recipeId = recipeId,
        isSaved = isSaved,
        isCrispied = isCrispied,
        isArchived = isArchived,
        updatedAt = updatedAt,
    )
}

@Serializable
private data class UserRecipeStateUpsertPayload(
    @SerialName("user_id") val userId: String,
    @SerialName("recipe_id") val recipeId: String,
    @SerialName("is_saved") val isSaved: Boolean,
    @SerialName("is_crispied") val isCrispied: Boolean,
    @SerialName("is_archived") val isArchived: Boolean,
    @SerialName("updated_at") val updatedAt: String,
)
