package it.seasonapp.season.features.search

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun SearchScreen(
    onRecipeSelected: (SeasonRecipe) -> Unit,
    searchViewModel: SearchViewModel = viewModel(),
) {
    val state by searchViewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            SearchHeader(
                query = state.query,
                onQueryChange = searchViewModel::updateQuery,
                isLoading = state.isLoading,
            )
        }

        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Ricerca non caricata",
                    body = message,
                    action = "Riprova",
                    onAction = searchViewModel::retry,
                )
            }
        }

        if (!state.isLoading && state.errorMessage == null) {
            item {
                SearchSectionTitle(
                    title = "Ricette",
                    count = state.results.recipes.size,
                )
            }
            if (state.results.recipes.isEmpty()) {
                item { EmptySearchCard("Nessuna ricetta trovata per questa ricerca.") }
            } else {
                items(state.results.recipes, key = { it.id }) { recipe ->
                    RecipeSearchRow(recipe = recipe, onClick = { onRecipeSelected(recipe) })
                }
            }

            item {
                SearchSectionTitle(
                    title = "Ingredienti",
                    count = state.results.ingredients.size,
                )
            }
            if (state.results.ingredients.isEmpty()) {
                item { EmptySearchCard("Nessun ingrediente catalogo trovato.") }
            } else {
                items(state.results.ingredients, key = { it.id }) { ingredient ->
                    IngredientSearchRow(ingredient = ingredient)
                }
            }
        }
    }
}

@Composable
private fun SearchHeader(query: String, onQueryChange: (String) -> Unit, isLoading: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Scopri",
            style = MaterialTheme.typography.headlineMedium,
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = query,
            onValueChange = onQueryChange,
            singleLine = true,
            label = { Text("Cerca ricette o ingredienti") },
        )
        if (isLoading) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(strokeWidth = 2.dp)
                Text(
                    text = "Carico ricette e catalogo…",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SearchSectionTitle(title: String, count: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = title, style = MaterialTheme.typography.titleLarge)
        Text(
            text = "$count risultati",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RecipeSearchRow(recipe: SeasonRecipe, onClick: () -> Unit) {
    SearchCard(onClick = onClick) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text = recipe.title,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "${recipe.displaySource} · Per ${recipe.servings} persone · ${recipe.ingredients.size} ingredienti",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun IngredientSearchRow(ingredient: CatalogIngredient) {
    SearchCard {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = ingredient.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = ingredient.type?.replace('_', ' ') ?: "Catalogo",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (ingredient.isSeasonal) {
                Text(
                    text = "Stagionale",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun SearchCard(content: @Composable () -> Unit) {
    SearchCard(onClick = null, content = content)
}

@Composable
private fun SearchCard(onClick: (() -> Unit)?, content: @Composable () -> Unit) {
    Card(
        modifier = if (onClick == null) {
            Modifier.fillMaxWidth()
        } else {
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
        },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.6f)),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun EmptySearchCard(message: String) {
    SeasonStatusCard(title = "Vuoto", body = message)
}
