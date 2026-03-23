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
    let title: String?
    let ingredients: [CloudRecipeIngredient]?
    let steps: [String]?
    let servings: Int?
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
                .insert(payload)
                .execute()
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

                return Recipe(
                    id: row.id,
                    title: safeTitle,
                    author: "Season",
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
