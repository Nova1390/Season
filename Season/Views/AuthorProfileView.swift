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
            VStack(alignment: .leading, spacing: 22) {
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
        .background(DS.Color.bg)
        .seasonTopBar(
            produceViewModel: viewModel,
            shoppingListViewModel: shoppingListViewModel,
            leading: .back
        )
        .onAppear {
            SeasonLog.debug("[SEASON_FOLLOW_IDENTITY] phase=profile_appear creator_id=\(canonicalCreatorID ?? "nil") creator_name=\(authorName) was_following=\(isFollowing)")
        }
    }

    private var profileHeaderSection: some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(DS.Color.sageSoft.opacity(0.58))
                    .frame(width: 122, height: 122)
                    .overlay(avatarContent)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.84), lineWidth: 4)
                    )
                    .shadow(color: DS.Color.ink.opacity(0.08), radius: 18, x: 0, y: 9)

                if !authorBadges.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white, DS.Color.sage)
                        .padding(7)
                        .background(
                            Circle()
                                .fill(DS.Color.card)
                        )
                        .overlay(
                            Circle()
                                .stroke(DS.Color.bg, lineWidth: 2)
                        )
                }
            }

            VStack(spacing: 5) {
                Text(authorName)
                    .font(DS.Font.serif(34, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                    .tracking(-0.4)
                    .multilineTextAlignment(.center)

                Text(viewModel.localizer.text(.creatorProfileSubtitle))
                    .font(DS.Font.sans(14, weight: .medium))
                    .foregroundStyle(DS.Color.inkMuted)
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
                                        .fill(DS.Color.card.opacity(0.78))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(DS.Color.borderM, lineWidth: 0.7)
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
                            .font(DS.Font.sans(16, weight: .bold))
                    }
                    .foregroundStyle(isFollowing ? DS.Color.ink : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(buttonBackgroundStyle)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.Color.border.opacity(isFollowing ? 0.95 : 0.16), lineWidth: 0.8)
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
                    .fill(DS.Color.borderM)
                    .frame(width: 1, height: 30)

                profileStatColumn(
                    value: "\(rankedRecipes.count.compactFormatted())",
                    label: viewModel.localizer.text(.recipes)
                )

                Rectangle()
                    .fill(DS.Color.borderM)
                    .frame(width: 1, height: 30)

                profileStatColumn(
                    value: "\(totalCrispy.compactFormatted())",
                    label: viewModel.localizer.text(.crispyAction)
                )
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.Color.card.opacity(0.72))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Color.card.opacity(0.98),
                            DS.Color.sageSoft.opacity(0.66),
                            DS.Color.ochreSoft.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DS.Color.borderM, lineWidth: 0.8)
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Color.cardSoft.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.Color.border.opacity(0.72), lineWidth: 0.7)
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
                cardBackgroundOpacity: 0.88,
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
                    cardBackgroundOpacity: 0.94,
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
                            .fill(DS.Color.sageSoft.opacity(0.76))
                    )
                Text(socialDisplayValue(for: link))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(DS.Color.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Color.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 0.7)
            )
        }
        .buttonStyle(PressableCardButtonStyle(pressedScale: 0.985))
    }

    private func profileStatColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Font.sans(17, weight: .bold))
                .foregroundStyle(DS.Color.ink)
            Text(label.uppercased())
                .font(DS.Font.mono(9.5, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(DS.Color.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private var buttonBackgroundStyle: AnyShapeStyle {
        if isFollowing {
            return AnyShapeStyle(DS.Color.card.opacity(0.82))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [DS.Color.sage, DS.Color.sageDeep.opacity(0.92)],
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
            SeasonLog.debug("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(cleaned)")
            if cleaned.range(of: "^[a-z0-9_\\-.]+$", options: .regularExpression) != nil &&
                !cleaned.contains("-") {
                SeasonLog.debug("[SEASON_FOLLOW_IDENTITY] phase=legacy_name_rejected value=\(cleaned)")
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
        if canonicalCreatorID == currentCreatorID {
            return 0
        }
        return followerCount(for: canonicalCreatorID, fallbackName: authorName)
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
        SeasonLog.debug("[SEASON_FOLLOW_IDENTITY] phase=profile_toggle creator_id=\(canonicalCreatorID) creator_name=\(authorName) was_following=\(wasFollowing)")
        followStore.toggleFollow(canonicalCreatorID)
    }
}
