package it.seasonapp.season.features.profile

import it.seasonapp.season.features.recipes.SeasonRecipe

data class ProfileDashboard(
    val savedRecipes: List<SeasonRecipe> = emptyList(),
    val publishedRecipes: List<SeasonRecipe> = emptyList(),
)

data class ProfileUiState(
    val isLoading: Boolean = false,
    val dashboard: ProfileDashboard = ProfileDashboard(),
    val errorMessage: String? = null,
)
