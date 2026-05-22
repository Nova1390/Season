package it.seasonapp.season.features.shopping

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import it.seasonapp.season.core.backend.SeasonSupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

class ShoppingRepository {
    private val client
        get() = SeasonSupabaseClient.client

    suspend fun fetchItems(userId: String): List<ShoppingItem> {
        ensureFreshSession()
        return client
            .from("shopping_list_items")
            .select {
                filter {
                    eq("user_id", userId)
                }
            }
            .decodeList<ShoppingItemRow>()
            .map { it.toDomain() }
            .sortedWith(
                compareBy<ShoppingItem> { it.isChecked }
                    .thenBy { it.customName ?: it.ingredientId.orEmpty() }
                    .thenBy { it.id },
            )
    }

    suspend fun addItem(userId: String, request: ShoppingAddRequest) {
        ensureFreshSession()
        val now = Instant.now().toString()
        client
            .from("shopping_list_items")
            .insert(
                ShoppingItemInsertPayload(
                    id = UUID.randomUUID().toString(),
                    userId = userId,
                    ingredientType = request.ingredientType,
                    ingredientId = request.ingredientId,
                    customName = request.customName,
                    quantity = request.quantity,
                    unit = request.unit,
                    sourceRecipeId = request.sourceRecipeId,
                    isChecked = false,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
    }

    suspend fun updateChecked(userId: String, itemId: String, isChecked: Boolean) {
        ensureFreshSession()
        client
            .from("shopping_list_items")
            .update(
                ShoppingItemUpdatePayload(
                    isChecked = isChecked,
                    updatedAt = Instant.now().toString(),
                ),
            ) {
                filter {
                    eq("id", itemId)
                    eq("user_id", userId)
                }
            }
    }

    suspend fun removeItem(userId: String, itemId: String) {
        ensureFreshSession()
        client
            .from("shopping_list_items")
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
            "Authenticated session required for shopping sync."
        }
        client.auth.refreshCurrentSession()
    }
}

@Serializable
private data class ShoppingItemRow(
    val id: String,
    @SerialName("ingredient_type") val ingredientType: String,
    @SerialName("ingredient_id") val ingredientId: String? = null,
    @SerialName("custom_name") val customName: String? = null,
    val quantity: Double? = null,
    val unit: String? = null,
    @SerialName("source_recipe_id") val sourceRecipeId: String? = null,
    @SerialName("is_checked") val isChecked: Boolean = false,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    fun toDomain() = ShoppingItem(
        id = id,
        ingredientType = ingredientType,
        ingredientId = ingredientId?.trim()?.takeIf { it.isNotEmpty() },
        customName = customName?.trim()?.takeIf { it.isNotEmpty() },
        quantity = quantity,
        unit = unit?.trim()?.takeIf { it.isNotEmpty() },
        sourceRecipeId = sourceRecipeId?.trim()?.takeIf { it.isNotEmpty() },
        isChecked = isChecked,
        updatedAt = updatedAt,
    )
}

@Serializable
private data class ShoppingItemInsertPayload(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("ingredient_type") val ingredientType: String,
    @SerialName("ingredient_id") val ingredientId: String?,
    @SerialName("custom_name") val customName: String?,
    val quantity: Double?,
    val unit: String?,
    @SerialName("source_recipe_id") val sourceRecipeId: String?,
    @SerialName("is_checked") val isChecked: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
private data class ShoppingItemUpdatePayload(
    @SerialName("is_checked") val isChecked: Boolean,
    @SerialName("updated_at") val updatedAt: String,
)
