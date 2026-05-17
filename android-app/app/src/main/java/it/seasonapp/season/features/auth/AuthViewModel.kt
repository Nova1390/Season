package it.seasonapp.season.features.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCustomException
import androidx.credentials.exceptions.NoCredentialException
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import it.seasonapp.season.core.env.SeasonEnvironment
import it.seasonapp.season.core.logging.SeasonLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AuthViewModel(
    private val authRepository: AuthRepository = AuthRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow<AuthUiState>(AuthUiState.Loading)
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        restoreSession()
    }

    fun restoreSession() {
        if (!SeasonSupabaseClient.isConfigured) {
            _uiState.value = signedOutState(
                message = "Configura la anon key dev prima di collegarti a Supabase.",
            )
            return
        }

        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            runCatching {
                authRepository.restoreSession()
            }.onSuccess { user ->
                if (user == null) {
                    _uiState.value = signedOutState()
                } else {
                    completeProfileBootstrap(user)
                }
            }.onFailure { error ->
                SeasonLog.warning("auth_restore_failed ${error::class.simpleName}")
                _uiState.value = signedOutState(message = "Sessione non ripristinata. Accedi di nuovo.")
            }
        }
    }

    fun signInWithGoogle(context: Context) {
        if (!SeasonSupabaseClient.isConfigured) {
            _uiState.value = signedOutState("Configura la anon key dev prima del login.")
            return
        }
        if (!SeasonEnvironment.current.hasGoogleWebClientId) {
            _uiState.value = signedOutState("Configura SEASON_GOOGLE_WEB_CLIENT_ID per usare Google.")
            return
        }

        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            val googleClient = GoogleIdentityClient(CredentialManager.create(context))
            runCatching {
                val idToken = googleClient.requestIdToken(context)
                authRepository.signInWithGoogleIdToken(idToken)
            }.onSuccess { user ->
                completeProfileBootstrap(user)
            }.onFailure { error ->
                SeasonLog.warning("google_sign_in_failed ${error::class.simpleName}")
                _uiState.value = signedOutState(message = error.userSafeMessage("Accesso Google non riuscito."))
            }
        }
    }

    fun signInWithEmail(email: String, password: String) {
        runEmailAuth(email, password, isSignUp = false)
    }

    fun signUpWithEmail(email: String, password: String) {
        runEmailAuth(email, password, isSignUp = true)
    }

    fun saveUsername(username: String) {
        val state = _uiState.value as? AuthUiState.NeedsUsername ?: return
        viewModelScope.launch {
            _uiState.value = state.copy(isSaving = true, message = null)
            runCatching {
                authRepository.saveUsername(
                    userId = state.profile.id,
                    username = username,
                    displayName = state.profile.displayName,
                )
            }.onSuccess { profile ->
                _uiState.value = AuthUiState.SignedIn(profile)
            }.onFailure { error ->
                SeasonLog.warning("username_save_failed ${error::class.simpleName}")
                _uiState.value = state.copy(
                    isSaving = false,
                    message = error.userSafeMessage("Username non salvato."),
                )
            }
        }
    }

    fun signOut(context: Context) {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            runCatching {
                authRepository.signOut()
                GoogleIdentityClient(CredentialManager.create(context)).clearCredentialState()
            }.onFailure { error ->
                SeasonLog.warning("sign_out_failed ${error::class.simpleName}")
            }
            _uiState.value = signedOutState()
        }
    }

    private fun runEmailAuth(email: String, password: String, isSignUp: Boolean) {
        if (!SeasonSupabaseClient.isConfigured) {
            _uiState.value = signedOutState("Configura la anon key dev prima del login.")
            return
        }

        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            runCatching {
                if (isSignUp) {
                    authRepository.signUpWithEmail(email, password)
                } else {
                    authRepository.signInWithEmail(email, password)
                }
            }.onSuccess { user ->
                completeProfileBootstrap(user)
            }.onFailure { error ->
                SeasonLog.warning("email_auth_failed ${error::class.simpleName}")
                _uiState.value = signedOutState(
                    message = error.userSafeMessage(
                        if (isSignUp) "Registrazione non riuscita." else "Login non riuscito.",
                    ),
                )
            }
        }
    }

    private suspend fun completeProfileBootstrap(user: AuthenticatedUser) {
        runCatching {
            authRepository.bootstrapProfile(user)
        }.onSuccess { profile ->
            _uiState.value = if (profile.hasUsername) {
                AuthUiState.SignedIn(profile)
            } else {
                AuthUiState.NeedsUsername(profile)
            }
        }.onFailure { error ->
            SeasonLog.warning("profile_bootstrap_failed ${error::class.simpleName}")
            _uiState.value = signedOutState("Profilo non caricato. Riprova il login.")
        }
    }

    private fun signedOutState(message: String? = null): AuthUiState.SignedOut {
        val environment = SeasonEnvironment.current
        return AuthUiState.SignedOut(
            isBackendConfigured = SeasonSupabaseClient.isConfigured,
            isGoogleConfigured = environment.hasGoogleWebClientId,
            message = message,
        )
    }

    private fun Throwable.userSafeMessage(fallback: String): String {
        if (this is NoCredentialException) {
            return "Nessun account Google trovato sull'emulatore. Aggiungine uno da Settings > Passwords & accounts, oppure usa email/password."
        }
        if (this is GetCredentialCancellationException) {
            return "Accesso Google annullato."
        }
        if (this is GetCredentialCustomException) {
            return "Google non è configurato correttamente: in SEASON_GOOGLE_WEB_CLIENT_ID serve il client ID Web, non quello Android."
        }
        return message
            ?.takeIf { it.isNotBlank() && !it.contains("eyJ") && !it.contains("http") }
            ?: fallback
    }
}
