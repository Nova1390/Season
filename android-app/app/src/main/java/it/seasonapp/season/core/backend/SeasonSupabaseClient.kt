package it.seasonapp.season.core.backend

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.SettingsSessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.github.jan.supabase.postgrest.Postgrest
import it.seasonapp.season.BuildConfig
import it.seasonapp.season.core.env.SeasonEnvironment

object SeasonSupabaseClient {
    private val environment: SeasonEnvironment
        get() = SeasonEnvironment.current

    val isConfigured: Boolean
        get() = environment.isConfigured

    val client: SupabaseClient by lazy {
        require(environment.isConfigured) {
            "Supabase is not configured for ${BuildConfig.SEASON_ENVIRONMENT}."
        }

        createSupabaseClient(
            supabaseUrl = environment.supabaseUrl,
            supabaseKey = BuildConfig.SEASON_SUPABASE_ANON_KEY,
        ) {
            defaultLogLevel = LogLevel.NONE
            install(Auth) {
                sessionManager = SettingsSessionManager()
                autoLoadFromStorage = true
                autoSaveToStorage = true
            }
            install(Postgrest)
        }
    }
}
