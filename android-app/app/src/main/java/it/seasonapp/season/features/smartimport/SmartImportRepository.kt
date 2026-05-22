package it.seasonapp.season.features.smartimport

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
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
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipes.SeasonRecipeIngredient
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.UUID

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

    suspend fun publishDraft(draft: SmartImportDraft, sourceUrl: String?): SeasonRecipe {
        val blockReason = draft.publishBlockReason
        require(blockReason == null) { blockReason ?: "Bozza non pubblicabile." }
        client.auth.awaitInitialization()
        checkNotNull(client.auth.currentSessionOrNull()) {
            "Sessione richiesta per pubblicare."
        }
        client.auth.refreshCurrentSession()
        val user = checkNotNull(client.auth.currentUserOrNull()) {
            "Utente richiesto per pubblicare."
        }
        val recipeId = UUID.randomUUID().toString()
        val createdAt = Instant.now().toString()
        val payload = RecipePublishPayload(
            id = recipeId,
            userId = user.id,
            title = draft.title.trim(),
            ingredients = draft.ingredients.map { ingredient ->
                RecipeIngredientPublishPayload(
                    ingredientId = ingredient.matchedIngredientId?.trim()?.takeIf { it.isNotEmpty() },
                    name = ingredient.name.trim(),
                    quantityValue = ingredient.quantity?.takeIf { it > 0 },
                    quantityUnit = ingredient.unit?.trim()?.takeIf { it.isNotEmpty() },
                )
            },
            steps = draft.steps.mapNotNull { it.trim().takeIf(String::isNotEmpty) },
            servings = draft.servings.coerceAtLeast(1),
            sourceUrl = sourceUrl?.trim()?.takeIf { it.isNotEmpty() },
            sourceName = "Season Smart Import",
            sourceType = "user_generated",
            createdAt = createdAt,
        )
        client
            .from("recipes")
            .insert(payload)
        return SeasonRecipe(
            id = recipeId,
            userId = user.id,
            title = draft.title.trim(),
            creatorName = "Season Smart Import",
            sourceName = "Season Smart Import",
            sourceType = "user_generated",
            imageUrl = null,
            servings = draft.servings.coerceAtLeast(1),
            ingredients = draft.ingredients.map { ingredient ->
                SeasonRecipeIngredient(
                    ingredientId = ingredient.matchedIngredientId?.trim()?.takeIf { it.isNotEmpty() },
                    name = ingredient.name.trim(),
                    quantityValue = ingredient.quantity?.takeIf { it > 0 },
                    quantityUnit = ingredient.unit?.trim()?.takeIf { it.isNotEmpty() },
                )
            },
            steps = draft.steps.mapNotNull { it.trim().takeIf(String::isNotEmpty) },
            createdAt = createdAt,
        )
    }
}
