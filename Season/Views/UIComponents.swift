import SwiftUI
import UIKit
import Foundation
import ImageIO

enum SeasonSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum SeasonRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
    static let large: CGFloat = 12
    static let xl: CGFloat = 16
}

enum SeasonTypography {
    // Hierarchy rule: title > subtitle > body > metadata > caption.
    static let title: Font = .title2.weight(.bold)
    static let subtitle: Font = .subheadline.weight(.semibold)
    static let body: Font = .body
    static let metadata: Font = .caption.weight(.medium)
    static let caption: Font = .caption2
    static let captionStrong: Font = .caption2.weight(.semibold)
}

enum SeasonColors {
    static let primarySurface = Color(.systemGroupedBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let subtleSurface = Color(.tertiarySystemGroupedBackground)
    static let mutedChipSurface = Color(.systemGray6)
    static let seasonGreen = Color(red: 0.33, green: 0.40, blue: 0.29)
    static let seasonGreenSoft = Color(red: 0.84, green: 0.90, blue: 0.79)
    static let warningOrange = Color(red: 0.84, green: 0.58, blue: 0.18)
}

enum SeasonChipSemantic {
    case positive
    case warning
    case neutral

    var foreground: Color {
        switch self {
        case .positive:
            return SeasonColors.seasonGreen.opacity(0.9)
        case .warning:
            return SeasonColors.warningOrange.opacity(0.9)
        case .neutral:
            return Color.primary.opacity(0.68)
        }
    }

    var background: Color {
        switch self {
        case .positive:
            return SeasonColors.seasonGreenSoft.opacity(0.38)
        case .warning:
            return SeasonColors.warningOrange.opacity(0.14)
        case .neutral:
            return SeasonColors.subtleSurface
        }
    }

    var borderColor: Color {
        switch self {
        case .positive:
            return SeasonColors.seasonGreen.opacity(0.14)
        case .warning:
            return SeasonColors.warningOrange.opacity(0.18)
        case .neutral:
            return Color.primary.opacity(0.07)
        }
    }
}

extension View {
    func seasonCardStyle(
        cornerRadius: CGFloat = SeasonRadius.medium,
        background: Color = SeasonColors.secondarySurface
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
        )
    }

    func seasonChipStyle(
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        cornerRadius: CGFloat = SeasonRadius.small,
        background: Color = SeasonColors.subtleSurface
    ) -> some View {
        self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
    }

    func seasonCapsuleChipStyle(
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 8,
        background: Color = SeasonColors.mutedChipSurface
    ) -> some View {
        self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }

    // Use for section rhythm to keep vertical cadence consistent across screens.
    func seasonSectionSpacing(_ vertical: CGFloat = SeasonSpacing.sm) -> some View {
        self.padding(.vertical, vertical)
    }
}

enum SeasonLayout {
    // Keeps scroll content comfortably above the custom bottom navigation bar.
    static let bottomBarContentClearance: CGFloat = 84
}

struct SeasonCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(SeasonSpacing.sm)
            .seasonCardStyle(cornerRadius: SeasonRadius.medium, background: SeasonColors.secondarySurface)
    }
}

struct PressableCardButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = SeasonMotion.pressScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: configuration.isPressed)
    }
}

enum SeasonMotion {
    static let pressScale: CGFloat = 0.98
    static let pressOpacity: Double = 0.96
    static let pressAnimation: Animation = .easeOut(duration: 0.16)
}

struct SeasonPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SeasonColors.seasonGreen, SeasonColors.seasonGreen.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? SeasonMotion.pressScale : 1.0)
            .opacity(configuration.isPressed ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: configuration.isPressed)
    }
}

struct SeasonSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SeasonColors.secondarySurface.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? SeasonMotion.pressScale : 1.0)
            .opacity(configuration.isPressed ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: configuration.isPressed)
    }
}

struct SeasonDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.red.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.18), lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? SeasonMotion.pressScale : 1.0)
            .opacity(configuration.isPressed ? SeasonMotion.pressOpacity : 1.0)
            .animation(SeasonMotion.pressAnimation, value: configuration.isPressed)
    }
}

struct SeasonalStatusBadge: View {
    let score: Double
    let delta: Double
    let localizer: AppLocalizer

    init(score: Double, delta: Double = 0, localizer: AppLocalizer) {
        self.score = min(1.0, max(0.0, score))
        self.delta = delta
        self.localizer = localizer
    }

