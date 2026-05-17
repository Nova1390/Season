package it.seasonapp.season.features.search

import androidx.compose.runtime.Composable
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun SearchScreen() {
    SeasonScreenFrame(
        title = "Scopri",
        subtitle = "Ricette e ingredienti useranno catalogo e ricette remote con debounce e filtri leggibili.",
    ) {
        SeasonStatusCard(
            title = "Contratto ricerca",
            body = "Search Android dovrà interrogare snapshot ricette e catalogo read-only, preservando ingredient_id e quantità.",
        )
    }
}

