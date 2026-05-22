package it.seasonapp.season.features.shopping

import android.content.Context
import it.seasonapp.season.core.sync.SeasonOutboxStore
import org.json.JSONObject

class ShoppingOutboxStore(context: Context) {
    private val store = SeasonOutboxStore(
        context = context,
        namespace = "shopping",
        mergeKey = ShoppingOutboxIntent::mergeKey,
        toJson = ::toJson,
        fromJson = ::fromJson,
    )

    fun load(userId: String): List<ShoppingOutboxIntent> = store.load(userId)

    fun upsert(userId: String, intent: ShoppingOutboxIntent) {
        store.upsert(userId, intent)
    }

    fun replace(userId: String, intents: List<ShoppingOutboxIntent>) {
        store.replace(userId, intents)
    }

    fun clear(userId: String) {
        store.clear(userId)
    }

    private fun toJson(intent: ShoppingOutboxIntent): JSONObject {
        return JSONObject()
            .put("action", intent.action.name)
            .put("targetChecked", intent.targetChecked ?: JSONObject.NULL)
            .put("createdAtMillis", intent.createdAtMillis)
            .put("attemptCount", intent.attemptCount)
            .put("lastErrorType", intent.lastErrorType.orEmpty())
            .put("item", intent.item.toJson())
    }

    private fun fromJson(json: JSONObject): ShoppingOutboxIntent? {
        val action = runCatching {
            ShoppingOutboxAction.valueOf(json.optString("action"))
        }.getOrNull() ?: return null
        val item = json.optJSONObject("item")?.toShoppingItem() ?: return null
        return ShoppingOutboxIntent(
            action = action,
            item = item,
            targetChecked = if (json.isNull("targetChecked")) null else json.optBoolean("targetChecked"),
            createdAtMillis = json.optLong("createdAtMillis"),
            attemptCount = json.optInt("attemptCount"),
            lastErrorType = json.optString("lastErrorType").takeIf { it.isNotBlank() },
        )
    }
}

private fun ShoppingItem.toJson(): JSONObject {
    return JSONObject()
        .put("id", id)
        .put("ingredientType", ingredientType)
        .put("ingredientId", ingredientId.orEmpty())
        .put("customName", customName.orEmpty())
        .put("quantity", quantity ?: JSONObject.NULL)
        .put("unit", unit.orEmpty())
        .put("sourceRecipeId", sourceRecipeId.orEmpty())
        .put("isChecked", isChecked)
        .put("updatedAt", updatedAt.orEmpty())
}

private fun JSONObject.toShoppingItem(): ShoppingItem? {
    val id = optString("id").takeIf { it.isNotBlank() } ?: return null
    val ingredientType = optString("ingredientType").takeIf { it.isNotBlank() } ?: return null
    return ShoppingItem(
        id = id,
        ingredientType = ingredientType,
        ingredientId = optString("ingredientId").takeIf { it.isNotBlank() },
        customName = optString("customName").takeIf { it.isNotBlank() },
        quantity = if (isNull("quantity")) null else optDouble("quantity").takeIf { it > 0 },
        unit = optString("unit").takeIf { it.isNotBlank() },
        sourceRecipeId = optString("sourceRecipeId").takeIf { it.isNotBlank() },
        isChecked = optBoolean("isChecked"),
        updatedAt = optString("updatedAt").takeIf { it.isNotBlank() },
    )
}