    init(isInSeason: Bool, localizer: AppLocalizer) {
        self.score = isInSeason ? 0.72 : 0.10
        self.delta = 0
        self.localizer = localizer
    }

    var body: some View {
        Text(localizer.seasonalityPhaseTitle(phase))
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private var phase: SeasonalityPhase {
        ProduceItem.seasonalityPhase(score: score, delta: delta)
    }

    private var foregroundColor: Color {
        switch phase {
        case .inSeason:
            return Color(red: 0.16, green: 0.65, blue: 0.30)
        case .earlySeason:
            return Color(red: 0.24, green: 0.58, blue: 0.25)
        case .endingSoon:
            return Color(red: 0.84, green: 0.58, blue: 0.18)
        case .outOfSeason:
            return Color(red: 0.78, green: 0.36, blue: 0.33)
        }
    }

    private var backgroundColor: Color {
        switch phase {
        case .inSeason:
            return Color(red: 0.16, green: 0.65, blue: 0.30).opacity(0.18)
        case .earlySeason:
            return Color(red: 0.24, green: 0.58, blue: 0.25).opacity(0.15)
        case .endingSoon:
            return Color(red: 0.84, green: 0.58, blue: 0.18).opacity(0.14)
        case .outOfSeason:
            return Color(red: 0.78, green: 0.36, blue: 0.33).opacity(0.13)
        }
    }
}

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct SeasonSectionHeader: View {
    let title: String
    let trailingText: String?
    let trailingActionTitle: String?
    let trailingAction: (() -> Void)?

    init(
        title: String,
        trailingText: String? = nil,
        trailingActionTitle: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.trailingText = trailingText
        self.trailingActionTitle = trailingActionTitle
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .center, spacing: SeasonSpacing.sm) {
            Text(title)
                .font(SeasonTypography.subtitle)
                .foregroundStyle(.primary)
            Spacer(minLength: SeasonSpacing.xs)
            if let trailingText {
                Text(trailingText)
                    .font(SeasonTypography.metadata)
                    .foregroundStyle(.secondary)
            } else if let trailingActionTitle, let trailingAction {
                Button(trailingActionTitle, action: trailingAction)
                    .font(SeasonTypography.metadata)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

struct SeasonStatChip: View {
    let icon: String
    let text: String
    var semantic: SeasonChipSemantic = .neutral
    var background: Color? = nil
    var foreground: Color? = nil
    var borderOpacity: Double = 0.08
    private var resolvedForeground: Color { foreground ?? semantic.foreground }
    private var resolvedBackground: Color { background ?? semantic.background }
    private var resolvedBorder: Color {
        if background == nil && foreground == nil {
            return semantic.borderColor
        }
        return Color.primary.opacity(borderOpacity)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(SeasonTypography.captionStrong)
                .foregroundStyle(resolvedForeground)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(resolvedForeground)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(resolvedBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(resolvedBorder, lineWidth: 0.5)
        )
    }
}

struct SeasonBadge: View {
    let text: String
    var icon: String?
    var semantic: SeasonChipSemantic = .neutral
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = SeasonRadius.small
    var foreground: Color? = nil
    var background: Color? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(SeasonTypography.captionStrong)
            }
            Text(text)
                .font(SeasonTypography.captionStrong)
                .lineLimit(1)
        }
        .foregroundStyle(foreground ?? semantic.foreground)
        .seasonChipStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            cornerRadius: cornerRadius,
            background: background ?? semantic.background
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke((foreground == nil && background == nil ? semantic.borderColor : Color.primary.opacity(0.055)), lineWidth: 0.5)
        )
    }
}

struct SeasonCardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var cornerRadius: CGFloat = SeasonRadius.large
    var background: Color = Color(.systemBackground)
    var backgroundOpacity: Double = 1.0
    var borderOpacity: Double = 0.06
    var shadowOpacity: Double = 0.02
    var shadowRadius: CGFloat = 6
    var shadowY: CGFloat = 2

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(borderOpacity), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
    }
}

enum RecipeCardVariant {
    case compact
    case regular
    case profile
    case feedCompact
    case feedLarge

    var thumbnailSize: CGFloat {
        switch self {
        case .compact: return 52
        case .regular: return 62
        case .profile: return 50
        case .feedCompact: return 72
        case .feedLarge: return 0
        }
    }
}

