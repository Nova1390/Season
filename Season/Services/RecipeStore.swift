import Foundation

enum RecipeStore {
    private static var cachedRecipes: [Recipe]?
    private static let cacheLock = NSLock()
    private static let userRecipesStorageKey = "userCreatedRecipesData"
    private static let seededCreatorRegistry: [String: UserProfile] = [
        "anna": UserProfile(id: "9f4f9247-7efc-4d2d-b183-2b50fdbec564", name: "Anna"),
        "marco": UserProfile(id: "2c6d6876-2f6c-4290-8d13-5cb7e1f3a24e", name: "Marco"),
        "sofia": UserProfile(id: "5be98b2e-0ba9-4ce3-8f55-f6f021db5f35", name: "Sofia"),
        "luca": UserProfile(id: "6d04d393-35f8-4ec2-8bd2-e4d198ecdd0f", name: "Luca")
    ]

    static func loadProfiles() -> [UserProfile] {
        Array(seededCreatorRegistry.values).sorted { $0.name < $1.name }
    }

    static func localOnlyCreatorIDs() -> Set<String> {
        Set(
            seededCreatorRegistry.values.map {
                $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )
    }

    static func loadRecipes() -> [Recipe] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedRecipes {
            return cachedRecipes
        }

        #if false
        let curated: [Recipe] = [
            Recipe(
                id: "recipe_1",
                title: "Spring Green Bowl",
                author: "Anna",
                ingredients: [
                    RecipeIngredient(produceID: "spinach", basicIngredientID: nil, quality: .coreSeasonal, name: "Spinach", quantityValue: 120, quantityUnit: .g),
                    RecipeIngredient(produceID: "peas", basicIngredientID: nil, quality: .coreSeasonal, name: "Peas", quantityValue: 100, quantityUnit: .g),
                    RecipeIngredient(produceID: "lemon", basicIngredientID: nil, quality: .coreSeasonal, name: "Lemon", quantityValue: 0.5, quantityUnit: .piece),
                    RecipeIngredient(produceID: nil, basicIngredientID: "olive_oil", quality: .basic, name: "Olive oil", quantityValue: 10, quantityUnit: .g),
                    RecipeIngredient(produceID: nil, basicIngredientID: "parmesan", quality: .basic, name: "Parmesan", quantityValue: 15, quantityUnit: .g)
                ],
                preparationSteps: [
                    "Wash spinach and blanch peas for 2 minutes.",
                    "Mix spinach and peas in a bowl.",
                    "Dress with lemon juice, olive oil, and a pinch of salt."
                ],
                prepTimeMinutes: 10,
                cookTimeMinutes: 2,
                difficulty: .easy,
                crispy: 128,
                dietaryTags: [.vegetarian, .glutenFree],
                seasonalMatchPercent: 88,
                createdAt: daysAgo(2),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "spinach",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            ),
            Recipe(
                id: "recipe_2",
                title: "Citrus Crunch Salad",
                author: "Marco",
                ingredients: [
                    RecipeIngredient(produceID: "orange", basicIngredientID: nil, quality: .coreSeasonal, name: "Orange", quantityValue: 1, quantityUnit: .piece),
                    RecipeIngredient(produceID: "lettuce", basicIngredientID: nil, quality: .coreSeasonal, name: "Lettuce", quantityValue: 150, quantityUnit: .g),
                    RecipeIngredient(produceID: "carrot", basicIngredientID: nil, quality: .coreSeasonal, name: "Carrot", quantityValue: 1, quantityUnit: .piece),
                    RecipeIngredient(produceID: nil, basicIngredientID: "olive_oil", quality: .basic, name: "Olive oil", quantityValue: 8, quantityUnit: .g),
                    RecipeIngredient(produceID: "garlic", basicIngredientID: nil, quality: .coreSeasonal, name: "Garlic", quantityValue: 2, quantityUnit: .clove)
                ],
                preparationSteps: [
                    "Slice orange into thin rounds.",
                    "Chop lettuce and grate carrot.",
                    "Combine all ingredients and add a light vinaigrette."
                ],
                prepTimeMinutes: 12,
                cookTimeMinutes: nil,
                difficulty: .easy,
                crispy: 92,
                dietaryTags: [.vegetarian, .glutenFree, .vegan],
                seasonalMatchPercent: 76,
                createdAt: daysAgo(5),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "orange",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            ),
            Recipe(
                id: "recipe_3",
                title: "Roasted Root Mix",
                author: "Sofia",
                ingredients: [
                    RecipeIngredient(produceID: "potato", basicIngredientID: nil, quality: .coreSeasonal, name: "Potato", quantityValue: 250, quantityUnit: .g),
                    RecipeIngredient(produceID: "sweet_potato", basicIngredientID: nil, quality: .coreSeasonal, name: "Sweet potato", quantityValue: 200, quantityUnit: .g),
                    RecipeIngredient(produceID: "onion", basicIngredientID: nil, quality: .coreSeasonal, name: "Onion", quantityValue: 1, quantityUnit: .piece),
                    RecipeIngredient(produceID: nil, basicIngredientID: "olive_oil", quality: .basic, name: "Olive oil", quantityValue: 1, quantityUnit: .tbsp),
                    RecipeIngredient(produceID: "garlic", basicIngredientID: nil, quality: .coreSeasonal, name: "Garlic", quantityValue: 2, quantityUnit: .clove)
                ],
                preparationSteps: [
                    "Cut potatoes and onion into bite-sized pieces.",
                    "Toss with olive oil, rosemary, salt, and pepper.",
                    "Roast at 200 C for about 30 minutes, turning once."
                ],
                prepTimeMinutes: 15,
                cookTimeMinutes: 30,
                difficulty: .medium,
                crispy: 84,
                dietaryTags: [.vegetarian, .vegan, .glutenFree],
                seasonalMatchPercent: 72,
                createdAt: daysAgo(9),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "sweet_potato",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            ),
            Recipe(
                id: "recipe_4",
                title: "Berry Morning Cup",
                author: "Luca",
                ingredients: [
                    RecipeIngredient(produceID: "strawberry", basicIngredientID: nil, quality: .coreSeasonal, name: "Strawberry", quantityValue: 120, quantityUnit: .g),
                    RecipeIngredient(produceID: "blueberry", basicIngredientID: nil, quality: .coreSeasonal, name: "Blueberry", quantityValue: 80, quantityUnit: .g),
                    RecipeIngredient(produceID: "raspberry", basicIngredientID: nil, quality: .coreSeasonal, name: "Raspberry", quantityValue: 60, quantityUnit: .g),
                    RecipeIngredient(produceID: nil, basicIngredientID: "milk", quality: .basic, name: "Milk", quantityValue: 120, quantityUnit: .ml)
                ],
                preparationSteps: [
                    "Rinse all berries carefully.",
                    "Layer strawberries, blueberries, and raspberries in a cup.",
                    "Serve fresh with yogurt or oats if preferred."
                ],
                prepTimeMinutes: 8,
                cookTimeMinutes: nil,
                difficulty: .easy,
                crispy: 146,
                dietaryTags: [.vegetarian, .glutenFree],
                seasonalMatchPercent: 91,
                createdAt: daysAgo(1),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "strawberry",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            ),
            Recipe(
                id: "recipe_5",
                title: "Tomato Herb Plate",
                author: "Anna",
                ingredients: [
                    RecipeIngredient(produceID: "tomato", basicIngredientID: nil, quality: .coreSeasonal, name: "Tomato", quantityValue: 2, quantityUnit: .piece),
                    RecipeIngredient(produceID: "zucchini", basicIngredientID: nil, quality: .coreSeasonal, name: "Zucchini", quantityValue: 1, quantityUnit: .piece),
                    RecipeIngredient(produceID: "onion", basicIngredientID: nil, quality: .coreSeasonal, name: "Onion", quantityValue: 0.5, quantityUnit: .piece),
                    RecipeIngredient(produceID: nil, basicIngredientID: "olive_oil", quality: .basic, name: "Olive oil", quantityValue: 10, quantityUnit: .g)
                ],
                preparationSteps: [
                    "Slice tomato, zucchini, and onion very thinly.",
                    "Arrange on a plate and season with olive oil and herbs.",
                    "Let rest for 5 minutes before serving."
                ],
                prepTimeMinutes: 12,
                cookTimeMinutes: nil,
                difficulty: .easy,
                crispy: 75,
                dietaryTags: [.vegetarian, .vegan, .glutenFree],
                seasonalMatchPercent: 68,
                createdAt: daysAgo(4),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "tomato",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            ),
            Recipe(
                id: "recipe_6",
                title: "Golden Veg Soup",
                author: "Marco",
                ingredients: [
                    RecipeIngredient(produceID: "pumpkin", basicIngredientID: nil, quality: .coreSeasonal, name: "Pumpkin", quantityValue: 300, quantityUnit: .g),
                    RecipeIngredient(produceID: "carrot", basicIngredientID: nil, quality: .coreSeasonal, name: "Carrot", quantityValue: 2, quantityUnit: .piece),
                    RecipeIngredient(produceID: "potato", basicIngredientID: nil, quality: .coreSeasonal, name: "Potato", quantityValue: 1, quantityUnit: .piece),
                    RecipeIngredient(produceID: "onion", basicIngredientID: nil, quality: .coreSeasonal, name: "Onion", quantityValue: 80, quantityUnit: .g),
                    RecipeIngredient(produceID: nil, basicIngredientID: "butter", quality: .basic, name: "Butter", quantityValue: 8, quantityUnit: .g)
                ],
                preparationSteps: [
                    "Peel and cube all vegetables.",
                    "Simmer in vegetable stock for 25 minutes.",
                    "Blend until smooth and season to taste."
                ],
                prepTimeMinutes: 15,
                cookTimeMinutes: 25,
                difficulty: .medium,
                crispy: 110,
                dietaryTags: [.vegetarian, .glutenFree],
                seasonalMatchPercent: 82,
                createdAt: daysAgo(3),
                externalMedia: [],
                images: [],
                coverImageID: nil,
                coverImageName: "pumpkin",
                mediaLinkURL: nil,
                sourceURL: nil,
                sourcePlatform: nil,
                sourceCaptionRaw: nil,
                importedFromSocial: false,
                isRemix: false,
                originalRecipeID: nil,
                originalRecipeTitle: nil,
                originalAuthorName: nil
            )
        ]
        #endif

        let localUserRecipes = loadPersistedUserRecipes()
        let normalized = normalizeCreatorIdentity(in: localUserRecipes, profiles: loadProfiles())
        cachedRecipes = normalized
        return normalized
    }

