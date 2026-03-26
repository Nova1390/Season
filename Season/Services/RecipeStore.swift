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

        let profiles = loadProfiles()
        let seedRecipes = loadSeedRecipesFromBundle()
        var seen = Set<String>()
        let localUserRecipes = loadPersistedUserRecipes()
        let merged = (localUserRecipes + curated + seedRecipes).filter { recipe in
            seen.insert(recipe.id).inserted
        }
        let normalized = normalizeCreatorIdentity(in: merged, profiles: profiles)
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

    private static func loadSeedRecipesFromBundle() -> [Recipe] {
        guard let url = Bundle.main.url(forResource: "seed_recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payloads = try? JSONDecoder().decode([SeedRecipePayload].self, from: data) else {
            return []
        }

        let normalizer = SeedRecipeImportNormalizer(
            produceByID: Dictionary(uniqueKeysWithValues: ProduceStore.loadFromBundle().map { ($0.id, $0) }),
            basicByID: Dictionary(uniqueKeysWithValues: BasicIngredientCatalog.all.map { ($0.id, $0) })
        )
        let iso8601 = ISO8601DateFormatter()
        return payloads.compactMap { payload in
            let createdAt = iso8601.date(from: payload.createdAtISO8601) ?? Date()
            let sourcePlatform = SocialSourcePlatform(rawValue: payload.sourcePlatform ?? "")
            let sourceType = RecipeSourceType(rawValue: payload.sourceType) ?? .seedWeb
            let dietaryTags = payload.dietaryTags.compactMap(RecipeDietaryTag.init(rawValue:))

            let ingredients = payload.ingredients.map { ingredient in
                normalizer.normalizedSeedIngredient(from: ingredient)
            }

            let images = payload.images.map { RecipeImage(id: $0.id, localPath: $0.localPath, remoteURL: $0.remoteURL) }
            let coverImageID = images.contains(where: { $0.id == payload.coverImageID }) ? payload.coverImageID : images.first?.id

            let servings = normalizer.normalizedServings(
                payload.servings,
                ingredientsCount: ingredients.count,
                prepTimeMinutes: payload.prepTimeMinutes,
                cookTimeMinutes: payload.cookTimeMinutes
            )

            return Recipe(
                id: payload.id,
                title: payload.title,
                author: payload.author,
                creatorId: payload.creatorID ?? "unknown",
                creatorDisplayName: payload.creatorDisplayName,
                ingredients: ingredients,
                preparationSteps: payload.preparationSteps,
                prepTimeMinutes: payload.prepTimeMinutes,
                cookTimeMinutes: payload.cookTimeMinutes,
                difficulty: payload.difficulty.flatMap(RecipeDifficulty.init(rawValue:)),
                servings: servings,
                crispy: payload.crispy,
                dietaryTags: dietaryTags,
                seasonalMatchPercent: payload.seasonalMatchPercent,
                createdAt: createdAt,
                externalMedia: [],
                images: images,
                coverImageID: coverImageID,
                coverImageName: payload.coverImageName,
                mediaLinkURL: payload.mediaLinkURL,
                sourceURL: payload.sourceURL,
                sourceName: payload.sourceName,
                sourcePlatform: sourcePlatform,
                sourceCaptionRaw: payload.sourceCaptionRaw,
                importedFromSocial: payload.importedFromSocial,
                sourceType: sourceType,
                isUserGenerated: payload.isUserGenerated,
                imageURL: payload.imageURL,
                imageSource: payload.imageSource,
                attributionText: payload.attributionText,
                isRemix: payload.isRemix,
                originalRecipeID: payload.originalRecipeID,
                originalRecipeTitle: payload.originalRecipeTitle,
                originalAuthorName: payload.originalAuthorName
            )
        }
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
                if !rawCreatorID.isEmpty && rawCreatorIDLowercased != "unknown" {
                    print("[SEASON_CREATOR_MIGRATION] phase=legacy_creator_found recipe_id=\(updated.id) raw_creator_id=\(rawCreatorID)")
                }

                let normalizedAuthor = updated.author.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let profile = profileByName[normalizedAuthor] {
                    let canonicalCreatorID = profile.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    updated.creatorId = canonicalCreatorID
                    if (updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                        updated.creatorDisplayName = profile.name
                    }
                    let displayNameForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? profile.name
                    print("[SEASON_CREATOR_MIGRATION] phase=seed_creator_registry_used recipe_id=\(updated.id) creator_id=\(canonicalCreatorID)")
                    print("[SEASON_CREATOR_MIGRATION] phase=creator_uuid_mapped recipe_id=\(updated.id) creator_id=\(canonicalCreatorID) display_name=\(displayNameForLog)")
                }
            }

            if updated.canonicalCreatorID == nil {
                let displayNameForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.author.trimmingCharacters(in: .whitespacesAndNewlines)
                if !displayNameForLog.isEmpty && displayNameForLog.lowercased() != "unknown" {
                    print("[SEASON_CREATOR_MIGRATION] phase=creator_uuid_missing recipe_id=\(updated.id) display_name=\(displayNameForLog)")
                }
            }

            let creatorIDForLog = updated.creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
            let creatorDisplayForLog = updated.creatorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
            print("[SEASON_CREATOR_CHAIN] phase=recipe_identity source=recipe_store recipe_id=\(updated.id) title=\(updated.title) creator_id=\(creatorIDForLog.isEmpty ? "nil" : creatorIDForLog) creator_display_name=\(creatorDisplayForLog) author=\(updated.author)")

            if (updated.isUserGenerated || updated.sourceType == .userGenerated),
               updated.canonicalCreatorID == nil {
                print("[SEASON_CREATOR_CHAIN] phase=missing_canonical_creator_id recipe_id=\(updated.id) title=\(updated.title) creator_display_name=\(creatorDisplayForLog) author=\(updated.author)")
            }

            return updated
        }
    }
}

