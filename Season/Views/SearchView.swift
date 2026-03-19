import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @State private var query = ""

    var body: some View {
        List {
            let ingredientResults = viewModel.searchIngredientResults(query: query)
            let recipeResults = viewModel.searchRecipeResults(query: query)
            let primaryType = viewModel.searchPrimaryType(for: query)

            if ingredientResults.isEmpty && recipeResults.isEmpty {
                EmptyStateCard(
                    symbol: "magnifyingglass.circle",
                    title: viewModel.localizer.text(.searchEmptyTitle),
                    subtitle: viewModel.localizer.text(.searchEmptySubtitle)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                if primaryType == .recipes {
                    recipesSection(results: recipeResults)
                    ingredientsSection(results: ingredientResults)
                } else {
                    ingredientsSection(results: ingredientResults)
                    recipesSection(results: recipeResults)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.localizer.text(.searchTab))
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .searchable(text: $query, prompt: viewModel.localizer.text(.searchPlaceholder))
    }

    @ViewBuilder
    private func ingredientsSection(results: [IngredientSearchResult]) -> some View {
        if !results.isEmpty {
            Section(header: Text(viewModel.localizer.text(.ingredients)).textCase(nil)) {
                ForEach(results) { result in
                    SeasonCard {
                        HStack(alignment: .center, spacing: 14) {
                            ingredientThumbnail(for: result)

                            NavigationLink {
                                ingredientDestination(for: result)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.body)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if case .produce(let item) = result.source {
                                    SeasonalStatusBadge(
                                        score: item.seasonalityScore(month: viewModel.currentMonth),
                                        delta: item.seasonalityDelta(month: viewModel.currentMonth),
                                        localizer: viewModel.localizer
                                    )
                                }
                            }
                            .buttonStyle(.plain)

                            quickAddIngredientButton(for: result)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    @ViewBuilder
    private func recipesSection(results: [RankedRecipe]) -> some View {
        if !results.isEmpty {
            Section(header: Text(viewModel.localizer.text(.recipes)).textCase(nil)) {
                ForEach(results) { ranked in
                    SeasonCard {
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink {
                                RecipeDetailView(
                                    rankedRecipe: ranked,
                                    viewModel: viewModel,
                                    shoppingListViewModel: shoppingListViewModel,
                                    isFollowingAuthor: isFollowing(author: ranked.recipe.author),
                                    onToggleFollow: { toggleFollow(for: ranked.recipe.author) }
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    RecipeThumbnailView(recipe: ranked.recipe, size: 48)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ranked.recipe.title)
                                            .font(.body.weight(.semibold))
                                            .lineLimit(2)
                                            .foregroundStyle(.primary)

                                        Text(ranked.recipe.author)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text("\(ranked.seasonalMatchPercent)%")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            let confirmedDietaryTags = viewModel.confirmedDietaryTags(for: ranked.recipe)
                            if !confirmedDietaryTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(confirmedDietaryTags) { tag in
                                            RecipeDietaryTagPill(tag: tag, localizer: viewModel.localizer)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    @ViewBuilder
    private func quickAddIngredientButton(for result: IngredientSearchResult) -> some View {
        let isInList = ingredientIsInList(result)

        Button {
            switch result.source {
            case .produce(let item):
                shoppingListViewModel.add(item)
            case .basic(let basic):
                shoppingListViewModel.add(basic)
            }
        } label: {
            Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(isInList ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isInList)
    }

    private func ingredientIsInList(_ result: IngredientSearchResult) -> Bool {
        switch result.source {
        case .produce(let item):
            return shoppingListViewModel.contains(item)
        case .basic(let basic):
            return shoppingListViewModel.contains(basic)
        }
    }

    @ViewBuilder
    private func ingredientDestination(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceDetailView(
                item: item,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        case .basic(let basic):
            ProduceDetailView(
                basicIngredient: basic,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    @ViewBuilder
    private func ingredientThumbnail(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceThumbnailView(item: item, size: 46)
        case .basic:
            Image(systemName: "leaf")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        }
    }

    private var followedAuthorsSet: Set<String> {
        Set(
            followedAuthorsRaw
                .split(separator: "|")
                .map { String($0) }
                .filter { !$0.isEmpty }
        )
    }

    private func isFollowing(author: String) -> Bool {
        followedAuthorsSet.contains(author)
    }

    private func toggleFollow(for author: String) {
        var updated = followedAuthorsSet
        if updated.contains(author) {
            updated.remove(author)
        } else {
            updated.insert(author)
        }
        followedAuthorsRaw = updated.sorted().joined(separator: "|")
    }
}
