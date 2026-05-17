package it.seasonapp.season.features.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.navigation.EnvironmentCard
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun HomeScreen(homeViewModel: HomeViewModel = viewModel()) {
    val state by homeViewModel.uiState.collectAsStateWithLifecycle()

    when (val current = state) {
        HomeUiState.Loading -> HomeLoading()
        is HomeUiState.Error -> HomeError(
            message = current.message,
            onRetry = homeViewModel::refresh,
        )
        is HomeUiState.Content -> HomeContent(
            snapshot = current.snapshot,
            onRefresh = homeViewModel::refresh,
        )
    }
}

@Composable
private fun HomeLoading() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun HomeError(message: String, onRetry: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { HomeHeader() }
        item { EnvironmentCard() }
        item {
            SeasonStatusCard(
                title = "Home non caricata",
                body = message,
                action = "Riprova",
                onAction = onRetry,
            )
        }
    }
}

@Composable
private fun HomeContent(snapshot: HomeSnapshot, onRefresh: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { HomeHeader() }
        item {
            HomeSummaryCard(
                totalRecipes = snapshot.totalCount,
                externalCount = snapshot.externalCount,
                onRefresh = onRefresh,
            )
        }

        val hero = snapshot.hero
        if (hero == null) {
            item {
                SeasonStatusCard(
                    title = "Nessuna ricetta pubblicata",
                    body = "Supabase è collegato, ma non ci sono ancora ricette leggibili per questa Home.",
                    action = "Ricarica",
                    onAction = onRefresh,
                )
            }
        } else {
            item {
                Text(
                    text = "Scelta per ora",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            item { HeroRecipeCard(recipe = hero) }
        }

        if (snapshot.recommended.isNotEmpty()) {
            item {
                Text(
                    text = "Da Supabase",
                    style = MaterialTheme.typography.titleLarge,
                )
            }
            items(snapshot.recommended, key = { it.id }) { recipe ->
                RecipeRowCard(recipe = recipe)
            }
        }
    }
}

@Composable
private fun HomeHeader() {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Season.",
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = "Il meglio di stagione, proprio ora.",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = "Ricette reali da Supabase dev, senza seed locali come source of truth.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun HomeSummaryCard(totalRecipes: Int, externalCount: Int, onRefresh: () -> Unit) {
    SeasonStatusCard(
        title = "Ambiente Dev",
        body = "$totalRecipes ricette caricate. $externalCount da fonti esterne riconosciute.",
        action = "Aggiorna",
        onAction = onRefresh,
    )
}

@Composable
private fun HeroRecipeCard(recipe: SeasonRecipe) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Column(
            modifier = Modifier.padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = recipe.displaySource,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = recipe.title,
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                text = recipeMeta(recipe),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            IngredientPreview(recipe = recipe)
        }
    }
}

@Composable
private fun RecipeRowCard(recipe: SeasonRecipe) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.6f)),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = recipe.title,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = recipeMeta(recipe),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = "${recipe.ingredients.size}",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun IngredientPreview(recipe: SeasonRecipe) {
    val preview = recipe.ingredients
        .take(3)
        .joinToString(separator = " · ") { ingredient ->
            listOfNotNull(ingredient.name, ingredient.quantityText).joinToString(" ")
        }

    if (preview.isNotBlank()) {
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = preview,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

private fun recipeMeta(recipe: SeasonRecipe): String {
    val source = recipe.displaySource
    val servings = "Per ${recipe.servings} persone"
    val steps = if (recipe.steps.isNotEmpty()) "${recipe.steps.size} passaggi" else "passaggi da completare"
    return "$source · $servings · $steps"
}