struct RecipeCardView: View {
    let recipe: Recipe
    let title: String
    let subtitle: String?
    let metadataText: String?
    let seasonalityScore: Double?
    let localizer: AppLocalizer?
    var variant: RecipeCardVariant = .regular
    var badges: [String] = []
    var cardBackground: Color = SeasonColors.secondarySurface
    var cardBackgroundOpacity: Double = 1.0
    var cardBorderOpacity: Double = 0.05
    var cardShadowOpacity: Double = 0
    var cardShadowRadius: CGFloat = 0
    var cardShadowY: CGFloat = 0

    var body: some View {
        if variant == .feedLarge {
            feedLargeCard
        } else {
            inlineCard(for: variant)
        }
    }

    private func inlineCard(for variant: RecipeCardVariant) -> some View {
        let isFeedCompact = variant == .feedCompact

        return SeasonCardContainer(
            content: {
                HStack(alignment: .top, spacing: 12) {
                    RecipeThumbnailView(recipe: recipe, size: variant.thumbnailSize)
                        .frame(width: isFeedCompact ? 74 : variant.thumbnailSize, height: isFeedCompact ? 74 : variant.thumbnailSize)

                    VStack(alignment: .leading, spacing: isFeedCompact ? 5 : 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(title)
                                .font(isFeedCompact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                                .lineLimit(2)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            if isFeedCompact, let seasonalityScore, let localizer {
                                SeasonalStatusBadge(score: seasonalityScore, localizer: localizer)
                            }
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(isFeedCompact ? .caption.weight(.medium) : SeasonTypography.metadata)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            if let metadataText {
                                SeasonBadge(
                                    text: metadataText,
                                    horizontalPadding: SeasonSpacing.xs,
                                    verticalPadding: isFeedCompact ? 4 : 3,
                                    cornerRadius: SeasonRadius.small,
                                    foreground: .secondary,
                                    background: SeasonColors.subtleSurface
                                )
                            }

                            ForEach(badges, id: \.self) { badge in
                                SeasonBadge(
                                    text: badge,
                                    horizontalPadding: SeasonSpacing.xs - 1,
                                    verticalPadding: 3,
                                    cornerRadius: SeasonRadius.small
                                )
                            }
                        }
                    }

                    Spacer(minLength: isFeedCompact ? 2 : 8)

                    if !isFeedCompact, let seasonalityScore, let localizer {
                        SeasonalStatusBadge(score: seasonalityScore, localizer: localizer)
                    }
                }
                .padding(.horizontal, isFeedCompact ? 11 : 12)
                .padding(.vertical, isFeedCompact ? 9 : 11)
                .frame(minHeight: isFeedCompact ? 92 : nil, alignment: .topLeading)
            },
            cornerRadius: SeasonRadius.large,
            background: cardBackground,
            backgroundOpacity: cardBackgroundOpacity,
            borderOpacity: cardBorderOpacity,
            shadowOpacity: cardShadowOpacity,
            shadowRadius: cardShadowRadius,
            shadowY: cardShadowY
        )
    }

    private var feedLargeCard: some View {
        SeasonCardContainer(
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    feedHeroImage(height: 150)

                    HStack(alignment: .top, spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 6)

                        if let seasonalityScore, let localizer {
                            SeasonalStatusBadge(score: seasonalityScore, localizer: localizer)
                        }
                    }

                    HStack(spacing: 6) {
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let metadataText {
                            SeasonBadge(
                                text: metadataText,
                                horizontalPadding: SeasonSpacing.xs,
                                verticalPadding: 3,
                                cornerRadius: SeasonRadius.small,
                                foreground: .secondary,
                                background: SeasonColors.subtleSurface
                            )
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            },
            cornerRadius: SeasonRadius.large,
            background: cardBackground,
            backgroundOpacity: cardBackgroundOpacity,
            borderOpacity: cardBorderOpacity,
            shadowOpacity: cardShadowOpacity,
            shadowRadius: cardShadowRadius,
            shadowY: cardShadowY
        )
    }

