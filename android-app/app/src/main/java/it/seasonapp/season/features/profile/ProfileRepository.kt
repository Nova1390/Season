package it.seasonapp.season.features.profile

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import it.seasonapp.season.features.recipes.RecipeRepository
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class ProfileRepository(
    private val recipeRepository: RecipeRepository = RecipeRepository(),
) {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchDashboard(userId: String): ProfileDashboard {
        ensureFreshSession()
        val savedIds = client
            .from("user_recipe_states")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("is_saved", true)
                }
            }
            .decodeList<SavedRecipeStateRow>()
            .map { it.recipeId }
            .toSet()

        val recipes = recipeRepository.fetchPublishedRecipes(limit = 100)
        return ProfileDashboard(
            savedRecipes = recipes.filter { it.id in savedIds },
            publishedRecipes = recipes.filter { it.userId == userId },
        )
    }

    private suspend fun ensureFreshSession() {
        client.auth.awaitInitialization()
        checkNotNull(client.auth.currentSessionOrNull()) {
            "Authenticated session required for profile dashboard."
        }
        client.auth.refreshCurrentSession()
    }
}

@Serializable
private data class SavedRecipeStateRow(
    @SerialName("recipe_id") val recipeId: String,
)
