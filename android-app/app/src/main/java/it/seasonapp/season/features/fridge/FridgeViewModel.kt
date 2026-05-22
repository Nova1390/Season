package it.seasonapp.season.features.fridge

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.CatalogRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class FridgeViewModel(
    private val fridgeRepository: FridgeRepository = FridgeRepository(),
    private val catalogRepository: CatalogRepository = CatalogRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(FridgeUiState())
    val uiState: StateFlow<FridgeUiState> = _uiState

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
                val items = fridgeRepository.fetchItems(userId)
                buildStateItems(items = items, catalog = catalog)
                    .let { catalog to it }
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
        mutateAndRefresh(clearQuery = true) {
            fridgeRepository.addCatalogItem(userId = userId, ingredient = ingredient)
        }
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
        mutateAndRefresh(clearCustomName = true) {
            fridgeRepository.addCustomItem(userId = userId, name = customName)
        }
    }

    fun removeItem(item: FridgeItemUi) {
        val userId = _uiState.value.userId ?: return
        mutateAndRefresh {
            fridgeRepository.removeItem(userId = userId, itemId = item.item.id)
        }
    }

    fun clearLocalStateOnLogout() {
        _uiState.value = FridgeUiState()
    }

    private fun mutateAndRefresh(
        clearQuery: Boolean = false,
        clearCustomName: Boolean = false,
        block: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isMutating = true, errorMessage = null) }
            runCatching {
                block()
            }.onSuccess {
                if (clearQuery || clearCustomName) {
                    _uiState.update { state ->
                        state.copy(
                            query = if (clearQuery) "" else state.query,
                            customName = if (clearCustomName) "" else state.customName,
                        )
                    }
                }
                _uiState.update { it.copy(isMutating = false) }
                refresh()
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isMutating = false,
                        errorMessage = error.message ?: "Operazione frigo non riuscita.",
                    )
                }
            }
        }
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
}
