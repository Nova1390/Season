import Foundation
import Supabase

enum EmailSignUpResult {
    case signedIn(UUID)
    case needsEmailConfirmation
}

final class AuthRepository {
    private static let emailConfirmationRedirectURL = URL(string: "season://auth/callback")

    private let client: SupabaseClient?
    private let configurationIssue: String?

    init(
        client: SupabaseClient?,
        configurationIssue: String?
    ) {
        self.client = client
        self.configurationIssue = configurationIssue
    }

    func currentAuthenticatedUserID() -> UUID? {
        client?.auth.currentUser?.id
    }

    func currentAuthenticatedEmail() -> String? {
        let value = client?.auth.currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    func isUsernameAvailable(_ username: String, excludingUserID: UUID? = nil) async throws -> Bool {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        let response = try await supabaseClient
            .from("profiles")
            .select("id")
            .eq("season_username", value: normalized)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([SupabaseProfileProbe].self, from: response.data)
        guard let foundID = rows.first?.id else { return true }
        if let excludingUserID, foundID == excludingUserID {
            return true
        }
        return false
    }

    func signInWithEmail(email: String, password: String) async throws -> UUID {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }

        let session = try await supabaseClient.auth.signIn(email: normalizedEmail, password: normalizedPassword)
        _ = try await supabaseClient.auth.setSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken
        )
        return session.user.id
    }

    func signUpWithEmail(email: String, password: String) async throws -> EmailSignUpResult {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }

        let response = try await supabaseClient.auth.signUp(
            email: normalizedEmail,
            password: normalizedPassword,
            redirectTo: Self.emailConfirmationRedirectURL
        )
        if let session = response.session {
            _ = try await supabaseClient.auth.setSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            return .signedIn(session.user.id)
        }

        if let userID = supabaseClient.auth.currentUser?.id {
            return .signedIn(userID)
        }

        return .needsEmailConfirmation
    }

    func signOut() async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }
        try await supabaseClient.auth.signOut()
    }

    func signInWithAppleIDToken(
        _ idToken: String,
        nonce: String,
        fullName: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> UUID {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let trimmedToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }
        let trimmedNonce = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNonce.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }

        SeasonLog.debug("[SEASON_AUTH] phase=apple_supabase_exchange_started")
        let session = try await supabaseClient.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: trimmedToken,
                nonce: trimmedNonce
            )
        )
        _ = try await supabaseClient.auth.setSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken
        )

        await updateAppleUserMetadataIfNeeded(
            client: supabaseClient,
            fullName: fullName,
            givenName: givenName,
            familyName: familyName
        )

        let userID = session.user.id
        SeasonLog.debug("[SEASON_AUTH] phase=apple_supabase_exchange_succeeded user_id=\(userID.uuidString.lowercased())")
        return userID
    }

    private func updateAppleUserMetadataIfNeeded(
        client supabaseClient: SupabaseClient,
        fullName: String?,
        givenName: String?,
        familyName: String?
    ) async {
        let normalizedFullName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGivenName = givenName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFamilyName = familyName?.trimmingCharacters(in: .whitespacesAndNewlines)

        var metadata: [String: AnyJSON] = [:]
        if let normalizedFullName, !normalizedFullName.isEmpty {
            metadata["full_name"] = .string(normalizedFullName)
        }
        if let normalizedGivenName, !normalizedGivenName.isEmpty {
            metadata["given_name"] = .string(normalizedGivenName)
        }
        if let normalizedFamilyName, !normalizedFamilyName.isEmpty {
            metadata["family_name"] = .string(normalizedFamilyName)
        }
        guard !metadata.isEmpty else { return }

        do {
            _ = try await supabaseClient.auth.update(user: UserAttributes(data: metadata))
            SeasonLog.debug("[SEASON_AUTH] phase=apple_user_metadata_updated")
        } catch {
            SeasonLog.debug("[SEASON_AUTH] phase=apple_user_metadata_update_failed error=\(error.localizedDescription)")
        }
    }

    func validateProfilePipeline(for userID: UUID) async throws -> Bool {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let response = try await supabaseClient
            .from("profiles")
            .select("id")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([SupabaseProfileProbe].self, from: response.data)
        return !rows.isEmpty
    }

    func fetchMyProfile() async throws -> Profile? {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let userID: UUID
        if let user = supabaseClient.auth.currentUser {
            userID = user.id
        } else {
            userID = try await supabaseClient.auth.session.user.id
        }

        let response = try await supabaseClient
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .single()
            .execute()

        return try JSONDecoder().decode(Profile.self, from: response.data)
    }

    func updateMyProfileSocialLinks(instagramURL: String?, tiktokURL: String?) async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            throw SupabaseServiceError.unauthenticated
        }

        let payload = ProfileSocialLinksUpdatePayload(
            instagram_url: instagramURL,
            tiktok_url: tiktokURL
        )

        _ = try await supabaseClient
            .from("profiles")
            .update(payload)
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    func upsertMyProfileIdentity(username: String, displayName: String?) async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            throw SupabaseServiceError.unauthenticated
        }

        let normalizedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedUsername.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }
        let normalizedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = ProfileIdentityUpsertPayload(
            id: user.id.uuidString,
            display_name: normalizedDisplayName?.isEmpty == false ? normalizedDisplayName : nil,
            season_username: normalizedUsername
        )

        _ = try await supabaseClient
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    func uploadMyProfileAvatar(imageData: Data) async throws -> String {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            throw SupabaseServiceError.unauthenticated
        }

        let path = "avatars/\(user.id.uuidString.lowercased()).jpg"
        _ = try await supabaseClient.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let publicURL = try supabaseClient.storage
            .from("avatars")
            .getPublicURL(path: path)
            .absoluteString

        let payload = ProfileAvatarUpdatePayload(avatar_url: publicURL)
        _ = try await supabaseClient
            .from("profiles")
            .update(payload)
            .eq("id", value: user.id.uuidString)
            .execute()

        return publicURL
    }

    func fetchMyLinkedSocialAccounts() async throws -> [CloudLinkedSocialAccount] {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            return []
        }

        let response = try await supabaseClient
            .from("linked_social_accounts")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .execute()

        return try JSONDecoder().decode([CloudLinkedSocialAccount].self, from: response.data)
    }

    func deleteMyLinkedSocialAccount(provider: String) async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            throw SupabaseServiceError.unauthenticated
        }

        _ = try await supabaseClient
            .from("linked_social_accounts")
            .delete()
            .eq("user_id", value: user.id.uuidString)
            .eq("provider", value: provider)
            .execute()
    }
}

private struct ProfileSocialLinksUpdatePayload: Encodable {
    let instagram_url: String?
    let tiktok_url: String?
}

private struct ProfileAvatarUpdatePayload: Encodable {
    let avatar_url: String?
}

private struct ProfileIdentityUpsertPayload: Encodable {
    let id: String
    let display_name: String?
    let season_username: String
}
