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
    private let seasonGreen = Color(red: 0.33, green: 0.40, blue: 0.29)

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
            VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                profileHeaderSection

                if !profileSocialLinks.isEmpty {
                    socialLinksSection
                }

                creatorRecipesSection
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance)
        }
        .background(SeasonColors.primarySurface)
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
        VStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 116, height: 116)
                    .overlay(avatarContent)
                    .overlay(
                        Circle()
                            .stroke(seasonGreen.opacity(0.22), lineWidth: 1.1)
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)

                if !authorBadges.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white, seasonGreen)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                        )
                }
            }

            VStack(spacing: 3) {
                Text(authorName)
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)

                Text(viewModel.localizer.text(.creatorProfileSubtitle))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !authorBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(authorBadges) { badge in
                            UserBadgePill(badge: badge, localizer: viewModel.localizer)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.78))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(seasonGreen.opacity(0.12), lineWidth: 0.7)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 2)
            }

            if canShowFollowButton {
                Button {
                    toggleFollow()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                            .font(.subheadline.weight(.semibold))
                        Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(isFollowing ? Color.primary : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(buttonBackgroundStyle)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(seasonGreen.opacity(isFollowing ? 0.10 : 0.05), lineWidth: 0.6)
                    )
                }
                .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
                .accessibilityLabel(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
            }

            HStack(spacing: 0) {
                profileStatColumn(
                    value: formattedFollowerCount(followerCountValue),
                    label: viewModel.localizer.text(.followers)
                )

                Rectangle()
                    .fill(seasonGreen.opacity(0.12))
                    .frame(width: 1, height: 30)

                profileStatColumn(
                    value: "\(rankedRecipes.count.compactFormatted())",
                    label: viewModel.localizer.text(.recipes)
                )

                Rectangle()
                    .fill(seasonGreen.opacity(0.12))
                    .frame(width: 1, height: 30)

                profileStatColumn(
                    value: "\(totalCrispy.compactFormatted())",
                    label: viewModel.localizer.text(.crispyAction)
                )
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.68))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(seasonGreen.opacity(0.09), lineWidth: 0.7)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.93, blue: 0.88).opacity(0.92),
                            Color(red: 0.94, green: 0.91, blue: 0.85).opacity(0.65),
                            Color(red: 0.92, green: 0.89, blue: 0.82).opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(seasonGreen.opacity(0.11), lineWidth: 0.8)
        )
    }

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SeasonSectionHeader(title: viewModel.localizer.accountSocialProfilesTitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profileSocialLinks) { link in
                        socialLinkChip(for: link)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.52))
        )
    }

    private var creatorRecipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                VStack(spacing: 10) {
                    featuredRecipeCard
                    ForEach(Array(rankedRecipes.dropFirst())) { ranked in
                        creatorRecipeCard(ranked)
                    }
                }
            }
        }
    }

    private func creatorRecipeCard(_ ranked: RankedRecipe) -> some View {
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
                cardBackground: Color(.systemBackground),
                cardBackgroundOpacity: 0.92,
                cardBorderOpacity: 0.05,
                cardShadowOpacity: 0.015,
                cardShadowRadius: 8,
                cardShadowY: 2
            )
        }
        .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
    }

    @ViewBuilder
    private var featuredRecipeCard: some View {
        if let featured = rankedRecipes.first {
            NavigationLink {
                RecipeDetailView(
                    rankedRecipe: featured,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            } label: {
                RecipeCardView(
                    recipe: featured.recipe,
                    title: featured.recipe.title,
                    subtitle: viewModel.recipeReasonText(for: featured),
                    metadataText: "\(viewModel.compactCountText(featured.recipe.crispy)) \(viewModel.localizer.text(.crispyAction).lowercased())",
                    seasonalityScore: featured.seasonalityScore,
                    localizer: viewModel.localizer,
                    variant: .feedLarge,
                    cardBackground: Color(.systemBackground),
                    cardBackgroundOpacity: 0.96,
                    cardBorderOpacity: 0.05,
                    cardShadowOpacity: 0.02,
                    cardShadowRadius: 10,
                    cardShadowY: 3
                )
            }
            .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
        }
    }

    private func socialLinkChip(for link: CreatorSocialLink) -> some View {
        Button {
            guard let url = URL(string: link.url) else { return }
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                socialIcon(for: link.platform)
                    .frame(width: 16, height: 16)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(seasonGreen.opacity(0.12))
                    )
                Text(socialDisplayValue(for: link))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(seasonGreen.opacity(0.09), lineWidth: 0.7)
            )
        }
        .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
    }

    private func profileStatColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(seasonGreen)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private var buttonBackgroundStyle: AnyShapeStyle {
        if isFollowing {
            return AnyShapeStyle(Color(.tertiarySystemGroupedBackground))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [SeasonColors.seasonGreen, SeasonColors.seasonGreen.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
