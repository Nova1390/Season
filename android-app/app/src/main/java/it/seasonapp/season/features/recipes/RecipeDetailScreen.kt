package it.seasonapp.season.features.recipes

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.seasonapp.season.core.design.SeasonKicker
import it.seasonapp.season.core.design.SeasonPanel
import it.seasonapp.season.core.design.SeasonPill
import it.seasonapp.season.core.design.SeasonPillEmphasis
import it.seasonapp.season.core.design.SeasonRecipeArtwork
import it.seasonapp.season.features.recipestate.UserRecipeStateUi
import it.seasonapp.season.features.recipestate.UserRecipeStateViewModel
import it.seasonapp.season.features.shopping.ShoppingViewModel
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun RecipeDetailScreen(
    recipe: SeasonRecipe,
    recipeStateViewModel: UserRecipeStateViewModel,
    shoppingViewModel: ShoppingViewModel,
    onOpenShopping: () -> Unit,
) {
    LaunchedEffect(recipe.id) {
        recipeStateViewModel.ensureLoaded(recipe.id)
    }
    val recipeStateFlow = remember(recipe.id, recipeStateViewModel) {
        recipeStateViewModel.observeRecipeState(recipe.id)
    }
    val recipeState by recipeStateFlow.collectAsStateWithLifecycle()
    val shoppingState by shoppingViewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { RecipeDetailHeader(recipe = recipe) }
        item {
            RecipeStateActions(
                state = recipeState,
                onToggleSaved = { recipeStateViewModel.toggleSaved(recipe.id) },
                onToggleCrispy = { recipeStateViewModel.toggleCrispy(recipe.id) },
            )
        }
        item {
            RecipeShoppingActions(
                hasIngredients = recipe.ingredients.isNotEmpty(),
                isMutating = shoppingState.isMutating,
                feedbackMessage = shoppingState.feedbackMessage,
                onAddToShopping = { shoppingViewModel.addRecipeIngredients(recipe) },
                onOpenShopping = onOpenShopping,
            )
        }
        item { RecipeIngredientSection(recipe = recipe) }
        item { RecipeStepsSection(recipe = recipe) }
    }
}

@Composable
private fun RecipeShoppingActions(
    hasIngredients: Boolean,
    isMutating: Boolean,
    feedbackMessage: String?,
    onAddToShopping: () -> Unit,
    onOpenShopping: () -> Unit,
) {
    SeasonPanel {
        SeasonKicker(text = "Lista della spesa")
        Text(
            text = "Aggiunge gli ingredienti preservando quantità, unità e origine.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                enabled = hasIngredients && !isMutating,
                onClick = onAddToShopping,
            ) {
                Text(if (isMutating) "Aggiungo…" else "Aggiungi alla lista")
            }
            OutlinedButton(onClick = onOpenShopping) {
                Text("Apri lista")
            }
        }
        feedbackMessage?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun RecipeDetailHeader(recipe: SeasonRecipe) {
    SeasonPanel(prominent = true) {
        SeasonRecipeArtwork(title = recipe.title, imageUrl = recipe.imageUrl, heightDp = 248)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SeasonPill(text = recipe.displaySource, emphasis = SeasonPillEmphasis.Primary)
            if (recipe.isExternal) {
                SeasonPill(text = "Ricetta esterna")
            }
            SeasonPill(text = "Per ${recipe.servings}", emphasis = SeasonPillEmphasis.Secondary)
        }
        Text(
            text = recipe.title,
            style = MaterialTheme.typography.displaySmall,
        )
        Text(
            text = "${recipe.ingredients.size} ingredienti · ${recipe.steps.size} passaggi",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RecipeStateActions(
    state: UserRecipeStateUi,
    onToggleSaved: () -> Unit,
    onToggleCrispy: () -> Unit,
) {
    SeasonPanel {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (state.isSaved) {
                Button(onClick = onToggleSaved) {
                    Text("Salvata")
                }
            } else {
                OutlinedButton(onClick = onToggleSaved) {
                    Text("Salva")
                }
            }

            if (state.isCrispied) {
                Button(onClick = onToggleCrispy) {
                    Text("Crispy")
                }
            } else {
                OutlinedButton(onClick = onToggleCrispy) {
                    Text("Crispy")
                }
            }
        }
        if (state.isPending || state.isFailed) {
            Text(
                text = if (state.isFailed) "Da sincronizzare" else "Sincronizzazione…",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun RecipeIngredientSection(recipe: SeasonRecipe) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "Ingredienti",
            style = MaterialTheme.typography.titleLarge,
        )
        if (recipe.ingredients.isEmpty()) {
            SeasonStatusCard(
                title = "Ingredienti non disponibili",
                body = "Questa ricetta non ha ancora ingredienti strutturati nel dato remoto.",
            )
        } else {
            recipe.ingredients.forEach { ingredient ->
                IngredientRow(ingredient = ingredient)
            }
        }
    }
}

@Composable
private fun IngredientRow(ingredient: SeasonRecipeIngredient) {
    SeasonPanel {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            modifier = Modifier.weight(1f),
            text = ingredient.name,
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text = ingredient.quantityText ?: "Senza quantità",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    }
}

@Composable
private fun RecipeStepsSection(recipe: SeasonRecipe) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "Passaggi",
            style = MaterialTheme.typography.titleLarge,
        )
        if (recipe.steps.isEmpty()) {
            SeasonStatusCard(
                title = "Passaggi da completare",
                body = "Questa ricetta non ha ancora passaggi strutturati.",
            )
        } else {
            LazyColumnStepItems(steps = recipe.steps)
        }
    }
}

@Composable
private fun LazyColumnStepItems(steps: List<String>) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        steps.forEachIndexed { index, step ->
            StepRow(number = index + 1, step = step)
        }
    }
}

@Composable
private fun StepRow(number: Int, step: String) {
    SeasonPanel {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        SeasonPill(text = number.toString(), emphasis = SeasonPillEmphasis.Primary)
        Text(
            modifier = Modifier.weight(1f),
            text = step,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
    }
}
