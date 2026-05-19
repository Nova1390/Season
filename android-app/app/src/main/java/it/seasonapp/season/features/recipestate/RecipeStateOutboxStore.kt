package it.seasonapp.season.features.recipestate

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class RecipeStateOutboxStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "season_recipe_state_outbox",
        Context.MODE_PRIVATE,
    )

    fun load(userId: String): List<RecipeStateOutboxIntent> {
        val raw = preferences.getString(key(userId), null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val field = when (item.optString("field")) {
                        RecipeStateField.Saved.remoteName -> RecipeStateField.Saved
                        RecipeStateField.Crispied.remoteName -> RecipeStateField.Crispied
                        else -> null
                    } ?: continue
                    val recipeId = item.optString("recipeId").takeIf { it.isNotBlank() } ?: continue
                    add(
                        RecipeStateOutboxIntent(
                            recipeId = recipeId,
                            stateField = field,
                            targetValue = item.optBoolean("targetValue"),
                            createdAtMillis = item.optLong("createdAtMillis"),
                            attemptCount = item.optInt("attemptCount"),
                            lastErrorType = item.optString("lastErrorType").takeIf { it.isNotBlank() },
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun upsert(userId: String, intent: RecipeStateOutboxIntent) {
        val merged = load(userId)
            .filterNot { it.mergeKey == intent.mergeKey }
            .plus(intent)
            .sortedBy { it.createdAtMillis }
        save(userId, merged)
    }

    fun replace(userId: String, intents: List<RecipeStateOutboxIntent>) {
        val latestByKey = intents.associateBy { it.mergeKey }.values.sortedBy { it.createdAtMillis }
        save(userId, latestByKey)
    }

    fun clear(userId: String) {
        preferences.edit().remove(key(userId)).apply()
    }

    fun clearAll() {
        preferences.edit().clear().apply()
    }

    private fun save(userId: String, intents: Collection<RecipeStateOutboxIntent>) {
        val array = JSONArray()
        intents.forEach { intent ->
            array.put(
                JSONObject()
                    .put("recipeId", intent.recipeId)
                    .put("field", intent.stateField.remoteName)
                    .put("targetValue", intent.targetValue)
                    .put("createdAtMillis", intent.createdAtMillis)
                    .put("attemptCount", intent.attemptCount)
                    .put("lastErrorType", intent.lastErrorType.orEmpty()),
            )
        }
        preferences.edit().putString(key(userId), array.toString()).apply()
    }

    private fun key(userId: String): String = "pending:$userId"
}
