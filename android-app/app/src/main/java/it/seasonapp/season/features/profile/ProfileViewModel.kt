package it.seasonapp.season.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ProfileViewModel(
    private val repository: ProfileRepository = ProfileRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    private var userId: String? = null

    fun initialize(userId: String) {
        if (this.userId == userId && !_uiState.value.isLoading) return
        this.userId = userId
        refresh()
    }

    fun refresh() {
        val id = userId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                repository.fetchDashboard(id)
            }.onSuccess { dashboard ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        dashboard = dashboard,
                        errorMessage = null,
                    )
                }
            }.onFailure { error ->
                SeasonLog.warning("profile_dashboard_failed ${error::class.simpleName}")
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "Profilo non disponibile. Riprova tra poco.",
                    )
                }
            }
        }
    }
}
