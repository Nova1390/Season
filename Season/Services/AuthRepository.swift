import Foundation
import Supabase

final class AuthRepository {
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

        _ = try await supabaseClient.auth.signIn(email: normalizedEmail, password: normalizedPassword)
        guard let userID = supabaseClient.auth.currentUser?.id else {
            throw SupabaseServiceError.unauthenticated
        }
        return userID
    }

    func signUpWithEmail(email: String, password: String) async throws -> UUID {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }

        _ = try await supabaseClient.auth.signUp(email: normalizedEmail, password: normalizedPassword)
        if supabaseClient.auth.currentUser == nil {
            _ = try await supabaseClient.auth.signIn(email: normalizedEmail, password: normalizedPassword)
        }
        guard let userID = supabaseClient.auth.currentUser?.id else {
            throw SupabaseServiceError.unauthenticated
        }
        return userID
    }

    func signOut() async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }
        try await supabaseClient.auth.signOut()
    }

    func signInWithAppleIDToken(_ idToken: String) async throws -> UUID {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let trimmedToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw SupabaseServiceError.unauthenticated
        }

        print("[SEASON_AUTH] phase=apple_supabase_exchange_started")
        _ = try await supabaseClient.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: trimmedToken
            )
        )

        guard let userID = supabaseClient.auth.currentUser?.id else {
            print("[SEASON_AUTH] phase=apple_supabase_exchange_failed reason=missing_current_user_after_exchange")
            throw SupabaseServiceError.unauthenticated
        }

        print("[SEASON_AUTH] phase=apple_supabase_exchange_succeeded user_id=\(userID.uuidString.lowercased())")
        return userID
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

        guard let user = supabaseClient.auth.currentUser else {
            return nil
        }

        let response = try await supabaseClient
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
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
