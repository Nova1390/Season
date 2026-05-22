package it.seasonapp.season.features.create

import androidx.compose.runtime.Composable
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.smartimport.SmartImportScreen

@Composable
fun CreateScreen(onRecipePublished: (SeasonRecipe) -> Unit = {}) {
    SmartImportScreen(onRecipePublished = onRecipePublished)
}