    @ViewBuilder
    private func feedHeroImage(height: CGFloat) -> some View {
        Group {
            if let cover = resolvedRecipeCoverImage(for: recipe),
               recipeImageFileURL(for: cover.localPath) != nil {
                RecipeLocalImageView(
                    image: cover,
                    targetSize: CGSize(width: height * 1.6, height: height),
                    contentMode: .fill
                ) {
                    feedHeroImageFallback(height: height)
                }
            } else if let cover = resolvedRecipeCoverImage(for: recipe),
                      let remoteURLString = cover.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackMedia
                    }
                }
            } else if let imageName = recipe.coverImageName,
                      UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackMedia
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func feedHeroImageFallback(height: CGFloat) -> some View {
        if let cover = resolvedRecipeCoverImage(for: recipe),
           let remoteURLString = cover.remoteURL,
           let remoteURL = URL(string: remoteURLString) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackMedia
                }
            }
        } else if let imageName = recipe.coverImageName,
                  UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackMedia
        }
    }

    private var fallbackMedia: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SeasonColors.subtleSurface)
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct SeasonAuthorHeaderView<Avatar: View, TrailingAction: View, Stats: View, Badges: View>: View {
    let name: String
    let subtitle: String
    let metadataText: String
    @ViewBuilder var avatar: Avatar
    @ViewBuilder var trailingAction: TrailingAction
    @ViewBuilder var stats: Stats
    @ViewBuilder var badges: Badges

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: SeasonSpacing.md) {
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .padding(.bottom, 1)

                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(metadataText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                trailingAction
            }

            stats
            badges
        }
    }
}

struct UserBadgePill: View {
    let badge: UserBadge
    let localizer: AppLocalizer

    var body: some View {
        SeasonBadge(
            text: localizer.userBadgeTitle(badge.kind),
            icon: badge.symbol,
            horizontalPadding: 8,
            verticalPadding: 4,
            cornerRadius: SeasonRadius.small,
            foreground: .secondary,
            background: SeasonColors.subtleSurface
        )
    }
}

struct InlineStatsRow: View {
    let stats: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, value in
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if index < stats.count - 1 {
                        Circle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
    }
}

struct SectionTitleCountRow: View {
    let title: String
    let countText: String?

    var body: some View {
        SeasonSectionHeader(title: title, trailingText: countText)
    }
}

struct RecipeDietaryTagPill: View {
    let tag: RecipeDietaryTag
    let localizer: AppLocalizer

    var body: some View {
        SeasonBadge(
            text: localizer.dietaryTagTitle(tag),
            horizontalPadding: SeasonSpacing.xs,
            verticalPadding: 4,
            cornerRadius: SeasonRadius.small,
            foreground: .secondary,
            background: SeasonColors.subtleSurface
        )
    }
}

func symbolName(for category: ProduceCategoryKey) -> String {
    switch category {
    case .fruit:
        return "apple.logo"
    case .vegetable:
        return "carrot.fill"
    case .tuber:
        return "square.grid.2x2.fill"
    case .legume:
        return "leaf.circle.fill"
    }
}

func categoryAssetName(for category: ProduceCategoryKey) -> String {
    switch category {
    case .fruit:
        return "category_fruit"
    case .vegetable:
        return "category_vegetable"
    case .tuber:
        return "category_tuber"
    case .legume:
        return "category_legume"
    }
}

func hasAsset(named name: String) -> Bool {
    UIImage(named: name) != nil
}

func produceImageCandidates(for item: ProduceItem) -> [String] {
    var candidates: [String] = []

    if let raw = item.imageName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
        candidates.append(raw)

        if raw.hasPrefix("produce_") {
            candidates.append(String(raw.dropFirst("produce_".count)))
        }

        let lowercased = raw.lowercased()
        if lowercased != raw {
            candidates.append(lowercased)
        }
    }

    candidates.append(item.id)

    var seen = Set<String>()
    return candidates.filter { seen.insert($0).inserted }
}

func resolvedProduceImageName(for item: ProduceItem) -> String? {
    for name in produceImageCandidates(for: item) where hasAsset(named: name) {
        return name
    }
    return nil
}

struct IngredientVisualView: View {
    let name: String
    let produceCategory: ProduceCategoryKey?
    let basicCategory: BasicIngredientCategory?
    let imageName: String?
    var cornerRadius: CGFloat = 10
    var imageContentMode: ContentMode = .fit
    var imagePaddingRatio: CGFloat = 0.08
    var iconScale: CGFloat = 0.5
    var showsNameInFallback: Bool = false

