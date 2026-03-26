import SwiftUI

struct AuthorProfileView: View {
    struct CreatorSocialLink: Identifiable, Hashable {
        let platform: RecipeExternalPlatform
        let url: String
        var id: String { "\(platform.rawValue)-\(url)" }
    }

    let authorName: String
    let creatorID: String?
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @ObservedObject private var followStore = FollowStore.shared
    let profileSocialLinks: [CreatorSocialLink]
    let profileAvatarURL: String?
    @Environment(\.openURL) private var openURL

    init(
        authorName: String,
        creatorID: String? = nil,
        viewModel: ProduceViewModel,
        shoppingListViewModel: ShoppingListViewModel,
        profileSocialLinks: [CreatorSocialLink] = [],
        profileAvatarURL: String? = nil
    ) {
        self.authorName = authorName
        self.creatorID = creatorID
        self.viewModel = viewModel
        self.shoppingListViewModel = shoppingListViewModel
        self.profileSocialLinks = profileSocialLinks
        self.profileAvatarURL = profileAvatarURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                profileHeaderSection

                if !profileSocialLinks.isEmpty {
                    Divider().opacity(0.14)
                    socialLinksSection
                }

                Divider().opacity(0.14)
                creatorRecipesSection
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .onAppear {
            print("[SEASON_FOLLOW_IDENTITY] phase=profile_appear creator_id=\(canonicalCreatorID ?? "nil") creator_name=\(authorName) was_following=\(isFollowing)")
        }
    }

