package it.seasonapp.season.features.smartimport

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SmartImportModelsTest {
    @Test
    fun `risotto draft preserves title servings quantities and steps`() {
        val draft = ParseRecipeCaptionResult(
            title = "Risotto ai funghi",
            servings = 2,
            confidence = "high",
            ingredients = listOf(
                ingredient("Riso", 180.0, "g", "catalog", "rice"),
                ingredient("Funghi", 250.0, "g", "catalog", "mushroom"),
                ingredient("Brodo vegetale", 700.0, "ml", "catalog", "vegetable_stock"),
                ingredient("Burro", 20.0, "g", "catalog", "butter"),
                ingredient("Parmigiano", 30.0, "g", "catalog", "parmesan"),
            ),
            steps = listOf(
                "Tosta il riso.",
                "Aggiungi i funghi.",
                "Cuoci con il brodo poco alla volta e manteca.",
            ),
        ).toDraft()

        assertEquals("Risotto ai funghi", draft.title)
        assertEquals(2, draft.servings)
        assertEquals(5, draft.ingredients.size)
        assertEquals("180 g", draft.ingredients.first { it.name == "Riso" }.quantityText)
        assertEquals("700 ml", draft.ingredients.first { it.name == "Brodo vegetale" }.quantityText)
        assertEquals(3, draft.steps.size)
        assertNull(draft.publishBlockReason)
    }

    @Test
    fun `dedupe keeps the richer quantity for repeated catalog ingredients`() {
        val draft = ParseRecipeCaptionResult(
            title = "Pasta al burro",
            servings = 2,
            confidence = "medium",
            ingredients = listOf(
                ingredient("Burro", null, null, "catalog", "butter"),
                ingredient("Burro", 20.0, "g", "catalog", "butter"),
                ingredient("Pasta", 160.0, "g", "catalog", "pasta"),
            ),
            steps = listOf("Cuoci la pasta e manteca con burro."),
        ).toDraft()

        assertEquals(2, draft.ingredients.size)
        assertEquals("20 g", draft.ingredients.first { it.name == "Burro" }.quantityText)
    }

    @Test
    fun `publish is blocked when preparation steps are missing but ingredients stay readable`() {
        val draft = ParseRecipeCaptionResult(
            title = "Insalata di pollo",
            servings = 2,
            confidence = "high",
            ingredients = listOf(
                ingredient("Pollo grigliato", 250.0, "g", "needs_confirmation", null),
                ingredient("Lattuga", 120.0, "g", "catalog", "lettuce"),
            ),
            steps = emptyList(),
        ).toDraft()

        assertEquals(2, draft.ingredients.size)
        assertEquals("250 g", draft.ingredients.first().quantityText)
        assertEquals("Mancano i passaggi di preparazione.", draft.publishBlockReason)
    }

    @Test
    fun `inferred dish is used as fallback title instead of untitled recipe`() {
        val draft = ParseRecipeCaptionResult(
            title = null,
            inferredDish = "Pancake banana e avena",
            servings = 2,
            confidence = "medium",
            ingredients = listOf(
                ingredient("Banana", 1.0, "piece", "catalog", "banana"),
                ingredient("Uova", 2.0, "piece", "catalog", "eggs"),
            ),
            steps = listOf("Frulla tutto e cuoci in padella."),
        ).toDraft()

        assertEquals("Pancake banana e avena", draft.title)
        assertNull(draft.publishBlockReason)
    }

    private fun ingredient(
        name: String,
        quantity: Double?,
        unit: String?,
        status: String?,
        matchedIngredientId: String?,
    ): ParseRecipeCaptionIngredient {
        return ParseRecipeCaptionIngredient(
            name = name,
            quantity = quantity,
            unit = unit,
            status = status,
            matchType = if (matchedIngredientId == null) null else "catalog",
            matchedIngredientId = matchedIngredientId,
        )
    }
}
