package it.seasonapp.season.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import it.seasonapp.season.core.logging.SeasonLog
import it.seasonapp.season.features.recipes.RecipeRepository
import it.seasonapp.season.features.recipes.SeasonRecipe
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class HomeViewModel(
    private val recipeRepository: RecipeRepository = RecipeRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow<HomeUiState>(HomeUiState.Loading)
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        if (!SeasonSupabaseClient.isConfigured) {
            _uiState.value = HomeUiState.Error("Configura Supabase dev prima di caricare la Home.")
            return
        }

        viewModelScope.launch {
            _uiState.value = HomeUiState.Loading
            runCatching {
                recipeRepository.fetchPublishedRecipes(limit = 48)
            }.onSuccess { recipes ->
                _uiState.value = HomeUiState.Content(HomeSnapshot.from(recipes))
            }.onFailure { error ->
                SeasonLog.warning("home_recipes_fetch_failed ${error::class.simpleName}")
                _uiState.value = HomeUiState.Error("Non riesco a caricare le ricette Supabase. Riprova tra poco.")
            }
        }
    }
}

sealed interface HomeUiState {
    data object Loading : HomeUiState
    data class Error(val message: String) : HomeUiState
    data class Content(val snapshot: HomeSnapshot) : HomeUiState
}

data class HomeSnapshot(
    val hero: SeasonRecipe?,
    val recommended: List<SeasonRecipe>,
    val totalCount: Int,
    val externalCount: Int,
) {
    companion object {
        fun from(recipes: List<SeasonRecipe>): HomeSnapshot {
            val presentable = recipes
                .filter { it.title.isNotBlank() }
                .distinctBy { it.id }

            val hero = presentable.firstOrNull { it.imageUrl != null } ?: presentable.firstOrNull()
            val recommended = presentable
                .filterNot { it.id == hero?.id }
                .take(8)

            return HomeSnapshot(
                hero = hero,
                recommended = recommended,
                totalCount = presentable.size,
                externalCount = presentable.count { it.isExternal },
            )
        }
    }
}
