package it.seasonapp.season.features.shopping

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.core.logging.SeasonLog
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.CatalogRepository
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

class ShoppingViewModel(
    application: Application,
    private val shoppingRepository: ShoppingRepository = ShoppingRepository(),
    private val catalogRepository: CatalogRepository = CatalogRepository(),
) : AndroidViewModel(application) {
    constructor(application: Application) : this(
        application = application,
        shoppingRepository = ShoppingRepository(),
        catalogRepository = CatalogRepository(),
    )

    private val outboxStore = ShoppingOutboxStore(application)
    private val _uiState = MutableStateFlow(ShoppingUiState())
    val uiState: StateFlow<ShoppingUiState> = _uiState

    fun initialize(userId: String) {
        if (_uiState.value.userId == userId && _uiState.value.catalogIngredients.isNotEmpty()) {
            return
        }
        _uiState.update { it.copy(userId = userId) }
        applyPendingIntentsToUi(outboxStore.load(userId))
        refresh()
        flushPendingShoppingMutations()
    }

    fun refresh() {
        val userId = _uiState.value.userId ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val catalog = catalogRepository.fetchCatalogIngredients(limit = 500)
                val items = shoppingRepository.fetchItems(userId)
                catalog to buildStateItems(items = items, catalog = catalog)
            }.onSuccess { (catalog, items) ->
                _uiState.update {
                    val withRemote = it.copy(
                        catalogIngredients = catalog,
                        items = items,
                        isLoading = false,
                        errorMessage = null,
                    )
                    withRemote.copy(items = applyPendingIntentsToItems(withRemote.items, outboxStore.load(userId)))
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Non riesco a caricare la lista.",
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

    fun updateQuantity(quantity: String) {
        _uiState.update { it.copy(quantity = quantity) }
    }

    fun updateUnit(unit: String) {
        _uiState.update { it.copy(unit = unit) }
    }

    fun addCatalogIngredient(ingredient: CatalogIngredient) {
        val userId = _uiState.value.userId ?: return
        val request = ShoppingAddRequest(
            ingredientType = "catalog",
            ingredientId = ingredient.id,
            customName = null,
            displayName = ingredient.displayName,
            quantity = _uiState.value.quantity.parseQuantity(),
            unit = _uiState.value.unit.cleanOrNull(),
            sourceRecipeId = null,
        )
        if (hasDuplicate(request)) {
            _uiState.update { it.copy(feedbackMessage = "Ingrediente già presente nella lista.") }
            return
        }
        enqueueIntent(userId = userId, intent = request.toAddIntent(), clearQuery = true, clearQuantity = true)
    }

    fun addCustomIngredient() {
        val userId = _uiState.value.userId ?: return
        val customName = _uiState.value.customName.trim()
        if (customName.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Inserisci un nome ingrediente.") }
            return
        }
        val request = ShoppingAddRequest(
            ingredientType = "custom",
            ingredientId = null,
            customName = customName,
            displayName = customName,
            quantity = _uiState.value.quantity.parseQuantity(),
            unit = _uiState.value.unit.cleanOrNull(),
            sourceRecipeId = null,
        )
        if (hasDuplicate(request)) {
            _uiState.update { it.copy(feedbackMessage = "Ingrediente già presente nella lista.") }
            return
        }
        enqueueIntent(userId = userId, intent = request.toAddIntent(), clearCustomName = true, clearQuantity = true)
    }

    fun toggleChecked(item: ShoppingItemUi) {
        val userId = _uiState.value.userId ?: return
        val target = !item.item.isChecked
        enqueueIntent(
            userId = userId,
            intent = ShoppingOutboxIntent(
                action = ShoppingOutboxAction.Check,
                item = item.item.copy(isChecked = target),
                targetChecked = target,
                createdAtMillis = System.currentTimeMillis(),
            ),
        )
    }

    fun removeItem(item: ShoppingItemUi) {
        val userId = _uiState.value.userId ?: return
        enqueueIntent(
            userId = userId,
            intent = ShoppingOutboxIntent(
                action = ShoppingOutboxAction.Delete,
                item = item.item,
                createdAtMillis = System.currentTimeMillis(),
            ),
        )
    }

    fun addRecipeIngredients(recipe: SeasonRecipe) {
        addRecipeIngredients(recipe = recipe, ingredients = recipe.ingredients)
    }

    fun addRecipeIngredients(recipe: SeasonRecipe, ingredients: List<SeasonRecipeIngredient>) {
        val userId = _uiState.value.userId ?: return
        val requests = ingredients.mapNotNull { it.toShoppingRequest(sourceRecipeId = recipe.id) }
        if (requests.isEmpty()) {
            _uiState.update { it.copy(feedbackMessage = "Questa ricetta non ha ingredienti da aggiungere.") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isMutating = true, feedbackMessage = null, errorMessage = null) }
            var added = 0
            var skipped = 0
            var failed = 0
            requests.forEach { request ->
                if (hasDuplicate(request)) {
                    skipped += 1
                } else {
                    outboxStore.upsert(userId, request.toAddIntent())
                    added += 1
                }
            }
            val result = ShoppingRecipeAddResult(added = added, skipped = skipped, failed = failed)
            _uiState.update {
                val next = it.copy(
                    isMutating = false,
                    feedbackMessage = result.message,
                    errorMessage = if (failed > 0) "Alcuni ingredienti non sono stati sincronizzati." else null,
                )
                next.copy(items = applyPendingIntentsToItems(next.items, outboxStore.load(userId)))
            }
            flushPendingShoppingMutations()
        }
    }

    fun flushPendingShoppingMutations() {
        val userId = _uiState.value.userId ?: return
        viewModelScope.launch {
            val pending = outboxStore.load(userId)
            if (pending.isEmpty()) return@launch
            val remaining = mutableListOf<ShoppingOutboxIntent>()
            var didSync = false
            pending.forEach { intent ->
                runCatching {
                    when (intent.action) {
                        ShoppingOutboxAction.Add -> shoppingRepository.addItem(userId = userId, item = intent.item)
                        ShoppingOutboxAction.Check -> shoppingRepository.updateChecked(
                            userId = userId,
                            itemId = intent.item.id,
                            isChecked = intent.targetChecked ?: intent.item.isChecked,
                        )
                        ShoppingOutboxAction.Delete -> shoppingRepository.removeItem(userId = userId, itemId = intent.item.id)
                    }
                }.onSuccess {
                    didSync = true
                }.onFailure { error ->
                    SeasonLog.warning("shopping_sync_failed ${error::class.simpleName}")
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
        _uiState.value = ShoppingUiState()
    }

    private fun enqueueIntent(
        userId: String,
        intent: ShoppingOutboxIntent,
        clearQuery: Boolean = false,
        clearCustomName: Boolean = false,
        clearQuantity: Boolean = false,
    ) {
        outboxStore.upsert(userId, intent)
        _uiState.update { state ->
            val next = state.copy(
                query = if (clearQuery) "" else state.query,
                customName = if (clearCustomName) "" else state.customName,
                quantity = if (clearQuantity) "" else state.quantity,
                unit = if (clearQuantity) "" else state.unit,
                errorMessage = null,
                feedbackMessage = "Lista aggiornata.",
            )
            next.copy(items = applyPendingIntentsToItems(next.items, outboxStore.load(userId)))
        }
        flushPendingShoppingMutations()
    }

    private fun buildStateItems(
        items: List<ShoppingItem>,
        catalog: List<CatalogIngredient>,
    ): List<ShoppingItemUi> {
        val catalogById = catalog.associateBy { it.id }
        return items.map { item ->
            val ingredient = item.ingredientId?.let(catalogById::get)
            val displayName = item.customName
                ?: ingredient?.displayName
                ?: item.ingredientId?.replace('_', ' ')
                ?: "Ingrediente"
            ShoppingItemUi(
                item = item,
                displayName = displayName,
                label = if (item.isCustom) "Custom" else "Catalogo",
            )
        }.sortedWith(compareBy<ShoppingItemUi> { it.item.isChecked }.thenBy { it.displayName.lowercase() })
    }

    private fun applyPendingIntentsToUi(intents: List<ShoppingOutboxIntent>) {
        _uiState.update { state ->
            state.copy(items = applyPendingIntentsToItems(state.items, intents))
        }
    }

    private fun applyPendingIntentsToItems(
        items: List<ShoppingItemUi>,
        intents: List<ShoppingOutboxIntent>,
    ): List<ShoppingItemUi> {
        if (intents.isEmpty()) return items.map { it.copy(isPending = false, isFailed = false) }
        val mutable = items.associateBy { it.item.id }.toMutableMap()
        intents.forEach { intent ->
            when (intent.action) {
                ShoppingOutboxAction.Add -> {
                    val existing = mutable[intent.item.id]
                    mutable[intent.item.id] = (existing ?: intent.item.toPendingUi()).copy(
                        isPending = true,
                        isFailed = intent.attemptCount >= FAILED_ATTEMPT_THRESHOLD,
                    )
                }
                ShoppingOutboxAction.Check -> {
                    val previous = mutable[intent.item.id] ?: intent.item.toPendingUi()
                    mutable[intent.item.id] = previous.copy(
                        item = previous.item.copy(isChecked = intent.targetChecked ?: intent.item.isChecked),
                        isPending = true,
                        isFailed = intent.attemptCount >= FAILED_ATTEMPT_THRESHOLD,
                    )
                }
                ShoppingOutboxAction.Delete -> {
                    mutable.remove(intent.item.id)
                }
            }
        }
        return mutable.values.sortedWith(compareBy<ShoppingItemUi> { it.item.isChecked }.thenBy { it.displayName.lowercase() })
    }

    private fun ShoppingItem.toPendingUi(): ShoppingItemUi {
        val displayName = customName
            ?: _uiState.value.catalogIngredients.firstOrNull { it.id == ingredientId }?.displayName
            ?: ingredientId?.replace('_', ' ')
            ?: "Ingrediente"
        return ShoppingItemUi(
            item = this,
            displayName = displayName,
            label = if (isCustom) "Custom" else "Catalogo",
            isPending = true,
        )
    }

    private fun hasDuplicate(request: ShoppingAddRequest): Boolean {
        return _uiState.value.items.any { item ->
            item.item.sourceRecipeId == request.sourceRecipeId &&
                item.item.quantity == request.quantity &&
                item.item.unit.normalized() == request.unit.normalized() &&
                when {
                    request.ingredientId != null -> item.item.ingredientId == request.ingredientId
                    else -> item.displayName.normalized() == request.displayName.normalized()
                }
        }
    }

    private fun ShoppingAddRequest.toAddIntent(): ShoppingOutboxIntent {
        val item = ShoppingItem(
            id = UUID.randomUUID().toString(),
            ingredientType = ingredientType,
            ingredientId = ingredientId,
            customName = customName,
            quantity = quantity,
            unit = unit,
            sourceRecipeId = sourceRecipeId,
            isChecked = false,
            updatedAt = null,
        )
        return ShoppingOutboxIntent(
            action = ShoppingOutboxAction.Add,
            item = item,
            createdAtMillis = System.currentTimeMillis(),
        )
    }

    companion object {
        private const val FAILED_ATTEMPT_THRESHOLD = 3
    }
}

private fun String.parseQuantity(): Double? {
    return trim()
        .replace(",", ".")
        .toDoubleOrNull()
        ?.takeIf { it > 0 }
}

private fun String.cleanOrNull(): String? {
    return trim().takeIf { it.isNotEmpty() }
}

private fun String?.normalized(): String {
    return this?.trim()?.lowercase()?.replace(Regex("\\s+"), " ").orEmpty()
}