    private var resolvedImageName: String? {
        guard let imageName else { return nil }
        let trimmed = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, hasAsset(named: trimmed) else { return nil }
        return trimmed
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let imagePadding = max(4, side * imagePaddingRatio)
            let iconSize = max(16, side * iconScale)
            let initial = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: fallbackGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let resolvedImageName {
                    Group {
                        if imageContentMode == .fill {
                            Image(resolvedImageName)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(resolvedImageName)
                                .resizable()
                                .scaledToFit()
                                .padding(imagePadding)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                } else {
                    VStack(spacing: max(2, side * 0.04)) {
                        Image(systemName: fallbackSymbol)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.48))

                        if showsNameInFallback, !initial.isEmpty, side > 120 {
                            Text(initial)
                                .font(.system(size: max(14, side * 0.12), weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.26))
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var fallbackSymbol: String {
        if let produceCategory {
            switch produceCategory {
            case .vegetable, .legume:
                return "leaf.fill"
            case .fruit:
                return "apple.logo"
            case .tuber:
                return "square.grid.2x2.fill"
            }
        }

        if let basicCategory {
            switch basicCategory {
            case .dairy:
                return "drop.fill"
            case .condiments:
                return "drop.circle.fill"
            case .herbsAromatics:
                return "flame.fill"
            case .legumes:
                return "leaf.fill"
            case .pantry:
                return "archivebox.fill"
            case .proteins, .carbs:
                return "cube.fill"
            }
        }

        return "cube.fill"
    }

    private var fallbackGradient: [Color] {
        if produceCategory != nil {
            return [
                SeasonColors.seasonGreenSoft.opacity(0.38),
                SeasonColors.secondarySurface.opacity(0.95)
            ]
        }

        if let basicCategory {
            switch basicCategory {
            case .dairy:
                return [
                    Color(red: 0.97, green: 0.95, blue: 0.90),
                    SeasonColors.secondarySurface.opacity(0.94)
                ]
            case .condiments:
                return [
                    Color(red: 0.97, green: 0.93, blue: 0.84),
                    SeasonColors.secondarySurface.opacity(0.95)
                ]
            case .herbsAromatics:
                return [
                    Color(red: 0.95, green: 0.90, blue: 0.85),
                    SeasonColors.secondarySurface.opacity(0.95)
                ]
            case .legumes:
                return [
                    SeasonColors.seasonGreenSoft.opacity(0.32),
                    SeasonColors.secondarySurface.opacity(0.95)
                ]
            case .pantry, .proteins, .carbs:
                return [
                    SeasonColors.secondarySurface.opacity(0.96),
                    SeasonColors.subtleSurface.opacity(0.96)
                ]
            }
        }

        return [
            SeasonColors.secondarySurface.opacity(0.96),
            SeasonColors.subtleSurface.opacity(0.96)
        ]
    }
}

struct CategoryIconView: View {
    let category: ProduceCategoryKey
    var size: CGFloat = 20

    var body: some View {
        let assetName = categoryAssetName(for: category)

        Group {
            if hasAsset(named: assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: symbolName(for: category))
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ProduceThumbnailView: View {
    let item: ProduceItem
    var size: CGFloat = 46

    var body: some View {
        IngredientVisualView(
            name: item.displayName(languageCode: "en"),
            produceCategory: item.category,
            basicCategory: nil,
            imageName: resolvedProduceImageName(for: item),
            cornerRadius: 10,
            imageContentMode: .fit,
            imagePaddingRatio: 0.08,
            iconScale: 0.54
        )
        .frame(width: size, height: size)
    }
}

struct ProduceHeroImageView: View {
    let item: ProduceItem
    var height: CGFloat = 200

    var body: some View {
        IngredientVisualView(
            name: item.displayName(languageCode: "en"),
            produceCategory: item.category,
            basicCategory: nil,
            imageName: resolvedProduceImageName(for: item),
            cornerRadius: 14,
            imageContentMode: .fit,
            imagePaddingRatio: 0.08,
            iconScale: 0.24,
            showsNameInFallback: true
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

struct RecipeThumbnailView: View {
    private let imageName: String?
    private let recipe: Recipe?
    var size: CGFloat = 52

    init(imageName: String?, size: CGFloat = 52) {
        self.imageName = imageName
        self.recipe = nil
        self.size = size
    }

    init(recipe: Recipe, size: CGFloat = 52) {
        self.imageName = nil
        self.recipe = recipe
        self.size = size
    }

    var body: some View {
        let legacyImageName = imageName ?? recipe?.coverImageName
        let trimmedName = legacyImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasImage = !trimmedName.isEmpty && hasAsset(named: trimmedName)
        let recipeRemoteURL = recipe?.imageURL?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let recipeRemote = recipeRemoteURL.flatMap(URL.init(string:))
        let coverRemoteURL = recipe?.coverImage?.remoteURL?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let coverRemote = coverRemoteURL.flatMap(URL.init(string:))

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))

            if let recipeRemote {
                AsyncImage(url: recipeRemote) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackContent
                    }
                }
            } else if let recipe,
                      let cover = resolvedRecipeCoverImage(for: recipe),
                      recipeImageFileURL(for: cover.localPath) != nil {
                RecipeLocalImageView(
                    image: cover,
                    targetSize: CGSize(width: size, height: size),
                    contentMode: .fill
                ) {
                    thumbnailFallback(coverRemote: coverRemote, assetName: hasImage ? trimmedName : nil)
                }
                .clipped()
            } else if let coverRemote {
                AsyncImage(url: coverRemote) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackContent
                    }
                }
            } else if hasImage {
                Image(trimmedName)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                fallbackContent
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func thumbnailFallback(coverRemote: URL?, assetName: String?) -> some View {
        if let coverRemote {
            AsyncImage(url: coverRemote) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackContent
                }
            }
        } else if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            fallbackContent
        }
    }

    private var fallbackContent: some View {
        Image(systemName: "fork.knife.circle.fill")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

func resolvedRecipeCoverImage(for recipe: Recipe) -> RecipeImage? {
    recipe.coverImage
}

func recipeImageFileURL(for localPath: String?) -> URL? {
    guard let localPath, !localPath.isEmpty else { return nil }
    if localPath.hasPrefix("/") {
        return URL(fileURLWithPath: localPath)
    }
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    return documentsURL?.appendingPathComponent(localPath)
}

func recipeUIImage(from image: RecipeImage) -> UIImage? {
    RecipeLocalImageLoader.shared.imageSynchronously(for: image.localPath, targetSize: nil)
}

enum SeasonImageProcessor {
    static func jpegData(from image: UIImage, compressionQuality: CGFloat = 0.9) async -> Data? {
        let sendableImage = SendableUIImage(image: image)
        return await Task.detached(priority: .utility) {
            sendableImage.image.jpegData(compressionQuality: compressionQuality)
        }.value
    }

    static func jpegData(fromImageData imageData: Data, compressionQuality: CGFloat = 0.9) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let image = UIImage(data: imageData) else { return nil }
            return image.jpegData(compressionQuality: compressionQuality)
        }.value
    }

    static func jpegData(fromRecipeImageLocalPath localPath: String?, compressionQuality: CGFloat = 0.9) async -> Data? {
        guard let fileURL = recipeImageFileURL(for: localPath) else { return nil }
        return await Task.detached(priority: .utility) {
            guard let image = UIImage(contentsOfFile: fileURL.path) else { return nil }
            return image.jpegData(compressionQuality: compressionQuality)
        }.value
    }

    static func saveRecipeImageDataToDocuments(_ data: Data) async -> String? {
        await Task.detached(priority: .utility) {
            let filename = "recipe_\(UUID().uuidString.lowercased()).jpg"
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }

            let fileURL = documentsURL.appendingPathComponent(filename)
            do {
                try data.write(to: fileURL, options: .atomic)
                return filename
            } catch {
                return nil
            }
        }.value
    }

    static func saveRecipeUIImageToDocuments(_ image: UIImage, compressionQuality: CGFloat = 0.9) async -> String? {
        guard let jpegData = await jpegData(from: image, compressionQuality: compressionQuality) else { return nil }
        return await saveRecipeImageDataToDocuments(jpegData)
    }
}

// UIImage is treated as immutable here and only handed to a utility task for JPEG encoding.
private struct SendableUIImage: @unchecked Sendable {
    let image: UIImage
}

struct RecipeLocalImageView<Placeholder: View>: View {
    let image: RecipeImage
    let targetSize: CGSize?
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var loadedCacheKey: String?
    @State private var failedCacheKey: String?

    init(
        image: RecipeImage,
        targetSize: CGSize? = nil,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.image = image
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        let cacheKey = RecipeLocalImageLoader.shared.cacheKey(
            for: image.localPath,
            targetSize: targetSize,
            displayScale: displayScale
        )
        let memoryImage = RecipeLocalImageLoader.shared.cachedImage(
            for: image.localPath,
            targetSize: targetSize,
            displayScale: displayScale
        )
        let displayImage = loadedCacheKey == cacheKey ? loadedImage ?? memoryImage : memoryImage

        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: cacheKey) {
            guard failedCacheKey != cacheKey else { return }
            if let memoryImage {
                loadedImage = memoryImage
                loadedCacheKey = cacheKey
                return
            }

            let decodedImage = await RecipeLocalImageLoader.shared.image(
                for: image.localPath,
                targetSize: targetSize,
                displayScale: displayScale
            )
            if let decodedImage {
                loadedImage = decodedImage
                loadedCacheKey = cacheKey
            } else {
                loadedImage = nil
                loadedCacheKey = cacheKey
                failedCacheKey = cacheKey
            }
        }
    }
}

final class RecipeLocalImageLoader {
    static let shared = RecipeLocalImageLoader()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 96
    }

