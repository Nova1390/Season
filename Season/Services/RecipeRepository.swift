import Foundation
import Supabase

final class RecipeRepository {
    private let client: SupabaseClient?
    private let configurationIssue: String?
    private var cachedRecipeColumnCapabilities: RecipeOptionalColumnCapabilities?

    init(
        client: SupabaseClient?,
        configurationIssue: String?
    ) {
        self.client = client
        self.configurationIssue = configurationIssue
    }

    func createRecipe(_ recipe: Recipe) async throws {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let currentAuthUserID = supabaseClient.auth.currentUser?.id.uuidString.lowercased() ?? "nil"
        print("[SEASON_SUPABASE] phase=create_recipe_auth_context recipe_id=\(recipe.id) current_auth_user_id=\(currentAuthUserID)")
        guard let user = supabaseClient.auth.currentUser else {
            print("[SEASON_SUPABASE] phase=create_recipe_blocked recipe_id=\(recipe.id) reason=unauthenticated")
            throw SupabaseServiceError.unauthenticated
        }

        let publishUserID = user.id.uuidString.lowercased()
        let payloadHasUserID = !publishUserID.isEmpty
        print("[SEASON_SUPABASE] phase=create_recipe_payload_check recipe_id=\(recipe.id) payload_includes_user_id=\(payloadHasUserID) user_id=\(payloadHasUserID ? publishUserID : "nil")")

        let ingredientPayloads = recipe.ingredients.map {
            RecipeIngredientInsertPayload(
                ingredient_id: $0.ingredientID,
                produce_id: $0.produceID,
                basic_ingredient_id: $0.basicIngredientID,
                name: $0.name,
                quantity_value: $0.quantityValue,
                quantity_unit: $0.quantityUnit.rawValue
            )
        }
        let createdAt = ISO8601DateFormatter().string(from: recipe.createdAt)
        let capabilities = try await resolveRecipeOptionalColumnCapabilities(using: supabaseClient)

        if capabilities.supportsImageURL && capabilities.supportsSourceColumns {
            print("[SEASON_SUPABASE] phase=create_recipe_write_started recipe_id=\(recipe.id) path=full_schema")
            _ = try await supabaseClient
                .from("recipes")
                .upsert(
                    RecipeInsertPayload(
                        id: recipe.id,
                        user_id: publishUserID,
                        title: recipe.title,
                        ingredients: ingredientPayloads,
                        steps: recipe.preparationSteps,
                        servings: recipe.servings,
                        image_url: recipe.imageURL,
                        instagram_url: recipe.instagramURL,
                        tiktok_url: recipe.tiktokURL,
                        source_url: recipe.sourceURL,
                        source_name: recipe.sourceName,
                        source_type: recipe.sourceType?.rawValue,
                        created_at: createdAt
                    ),
                    onConflict: "id"
                )
                .execute()
            print("[SEASON_SUPABASE] phase=create_recipe_write_succeeded recipe_id=\(recipe.id) path=full_schema")
            return
        }

        if !capabilities.supportsImageURL && capabilities.supportsSourceColumns {
            print("[SEASON_SUPABASE] phase=create_recipe_write_started recipe_id=\(recipe.id) path=without_image_column")
            _ = try await supabaseClient
                .from("recipes")
                .upsert(
                    RecipeInsertPayloadWithoutImageURL(
                        id: recipe.id,
                        user_id: publishUserID,
                        title: recipe.title,
                        ingredients: ingredientPayloads,
                        steps: recipe.preparationSteps,
                        servings: recipe.servings,
                        instagram_url: recipe.instagramURL,
                        tiktok_url: recipe.tiktokURL,
                        source_url: recipe.sourceURL,
                        source_name: recipe.sourceName,
                        source_type: recipe.sourceType?.rawValue,
                        created_at: createdAt
                    ),
                    onConflict: "id"
                )
                .execute()
            print("[SEASON_SUPABASE] phase=create_recipe_write_succeeded recipe_id=\(recipe.id) path=without_image_column")
            return
        }

        if capabilities.supportsImageURL && !capabilities.supportsSourceColumns {
            print("[SEASON_SUPABASE] phase=create_recipe_write_started recipe_id=\(recipe.id) path=without_source_columns")
            _ = try await supabaseClient
                .from("recipes")
                .upsert(
                    RecipeInsertPayloadWithoutSourceColumns(
                        id: recipe.id,
                        user_id: publishUserID,
                        title: recipe.title,
                        ingredients: ingredientPayloads,
                        steps: recipe.preparationSteps,
                        servings: recipe.servings,
                        image_url: recipe.imageURL,
                        instagram_url: recipe.instagramURL,
                        tiktok_url: recipe.tiktokURL,
                        created_at: createdAt
                    ),
                    onConflict: "id"
                )
                .execute()
            print("[SEASON_SUPABASE] phase=create_recipe_write_succeeded recipe_id=\(recipe.id) path=without_source_columns")
            return
        }

        print("[SEASON_SUPABASE] phase=create_recipe_write_started recipe_id=\(recipe.id) path=legacy_columns_only")
        _ = try await supabaseClient
            .from("recipes")
            .upsert(
                RecipeInsertPayloadLegacyColumnsOnly(
                    id: recipe.id,
                    user_id: publishUserID,
                    title: recipe.title,
                    ingredients: ingredientPayloads,
                    steps: recipe.preparationSteps,
                    servings: recipe.servings,
                    instagram_url: recipe.instagramURL,
                    tiktok_url: recipe.tiktokURL,
                    created_at: createdAt
                ),
                onConflict: "id"
            )
            .execute()
        print("[SEASON_SUPABASE] phase=create_recipe_write_succeeded recipe_id=\(recipe.id) path=legacy_columns_only")
    }

