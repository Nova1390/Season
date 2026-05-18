package it.seasonapp.season.features.today

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import it.seasonapp.season.features.catalog.CatalogRepository
import it.seasonapp.season.features.catalog.SeasonalIngredient
import it.seasonapp.season.features.catalog.SeasonalPhase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

class TodayViewModel(
    private val catalogRepository: CatalogRepository = CatalogRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(TodayUiState())
    val uiState: StateFlow<TodayUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val currentMonth = LocalDate.now().monthValue
                val seasonal = catalogRepository.fetchCatalogIngredients(limit = 300)
                    .asSequence()
                    .filter { it.isSeasonal && it.seasonMonths.isNotEmpty() }
                    .mapNotNull { ingredient ->
                        val phase = seasonalPhase(ingredient.seasonMonths, currentMonth) ?: return@mapNotNull null
                        SeasonalIngredient(
                            ingredient = ingredient,
                            phase = phase,
                            score = seasonalScore(ingredient.seasonMonths, currentMonth, phase),
                        )
                    }
                    .sortedWith(
                        compareByDescending<SeasonalIngredient> { it.score }
                            .thenBy { it.ingredient.displayName.lowercase() },
                    )
                    .take(36)
                    .toList()

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        currentMonth = currentMonth,
                        ingredients = seasonal,
                    )
                }
            } catch (error: Throwable) {
                SeasonLog.warning("today_load_failed: ${error::class.simpleName}")
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "Stagionalità non disponibile. Riprova tra poco.",
                    )
                }
            }
        }
    }

    private fun seasonalPhase(months: List<Int>, currentMonth: Int): SeasonalPhase? {
        if (currentMonth !in months) return null
        val sorted = months.distinct().sorted()
        val index = sorted.indexOf(currentMonth)
        return when {
            sorted.size == 1 -> SeasonalPhase.Peak
            index == 0 -> SeasonalPhase.Early
            index == sorted.lastIndex -> SeasonalPhase.Ending
            else -> SeasonalPhase.Peak
        }
    }

    private fun seasonalScore(months: List<Int>, currentMonth: Int, phase: SeasonalPhase): Int {
        val durationPenalty = months.size * 2
        val phaseScore = when (phase) {
            SeasonalPhase.Peak -> 100
            SeasonalPhase.Early -> 88
            SeasonalPhase.Ending -> 76
        }
        val centerBonus = if (currentMonth == months.sorted().getOrNull(months.size / 2)) 8 else 0
        return phaseScore + centerBonus - durationPenalty
    }
}

data class TodayUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val currentMonth: Int = LocalDate.now().monthValue,
    val ingredients: List<SeasonalIngredient> = emptyList(),
)