    private var profileHeaderSection: some View {
        SeasonAuthorHeaderView(
            name: authorName,
            subtitle: viewModel.localizer.text(.creatorProfileSubtitle),
            metadataText: compactRecipeCountText,
            avatar: {
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 92, height: 92)
                    .overlay(avatarContent)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.55, green: 0.46, blue: 0.30).opacity(0.25), lineWidth: 1.0)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            },
            trailingAction: {
                if canShowFollowButton {
                    Button {
                        toggleFollow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                                .font(.caption.weight(.medium))
                                .frame(width: 14)
                            Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(isFollowing ? .primary : Color(.systemBackground))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(minWidth: 108)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isFollowing
                                    ? Color(.tertiarySystemGroupedBackground)
                                    : Color.primary.opacity(0.76)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                }
            },
            stats: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SeasonStatChip(
                            icon: "person.2.fill",
                            text: estimatedFollowersStatText,
                            background: Color(red: 0.88, green: 0.83, blue: 0.73).opacity(0.46)
                        )
                        SeasonStatChip(
                            icon: "flame.fill",
                            text: "\(totalCrispy.compactFormatted()) \(viewModel.localizer.text(.crispyAction).lowercased())",
                            background: Color(red: 0.90, green: 0.78, blue: 0.63).opacity(0.46)
                        )
                        SeasonStatChip(
                            icon: "leaf",
                            text: "\(Int(averageSeasonalMatch.rounded()))% \(viewModel.localizer.text(.seasonalMatch).lowercased())",
                            background: Color(red: 0.77, green: 0.86, blue: 0.75).opacity(0.4)
                        )
                    }
                }
            },
            badges: {
                VStack(alignment: .leading, spacing: 8) {
                    SeasonSectionHeader(title: viewModel.localizer.text(.badges))

                    if authorBadges.isEmpty {
                        Text(viewModel.localizer.text(.noBadgesYet))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(authorBadges) { badge in
                                UserBadgePill(badge: badge, localizer: viewModel.localizer)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.89, green: 0.85, blue: 0.77).opacity(0.33))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color(red: 0.53, green: 0.46, blue: 0.33).opacity(0.12), lineWidth: 0.6)
                                    )
                            }
                        }
                    }
                }
            }
        )
        .padding(SeasonSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.92),
                            Color(red: 0.94, green: 0.90, blue: 0.82).opacity(0.58),
                            Color(red: 0.91, green: 0.87, blue: 0.80).opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.45, green: 0.38, blue: 0.26).opacity(0.12), lineWidth: 0.8)
        )
    }

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.localizer.accountSocialProfilesTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profileSocialLinks) { link in
                        Button {
                            guard let url = URL(string: link.url) else { return }
                            openURL(url)
                        } label: {
                            HStack(spacing: 8) {
                                socialIcon(for: link.platform)
                                    .frame(width: 16, height: 16)
                                Text(link.platform == .instagram ? viewModel.localizer.commonInstagram : viewModel.localizer.commonTikTok)
                                    .font(.subheadline.weight(.semibold))
                                Text(socialDisplayValue(for: link))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var creatorRecipesSection: some View {
        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            SeasonSectionHeader(
                title: viewModel.localizer.text(.publishedRecipes),
                trailingText: compactRecipeCountText
            )

            if rankedRecipes.isEmpty {
                EmptyStateCard(
                    symbol: "fork.knife.circle",
                    title: viewModel.localizer.text(.publishedRecipes),
                    subtitle: viewModel.localizer.text(.searchEmptySubtitle)
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(rankedRecipes) { ranked in
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: ranked,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            RecipeCardView(
                                recipe: ranked.recipe,
                                title: ranked.recipe.title,
                                subtitle: viewModel.recipeReasonText(for: ranked),
                                metadataText: "\(viewModel.compactCountText(ranked.recipe.crispy)) \(viewModel.localizer.text(.crispyAction).lowercased())",
                                seasonalityScore: ranked.seasonalityScore,
                                localizer: viewModel.localizer,
                                variant: .profile,
                                cardBackground: SeasonColors.secondarySurface,
                                cardBackgroundOpacity: 0.55,
                                cardBorderOpacity: 0.05
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var rankedRecipes: [RankedRecipe] {
        viewModel.rankedRecipesByAuthor(authorName)
    }

    private var canonicalCreatorID: String? {
        let cleaned = (creatorID ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !cleaned.isEmpty, cleaned != "unknown" else { return nil }
        guard UUID(uuidString: cleaned) != nil else {
            print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(cleaned)")
            if cleaned.range(of: "^[a-z0-9_\\-.]+$", options: .regularExpression) != nil &&
                !cleaned.contains("-") {
                print("[SEASON_FOLLOW_IDENTITY] phase=legacy_name_rejected value=\(cleaned)")
            }
            return nil
        }
        return cleaned
    }

    private var currentCreatorID: String {
        CurrentUser.shared.creator.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canShowFollowButton: Bool {
        guard let canonicalCreatorID else { return false }
        return canonicalCreatorID != currentCreatorID
    }

    private var isFollowing: Bool {
        guard let canonicalCreatorID else { return false }
        return followStore.isFollowing(canonicalCreatorID)
    }

    private var followerCountValue: Int {
        followerCount(for: canonicalCreatorID, fallbackName: authorName)
    }

    private var estimatedFollowersStatText: String {
        "\(formattedFollowerCount(followerCountValue)) \(viewModel.localizer.text(.followers).lowercased())"
    }

    private var compactRecipeCountText: String {
        "\(rankedRecipes.count.compactFormatted()) \(viewModel.localizer.text(.recipes).lowercased())"
    }

    private var totalCrispy: Int {
        viewModel.totalCrispy(for: authorName)
    }

    private var averageSeasonalMatch: Double {
        viewModel.averageSeasonalMatch(for: authorName)
    }

    private var authorBadges: [UserBadge] {
        viewModel.badges(for: authorName)
    }

    @ViewBuilder
    private func socialIcon(for platform: RecipeExternalPlatform) -> some View {
        switch platform {
        case .instagram:
            Image("instagram_icon")
                .resizable()
                .scaledToFit()
        case .tiktok:
            Image("tiktok_icon")
                .resizable()
                .scaledToFit()
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        AvatarView(
            avatarURL: profileAvatarURL,
            size: 72,
            creatorID: canonicalCreatorID,
            displayName: authorName
        )
    }

    private func socialDisplayValue(for link: CreatorSocialLink) -> String {
        guard let url = URL(string: link.url),
              let host = url.host?.lowercased() else {
            return link.url
        }

        let pathParts = url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }

        switch link.platform {
        case .instagram:
            guard host.contains("instagram.com"), let username = pathParts.first else {
                return link.url
            }
            return username.hasPrefix("@") ? username : "@\(username)"
        case .tiktok:
            guard host.contains("tiktok.com"), let first = pathParts.first else {
                return link.url
            }
            return first.hasPrefix("@") ? first : "@\(first)"
        }
    }

    private func toggleFollow() {
        guard let canonicalCreatorID else { return }
        let wasFollowing = followStore.isFollowing(canonicalCreatorID)
        print("[SEASON_FOLLOW_IDENTITY] phase=profile_toggle creator_id=\(canonicalCreatorID) creator_name=\(authorName) was_following=\(wasFollowing)")
        followStore.toggleFollow(canonicalCreatorID)
    }
}
