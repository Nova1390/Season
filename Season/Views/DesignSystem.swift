import SwiftUI
import UIKit

/// Asset-catalog namespace prefix for every v2 color.
/// Kept at file scope so nested enums (`DS.Color.Reason`, `DS.Color.Crispy`)
/// can reference it without a qualified path.
private let dsColorNamespace = "DesignSystem/"

// MARK: - DS — Season v2 Design System
//
// Unified design tokens for the visual refresh ("v2").
// Source of truth: docs/design/season-ui-refresh/_shared/season-v2.css
//
// Migration strategy (Option A): this namespace coexists with the legacy
// `SeasonColors`, `SeasonTypography`, `SeasonSpacing`, `SeasonRadius` in
// UIComponents.swift. New and refactored views use DS; legacy helpers are
// removed as each view is migrated.
//
// Tokens are organized into small nested enums so autocompletion reveals the
// surface quickly (e.g. `DS.Color.sage`, `DS.Font.cardTitle`).

enum DS {

    // MARK: - Color

    /// Color tokens live in `Assets.xcassets/DesignSystem/`. The asset
    /// catalog folder uses `provides-namespace: true` so every color is
    /// addressed under the `DesignSystem/` prefix. Inner folders (Surfaces,
    /// Ink, Accents, Reasons, Crispy, Borders) are organizational only.
    enum Color {
        // Surfaces
        static let bg       = SwiftUI.Color(dsColorNamespace + "bg")
        static let bgSub    = SwiftUI.Color(dsColorNamespace + "bgSub")
        static let card     = SwiftUI.Color(dsColorNamespace + "card")
        static let cardSoft = SwiftUI.Color(dsColorNamespace + "cardSoft")

        // Borders (already include ~6–16% alpha in the asset)
        static let border  = SwiftUI.Color(dsColorNamespace + "border")
        static let borderM = SwiftUI.Color(dsColorNamespace + "borderM")
        static let borderS = SwiftUI.Color(dsColorNamespace + "borderS")

        // Ink (text) — darkest to faintest
        static let ink      = SwiftUI.Color(dsColorNamespace + "ink")
        static let inkSoft  = SwiftUI.Color(dsColorNamespace + "inkSoft")
        static let inkMuted = SwiftUI.Color(dsColorNamespace + "inkMuted")
        static let inkFaint = SwiftUI.Color(dsColorNamespace + "inkFaint")

        // Accents
        static let sage           = SwiftUI.Color(dsColorNamespace + "sage")
        static let sageDeep       = SwiftUI.Color(dsColorNamespace + "sageDeep")
        static let sageSoft       = SwiftUI.Color(dsColorNamespace + "sageSoft")
        static let terracotta     = SwiftUI.Color(dsColorNamespace + "terracotta")
        static let terracottaSoft = SwiftUI.Color(dsColorNamespace + "terracottaSoft")
        static let ochre          = SwiftUI.Color(dsColorNamespace + "ochre")
        static let ochreSoft      = SwiftUI.Color(dsColorNamespace + "ochreSoft")
        static let fresh          = SwiftUI.Color(dsColorNamespace + "fresh")

        // Reason chips (each has a paired background / foreground)
        enum Reason {
            static let fridgeBg  = SwiftUI.Color(dsColorNamespace + "reasonFridgeBg")
            static let fridgeFg  = SwiftUI.Color(dsColorNamespace + "reasonFridgeFg")
            static let creatorBg = SwiftUI.Color(dsColorNamespace + "reasonCreatorBg")
            static let creatorFg = SwiftUI.Color(dsColorNamespace + "reasonCreatorFg")
            static let similarBg = SwiftUI.Color(dsColorNamespace + "reasonSimilarBg")
            static let similarFg = SwiftUI.Color(dsColorNamespace + "reasonSimilarFg")
            static let peakBg    = SwiftUI.Color(dsColorNamespace + "reasonPeakBg")
            static let peakFg    = SwiftUI.Color(dsColorNamespace + "reasonPeakFg")
            static let trendBg   = SwiftUI.Color(dsColorNamespace + "reasonTrendBg")
            static let trendFg   = SwiftUI.Color(dsColorNamespace + "reasonTrendFg")
            static let freshBg   = SwiftUI.Color(dsColorNamespace + "reasonFreshBg")
            static let freshFg   = SwiftUI.Color(dsColorNamespace + "reasonFreshFg")
        }

        // Crispy pill (flame-fill like + counter)
        enum Crispy {
            static let inkInactive   = SwiftUI.Color(dsColorNamespace + "crispyInkInactive")
            static let flameInactive = SwiftUI.Color(dsColorNamespace + "crispyFlameInactive")
            static let inkActive     = SwiftUI.Color(dsColorNamespace + "crispyInkActive")
            static let flameActive   = SwiftUI.Color(dsColorNamespace + "crispyFlameActive")
            static let bgActive      = SwiftUI.Color(dsColorNamespace + "crispyBgActive")
        }
    }

    // MARK: - Font

    /// Typography tokens. Falls back to system fonts if a custom face is not
    /// available at runtime (`Font.custom` substitutes automatically).
    ///
    /// Families:
    /// - Serif → Newsreader (display, section titles, card titles, hero)
    /// - Sans  → Inter (body, metadata, chips, tab labels)
    /// - Mono  → JetBrains Mono (category eyebrows, small uppercase labels)
    enum Font {

