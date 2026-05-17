package it.seasonapp.season.features.today

import androidx.compose.runtime.Composable
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun TodayScreen() {
    SeasonScreenFrame(
        title = "Oggi",
        subtitle = "La stagionalità Android distinguerà al meglio, primizie e fine stagione, senza appiattire tutto su “di stagione”.",
    ) {
        SeasonStatusCard(
            title = "Ranking stagionale",
            body = "La prima versione riuserà i dati stagionali esistenti e manterrà copy alimentare coerente con iOS.",
        )
    }
}

