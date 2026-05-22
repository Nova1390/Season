package it.seasonapp.season.features.fridge

import android.content.Context
import it.seasonapp.season.core.sync.SeasonOutboxStore
import org.json.JSONObject

class FridgeOutboxStore(context: Context) {
    private val store = SeasonOutboxStore(
        context = context,
        namespace = "fridge",
        mergeKey = FridgeOutboxIntent::mergeKey,
        toJson = ::toJson,
        fromJson = ::fromJson,
    )

    fun load(userId: String): List<FridgeOutboxIntent> = store.load(userId)

    fun upsert(userId: String, intent: FridgeOutboxIntent) {
        store.upsert(userId, intent)
    }

    fun replace(userId: String, intents: List<FridgeOutboxIntent>) {
        store.replace(userId, intents)
    }

    fun clear(userId: String) {
        store.clear(userId)
    }

    private fun toJson(intent: FridgeOutboxIntent): JSONObject {
        return JSONObject()
            .put("action", intent.action.name)
            .put("createdAtMillis", intent.createdAtMillis)
            .put("attemptCount", intent.attemptCount)
            .put("lastErrorType", intent.lastErrorType.orEmpty())
            .put("item", intent.item.toJson())
    }

    private fun fromJson(json: JSONObject): FridgeOutboxIntent? {
        val action = runCatching {
            FridgeOutboxAction.valueOf(json.optString("action"))
        }.getOrNull() ?: return null
        val item = json.optJSONObject("item")?.toFridgeItem() ?: return null
        return FridgeOutboxIntent(
            action = action,
            item = item,
            createdAtMillis = json.optLong("createdAtMillis"),
            attemptCount = json.optInt("attemptCount"),
            lastErrorType = json.optString("lastErrorType").takeIf { it.isNotBlank() },
        )
    }
}

private fun FridgeItem.toJson(): JSONObject {
    return JSONObject()
        .put("id", id)
        .put("ingredientType", ingredientType)
        .put("ingredientId", ingredientId.orEmpty())
        .put("customName", customName.orEmpty())
        .put("quantity", quantity ?: JSONObject.NULL)
        .put("unit", unit.orEmpty())
        .put("updatedAt", updatedAt.orEmpty())
}

private fun JSONObject.toFridgeItem(): FridgeItem? {
    val id = optString("id").takeIf { it.isNotBlank() } ?: return null
    val ingredientType = optString("ingredientType").takeIf { it.isNotBlank() } ?: return null
    return FridgeItem(
        id = id,
        ingredientType = ingredientType,
        ingredientId = optString("ingredientId").takeIf { it.isNotBlank() },
        customName = optString("customName").takeIf { it.isNotBlank() },
        quantity = if (isNull("quantity")) null else optDouble("quantity").takeIf { it > 0 },
        unit = optString("unit").takeIf { it.isNotBlank() },
        updatedAt = optString("updatedAt").takeIf { it.isNotBlank() },
    )
}