        // Family façades — public so view code can build ad-hoc sizes when needed.
        static func serif(_ size: CGFloat, weight: Weight = .regular, italic: Bool = false) -> SwiftUI.Font {
            SwiftUI.Font.custom(Family.newsreader(weight: weight, italic: italic), size: size)
        }

        static func sans(_ size: CGFloat, weight: Weight = .regular) -> SwiftUI.Font {
            SwiftUI.Font.custom(Family.inter(weight: weight), size: size)
        }

        static func mono(_ size: CGFloat, weight: Weight = .regular) -> SwiftUI.Font {
            SwiftUI.Font.custom(Family.jetBrainsMono(weight: weight), size: size)
        }

        // MARK: Semantic presets (map to prototype usages)

        /// Hero serif — "Buongiorno Rocco…" style headlines.
        static let hero = serif(28, weight: .medium)

        /// Section/card title in serif — matches `.fcard__title` at 18–20px medium.
        static let cardTitle = serif(19, weight: .medium)

        /// Large editorial title (peak carousel, recipe detail eyebrow+title pair).
        static let displayTitle = serif(24, weight: .medium)

        /// Wordmark "Season." at ~22px medium.
        static let wordmark = serif(22, weight: .medium)

        /// Italic callout inside serif text (used in headlines and tips).
        static let serifItalic = serif(19, weight: .regular, italic: true)

        /// Body copy in sans.
        static let body = sans(14, weight: .regular)

        /// Emphasized body in sans (labels, active tab).
        static let bodyStrong = sans(14, weight: .semibold)

        /// Chip / pill labels.
        static let chip = sans(12, weight: .medium)

        /// Small metadata under cards (time · servings · difficulty).
        static let meta = sans(12, weight: .regular)

        /// Uppercase mono eyebrow ("APRILE · MILANO · SETTIMANA 16").
        static let eyebrow = mono(10.5, weight: .medium)

        /// Mono chip for the Crispy counter.
        static let crispyCounter = mono(11, weight: .medium)

        // MARK: Weight enum

        enum Weight {
            case regular, medium, semibold, bold
        }

        /// Resolves weight + italic to the matching PostScript name.
        /// Keeping this private protects callers from typos.
        private enum Family {
            static func newsreader(weight: Weight, italic: Bool) -> String {
                if italic { return "Newsreader-Italic" }
                switch weight {
                case .regular:  return "Newsreader-Regular"
                case .medium:   return "Newsreader-Medium"
                // Newsreader only ships Regular/Medium/Italic in our bundle;
                // heavier weights fall back to Medium which still reads heavier
                // than system serif at display sizes.
                case .semibold, .bold: return "Newsreader-Medium"
                }
            }

            static func inter(weight: Weight) -> String {
                switch weight {
                case .regular:  return "Inter-Regular"
                case .medium:   return "Inter-Medium"
                case .semibold: return "Inter-SemiBold"
                case .bold:     return "Inter-Bold"
                }
            }

            static func jetBrainsMono(weight: Weight) -> String {
                switch weight {
                case .regular:  return "JetBrainsMono-Regular"
                case .medium,
                     .semibold,
                     .bold:     return "JetBrainsMono-Medium"
                }
            }
        }

        // MARK: Diagnostics

        /// Logs which custom font families actually registered at launch.
        /// Call once from `SeasonApp.init()` so missing TTFs are visible in
        /// the console without breaking the app (system fallback still works).
        static func logRegistrationStatus() {
            let expected: [String] = [
                "Newsreader-Regular", "Newsreader-Medium", "Newsreader-Italic",
                "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold",
                "JetBrainsMono-Regular", "JetBrainsMono-Medium",
            ]
            let missing = expected.filter { UIFont(name: $0, size: 12) == nil }
            if missing.isEmpty {
                SeasonLog.debug("[SEASON_DS_FONT] phase=registered count=\(expected.count)")
            } else {
                SeasonLog.debug("[SEASON_DS_FONT] phase=partial loaded=\(expected.count - missing.count) missing=\(missing.count) names=\(missing.joined(separator: ","))")
            }
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        /// iOS "pill" / capsule — use with `.clipShape(Capsule())`.
        static let pill: CGFloat = 9_999
    }

    // MARK: - Shadow

    /// Elevation presets mirroring `--shadow-1/2/3` in season-v2.css.
    /// Apply with `.shadow(color:radius:x:y:)` via the helper below.
    struct Shadow {
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let s1 = Shadow(color: SwiftUI.Color.black.opacity(0.04),
                               radius: 2,  x: 0, y: 1)
        static let s2 = Shadow(color: SwiftUI.Color.black.opacity(0.06),
                               radius: 16, x: 0, y: 4)
        static let s3 = Shadow(color: SwiftUI.Color.black.opacity(0.10),
                               radius: 32, x: 0, y: 10)
    }

    // MARK: - Layout

    /// Fixed layout constants used across the app chrome.
    enum Layout {
        /// Height of the custom top bar (wordmark + trailing actions).
        static let topBarHeight: CGFloat = 54
        /// Height of the bottom tab bar.
        static let tabBarHeight: CGFloat = 72
        /// Max content width — keeps text readable on large screens (iPad).
        static let contentMaxWidth: CGFloat = 640
    }
}

// MARK: - View helpers

extension View {
    /// Apply one of the three design-system shadow elevations.
    func dsShadow(_ shadow: DS.Shadow) -> some View {
        self.shadow(color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y)
    }
}