    func cacheKey(for localPath: String?, targetSize: CGSize?, displayScale: CGFloat = 1) -> String {
        guard let fileURL = recipeImageFileURL(for: localPath) else {
            return "missing-local-recipe-image"
        }

        if let maxPixelDimension = maxPixelDimension(for: targetSize, displayScale: displayScale), maxPixelDimension > 0 {
            return "\(fileURL.path)#\(maxPixelDimension)"
        }
        return "\(fileURL.path)#original"
    }

    func cachedImage(for localPath: String?, targetSize: CGSize?, displayScale: CGFloat = 1) -> UIImage? {
        let key = cacheKey(for: localPath, targetSize: targetSize, displayScale: displayScale)
        return cache.object(forKey: key as NSString)
    }

    func image(for localPath: String?, targetSize: CGSize?, displayScale: CGFloat = 1) async -> UIImage? {
        guard let fileURL = recipeImageFileURL(for: localPath) else { return nil }
        let key = cacheKey(for: localPath, targetSize: targetSize, displayScale: displayScale)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let maxPixelDimension = maxPixelDimension(for: targetSize, displayScale: displayScale)
        let decoded = await Task.detached(priority: .utility) {
            Self.loadImage(at: fileURL, maxPixelDimension: maxPixelDimension)
        }.value

        if let decoded {
            cache.setObject(decoded, forKey: key as NSString)
        }
        return decoded
    }

