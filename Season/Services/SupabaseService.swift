import Foundation
import Supabase

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
}

enum SupabaseServiceError: LocalizedError {
    case missingConfiguration(String)
    case invalidURL
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "Missing Supabase configuration: \(key)."
        case .invalidURL:
            return "Supabase URL is invalid."
        case .unauthenticated:
            return "No authenticated Supabase user found."
        }
    }
}

struct SupabaseProfileProbe: Decodable {
    let id: UUID
}

struct Profile: Codable {
    let id: UUID
    let created_at: String?
    let display_name: String?
    let season_username: String?
    let avatar_url: String?
    let preferred_language: String?
    let is_public: Bool?
}

struct CloudLinkedSocialAccount: Codable {
    let id: String?
    let user_id: String?
    let provider: String
    let provider_user_id: String?
    let display_name: String?
    let handle: String?
    let profile_image_url: String?
    let is_verified: Bool?
    let linked_at: String?
    let created_at: String?
}

struct CloudUserRecipeState: Codable {
    let id: String?
    let user_id: String?
    let recipe_id: String?
    let is_saved: Bool?
    let is_crispied: Bool?
    let is_archived: Bool?
    let updated_at: String?
}

private struct UserRecipeSavedStateUpsert: Encodable {
    let user_id: String
    let recipe_id: String
    let is_saved: Bool
    let updated_at: String
}

private struct UserRecipeCrispiedStateUpsert: Encodable {
    let user_id: String
    let recipe_id: String
    let is_crispied: Bool
    let updated_at: String
}

final class SupabaseService {
    static let shared = SupabaseService()

    let configuration: SupabaseConfiguration?
    let configurationIssue: String?
    private let client: SupabaseClient?

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseService.loadConfiguration(from: bundle)
            self.configuration = configuration
            self.configurationIssue = nil
            self.client = SupabaseClient(
                supabaseURL: configuration.url,
                supabaseKey: configuration.anonKey
            )
        } catch {
            self.configuration = nil
            self.configurationIssue = (error as? LocalizedError)?.errorDescription ?? "Supabase configuration is invalid."
            self.client = nil
        }
    }

    func authenticateWithEmailPasswordForTesting(email: String, password: String) async throws -> UUID {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("Email")
        }
        guard !normalizedPassword.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("Password")
        }

        guard let client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        do {
            _ = try await client.auth.signIn(email: normalizedEmail, password: normalizedPassword)
        } catch {
            _ = try await client.auth.signUp(email: normalizedEmail, password: normalizedPassword)
            _ = try await client.auth.signIn(email: normalizedEmail, password: normalizedPassword)
        }

        guard let userID = client.auth.currentUser?.id else {
            throw SupabaseServiceError.unauthenticated
        }
        return userID
    }

    func validateProfilePipeline(for userID: UUID) async throws -> Bool {
        guard let client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }
        
        let response = try await client
            .from("profiles")
            .select("id")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
        
        let rows = try JSONDecoder().decode([SupabaseProfileProbe].self, from: response.data)
        return !rows.isEmpty
    }

    func fetchMyProfile() async throws -> Profile? {
        guard let supabaseClient = self.client else {
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

    func fetchMyLinkedSocialAccounts() async throws -> [CloudLinkedSocialAccount] {
        guard let supabaseClient = self.client else {
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

    func fetchMyUserRecipeStates() async throws -> [CloudUserRecipeState] {
        guard let supabaseClient = self.client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            return []
        }

        let response = try await supabaseClient
            .from("user_recipe_states")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .execute()

        return try JSONDecoder().decode([CloudUserRecipeState].self, from: response.data)
    }

    func setRecipeSavedState(recipeID: String, isSaved: Bool) async throws {
        print("[SEASON_SUPABASE] entered setRecipeSavedState for recipe: \(recipeID) isSaved: \(isSaved)")
        guard let supabaseClient = self.client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            return
        }

        let payload = UserRecipeSavedStateUpsert(
            user_id: user.id.uuidString,
            recipe_id: recipeID,
            is_saved: isSaved,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await performWithRetry {
                _ = try await supabaseClient
                    .from("user_recipe_states")
                    .upsert(payload, onConflict: "user_id,recipe_id")
                    .execute()
            }
            print("[SEASON_SUPABASE] save state write OK for recipe: \(recipeID)")
        } catch {
            print("[SEASON_SUPABASE] save state write FAILED: \(error)")
            throw error
        }
    }

    func setRecipeCrispiedState(recipeID: String, isCrispied: Bool) async throws {
        print("[SEASON_SUPABASE] entered setRecipeCrispiedState for recipe: \(recipeID) isCrispied: \(isCrispied)")
        guard let supabaseClient = self.client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let user = supabaseClient.auth.currentUser else {
            return
        }

        let payload = UserRecipeCrispiedStateUpsert(
            user_id: user.id.uuidString,
            recipe_id: recipeID,
            is_crispied: isCrispied,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await performWithRetry {
                _ = try await supabaseClient
                    .from("user_recipe_states")
                    .upsert(payload, onConflict: "user_id,recipe_id")
                    .execute()
            }
            print("[SEASON_SUPABASE] crispied state write OK for recipe: \(recipeID)")
        } catch {
            print("[SEASON_SUPABASE] crispied state write FAILED: \(error)")
            throw error
        }
    }

    private func performWithRetry(
        operation: @escaping () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch {
            if isTransientNetworkError(error) {
                print("[SEASON_SUPABASE] retrying operation after transient error...")
                try await Task.sleep(nanoseconds: 300_000_000)
                try await operation()
            } else {
                throw error
            }
        }
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            (nsError.code == -1005 ||
             nsError.code == -1001 ||
             nsError.code == -1009)
    }

    private static func loadConfiguration(from bundle: Bundle) throws -> SupabaseConfiguration {
        let urlString = firstInfoPlistString(
            in: bundle,
            keys: ["SUPABASE_URL", "SupabaseURL", "supabase_url"]
        )
        let key = firstInfoPlistString(
            in: bundle,
            keys: ["SUPABASE_ANON_KEY", "SupabaseAnonKey", "supabase_anon_key"]
        )

        let normalizedURLString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedKey = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !normalizedURLString.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("SUPABASE_URL")
        }

        guard !normalizedKey.isEmpty else {
            throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
        }

        guard let url = URL(string: normalizedURLString) else {
            throw SupabaseServiceError.invalidURL
        }

        return SupabaseConfiguration(url: url, anonKey: normalizedKey)
    }

    private static func firstInfoPlistString(in bundle: Bundle, keys: [String]) -> String? {
        for key in keys {
            if let value = bundle.object(forInfoDictionaryKey: key) as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }

            if let value = bundle.infoDictionary?[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
