package it.seasonapp.season.features.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.CatalogRepository
import it.seasonapp.season.features.recipes.RecipeRepository
import it.seasonapp.season.features.recipes.SeasonRecipe
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class SearchViewModel(
    private val recipeRepository: RecipeRepository = RecipeRepository(),
    private val catalogRepository: CatalogRepository = CatalogRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    private var allRecipes: List<SeasonRecipe> = emptyList()
    private var allIngredients: List<CatalogIngredient> = emptyList()
    private val resultCache = mutableMapOf<String, SearchResults>()
    private var searchJob: Job? = null

    init {
        load()
    }

    fun updateQuery(value: String) {
        _uiState.update { it.copy(query = value) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300)
            applySearch(value)
        }
    }

    fun retry() {
        load()
    }

    private fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                allRecipes = recipeRepository.fetchPublishedRecipes(limit = 100)
                allIngredients = catalogRepository.fetchCatalogIngredients(limit = 250)
                resultCache.clear()
                _uiState.update { state ->
                    state.copy(
                        isLoading = false,
                        results = buildResults(state.query),
                    )
                }
            } catch (error: Throwable) {
                SeasonLog.warning("search_load_failed: ${error::class.simpleName}")
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "Ricerca non disponibile. Riprova tra poco.",
                    )
                }
            }
        }
    }

    private fun applySearch(rawQuery: String) {
        _uiState.update { it.copy(results = buildResults(rawQuery)) }
    }

    private fun buildResults(rawQuery: String): SearchResults {
        val query = rawQuery.normalized()
        if (query.isBlank()) {
            return SearchResults(
                recipes = allRecipes.take(12),
                ingredients = allIngredients.take(12),
            )
        }
        return resultCache.getOrPut(query) {
            SearchResults(
                recipes = allRecipes
                    .filter { recipe ->
                        recipe.title.normalized().contains(query) ||
                            recipe.displaySource.normalized().contains(query) ||
                            recipe.ingredients.any { it.name.normalized().contains(query) }
                    }
                    .take(20),
                ingredients = allIngredients
                    .filter { it.searchText.contains(query) }
                    .take(20),
            )
        }
    }
}

data class SearchUiState(
    val query: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val results: SearchResults = SearchResults(),
)

data class SearchResults(
    val recipes: List<SeasonRecipe> = emptyList(),
    val ingredients: List<CatalogIngredient> = emptyList(),
)

private fun String.normalized(): String {
    return trim().lowercase()
}