private struct SeedRecipePayload: Codable {
    let id: String
    let title: String
    let author: String
    let creatorID: String?
    let creatorDisplayName: String?
    let ingredients: [SeedIngredientPayload]
    let preparationSteps: [String]
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let servings: Int?
    let difficulty: String?
    let crispy: Int
    let dietaryTags: [String]
    let seasonalMatchPercent: Int
    let createdAtISO8601: String
    let images: [SeedRecipeImagePayload]
    let coverImageID: String?
    let coverImageName: String?
    let mediaLinkURL: String?
    let sourceURL: String?
    let sourceName: String?
    let sourcePlatform: String?
    let sourceCaptionRaw: String?
    let importedFromSocial: Bool
    let sourceType: String
    let isUserGenerated: Bool
    let imageURL: String?
    let imageSource: String?
    let attributionText: String?
    let isRemix: Bool
    let originalRecipeID: String?
    let originalRecipeTitle: String?
    let originalAuthorName: String?
}

private struct SeedIngredientPayload: Codable {
    let produceID: String?
    let basicIngredientID: String?
    let quality: String
    let name: String
    let quantityValue: Double
    let quantityUnit: String
    let rawIngredientLine: String?
    let mappingConfidence: String
}

private struct SeedRecipeImagePayload: Codable {
    let id: String
    let localPath: String?
    let remoteURL: String?
}

private struct SeedRecipeImportNormalizer {
    let produceByID: [String: ProduceItem]
    let basicByID: [String: BasicIngredient]

    func normalizedSeedIngredient(from payload: SeedIngredientPayload) -> RecipeIngredient {
        let mappedUnit = RecipeQuantityUnit(rawValue: payload.quantityUnit) ?? .piece
        var normalized = normalizedQuantityAndUnit(
            from: payload.rawIngredientLine,
            fallbackValue: payload.quantityValue,
            fallbackUnit: mappedUnit
        )

        let unitProfile = unitProfile(forProduceID: payload.produceID, basicID: payload.basicIngredientID)
        normalized = normalizedToUnitProfile(
            normalized,
            profile: unitProfile,
            ingredientName: payload.name
        )

        return RecipeIngredient(
            produceID: payload.produceID,
            basicIngredientID: payload.basicIngredientID,
            quality: RecipeIngredientQuality(rawValue: payload.quality) ?? .basic,
            name: payload.name,
            quantityValue: normalized.value,
            quantityUnit: normalized.unit,
            rawIngredientLine: payload.rawIngredientLine,
            mappingConfidence: RecipeIngredientMappingConfidence(rawValue: payload.mappingConfidence) ?? .unmapped
        )
    }

    func normalizedServings(
        _ payloadValue: Int?,
        ingredientsCount: Int,
        prepTimeMinutes: Int?,
        cookTimeMinutes: Int?
    ) -> Int {
        if let payloadValue, payloadValue > 0 {
            return min(12, max(1, payloadValue))
        }

        let totalMinutes = (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0)
        if ingredientsCount <= 4 && totalMinutes <= 20 {
            return 2
        }
        if ingredientsCount <= 8 {
            return 4
        }
        return 6
    }

    private func unitProfile(forProduceID produceID: String?, basicID: String?) -> IngredientUnitProfile? {
        if let produceID,
           let produce = produceByID[produceID],
           let defaultUnit = produce.defaultUnit {
            let supported = produce.supportedUnits ?? [defaultUnit]
            var grams: [RecipeQuantityUnit: Double] = [:]
            var ml: [RecipeQuantityUnit: Double] = [:]
            for (rawUnit, value) in produce.gramsPerUnit ?? [:] {
                if let unit = RecipeQuantityUnit(rawValue: rawUnit) {
                    grams[unit] = value
                }
            }
            for (rawUnit, value) in produce.mlPerUnit ?? [:] {
                if let unit = RecipeQuantityUnit(rawValue: rawUnit) {
                    ml[unit] = value
                }
            }
            if grams[.g] == nil { grams[.g] = 1 }
            if ml[.ml] == nil { ml[.ml] = 1 }
            return IngredientUnitProfile(
                defaultUnit: defaultUnit,
                supportedUnits: supported,
                gramsPerUnit: grams,
                mlPerUnit: ml,
                gramsPerMl: produce.gramsPerMl
            )
        }

        if let basicID, let basic = basicByID[basicID] {
            return basic.unitProfile
        }

        return nil
    }

