package it.seasonapp.season.features.create

import androidx.compose.runtime.Composable
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun CreateScreen() {
    SeasonScreenFrame(
        title = "Crea ricetta",
        subtitle = "Smart Import sarà il primo grande vantaggio Android: caption, bozza, correzione e publish.",
    ) {
        SeasonStatusCard(
            title = "Smart Import contract",
            body = "La fase dedicata userà parse-recipe-caption, dedupe per catalog id/nome normalizzato e blocco publish se mancano dati critici.",
        )
    }
}

