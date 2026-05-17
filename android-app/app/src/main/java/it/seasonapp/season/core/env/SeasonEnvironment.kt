package it.seasonapp.season.core.env

import it.seasonapp.season.BuildConfig

enum class SeasonEnvironmentKind {
    LocalDebug,
    Dev,
    Staging,
    Production,
}

data class SeasonEnvironment(
    val kind: SeasonEnvironmentKind,
    val supabaseUrl: String,
    val hasAnonKey: Boolean,
) {
    val isConfigured: Boolean
        get() = supabaseUrl.isNotBlank() && hasAnonKey

    companion object {
        val current: SeasonEnvironment
            get() = SeasonEnvironment(
                kind = when (BuildConfig.SEASON_ENVIRONMENT) {
                    "dev" -> SeasonEnvironmentKind.Dev
                    "staging" -> SeasonEnvironmentKind.Staging
                    "production" -> SeasonEnvironmentKind.Production
                    else -> SeasonEnvironmentKind.LocalDebug
                },
                supabaseUrl = BuildConfig.SEASON_SUPABASE_URL,
                hasAnonKey = BuildConfig.SEASON_SUPABASE_ANON_KEY.isNotBlank(),
            )
    }
}

