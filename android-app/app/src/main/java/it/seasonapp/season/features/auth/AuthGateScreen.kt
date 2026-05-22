package it.seasonapp.season.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import it.seasonapp.season.core.design.SeasonCanvas
import it.seasonapp.season.core.design.SeasonKicker
import it.seasonapp.season.core.design.SeasonPanel
import it.seasonapp.season.navigation.EnvironmentCard
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun AuthGateScreen(
    state: AuthUiState,
    onGoogleSignIn: () -> Unit,
    onEmailSignIn: (String, String) -> Unit,
    onEmailSignUp: (String, String) -> Unit,
    onSaveUsername: (String) -> Unit,
) {
    SeasonCanvas {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
        ) {
            SeasonKicker(text = "Season Android")
            Text(
                text = "Season.",
                style = androidx.compose.material3.MaterialTheme.typography.displaySmall,
            )
            Text(
                text = "Cook with the land, not against it.",
                style = androidx.compose.material3.MaterialTheme.typography.bodyLarge,
                color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
            )

            when (state) {
                AuthUiState.Loading -> LoadingAuthCard()
                is AuthUiState.SignedOut -> SignedOutAuthForm(
                    state = state,
                    onGoogleSignIn = onGoogleSignIn,
                    onEmailSignIn = onEmailSignIn,
                    onEmailSignUp = onEmailSignUp,
                )
                is AuthUiState.NeedsUsername -> UsernameForm(
                    state = state,
                    onSaveUsername = onSaveUsername,
                )
                is AuthUiState.SignedIn -> SeasonStatusCard(
                    title = "Sessione attiva",
                    body = "Stiamo aprendo Season.",
                )
            }
        }
    }
}

@Composable
private fun LoadingAuthCard() {
    SeasonStatusCard(
        title = "Controllo sessione",
        body = "Verifico se hai già una sessione Supabase valida su questo dispositivo.",
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun SignedOutAuthForm(
    state: AuthUiState.SignedOut,
    onGoogleSignIn: () -> Unit,
    onEmailSignIn: (String, String) -> Unit,
    onEmailSignUp: (String, String) -> Unit,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    SeasonPanel(prominent = true) {
        SeasonKicker(text = "Accesso Season-dev")
        Text(
            text = state.message ?: "Accedi con Google o email per iniziare i test backend reali.",
            style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(
            onClick = onGoogleSignIn,
            enabled = state.isBackendConfigured && state.isGoogleConfigured,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Continua con Google")
        }
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Email") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Password") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Button(
                onClick = { onEmailSignIn(email, password) },
                enabled = state.isBackendConfigured && email.isNotBlank() && password.length >= 6,
                modifier = Modifier.weight(1f),
            ) {
                Text("Accedi")
            }
            OutlinedButton(
                onClick = { onEmailSignUp(email, password) },
                enabled = state.isBackendConfigured && email.isNotBlank() && password.length >= 6,
                modifier = Modifier.weight(1f),
            ) {
                Text("Registrati")
            }
        }
    }
    EnvironmentCard()
}

@Composable
private fun UsernameForm(
    state: AuthUiState.NeedsUsername,
    onSaveUsername: (String) -> Unit,
) {
    var username by rememberSaveable {
        mutableStateOf(state.profile.username.orEmpty())
    }

    SeasonStatusCard(
        title = "Scegli username",
        body = state.message ?: "Serve uno username per completare il profilo Season.",
    )
    OutlinedTextField(
        value = username,
        onValueChange = { username = it },
        modifier = Modifier.fillMaxWidth(),
        label = { Text("Username") },
        prefix = { Text("@") },
        singleLine = true,
    )
    Button(
        onClick = { onSaveUsername(username) },
        enabled = !state.isSaving && username.trim().removePrefix("@").length >= 3,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(if (state.isSaving) "Salvataggio..." else "Salva username")
    }
}
