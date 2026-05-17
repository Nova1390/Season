package it.seasonapp.season.features.auth

import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class ProfileRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchProfile(userId: String): SeasonProfile? {
        val rows = client
            .from("profiles")
            .select {
                filter {
                    eq("id", userId)
                }
                limit(1)
            }
            .decodeList<ProfileRow>()

        return rows.firstOrNull()?.toDomain()
    }

    suspend fun bootstrapProfile(userId: String, displayName: String?, preferredLanguage: String = "it"): SeasonProfile {
        val existing = fetchProfile(userId)
        if (existing != null) return existing

        val payload = ProfileUpsertPayload(
            id = userId,
            displayName = displayName?.takeIf { it.isNotBlank() },
            seasonUsername = null,
            preferredLanguage = preferredLanguage,
        )

        client
            .from("profiles")
            .upsert(payload) {
                onConflict = "id"
            }

        return fetchProfile(userId) ?: SeasonProfile(
            id = userId,
            displayName = displayName,
            username = null,
            avatarUrl = null,
            preferredLanguage = preferredLanguage,
        )
    }

    suspend fun saveUsername(userId: String, username: String, displayName: String?): SeasonProfile {
        val normalized = normalizeUsername(username)
        require(normalized.length in 3..24) { "Lo username deve avere tra 3 e 24 caratteri." }
        require(normalized.all { it.isLetterOrDigit() || it == '_' }) {
            "Usa solo lettere, numeri e underscore."
        }

        val payload = ProfileUpsertPayload(
            id = userId,
            displayName = displayName?.takeIf { it.isNotBlank() } ?: normalized,
            seasonUsername = normalized,
            preferredLanguage = "it",
        )

        client
            .from("profiles")
            .upsert(payload) {
                onConflict = "id"
            }

        return fetchProfile(userId) ?: SeasonProfile(
            id = userId,
            displayName = payload.displayName,
            username = normalized,
            avatarUrl = null,
            preferredLanguage = payload.preferredLanguage,
        )
    }

    private fun normalizeUsername(value: String): String {
        return value
            .trim()
            .removePrefix("@")
            .lowercase()
    }
}

@Serializable
private data class ProfileRow(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("season_username") val seasonUsername: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("preferred_language") val preferredLanguage: String? = null,
) {
    fun toDomain(): SeasonProfile {
        return SeasonProfile(
            id = id,
            displayName = displayName,
            username = seasonUsername,
            avatarUrl = avatarUrl,
            preferredLanguage = preferredLanguage,
        )
    }
}

@Serializable
private data class ProfileUpsertPayload(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("season_username") val seasonUsername: String? = null,
    @SerialName("preferred_language") val preferredLanguage: String? = null,
)