    static func upsertUserRecipe(_ recipe: Recipe) {
        cacheLock.lock()
        var localUserRecipes = loadPersistedUserRecipes()
        if let existingIndex = localUserRecipes.firstIndex(where: { $0.id == recipe.id }) {
            localUserRecipes[existingIndex] = recipe
        } else {
            localUserRecipes.insert(recipe, at: 0)
        }
        persistUserRecipes(localUserRecipes)

        if var cached = cachedRecipes {
            if let existingIndex = cached.firstIndex(where: { $0.id == recipe.id }) {
                cached[existingIndex] = recipe
            } else {
                cached.insert(recipe, at: 0)
            }
            cachedRecipes = cached
        }
        cacheLock.unlock()
    }

    static func removeUserRecipe(id: String) {
        cacheLock.lock()
        var localUserRecipes = loadPersistedUserRecipes()
        localUserRecipes.removeAll { $0.id == id }
        persistUserRecipes(localUserRecipes)

        if var cached = cachedRecipes {
            cached.removeAll { $0.id == id }
            cachedRecipes = cached
        }
        cacheLock.unlock()
    }

    static func clearUserSessionData() {
        cacheLock.lock()
        cachedRecipes = nil
        UserDefaults.standard.removeObject(forKey: userRecipesStorageKey)
        cacheLock.unlock()
    }

