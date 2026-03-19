import SwiftUI

struct AccountView: View {
    @Binding var selectedLanguage: String
    @Binding var nutritionGoalsRaw: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("accountUsername") private var accountUsername = "Anna"
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @State private var showingCreateRecipeAlert = false

    var body: some View {
        List {
            profileSection
            savedRecipesSection
            activeRecipesSection
            archivedRecipesSection
            settingsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.localizer.text(.accountTab))
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .alert(viewModel.localizer.text(.comingSoon), isPresented: $showingCreateRecipeAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private var profileSection: some View {
        Section(header: Text(viewModel.localizer.text(.profile)).textCase(nil)) {
            VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountUsername)
                            .font(.title3.weight(.semibold))
                        Text(viewModel.localizer.text(.accountTab))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    profileStat(
                        value: String(myRecipeTotalCount),
                        label: String(format: viewModel.localizer.text(.recipeCountFormat), myRecipeTotalCount)
                    )
                    profileStat(
                        value: String(followedAuthorsCount),
                        label: String(format: viewModel.localizer.text(.followedAuthorsCountFormat), followedAuthorsCount)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.localizer.text(.badges))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if myBadges.isEmpty {
                        Text(viewModel.localizer.text(.noBadgesYet))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(myBadges) { badge in
                                    UserBadgePill(badge: badge, localizer: viewModel.localizer)
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

    private var savedRecipesSection: some View {
        Section(header: Text(viewModel.localizer.text(.savedRecipes)).textCase(nil)) {
            if savedRecipes.isEmpty {
                EmptyStateCard(
                    symbol: "bookmark",
                    title: viewModel.localizer.text(.savedRecipes),
                    subtitle: viewModel.localizer.text(.savedRecipesEmptySubtitle)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(savedRecipes) { ranked in
                    recipeRow(ranked: ranked, managementMode: nil)
                }
            }
        }
    }

    private var activeRecipesSection: some View {
        Section(header: Text(viewModel.localizer.text(.myRecipes)).textCase(nil)) {
            if myActiveRankedRecipes.isEmpty {
                EmptyStateCard(
                    symbol: "fork.knife",
                    title: viewModel.localizer.text(.myRecipes),
                    subtitle: viewModel.localizer.text(.noResults)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(myActiveRankedRecipes) { ranked in
                    recipeRow(ranked: ranked, managementMode: .active)
                }
            }

            Button {
                showingCreateRecipeAlert = true
            } label: {
                Text(viewModel.localizer.text(.createRecipe))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var archivedRecipesSection: some View {
        Section(header: Text(viewModel.localizer.text(.archivedRecipes)).textCase(nil)) {
            if myArchivedRankedRecipes.isEmpty {
                Text(viewModel.localizer.text(.archivedRecipesEmptySubtitle))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(myArchivedRankedRecipes) { ranked in
                    recipeRow(ranked: ranked, managementMode: .archived)
                }
            }
        }
    }

    private var settingsSection: some View {
        Section(header: Text(viewModel.localizer.text(.settingsTab)).textCase(nil)) {
            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                Label(viewModel.localizer.text(.language), systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(viewModel.localizer.text(.language), selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerLabel)
                            .tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                Label(viewModel.localizer.text(.nutritionPreferences), systemImage: "heart.text.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(NutritionPriorityDimension.allCases) { dimension in
                    preferenceRow(for: dimension)
                }

                Text(viewModel.localizer.text(.nutritionPreferencesHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(viewModel.localizer.text(.nutritionComparisonBasisNote))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private enum ManagementMode {
        case active
        case archived
    }

    @ViewBuilder
    private func recipeRow(ranked: RankedRecipe, managementMode: ManagementMode?) -> some View {
        NavigationLink {
            RecipeDetailView(
                rankedRecipe: ranked,
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel,
                isFollowingAuthor: isFollowing(author: ranked.recipe.author),
                onToggleFollow: { toggleFollow(for: ranked.recipe.author) }
            )
        } label: {
            HStack(spacing: 10) {
                RecipeThumbnailView(recipe: ranked.recipe, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ranked.recipe.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    Text(String(format: viewModel.localizer.text(.crispyCountFormat), ranked.recipe.crispy))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: viewModel.localizer.text(.viewsCountFormat), viewModel.viewCount(for: ranked.recipe)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.visible)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            switch managementMode {
            case .active:
                Button {
                    viewModel.archiveRecipe(ranked.recipe)
                } label: {
                    Label(viewModel.localizer.text(.archiveRecipe), systemImage: "archivebox")
                }
                .tint(.gray)

                Button(role: .destructive) {
                    viewModel.deleteRecipe(ranked.recipe)
                } label: {
                    Label(viewModel.localizer.text(.deleteRecipe), systemImage: "trash")
                }

            case .archived:
                Button {
                    viewModel.unarchiveRecipe(ranked.recipe)
                } label: {
                    Label(viewModel.localizer.text(.restoreRecipe), systemImage: "arrow.uturn.left")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    viewModel.deleteRecipe(ranked.recipe)
                } label: {
                    Label(viewModel.localizer.text(.deleteRecipe), systemImage: "trash")
                }

            case nil:
                Button {
                    viewModel.toggleSavedRecipe(ranked.recipe)
                } label: {
                    Label(viewModel.localizer.text(.removeSavedRecipe), systemImage: "bookmark.slash")
                }
                .tint(.gray)
            }
        }
    }

    private var myActiveRecipes: [Recipe] {
        viewModel.activeRecipes(for: accountUsername)
    }

    private var myArchivedRecipes: [Recipe] {
        viewModel.archivedRecipes(for: accountUsername)
    }

    private var myActiveRankedRecipes: [RankedRecipe] {
        myActiveRecipes.compactMap { viewModel.rankedRecipe(forID: $0.id) }
    }

    private var myArchivedRankedRecipes: [RankedRecipe] {
        myArchivedRecipes.compactMap { viewModel.rankedRecipe(forID: $0.id) }
    }

    private var savedRecipes: [RankedRecipe] {
        viewModel.savedRecipesRanked()
    }

    private var myRecipeTotalCount: Int {
        myActiveRecipes.count + myArchivedRecipes.count
    }

    private var myBadges: [UserBadge] {
        viewModel.badges(for: accountUsername)
    }

    private var followedAuthorsCount: Int {
        Set(
            followedAuthorsRaw
                .split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
        ).count
    }

    @ViewBuilder
    private func profileStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func preferenceRow(for dimension: NutritionPriorityDimension) -> some View {
        let value = viewModel.nutritionPriorityValue(for: dimension)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.localizer.nutritionPriorityTitle(dimension))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { viewModel.nutritionPriorityValue(for: dimension) },
                    set: { newValue in
                        nutritionGoalsRaw = viewModel.updateNutritionPriority(newValue, for: dimension)
                    }
                ),
                in: 0...1
            )
        }
    }

    private var followedAuthorsSet: Set<String> {
        Set(
            followedAuthorsRaw
                .split(separator: "|")
                .map(String.init)
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
