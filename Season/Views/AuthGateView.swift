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
                    DS.Color.bg.ignoresSafeArea()
                    ProgressView()
                        .tint(DS.Color.sage)
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
            // Keep authenticated session users in a recoverable onboarding state when profile read fails.
            // Do not route to unauthenticated unless the session itself is missing.
            print("[SEASON_AUTH_GATE] phase=state_update reason=\(reason) user_id=\(userID.uuidString.lowercased()) state=needs_username reason=profile_unavailable error=\(error.localizedDescription)")
            phase = .needsUsername
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
            Image("auth_stitch_login_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: DS.Color.ink.opacity(0.18), location: 0.0),
                    .init(color: DS.Color.ink.opacity(0.24), location: 0.28),
                    .init(color: DS.Color.ink.opacity(0.56), location: 0.62),
                    .init(color: DS.Color.ink.opacity(0.90), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Season")
                        .font(DS.Font.wordmark)
                    Text(".")
                        .font(DS.Font.serif(22, weight: .medium, italic: true))
                        .foregroundStyle(DS.Color.sageSoft)
                    Spacer()
                    Text("EST. MMXXVI")
                        .font(DS.Font.mono(9.5, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.56))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Cook with the\nland, not\nagainst it.")
                            .font(DS.Font.serif(46, weight: .medium, italic: true))
                            .foregroundStyle(Color.white)
                            .lineSpacing(-4)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("A field guide to seasonal cooking, built around what’s growing near you right now.")
                            .font(DS.Font.serif(16, weight: .regular, italic: true))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, mode == .entry ? 32 : 20)

                    VStack(spacing: 12) {
                        if mode == .entry {
                            if FeatureFlags.appleAuthenticationEnabled {
                                Button {
                                    continueWithApple()
                                } label: {
                                    Label("Continue with Apple", systemImage: "applelogo")
                                        .font(DS.Font.sans(16, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                        .frame(maxWidth: .infinity, minHeight: 56)
                                }
                                .buttonStyle(AuthGateAppleButtonStyle())
                                .disabled(isLoading)
                            }

                            Button {
                                clearStatus()
                                mode = .signUp
                            } label: {
                                Text("Sign up with email")
                                    .font(DS.Font.sans(16, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(AuthGateOutlineButtonStyle())
                            .disabled(isLoading)

                            Button {
                                clearStatus()
                                mode = .logIn
                            } label: {
                                Text("Already have an account? \(Text("Log in").underline())")
                                    .font(DS.Font.sans(13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white.opacity(0.66))
                            .padding(.top, 6)
                            .disabled(isLoading)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(mode == .signUp ? "Create your account" : "Welcome back")
                                    .font(DS.Font.serif(23, weight: .medium))
                                    .foregroundStyle(DS.Color.ink)

                                Group {
                                    TextField("Email", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()

                                    SecureField("Password", text: $password)

                                    if mode == .signUp {
                                        TextField("Username", text: $username)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    }
                                }
                                .textFieldStyle(AuthGateTextFieldStyle())

                                if mode == .signUp {
                                    Text("3-24 chars • letters, numbers, underscore")
                                        .font(DS.Font.sans(11))
                                        .foregroundStyle(DS.Color.inkMuted)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(DS.Color.card.opacity(0.86))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                            )

                            Button {
                                submitEmailAuth()
                            } label: {
                                Text(mode == .signUp ? "Create account" : "Log in")
                                    .font(DS.Font.sans(16, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(AuthGateSageButtonStyle())
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
                            .font(DS.Font.sans(13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .disabled(isLoading)
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                    .tint(Color.white.opacity(0.82))
                                Text("Processing…")
                                    .font(DS.Font.sans(12))
                                    .foregroundStyle(Color.white.opacity(0.70))
                            }
                            .padding(.top, 4)
                        } else if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(DS.Font.sans(12))
                                .foregroundStyle(isError ? Color.red.opacity(0.92) : Color.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 390)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
            }
            .safeAreaPadding(.top, 16)
            .safeAreaPadding(.bottom, 24)
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
                    let signUpResult = try await supabaseService.signUpWithEmail(email: normalizedEmail, password: normalizedPassword)
                    guard case .signedIn(let userID) = signUpResult else {
                        await MainActor.run {
                            statusMessage = "Check your email to confirm your account, then log in."
                            isError = false
                            password = ""
                            mode = .logIn
                        }
                        print("[SEASON_AUTH_GATE] phase=email_sign_up_confirmation_required")
                        return
                    }
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

private struct AuthGateAppleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DS.Color.ink)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.88 : 0.96))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AuthGateOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(0.96))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
            )
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AuthGateSageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.Color.sage, DS.Color.sageDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: DS.Color.ink.opacity(0.18), radius: 14, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AuthGateTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(DS.Font.sans(14))
            .foregroundStyle(DS.Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.Color.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 0.8)
            )
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
            DS.Color.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text("Choose your username")
                    .font(DS.Font.serif(32, weight: .medium))
                    .foregroundStyle(DS.Color.ink)

                Text("This is how other cooks will find you on Season.")
                    .font(DS.Font.serif(16, weight: .regular, italic: true))
                    .foregroundStyle(DS.Color.inkMuted)
                    .multilineTextAlignment(.center)

                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(AuthGateTextFieldStyle())

                Text("3-24 chars • letters, numbers, underscore")
                    .font(DS.Font.sans(11))
                    .foregroundStyle(DS.Color.inkMuted)

                Button {
                    saveUsername()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SeasonPrimaryButtonStyle())
                .disabled(isSaving || UsernameValidation.validationError(for: username) != nil)

                if isSaving {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                            .tint(DS.Color.sage)
                        Text("Saving username…")
                            .font(DS.Font.sans(12))
                            .foregroundStyle(DS.Color.inkMuted)
                    }
                } else if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(DS.Font.sans(12))
                        .foregroundStyle(isError ? .red : DS.Color.inkMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: 390)
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
