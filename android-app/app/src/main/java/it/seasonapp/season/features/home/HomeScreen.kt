package it.seasonapp.season.features.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.res.painterResource
import it.seasonapp.season.R
import it.seasonapp.season.core.design.SeasonDot
import it.seasonapp.season.core.design.SeasonKicker
import it.seasonapp.season.core.design.SeasonPanel
import it.seasonapp.season.core.design.SeasonPill
import it.seasonapp.season.core.design.SeasonPillEmphasis
import it.seasonapp.season.core.design.SeasonRecipeArtwork
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.navigation.EnvironmentCard
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun HomeScreen(
    onRecipeSelected: (SeasonRecipe) -> Unit,
    homeViewModel: HomeViewModel = viewModel(),
) {
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
            onRecipeSelected = onRecipeSelected,
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
private fun HomeContent(
    snapshot: HomeSnapshot,
    onRefresh: () -> Unit,
    onRecipeSelected: (SeasonRecipe) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 22.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item { HomeHeader() }

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
            item { HeroRecipeCard(recipe = hero, onClick = { onRecipeSelected(hero) }) }
            item { HomeIngredientRail() }
            item {
                HomeActivityCard(
                    totalRecipes = snapshot.totalCount,
                    externalCount = snapshot.externalCount,
                    onRefresh = onRefresh,
                )
            }
        }

        if (snapshot.recommended.isNotEmpty()) {
            item {
                SectionHeader(title = "Di tendenza ora", count = "${snapshot.recommended.size} ricette")
            }
            items(snapshot.recommended, key = { it.id }) { recipe ->
                RecipeRowCard(recipe = recipe, onClick = { onRecipeSelected(recipe) })
            }
        }
    }
}

@Composable
private fun HomeHeader() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SeasonDot()
            SeasonKicker(text = "Maggio · Settimana 21")
        }
        Text(
            text = "Buongiorno, cosa cuciniamo con quello che hai?",
            style = MaterialTheme.typography.headlineMedium,
        )
    }
}

@Composable
private fun HeroRecipeCard(recipe: SeasonRecipe, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.62f)),
    ) {
        Column {
            SeasonRecipeArtwork(
                title = recipe.title,
                imageUrl = recipe.imageUrl,
                heightDp = 214,
                badgeText = "Perfetta per stasera",
            )
            Column(
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SeasonPill(text = "Di tendenza", emphasis = SeasonPillEmphasis.Primary)
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = recipe.displaySource,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        text = if (recipe.isExternal) "Fonte esterna" else "Creator Season",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    text = recipe.title,
                    style = MaterialTheme.typography.headlineMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "Ricetta esterna · Per ${recipe.servings} persone",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                IngredientPreview(recipe = recipe, maxLines = 1)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onClick,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.onSurface,
                            contentColor = MaterialTheme.colorScheme.surface,
                        ),
                        contentPadding = PaddingValues(vertical = 15.dp),
                    ) {
                        Text("Inizia a cucinare  →")
                    }
                    Surface(
                        modifier = Modifier.size(56.dp),
                        shape = RoundedCornerShape(18.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.28f)),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text("♡", style = MaterialTheme.typography.titleLarge)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RecipeRowCard(recipe: SeasonRecipe, onClick: () -> Unit) {
    SeasonPanel(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SeasonRecipeArtwork(
                title = recipe.title,
                imageUrl = recipe.imageUrl,
                modifier = Modifier.width(92.dp),
                heightDp = 92,
                badgeText = "",
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(7.dp),
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
private fun HomeIngredientRail() {
    val assets = listOf(
        R.drawable.basil to "Basilico",
        R.drawable.tomato to "Pomodori",
        R.drawable.zucchini to "Zucchine",
        R.drawable.potato to "Patate",
        R.drawable.arugula to "Rucola",
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        assets.forEach { (asset, label) ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(58.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f))
                        .padding(8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(asset),
                        contentDescription = label,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeActivityCard(totalRecipes: Int, externalCount: Int, onRefresh: () -> Unit) {
    SeasonPanel {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                SeasonKicker(text = "In cucina ora")
                Text(
                    text = "$totalRecipes ricette attive",
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = "$externalCount fonti esterne riconosciute oggi",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Button(onClick = onRefresh, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)) {
                Text("Aggiorna")
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String, count: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = title, style = MaterialTheme.typography.titleLarge)
        SeasonKicker(text = count)
    }
}

@Composable
private fun IngredientPreview(recipe: SeasonRecipe, maxLines: Int = 2) {
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
            maxLines = maxLines,
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
