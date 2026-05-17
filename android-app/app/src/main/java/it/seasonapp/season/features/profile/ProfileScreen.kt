package it.seasonapp.season.features.profile

import androidx.compose.runtime.Composable
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun ProfileScreen(onLogout: () -> Unit) {
    SeasonScreenFrame(
        title = "Profilo",
        subtitle = "Account base, username, avatar e ricette salvate/pubblicate. Nessuna governance catalogo in app.",
    ) {
        SeasonStatusCard(
            title = "Superficie consumer",
            body = "Android non esporrà strumenti catalog/admin; la console operativa resta catalog.seasonapp.it.",
            action = "Logout dev",
            onAction = onLogout,
        )
    }
}

