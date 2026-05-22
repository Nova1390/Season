package it.seasonapp.season.features.profile

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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.features.auth.SeasonProfile
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun ProfileScreen(
    profile: SeasonProfile,
    onRecipeSelected: (SeasonRecipe) -> Unit,
    onLogout: () -> Unit,
    profileViewModel: ProfileViewModel = viewModel(),
) {
    val state by profileViewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(profile.id) {
        profileViewModel.initialize(profile.id)
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            ProfileHeader(profile = profile, onRefresh = profileViewModel::refresh, onLogout = onLogout)
        }
        if (state.isLoading) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(strokeWidth = 2.dp)
                    Text("Carico ricette salvate e pubblicate…")
                }
            }
        }
        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(title = "Profilo non disponibile", body = message)
            }
        }
        item {
            RecipeSection(
                title = "Ricette salvate",
                emptyBody = "Salva ricette per ritrovarle qui.",
                recipes = state.dashboard.savedRecipes,
                onRecipeSelected = onRecipeSelected,
            )
        }
        item {
            RecipeSection(
                title = "Ricette pubblicate",
                emptyBody = "Quando pubblichi da Smart Import o iOS, le ricette appaiono qui.",
                recipes = state.dashboard.publishedRecipes,
                onRecipeSelected = onRecipeSelected,
            )
        }
        item {
            SeasonStatusCard(
                title = "Superficie consumer",
                body = "Android non espone strumenti catalog/admin; la console operativa resta catalog.seasonapp.it.",
            )
        }
    }
}

@Composable
private fun ProfileHeader(profile: SeasonProfile, onRefresh: () -> Unit, onLogout: () -> Unit) {
    ProfileCard {
        Text(text = "Profilo", style = MaterialTheme.typography.headlineMedium)
        Text(
            text = "Ciao @${profile.username ?: "season"}",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = onRefresh) {
                Text("Aggiorna")
            }
            TextButton(onClick = onLogout) {
                Text("Logout")
            }
        }
    }
}

@Composable
private fun RecipeSection(
    title: String,
    emptyBody: String,
    recipes: List<SeasonRecipe>,
    onRecipeSelected: (SeasonRecipe) -> Unit,
) {
    ProfileCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = title, style = MaterialTheme.typography.titleLarge)
            Text(
                text = recipes.size.toString(),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (recipes.isEmpty()) {
            Text(
                text = emptyBody,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            recipes.take(8).forEach { recipe ->
                RecipeProfileRow(recipe = recipe, onClick = { onRecipeSelected(recipe) })
            }
        }
    }
}

@Composable
private fun RecipeProfileRow(recipe: SeasonRecipe, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = recipe.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "${recipe.displaySource} · Per ${recipe.servings} persone",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ProfileCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            content()
        }
    }
}
