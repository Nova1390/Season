import SwiftUI
import UIKit
import Foundation

enum SeasonSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
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
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
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

struct UserBadgePill: View {
    let badge: UserBadge
    let localizer: AppLocalizer

    var body: some View {
        Label(localizer.userBadgeTitle(badge.kind), systemImage: badge.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
    }
}

struct RecipeDietaryTagPill: View {
    let tag: RecipeDietaryTag
    let localizer: AppLocalizer

    var body: some View {
        Text(localizer.dietaryTagTitle(tag))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
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
