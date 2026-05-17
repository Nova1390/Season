package it.seasonapp.season.features.home

import androidx.compose.runtime.Composable
import it.seasonapp.season.navigation.EnvironmentCard
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun HomeScreen() {
    SeasonScreenFrame(
        title = "Il meglio di stagione, proprio ora.",
        subtitle = "La Home Android partirà da ricette Supabase, ranking stabile e sezioni essenziali prima della rifinitura editoriale.",
    ) {
        EnvironmentCard()
        SeasonStatusCard(
            title = "Prossimo collegamento",
            body = "Repository ricette remoto, hero recipe, sezioni consigliate e stagionali, senza seed locali come source of truth.",
        )
    }
}

