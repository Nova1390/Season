import SwiftUI
import os

struct AccountView: View {
    @Binding var selectedLanguage: String
    @Binding var nutritionGoalsRaw: String
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @AppStorage("accountUsername") private var accountUsername = "Anna"
    @AppStorage("followedAuthorsRaw") private var followedAuthorsRaw = ""
    @AppStorage("linkedSocialAccountsRaw") private var linkedSocialAccountsRaw = ""
    @AppStorage("accountProfileImageURL") private var accountProfileImageURL = ""
    @State private var showingCreateRecipeAlert = false
    @State private var showNutritionPreferences = false
    @State private var linkingInProgressProvider: SocialAuthProvider?
    @State private var authErrorMessage = ""
    @State private var showSupabaseAuthTest = false
    @State private var supabaseTestEmail = ""
    @State private var supabaseTestPassword = ""
    @State private var supabaseTestStatus = ""
    @State private var supabaseTestRunning = false
    @State private var supabaseProfileFetchStatus = ""
    @State private var supabaseProfileFetchRunning = false
    @State private var supabaseRecipeStatesFetchStatus = ""
    @State private var supabaseRecipeStatesFetchRunning = false
    @State private var supabaseShoppingListFetchStatus = ""
    @State private var supabaseShoppingListFetchRunning = false
    @State private var supabaseFridgeFetchStatus = ""
    @State private var supabaseFridgeFetchRunning = false
    @State private var outboxProcessingStatus = ""
    @State private var outboxProcessingRunning = false
    @State private var backfillStatus = ""
    @State private var backfillRunning = false
    @State private var reconciliationStatus = ""
    @State private var reconciliationRunning = false
    @State private var softSyncReadStatus = ""
    @State private var softSyncReadRunning = false
    @State private var cloudProfile: Profile?
    @State private var hasAttemptedCloudProfileLoad = false
    @State private var cloudLinkedAccounts: [CloudLinkedSocialAccount] = []
    @State private var hasAttemptedCloudLinkedAccountsLoad = false
    private let socialAuthService: SocialAuthServicing = SocialAuthService.live
    private let supabaseService = SupabaseService.shared
    private let backfillService = BackfillService()
    private let reconciliationDiagnosticsService = ReconciliationDiagnosticsService()
    private let authLogger = Logger(subsystem: "Season", category: "SocialAuthUI")

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
            Button(viewModel.localizer.text(.commonOK), role: .cancel) {}
        }
        .alert(viewModel.localizer.text(.authErrorTitle), isPresented: Binding(
            get: { !authErrorMessage.isEmpty },
            set: { newValue in
                if !newValue { authErrorMessage = "" }
            }
        )) {
            Button(viewModel.localizer.text(.commonOK), role: .cancel) {}
        } message: {
            Text(authErrorMessage)
        }
        .onAppear {
            migrateLegacyAccessTokensIfNeeded()
            loadCloudProfileForReadOnlyDisplayIfNeeded()
            loadCloudLinkedAccountsForReadOnlyDisplayIfNeeded()
        }
    }

    private var profileHeaderSection: some View {
        Section(header: Text(viewModel.localizer.text(.profile)).textCase(nil)) {
            VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 68, height: 68)
                        .overlay(profileAvatarContent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountDisplayName)
                            .font(.title2.weight(.semibold))
                        Text(accountHandleLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let cloudLanguageLine {
                            Text(cloudLanguageLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                Label(viewModel.localizer.text(.connectedAccounts), systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if cloudLinkedAccounts.isEmpty {
                    socialLinkRow(for: .instagram)
                    socialLinkRow(for: .tiktok)
                    socialLinkRow(for: .apple)
                } else {
                    ForEach(Array(cloudLinkedAccounts.enumerated()), id: \.offset) { _, account in
                        cloudLinkedAccountRow(account)
                    }
                }
            }
            .padding(.vertical, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                DisclosureGroup(isExpanded: $showSupabaseAuthTest) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.localizer.text(.supabaseTestDescription))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField(viewModel.localizer.text(.supabaseEmailField), text: $supabaseTestEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField(viewModel.localizer.text(.supabasePasswordField), text: $supabaseTestPassword)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            runSupabaseAuthTest()
                        } label: {
                            Text(viewModel.localizer.text(.supabaseRunTestAction))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(supabaseTestRunning || supabaseTestEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || supabaseTestPassword.isEmpty)

                        Button {
                            fetchSupabaseProfileForTesting()
                        } label: {
                            Text("Fetch profile")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(supabaseTestRunning || supabaseProfileFetchRunning || supabaseRecipeStatesFetchRunning)

                        Button {
                            fetchSupabaseRecipeStatesForTesting()
                        } label: {
                            Text("Fetch recipe states")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning ||
                            softSyncReadRunning
                        )

                        Button {
                            fetchSupabaseShoppingListItemsForTesting()
                        } label: {
                            Text("Fetch shopping list items")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning ||
                            softSyncReadRunning
                        )

                        Button {
                            fetchSupabaseFridgeItemsForTesting()
                        } label: {
                            Text("Fetch fridge items")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning ||
                            softSyncReadRunning
                        )

                        Button {
                            processOutboxForTesting()
                        } label: {
                            Text("Process outbox")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning ||
                            softSyncReadRunning
                        )

                        Button {
                            runSoftSyncReadForTesting()
                        } label: {
                            Text("Run soft sync read")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning ||
                            softSyncReadRunning
                        )

                        Button {
                            runReconciliationDiagnosticsForTesting()
                        } label: {
                            Text("Run reconciliation diagnostics")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning ||
                            reconciliationRunning
                        )

                        Button {
                            runBackfillForTesting()
                        } label: {
                            Text("Run backfill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            supabaseTestRunning ||
                            supabaseProfileFetchRunning ||
                            supabaseRecipeStatesFetchRunning ||
                            supabaseShoppingListFetchRunning ||
                            supabaseFridgeFetchRunning ||
                            outboxProcessingRunning ||
                            backfillRunning
                        )

                        if supabaseTestRunning {
                            Text(viewModel.localizer.text(.supabaseTestingInProgress))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !supabaseTestStatus.isEmpty {
                            Text(supabaseTestStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if supabaseProfileFetchRunning {
                            Text("Fetching profile...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !supabaseProfileFetchStatus.isEmpty {
                            Text(supabaseProfileFetchStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if supabaseRecipeStatesFetchRunning {
                            Text("Fetching recipe states...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !supabaseRecipeStatesFetchStatus.isEmpty {
                            Text(supabaseRecipeStatesFetchStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if supabaseShoppingListFetchRunning {
                            Text("Fetching shopping list items...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !supabaseShoppingListFetchStatus.isEmpty {
                            Text(supabaseShoppingListFetchStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if supabaseFridgeFetchRunning {
                            Text("Fetching fridge items...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !supabaseFridgeFetchStatus.isEmpty {
                            Text(supabaseFridgeFetchStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if outboxProcessingRunning {
                            Text("Processing outbox...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !outboxProcessingStatus.isEmpty {
                            Text(outboxProcessingStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if backfillRunning {
                            Text("Running backfill...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !backfillStatus.isEmpty {
                            Text(backfillStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if reconciliationRunning {
                            Text("Running reconciliation diagnostics...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !reconciliationStatus.isEmpty {
                            Text(reconciliationStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if softSyncReadRunning {
                            Text("Running soft sync read...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !softSyncReadStatus.isEmpty {
                            Text(softSyncReadStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Label(viewModel.localizer.text(.supabaseTestSectionTitle), systemImage: "checkmark.shield")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

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

    private var accountDisplayName: String {
        let cloudName = cloudProfile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cloudName.isEmpty ? accountUsername : cloudName
    }

    private var accountHandleLine: String {
        let cloudHandle = cloudProfile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cloudHandle.isEmpty {
            return cloudHandle.hasPrefix("@") ? cloudHandle : "@\(cloudHandle)"
        }
        return "@\(accountUsername.lowercased())"
    }

    private var cloudLanguageLine: String? {
        guard let language = cloudProfile?.preferred_language?.trimmingCharacters(in: .whitespacesAndNewlines),
              !language.isEmpty else {
            return nil
        }
        return "Cloud language: \(language)"
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

    @ViewBuilder
    private var profileAvatarContent: some View {
        if let url = URL(string: accountProfileImageURL.trimmingCharacters(in: .whitespacesAndNewlines)),
           !accountProfileImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(Circle())
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var linkedAccounts: [LinkedSocialAccount] {
        SocialAccountLinkStore.decode(linkedSocialAccountsRaw)
    }

    private func linkedAccount(for provider: SocialAuthProvider) -> LinkedSocialAccount? {
        linkedAccounts.first(where: { $0.provider == provider })
    }

    private func providerTitle(_ provider: SocialAuthProvider) -> String {
        switch provider {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .apple: return "Apple"
        }
    }

    private func cloudProviderTitle(_ provider: String) -> String {
        switch provider.lowercased() {
        case "instagram": return "Instagram"
        case "tiktok": return "TikTok"
        case "apple": return "Apple"
        default: return provider.capitalized
        }
    }

    private func cloudLinkedAccountDescriptor(_ account: CloudLinkedSocialAccount) -> String? {
        let handle = account.handle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !handle.isEmpty {
            return handle.hasPrefix("@") ? handle : "@\(handle)"
        }
        let display = account.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !display.isEmpty {
            return display
        }
        let providerUserID = account.provider_user_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !providerUserID.isEmpty {
            return providerUserID
        }
        return nil
    }

    private func socialLinkRow(for provider: SocialAuthProvider) -> some View {
        let linked = linkedAccount(for: provider)
        return HStack(spacing: 10) {
            Text(providerTitle(provider))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let linked {
                Text(linked.handle ?? linked.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button(viewModel.localizer.text(.unlinkAction), role: .destructive) {
                    removeLinkedAccount(provider: provider)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
            } else {
                Button(viewModel.localizer.text(.connectAction)) {
                    link(provider: provider)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
            }
        }
    }

    private func cloudLinkedAccountRow(_ account: CloudLinkedSocialAccount) -> some View {
        HStack(spacing: 10) {
            Text(cloudProviderTitle(account.provider))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let descriptor = cloudLinkedAccountDescriptor(account) {
                Text(descriptor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func upsertLinkedAccount(_ account: LinkedSocialAccount) {
        var sanitizedAccount = account
        if let token = sanitizedAccount.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            _ = SocialAccessTokenStore.saveToken(
                token,
                provider: sanitizedAccount.provider,
                providerUserID: sanitizedAccount.providerUserID
            )
        }
        sanitizedAccount.accessToken = nil

        var accounts = linkedAccounts
        if let index = accounts.firstIndex(where: { $0.provider == sanitizedAccount.provider }) {
            let previous = accounts[index]
            if previous.providerUserID != sanitizedAccount.providerUserID {
                _ = SocialAccessTokenStore.deleteToken(
                    provider: previous.provider,
                    providerUserID: previous.providerUserID
                )
            }
            accounts[index] = sanitizedAccount
        } else {
            accounts.append(sanitizedAccount)
        }
        linkedSocialAccountsRaw = SocialAccountLinkStore.encode(accounts)

        if let profileURL = sanitizedAccount.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !profileURL.isEmpty {
            accountProfileImageURL = profileURL
        }

        let name = sanitizedAccount.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            accountUsername = name
        }
    }

    private func removeLinkedAccount(provider: SocialAuthProvider) {
        if let existing = linkedAccount(for: provider) {
            _ = SocialAccessTokenStore.deleteToken(
                provider: existing.provider,
                providerUserID: existing.providerUserID
            )
        }
        let updated = linkedAccounts.filter { $0.provider != provider }
        linkedSocialAccountsRaw = SocialAccountLinkStore.encode(updated)
    }

    private func migrateLegacyAccessTokensIfNeeded() {
        let accounts = linkedAccounts
        guard !accounts.isEmpty else { return }

        var migrated = false
        var sanitizedAccounts = accounts

        for index in sanitizedAccounts.indices {
            let token = sanitizedAccounts[index].accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !token.isEmpty {
                _ = SocialAccessTokenStore.saveToken(
                    token,
                    provider: sanitizedAccounts[index].provider,
                    providerUserID: sanitizedAccounts[index].providerUserID
                )
                sanitizedAccounts[index].accessToken = nil
                migrated = true
            }
        }

        if migrated {
            linkedSocialAccountsRaw = SocialAccountLinkStore.encode(sanitizedAccounts)
            authLogger.debug("Migrated legacy social access tokens from AppStorage JSON to Keychain.")
        }
    }

    private func link(provider: SocialAuthProvider) {
        guard linkingInProgressProvider == nil else { return }
        authErrorMessage = ""
        linkingInProgressProvider = provider
        let attemptID = UUID().uuidString
        authLogger.debug("[\(attemptID, privacy: .public)] UI tap provider=\(provider.rawValue, privacy: .public)")

        Task {
            defer { linkingInProgressProvider = nil }
            do {
                authLogger.debug("[\(attemptID, privacy: .public)] Calling auth service for provider=\(provider.rawValue, privacy: .public)")
                let result = try await socialAuthService.authenticate(with: provider)
                authLogger.debug("[\(attemptID, privacy: .public)] Auth success provider=\(result.provider.rawValue, privacy: .public) userID=\(result.providerUserID, privacy: .public)")
                let account = LinkedSocialAccount(
                    provider: provider,
                    providerUserID: result.providerUserID,
                    displayName: result.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (result.displayName ?? "")
                        : accountUsername,
                    handle: result.handle,
                    profileImageURL: result.profileImageURL,
                    accessToken: result.accessToken,
                    isVerified: true,
                    eligiblePostURLs: linkedAccount(for: provider)?.eligiblePostURLs ?? [],
                    linkedAt: Date()
                )
                upsertLinkedAccount(account)
            } catch {
                let scopedMessage = providerScopedAuthErrorMessage(error, provider: provider)
                authLogger.error("[\(attemptID, privacy: .public)] Auth failure provider=\(provider.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
                authLogger.error("[\(attemptID, privacy: .public)] Assigning authErrorMessage='\(scopedMessage, privacy: .public)'")
                authErrorMessage = scopedMessage
            }
        }
    }

    private func providerScopedAuthErrorMessage(_ error: Error, provider: SocialAuthProvider) -> String {
        if let socialError = error as? SocialAuthError {
            switch socialError {
            case .oauthNotConfigured:
                switch provider {
                case .instagram: return viewModel.localizer.text(.authOAuthNotConfiguredInstagram)
                case .tiktok: return viewModel.localizer.text(.authOAuthNotConfiguredTikTok)
                case .apple: return viewModel.localizer.text(.authOAuthNotConfiguredApple)
                }
            case .missingPresentationAnchor:
                return viewModel.localizer.text(.authMissingApplePresentationAnchor)
            case .cancelled:
                return viewModel.localizer.text(.authCancelled)
            case .unknown:
                switch provider {
                case .instagram: return viewModel.localizer.text(.authFailedInstagram)
                case .tiktok: return viewModel.localizer.text(.authFailedTikTok)
                case .apple: return viewModel.localizer.text(.authFailedApple)
                }
            case .appleAuthorizationFailed(let details):
                return details
            }
        }

        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }

        switch provider {
        case .instagram: return viewModel.localizer.text(.authFailedInstagram)
        case .tiktok: return viewModel.localizer.text(.authFailedTikTok)
        case .apple: return viewModel.localizer.text(.authFailedApple)
        }
    }

    private func runSupabaseAuthTest() {
        let email = supabaseTestEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = supabaseTestPassword

        guard supabaseService.configuration != nil else {
            let issue = supabaseService.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY"
            supabaseTestStatus = String(format: viewModel.localizer.text(.supabaseNotConfiguredFormat), issue)
            return
        }

        guard !email.isEmpty, !password.isEmpty else { return }

        supabaseTestRunning = true
        supabaseTestStatus = ""

        Task {
            defer { supabaseTestRunning = false }
            do {
                let userID = try await supabaseService.authenticateWithEmailPasswordForTesting(
                    email: email,
                    password: password
                )
                let profileExists = try await supabaseService.validateProfilePipeline(for: userID)
                if profileExists {
                    supabaseTestStatus = String(
                        format: viewModel.localizer.text(.supabaseValidationSuccessFormat),
                        email,
                        userID.uuidString
                    )
                } else {
                    supabaseTestStatus = String(
                        format: viewModel.localizer.text(.supabaseValidationMissingProfileFormat),
                        email,
                        userID.uuidString
                    )
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseTestStatus = String(
                    format: viewModel.localizer.text(.supabaseValidationFailedFormat),
                    details
                )
            }
        }
    }

    private func loadCloudProfileForReadOnlyDisplayIfNeeded() {
        guard !hasAttemptedCloudProfileLoad else { return }
        hasAttemptedCloudProfileLoad = true

        Task {
            do {
                cloudProfile = try await supabaseService.fetchMyProfile()
            } catch {
                cloudProfile = nil
            }
        }
    }

    private func loadCloudLinkedAccountsForReadOnlyDisplayIfNeeded() {
        guard !hasAttemptedCloudLinkedAccountsLoad else { return }
        hasAttemptedCloudLinkedAccountsLoad = true

        Task {
            do {
                cloudLinkedAccounts = try await supabaseService.fetchMyLinkedSocialAccounts()
            } catch {
                cloudLinkedAccounts = []
            }
        }
    }

    private func fetchSupabaseProfileForTesting() {
        guard supabaseService.configuration != nil else {
            let issue = supabaseService.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY"
            supabaseProfileFetchStatus = String(format: viewModel.localizer.text(.supabaseNotConfiguredFormat), issue)
            return
        }

        supabaseProfileFetchRunning = true
        supabaseProfileFetchStatus = ""

        Task {
            defer { supabaseProfileFetchRunning = false }
            do {
                guard let profile = try await supabaseService.fetchMyProfile() else {
                    cloudProfile = nil
                    supabaseProfileFetchStatus = "No authenticated user"
                    return
                }
                cloudProfile = profile
                supabaseProfileFetchStatus = "Profile loaded: \(profile.id.uuidString)"
            } catch {
                cloudProfile = nil
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseProfileFetchStatus = "Profile fetch failed: \(details)"
            }
        }
    }

    private func fetchSupabaseRecipeStatesForTesting() {
        guard supabaseService.configuration != nil else {
            let issue = supabaseService.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY"
            supabaseRecipeStatesFetchStatus = String(format: viewModel.localizer.text(.supabaseNotConfiguredFormat), issue)
            return
        }

        supabaseRecipeStatesFetchRunning = true
        supabaseRecipeStatesFetchStatus = ""

        Task {
            defer { supabaseRecipeStatesFetchRunning = false }
            do {
                let states = try await supabaseService.fetchMyUserRecipeStates()
                if let firstRecipeID = states.first?.recipe_id, !firstRecipeID.isEmpty {
                    supabaseRecipeStatesFetchStatus = "Recipe states loaded: \(states.count). First recipe_id: \(firstRecipeID)"
                } else {
                    supabaseRecipeStatesFetchStatus = "Recipe states loaded: \(states.count)"
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseRecipeStatesFetchStatus = "Recipe states fetch failed: \(details)"
            }
        }
    }

    private func fetchSupabaseShoppingListItemsForTesting() {
        guard supabaseService.configuration != nil else {
            let issue = supabaseService.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY"
            supabaseShoppingListFetchStatus = String(format: viewModel.localizer.text(.supabaseNotConfiguredFormat), issue)
            return
        }

        supabaseShoppingListFetchRunning = true
        supabaseShoppingListFetchStatus = ""

        Task {
            defer { supabaseShoppingListFetchRunning = false }
            do {
                let items = try await supabaseService.fetchMyShoppingListItems()
                if let firstID = items.first?.id, !firstID.isEmpty {
                    supabaseShoppingListFetchStatus = "Shopping list items loaded: \(items.count). First id: \(firstID)"
                } else {
                    supabaseShoppingListFetchStatus = "Shopping list items loaded: \(items.count)"
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseShoppingListFetchStatus = "Shopping list items fetch failed: \(details)"
            }
        }
    }

    private func fetchSupabaseFridgeItemsForTesting() {
        guard supabaseService.configuration != nil else {
            let issue = supabaseService.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY"
            supabaseFridgeFetchStatus = String(format: viewModel.localizer.text(.supabaseNotConfiguredFormat), issue)
            return
        }

        supabaseFridgeFetchRunning = true
        supabaseFridgeFetchStatus = ""

        Task {
            defer { supabaseFridgeFetchRunning = false }
            do {
                let items = try await supabaseService.fetchMyFridgeItems()
                if let firstID = items.first?.id, !firstID.isEmpty {
                    supabaseFridgeFetchStatus = "Fridge items loaded: \(items.count). First id: \(firstID)"
                } else {
                    supabaseFridgeFetchStatus = "Fridge items loaded: \(items.count)"
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseFridgeFetchStatus = "Fridge items fetch failed: \(details)"
            }
        }
    }

    private func processOutboxForTesting() {
        outboxProcessingRunning = true
        outboxProcessingStatus = ""

        Task {
            let dispatcher = OutboxDispatcher()
            await dispatcher.processPendingMutations()
            outboxProcessingStatus = "Outbox processing completed"
            outboxProcessingRunning = false
        }
    }

    private func runBackfillForTesting() {
        backfillRunning = true
        backfillStatus = ""

        Task {
            do {
                let result = try await backfillService.runManualBackfill()
                backfillStatus = "Backfill completed. Shopping inserted: \(result.shoppingInserted). Fridge inserted: \(result.fridgeInserted)"
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                backfillStatus = "Backfill failed: \(details)"
            }
            backfillRunning = false
        }
    }

    private func runReconciliationDiagnosticsForTesting() {
        reconciliationRunning = true
        reconciliationStatus = ""

        Task {
            do {
                let result = try await reconciliationDiagnosticsService.runDiagnostics()
                let shopping = "Shopping — local_only: \(result.shopping.localOnly), backend_only: \(result.shopping.backendOnly), shared_same: \(result.shopping.sharedSame), shared_different: \(result.shopping.sharedDifferent)"
                let fridge = "Fridge — local_only: \(result.fridge.localOnly), backend_only: \(result.fridge.backendOnly), shared_same: \(result.fridge.sharedSame), shared_different: \(result.fridge.sharedDifferent)"
                reconciliationStatus = "\(shopping)\n\(fridge)"
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                reconciliationStatus = "Reconciliation diagnostics failed: \(details)"
            }
            reconciliationRunning = false
        }
    }

    private func runSoftSyncReadForTesting() {
        softSyncReadRunning = true
        softSyncReadStatus = ""

        Task {
            do {
                let result = try await reconciliationDiagnosticsService.runSoftSyncReadDiagnostics()
                let shopping = "Soft sync — Shopping: local_only \(result.shopping.localOnly), backend_only \(result.shopping.backendOnly), shared_same \(result.shopping.sharedSame), shared_different \(result.shopping.sharedDifferent)"
                let fridge = "Soft sync — Fridge: local_only \(result.fridge.localOnly), backend_only \(result.fridge.backendOnly), shared_same \(result.fridge.sharedSame), shared_different \(result.fridge.sharedDifferent)"
                softSyncReadStatus = "\(shopping)\n\(fridge)"
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                softSyncReadStatus = "Soft sync read failed: \(details)"
            }
            softSyncReadRunning = false
        }
    }
}
