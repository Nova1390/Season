import Foundation
import Supabase
import CryptoKit

enum NetworkErrorCategory: String {
    case auth_session
    case permission_rls
    case network_offline
    case rate_limit
    case server_error
    case client_validation
    case unknown
}

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
}

enum SupabaseServiceError: LocalizedError {
    case missingConfiguration(String)
    case invalidURL
    case unauthenticated
    case requestTimedOut(String, TimeInterval)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "Missing Supabase configuration: \(key)."
        case .invalidURL:
            return "Supabase URL is invalid."
        case .unauthenticated:
            return "No authenticated Supabase user found."
        case .requestTimedOut(let requestName, let seconds):
            return "\(requestName) timed out after \(Int(seconds))s."
        }
    }
}

enum ParseRecipeCaptionInvokeError: Error {
    case tooFrequent(retryAfterSeconds: Int?)
    case dailyLimitReached
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
    let instagram_url: String?
    let tiktok_url: String?
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

struct CloudShoppingListItem: Codable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool?
    let created_at: String?
    let updated_at: String?
}

struct CloudFridgeItem: Codable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let created_at: String?
    let updated_at: String?
}

struct IngredientAliasRecord: Sendable {
    let produceID: String?
    let basicIngredientID: String?
    let aliasText: String
    let normalizedAliasText: String
    let languageCode: String?
    let source: String
    let confidence: Double?
    let isActive: Bool
}

struct UnifiedIngredientCatalogSummaryRecord: Sendable {
    let ingredientID: String
    let slug: String
    let ingredientType: String
    let enName: String?
    let itName: String?
    let legacyProduceID: String?
    let legacyBasicID: String?
}

struct UnifiedIngredientAliasRecord: Sendable {
    let ingredientID: String
    let aliasText: String
    let normalizedAliasText: String
    let languageCode: String?
    let source: String
    let confidence: Double?
    let isActive: Bool
}

private struct CloudIngredientAliasRow: Codable {
    let produce_id: String?
    let basic_ingredient_id: String?
    let alias_text: String?
    let normalized_alias_text: String?
    let language_code: String?
    let source: String?
    let confidence: Double?
    let is_active: Bool?
}

private struct CloudUnifiedIngredientCatalogSummaryRow: Codable {
    let ingredient_id: String
    let slug: String
    let ingredient_type: String
    let en_name: String?
    let it_name: String?
    let legacy_produce_id: String?
    let legacy_basic_id: String?
}

private struct CloudUnifiedIngredientAliasRow: Codable {
    let ingredient_id: String?
    let alias_text: String?
    let normalized_alias_text: String?
    let language_code: String?
    let source: String?
    let confidence: Double?
    let is_active: Bool?
}

struct ParseRecipeCaptionFunctionIngredient: Codable {
    let name: String
    let quantity: Double?
    let unit: String?
}

struct ParseRecipeCaptionFunctionResult: Codable {
    let title: String?
    let ingredients: [ParseRecipeCaptionFunctionIngredient]
    let steps: [String]
    let prepTimeMinutes: Double?
    let cookTimeMinutes: Double?
    let confidence: String
    let inferredDish: String?
}

struct ParseRecipeCaptionFunctionError: Codable {
    let code: String
    let message: String
}

struct ParseRecipeCaptionFunctionResponse: Codable {
    let ok: Bool
    let result: ParseRecipeCaptionFunctionResult?
    let error: ParseRecipeCaptionFunctionError?
}

struct CustomIngredientObservation: Sendable {
    let normalizedText: String
    let rawExample: String
    let languageCode: String?
    let source: String
    let latestRecipeID: String?
}

struct CustomIngredientObservationInsightRecord: Sendable {
    let normalizedText: String
    let occurrenceCount: Int
    let exampleCount: Int
    let latestExample: String?
    let languageCode: String?
    let source: String?
    let priorityScore: Double
}

private struct ParseRecipeCaptionFunctionRequest: Encodable {
    let caption: String?
    let url: String?
    let languageCode: String
}

private struct CloudCustomIngredientObservationInsightRow: Codable {
    let normalized_text: String?
    let occurrence_count: Int?
    let example_count: Int?
    let latest_example: String?
    let language_code: String?
    let source: String?
    let priority_score: Double?
}

private struct ParseRecipeCaptionFunctionErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    struct MetaBody: Decodable {
        let retryAfterSeconds: Int?
    }

    let ok: Bool
    let error: ErrorBody?
    let meta: MetaBody?
}

private struct CloudFollowRow: Codable {
    let id: String?
    let follower_id: String?
    let following_id: String?
    let created_at: String?
}

private struct FollowInsertPayload: Encodable {
    let follower_id: String
    let following_id: String
    let created_at: String
}

private struct CloudRecipeIngredient: Codable {
    let produce_id: String?
    let basic_ingredient_id: String?
    let name: String?
    let quantity_value: Double?
    let quantity_unit: String?
}

