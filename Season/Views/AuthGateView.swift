import SwiftUI

private enum AuthGatePhase {
    case loading
    case unauthenticated
    case needsUsername
    case authenticated
}

private enum AuthEntryMode {
    case entry
    case signUp
    case logIn
}

private enum AuthActionKind {
    case apple
    case signUp
    case logIn
    case username
}

private enum UsernameValidation {
    static let minLength = 3
    static let maxLength = 24

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func validationError(for raw: String) -> String? {
        let value = normalized(raw)
        if value.count < minLength {
            return "Username must be at least \(minLength) characters."
        }
        if value.count > maxLength {
            return "Username must be at most \(maxLength) characters."
        }
        let pattern = "^[a-zA-Z0-9_]+$"
        let valid = value.range(of: pattern, options: .regularExpression) != nil
        if !valid {
            return "Use only letters, numbers, and underscore."
        }
        return nil
    }

    static func isValid(_ raw: String) -> Bool {
        validationError(for: raw) == nil
    }
}

private func mappedAuthMessage(_ error: Error, action: AuthActionKind) -> String {
    if let socialError = error as? SocialAuthError {
        switch socialError {
        case .cancelled:
            return "Apple sign-in was cancelled."
        case .appleAuthorizationFailed:
            return "Apple sign-in failed. Please try again."
        case .oauthFlowFailed, .unknown, .missingPresentationAnchor:
            return "Apple sign-in failed. Please try again."
        case .oauthNotConfigured:
            return "Apple sign-in is not available right now."
        }
    }

    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    let normalized = message.lowercased()

    if normalized.contains("username_taken") {
        return "That username is already taken."
    }

    if normalized.contains("user already registered") || normalized.contains("already registered") {
        return "That email is already in use."
    }
    if normalized.contains("invalid email") || normalized.contains("email address") {
        return "Please enter a valid email address."
    }
    if normalized.contains("password should be") || normalized.contains("weak password") || normalized.contains("password") && normalized.contains("at least") {
        return "Password is too short. Use at least 6 characters."
    }
    if normalized.contains("invalid login credentials") || normalized.contains("invalid credentials") {
        return "Wrong email or password."
    }
    if normalized.contains("network") || normalized.contains("offline") || normalized.contains("timed out") {
        return "Network error. Check your connection and try again."
    }
    if normalized.contains("duplicate key") || normalized.contains("season_username") || normalized.contains("unique") {
        return "That username is already taken."
    }

    switch action {
    case .apple:
        return "Apple sign-in failed. Please try again."
    case .signUp:
        return "Sign up failed. Please try again."
    case .logIn:
        return "Log in failed. Please try again."
    case .username:
        return "Could not save username. Please try again."
    }
}

struct AuthGateView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("accountUsername") private var accountUsername = "You"

    @State private var phase: AuthGatePhase = .loading
    @State private var contentSessionID = UUID()
    @State private var refreshInProgress = false

    private let supabaseService = SupabaseService.shared

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView()
                }
            case .unauthenticated:
                AuthEntryScreen {
                    await refreshAuthGateState(reason: "auth_completed")
                }
            case .needsUsername:
                UsernameCompletionScreen {
                    await refreshAuthGateState(reason: "username_completed")
                }
            case .authenticated:
                ContentView()
                    .id(contentSessionID)
            }
        }
        .task {
            await refreshAuthGateState(reason: "initial_load")
        }
        .onReceive(NotificationCenter.default.publisher(for: .seasonAuthStateDidChange)) { _ in
            Task {
                await refreshAuthGateState(reason: "auth_notification")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshAuthGateState(reason: "scene_active")
            }
        }
    }

    @MainActor
    private func refreshAuthGateState(reason: String) async {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        defer { refreshInProgress = false }

        guard let userID = supabaseService.currentAuthenticatedUserID() else {
            if phase == .authenticated {
                contentSessionID = UUID()
            }
            print("[SEASON_AUTH_GATE] phase=state_update reason=\(reason) state=unauthenticated")
            phase = .unauthenticated
            return
        }

        do {
            let profile = try await supabaseService.fetchMyProfile()
            let username = profile?.season_username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if username.isEmpty || !UsernameValidation.isValid(username) {
                print("[SEASON_AUTH_GATE] phase=state_update reason=\(reason) user_id=\(userID.uuidString.lowercased()) state=needs_username")
                phase = .needsUsername
                return
            }

            accountUsername = username
            print("[SEASON_AUTH_GATE] phase=state_update reason=\(reason) user_id=\(userID.uuidString.lowercased()) state=authenticated")
            phase = .authenticated
        } catch {
            print("[SEASON_AUTH_GATE] phase=state_update reason=\(reason) state=unauthenticated error=\(error.localizedDescription)")
            if phase == .authenticated {
                contentSessionID = UUID()
            }
            phase = .unauthenticated
        }
    }
}

private struct AuthEntryScreen: View {
    @AppStorage("accountUsername") private var accountUsername = "You"

    @State private var mode: AuthEntryMode = .entry
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var isError = false

