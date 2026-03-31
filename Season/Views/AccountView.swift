import SwiftUI
import os
import PhotosUI
import UIKit

struct AccountView: View {
    private struct DraftEditorRoute: Identifiable {
        let id: String
    }
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
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var authUsernameInput = ""
    @State private var authModeIsSignUp = false
    @State private var authActionRunning = false
    @State private var authStatusMessage = ""
    @State private var authStatusIsError = false
    @State private var socialLinkStatusMessage = ""
    @State private var socialLinkStatusIsError = false
    @State private var selectedDraftEditorRoute: DraftEditorRoute?
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
    @State private var instagramProfileURLInput = ""
    @State private var tiktokProfileURLInput = ""
    @State private var socialProfilesSaveStatus = ""
    @State private var socialProfilesSaveIsError = false
    @State private var socialProfilesSaveRunning = false
    @State private var pendingDraftDeleteRecipe: Recipe?
    @State private var showingDraftDeleteConfirmation = false
    @State private var selectedAvatarPhotoItem: PhotosPickerItem?
    @State private var avatarUploadRunning = false
    @State private var showingLogoutConfirmation = false
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel
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
        .alert("Delete this draft?", isPresented: $showingDraftDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDraftDeleteRecipe = nil
            }
            Button("Delete", role: .destructive) {
                if let recipe = pendingDraftDeleteRecipe {
                    viewModel.deleteRecipe(recipe)
                }
                pendingDraftDeleteRecipe = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Log out?", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) {
                logout()
            }
        } message: {
            Text("You will need to sign in again to access Season.")
        }
        .onAppear {
            migrateLegacyAccessTokensIfNeeded()
            loadCloudProfileForReadOnlyDisplayIfNeeded()
            loadCloudLinkedAccountsForReadOnlyDisplayIfNeeded()
            applyCloudProfileSocialLinksToInputs(cloudProfile)
        }
        .onChange(of: selectedAvatarPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadSelectedAvatar(from: newItem)
            }
        }
        .fullScreenCover(item: $selectedDraftEditorRoute) { route in
            CreateRecipeView(
                viewModel: viewModel,
                initialDraftRecipeID: route.id,
                enableDraftMode: true
            )
        }
    }

    private var profileHeaderSection: some View {
        Section(header: Text(viewModel.localizer.text(.profile)).textCase(nil)) {
            VStack(alignment: .leading, spacing: SeasonSpacing.md) {
                HStack(alignment: .top, spacing: 12) {
                    PhotosPicker(
                        selection: $selectedAvatarPhotoItem,
                        matching: .images
                    ) {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 68, height: 68)
                            .overlay(profileAvatarContent)
                            .overlay {
                                if avatarUploadRunning {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.secondary)
                                }
                            }
                    }
                    .buttonStyle(.plain)

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

                        if !creatorSocialProfileLinks.isEmpty {
                            HStack(spacing: 10) {
                                ForEach(creatorSocialProfileLinks, id: \.platform) { link in
                                    Button {
                                        guard let url = URL(string: link.url) else { return }
                                        openURL(url)
                                    } label: {
                                        creatorSocialIcon(for: link.platform)
                                            .frame(width: 20, height: 20)
                                            .frame(minWidth: 32, minHeight: 32)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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

                NavigationLink {
                    AuthorProfileView(
                        authorName: publicProfileAuthorName,
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel,
                        profileSocialLinks: publicProfileSocialLinks,
                        profileAvatarURL: cloudProfile?.avatar_url
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.square")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.localizer.text(.previewPublicProfile))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)

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

            librarySubheader(title: viewModel.localizer.text(.draftRecipes), count: myDraftRecipes.count)

            if myDraftRecipes.isEmpty {
                libraryEmptyRow(symbol: "doc.text", subtitle: viewModel.localizer.text(.draftRecipesEmptySubtitle))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(myDraftRecipes) { draftRecipe in
                    recipeRow(recipe: draftRecipe, ranked: nil, managementMode: .draft)
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
                Label("Authentication", systemImage: "person.badge.key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let authenticatedUserID = currentAuthenticatedUserID {
                    Text("Signed in • \(authenticatedUserID)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    let visibleUsername = cloudProfile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? accountUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !visibleUsername.isEmpty {
                        Text("Username: @\(visibleUsername)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    if let email = currentAuthenticatedEmail, !email.isEmpty {
                        Text("Email: \(email)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if let requiredUsername = requiredUsernamePrompt {
                        Text(requiredUsername)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if shouldRequireUsernameOnboarding {
                        TextField("Choose username", text: $authUsernameInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        Button {
                            saveUsername()
                        } label: {
                            Text("Save username")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(authActionRunning || authUsernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Log out")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(authActionRunning)
                } else {
                    Button {
                        link(provider: .apple)
                    } label: {
                        Label("Sign in with Apple", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(linkingInProgressProvider != nil)

                    if linkingInProgressProvider == .apple {
                        Text("Signing in…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Email", text: $authEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $authPassword)
                        .textFieldStyle(.roundedBorder)

                    if authModeIsSignUp {
                        TextField("Username", text: $authUsernameInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        submitEmailAuth()
                    } label: {
                        Text(authModeIsSignUp ? "Sign up" : "Sign in")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authActionRunning || authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authPassword.isEmpty || (authModeIsSignUp && authUsernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                    Button {
                        authModeIsSignUp.toggle()
                    } label: {
                        Text(authModeIsSignUp ? "Have an account? Sign in" : "Need an account? Sign up")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(authActionRunning)
                }

                if authActionRunning {
                    Text("Processing authentication…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !authStatusMessage.isEmpty {
                    Text(authStatusMessage)
                        .font(.caption)
                        .foregroundStyle(authStatusIsError ? .red : .secondary)
                }
            }
            .padding(.vertical, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: SeasonSpacing.xs) {
                Label(viewModel.localizer.accountSocialProfilesTitle, systemImage: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(viewModel.localizer.accountSocialProfilesInstagramUsername, text: $instagramProfileURLInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField(viewModel.localizer.accountSocialProfilesTikTokUsername, text: $tiktokProfileURLInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button {
                    saveProfileSocialLinks()
                } label: {
                    Text(viewModel.localizer.accountSocialProfilesSaveAction)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(socialProfilesSaveRunning)

                if socialProfilesSaveRunning {
                    Text(viewModel.localizer.commonSaving)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !socialProfilesSaveStatus.isEmpty {
                    Text(socialProfilesSaveStatus)
                        .font(.caption)
                        .foregroundStyle(socialProfilesSaveIsError ? .red : .secondary)
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
        case draft
    }

    @ViewBuilder
    private func recipeRow(ranked: RankedRecipe, managementMode: ManagementMode?) -> some View {
        recipeRow(recipe: ranked.recipe, ranked: ranked, managementMode: managementMode)
    }

    @ViewBuilder
    private func recipeRow(recipe: Recipe, ranked: RankedRecipe?, managementMode: ManagementMode?) -> some View {
        Group {
            if managementMode == .draft {
                Button {
                    print("[SEASON_RECIPE] phase=draft_reopened id=\(recipe.id)")
                    selectedDraftEditorRoute = DraftEditorRoute(id: recipe.id)
                } label: {
                    recipeRowContent(recipe: recipe)
                }
            } else if let ranked {
                NavigationLink {
                    RecipeDetailView(
                        rankedRecipe: ranked,
                        viewModel: viewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    recipeRowContent(recipe: recipe)
                }
            } else {
                recipeRowContent(recipe: recipe)
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.visible)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            switch managementMode {
            case .active:
                Button {
                    viewModel.archiveRecipe(recipe)
                } label: {
                    Label(viewModel.localizer.text(.archiveRecipe), systemImage: "archivebox")
                }
                .tint(.gray)

                Button(role: .destructive) {
                    viewModel.deleteRecipe(recipe)
                } label: {
                    Label(viewModel.localizer.text(.deleteRecipe), systemImage: "trash")
                }

            case .archived:
                Button {
                    viewModel.unarchiveRecipe(recipe)
                } label: {
                    Label(viewModel.localizer.text(.restoreRecipe), systemImage: "arrow.uturn.left")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    viewModel.deleteRecipe(recipe)
                } label: {
                    Label(viewModel.localizer.text(.deleteRecipe), systemImage: "trash")
                }

            case .draft:
                Button(role: .destructive) {
                    pendingDraftDeleteRecipe = recipe
                    showingDraftDeleteConfirmation = true
                } label: {
                    Label(viewModel.localizer.text(.deleteRecipe), systemImage: "trash")
                }

            case nil:
                Button {
                    viewModel.toggleSavedRecipe(recipe)
                } label: {
                    Label(viewModel.localizer.text(.removeSavedRecipe), systemImage: "bookmark.slash")
                }
                .tint(.gray)
            }
        }
    }

    private func recipeRowContent(recipe: Recipe) -> some View {
        HStack(spacing: 10) {
            RecipeThumbnailView(recipe: recipe, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                let trimmedTitle = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmedTitle.isEmpty ? viewModel.localizer.text(.untitledDraft) : trimmedTitle)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(String(format: viewModel.localizer.text(.crispyCountFormat), recipe.crispy))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: viewModel.localizer.text(.viewsCountFormat), viewModel.viewCount(for: recipe)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var myActiveRecipes: [Recipe] {
        viewModel.activeRecipes(for: accountUsername)
    }

    private var myArchivedRecipes: [Recipe] {
        viewModel.archivedRecipes(for: accountUsername)
    }

    private var myDraftRecipes: [Recipe] {
        viewModel.draftRecipes(for: accountUsername)
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
        myActiveRecipes.count + myArchivedRecipes.count + myDraftRecipes.count
    }

    private var myBadges: [UserBadge] {
        viewModel.badges(for: accountUsername)
    }

    private var publicProfileAuthorName: String {
        let cloudName = accountDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cloudName.isEmpty, !viewModel.rankedRecipesByAuthor(cloudName).isEmpty {
            return cloudName
        }
        return accountUsername
    }

    private var publicProfileSocialLinks: [AuthorProfileView.CreatorSocialLink] {
        creatorSocialProfileLinks.map { link in
            AuthorProfileView.CreatorSocialLink(platform: link.platform, url: link.url)
        }
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
        return String(format: viewModel.localizer.accountCloudLanguageFormat, language)
    }

    private var creatorSocialProfileLinks: [(platform: RecipeExternalPlatform, url: String)] {
        var links: [(RecipeExternalPlatform, String)] = []
        if let instagram = cloudProfile?.instagram_url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instagram.isEmpty {
            links.append((.instagram, instagram))
        }
        if let tiktok = cloudProfile?.tiktok_url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !tiktok.isEmpty {
            links.append((.tiktok, tiktok))
        }
        return links
    }

    @ViewBuilder
    private func creatorSocialIcon(for platform: RecipeExternalPlatform) -> some View {
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
        AvatarView(
            avatarURL: accountProfileImageURL,
            size: 68,
            creatorID: cloudProfile?.id.uuidString,
            displayName: accountDisplayName
        )
    }

    private var linkedAccounts: [LinkedSocialAccount] {
        SocialAccountLinkStore.decode(linkedSocialAccountsRaw)
    }

    private var currentAuthenticatedUserID: String? {
        let id = supabaseService.currentAuthenticatedUserID()?.uuidString.lowercased() ?? ""
        return id.isEmpty ? nil : id
    }

    private var currentAuthenticatedEmail: String? {
        supabaseService.currentAuthenticatedEmail()
    }

    private var shouldRequireUsernameOnboarding: Bool {
        guard currentAuthenticatedUserID != nil else { return false }
        let username = cloudProfile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return username.isEmpty
    }

    private var requiredUsernamePrompt: String? {
        guard shouldRequireUsernameOnboarding else { return nil }
        return "Choose a username to complete account setup."
    }

    private func validateUsernameForAuth(_ raw: String) -> String? {
        let username = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if username.count < 3 {
            return "Username must be at least 3 characters."
        }
        if username.count > 24 {
            return "Username must be at most 24 characters."
        }
        let pattern = "^[a-zA-Z0-9_]+$"
        let valid = username.range(of: pattern, options: .regularExpression) != nil
        if !valid {
            return "Use only letters, numbers, and underscore."
        }
        return nil
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

    private func cloudLinkedAccount(for provider: SocialAuthProvider) -> CloudLinkedSocialAccount? {
        cloudLinkedAccounts.first { $0.provider.caseInsensitiveCompare(provider.rawValue) == .orderedSame }
    }

    private var hasAnyConnectedSocialAccount: Bool {
        SocialAuthProvider.allCases.contains { provider in
            cloudLinkedAccount(for: provider) != nil || linkedAccount(for: provider) != nil
        }
    }

    private func providerDescriptor(for provider: SocialAuthProvider) -> String? {
        if let cloud = cloudLinkedAccount(for: provider),
           let descriptor = cloudLinkedAccountDescriptor(cloud) {
            return descriptor
        }
        if let local = linkedAccount(for: provider) {
            let handle = local.handle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !handle.isEmpty {
                return handle.hasPrefix("@") ? handle : "@\(handle)"
            }
            let displayName = local.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return displayName.isEmpty ? nil : displayName
        }
        return nil
    }

    private func socialLinkRow(for provider: SocialAuthProvider) -> some View {
        let descriptor = providerDescriptor(for: provider)
        let isConnected = descriptor != nil
        let isLoading = linkingInProgressProvider == provider

        return HStack(spacing: 10) {
            Text(providerTitle(provider))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let descriptor {
                Text(descriptor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if isConnected {
                Button(viewModel.localizer.text(.unlinkAction), role: .destructive) {
                    unlink(provider: provider)
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

    private func unlink(provider: SocialAuthProvider) {
        guard linkingInProgressProvider == nil else { return }
        socialLinkStatusMessage = ""
        socialLinkStatusIsError = false
        linkingInProgressProvider = provider

        Task {
            defer { linkingInProgressProvider = nil }

            removeLinkedAccount(provider: provider)
            let hadCloudAccount = cloudLinkedAccount(for: provider) != nil

            if hadCloudAccount {
                do {
                    try await supabaseService.deleteMyLinkedSocialAccount(provider: provider.rawValue)
                    cloudLinkedAccounts.removeAll { $0.provider.caseInsensitiveCompare(provider.rawValue) == .orderedSame }
                    socialLinkStatusMessage = "\(providerTitle(provider)) disconnected."
                    socialLinkStatusIsError = false
                } catch {
                    socialLinkStatusMessage = "Failed to disconnect \(providerTitle(provider))."
                    socialLinkStatusIsError = true
                }
            } else {
                socialLinkStatusMessage = "\(providerTitle(provider)) disconnected."
                socialLinkStatusIsError = false
            }
        }
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

    private func submitEmailAuth() {
        guard !authActionRunning else { return }

        let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = authPassword
        let username = authUsernameInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, !password.isEmpty else { return }
        if authModeIsSignUp {
            if let validationError = validateUsernameForAuth(username) {
                authStatusMessage = validationError
                authStatusIsError = true
                return
            }
        }

        authActionRunning = true
        authStatusMessage = ""
        authStatusIsError = false

        Task {
            defer { authActionRunning = false }
            do {
                let userID: UUID
                if authModeIsSignUp {
                    userID = try await supabaseService.signUpWithEmail(email: email, password: password)
                    print("[SEASON_AUTH] phase=email_sign_up_success user_id=\(userID.uuidString.lowercased())")
                    let available = try await supabaseService.isUsernameAvailable(username, excludingUserID: userID)
                    guard available else {
                        throw NSError(domain: "SeasonAuth", code: 409, userInfo: [NSLocalizedDescriptionKey: "That username is already taken."])
                    }
                    try await supabaseService.upsertMyProfileIdentity(username: username, displayName: username)
                    print("[SEASON_AUTH] phase=username_saved_success user_id=\(userID.uuidString.lowercased()) username=\(username)")
                } else {
                    userID = try await supabaseService.signInWithEmail(email: email, password: password)
                    print("[SEASON_AUTH] phase=email_sign_in_success user_id=\(userID.uuidString.lowercased())")
                }

                let refreshedProfile = try await supabaseService.fetchMyProfile()
                await MainActor.run {
                    cloudProfile = refreshedProfile
                    applyCloudProfileSocialLinksToInputs(refreshedProfile)
                    let hasUsername = !(refreshedProfile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    print("[SEASON_AUTH] phase=username_check user_id=\(userID.uuidString.lowercased()) exists=\(hasUsername)")
                    authStatusMessage = authModeIsSignUp ? "Account created." : "Signed in."
                    authStatusIsError = false
                    if !hasUsername {
                        authStatusMessage = "Signed in. Choose a username to continue."
                    }
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if authModeIsSignUp {
                    print("[SEASON_AUTH] phase=email_sign_up_failed error=\(details)")
                } else {
                    print("[SEASON_AUTH] phase=email_sign_in_failed error=\(details)")
                }
                await MainActor.run {
                    authStatusMessage = details
                    authStatusIsError = true
                }
            }
        }
    }

    private func saveUsername() {
        guard !authActionRunning else { return }
        let username = authUsernameInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !username.isEmpty else { return }
        if let validationError = validateUsernameForAuth(username) {
            authStatusMessage = validationError
            authStatusIsError = true
            return
        }

        authActionRunning = true
        authStatusMessage = ""
        authStatusIsError = false

        Task {
            defer { authActionRunning = false }
            do {
                let currentUserID = supabaseService.currentAuthenticatedUserID()
                let available = try await supabaseService.isUsernameAvailable(username, excludingUserID: currentUserID)
                guard available else {
                    throw NSError(domain: "SeasonAuth", code: 409, userInfo: [NSLocalizedDescriptionKey: "That username is already taken."])
                }
                try await supabaseService.upsertMyProfileIdentity(username: username, displayName: username)
                print("[SEASON_AUTH] phase=username_saved_success user_id=\(currentAuthenticatedUserID ?? "nil") username=\(username)")
                let refreshedProfile = try await supabaseService.fetchMyProfile()
                await MainActor.run {
                    cloudProfile = refreshedProfile
                    applyCloudProfileSocialLinksToInputs(refreshedProfile)
                    authStatusMessage = "Username saved."
                    authStatusIsError = false
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                print("[SEASON_AUTH] phase=username_saved_failed error=\(details)")
                await MainActor.run {
                    authStatusMessage = details
                    authStatusIsError = true
                }
            }
        }
    }

    private func logout() {
        guard !authActionRunning else { return }
        print("[SEASON_AUTH] phase=logout_started")
        authActionRunning = true
        authStatusMessage = ""
        authStatusIsError = false

        Task {
            defer { authActionRunning = false }
            do {
                try await supabaseService.signOut()
                print("[SEASON_AUTH] phase=supabase_logout_succeeded")
                await MainActor.run {
                    viewModel.resetForLogout()
                    shoppingListViewModel.resetForLogout()
                    fridgeViewModel.resetForLogout()
                    accountUsername = "You"
                    followedAuthorsRaw = ""
                    linkedSocialAccountsRaw = ""
                    accountProfileImageURL = ""
                    authEmail = ""
                    authPassword = ""
                    authUsernameInput = ""
                    authModeIsSignUp = false
                    cloudProfile = nil
                    cloudLinkedAccounts = []
                    hasAttemptedCloudProfileLoad = false
                    hasAttemptedCloudLinkedAccountsLoad = false
                    socialLinkStatusMessage = ""
                    socialLinkStatusIsError = false
                    print("[SEASON_AUTH] phase=local_state_cleared")
                    authStatusMessage = "Logged out."
                    authStatusIsError = false
                    print("[SEASON_AUTH] phase=ui_reset_completed")
                }
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                print("[SEASON_AUTH] phase=logout_failed error=\(details)")
                await MainActor.run {
                    authStatusMessage = details
                    authStatusIsError = true
                }
            }
        }
    }

    private func link(provider: SocialAuthProvider) {
        guard linkingInProgressProvider == nil else { return }
        authErrorMessage = ""
        socialLinkStatusMessage = ""
        socialLinkStatusIsError = false
        linkingInProgressProvider = provider
        let attemptID = UUID().uuidString
        print("[SEASON_AUTH] phase=oauth_started provider=\(provider.rawValue)")
        authLogger.debug("[\(attemptID, privacy: .public)] UI tap provider=\(provider.rawValue, privacy: .public)")

        Task {
            defer { linkingInProgressProvider = nil }
            do {
                authLogger.debug("[\(attemptID, privacy: .public)] Calling auth service for provider=\(provider.rawValue, privacy: .public)")
                let result = try await socialAuthService.authenticate(with: provider)
                authLogger.debug("[\(attemptID, privacy: .public)] Auth success provider=\(result.provider.rawValue, privacy: .public) userID=\(result.providerUserID, privacy: .public)")
                let currentAuthUserID = SupabaseService.shared.currentAuthenticatedUserID()?.uuidString.lowercased() ?? "nil"
                print("[SEASON_AUTH] phase=auth_flow_completed provider=\(provider.rawValue) has_session=\(currentAuthUserID != "nil") current_user_id=\(currentAuthUserID)")
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
                let refreshedProfile = try await supabaseService.fetchMyProfile()
                cloudProfile = refreshedProfile
                applyCloudProfileSocialLinksToInputs(refreshedProfile)
                let hasUsername = !(refreshedProfile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                print("[SEASON_AUTH] phase=username_check provider=\(provider.rawValue) exists=\(hasUsername)")
                if !hasUsername {
                    let fallback = accountUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !fallback.isEmpty {
                        authUsernameInput = fallback
                    }
                    authStatusMessage = "Choose a username to complete account setup."
                    authStatusIsError = false
                }
                print("[SEASON_AUTH] phase=oauth_succeeded provider=\(provider.rawValue)")
                socialLinkStatusMessage = "\(providerTitle(provider)) connected."
                socialLinkStatusIsError = false
            } catch {
                let scopedMessage = providerScopedAuthErrorMessage(error, provider: provider)
                authLogger.error("[\(attemptID, privacy: .public)] Auth failure provider=\(provider.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
                authLogger.error("[\(attemptID, privacy: .public)] Assigning authErrorMessage='\(scopedMessage, privacy: .public)'")
                authErrorMessage = scopedMessage
                print("[SEASON_AUTH] phase=oauth_failed provider=\(provider.rawValue) error=\(error)")
                socialLinkStatusMessage = scopedMessage
                socialLinkStatusIsError = true
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
            case .oauthFlowFailed(_, let details):
                return details
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
                let profile = try await supabaseService.fetchMyProfile()
                cloudProfile = profile
                applyCloudProfileSocialLinksToInputs(profile)
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
                    applyCloudProfileSocialLinksToInputs(nil)
                    supabaseProfileFetchStatus = "No authenticated user"
                    return
                }
                cloudProfile = profile
                applyCloudProfileSocialLinksToInputs(profile)
                supabaseProfileFetchStatus = "Profile loaded: \(profile.id.uuidString)"
            } catch {
                cloudProfile = nil
                applyCloudProfileSocialLinksToInputs(nil)
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                supabaseProfileFetchStatus = "Profile fetch failed: \(details)"
            }
        }
    }

    private func applyCloudProfileSocialLinksToInputs(_ profile: Profile?) {
        let avatarURL = profile?.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        accountProfileImageURL = avatarURL
        instagramProfileURLInput = extractedUsername(
            from: profile?.instagram_url,
            platform: .instagram
        ) ?? ""
        tiktokProfileURLInput = extractedUsername(
            from: profile?.tiktok_url,
            platform: .tiktok
        ) ?? ""
    }

    private func saveProfileSocialLinks() {
        socialProfilesSaveRunning = true
        socialProfilesSaveStatus = ""
        socialProfilesSaveIsError = false

        let instagram = normalizedSocialProfileURL(
            from: instagramProfileURLInput,
            platform: .instagram
        )
        let tiktok = normalizedSocialProfileURL(
            from: tiktokProfileURLInput,
            platform: .tiktok
        )

        Task {
            defer { socialProfilesSaveRunning = false }
            do {
                try await supabaseService.updateMyProfileSocialLinks(
                    instagramURL: instagram,
                    tiktokURL: tiktok
                )
                if let refreshed = try await supabaseService.fetchMyProfile() {
                    cloudProfile = refreshed
                    applyCloudProfileSocialLinksToInputs(refreshed)
                }
                socialProfilesSaveStatus = viewModel.localizer.accountSocialProfilesSaved
                socialProfilesSaveIsError = false
            } catch {
                let details = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                socialProfilesSaveStatus = String(
                    format: viewModel.localizer.accountSocialProfilesSaveFailedFormat,
                    details
                )
                socialProfilesSaveIsError = true
            }
        }
    }

    @MainActor
    private func uploadSelectedAvatar(from item: PhotosPickerItem) async {
        avatarUploadRunning = true
        defer {
            avatarUploadRunning = false
            selectedAvatarPhotoItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData),
                  let jpegData = image.jpegData(compressionQuality: 0.9) else {
                return
            }

            let uploadedURL = try await supabaseService.uploadMyProfileAvatar(imageData: jpegData)
            accountProfileImageURL = uploadedURL
            if let refreshed = try await supabaseService.fetchMyProfile() {
                cloudProfile = refreshed
                applyCloudProfileSocialLinksToInputs(refreshed)
            }
        } catch {
            // MVP: silently fall back to current avatar placeholder/image on failure.
        }
    }

    private func extractedUsername(from rawValue: String?, platform: RecipeExternalPlatform) -> String? {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        if let usernameFromKnownURL = extractedUsernameFromKnownURL(trimmed, platform: platform) {
            return usernameFromKnownURL
        }

        let fallback = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractedUsernameFromKnownURL(_ rawValue: String, platform: RecipeExternalPlatform) -> String? {
        guard let url = URL(string: rawValue), let host = url.host?.lowercased() else {
            return nil
        }
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        switch platform {
        case .instagram:
            guard host.contains("instagram.com"), let first = pathComponents.first else { return nil }
            let cleaned = first.hasPrefix("@") ? String(first.dropFirst()) : first
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        case .tiktok:
            guard host.contains("tiktok.com"), let first = pathComponents.first else { return nil }
            let cleaned = first.hasPrefix("@") ? String(first.dropFirst()) : first
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func normalizedSocialProfileURL(from input: String, platform: RecipeExternalPlatform) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let username = extractedUsernameFromKnownURL(trimmed, platform: platform), !username.isEmpty {
            switch platform {
            case .instagram:
                return "https://instagram.com/\(username)"
            case .tiktok:
                return "https://tiktok.com/@\(username)"
            }
        }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return trimmed
        }

        let cleanedUsername = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let normalized = cleanedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        switch platform {
        case .instagram:
            return "https://instagram.com/\(normalized)"
        case .tiktok:
            return "https://tiktok.com/@\(normalized)"
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
