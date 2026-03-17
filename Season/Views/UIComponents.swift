import SwiftUI
import UIKit

struct SeasonCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

struct SeasonalStatusBadge: View {
    let isInSeason: Bool
    let localizer: AppLocalizer

    var body: some View {
        Text(localizer.text(isInSeason ? .inSeason : .notInSeason))
            .font(.caption.weight(.bold))
            .foregroundStyle(isInSeason ? Color.green : Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isInSeason ? Color.green.opacity(0.18) : Color.orange.opacity(0.14))
            )
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

func symbolName(for category: ProduceCategoryKey) -> String {
    switch category {
    case .fruit:
        return "apple.logo"
    case .vegetable:
        return "carrot.fill"
    case .tuber:
        return "square.grid.2x2.fill"
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
            Circle()
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
    }
}

struct ProduceHeroImageView: View {
    let item: ProduceItem
    var height: CGFloat = 200

    var body: some View {
        let resolvedName = resolvedProduceImageName(for: item)

        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .padding(22)
            } else {
                CategoryIconView(category: item.category, size: 74)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}
