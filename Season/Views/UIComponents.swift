import SwiftUI
import UIKit
import Foundation

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
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
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
    var background: Color = SeasonColors.subtleSurface
    var foreground: Color = Color.primary.opacity(0.76)
    var borderOpacity: Double = 0.08

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(SeasonTypography.captionStrong)
                .foregroundStyle(foreground)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(borderOpacity), lineWidth: 0.6)
        )
    }
}

struct SeasonBadge: View {
    let text: String
    var icon: String?
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = SeasonRadius.small
    var foreground: Color = .secondary
    var background: Color = SeasonColors.subtleSurface

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
        .foregroundStyle(foreground)
        .seasonChipStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            cornerRadius: cornerRadius,
            background: background
        )
    }
}

struct SeasonCardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var cornerRadius: CGFloat = SeasonRadius.large
    var background: Color = Color(.systemBackground)
    var backgroundOpacity: Double = 1.0
    var borderOpacity: Double = 0.09
    var shadowOpacity: Double = 0.028
    var shadowRadius: CGFloat = 8
    var shadowY: CGFloat = 3

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
                                    horizontalPadding: isFeedCompact ? 7 : 7,
                                    verticalPadding: isFeedCompact ? 4 : 3,
                                    cornerRadius: 7,
                                    foreground: .secondary,
                                    background: SeasonColors.subtleSurface
                                )
                            }

                            ForEach(badges, id: \.self) { badge in
                                SeasonBadge(
                                    text: badge,
                                    horizontalPadding: 6,
                                    verticalPadding: 3,
                                    cornerRadius: 7
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
                                horizontalPadding: 7,
                                verticalPadding: 3,
                                cornerRadius: 7,
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
               let localImage = recipeUIImage(from: cover) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
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
            horizontalPadding: 7,
            verticalPadding: 4,
            cornerRadius: 7,
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
        let resolvedName = resolvedProduceImageName(for: item)

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))

            if let resolvedName {
                Image(resolvedName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                CategoryIconView(category: item.category, size: size * 0.62)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ProduceHeroImageView: View {
    let item: ProduceItem
    var height: CGFloat = 200

    var body: some View {
        let resolvedName = resolvedProduceImageName(for: item)

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let resolvedName {
                Image(resolvedName)
                    .resizable()
                    .scaledToFit()
                    .padding(SeasonSpacing.md)
            } else {
                CategoryIconView(category: item.category, size: 74)
            }
        }
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

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))

            if let recipe, let cover = resolvedRecipeCoverImage(for: recipe), let image = recipeUIImage(from: cover) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if hasImage {
                Image(trimmedName)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if let recipe,
                      let cover = resolvedRecipeCoverImage(for: recipe),
                      let remoteURLString = cover.remoteURL,
                      let remoteURL = URL(string: remoteURLString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    guard let fileURL = recipeImageFileURL(for: image.localPath) else { return nil }
    return UIImage(contentsOfFile: fileURL.path)
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