    func fetchRecipes(limit: Int = 40, offset: Int = 0) async throws -> [Recipe] {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        let safeLimit = max(1, min(limit, 200))
        let safeOffset = max(0, offset)
        let rangeEnd = safeOffset + safeLimit - 1

        let response = try await supabaseClient
            .from("recipes")
            .select()
            .order("created_at", ascending: false)
            .order("id", ascending: false)
            .range(from: safeOffset, to: rangeEnd)
            .execute()

        let rows = try JSONDecoder().decode([CloudRecipeRow].self, from: response.data)
        let iso8601 = ISO8601DateFormatter()

        return rows.map { row in
            let mappedIngredients: [RecipeIngredient] = (row.ingredients ?? []).map { ingredient in
                let unit = RecipeQuantityUnit(rawValue: ingredient.quantity_unit ?? "") ?? .g
                let ingredientID = ingredient.ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                let produceID = ingredient.produce_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                let basicID = ingredient.basic_ingredient_id?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackName = ingredient.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = (fallbackName?.isEmpty == false)
                    ? fallbackName!
                    : (ingredientID?.isEmpty == false
                        ? ingredientID!
                        : (produceID?.isEmpty == false ? produceID! : (basicID?.isEmpty == false ? basicID! : "Ingredient")))
                let quality: RecipeIngredientQuality = (produceID?.isEmpty == false) ? .coreSeasonal : .basic

                return RecipeIngredient(
                    ingredientID: (ingredientID?.isEmpty == false) ? ingredientID?.lowercased() : nil,
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
                sourceURL: row.source_url?.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceName: row.source_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                sourceType: RecipeSourceType(rawValue: row.source_type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
                isUserGenerated: (RecipeSourceType(rawValue: row.source_type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? .userGenerated) == .userGenerated,
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

    func upsertRecipeSavedState(recipeID: String, isSaved: Bool) async throws {
        guard let supabaseClient = client else {
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

        _ = try await supabaseClient
            .from("user_recipe_states")
            .upsert(payload, onConflict: "user_id,recipe_id")
            .execute()
    }

    func upsertRecipeCrispiedState(recipeID: String, isCrispied: Bool) async throws {
        guard let supabaseClient = client else {
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

        _ = try await supabaseClient
            .from("user_recipe_states")
            .upsert(payload, onConflict: "user_id,recipe_id")
            .execute()
    }

    func fetchMyUserRecipeStates() async throws -> [CloudUserRecipeState] {
        guard let supabaseClient = client else {
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

    private func resolveRecipeOptionalColumnCapabilities(
        using supabaseClient: SupabaseClient
    ) async throws -> RecipeOptionalColumnCapabilities {
        if let cachedRecipeColumnCapabilities {
            return cachedRecipeColumnCapabilities
        }

        async let imageSupported = supportsRecipeColumn("image_url", using: supabaseClient)
        async let sourceURLSupported = supportsRecipeColumn("source_url", using: supabaseClient)
        async let sourceNameSupported = supportsRecipeColumn("source_name", using: supabaseClient)
        async let sourceTypeSupported = supportsRecipeColumn("source_type", using: supabaseClient)

        let capabilities = try await RecipeOptionalColumnCapabilities(
            supportsImageURL: imageSupported,
            supportsSourceURL: sourceURLSupported,
            supportsSourceName: sourceNameSupported,
            supportsSourceType: sourceTypeSupported
        )

        cachedRecipeColumnCapabilities = capabilities
        return capabilities
    }

    private func supportsRecipeColumn(
        _ column: String,
        using supabaseClient: SupabaseClient
    ) async throws -> Bool {
        do {
            _ = try await supabaseClient
                .from("recipes")
                .select("id,\(column)")
                .limit(1)
                .execute()
            return true
        } catch {
            if isMissingColumnProbeError(error) {
                return false
            }
            throw error
        }
    }

    private func isMissingColumnProbeError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if let code = postgrestErrorCode(from: nsError) {
            return code.uppercased() == "PGRST204"
        }
        return false
    }

    private func postgrestErrorCode(from error: NSError) -> String? {
        let keys = ["code", "Code", "postgrestCode", "postgrest_code"]
        for key in keys {
            if let value = error.userInfo[key] as? String, !value.isEmpty {
                return value
            }
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return postgrestErrorCode(from: underlying)
        }

        return nil
    }
}

private struct RecipeOptionalColumnCapabilities {
    let supportsImageURL: Bool
    let supportsSourceURL: Bool
    let supportsSourceName: Bool
    let supportsSourceType: Bool

    var supportsSourceColumns: Bool {
        supportsSourceURL && supportsSourceName && supportsSourceType
    }
}

private struct CloudRecipeIngredient: Codable {
    let ingredient_id: String?
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
    let source_url: String?
    let source_name: String?
    let source_type: String?
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

private struct RecipeIngredientInsertPayload: Encodable {
    let ingredient_id: String?
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
    let image_url: String?
    let instagram_url: String?
    let tiktok_url: String?
    let source_url: String?
    let source_name: String?
    let source_type: String?
    let created_at: String
}

private struct RecipeInsertPayloadWithoutImageURL: Encodable {
    let id: String
    let user_id: String
    let title: String
    let ingredients: [RecipeIngredientInsertPayload]
    let steps: [String]
    let servings: Int
    let instagram_url: String?
    let tiktok_url: String?
    let source_url: String?
    let source_name: String?
    let source_type: String?
    let created_at: String
}

private struct RecipeInsertPayloadWithoutSourceColumns: Encodable {
    let id: String
    let user_id: String
    let title: String
    let ingredients: [RecipeIngredientInsertPayload]
    let steps: [String]
    let servings: Int
    let image_url: String?
    let instagram_url: String?
    let tiktok_url: String?
    let created_at: String
}

private struct RecipeInsertPayloadLegacyColumnsOnly: Encodable {
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