private struct CloudRecipeRow: Codable {
    let id: String
    let user_id: String?
    let creator_id: String?
    let creator_display_name: String?
    let creator_avatar_url: String?
    let avatar_url: String?
    let title: String?
    let ingredients: [CloudRecipeIngredient]?
    let steps: [String]?
    let servings: Int?
    let image_url: String?
    let instagram_url: String?
    let tiktok_url: String?
    let created_at: String?
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

private struct ShoppingListItemInsertPayload: Encodable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool
    let created_at: String
    let updated_at: String
}

private struct ShoppingListItemUpdatePayload: Encodable {
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let source_recipe_id: String?
    let is_checked: Bool
    let updated_at: String
}

private struct FridgeItemInsertPayload: Encodable {
    let id: String
    let user_id: String
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let created_at: String
    let updated_at: String
}

private struct FridgeItemUpdatePayload: Encodable {
    let ingredient_type: String
    let ingredient_id: String?
    let custom_name: String?
    let quantity: Double?
    let unit: String?
    let updated_at: String
}

private struct RecipeIngredientInsertPayload: Encodable {
    let produce_id: String?
    let basic_ingredient_id: String?
    let name: String
    let quantity_value: Double
    let quantity_unit: String
}

private struct RecipeInsertPayload: Encodable {
    let id: String
    let user_id: String
    let creator_id: String?
    let creator_display_name: String?
    let title: String
    let ingredients: [RecipeIngredientInsertPayload]
    let steps: [String]
    let servings: Int
    let image_url: String?
    let instagram_url: String?
    let tiktok_url: String?
    let created_at: String
}

private struct RecipeInsertPayloadWithoutImageURL: Encodable {
    let id: String
    let user_id: String
    let creator_id: String?
    let creator_display_name: String?
    let title: String
    let ingredients: [RecipeIngredientInsertPayload]
    let steps: [String]
    let servings: Int
    let instagram_url: String?
    let tiktok_url: String?
    let created_at: String
}

private struct ProfileSocialLinksUpdatePayload: Encodable {
    let instagram_url: String?
    let tiktok_url: String?
}

private struct ProfileAvatarUpdatePayload: Encodable {
    let avatar_url: String?
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

    func currentAuthenticatedUserID() -> UUID? {
        client?.auth.currentUser?.id
    }