    func imageSynchronously(for localPath: String?, targetSize: CGSize?) -> UIImage? {
        guard let fileURL = recipeImageFileURL(for: localPath) else { return nil }
        let key = cacheKey(for: localPath, targetSize: targetSize)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let decoded = Self.loadImage(at: fileURL, maxPixelDimension: maxPixelDimension(for: targetSize, displayScale: 1))
        if let decoded {
            cache.setObject(decoded, forKey: key as NSString)
        }
        return decoded
    }

    private func maxPixelDimension(for targetSize: CGSize?, displayScale: CGFloat) -> Int? {
        guard let targetSize else { return nil }
        let maxPointDimension = max(targetSize.width, targetSize.height)
        guard maxPointDimension > 0 else { return nil }
        return Int(ceil(maxPointDimension * max(displayScale, 1)))
    }

    nonisolated private static func loadImage(at fileURL: URL, maxPixelDimension: Int?) -> UIImage? {
        guard let maxPixelDimension, maxPixelDimension > 0 else {
            return UIImage(contentsOfFile: fileURL.path)
        }

        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
            return UIImage(contentsOfFile: fileURL.path)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(contentsOfFile: fileURL.path)
        }

        return UIImage(cgImage: cgImage)
    }
}

struct CartToolbarItems: ToolbarContent {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                ShoppingListView(
                    produceViewModel: produceViewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                Image(systemName: "bag")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(produceViewModel.localizer.text(.listTab))
        }

        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                FridgeView(
                    produceViewModel: produceViewModel,
                    fridgeViewModel: fridgeViewModel
                )
            } label: {
                Image(systemName: "snowflake")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(produceViewModel.localizer.text(.fridgeTab))
        }
    }
}
