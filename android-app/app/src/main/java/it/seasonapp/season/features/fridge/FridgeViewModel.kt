package it.seasonapp.season.features.fridge

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.CatalogRepository
import it.seasonapp.season.features.recipes.RecipeRepository
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

class FridgeViewModel(
    application: Application,
    private val fridgeRepository: FridgeRepository = FridgeRepository(),
    private val catalogRepository: CatalogRepository = CatalogRepository(),
    private val recipeRepository: RecipeRepository = RecipeRepository(),
) : AndroidViewModel(application) {
    constructor(application: Application) : this(
        application = application,
        fridgeRepository = FridgeRepository(),
        catalogRepository = CatalogRepository(),
        recipeRepository = RecipeRepository(),
    )

    private val outboxStore = FridgeOutboxStore(application)
    private val _uiState = MutableStateFlow(FridgeUiState())
    val uiState: StateFlow<FridgeUiState> = _uiState

    fun initialize(userId: String) {
        if (_uiState.value.userId == userId && _uiState.value.catalogIngredients.isNotEmpty()) {
            return
        }
        _uiState.update { it.copy(userId = userId) }
        applyPendingIntentsToUi(outboxStore.load(userId))
        refresh()
        flushPendingFridgeMutations()
    }

    fun refresh() {
        val userId = _uiState.value.userId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val catalog = catalogRepository.fetchCatalogIngredients(limit = 500)
                val items = fridgeRepository.fetchItems(userId)
                val recipes = recipeRepository.fetchPublishedRecipes(limit = 80)
                val stateItems = buildStateItems(items = items, catalog = catalog)
                Triple(catalog, stateItems, buildRecipeGroups(recipes = recipes, fridgeItems = stateItems))
            }.onSuccess { (catalog, items, recipeGroups) ->
                _uiState.update {
                    val withRemote = it.copy(
                        catalogIngredients = catalog,
                        items = items,
                        recipeGroups = recipeGroups,
                        isLoading = false,
                        errorMessage = null,
                    )
                    withRemote.copy(items = applyPendingIntentsToItems(withRemote.items, outboxStore.load(userId)))
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Non riesco a caricare il frigo.",
                    )
                }
            }
        }
    }

    fun updateQuery(query: String) {
        _uiState.update { it.copy(query = query) }
    }

    fun updateCustomName(customName: String) {
        _uiState.update { it.copy(customName = customName) }
    }

    fun addCatalogIngredient(ingredient: CatalogIngredient) {
        val userId = _uiState.value.userId ?: return
        val item = FridgeItem(
            id = UUID.randomUUID().toString(),
            ingredientType = "catalog",
            ingredientId = ingredient.id,
            customName = null,
            quantity = null,
            unit = null,
            updatedAt = null,
        )
        enqueueIntent(
            userId = userId,
            intent = FridgeOutboxIntent(
                action = FridgeOutboxAction.Add,
                item = item,
                createdAtMillis = System.currentTimeMillis(),
            ),
            clearQuery = true,
        )
    }

    fun addCustomIngredient() {
        val userId = _uiState.value.userId ?: return
        val customName = _uiState.value.customName.trim()
        if (customName.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Inserisci un nome ingrediente.") }
            return
        }
        val alreadyExists = _uiState.value.items.any {
            it.displayName.normalized() == customName.normalized()
        }
        if (alreadyExists) {
            _uiState.update { it.copy(errorMessage = "Ingrediente già presente nel frigo.") }
            return
        }
        val item = FridgeItem(
            id = UUID.randomUUID().toString(),
            ingredientType = "custom",
            ingredientId = null,
            customName = customName,
            quantity = null,
            unit = null,
            updatedAt = null,
        )
        enqueueIntent(
            userId = userId,
            intent = FridgeOutboxIntent(
                action = FridgeOutboxAction.Add,
                item = item,
                createdAtMillis = System.currentTimeMillis(),
            ),
            clearCustomName = true,
        )
    }

    fun removeItem(item: FridgeItemUi) {
        val userId = _uiState.value.userId ?: return
        enqueueIntent(
            userId = userId,
            intent = FridgeOutboxIntent(
                action = FridgeOutboxAction.Delete,
                item = item.item,
                createdAtMillis = System.currentTimeMillis(),
            ),
        )
    }

    fun flushPendingFridgeMutations() {
        val userId = _uiState.value.userId ?: return
        viewModelScope.launch {
            val pending = outboxStore.load(userId)
            if (pending.isEmpty()) return@launch
            val remaining = mutableListOf<FridgeOutboxIntent>()
            var didSync = false
            pending.forEach { intent ->
                runCatching {
                    when (intent.action) {
                        FridgeOutboxAction.Add -> fridgeRepository.addItem(userId = userId, item = intent.item)
                        FridgeOutboxAction.Delete -> fridgeRepository.removeItem(userId = userId, itemId = intent.item.id)
                    }
                }.onSuccess {
                    didSync = true
                }.onFailure { error ->
                    SeasonLog.warning("fridge_sync_failed ${error::class.simpleName}")
                    remaining += intent.copy(
                        attemptCount = intent.attemptCount + 1,
                        lastErrorType = error::class.simpleName,
                    )
                }
            }
            outboxStore.replace(userId, remaining)
            applyPendingIntentsToUi(remaining)
            if (didSync) refresh()
        }
    }

    fun clearLocalStateOnLogout() {
        _uiState.value.userId?.let(outboxStore::clear)
        _uiState.value = FridgeUiState()
    }

    private fun enqueueIntent(
        userId: String,
        intent: FridgeOutboxIntent,
        clearQuery: Boolean = false,
        clearCustomName: Boolean = false,
    ) {
        outboxStore.upsert(userId, intent)
        _uiState.update { state ->
            val next = state.copy(
                query = if (clearQuery) "" else state.query,
                customName = if (clearCustomName) "" else state.customName,
                errorMessage = null,
            )
            next.copy(items = applyPendingIntentsToItems(next.items, outboxStore.load(userId)))
        }
        flushPendingFridgeMutations()
    }

    private fun buildStateItems(
        items: List<FridgeItem>,
        catalog: List<CatalogIngredient>,
    ): List<FridgeItemUi> {
        val catalogById = catalog.associateBy { it.id }
        return items.map { item ->
            val ingredient = item.ingredientId?.let(catalogById::get)
            val displayName = item.customName
                ?: ingredient?.displayName
                ?: item.ingredientId?.replace('_', ' ')
                ?: "Ingrediente"
            FridgeItemUi(
                item = item,
                displayName = displayName,
                label = if (item.isCustom) "Custom" else "Catalogo",
            )
        }.sortedWith(compareBy<FridgeItemUi> { it.displayName.lowercase() }.thenBy { it.item.id })
    }

    private fun applyPendingIntentsToUi(intents: List<FridgeOutboxIntent>) {
        _uiState.update { state ->
            state.copy(items = applyPendingIntentsToItems(state.items, intents))
        }
    }

    private fun applyPendingIntentsToItems(
        items: List<FridgeItemUi>,
        intents: List<FridgeOutboxIntent>,
    ): List<FridgeItemUi> {
        if (intents.isEmpty()) return items.map { it.copy(isPending = false, isFailed = false) }
        val mutable = items.associateBy { it.item.id }.toMutableMap()
        intents.forEach { intent ->
            when (intent.action) {
                FridgeOutboxAction.Add -> {
                    val existing = mutable[intent.item.id]
                    mutable[intent.item.id] = (existing ?: intent.item.toPendingUi()).copy(
                        isPending = true,
                        isFailed = intent.attemptCount >= FAILED_ATTEMPT_THRESHOLD,
                    )
                }
                FridgeOutboxAction.Delete -> {
                    mutable.remove(intent.item.id)
                }
            }
        }
        return mutable.values.sortedWith(compareBy<FridgeItemUi> { it.displayName.lowercase() }.thenBy { it.item.id })
    }

    private fun FridgeItem.toPendingUi(): FridgeItemUi {
        val displayName = customName
            ?: _uiState.value.catalogIngredients.firstOrNull { it.id == ingredientId }?.displayName
            ?: ingredientId?.replace('_', ' ')
            ?: "Ingrediente"
        return FridgeItemUi(
            item = this,
            displayName = displayName,
            label = if (isCustom) "Custom" else "Catalogo",
            isPending = true,
        )
    }

    private fun buildRecipeGroups(
        recipes: List<SeasonRecipe>,
        fridgeItems: List<FridgeItemUi>,
    ): FridgeRecipeGroups {
        if (fridgeItems.isEmpty()) return FridgeRecipeGroups()
        val catalogIds = fridgeItems.mapNotNull { it.item.ingredientId }.toSet()
        val normalizedNames = fridgeItems.map { it.displayName.normalized() }.toSet()
        val matches = recipes.mapNotNull { recipe ->
            recipe.toFridgeMatch(catalogIds = catalogIds, normalizedNames = normalizedNames)
        }.sortedWith(
            compareBy<FridgeRecipeMatch> { it.missingCount }
                .thenByDescending { it.matchedCount }
                .thenBy { it.recipe.title.lowercase() },
        )

        return FridgeRecipeGroups(
            ready = matches.filter { it.missingCount == 0 }.take(8),
            missingFew = matches.filter { it.missingCount in 1..2 }.take(8),
            almostReady = matches
                .filter { it.missingCount > 2 && it.matchedCount >= (it.totalCount / 2).coerceAtLeast(1) }
                .take(8),
        )
    }

    private fun SeasonRecipe.toFridgeMatch(
        catalogIds: Set<String>,
        normalizedNames: Set<String>,
    ): FridgeRecipeMatch? {
        val usefulIngredients = ingredients.filter { it.name.isNotBlank() }
        if (usefulIngredients.size < 2) return null
        if (usefulIngredients.isEmpty()) return null
        val missing = usefulIngredients.filterNot { ingredient ->
            ingredient.matchesFridge(catalogIds = catalogIds, normalizedNames = normalizedNames)
        }
        val matched = usefulIngredients.size - missing.size
        if (matched == 0) return null
        return FridgeRecipeMatch(
            recipe = this,
            missingIngredients = missing,
            matchedCount = matched,
            totalCount = usefulIngredients.size,
        )
    }

    private fun SeasonRecipeIngredient.matchesFridge(
        catalogIds: Set<String>,
        normalizedNames: Set<String>,
    ): Boolean {
        val id = ingredientId?.trim()?.takeIf { it.isNotEmpty() }
        return (id != null && id in catalogIds) || name.normalized() in normalizedNames
    }

    companion object {
        private const val FAILED_ATTEMPT_THRESHOLD = 3
    }
}
