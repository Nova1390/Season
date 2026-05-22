package it.seasonapp.season.features.auth

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.Google
import it.seasonapp.season.core.backend.SeasonSupabaseClient

class AuthRepository(
    private val profileRepository: ProfileRepository = ProfileRepository(),
) {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun restoreSession(): AuthenticatedUser? {
        client.auth.awaitInitialization()
        val session = client.auth.currentSessionOrNull() ?: return null
        runCatching {
            client.auth.refreshCurrentSession()
        }.onFailure {
            client.auth.clearSession()
            return null
        }
        val user = client.auth.currentUserOrNull() ?: return null
        return AuthenticatedUser(
            id = user.id,
            displayName = user.userMetadata?.get("full_name")?.toString(),
        ).takeIf { it.id.isNotBlank() }
    }

    suspend fun signInWithGoogleIdToken(idToken: String): AuthenticatedUser {
        client.auth.signInWith(IDToken) {
            provider = Google
            this.idToken = idToken
        }
        return requireAuthenticatedUser()
    }

    suspend fun signInWithEmail(email: String, password: String): AuthenticatedUser {
        client.auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        return requireAuthenticatedUser()
    }

    suspend fun signUpWithEmail(email: String, password: String): AuthenticatedUser {
        client.auth.signUpWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        return requireAuthenticatedUser()
    }

    suspend fun signOut() {
        client.auth.signOut()
    }

    suspend fun bootstrapProfile(user: AuthenticatedUser): SeasonProfile {
        return profileRepository.bootstrapProfile(
            userId = user.id,
            displayName = user.displayName,
        )
    }

    suspend fun saveUsername(userId: String, username: String, displayName: String?): SeasonProfile {
        return profileRepository.saveUsername(
            userId = userId,
            username = username,
            displayName = displayName,
        )
    }

    private fun requireAuthenticatedUser(): AuthenticatedUser {
        val user = client.auth.currentUserOrNull()
            ?: throw IllegalStateException("Sessione Supabase non disponibile dopo il login.")

        return AuthenticatedUser(
            id = user.id,
            displayName = user.userMetadata?.get("full_name")?.toString()
                ?: user.userMetadata?.get("name")?.toString(),
        )
    }
}

data class AuthenticatedUser(
    val id: String,
    val displayName: String?,
)
