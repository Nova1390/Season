package it.seasonapp.season.features.smartimport

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.navigation.SeasonStatusCard

@Composable
fun SmartImportScreen(
    smartImportViewModel: SmartImportViewModel = viewModel(),
) {
    val state by smartImportViewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .imePadding(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            SmartImportHeader()
        }
        item {
            SmartImportInputCard(
                caption = state.caption,
                sourceUrl = state.sourceUrl,
                isLoading = state.isLoading,
                onCaptionChange = smartImportViewModel::updateCaption,
                onSourceUrlChange = smartImportViewModel::updateSourceUrl,
                onImport = smartImportViewModel::importDraft,
            )
        }
        state.errorMessage?.let { message ->
            item {
                SeasonStatusCard(
                    title = "Import non riuscito",
                    body = message,
                )
            }
        }
        state.draft?.let { draft ->
            item { SmartImportDraftCard(draft = draft) }
            item { SmartImportIngredientsCard(draft = draft) }
            item { SmartImportStepsCard(draft = draft) }
        }
    }
}

@Composable
private fun SmartImportHeader() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(text = "Crea ricetta", style = MaterialTheme.typography.headlineMedium)
        Text(
            text = "Incolla una caption Instagram/TikTok: Season crea una bozza con titolo, dosi e passaggi.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SmartImportInputCard(
    caption: String,
    sourceUrl: String,
    isLoading: Boolean,
    onCaptionChange: (String) -> Unit,
    onSourceUrlChange: (String) -> Unit,
    onImport: () -> Unit,
) {
    SmartImportCard {
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = sourceUrl,
            onValueChange = onSourceUrlChange,
            singleLine = true,
            label = { Text("Link media esterno (opzionale)") },
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = caption,
            onValueChange = onCaptionChange,
            minLines = 5,
            label = { Text("Caption o ingredienti") },
        )
        Button(
            enabled = !isLoading && caption.isNotBlank(),
            onClick = onImport,
        ) {
            Text(if (isLoading) "Importo…" else "Importa bozza")
        }
        if (isLoading) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(strokeWidth = 2.dp)
                Text(
                    text = "Sto leggendo caption, quantità e passaggi…",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SmartImportDraftCard(draft: SmartImportDraft) {
    SmartImportCard {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AssistChip(onClick = {}, label = { Text(draft.qualityLabel) })
            AssistChip(onClick = {}, label = { Text("Per ${draft.servings}") })
        }
        Text(
            text = draft.title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        val blockReason = draft.publishBlockReason
        SeasonStatusCard(
            title = if (blockReason == null) "Bozza pronta" else "Da completare prima di pubblicare",
            body = blockReason ?: "Controlla ingredienti e passaggi, poi il publish verrà collegato nel prossimo step.",
        )
    }
}

@Composable
private fun SmartImportIngredientsCard(draft: SmartImportDraft) {
    SmartImportCard {
        Text(text = "Ingredienti (${draft.ingredients.size})", style = MaterialTheme.typography.titleMedium)
        if (draft.ingredients.isEmpty()) {
            Text(
                text = "Nessun ingrediente strutturato.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            draft.ingredients.forEach { ingredient ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        modifier = Modifier.weight(1f),
                        text = ingredient.name,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Text(
                        text = ingredient.quantityText ?: "Senza quantità",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun SmartImportStepsCard(draft: SmartImportDraft) {
    SmartImportCard {
        Text(text = "Passaggi (${draft.steps.size})", style = MaterialTheme.typography.titleMedium)
        if (draft.steps.isEmpty()) {
            Text(
                text = "Mancano i passaggi: la bozza resta modificabile ma non è pubblicabile.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            draft.steps.forEachIndexed { index, step ->
                Text(
                    text = "${index + 1}. $step",
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
    }
}

@Composable
private fun SmartImportCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.65f)),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}
