package it.seasonapp.season.features.smartimport

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class SmartImportViewModel(
    private val repository: SmartImportRepository = SmartImportRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(SmartImportUiState())
    val uiState: StateFlow<SmartImportUiState> = _uiState

    fun updateCaption(value: String) {
        _uiState.update { it.copy(caption = value, errorMessage = null) }
    }

    fun updateSourceUrl(value: String) {
        _uiState.update { it.copy(sourceUrl = value, errorMessage = null) }
    }

    fun importDraft() {
        val state = _uiState.value
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                repository.parseCaption(caption = state.caption, sourceUrl = state.sourceUrl)
            }.onSuccess { draft ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        draft = draft,
                        errorMessage = null,
                    )
                }
            }.onFailure { error ->
                SeasonLog.warning("smart_import_failed ${error::class.simpleName}")
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Smart Import non riuscito.",
                    )
                }
            }
        }
    }
}
