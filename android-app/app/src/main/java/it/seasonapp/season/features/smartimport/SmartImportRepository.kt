package it.seasonapp.season.features.smartimport

import io.github.jan.supabase.auth.auth
import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import it.seasonapp.season.BuildConfig
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import it.seasonapp.season.core.env.SeasonEnvironment
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class SmartImportRepository(
    private val httpClient: HttpClient = HttpClient(Android),
) {
    private val client
        get() = SeasonSupabaseClient.client

    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    suspend fun parseCaption(caption: String, sourceUrl: String?): SmartImportDraft {
        val cleanCaption = caption.trim()
        require(cleanCaption.isNotEmpty()) { "Inserisci una caption o una lista ingredienti." }
        client.auth.awaitInitialization()
        val session = checkNotNull(client.auth.currentSessionOrNull()) {
            "Sessione richiesta per Smart Import."
        }
        client.auth.refreshCurrentSession()
        val accessToken = client.auth.currentSessionOrNull()?.accessToken ?: session.accessToken
        val environment = SeasonEnvironment.current
        check(environment.supabaseUrl.isNotBlank() && BuildConfig.SEASON_SUPABASE_ANON_KEY.isNotBlank()) {
            "Supabase non configurato per Smart Import."
        }

        val request = ParseRecipeCaptionRequest(
            caption = cleanCaption,
            url = sourceUrl?.trim()?.takeIf { it.isNotEmpty() },
            languageCode = "it",
        )
        val response = httpClient.post("${environment.supabaseUrl}/functions/v1/parse-recipe-caption") {
            contentType(ContentType.Application.Json)
            header(HttpHeaders.Authorization, "Bearer $accessToken")
            header("apikey", BuildConfig.SEASON_SUPABASE_ANON_KEY)
            setBody(json.encodeToString(request))
        }
        val body = response.bodyAsText()
        val parsed = runCatching {
            json.decodeFromString<ParseRecipeCaptionResponse>(body)
        }.getOrElse {
            throw IllegalStateException("Risposta Smart Import non leggibile.")
        }
        if (!response.status.isSuccess() || !parsed.ok) {
            throw IllegalStateException(parsed.error?.message ?: "Smart Import non riuscito.")
        }
        return checkNotNull(parsed.result) { "Smart Import non ha restituito una bozza." }.toDraft()
    }
}