    private let socialAuthService: SocialAuthServicing = SocialAuthService.live
    private let supabaseService = SupabaseService.shared
    let onAuthCompleted: () async -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Eat better, in season.")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Save recipes, manage your fridge, and cook smarter. Free. Now and forever.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                VStack(spacing: 12) {
                    Button {
                        continueWithApple()
                    } label: {
                        Label("Continue with Apple", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)

                    if mode == .entry {
                        Button("Sign up with email") {
                            clearStatus()
                            mode = .signUp
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(isLoading)

                        Button("Already have an account? Log in") {
                            clearStatus()
                            mode = .logIn
                        }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .disabled(isLoading)
                    } else {
                        VStack(spacing: 10) {
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)

                            if mode == .signUp {
                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                Text("3-24 chars • letters, numbers, underscore")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(mode == .signUp ? "Create account" : "Log in") {
                            submitEmailAuth()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(
                            isLoading ||
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            password.isEmpty ||
                            (mode == .signUp && UsernameValidation.validationError(for: username) != nil)
                        )

                        Button("Back") {
                            clearStatus()
                            mode = .entry
                        }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .disabled(isLoading)
                    }

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Processing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    } else if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(isError ? .red : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.86))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func clearStatus() {
        statusMessage = ""
        isError = false
    }

    private func continueWithApple() {
        guard !isLoading else { return }
        clearStatus()
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                _ = try await socialAuthService.authenticate(with: .apple)
                print("[SEASON_AUTH_GATE] phase=apple_sign_in_success")
                await onAuthCompleted()
            } catch {
                print("[SEASON_AUTH_GATE] phase=apple_sign_in_failed error=\(error.localizedDescription)")
                await MainActor.run {
                    statusMessage = mappedAuthMessage(error, action: .apple)
                    isError = true
                }
            }
        }
    }

    private func submitEmailAuth() {
        guard !isLoading else { return }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password
        let normalizedUsername = UsernameValidation.normalized(username)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else { return }
        if mode == .signUp {
            if let validationError = UsernameValidation.validationError(for: normalizedUsername) {
                statusMessage = validationError
                isError = true
                return
            }
        }

        clearStatus()
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                if mode == .signUp {
                    let userID = try await supabaseService.signUpWithEmail(email: normalizedEmail, password: normalizedPassword)
                    let available = try await supabaseService.isUsernameAvailable(normalizedUsername, excludingUserID: userID)
                    guard available else {
                        throw NSError(domain: "SeasonAuth", code: 409, userInfo: [NSLocalizedDescriptionKey: "username_taken"])
                    }
                    try await supabaseService.upsertMyProfileIdentity(username: normalizedUsername, displayName: normalizedUsername)
                    accountUsername = normalizedUsername
                    print("[SEASON_AUTH_GATE] phase=email_sign_up_success user_id=\(userID.uuidString.lowercased())")
                } else {
                    let userID = try await supabaseService.signInWithEmail(email: normalizedEmail, password: normalizedPassword)
                    print("[SEASON_AUTH_GATE] phase=email_sign_in_success user_id=\(userID.uuidString.lowercased())")
                }

                await onAuthCompleted()
            } catch {
                print("[SEASON_AUTH_GATE] phase=email_auth_failed mode=\(mode == .signUp ? "sign_up" : "log_in") error=\(error.localizedDescription)")
                await MainActor.run {
                    statusMessage = mappedAuthMessage(error, action: mode == .signUp ? .signUp : .logIn)
                    isError = true
                }
            }
        }
    }
}

private struct UsernameCompletionScreen: View {
    @AppStorage("accountUsername") private var accountUsername = "You"

    @State private var username = ""
    @State private var isSaving = false
    @State private var statusMessage = ""
    @State private var isError = false

    private let supabaseService = SupabaseService.shared
    let onCompleted: () async -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text("Choose your username")
                    .font(.title.weight(.bold))

                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Text("3-24 chars • letters, numbers, underscore")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    saveUsername()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || UsernameValidation.validationError(for: username) != nil)

                if isSaving {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Saving username…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func saveUsername() {
        guard !isSaving else { return }
        let normalizedUsername = UsernameValidation.normalized(username)
        if let validationError = UsernameValidation.validationError(for: normalizedUsername) {
            statusMessage = validationError
            isError = true
            return
        }
        isSaving = true
        statusMessage = ""
        isError = false

        Task {
            defer { isSaving = false }
            do {
                let currentUserID = supabaseService.currentAuthenticatedUserID()
                let available = try await supabaseService.isUsernameAvailable(normalizedUsername, excludingUserID: currentUserID)
                guard available else {
                    throw NSError(domain: "SeasonAuth", code: 409, userInfo: [NSLocalizedDescriptionKey: "username_taken"])
                }
                try await supabaseService.upsertMyProfileIdentity(username: normalizedUsername, displayName: normalizedUsername)
                accountUsername = normalizedUsername
                print("[SEASON_AUTH_GATE] phase=username_saved_success username=\(normalizedUsername)")
                await onCompleted()
            } catch {
                print("[SEASON_AUTH_GATE] phase=username_saved_failed error=\(error.localizedDescription)")
                await MainActor.run {
                    statusMessage = mappedAuthMessage(error, action: .username)
                    isError = true
                }
            }
        }
    }
}
