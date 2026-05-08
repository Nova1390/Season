import SwiftUI

// MARK: - Home feed atoms (v2b rhythm)
//
// Atomic SwiftUI components that compose the new home feed rhythm described
// in docs/design/season-ui-refresh/home-prototype-v2b.html. Every atom:
//
// * is pure presentational — it takes simple value types, no ObservedObject,
//   no ViewModel, so previews and composition are trivial;
// * reads every visual token from `DS.*` — if you need a color, spacing,
//   radius or font that isn't in DesignSystem.swift, add it there first;
// * is small enough to own a `#Preview` (at the bottom of the file) so the
//   designer can iterate on a single piece without running the full app.
//
// Consumption is expected from HomeView.mixedFeedSection, which emits the
// rhythm: classic → split → peak band → classic → tip ochre → compact →
// nudge → split → collection → compact → classic → pulse.

// MARK: - ReasonChip

/// Semantic reason for a recipe surfacing in the feed. Maps to
/// `.reason[data-why="..."]` in the v2b CSS — six distinct paired
/// background/foreground tokens live in `DS.Color.Reason.*`.
enum ReasonKind {
    case fridge
    case creator
    case similar
    case peak
    case trending
    case fresh

    var background: Color {
        switch self {
        case .fridge:   return DS.Color.Reason.fridgeBg
        case .creator:  return DS.Color.Reason.creatorBg
        case .similar:  return DS.Color.Reason.similarBg
        case .peak:     return DS.Color.Reason.peakBg
        case .trending: return DS.Color.Reason.trendBg
        case .fresh:    return DS.Color.Reason.freshBg
        }
    }

    var foreground: Color {
        switch self {
        case .fridge:   return DS.Color.Reason.fridgeFg
        case .creator:  return DS.Color.Reason.creatorFg
        case .similar:  return DS.Color.Reason.similarFg
        case .peak:     return DS.Color.Reason.peakFg
        case .trending: return DS.Color.Reason.trendFg
        case .fresh:    return DS.Color.Reason.freshFg
        }
    }
}

/// Substack-discreet reason pill: 8pt colored dot + mono 10 label.
/// Matches `.reason` in home-prototype-v2b.html:423.
struct ReasonChip: View {
    let kind: ReasonKind
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(kind.foreground.opacity(0.55))
                .frame(width: 8, height: 8)
            Text(text)
                .font(DS.Font.mono(10, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(kind.foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                .fill(kind.background)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Shared value types for feed atoms

/// Thin value-type wrapper for an image reference passed to atoms.
/// Atoms don't know about Recipe — callers translate their domain model
/// into a URL + optional asset fallback.
struct FeedImageSource {
    let url: URL?
    let fallbackAssetName: String?

    init(url: URL? = nil, fallbackAssetName: String? = nil) {
        self.url = url
        self.fallbackAssetName = fallbackAssetName
    }
}

/// Minimal metadata rendered under a card title (e.g. "25 min · 4 porzioni").
struct FeedMetaLine {
    let primary: String
    let secondary: String?

    init(primary: String, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }
}

enum FeedIdentityKind {
    case creator
    case source
}

private struct FeedThumbnailView: View {
    let image: FeedImageSource
    let symbolName: String

    var body: some View {
        if image.url != nil || image.fallbackAssetName != nil {
            RemoteImageView(
                url: image.url,
                fallbackAssetName: image.fallbackAssetName
            )
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        DS.Color.cardSoft,
                        DS.Color.sageSoft.opacity(0.68)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(DS.Color.sageDeep.opacity(0.72))
            }
        }
    }
}

private struct FeedIdentityAvatar: View {
    let image: FeedImageSource
    let kind: FeedIdentityKind
    let size: CGFloat

    var body: some View {
        if image.url != nil || image.fallbackAssetName != nil {
            RemoteImageView(
                url: image.url,
                fallbackAssetName: image.fallbackAssetName
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(DS.Color.borderS, lineWidth: 1))
        } else {
            Circle()
                .fill(kind == .source ? DS.Color.ochreSoft.opacity(0.72) : DS.Color.sageSoft.opacity(0.76))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: kind == .source ? "doc.text" : "person.crop.circle")
                        .font(.system(size: max(10, size * 0.48), weight: .semibold))
                        .foregroundStyle(kind == .source ? DS.Color.terracotta.opacity(0.72) : DS.Color.sageDeep.opacity(0.72))
                )
                .overlay(Circle().stroke(DS.Color.borderS, lineWidth: 1))
        }
    }
}

// MARK: - FeedCardSplit

/// Side-by-side card: 136pt image rail on the left, VStack of reason +
/// title + creator + meta on the right. Matches `.fcard--split` in the
/// prototype (line 804+).
struct FeedCardSplit: View {
    let image: FeedImageSource
    let reasonKind: ReasonKind
    let reasonText: String
    let title: String
    let creatorName: String
    let creatorAvatar: FeedImageSource
    let identityKind: FeedIdentityKind
    let meta: FeedMetaLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            FeedThumbnailView(
                image: image,
                symbolName: identityKind == .source ? "doc.text" : "fork.knife"
            )
            .frame(width: 136)
            .frame(maxHeight: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                ReasonChip(kind: reasonKind, text: reasonText)
                    .padding(.bottom, 2)

                Text(title)
                    .font(DS.Font.serif(16, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    FeedIdentityAvatar(
                        image: creatorAvatar,
                        kind: identityKind,
                        size: 18
                    )

                    Text(creatorName)
                        .font(DS.Font.sans(11))
                        .foregroundStyle(DS.Color.inkMuted)
                        .lineLimit(1)
                }

                metaRow
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 150)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
        .dsShadow(.s1)
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(meta.primary)
                .font(DS.Font.sans(11))
                .foregroundStyle(DS.Color.inkMuted)
            if let secondary = meta.secondary {
                Circle()
                    .fill(DS.Color.inkFaint)
                    .frame(width: 3, height: 3)
                Text(secondary)
                    .font(DS.Font.sans(11))
                    .foregroundStyle(DS.Color.inkMuted)
            }
        }
    }
}

