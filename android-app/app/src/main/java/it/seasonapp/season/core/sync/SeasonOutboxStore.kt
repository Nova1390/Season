package it.seasonapp.season.core.sync

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class SeasonOutboxStore<T>(
    context: Context,
    namespace: String,
    private val mergeKey: (T) -> String,
    private val toJson: (T) -> JSONObject,
    private val fromJson: (JSONObject) -> T?,
) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "season_${namespace}_outbox",
        Context.MODE_PRIVATE,
    )

    fun load(userId: String): List<T> {
        val raw = preferences.getString(key(userId), null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    fromJson(item)?.let(::add)
                }
            }
        }.getOrDefault(emptyList())
    }

    fun upsert(userId: String, intent: T) {
        val nextKey = mergeKey(intent)
        val merged = load(userId)
            .filterNot { mergeKey(it) == nextKey }
            .plus(intent)
        save(userId, merged)
    }

    fun replace(userId: String, intents: List<T>) {
        val latestByKey = intents.associateBy(mergeKey).values.toList()
        save(userId, latestByKey)
    }

    fun clear(userId: String) {
        preferences.edit().remove(key(userId)).apply()
    }

    fun clearAll() {
        preferences.edit().clear().apply()
    }

    private fun save(userId: String, intents: Collection<T>) {
        val array = JSONArray()
        intents.forEach { array.put(toJson(it)) }
        preferences.edit().putString(key(userId), array.toString()).apply()
    }

    private fun key(userId: String): String = "pending:$userId"
}
