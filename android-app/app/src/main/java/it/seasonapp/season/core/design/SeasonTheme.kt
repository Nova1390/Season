package it.seasonapp.season.core.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object SeasonColors {
    val Ink = Color(0xFF232019)
    val InkMuted = Color(0xFF6F695E)
    val Cream = Color(0xFFFBF7ED)
    val Linen = Color(0xFFF4ECDD)
    val Leaf = Color(0xFF4E6E3F)
    val LeafSoft = Color(0xFFDDEAD3)
    val Ochre = Color(0xFFC58B35)

    val Night = Color(0xFF0F140D)
    val NightSurface = Color(0xFF1B2117)
    val NightBorder = Color(0xFF34402C)
    val NightText = Color(0xFFF5F0E6)
    val NightMuted = Color(0xFFC1BAAD)
}

private val LightSeasonColorScheme: ColorScheme = lightColorScheme(
    primary = SeasonColors.Leaf,
    onPrimary = Color.White,
    secondary = SeasonColors.Ochre,
    onSecondary = SeasonColors.Ink,
    background = SeasonColors.Cream,
    onBackground = SeasonColors.Ink,
    surface = Color(0xFFFFFCF6),
    onSurface = SeasonColors.Ink,
    surfaceVariant = SeasonColors.Linen,
    onSurfaceVariant = SeasonColors.InkMuted,
    outline = Color(0xFFD7CDBD),
)

private val DarkSeasonColorScheme: ColorScheme = darkColorScheme(
    primary = Color(0xFFA7CF8F),
    onPrimary = SeasonColors.Night,
    secondary = Color(0xFFE3B66B),
    onSecondary = SeasonColors.Night,
    background = SeasonColors.Night,
    onBackground = SeasonColors.NightText,
    surface = SeasonColors.NightSurface,
    onSurface = SeasonColors.NightText,
    surfaceVariant = Color(0xFF242C1F),
    onSurfaceVariant = SeasonColors.NightMuted,
    outline = SeasonColors.NightBorder,
)

private val SeasonTypography = Typography(
    displaySmall = TextStyle(
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 36.sp,
        lineHeight = 38.sp,
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 28.sp,
        lineHeight = 32.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 26.sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 23.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        lineHeight = 18.sp,
    ),
)

private val SeasonShapes = Shapes(
    small = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
)

@Composable
fun SeasonTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkSeasonColorScheme else LightSeasonColorScheme,
        typography = SeasonTypography,
        shapes = SeasonShapes,
        content = content,
    )
}