// MARK: - FeedCardCompact

/// Single-row card: 72pt square thumb, 2-line title, small meta strip and
/// chevron. Matches `.fcard--compact` in the prototype (line 849+).
struct FeedCardCompact: View {
    let image: FeedImageSource
    let reasonKind: ReasonKind
    let reasonText: String
    let title: String
    let creatorName: String?
    let thumbnailSymbolName: String
    let meta: FeedMetaLine

    var body: some View {
        HStack(spacing: 12) {
            FeedThumbnailView(
                image: image,
                symbolName: thumbnailSymbolName
            )
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                ReasonChip(kind: reasonKind, text: reasonText)
                    .padding(.bottom, 1)

                Text(title)
                    .font(DS.Font.serif(15, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let creator = creatorName, !creator.isEmpty {
                    Text(creator)
                        .font(DS.Font.sans(10.5, weight: .medium))
                        .foregroundStyle(DS.Color.inkMuted)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(meta.primary)
                        .font(DS.Font.sans(10.5))
                        .foregroundStyle(DS.Color.inkMuted)
                    if let secondary = meta.secondary {
                        Circle()
                            .fill(DS.Color.inkFaint)
                            .frame(width: 3, height: 3)
                        Text(secondary)
                            .font(DS.Font.sans(10.5))
                            .foregroundStyle(DS.Color.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Color.inkFaint)
                .padding(.trailing, 2)
        }
        .padding(10)
        .frame(minHeight: 92)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
        .dsShadow(.s1)
    }
}

// MARK: - Full-bleed band scaffolding

/// Full-bleed coloured band. The caller positions it in a VStack without
/// horizontal padding — the band bleeds 16pt to each edge and applies its
/// own internal gutter, matching `.band` in the prototype (line 898+).
struct FullBleedBand<Content: View>: View {
    enum Tone { case sage, ochre }

    let tone: Tone
    let content: Content

    init(tone: Tone, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .background(toneColor)
        .padding(.vertical, 8)
    }

    private var toneColor: Color {
        switch tone {
        case .sage:  return DS.Color.sageSoft
        case .ochre: return DS.Color.ochreSoft
        }
    }
}

// MARK: - PeakCarouselBand

/// Single card inside `PeakCarouselBand`.
struct PeakIngredientCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let image: FeedImageSource

    init(id: String, title: String, subtitle: String, image: FeedImageSource) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }
}

/// Sage band with an eyebrow + serif headline + horizontal scroller of
/// 152pt peak cards. Matches `.band` + `.peak-scroll` (line 928+).
struct PeakCarouselBand: View {
    let kicker: String
    let title: String
    let titleEmphasis: String?
    let cards: [PeakIngredientCard]
    var onSelect: (PeakIngredientCard) -> Void = { _ in }

    var body: some View {
        FullBleedBand(tone: .sage) {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.sageDeep)
                    .padding(.bottom, 4)

                headline
                    .padding(.bottom, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(cards) { card in
                            Button {
                                onSelect(card)
                            } label: {
                                PeakCardTile(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // Negate the band's 16pt horizontal padding so the carousel
                // bleeds to the screen edge (matches `.peak-scroll` -16px).
                .padding(.horizontal, -16)
                .contentMargins(.horizontal, 16, for: .scrollContent)
            }
        }
    }

    @ViewBuilder
    private var headline: some View {
        let plain = Text(title)
            .font(DS.Font.serif(22, weight: .medium))
            .foregroundColor(DS.Color.ink)

        if let emphasis = titleEmphasis, !emphasis.isEmpty {
            let emphasisText = Text(emphasis)
                .font(DS.Font.serif(22, weight: .regular, italic: true))
                .foregroundColor(DS.Color.sageDeep)
            // iOS 26 deprecated `Text + Text`; interpolating Text values inside
            // another Text preserves per-segment styling (font, color, italic).
            Text("\(plain) \(emphasisText)")
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            plain
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PeakCardTile: View {
    let card: PeakIngredientCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImageView(
                url: card.image.url,
                fallbackAssetName: card.image.fallbackAssetName
            )
            .frame(width: 152, height: 96)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(DS.Font.serif(13.5, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.subtitle)
                    .font(DS.Font.sans(10))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(width: 152, alignment: .topLeading)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Color.sageDeep.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - TipCardBand

/// Ochre band with a big serif italic quote mark and an editorial tip.
/// Matches `.tip` (line 983+).
struct TipCardBand: View {
    let kicker: String
    let text: String
    let textEmphasis: String?
    let ctaText: String
    var isInteractive: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        FullBleedBand(tone: .ochre) {
            HStack(alignment: .top, spacing: 14) {
                Text("\u{201C}")
                    .font(DS.Font.serif(48, weight: .regular, italic: true))
                    .foregroundStyle(DS.Color.ochre)
                    .frame(height: 30, alignment: .top)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text(kicker)
                        .font(DS.Font.mono(10, weight: .medium))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.ochre)

                    tipText
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isInteractive {
                        Button(action: onTap) {
                            HStack(spacing: 4) {
                                Text(ctaText)
                                    .font(DS.Font.sans(12, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(DS.Color.terracotta)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tipText: some View {
        let plain = Text(text)
            .font(DS.Font.serif(19))
            .foregroundColor(DS.Color.ink)

        if let emphasis = textEmphasis, !emphasis.isEmpty {
            let emphasisText = Text(emphasis)
                .font(DS.Font.serif(19, weight: .regular, italic: true))
                .foregroundColor(DS.Color.terracotta)
            // iOS 26 deprecated `Text + Text`; use Text-in-Text interpolation.
            Text("\(plain) \(emphasisText)")
        } else {
            plain
        }
    }
}

// MARK: - CollectionTile

/// Editorial collection with a left mosaic (1 big + 2 small thumbs) and a
/// right column holding kicker / title / meta / CTA. Matches `.collection`
/// (line 1033+). `thumbs` should provide 3 images; missing entries fall back
/// to the soft card color.
struct CollectionTile: View {
    let kicker: String
    let title: String
    let meta: String
    let ctaText: String
    let thumbs: [FeedImageSource]
    var isInteractive: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        Group {
            if isInteractive {
                Button(action: onTap) {
                    cardBody
                }
                .buttonStyle(.plain)
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: 0) {
            mosaic
                .frame(width: 150, height: 150)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(kicker)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.sageDeep)

                Text(title)
                    .font(DS.Font.serif(17, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(meta)
                    .font(DS.Font.sans(11.5))
                    .foregroundStyle(DS.Color.inkMuted)
                    .padding(.top, 2)

                if isInteractive {
                    HStack(spacing: 4) {
                        Text(ctaText)
                            .font(DS.Font.sans(12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.sageDeep)
                    .padding(.top, 6)
                }
            }
            .padding(.vertical, 14)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 150)
        }
        .frame(height: 150)
        .background(DS.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
        .dsShadow(.s1)
    }

    @ViewBuilder
    private var mosaic: some View {
        HStack(spacing: 2) {
            mosaicTile(at: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 2) {
                mosaicTile(at: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                mosaicTile(at: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 74)
        }
        .background(DS.Color.cardSoft)
    }

    @ViewBuilder
    private func mosaicTile(at index: Int) -> some View {
        if index < thumbs.count, thumbs[index].url != nil || thumbs[index].fallbackAssetName != nil {
            RemoteImageView(
                url: thumbs[index].url,
                fallbackAssetName: thumbs[index].fallbackAssetName
            )
            .aspectRatio(contentMode: .fill)
            .clipped()
        } else {
            DS.Color.cardSoft
        }
    }
}

// MARK: - CommunityPulseBand

/// Neutral band: pulsing live dot + copy + stack of avatars. Matches
/// `.pulse__row` used inside a sage band (line 1101+).
struct CommunityPulseBand: View {
    let liveLabel: String
    let headline: String
    let emphasis: String?
    let subline: String
    let avatars: [FeedImageSource]

    @State private var pulse: Bool = false

    var body: some View {
        FullBleedBand(tone: .sage) {
            HStack(alignment: .center, spacing: 14) {
                if !avatars.isEmpty {
                    avatarStack
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(DS.Color.sageDeep)
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulse ? 1.2 : 1)
                            .opacity(pulse ? 1 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                value: pulse
                            )
                        Text(liveLabel)
                            .font(DS.Font.mono(9, weight: .medium))
                            .kerning(0.9)
                            .textCase(.uppercase)
                            .foregroundStyle(DS.Color.sageDeep)
                    }

                    headlineText
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subline)
                        .font(DS.Font.sans(10.5))
                        .foregroundStyle(DS.Color.inkSoft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Color.card.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DS.Color.sageDeep.opacity(0.14), lineWidth: 1)
            )
        }
        .onAppear { pulse = true }
    }

    @ViewBuilder
    private var headlineText: some View {
        let base = Text(headline)
            .font(DS.Font.sans(12.5, weight: .semibold))
            .foregroundColor(DS.Color.ink)

        if let em = emphasis, !em.isEmpty {
            let emText = Text(em)
                .font(DS.Font.sans(12.5, weight: .bold))
                .foregroundColor(DS.Color.sageDeep)
            // iOS 26 deprecated `Text + Text`; use Text-in-Text interpolation.
            Text("\(emText) \(base)")
        } else {
            base
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(avatars.prefix(4).enumerated()), id: \.offset) { _, avatar in
                RemoteImageView(
                    url: avatar.url,
                    fallbackAssetName: avatar.fallbackAssetName
                )
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Color.card, lineWidth: 2))
            }
        }
    }
}

// MARK: - NudgeCard

/// Inline follow nudge. Matches `.nudge` (line 1160+). `onFollow` is
/// fired when the user taps the trailing capsule.
struct NudgeCard: View {
    let kicker: String
    let name: String
    let bio: String
    let reason: String
    let avatar: FeedImageSource
    let followLabel: String
    let isFollowing: Bool
    var onFollow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                Text(kicker)
                    .font(DS.Font.mono(10, weight: .medium))
                    .kerning(1.0)
                    .textCase(.uppercase)
            }
            .foregroundStyle(DS.Color.sageDeep)

            HStack(spacing: 12) {
                RemoteImageView(
                    url: avatar.url,
                    fallbackAssetName: avatar.fallbackAssetName
                )
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Color.card, lineWidth: 2))
                .dsShadow(.s1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(DS.Font.sans(14, weight: .semibold))
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(1)
                    Text(bio)
                        .font(DS.Font.sans(11))
                        .foregroundStyle(DS.Color.inkSoft)
                        .lineLimit(1)
                    Text(reason)
                        .font(DS.Font.mono(9.5, weight: .regular))
                        .kerning(0.5)
                        .foregroundStyle(DS.Color.sageDeep)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onFollow) {
                    Text(followLabel)
                        .font(DS.Font.sans(12, weight: .semibold))
                        .foregroundStyle(isFollowing ? DS.Color.sageDeep : DS.Color.card)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isFollowing ? Color.clear : DS.Color.sageDeep)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(DS.Color.sageDeep.opacity(isFollowing ? 0.3 : 0), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [DS.Color.sageSoft, DS.Color.cardSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.sageDeep.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#if DEBUG

private let sampleImage = FeedImageSource(url: nil, fallbackAssetName: nil)

#Preview("ReasonChip — all variants") {
    VStack(alignment: .leading, spacing: 10) {
        ReasonChip(kind: .fridge,   text: "Hai 6 ingredienti su 8")
        ReasonChip(kind: .creator,  text: "Seguito da te")
        ReasonChip(kind: .similar,  text: "Simile a ciò che cucini")
        ReasonChip(kind: .peak,     text: "Pomodoro al picco")
        ReasonChip(kind: .trending, text: "235 salvataggi oggi")
        ReasonChip(kind: .fresh,    text: "Nuovo · 2 ore fa")
    }
    .padding()
    .background(DS.Color.bg)
}

#Preview("FeedCardSplit") {
    FeedCardSplit(
        image: sampleImage,
        reasonKind: .fridge,
        reasonText: "6 ingredienti su 8",
        title: "Pasta al limone con ricotta salata",
        creatorName: "Marta Sangiovanni",
        creatorAvatar: sampleImage,
        identityKind: .creator,
        meta: FeedMetaLine(primary: "25 min", secondary: "Facile")
    )
    .padding()
    .background(DS.Color.bg)
}

#Preview("FeedCardCompact") {
    VStack(spacing: 12) {
        FeedCardCompact(
            image: sampleImage,
            reasonKind: .trending,
            reasonText: "148 salvataggi",
            title: "Risotto alle fragole e basilico viola",
            creatorName: "Luca",
            thumbnailSymbolName: "fork.knife",
            meta: FeedMetaLine(primary: "35 min", secondary: "Medio")
        )
        FeedCardCompact(
            image: sampleImage,
            reasonKind: .similar,
            reasonText: "Come il tuo ultimo salvato",
            title: "Tortino di zucchine e pecorino",
            creatorName: nil,
            thumbnailSymbolName: "fork.knife",
            meta: FeedMetaLine(primary: "40 min", secondary: nil)
        )
    }
    .padding()
    .background(DS.Color.bg)
}

#Preview("PeakCarouselBand") {
    PeakCarouselBand(
        kicker: "Picco di stagione",
        title: "Cucina quello che è",
        titleEmphasis: "al massimo ora",
        cards: [
            PeakIngredientCard(id: "1", title: "Asparagi", subtitle: "Settimana 16", image: sampleImage),
            PeakIngredientCard(id: "2", title: "Piselli freschi", subtitle: "Settimana 16", image: sampleImage),
            PeakIngredientCard(id: "3", title: "Fragole", subtitle: "Settimana 16", image: sampleImage),
            PeakIngredientCard(id: "4", title: "Finocchi", subtitle: "Settimana 16", image: sampleImage),
        ]
    )
    .background(DS.Color.bg)
}

#Preview("TipCardBand") {
    TipCardBand(
        kicker: "Consiglio della settimana",
        text: "Taglia gli asparagi",
        textEmphasis: "appena prima di cuocerli per non perdere succosità.",
        ctaText: "Tutti i consigli"
    )
    .background(DS.Color.bg)
}

#Preview("CollectionTile") {
    CollectionTile(
        kicker: "Collezione · Primavera",
        title: "12 piatti da pranzo sotto i 30 minuti",
        meta: "12 ricette · curata da Season",
        ctaText: "Apri la collezione",
        thumbs: [sampleImage, sampleImage, sampleImage]
    )
    .padding()
    .background(DS.Color.bg)
}

#Preview("CommunityPulseBand") {
    CommunityPulseBand(
        liveLabel: "Live ora",
        headline: "persone stanno cucinando con Season",
        emphasis: "23",
        subline: "3 nuove ricette salvate negli ultimi 15 min",
        avatars: [sampleImage, sampleImage, sampleImage, sampleImage]
    )
    .background(DS.Color.bg)
}

#Preview("NudgeCard — follow") {
    NudgeCard(
        kicker: "Consigliato per te",
        name: "Giulia Ferrara",
        bio: "Cuoca italiana · Torino",
        reason: "Perché segui Marta e Luca",
        avatar: sampleImage,
        followLabel: "Segui",
        isFollowing: false
    )
    .padding()
    .background(DS.Color.bg)
}

#Preview("NudgeCard — following") {
    NudgeCard(
        kicker: "Consigliato per te",
        name: "Giulia Ferrara",
        bio: "Cuoca italiana · Torino",
        reason: "Perché segui Marta e Luca",
        avatar: sampleImage,
        followLabel: "Seguito",
        isFollowing: true
    )
    .padding()
    .background(DS.Color.bg)
}

#endif
