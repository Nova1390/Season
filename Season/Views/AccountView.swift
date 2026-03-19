import SwiftUI

struct AccountView: View {
    @Binding var selectedLanguage: String
    @Binding var nutritionGoalsRaw: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("accountUsername") private var accountUsername = "Anna"
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @State private var showingCreateRecipeAlert = false
    @State private var showNutritionPreferences = false

    var body: some View {
        List {
            profileHeaderSection
            librarySection
            preferencesSection
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

    private var profileHeaderSection: some View {
        Section(header: Text(viewModel.localizer.text(.profile)).textCase(nil)) {
            VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 68, height: 68)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountUsername)
                            .font(.title2.weight(.semibold))
                        Text("@\(accountUsername.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                InlineStatsRow(
                    stats: [
                        String(format: viewModel.localizer.text(.recipeCountFormat), myRecipeTotalCount),
                        String(format: viewModel.localizer.text(.followedAuthorsCountFormat), followedAuthorsCount),
                        "\(savedRecipes.count) \(viewModel.localizer.text(.savedRecipes).lowercased())"
                    ]
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.localizer.text(.badges))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if myBadges.isEmpty {
                        Text(viewModel.localizer.text(.noBadgesYet))
                            .font(.footnote)
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
            .padding(.vertical, 6)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var librarySection: some View {
        Section(header: Text(viewModel.localizer.text(.myRecipes)).textCase(nil)) {
            librarySubheader(title: viewModel.localizer.text(.savedRecipes), count: savedRecipes.count)

            if savedRecipes.isEmpty {
                libraryEmptyRow(symbol: "bookmark", subtitle: viewModel.localizer.text(.savedRecipesEmptySubtitle))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(savedRecipes) { ranked in
                    recipeRow(ranked: ranked, managementMode: nil)
                }
            }

            librarySubheader(title: viewModel.localizer.text(.myRecipes), count: myActiveRankedRecipes.count)

            if myActiveRankedRecipes.isEmpty {
                libraryEmptyRow(symbol: "fork.knife", subtitle: viewModel.localizer.text(.noResults))
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

            librarySubheader(title: viewModel.localizer.text(.archivedRecipes), count: myArchivedRankedRecipes.count)

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

    private var preferencesSection: some View {
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
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                DisclosureGroup(isExpanded: $showNutritionPreferences) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(NutritionPriorityDimension.allCases) { dimension in
                            preferenceRow(for: dimension)
                        }

                        Text(viewModel.localizer.text(.nutritionComparisonBasisNote))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                } label: {
                    Label(viewModel.localizer.text(.nutritionPreferences), systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.localizer.text(.nutritionPreferencesHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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

    private func librarySubheader(title: String, count: Int) -> some View {
        SectionTitleCountRow(
            title: title,
            countText: String(format: viewModel.localizer.text(.recipeCountFormat), count)
        )
        .padding(.top, 6)
    }

    private func libraryEmptyRow(symbol: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                )

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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

}