    func fetchFollows(for followerId: String) async -> [FollowRelation] {
        let normalizedFollowerID = normalizeFollowID(followerId)
        guard !normalizedFollowerID.isEmpty else { return [] }

        print("[SEASON_SUPABASE] request=fetchFollows phase=request_started follower_id=\(normalizedFollowerID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await client
                .from("follows")
                .select()
                .eq("follower_id", value: normalizedFollowerID)
                .execute()

            let rows = try JSONDecoder().decode([CloudFollowRow].self, from: response.data)
            let iso8601 = ISO8601DateFormatter()
            let relations = rows.compactMap { row -> FollowRelation? in
                let follower = normalizeFollowID(row.follower_id ?? "")
                let following = normalizeFollowID(row.following_id ?? "")
                guard !follower.isEmpty, !following.isEmpty, following != "unknown" else { return nil }
                let createdAt = row.created_at.flatMap { iso8601.date(from: $0) } ?? Date()
                return FollowRelation(followerId: follower, followingId: following, createdAt: createdAt)
            }

            print("[SEASON_SUPABASE] request=fetchFollows phase=request_ok follower_id=\(normalizedFollowerID) count=\(relations.count)")
            return relations
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed reason=table_missing follower_id=\(normalizedFollowerID) error=\(error)")
                return []
            }
            print("[SEASON_SUPABASE] request=fetchFollows phase=request_failed follower_id=\(normalizedFollowerID) error=\(error)")
            return []
        }
    }

    func createFollow(_ relation: FollowRelation) async {
        let followerID = normalizeFollowID(relation.followerId)
        let followingID = normalizeFollowID(relation.followingId)
        guard !followerID.isEmpty, !followingID.isEmpty, followingID != "unknown" else { return }

        print("[SEASON_SUPABASE] request=createFollow phase=request_started follower_id=\(followerID) following_id=\(followingID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=createFollow phase=request_failed reason=missing_configuration")
            return
        }

        let payload = FollowInsertPayload(
            follower_id: followerID,
            following_id: followingID,
            created_at: ISO8601DateFormatter().string(from: relation.createdAt)
        )

        do {
            _ = try await client
                .from("follows")
                .upsert(payload, onConflict: "follower_id,following_id")
                .execute()
            print("[SEASON_SUPABASE] request=createFollow phase=request_ok follower_id=\(followerID) following_id=\(followingID)")
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=createFollow phase=request_failed reason=table_missing follower_id=\(followerID) following_id=\(followingID) error=\(error)")
                return
            }
            print("[SEASON_SUPABASE] request=createFollow phase=request_failed follower_id=\(followerID) following_id=\(followingID) error=\(error)")
        }
    }

    func deleteFollow(followerId: String, followingId: String) async {
        let normalizedFollowerID = normalizeFollowID(followerId)
        let normalizedFollowingID = normalizeFollowID(followingId)
        guard !normalizedFollowerID.isEmpty, !normalizedFollowingID.isEmpty else { return }

        print("[SEASON_SUPABASE] request=deleteFollow phase=request_started follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID)")

        guard let client else {
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed reason=missing_configuration")
            return
        }

        do {
            _ = try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: normalizedFollowerID)
                .eq("following_id", value: normalizedFollowingID)
                .execute()
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_ok follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID)")
        } catch {
            if isMissingFollowsTableError(error) {
                print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed reason=table_missing follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID) error=\(error)")
                return
            }
            print("[SEASON_SUPABASE] request=deleteFollow phase=request_failed follower_id=\(normalizedFollowerID) following_id=\(normalizedFollowingID) error=\(error)")
        }
    }

    func setSession(accessToken: String, refreshToken: String) async throws {
        guard let client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }
        _ = try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
    }

    func authenticateWithEmailPasswordForTesting(email: String, password: String) async throws -> UUID {
        try await instrumentedRequest(name: "authenticateWithEmailPasswordForTesting") {
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
        try await instrumentedRequest(name: "fetchMyProfile") {
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
    }

    func updateMyProfileSocialLinks(instagramURL: String?, tiktokURL: String?) async throws {
        try await instrumentedRequest(name: "updateProfileSocialLinks") {
            guard let supabaseClient = self.client else {
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
    }

    func uploadMyProfileAvatar(imageData: Data) async throws -> String {
        try await instrumentedRequest(name: "uploadMyProfileAvatar") {
            guard let supabaseClient = self.client else {
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
    }

    func uploadRecipeImage(imageData: Data, recipeID: String) async throws -> String {
        try await instrumentedRequest(name: "uploadRecipeImage", metadata: "recipe_id=\(recipeID)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            let userAtUploadTime = supabaseClient.auth.currentUser
            let hasAuthenticatedUser = userAtUploadTime != nil
            let currentUserID = userAtUploadTime?.id.uuidString.lowercased() ?? "nil"

            guard let user = userAtUploadTime else {
                throw SupabaseServiceError.unauthenticated
            }

            let bucketName = "recipes"
            let normalizedRecipeID = recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = "\(user.id.uuidString.lowercased())/\(normalizedRecipeID).jpg"
            let pathSegments = path.split(separator: "/").map(String.init)
            let firstFolderSegment = pathSegments.indices.contains(0) ? pathSegments[0] : "nil"
            let uidPathSegment = pathSegments.indices.contains(1) ? pathSegments[1] : "nil"
            let fileSegment = pathSegments.indices.contains(2) ? pathSegments[2] : "nil"
            let timeoutSeconds: TimeInterval = 10

            print("[SEASON_SUPABASE] phase=upload_context bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) has_authenticated_user=\(hasAuthenticatedUser) current_user_id=\(currentUserID) path_first_segment=\(firstFolderSegment) path_uid_segment=\(uidPathSegment) path_file_segment=\(fileSegment)")
            print("[SEASON_SUPABASE] phase=upload_started bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) expected_auth_uid=\(user.id.uuidString.lowercased())")

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        _ = try await supabaseClient.storage
                            .from(bucketName)
                            .upload(
                                path,
                                data: imageData,
                                options: FileOptions(
                                    contentType: "image/jpeg",
                                    upsert: true
                                )
                            )
                    }

                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        throw SupabaseServiceError.requestTimedOut("uploadRecipeImage", timeoutSeconds)
                    }

                    _ = try await group.next()
                    group.cancelAll()
                }

                return try supabaseClient.storage
                    .from(bucketName)
                    .getPublicURL(path: path)
                    .absoluteString
            } catch let SupabaseServiceError.requestTimedOut(requestName, seconds) {
                print("[SEASON_SUPABASE] request=\(requestName) phase=request_timeout duration_s=\(Int(seconds)) recipe_id=\(recipeID)")
                throw SupabaseServiceError.requestTimedOut(requestName, seconds)
            } catch {
                print("[SEASON_SUPABASE] phase=upload_failed bucket=\(bucketName) path=\(path) recipe_id=\(recipeID) expected_auth_uid=\(user.id.uuidString.lowercased()) error=\(error)")
                throw error
            }
        }
    }

    func parseRecipeCaption(
        caption: String?,
        url: String?,
        languageCode: String
    ) async throws -> ParseRecipeCaptionFunctionResponse {
        try await instrumentedRequest(name: "parseRecipeCaption") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let authenticatedUser = supabaseClient.auth.currentUser else {
                print("[SEASON_IMPORT_AUTH] phase=missing_current_user has_session=false invoke_with_authenticated_context=false")
                throw SupabaseServiceError.unauthenticated
            }

            let accessToken: String
            do {
                accessToken = try await supabaseClient.auth.session.accessToken
            } catch {
                print("[SEASON_IMPORT_AUTH] phase=missing_access_token user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=false invoke_with_authenticated_context=false error=\(error)")
                throw SupabaseServiceError.unauthenticated
            }
            guard let anonKey = self.configuration?.anonKey,
                  !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
            }

            supabaseClient.functions.setAuth(token: accessToken)
            print("[SEASON_IMPORT_AUTH] phase=session_ready user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=true invoke_with_authenticated_context=true")

            let normalizedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = ParseRecipeCaptionFunctionRequest(
                caption: normalizedCaption?.isEmpty == true ? nil : normalizedCaption,
                url: normalizedURL?.isEmpty == true ? nil : normalizedURL,
                languageCode: languageCode
            )

            print("[SEASON_IMPORT_AUTH] phase=invoke_started user_id=\(authenticatedUser.id.uuidString.lowercased()) authenticated_context=true")
            do {
                return try await supabaseClient.functions.invoke(
                    "parse-recipe-caption",
                    options: FunctionInvokeOptions(
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(accessToken)",
                            "apikey": anonKey
                        ],
                        body: payload
                    )
                )
            } catch let functionsError as FunctionsError {
                switch functionsError {
                case .httpError(let code, let data):
                    if code == 429,
                       let parsed = try? JSONDecoder().decode(ParseRecipeCaptionFunctionErrorEnvelope.self, from: data),
                       let errorCode = parsed.error?.code {
                        if errorCode == "TOO_FREQUENT_REQUESTS" {
                            throw ParseRecipeCaptionInvokeError.tooFrequent(
                                retryAfterSeconds: parsed.meta?.retryAfterSeconds
                            )
                        }
                        if errorCode == "RATE_LIMIT_EXCEEDED" {
                            throw ParseRecipeCaptionInvokeError.dailyLimitReached
                        }
                    }
                    throw functionsError
                case .relayError:
                    throw functionsError
                }
            }
        }
    }

    func fetchMyLinkedSocialAccounts() async throws -> [CloudLinkedSocialAccount] {
        try await instrumentedRequest(name: "fetchMyLinkedSocialAccounts") {
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
    }

    func deleteMyLinkedSocialAccount(provider: String) async throws {
        try await instrumentedRequest(name: "deleteMyLinkedSocialAccount", metadata: "provider=\(provider)") {
            guard let supabaseClient = self.client else {
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

    func fetchMyUserRecipeStates() async throws -> [CloudUserRecipeState] {
        try await instrumentedRequest(name: "fetchMyUserRecipeStates") {
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
    }

    func fetchMyShoppingListItems() async throws -> [CloudShoppingListItem] {
        try await instrumentedRequest(name: "fetchMyShoppingListItems") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return []
            }

            let response = try await supabaseClient
                .from("shopping_list_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .execute()

            return try JSONDecoder().decode([CloudShoppingListItem].self, from: response.data)
        }
    }

    func fetchMyFridgeItems() async throws -> [CloudFridgeItem] {
        try await instrumentedRequest(name: "fetchMyFridgeItems") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return []
            }

            let response = try await supabaseClient
                .from("fridge_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .execute()

            return try JSONDecoder().decode([CloudFridgeItem].self, from: response.data)
        }
    }

    func fetchActiveIngredientAliases() async -> [IngredientAliasRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_ALIAS] phase=fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_aliases")
                .select()
                .eq("is_active", value: true)
                .execute()

            let rows = try JSONDecoder().decode([CloudIngredientAliasRow].self, from: response.data)
            let records = rows.compactMap { row -> IngredientAliasRecord? in
                let normalized = row.normalized_alias_text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""
                guard !normalized.isEmpty else { return nil }

                let alias = row.alias_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? normalized
                let produceID = row.produce_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                let basicID = row.basic_ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (produceID?.isEmpty == false) != (basicID?.isEmpty == false) else { return nil }
                let sourceValue = row.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                return IngredientAliasRecord(
                    produceID: produceID?.isEmpty == true ? nil : produceID,
                    basicIngredientID: basicID?.isEmpty == true ? nil : basicID,
                    aliasText: alias,
                    normalizedAliasText: normalized,
                    languageCode: row.language_code?.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: sourceValue.isEmpty ? "manual" : sourceValue,
                    confidence: row.confidence,
                    isActive: row.is_active ?? true
                )
            }
            print("[SEASON_ALIAS] phase=fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingIngredientAliasesTableError(error) {
                print("[SEASON_ALIAS] phase=fetch_failed reason=table_missing error=\(error)")
                return []
            }
            print("[SEASON_ALIAS] phase=fetch_failed error=\(error)")
            return []
        }
    }

    func fetchUnifiedIngredientCatalogSummary() async -> [UnifiedIngredientCatalogSummaryRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_UNIFIED] phase=catalog_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_catalog_summary")
                .select()
                .execute()

            let rows = try JSONDecoder().decode([CloudUnifiedIngredientCatalogSummaryRow].self, from: response.data)
            let records = rows.map { row in
                UnifiedIngredientCatalogSummaryRecord(
                    ingredientID: row.ingredient_id.trimmingCharacters(in: .whitespacesAndNewlines),
                    slug: row.slug.trimmingCharacters(in: .whitespacesAndNewlines),
                    ingredientType: row.ingredient_type.trimmingCharacters(in: .whitespacesAndNewlines),
                    enName: row.en_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                    itName: row.it_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                    legacyProduceID: row.legacy_produce_id?.trimmingCharacters(in: .whitespacesAndNewlines),
                    legacyBasicID: row.legacy_basic_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            print("[SEASON_UNIFIED] phase=catalog_fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingUnifiedIngredientSummaryRelationError(error) {
                print("[SEASON_UNIFIED] phase=catalog_fetch_failed reason=relation_missing error=\(error)")
                return []
            }
            print("[SEASON_UNIFIED] phase=catalog_fetch_failed error=\(error)")
            return []
        }
    }

    func fetchUnifiedIngredientAliases() async -> [UnifiedIngredientAliasRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let response = try await supabaseClient
                .from("ingredient_aliases_v2")
                .select()
                .eq("is_active", value: true)
                .execute()

            let rows = try JSONDecoder().decode([CloudUnifiedIngredientAliasRow].self, from: response.data)
            let records = rows.compactMap { row -> UnifiedIngredientAliasRecord? in
                let ingredientID = row.ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let normalized = row.normalized_alias_text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""
                guard !ingredientID.isEmpty, !normalized.isEmpty else { return nil }

                let aliasText = row.alias_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? normalized
                let sourceValue = row.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return UnifiedIngredientAliasRecord(
                    ingredientID: ingredientID,
                    aliasText: aliasText,
                    normalizedAliasText: normalized,
                    languageCode: row.language_code?.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: sourceValue.isEmpty ? "manual" : sourceValue,
                    confidence: row.confidence,
                    isActive: row.is_active ?? true
                )
            }
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_ok count=\(records.count)")
            return records
        } catch {
            if isMissingUnifiedIngredientAliasesRelationError(error) {
                print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed reason=relation_missing error=\(error)")
                return []
            }
            print("[SEASON_UNIFIED] phase=alias_v2_fetch_failed error=\(error)")
            return []
        }
    }

    func observeCustomIngredientObservations(_ observations: [CustomIngredientObservation]) async {
        guard !observations.isEmpty else { return }
        guard let supabaseClient = self.client else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_failed reason=missing_configuration count=\(observations.count)")
            return
        }
        guard supabaseClient.auth.currentUser != nil else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_skipped reason=unauthenticated count=\(observations.count)")
            return
        }

        for observation in observations {
            print("[SEASON_CUSTOM_INGREDIENT] phase=observed normalized_text=\(observation.normalizedText) source=\(observation.source)")
            var params: [String: String] = [
                "p_normalized_text": observation.normalizedText,
                "p_raw_example": observation.rawExample,
                "p_source": observation.source
            ]
            if let languageCode = observation.languageCode, !languageCode.isEmpty {
                params["p_language_code"] = languageCode
            }
            if let latestRecipeID = observation.latestRecipeID, !latestRecipeID.isEmpty {
                params["p_latest_recipe_id"] = latestRecipeID
            }

            do {
                _ = try await supabaseClient
                    .rpc("observe_custom_ingredient", params: params)
                    .execute()
                print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_succeeded normalized_text=\(observation.normalizedText)")
            } catch {
                print("[SEASON_CUSTOM_INGREDIENT] phase=upsert_failed normalized_text=\(observation.normalizedText) error=\(error)")
            }
        }
    }

    func fetchCustomIngredientObservationInsights(limit: Int = 50) async -> [CustomIngredientObservationInsightRecord] {
        guard let supabaseClient = self.client else {
            print("[SEASON_CUSTOM_INGREDIENT] phase=insights_fetch_failed reason=missing_configuration")
            return []
        }

        do {
            let params: [String: AnyJSON] = [
                "limit_count": .integer(max(1, limit)),
                "only_status_new": .bool(true),
                "sort_mode": .string("priority")
            ]
            let response = try await supabaseClient
                .rpc("custom_ingredient_observation_insights", params: params)
                .execute()

            let rows = try JSONDecoder().decode([CloudCustomIngredientObservationInsightRow].self, from: response.data)
            let records = rows.compactMap { row -> CustomIngredientObservationInsightRecord? in
                let normalizedText = row.normalized_text?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !normalizedText.isEmpty else { return nil }
                return CustomIngredientObservationInsightRecord(
                    normalizedText: normalizedText,
                    occurrenceCount: max(0, row.occurrence_count ?? 0),
                    exampleCount: max(0, row.example_count ?? 0),
                    latestExample: row.latest_example?.trimmingCharacters(in: .whitespacesAndNewlines),
                    languageCode: row.language_code?.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: row.source?.trimmingCharacters(in: .whitespacesAndNewlines),
                    priorityScore: row.priority_score ?? 0
                )
            }
            print("[SEASON_CUSTOM_INGREDIENT] phase=insights_fetch_ok count=\(records.count)")
            return records
        } catch {
            print("[SEASON_CUSTOM_INGREDIENT] phase=insights_fetch_failed error=\(error)")
            return []
        }
    }

    func createRecipe(_ recipe: Recipe) async throws {
        try await instrumentedRequest(name: "createRecipe", metadata: "recipe_id=\(recipe.id)") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                throw SupabaseServiceError.unauthenticated
            }

            let payload = RecipeInsertPayload(
                id: recipe.id,
                user_id: user.id.uuidString,
                creator_id: recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : recipe.creatorId,
                creator_display_name: recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                title: recipe.title,
                ingredients: recipe.ingredients.map {
                    RecipeIngredientInsertPayload(
                        produce_id: $0.produceID,
                        basic_ingredient_id: $0.basicIngredientID,
                        name: $0.name,
                        quantity_value: $0.quantityValue,
                        quantity_unit: $0.quantityUnit.rawValue
                    )
                },
                steps: recipe.preparationSteps,
                servings: recipe.servings,
                image_url: recipe.imageURL,
                instagram_url: recipe.instagramURL,
                tiktok_url: recipe.tiktokURL,
                created_at: ISO8601DateFormatter().string(from: recipe.createdAt)
            )

            do {
                _ = try await supabaseClient
                    .from("recipes")
                    .insert(payload)
                    .execute()
            } catch {
                if self.isMissingColumnError(error, column: "image_url")
                    || self.isMissingColumnError(error, column: "creator_id")
                    || self.isMissingColumnError(error, column: "creator_display_name") {
                    let fallbackPayload = RecipeInsertPayloadWithoutImageURL(
                        id: recipe.id,
                        user_id: user.id.uuidString,
                        creator_id: recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : recipe.creatorId,
                        creator_display_name: recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                        title: recipe.title,
                        ingredients: recipe.ingredients.map {
                            RecipeIngredientInsertPayload(
                                produce_id: $0.produceID,
                                basic_ingredient_id: $0.basicIngredientID,
                                name: $0.name,
                                quantity_value: $0.quantityValue,
                                quantity_unit: $0.quantityUnit.rawValue
                            )
                        },
                        steps: recipe.preparationSteps,
                        servings: recipe.servings,
                        instagram_url: recipe.instagramURL,
                        tiktok_url: recipe.tiktokURL,
                        created_at: ISO8601DateFormatter().string(from: recipe.createdAt)
                    )
                    _ = try await supabaseClient
                        .from("recipes")
                        .insert(fallbackPayload)
                        .execute()
                } else {
                    throw error
                }
            }
        }
    }

    func fetchRecipes() async throws -> [Recipe] {
        try await instrumentedRequest(name: "fetchRecipes") {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            let response = try await supabaseClient
                .from("recipes")
                .select()
                .execute()

            let rows = try JSONDecoder().decode([CloudRecipeRow].self, from: response.data)
            let iso8601 = ISO8601DateFormatter()

            return rows.map { row in
                let mappedIngredients: [RecipeIngredient] = (row.ingredients ?? []).map { ingredient in
                    let unit = RecipeQuantityUnit(rawValue: ingredient.quantity_unit ?? "") ?? .g
                    let produceID = ingredient.produce_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let basicID = ingredient.basic_ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallbackName = ingredient.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedName = (fallbackName?.isEmpty == false)
                        ? fallbackName!
                        : (produceID?.isEmpty == false ? produceID! : (basicID?.isEmpty == false ? basicID! : "Ingredient"))
                    let quality: RecipeIngredientQuality = (produceID?.isEmpty == false) ? .coreSeasonal : .basic

                    return RecipeIngredient(
                        produceID: (produceID?.isEmpty == false) ? produceID : nil,
                        basicIngredientID: (basicID?.isEmpty == false) ? basicID : nil,
                        quality: quality,
                        name: resolvedName,
                        quantityValue: max(0.1, ingredient.quantity_value ?? 1),
                        quantityUnit: unit
                    )
                }

                let createdAt = row.created_at.flatMap { iso8601.date(from: $0) } ?? Date()
                let trimmedTitle = row.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let safeTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : "Untitled recipe"
                let trimmedCreatorDisplayName = row.creator_display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let trimmedCreatorAvatarURL = row.creator_avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let legacyAvatarURL = row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // Canonical identity is creator_id + creator_display_name.
                // Keep author populated only as a legacy compatibility fallback for older author-based screens.
                let safeAuthorName = trimmedCreatorDisplayName.isEmpty ? "Unknown" : trimmedCreatorDisplayName

                var recipe = Recipe(
                    id: row.id,
                    title: safeTitle,
                    author: safeAuthorName,
                    creatorId: row.creator_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown",
                    creatorDisplayName: trimmedCreatorDisplayName.isEmpty ? nil : trimmedCreatorDisplayName,
                    creatorAvatarURL: {
                        if !trimmedCreatorAvatarURL.isEmpty { return trimmedCreatorAvatarURL }
                        if !legacyAvatarURL.isEmpty { return legacyAvatarURL }
                        return nil
                    }(),
                    ingredients: mappedIngredients,
                    preparationSteps: (row.steps ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                    prepTimeMinutes: nil,
                    cookTimeMinutes: nil,
                    difficulty: nil,
                    servings: max(1, row.servings ?? 2),
                    crispy: 0,
                    dietaryTags: [],
                    seasonalMatchPercent: 0,
                    createdAt: createdAt,
                    externalMedia: [],
                    images: [],
                    coverImageID: nil,
                    coverImageName: nil,
                    mediaLinkURL: nil,
                    instagramURL: row.instagram_url?.trimmingCharacters(in: .whitespacesAndNewlines),
                    tiktokURL: row.tiktok_url?.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceURL: nil,
                    sourcePlatform: nil,
                    sourceCaptionRaw: nil,
                    importedFromSocial: false,
                    sourceType: .userGenerated,
                    isUserGenerated: true,
                    publicationStatus: .published,
                    isRemix: false,
                    originalRecipeID: nil,
                    originalRecipeTitle: nil,
                    originalAuthorName: nil
                )
                recipe.imageURL = row.image_url?.trimmingCharacters(in: .whitespacesAndNewlines)
                let creatorIDForLog = recipe.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
                let creatorDisplayForLog = recipe.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                print("[SEASON_CREATOR_CHAIN] phase=recipe_identity source=supabase_fetch recipe_id=\(recipe.id) title=\(recipe.title) creator_id=\(creatorIDForLog.isEmpty ? "nil" : creatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(recipe.author)")
                return recipe
            }
        }
    }

    func setRecipeSavedState(recipeID: String, isSaved: Bool, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=service_entered")
        try await instrumentedRequest(
            name: "setRecipeSavedState",
            traceID: traceID,
            metadata: "action=saved recipe=\(recipeID) target=\(isSaved)"
        ) {
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
                print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=write_ok")
            } catch {
                let category = classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=saved recipe=\(recipeID) target=\(isSaved) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func setRecipeCrispiedState(recipeID: String, isCrispied: Bool, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=service_entered")
        try await instrumentedRequest(
            name: "setRecipeCrispiedState",
            traceID: traceID,
            metadata: "action=crispied recipe=\(recipeID) target=\(isCrispied)"
        ) {
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
                print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=write_ok")
            } catch {
                let category = classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=crispied recipe=\(recipeID) target=\(isCrispied) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func createShoppingListItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?,
        isChecked: Bool,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "createShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_create item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let payload = ShoppingListItemInsertPayload(
                id: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString),
                user_id: user.id.uuidString,
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                source_recipe_id: sourceRecipeID,
                is_checked: isChecked,
                created_at: now,
                updated_at: now
            )

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .insert(payload)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func updateShoppingListItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?,
        isChecked: Bool,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "updateShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_update item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let payload = ShoppingListItemUpdatePayload(
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                source_recipe_id: sourceRecipeID,
                is_checked: isChecked,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .update(payload)
                    .eq("id", value: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func deleteShoppingListItem(localItemID: String, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "deleteShoppingListItem",
            traceID: traceID,
            metadata: "action=shopping_list_delete item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            do {
                _ = try await supabaseClient
                    .from("shopping_list_items")
                    .delete()
                    .eq("id", value: self.shoppingListRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func createFridgeItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "createFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_create item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let payload = FridgeItemInsertPayload(
                id: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString),
                user_id: user.id.uuidString,
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                created_at: now,
                updated_at: now
            )

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .insert(payload)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_ok")
            } catch {
                if self.isDuplicateKeyPostgresError(error) {
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=duplicate_detected error=\(error)")
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=duplicate_fallback_update")

                    let fallbackPayload = FridgeItemUpdatePayload(
                        ingredient_type: ingredientType,
                        ingredient_id: ingredientID,
                        custom_name: customName,
                        quantity: quantity,
                        unit: unit,
                        updated_at: now
                    )

                    do {
                        _ = try await supabaseClient
                            .from("fridge_items")
                            .update(fallbackPayload)
                            .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                            .eq("user_id", value: user.id.uuidString)
                            .execute()
                        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_ok")
                    } catch {
                        let category = self.classifyNetworkError(error)
                        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                        throw error
                    }
                } else {
                    let category = self.classifyNetworkError(error)
                    print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                    throw error
                }
            }
        }
    }

    func updateFridgeItem(
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        traceID: String
    ) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "updateFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_update item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            let payload = FridgeItemUpdatePayload(
                ingredient_type: ingredientType,
                ingredient_id: ingredientID,
                custom_name: customName,
                quantity: quantity,
                unit: unit,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .update(payload)
                    .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_update item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    func deleteFridgeItem(localItemID: String, traceID: String) async throws {
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=service_entered")
        try await instrumentedRequest(
            name: "deleteFridgeItem",
            traceID: traceID,
            metadata: "action=fridge_delete item=\(localItemID)"
        ) {
            guard let supabaseClient = self.client else {
                throw SupabaseServiceError.missingConfiguration(self.configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
            }

            guard let user = supabaseClient.auth.currentUser else {
                return
            }

            do {
                _ = try await supabaseClient
                    .from("fridge_items")
                    .delete()
                    .eq("id", value: self.fridgeRowID(localItemID: localItemID, userID: user.id.uuidString))
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=write_ok")
            } catch {
                let category = self.classifyNetworkError(error)
                print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=write_failed category=\(category.rawValue) error=\(error)")
                throw error
            }
        }
    }

    private func instrumentedRequest<T>(
        name: String,
        traceID: String? = nil,
        metadata: String? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let tracePart = traceID.map { " trace=\($0)" } ?? ""
        let metadataPart = metadata.map { " \($0)" } ?? ""
        print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_started")

        do {
            let result = try await operation()
            let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1000).rounded())
            print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_ok duration_ms=\(elapsedMs)")
            return result
        } catch {
            let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1000).rounded())
            let category = classifyNetworkError(error)
            print("[SEASON_SUPABASE] request=\(name)\(tracePart)\(metadataPart) phase=request_failed duration_ms=\(elapsedMs) category=\(category.rawValue) error=\(error)")
            throw error
        }
    }

    private func performWithRetry(
        operation: () async throws -> Void
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

    private func classifyNetworkError(_ error: Error) -> NetworkErrorCategory {
        if let serviceError = error as? SupabaseServiceError {
            switch serviceError {
            case .unauthenticated:
                return .auth_session
            case .missingConfiguration, .invalidURL:
                return .client_validation
            case .requestTimedOut:
                return .network_offline
            }
        }

        if error is DecodingError || error is EncodingError {
            return .client_validation
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case -1009, -1005, -1001:
                return .network_offline
            default:
                break
            }
        }

        if let statusCode = extractHTTPStatusCode(from: nsError) {
            switch statusCode {
            case 401:
                return .auth_session
            case 403:
                return .permission_rls
            case 429:
                return .rate_limit
            case 500...599:
                return .server_error
            case 400...499:
                return .client_validation
            default:
                break
            }
        }

        let message = [
            nsError.localizedDescription,
            String(describing: error)
        ]
        .joined(separator: " ")
        .lowercased()

        if message.contains("rls") ||
            message.contains("permission denied") ||
            message.contains("forbidden") {
            return .permission_rls
        }
        if message.contains("unauthorized") ||
            message.contains("jwt") ||
            message.contains("session") ||
            message.contains("not authenticated") {
            return .auth_session
        }
        if message.contains("rate limit") ||
            message.contains("too many requests") {
            return .rate_limit
        }
        if message.contains("offline") ||
            message.contains("timed out") ||
            message.contains("timeout") ||
            message.contains("connection lost") {
            return .network_offline
        }
        if message.contains("decode") ||
            message.contains("encoding") ||
            message.contains("invalid") ||
            message.contains("missing") {
            return .client_validation
        }

        return .unknown
    }

    private func extractHTTPStatusCode(from error: NSError) -> Int? {
        let keys = ["status", "statusCode", "StatusCode", "code"]
        for key in keys {
            if let value = error.userInfo[key] as? Int, (100...599).contains(value) {
                return value
            }
            if let value = error.userInfo[key] as? NSNumber {
                let intValue = value.intValue
                if (100...599).contains(intValue) {
                    return intValue
                }
            }
            if let value = error.userInfo[key] as? String, let intValue = Int(value), (100...599).contains(intValue) {
                return intValue
            }
        }

        if let response = error.userInfo["response"] as? HTTPURLResponse {
            return response.statusCode
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return extractHTTPStatusCode(from: underlying)
        }

        return nil
    }

    private func isDuplicateKeyPostgresError(_ error: Error) -> Bool {
        if let code = extractPostgresErrorCode(from: error), code == "23505" {
            return true
        }

        let message = String(describing: error).lowercased()
        return message.contains("23505") &&
            message.contains("duplicate key")
    }

    private func extractPostgresErrorCode(from error: Error) -> String? {
        let nsError = error as NSError
        let keys = ["code", "sqlState", "sqlstate", "postgresCode", "PostgresCode", "pgcode"]

        for key in keys {
            if let value = nsError.userInfo[key] as? String, !value.isEmpty {
                return value
            }
            if let value = nsError.userInfo[key] as? NSNumber {
                return value.stringValue
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return extractPostgresErrorCode(from: underlying)
        }

        return nil
    }

    private func isMissingColumnError(_ error: Error, column: String) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("pgrst204") || (message.contains(column.lowercased()) && message.contains("column"))
    }

    private func isMissingFollowsTableError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("follows") &&
            message.contains("does not exist")
    }

    private func isMissingIngredientAliasesTableError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_aliases") &&
            message.contains("does not exist")
    }

    private func isMissingUnifiedIngredientSummaryRelationError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_catalog_summary") &&
            message.contains("does not exist")
    }

    private func isMissingUnifiedIngredientAliasesRelationError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("relation") &&
            message.contains("ingredient_aliases_v2") &&
            message.contains("does not exist")
    }

    private func normalizeFollowID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func shoppingListRowID(localItemID: String, userID: String) -> String {
        deterministicUUIDString(from: "shopping_list_item|\(userID)|\(localItemID)")
    }

    private func fridgeRowID(localItemID: String, userID: String) -> String {
        deterministicUUIDString(from: "fridge_item|\(userID)|\(localItemID)")
    }

    private func deterministicUUIDString(from input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple).uuidString.lowercased()
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
