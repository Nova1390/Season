package it.seasonapp.season.features.profile

import androidx.compose.runtime.Composable
import it.seasonapp.season.features.auth.SeasonProfile
import it.seasonapp.season.navigation.SeasonScreenFrame
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun ProfileScreen(profile: SeasonProfile, onLogout: () -> Unit) {
    SeasonScreenFrame(
        title = "Profilo",
        subtitle = "Ciao @${profile.username ?: "season"}. Account base, avatar e ricette salvate/pubblicate. Nessuna governance catalogo in app.",
    ) {
        SeasonStatusCard(
            title = "Superficie consumer",
            body = "Android non esporrà strumenti catalog/admin; la console operativa resta catalog.seasonapp.it.",
            action = "Logout",
            onAction = onLogout,
        )
    }
}
