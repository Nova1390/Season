package it.seasonapp.season.features.fridge

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
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient
import it.seasonapp.season.features.shopping.ShoppingViewModel
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun FridgeScreen(
    fridgeViewModel: FridgeViewModel,
    shoppingViewModel: ShoppingViewModel,
    onRecipeSelected: (SeasonRecipe) -> Unit,
    onOpenShopping: () -> Unit,
) {
    val state by fridgeViewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .imePadding(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            FridgeHeader(
                total = state.items.size,
                isLoading = state.isLoading,
                onRefresh = fridgeViewModel::refresh,
            )
        }

        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Frigo non aggiornato",
                    body = message,
                    action = "Riprova",
                    onAction = fridgeViewModel::refresh,
                )
            }
        }

        item {
            CatalogAddSection(
                query = state.query,
                candidates = state.filteredCatalogIngredients,
                isMutating = state.isMutating,
                onQueryChange = fridgeViewModel::updateQuery,
                onAdd = fridgeViewModel::addCatalogIngredient,
            )
        }

        item {
            CustomAddSection(
                customName = state.customName,
                isMutating = state.isMutating,
                onCustomNameChange = fridgeViewModel::updateCustomName,
                onAdd = fridgeViewModel::addCustomIngredient,
            )
        }

        item {
            Text(
                text = "Nel frigo",
                style = MaterialTheme.typography.titleLarge,
            )
        }

        if (state.items.isEmpty() && !state.isLoading) {
            item {
                SeasonStatusCard(
                    title = "Frigo vuoto",
                    body = "Aggiungi ingredienti dal catalogo o un custom temporaneo. I custom restano dati utente: non diventano catalogo.",
                )
            }
        } else {
            items(state.items, key = { it.item.id }) { item ->
                FridgeItemRow(
                    item = item,
                    isMutating = state.isMutating,
                    onRemove = { fridgeViewModel.removeItem(item) },
                )
            }
        }

        item {
            FridgeRecipesSection(
                groups = state.recipeGroups,
                onRecipeSelected = onRecipeSelected,
                onAddMissingToShopping = { recipe, missing ->
                    shoppingViewModel.addRecipeIngredients(recipe = recipe, ingredients = missing)
                    onOpenShopping()
                },
            )
        }
    }
}

