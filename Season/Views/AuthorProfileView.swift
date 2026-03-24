import SwiftUI

struct AuthorProfileView: View {
    struct CreatorSocialLink: Identifiable, Hashable {
        let platform: RecipeExternalPlatform
        let url: String
        var id: String { "\(platform.rawValue)-\(url)" }
    }

    let authorName: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    let profileSocialLinks: [CreatorSocialLink]
    let profileAvatarURL: String?
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @Environment(\.openURL) private var openURL

    init(
        authorName: String,
        viewModel: ProduceViewModel,
        shoppingListViewModel: ShoppingListViewModel,
        profileSocialLinks: [CreatorSocialLink] = [],
        profileAvatarURL: String? = nil
    ) {
        self.authorName = authorName
        self.viewModel = viewModel
        self.shoppingListViewModel = shoppingListViewModel
        self.profileSocialLinks = profileSocialLinks
        self.profileAvatarURL = profileAvatarURL
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: SeasonSpacing.lg) {
                    VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                        HStack(alignment: .center, spacing: SeasonSpacing.sm) {
                            Circle()
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    avatarContent
                                )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(authorName)
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)
                                Text(viewModel.localizer.text(.creatorProfileSubtitle))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Button {
                                toggleFollow()
                            } label: {
                                Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.top, 8)

                        InlineStatsRow(stats: [
                            String(format: viewModel.localizer.text(.recipeCountFormat), rankedRecipes.count),
                            estimatedFollowersStatText,
                            String(format: viewModel.localizer.text(.totalCrispyReceivedFormat), totalCrispy),
                            "\(Int(averageSeasonalMatch.rounded()))% \(viewModel.localizer.text(.seasonalMatch).lowercased())"
                        ])
                        .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.text(.badges))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

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
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .fill(Color(.secondarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .stroke(Color(.separator).opacity(0.12), lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    if !profileSocialLinks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.localizer.accountSocialProfilesTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(profileSocialLinks) { link in
                                Button {
                                    guard let url = URL(string: link.url) else { return }
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 8) {
                                        socialIcon(for: link.platform)
                                            .frame(width: 20, height: 20)
                                            .frame(minWidth: 32, minHeight: 32)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(link.platform == .instagram ? viewModel.localizer.commonInstagram : viewModel.localizer.commonTikTok)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Text(socialDisplayValue(for: link))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary.opacity(0.9))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section {
                if rankedRecipes.isEmpty {
                    EmptyStateCard(
                        symbol: "fork.knife.circle",
                        title: viewModel.localizer.text(.publishedRecipes),
                        subtitle: viewModel.localizer.text(.searchEmptySubtitle)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(rankedRecipes) { ranked in
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: ranked,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            HStack(spacing: 8) {
                                RecipeThumbnailView(recipe: ranked.recipe, size: 44)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ranked.recipe.title)
                                        .font(.body.weight(.semibold))
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)

                                    Text(viewModel.recipeReasonText(for: ranked))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    Text("\(viewModel.compactCountText(ranked.recipe.crispy)) \(viewModel.localizer.text(.crispyAction).lowercased())")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                SeasonalStatusBadge(
                                    score: ranked.seasonalityScore,
                                    localizer: viewModel.localizer
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                SectionTitleCountRow(
                    title: viewModel.localizer.text(.publishedRecipes),
                    countText: String(format: viewModel.localizer.text(.recipeCountFormat), rankedRecipes.count)
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    private var rankedRecipes: [RankedRecipe] {
        viewModel.rankedRecipesByAuthor(authorName)
    }

    private var followedAuthorsSet: Set<String> {
        Set(
            followedAuthorsRaw
                .split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private var isFollowing: Bool {
        followedAuthorsSet.contains(authorName)
    }

    private var followerCount: Int {
        viewModel.followerCount(for: authorName, isFollowedByCurrentUser: isFollowing)
    }

    private var estimatedFollowersStatText: String {
        "~" + String(format: viewModel.localizer.text(.followersCountFormat), followerCount)
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
        let trimmed = profileAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = trimmed.isEmpty ? nil : URL(string: trimmed)

        RemoteImageView(
            url: url,
            fallbackAssetName: nil
        )
        .clipShape(Circle())
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
        var updated = followedAuthorsSet
        if updated.contains(authorName) {
            updated.remove(authorName)
        } else {
            updated.insert(authorName)
        }
        followedAuthorsRaw = updated.sorted().joined(separator: "|")
    }
}