    private func normalizedToUnitProfile(
        _ quantity: (value: Double, unit: RecipeQuantityUnit),
        profile: IngredientUnitProfile?,
        ingredientName: String
    ) -> (value: Double, unit: RecipeQuantityUnit) {
        guard let profile else {
            return (max(0.1, quantity.value), quantity.unit)
        }

        var value = quantity.value
        var unit = quantity.unit

        let shouldAvoidPiece = profile.defaultUnit == .g || profile.defaultUnit == .ml
        if unit == .piece && shouldAvoidPiece {
            if let converted = convert(value: value, from: unit, to: profile.defaultUnit, profile: profile) {
                value = converted
                unit = profile.defaultUnit
            } else if ingredientName.lowercased() != "onion" && ingredientName.lowercased() != "garlic" {
                value *= 100
                unit = profile.defaultUnit
            }
        } else if !profile.supportedUnits.contains(unit) {
            if let converted = convert(value: value, from: unit, to: profile.defaultUnit, profile: profile) {
                value = converted
            } else {
                value = max(0.1, value)
            }
            unit = profile.defaultUnit
        }

        return (roundedQuantityValue(value), unit)
    }

    private func convert(
        value: Double,
        from sourceUnit: RecipeQuantityUnit,
        to targetUnit: RecipeQuantityUnit,
        profile: IngredientUnitProfile
    ) -> Double? {
        let safeValue = max(0.0001, value)
        if sourceUnit == targetUnit { return safeValue }

        if targetUnit == .g {
            if sourceUnit == .ml {
                return safeValue * (profile.gramsPerMl ?? 1)
            }
            if let grams = profile.gramsPerUnit[sourceUnit] {
                return safeValue * grams
            }
            if let ml = profile.mlPerUnit[sourceUnit] {
                return safeValue * ml * (profile.gramsPerMl ?? 1)
            }
        }

        if targetUnit == .ml {
            if sourceUnit == .g {
                return safeValue / (profile.gramsPerMl ?? 1)
            }
            if let ml = profile.mlPerUnit[sourceUnit] {
                return safeValue * ml
            }
            if let grams = profile.gramsPerUnit[sourceUnit] {
                return (safeValue * grams) / (profile.gramsPerMl ?? 1)
            }
        }

        if sourceUnit == .tbsp && targetUnit == .g { return safeValue * 15 }
        if sourceUnit == .tsp && targetUnit == .g { return safeValue * 5 }
        if sourceUnit == .tbsp && targetUnit == .ml { return safeValue * 15 }
        if sourceUnit == .tsp && targetUnit == .ml { return safeValue * 5 }
        if sourceUnit == .piece && targetUnit == .g { return safeValue * 100 }
        if sourceUnit == .piece && targetUnit == .ml { return safeValue * 100 }

        return nil
    }

    private func normalizedQuantityAndUnit(
        from rawIngredientLine: String?,
        fallbackValue: Double,
        fallbackUnit: RecipeQuantityUnit
    ) -> (value: Double, unit: RecipeQuantityUnit) {
        guard let raw = rawIngredientLine?.lowercased() else {
            return (max(0.1, fallbackValue), fallbackUnit)
        }

        let value = parsedFirstNumber(in: raw) ?? max(0.1, fallbackValue)
        if raw.contains("kg") { return (value * 1000, .g) }
        if raw.contains("lb") { return (value * 453.6, .g) }
        if raw.contains("oz") { return (value * 28.35, .g) }
        if raw.contains("ml") { return (value, .ml) }
        if raw.contains(" g") || raw.contains("g ") || raw.hasSuffix("g") { return (value, .g) }
        if raw.contains("tbsp") || raw.contains(" tbs") || raw.contains("tablespoon") { return (value, .tbsp) }
        if raw.contains("tsp") || raw.contains("teaspoon") { return (value, .tsp) }
        if raw.contains("clove") { return (value, .clove) }
        if raw.contains("cup") { return (value * 240, .ml) }

        return (max(0.1, fallbackValue), fallbackUnit)
    }

    private func parsedFirstNumber(in raw: String) -> Double? {
        let pattern = #"(\d+(?:[\.,]\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: nsRange),
              let range = Range(match.range(at: 1), in: raw) else { return nil }
        let token = raw[range].replacingOccurrences(of: ",", with: ".")
        return Double(token)
    }

    private func roundedQuantityValue(_ value: Double) -> Double {
        let clamped = max(0.1, value)
        let rounded = (clamped * 10).rounded() / 10
        if rounded >= 10 {
            return rounded.rounded()
        }
        return rounded
    }
}
