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
    val Clay = Color(0xFFB96D42)

    val Night = Color(0xFF0F140D)
    val NightSurface = Color(0xFF1A2016)
    val NightPanel = Color(0xFF20291B)
    val NightBorder = Color(0xFF3D4B34)
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
    primary = Color(0xFFB8DB9A),
    onPrimary = SeasonColors.Night,
    secondary = Color(0xFFE8BE75),
    onSecondary = SeasonColors.Night,
    background = SeasonColors.Night,
    onBackground = SeasonColors.NightText,
    surface = SeasonColors.NightSurface,
    onSurface = SeasonColors.NightText,
    surfaceVariant = SeasonColors.NightPanel,
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
    displayLarge = TextStyle(
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 68.sp,
        lineHeight = 72.sp,
    ),
)

private val SeasonShapes = Shapes(
    small = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(28.dp),
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
