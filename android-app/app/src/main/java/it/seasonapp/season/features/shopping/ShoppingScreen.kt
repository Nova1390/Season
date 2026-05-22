package it.seasonapp.season.features.shopping

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun ShoppingScreen(shoppingViewModel: ShoppingViewModel) {
    val state by shoppingViewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .imePadding(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            ShoppingHeader(
                total = state.items.size,
                unchecked = state.uncheckedCount,
                isLoading = state.isLoading,
                onRefresh = shoppingViewModel::refresh,
            )
        }

        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Lista non aggiornata",
                    body = message,
                    action = "Riprova",
                    onAction = shoppingViewModel::refresh,
                )
            }
        }

        state.feedbackMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Lista spesa",
                    body = message,
                )
            }
        }

        item {
            ShoppingInputSection(
                query = state.query,
                customName = state.customName,
                quantity = state.quantity,
                unit = state.unit,
                candidates = state.filteredCatalogIngredients,
                isMutating = state.isMutating,
                onQueryChange = shoppingViewModel::updateQuery,
                onCustomNameChange = shoppingViewModel::updateCustomName,
                onQuantityChange = shoppingViewModel::updateQuantity,
                onUnitChange = shoppingViewModel::updateUnit,
                onAddCatalog = shoppingViewModel::addCatalogIngredient,
                onAddCustom = shoppingViewModel::addCustomIngredient,
            )
        }

        item {
            Text(
                text = "Da comprare",
                style = MaterialTheme.typography.titleLarge,
            )
        }

        if (state.items.isEmpty() && !state.isLoading) {
            item {
                SeasonStatusCard(
                    title = "Lista vuota",
                    body = "Aggiungi ingredienti manualmente o da una ricetta. I custom restano nella tua lista e non modificano il catalogo.",
                )
            }
        } else {
            items(state.items, key = { it.item.id }) { item ->
                ShoppingItemRow(
                    item = item,
                    isMutating = state.isMutating,
                    onToggle = { shoppingViewModel.toggleChecked(item) },
                    onRemove = { shoppingViewModel.removeItem(item) },
                )
            }
        }
    }
}

@Composable
private fun ShoppingHeader(total: Int, unchecked: Int, isLoading: Boolean, onRefresh: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Lista della spesa",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = "Ingredienti da ricette o aggiunti a mano. Catalogo quando possibile, custom solo come fallback.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SeasonStatusCard(
            title = "$unchecked da comprare su $total",
            body = "Questo MVP sincronizza add, check e rimozione su Supabase dev.",
            action = "Aggiorna",
            onAction = onRefresh,
        )
        if (isLoading) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(strokeWidth = 2.dp)
                Text(
                    text = "Carico la lista…",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun ShoppingInputSection(
    query: String,
    customName: String,
    quantity: String,
    unit: String,
    candidates: List<CatalogIngredient>,
    isMutating: Boolean,
    onQueryChange: (String) -> Unit,
    onCustomNameChange: (String) -> Unit,
    onQuantityChange: (String) -> Unit,
    onUnitChange: (String) -> Unit,
    onAddCatalog: (CatalogIngredient) -> Unit,
    onAddCustom: () -> Unit,
) {
    ShoppingCard {
        Text(text = "Aggiungi ingrediente", style = MaterialTheme.typography.titleMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(
                modifier = Modifier.weight(1f),
                value = quantity,
                onValueChange = onQuantityChange,
                singleLine = true,
                label = { Text("Quantità") },
            )
            OutlinedTextField(
                modifier = Modifier.weight(1f),
                value = unit,
                onValueChange = onUnitChange,
                singleLine = true,
                label = { Text("Unità") },
            )
        }
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = query,
            onValueChange = onQueryChange,
            singleLine = true,
            label = { Text("Cerca nel catalogo") },
        )
        if (query.isNotBlank()) {
            if (candidates.isEmpty()) {
                Text(
                    text = "Nessun ingrediente catalogo trovato. Puoi aggiungerlo come custom.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    candidates.forEach { ingredient ->
                        ShoppingCandidateRow(
                            ingredient = ingredient,
                            isMutating = isMutating,
                            onAdd = { onAddCatalog(ingredient) },
                        )
                    }
                }
            }
        }
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = customName,
            onValueChange = onCustomNameChange,
            singleLine = true,
            label = { Text("Oppure custom") },
        )
        Button(
            enabled = !isMutating && customName.isNotBlank(),
            onClick = onAddCustom,
        ) {
            Text("Aggiungi custom")
        }
    }
}

@Composable
private fun ShoppingCandidateRow(
    ingredient: CatalogIngredient,
    isMutating: Boolean,
    onAdd: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = ingredient.displayName,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = ingredient.type?.replace('_', ' ') ?: "Catalogo",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        OutlinedButton(enabled = !isMutating, onClick = onAdd) {
            Text("Aggiungi")
        }
    }
}

@Composable
private fun ShoppingItemRow(
    item: ShoppingItemUi,
    isMutating: Boolean,
    onToggle: () -> Unit,
    onRemove: () -> Unit,
) {
    ShoppingCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Checkbox(
                checked = item.item.isChecked,
                enabled = !isMutating,
                onCheckedChange = { onToggle() },
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = item.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(onClick = {}, label = { Text(item.label) })
                    item.quantityText?.let {
                        AssistChip(onClick = {}, label = { Text(it) })
                    }
                    if (item.item.sourceRecipeId != null) {
                        AssistChip(onClick = {}, label = { Text("Da ricetta") })
                    }
                }
            }
            OutlinedButton(enabled = !isMutating, onClick = onRemove) {
                Text("Rimuovi")
            }
        }
    }
}

@Composable
private fun ShoppingCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.65f)),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}
