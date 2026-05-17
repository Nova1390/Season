package it.seasonapp.season.core.logging

import android.util.Log
import it.seasonapp.season.BuildConfig

object SeasonLog {
    private const val tag = "Season"

    fun debug(message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, redact(message))
        }
    }

    fun warning(message: String) {
        if (BuildConfig.DEBUG) {
            Log.w(tag, redact(message))
        }
    }

    private fun redact(message: String): String {
        return message
            .replace(Regex("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", RegexOption.IGNORE_CASE), "[redacted-email]")
            .replace(Regex("https?://\\S+"), "[redacted-url]")
            .replace(Regex("eyJ[\\w.-]+"), "[redacted-token]")
    }
}

