package it.seasonapp.season.features.auth

import android.content.Context
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import it.seasonapp.season.core.env.SeasonEnvironment

class GoogleIdentityClient(
    private val credentialManager: CredentialManager,
) {
    suspend fun requestIdToken(context: Context): String {
        val clientId = SeasonEnvironment.current.googleWebClientId
        require(clientId.isNotBlank()) {
            "Configura SEASON_GOOGLE_WEB_CLIENT_ID prima di usare Google Sign-In."
        }

        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(clientId)
            .setAutoSelectEnabled(false)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val result = credentialManager.getCredential(context, request)
        val credential = result.credential

        if (credential is CustomCredential &&
            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            try {
                return GoogleIdTokenCredential
                    .createFrom(credential.data)
                    .idToken
            } catch (error: GoogleIdTokenParsingException) {
                throw IllegalStateException("Google Sign-In non ha restituito un token valido.", error)
            }
        }

        throw IllegalStateException("Credenziale Google non supportata.")
    }

    suspend fun clearCredentialState() {
        credentialManager.clearCredentialState(ClearCredentialStateRequest())
    }
}
