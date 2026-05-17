package it.seasonapp.season.features.auth

data class SeasonProfile(
    val id: String,
    val displayName: String?,
    val username: String?,
    val avatarUrl: String?,
    val preferredLanguage: String?,
) {
    val hasUsername: Boolean
        get() = !username.isNullOrBlank()
}

sealed interface AuthUiState {
    data object Loading : AuthUiState
    data class SignedOut(
        val isBackendConfigured: Boolean,
        val isGoogleConfigured: Boolean,
        val message: String? = null,
    ) : AuthUiState

    data class NeedsUsername(
        val profile: SeasonProfile,
        val isSaving: Boolean = false,
        val message: String? = null,
    ) : AuthUiState

    data class SignedIn(
        val profile: SeasonProfile,
    ) : AuthUiState
}
