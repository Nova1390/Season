import Foundation

enum RecipeStore {
    static func loadProfiles() -> [UserProfile] {
        [
            UserProfile(id: "anna", name: "Anna"),
            UserProfile(id: "marco", name: "Marco"),
            UserProfile(id: "sofia", name: "Sofia"),
            UserProfile(id: "luca", name: "Luca")
        ]
    }

    static func loadRecipes() -> [Recipe] {
        [
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
                    RecipeIngredient(produceID: nil, basicIngredientID: "garlic", quality: .basic, name: "Garlic", quantityValue: 2, quantityUnit: .clove)
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
                    RecipeIngredient(produceID: nil, basicIngredientID: "garlic", quality: .basic, name: "Garlic", quantityValue: 2, quantityUnit: .clove)
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
                    RecipeIngredient(produceID: nil, basicIngredientID: "onion_basic", quality: .basic, name: "Onion", quantityValue: 80, quantityUnit: .g),
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
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
