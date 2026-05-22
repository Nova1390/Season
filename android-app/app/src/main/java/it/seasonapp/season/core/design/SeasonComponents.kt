package it.seasonapp.season.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.util.Locale

@Composable
fun SeasonCanvas(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        colors.background,
                        colors.surfaceVariant.copy(alpha = 0.42f),
                        colors.background,
                    ),
                ),
            ),
        content = content,
    )
}

@Composable
fun SeasonPanel(
    modifier: Modifier = Modifier,
    prominent: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        color = if (prominent) colors.surfaceVariant.copy(alpha = 0.78f) else colors.surface,
        contentColor = colors.onSurface,
        tonalElevation = if (prominent) 2.dp else 0.dp,
        shadowElevation = 0.dp,
        border = BorderStroke(
            width = 1.dp,
            color = colors.outline.copy(alpha = if (prominent) 0.72f else 0.48f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

@Composable
fun SeasonPill(
    text: String,
    modifier: Modifier = Modifier,
    emphasis: SeasonPillEmphasis = SeasonPillEmphasis.Neutral,
) {
    val colors = MaterialTheme.colorScheme
    val container = when (emphasis) {
        SeasonPillEmphasis.Primary -> colors.primary.copy(alpha = 0.18f)
        SeasonPillEmphasis.Secondary -> colors.secondary.copy(alpha = 0.18f)
        SeasonPillEmphasis.Neutral -> colors.surfaceVariant.copy(alpha = 0.86f)
    }
    val content = when (emphasis) {
        SeasonPillEmphasis.Primary -> colors.primary
        SeasonPillEmphasis.Secondary -> colors.secondary
        SeasonPillEmphasis.Neutral -> colors.onSurfaceVariant
    }

    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(999.dp),
        color = container,
        contentColor = content,
        border = BorderStroke(1.dp, content.copy(alpha = 0.22f)),
    ) {
        Text(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
            text = text,
            style = MaterialTheme.typography.labelLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

enum class SeasonPillEmphasis {
    Primary,
    Secondary,
    Neutral,
}

@Composable
fun SeasonKicker(text: String, modifier: Modifier = Modifier) {
    Text(
        modifier = modifier,
        text = text.uppercase(Locale.ITALIAN),
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.Bold,
        letterSpacing = androidx.compose.ui.unit.TextUnit.Unspecified,
    )
}

@Composable
fun SeasonRecipeArtwork(
    title: String,
    modifier: Modifier = Modifier,
    heightDp: Int = 210,
) {
    val colors = MaterialTheme.colorScheme
    val letter = title.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "S"
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heightDp.dp)
            .clip(MaterialTheme.shapes.large)
            .background(
                Brush.linearGradient(
                    listOf(
                        colors.primary.copy(alpha = 0.18f),
                        colors.surfaceVariant,
                        colors.secondary.copy(alpha = 0.14f),
                    ),
                ),
            )
            .padding(18.dp),
    ) {
        Text(
            text = letter,
            modifier = Modifier.align(Alignment.Center),
            style = MaterialTheme.typography.displayLarge,
            color = colors.onSurface.copy(alpha = 0.22f),
            textAlign = TextAlign.Center,
        )
        Row(
            modifier = Modifier.align(Alignment.BottomStart),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SeasonPill(text = "Season", emphasis = SeasonPillEmphasis.Primary)
        }
    }
}
