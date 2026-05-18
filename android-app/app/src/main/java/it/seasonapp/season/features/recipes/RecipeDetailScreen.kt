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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun RecipeDetailScreen(recipe: SeasonRecipe) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { RecipeDetailHeader(recipe = recipe) }
        item { RecipeIngredientSection(recipe = recipe) }
        item { RecipeStepsSection(recipe = recipe) }
    }
}

@Composable
private fun RecipeDetailHeader(recipe: SeasonRecipe) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Column(
            modifier = Modifier.padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = recipe.displaySource,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                if (recipe.isExternal) {
                    Text(
                        text = "Ricetta esterna",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Text(
                text = recipe.title,
                style = MaterialTheme.typography.displaySmall,
            )
            Text(
                text = "Per ${recipe.servings} persone · ${recipe.ingredients.size} ingredienti · ${recipe.steps.size} passaggi",
                style = MaterialTheme.typography.bodyLarge,
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
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
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
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = number.toString(),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                modifier = Modifier.weight(1f),
                text = step,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}
