import SwiftUI

struct AuthorProfileView: View {
    let authorName: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""

    var body: some View {
        List {
            Section {
                SeasonCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authorName)
                                    .font(.title3.weight(.semibold))
                                Text(String(format: viewModel.localizer.text(.recipeCountFormat), rankedRecipes.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Button {
                            toggleFollow()
                        } label: {
                            Text(isFollowing ? viewModel.localizer.text(.following) : viewModel.localizer.text(.follow))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: viewModel.localizer.text(.totalCrispyReceivedFormat), totalCrispy))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: viewModel.localizer.text(.averageSeasonalMatchFormat), averageSeasonalMatch))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !authorBadges.isEmpty {
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

            Section(header: Text(viewModel.localizer.text(.myRecipes)).textCase(nil)) {
                ForEach(rankedRecipes) { ranked in
                    SeasonCard {
                        HStack(spacing: 12) {
                            RecipeThumbnailView(recipe: ranked.recipe, size: 48)

                            VStack(alignment: .leading, spacing: 4) {
                                NavigationLink {
                                    RecipeDetailView(
                                        rankedRecipe: ranked,
                                        viewModel: viewModel,
                                        shoppingListViewModel: shoppingListViewModel,
                                        isFollowingAuthor: isFollowing,
                                        onToggleFollow: { toggleFollow() }
                                    )
                                } label: {
                                    Text(ranked.recipe.title)
                                        .font(.body.weight(.semibold))
                                }
                                .buttonStyle(.plain)

                                Text(viewModel.recipeReasonText(for: ranked))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            SeasonalStatusBadge(
                                score: ranked.seasonalityScore,
                                localizer: viewModel.localizer
                            )
                        }
                    }
                    .padding(.vertical, 1)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
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
