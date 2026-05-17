package it.seasonapp.season.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import it.seasonapp.season.navigation.EnvironmentCard
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun AuthGateScreen(onContinueAsDev: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(28.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
    ) {
        Text(
            text = "Season.",
            style = androidx.compose.material3.MaterialTheme.typography.displaySmall,
        )
        Text(
            text = "Cook with the land, not against it.",
            style = androidx.compose.material3.MaterialTheme.typography.bodyLarge,
            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SeasonStatusCard(
            title = "Android MVP foundation",
            body = "La shell è pronta per collegare Google Sign-In, Supabase Auth e username onboarding senza esporre superfici admin.",
        )
        EnvironmentCard()
        Button(
            onClick = onContinueAsDev,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Entra nella shell dev")
        }
        OutlinedButton(
            onClick = {},
            enabled = false,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Google Sign-In sarà collegato nella fase Auth")
        }
    }
}