    private static func loadPersistedUserRecipes() -> [Recipe] {
        guard let data = UserDefaults.standard.data(forKey: userRecipesStorageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
    }

    private static func persistUserRecipes(_ recipes: [Recipe]) {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: userRecipesStorageKey)
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func normalizeCreatorIdentity(in recipes: [Recipe], profiles: [UserProfile]) -> [Recipe] {
        let profileByName: [String: UserProfile] = Dictionary(
            uniqueKeysWithValues: profiles.map {
                ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0)
            }
        )

        return recipes.map { recipe in
            var updated = recipe
            let rawCreatorID = updated.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawCreatorIDLowercased = rawCreatorID.lowercased()

            if updated.canonicalCreatorID == nil {
                if SeasonLog.verbose {
                    if !rawCreatorID.isEmpty && rawCreatorIDLowercased != "unknown" {
                        SeasonLog.debug("[SEASON_CREATOR_MIGRATION] phase=legacy_creator_found recipe_id=\(updated.id) raw_creator_id=\(rawCreatorID)")
                    }
                }

                let normalizedAuthor = updated.author.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let profile = profileByName[normalizedAuthor] {
                    let canonicalCreatorID = profile.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    updated.creatorId = canonicalCreatorID
                    if (updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                        updated.creatorDisplayName = profile.name
                    }
                    if SeasonLog.verbose {
                        let displayNameForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? profile.name
                        SeasonLog.debug("[SEASON_CREATOR_MIGRATION] phase=seed_creator_registry_used recipe_id=\(updated.id) creator_id=\(canonicalCreatorID)")
                        SeasonLog.debug("[SEASON_CREATOR_MIGRATION] phase=creator_uuid_mapped recipe_id=\(updated.id) creator_id=\(canonicalCreatorID) display_name=\(displayNameForLog)")
                    }
                }
            }

            if SeasonLog.verbose, updated.canonicalCreatorID == nil {
                let displayNameForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.author.trimmingCharacters(in: .whitespacesAndNewlines)
                if !displayNameForLog.isEmpty && displayNameForLog.lowercased() != "unknown" {
                    SeasonLog.debug("[SEASON_CREATOR_MIGRATION] phase=creator_uuid_missing recipe_id=\(updated.id) display_name=\(displayNameForLog)")
                }
            }

            if SeasonLog.verbose {
                let creatorIDForLog = updated.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
                let creatorDisplayForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                SeasonLog.debug("[SEASON_CREATOR_CHAIN] phase=recipe_identity source=recipe_store recipe_id=\(updated.id) title=\(updated.title) creator_id=\(creatorIDForLog.isEmpty ? "nil" : creatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(updated.author)")
            }

            if SeasonLog.verbose,
               (updated.isUserGenerated || updated.sourceType == .userGenerated),
               updated.canonicalCreatorID == nil {
                let creatorDisplayForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                SeasonLog.debug("[SEASON_CREATOR_CHAIN] phase=missing_canonical_creator_id recipe_id=\(updated.id) title=\(updated.title) creator_display_name=\(creatorDisplayForLog) author=\(updated.author)")
            }

            return updated
        }
    }
}
