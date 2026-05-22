package it.seasonapp.season.features.today

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.features.catalog.CatalogIngredient
import it.seasonapp.season.features.catalog.SeasonalIngredient
import it.seasonapp.season.features.catalog.SeasonalPhase
import it.seasonapp.season.core.design.SeasonKicker
import it.seasonapp.season.core.design.SeasonPanel
import it.seasonapp.season.core.design.SeasonPill
import it.seasonapp.season.core.design.SeasonPillEmphasis
import it.seasonapp.season.navigation.SeasonStatusCard
import java.time.Month
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun TodayScreen(todayViewModel: TodayViewModel = viewModel()) {
    val state by todayViewModel.uiState.collectAsStateWithLifecycle()
    var selectedIngredient by remember { mutableStateOf<CatalogIngredient?>(null) }

    selectedIngredient?.let { ingredient ->
        IngredientDetail(
            ingredient = ingredient,
            onBack = { selectedIngredient = null },
        )
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            TodayHeader(
                currentMonth = state.currentMonth,
                total = state.ingredients.size,
                isLoading = state.isLoading,
            )
        }

        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Oggi non caricato",
                    body = message,
                    action = "Riprova",
                    onAction = todayViewModel::refresh,
                )
            }
        }

        if (!state.isLoading && state.errorMessage == null) {
            if (state.ingredients.isEmpty()) {
                item {
                    SeasonStatusCard(
                        title = "Nessun ingrediente stagionale",
                        body = "Il catalogo non espone ancora ingredienti stagionali per questo mese.",
                        action = "Ricarica",
                        onAction = todayViewModel::refresh,
                    )
                }
            } else {
                items(state.ingredients, key = { it.ingredient.id }) { seasonal ->
                    SeasonalIngredientRow(
                        seasonal = seasonal,
                        onClick = { selectedIngredient = seasonal.ingredient },
                    )
                }
            }
        }
    }
}

@Composable
private fun TodayHeader(currentMonth: Int, total: Int, isLoading: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SeasonKicker(text = "${monthName(currentMonth)} · di stagione")
        Text(
            text = "Il meglio di stagione, ora.",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = "Il catalogo stagionale di ${monthName(currentMonth)}.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SeasonStatusCard(
            title = "Stagione ora",
            body = if (isLoading) {
                "Sto leggendo il catalogo ingredienti…"
            } else {
                "$total ingredienti utili ora, distinti tra primizie, momento migliore e fine stagione."
            },
        )
        if (isLoading) {
            CircularProgressIndicator(strokeWidth = 2.dp)
        }
    }
}

@Composable
private fun SeasonalIngredientRow(seasonal: SeasonalIngredient, onClick: () -> Unit) {
    SeasonPanel(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = seasonal.ingredient.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = seasonalCopy(seasonal.phase),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            SeasonPill(
                text = seasonal.phase.label,
                emphasis = when (seasonal.phase) {
                    SeasonalPhase.Early -> SeasonPillEmphasis.Secondary
                    SeasonalPhase.Peak -> SeasonPillEmphasis.Primary
                    SeasonalPhase.Ending -> SeasonPillEmphasis.Neutral
                },
            )
        }
    }
}

@Composable
private fun IngredientDetail(ingredient: CatalogIngredient, onBack: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            Text(
                modifier = Modifier.clickable(onClick = onBack),
                text = "‹ Torna a Oggi",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        item {
            SeasonPanel(prominent = true) {
                Text(text = ingredient.displayName, style = MaterialTheme.typography.headlineMedium)
                Text(
                    text = ingredient.type?.replace('_', ' ') ?: "Ingrediente catalogo",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (ingredient.isSeasonal) {
                    Text(
                        text = "Mesi: ${ingredient.seasonMonths.joinToString(", ") { monthName(it) }}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                ingredient.caloriesPer100g?.let {
                    Text(
                        text = "${it.toInt()} kcal per 100 g",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                ingredient.proteinPer100g?.let {
                    Text(
                        text = "${formatOneDecimal(it)} g proteine per 100 g",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun seasonalCopy(phase: SeasonalPhase): String {
    return when (phase) {
        SeasonalPhase.Early -> "È una primizia: interessante ora, con stagione appena iniziata."
        SeasonalPhase.Peak -> "È nel momento migliore: priorità alta per ricette di stagione."
        SeasonalPhase.Ending -> "È in fine stagione: buono da usare prima che esca dal periodo migliore."
    }
}

@Composable
private fun phaseColor(phase: SeasonalPhase) = when (phase) {
    SeasonalPhase.Early -> MaterialTheme.colorScheme.secondary
    SeasonalPhase.Peak -> MaterialTheme.colorScheme.primary
    SeasonalPhase.Ending -> MaterialTheme.colorScheme.onSurfaceVariant
}

private fun monthName(month: Int): String {
    return Month.of(month).getDisplayName(TextStyle.FULL, Locale.ITALIAN)
}

private fun formatOneDecimal(value: Double): String {
    val rounded = value.toLong()
    return if (kotlin.math.abs(value - rounded.toDouble()) < 0.001) {
        rounded.toString()
    } else {
        "%.1f".format(value)
    }
}
