package it.seasonapp.season.features.fridge

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import it.seasonapp.season.features.catalog.CatalogIngredient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

class FridgeRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchItems(userId: String): List<FridgeItem> {
        ensureFreshSession()
        return client
            .from("fridge_items")
            .select {
                filter {
                    eq("user_id", userId)
                }
            }
            .decodeList<FridgeItemRow>()
            .map { it.toDomain() }
            .sortedWith(compareBy<FridgeItem> { it.customName ?: it.ingredientId.orEmpty() }.thenBy { it.id })
    }

    suspend fun addCatalogItem(userId: String, ingredient: CatalogIngredient) {
        ensureFreshSession()
        val now = Instant.now().toString()
        client
            .from("fridge_items")
            .insert(
                FridgeItemInsertPayload(
                    id = UUID.randomUUID().toString(),
                    userId = userId,
                    ingredientType = "catalog",
                    ingredientId = ingredient.id,
                    customName = null,
                    quantity = null,
                    unit = null,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
    }

    suspend fun addCustomItem(userId: String, name: String) {
        ensureFreshSession()
        val cleanName = name.trim()
        require(cleanName.isNotEmpty()) { "Custom ingredient name is required." }
        val now = Instant.now().toString()
        client
            .from("fridge_items")
            .insert(
                FridgeItemInsertPayload(
                    id = UUID.randomUUID().toString(),
                    userId = userId,
                    ingredientType = "custom",
                    ingredientId = null,
                    customName = cleanName,
                    quantity = null,
                    unit = null,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
    }

    suspend fun removeItem(userId: String, itemId: String) {
        ensureFreshSession()
        client
            .from("fridge_items")
            .delete {
                filter {
                    eq("id", itemId)
                    eq("user_id", userId)
                }
            }
    }

    private suspend fun ensureFreshSession() {
        client.auth.awaitInitialization()
        checkNotNull(client.auth.currentSessionOrNull()) {
            "Authenticated session required for fridge sync."
        }
        client.auth.refreshCurrentSession()
    }
}

@Serializable
private data class FridgeItemRow(
    val id: String,
    @SerialName("ingredient_type") val ingredientType: String,
    @SerialName("ingredient_id") val ingredientId: String? = null,
    @SerialName("custom_name") val customName: String? = null,
    val quantity: Double? = null,
    val unit: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    fun toDomain() = FridgeItem(
        id = id,
        ingredientType = ingredientType,
        ingredientId = ingredientId?.trim()?.takeIf { it.isNotEmpty() },
        customName = customName?.trim()?.takeIf { it.isNotEmpty() },
        quantity = quantity,
        unit = unit?.trim()?.takeIf { it.isNotEmpty() },
        updatedAt = updatedAt,
    )
}

@Serializable
private data class FridgeItemInsertPayload(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("ingredient_type") val ingredientType: String,
    @SerialName("ingredient_id") val ingredientId: String?,
    @SerialName("custom_name") val customName: String?,
    val quantity: Double?,
    val unit: String?,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)