@Composable
private fun FridgeHeader(total: Int, isLoading: Boolean, onRefresh: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Frigo",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = "La tua dispensa reale: catalogo quando possibile, custom solo come fallback utente.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SeasonStatusCard(
            title = "$total ingredienti disponibili",
            body = "Questo step sincronizza add/remove su Supabase dev. Le ricette cucinabili dal frigo arriveranno nel blocco successivo.",
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
                    text = "Carico il tuo frigo…",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun CatalogAddSection(
    query: String,
    candidates: List<CatalogIngredient>,
    isMutating: Boolean,
    onQueryChange: (String) -> Unit,
    onAdd: (CatalogIngredient) -> Unit,
) {
    FridgeCard {
        Text(text = "Aggiungi dal catalogo", style = MaterialTheme.typography.titleMedium)
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = query,
            onValueChange = onQueryChange,
            singleLine = true,
            label = { Text("Cerca ingrediente") },
        )
        if (query.isNotBlank()) {
            if (candidates.isEmpty()) {
                Text(
                    text = "Nessun ingrediente catalogo trovato. Usa il custom solo se serve davvero.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    candidates.forEach { ingredient ->
                        CandidateRow(
                            ingredient = ingredient,
                            isMutating = isMutating,
                            onAdd = { onAdd(ingredient) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CandidateRow(
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
        OutlinedButton(
            enabled = !isMutating,
            onClick = onAdd,
        ) {
            Text("Aggiungi")
        }
    }
}

@Composable
private fun CustomAddSection(
    customName: String,
    isMutating: Boolean,
    onCustomNameChange: (String) -> Unit,
    onAdd: () -> Unit,
) {
    FridgeCard {
        Text(text = "Fallback custom", style = MaterialTheme.typography.titleMedium)
        Text(
            text = "Usalo per ingredienti ancora non riconosciuti. Non modifica il catalogo centrale.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = customName,
            onValueChange = onCustomNameChange,
            singleLine = true,
            label = { Text("Nome ingrediente custom") },
        )
        Button(
            enabled = !isMutating && customName.isNotBlank(),
            onClick = onAdd,
        ) {
            Text("Aggiungi custom")
        }
    }
}

@Composable
private fun FridgeItemRow(item: FridgeItemUi, isMutating: Boolean, onRemove: () -> Unit) {
    FridgeCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
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
                    AssistChip(
                        onClick = {},
                        label = { Text(item.label) },
                    )
                    if (item.isPending || item.isFailed) {
                        AssistChip(
                            onClick = {},
                            label = { Text(if (item.isFailed) "Da sincronizzare" else "Sincronizzazione…") },
                        )
                    }
                    item.item.unit?.let { unit ->
                        AssistChip(
                            onClick = {},
                            label = { Text(quantityLabel(item.item.quantity, unit)) },
                        )
                    }
                }
            }
            OutlinedButton(
                enabled = !isMutating,
                onClick = onRemove,
            ) {
                Text("Rimuovi")
            }
        }
    }
}

@Composable
private fun FridgeRecipesSection(
    groups: FridgeRecipeGroups,
    onRecipeSelected: (SeasonRecipe) -> Unit,
    onAddMissingToShopping: (SeasonRecipe, List<SeasonRecipeIngredient>) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(text = "Cosa puoi cucinare", style = MaterialTheme.typography.titleLarge)
        if (groups.total == 0) {
            SeasonStatusCard(
                title = "Aggiungi qualche ingrediente",
                body = "Quando il frigo ha abbastanza dati, qui trovi ricette pronte, ricette a cui manca poco e idee quasi pronte.",
            )
        } else {
            RecipeMatchGroup(
                title = "Pronte",
                empty = "Nessuna ricetta completa con il frigo attuale.",
                matches = groups.ready,
                onRecipeSelected = onRecipeSelected,
                onAddMissingToShopping = onAddMissingToShopping,
            )
            RecipeMatchGroup(
                title = "Manca poco",
                empty = "Nessuna ricetta con 1-2 ingredienti mancanti.",
                matches = groups.missingFew,
                onRecipeSelected = onRecipeSelected,
                onAddMissingToShopping = onAddMissingToShopping,
            )
            RecipeMatchGroup(
                title = "Quasi pronte",
                empty = "Nessuna ricetta abbastanza vicina.",
                matches = groups.almostReady,
                onRecipeSelected = onRecipeSelected,
                onAddMissingToShopping = onAddMissingToShopping,
            )
        }
    }
}

@Composable
private fun RecipeMatchGroup(
    title: String,
    empty: String,
    matches: List<FridgeRecipeMatch>,
    onRecipeSelected: (SeasonRecipe) -> Unit,
    onAddMissingToShopping: (SeasonRecipe, List<SeasonRecipeIngredient>) -> Unit,
) {
    FridgeCard {
        Text(text = title, style = MaterialTheme.typography.titleMedium)
        if (matches.isEmpty()) {
            Text(
                text = empty,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            matches.forEach { match ->
                RecipeMatchRow(
                    match = match,
                    onRecipeSelected = { onRecipeSelected(match.recipe) },
                    onAddMissingToShopping = {
                        onAddMissingToShopping(match.recipe, match.missingIngredients)
                    },
                )
            }
        }
    }
}

@Composable
private fun RecipeMatchRow(
    match: FridgeRecipeMatch,
    onRecipeSelected: () -> Unit,
    onAddMissingToShopping: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                text = match.recipe.title,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = if (match.missingCount == 0) {
                    "${match.progressLabel} · pronta"
                } else {
                    "${match.progressLabel} · mancano ${match.missingCount}"
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onRecipeSelected) {
                Text("Apri")
            }
            if (match.missingCount > 0) {
                OutlinedButton(onClick = onAddMissingToShopping) {
                    Text("Mancanti")
                }
            }
        }
    }
}

@Composable
private fun FridgeCard(content: @Composable ColumnScope.() -> Unit) {
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

private fun quantityLabel(quantity: Double?, unit: String): String {
    return quantity?.let { "${it.cleanFormat()} $unit" } ?: unit
}

private fun Double.cleanFormat(): String {
    val rounded = toLong()
    return if (kotlin.math.abs(this - rounded.toDouble()) < 0.001) {
        rounded.toString()
    } else {
        "%.1f".format(this)
    }
}
