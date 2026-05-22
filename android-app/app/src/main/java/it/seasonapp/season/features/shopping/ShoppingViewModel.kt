package it.seasonapp.season.features.shopping

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.CatalogRepository
import it.seasonapp.season.features.recipes.SeasonRecipe
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ShoppingViewModel(
    private val shoppingRepository: ShoppingRepository = ShoppingRepository(),
    private val catalogRepository: CatalogRepository = CatalogRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(ShoppingUiState())
    val uiState: StateFlow<ShoppingUiState> = _uiState

    fun initialize(userId: String) {
        if (_uiState.value.userId == userId && _uiState.value.catalogIngredients.isNotEmpty()) {
            return
        }
        _uiState.update { it.copy(userId = userId) }
        refresh()
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
                    it.copy(
                        catalogIngredients = catalog,
                        items = items,
                        isLoading = false,
                        errorMessage = null,
                    )
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
        mutateAndRefresh(clearQuery = true, clearQuantity = true) {
            shoppingRepository.addItem(userId = userId, request = request)
        }
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
        mutateAndRefresh(clearCustomName = true, clearQuantity = true) {
            shoppingRepository.addItem(userId = userId, request = request)
        }
    }

    fun toggleChecked(item: ShoppingItemUi) {
        val userId = _uiState.value.userId ?: return
        mutateAndRefresh {
            shoppingRepository.updateChecked(
                userId = userId,
                itemId = item.item.id,
                isChecked = !item.item.isChecked,
            )
        }
    }

    fun removeItem(item: ShoppingItemUi) {
        val userId = _uiState.value.userId ?: return
        mutateAndRefresh {
            shoppingRepository.removeItem(userId = userId, itemId = item.item.id)
        }
    }

    fun addRecipeIngredients(recipe: SeasonRecipe) {
        val userId = _uiState.value.userId ?: return
        val requests = recipe.toShoppingRequests()
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
                    runCatching {
                        shoppingRepository.addItem(userId = userId, request = request)
                    }.onSuccess {
                        added += 1
                    }.onFailure {
                        failed += 1
                    }
                }
            }
            val result = ShoppingRecipeAddResult(added = added, skipped = skipped, failed = failed)
            _uiState.update {
                it.copy(
                    isMutating = false,
                    feedbackMessage = result.message,
                    errorMessage = if (failed > 0) "Alcuni ingredienti non sono stati sincronizzati." else null,
                )
            }
            refresh()
        }
    }

    fun clearLocalStateOnLogout() {
        _uiState.value = ShoppingUiState()
    }

    private fun mutateAndRefresh(
        clearQuery: Boolean = false,
        clearCustomName: Boolean = false,
        clearQuantity: Boolean = false,
        block: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isMutating = true, errorMessage = null, feedbackMessage = null) }
            runCatching {
                block()
            }.onSuccess {
                _uiState.update { state ->
                    state.copy(
                        isMutating = false,
                        query = if (clearQuery) "" else state.query,
                        customName = if (clearCustomName) "" else state.customName,
                        quantity = if (clearQuantity) "" else state.quantity,
                        unit = if (clearQuantity) "" else state.unit,
                        feedbackMessage = "Lista aggiornata.",
                    )
                }
                refresh()
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isMutating = false,
                        errorMessage = error.message ?: "Operazione lista non riuscita.",
                    )
                }
            }
        }
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
