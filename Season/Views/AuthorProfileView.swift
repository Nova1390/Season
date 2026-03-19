import SwiftUI

struct AuthorProfileView: View {
    let authorName: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                    HStack(alignment: .top, spacing: SeasonSpacing.sm) {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 68, height: 68)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authorName)
                                .font(.title2.weight(.semibold))
                            Text(viewModel.localizer.text(.creatorProfileSubtitle))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            toggleFollow()
                        } label: {
                            Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                                .font(.subheadline.weight(.semibold))
                                .frame(minWidth: 112)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }

                    InlineStatsRow(
                        stats: [
                            String(format: viewModel.localizer.text(.recipeCountFormat), rankedRecipes.count),
                            String(format: viewModel.localizer.text(.followersCountFormat), followerCount),
                            String(format: viewModel.localizer.text(.totalCrispyReceivedFormat), totalCrispy),
                            "\(Int(averageSeasonalMatch.rounded()))% \(viewModel.localizer.text(.seasonalMatch).lowercased())"
                        ]
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.localizer.text(.badges))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if authorBadges.isEmpty {
                            Text(viewModel.localizer.text(.noBadgesYet))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(authorBadges) { badge in
                                        UserBadgePill(badge: badge, localizer: viewModel.localizer)
                                    }
                                }
                            }
                        }
                    }
                }
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
                            HStack(spacing: 10) {
                                RecipeThumbnailView(recipe: ranked.recipe, size: 44)

                                VStack(alignment: .leading, spacing: 3) {
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
                            .padding(.vertical, 4)
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

    private var totalCrispy: Int {
        viewModel.totalCrispy(for: authorName)
    }

    private var averageSeasonalMatch: Double {
        viewModel.averageSeasonalMatch(for: authorName)
    }

    private var authorBadges: [UserBadge] {
        viewModel.badges(for: authorName)
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
