package it.seasonapp.season.features.recipestate

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class UserRecipeStateViewModel(
    application: Application,
    private val repository: UserRecipeStateRepository = UserRecipeStateRepository(),
) : AndroidViewModel(application) {
    constructor(application: Application) : this(application, UserRecipeStateRepository())

    private val outboxStore = RecipeStateOutboxStore(application)
    private val _uiState = MutableStateFlow(UserRecipeStatesUiState())
    val uiState: StateFlow<UserRecipeStatesUiState> = _uiState.asStateFlow()

    private var userId: String? = null

    fun initialize(userId: String) {
        if (this.userId == userId) return
        this.userId = userId
        applyPendingIntentsToUi(outboxStore.load(userId))
        flushPendingRecipeStateMutations()
    }

    fun observeRecipeState(recipeId: String): StateFlow<UserRecipeStateUi> {
        return uiState
            .map { it.states[recipeId] ?: UserRecipeStateUi.empty(recipeId) }
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
                initialValue = _uiState.value.states[recipeId] ?: UserRecipeStateUi.empty(recipeId),
            )
    }

    fun ensureLoaded(recipeId: String) {
        val currentUser = userId ?: return
        viewModelScope.launch {
            runCatching {
                repository.fetchRecipeState(userId = currentUser, recipeId = recipeId)
            }.onSuccess { remoteState ->
                mergeRemoteState(remoteState)
                applyPendingIntentsToUi(outboxStore.load(currentUser).filter { it.recipeId == recipeId })
            }.onFailure { error ->
                SeasonLog.warning("recipe_state_fetch_failed ${error::class.simpleName}")
            }
        }
    }

    fun toggleSaved(recipeId: String) {
        enqueueToggle(recipeId = recipeId, field = RecipeStateField.Saved)
    }

    fun toggleCrispy(recipeId: String) {
        enqueueToggle(recipeId = recipeId, field = RecipeStateField.Crispied)
    }

    fun flushPendingRecipeStateMutations() {
        val currentUser = userId ?: return
        viewModelScope.launch {
            val pending = outboxStore.load(currentUser)
            if (pending.isEmpty()) return@launch

            val remaining = mutableListOf<RecipeStateOutboxIntent>()
            pending.forEach { intent ->
                runCatching {
                    repository.applyIntent(userId = currentUser, intent = intent)
                }.onSuccess { remoteState ->
                    mergeRemoteState(remoteState)
                }.onFailure { error ->
                    SeasonLog.warning("recipe_state_sync_failed ${error::class.simpleName}")
                    remaining += intent.copy(
                        attemptCount = intent.attemptCount + 1,
                        lastErrorType = error::class.simpleName,
                    )
                }
            }

            outboxStore.replace(currentUser, remaining)
            applyPendingIntentsToUi(remaining)
        }
    }

    fun clearLocalRecipeStateOnLogout() {
        userId?.let { outboxStore.clear(it) }
        userId = null
        _uiState.value = UserRecipeStatesUiState()
    }

    private fun enqueueToggle(recipeId: String, field: RecipeStateField) {
        val currentUser = userId ?: return
        val current = _uiState.value.states[recipeId] ?: UserRecipeStateUi.empty(recipeId)
        val targetValue = when (field) {
            RecipeStateField.Saved -> !current.isSaved
            RecipeStateField.Crispied -> !current.isCrispied
        }
        val intent = RecipeStateOutboxIntent(
            recipeId = recipeId,
            stateField = field,
            targetValue = targetValue,
            createdAtMillis = System.currentTimeMillis(),
        )

        outboxStore.upsert(currentUser, intent)
        applyPendingIntentsToUi(listOf(intent))
        flushPendingRecipeStateMutations()
    }

    private fun mergeRemoteState(remoteState: UserRecipeState) {
        _uiState.update { state ->
            val previous = state.states[remoteState.recipeId] ?: UserRecipeStateUi.empty(remoteState.recipeId)
            state.copy(
                states = state.states + (
                    remoteState.recipeId to previous.copy(
                        isSaved = remoteState.isSaved,
                        isCrispied = remoteState.isCrispied,
                        isPending = false,
                        isFailed = false,
                    )
                ),
            )
        }
    }

    private fun applyPendingIntentsToUi(intents: List<RecipeStateOutboxIntent>) {
        if (intents.isEmpty()) return
        _uiState.update { state ->
            val mutable = state.states.toMutableMap()
            intents.forEach { intent ->
                val previous = mutable[intent.recipeId] ?: UserRecipeStateUi.empty(intent.recipeId)
                mutable[intent.recipeId] = when (intent.stateField) {
                    RecipeStateField.Saved -> previous.copy(
                        isSaved = intent.targetValue,
                        isPending = true,
                        isFailed = intent.attemptCount >= FAILED_ATTEMPT_THRESHOLD,
                    )
                    RecipeStateField.Crispied -> previous.copy(
                        isCrispied = intent.targetValue,
                        isPending = true,
                        isFailed = intent.attemptCount >= FAILED_ATTEMPT_THRESHOLD,
                    )
                }
            }
            state.copy(states = mutable)
        }
    }

    companion object {
        private const val FAILED_ATTEMPT_THRESHOLD = 3
    }
}

data class UserRecipeStatesUiState(
    val states: Map<String, UserRecipeStateUi> = emptyMap(),
)
