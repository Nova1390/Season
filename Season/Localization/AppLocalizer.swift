import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case italian = "it"

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        }
    }
}

enum AppTextKey: String {
    case homeTab
    case searchTab
    case createTab
    case todayTab
    case fridgeTab
    case listTab
    case settingsTab
    case accountTab
    case language
    case inSeasonNow
    case notInSeasonNow
    case inSeason
    case notInSeason
    case seasonPeakNow
    case seasonBestThisMonth
    case seasonEndOfSeason
    case seasonOutOfSeason
    case seasonPhaseInSeason
    case seasonPhaseEarlySeason
    case seasonPhaseEndingSoon
    case seasonPhaseOutOfSeason
    case currentMonth
    case fruit
    case vegetables
    case tubers
    case legumes
    case category
    case seasonMonths
    case recipes
    case basicIngredient
    case noResults
    case searchPlaceholder
    case addToList
    case removeFromList
    case addToFridge
    case removeFromFridge
    case alreadyInList
    case inShoppingList
    case inFridge
    case shoppingListEmpty
    case seasonalScore
    case itemsInSeasonFormat
    case searchEmptyTitle
    case searchEmptySubtitle
    case shoppingListEmptyTitle
    case shoppingListEmptySubtitle
    case seasonalStatus
    case nutrition
    case calories
    case protein
    case carbs
    case fat
    case fiber
    case vitaminC
    case potassium
    case nutritionPreferences
    case nutritionPreferencesHint
    case goalMoreProtein
    case goalMoreFiber
    case goalMoreVitaminC
    case goalLowerSugar
    case inSeasonTodayTitle
    case rankingWhy
    case reasonHighFiber
    case reasonHighProtein
    case reasonHighCarbs
    case reasonHighFat
    case reasonHighVitaminC
    case reasonHighPotassium
    case reasonInSeasonNow
    case seasonalityChart
    case recipeDietaryTags
    case dietaryTagClassificationNote
    case dietaryGlutenFree
    case dietaryVegetarian
    case dietaryVegan
    case creatorBadgeGlutenFreeMaster
    case creatorBadgeVegetarianMaster
    case creatorBadgeVeganMaster
    case nutritionComparisonBasisNote
    case nutritionSourceCaption
    case bestPicksToday
    case monthPicksFormat
    case trendingSeasonalRecipes
    case trendingNowTitle
    case smartSuggestionsTitle
    case fromPeopleYouFollow
    case addIngredients
    case saveRecipe
    case saved
    case savedRecipes
    case savedRecipesEmptySubtitle
    case removeSavedRecipe
    case follow
    case following
    case followAuthorsHint
    case ingredients
    case seasonalMatch
    case recipeReasonSeasonalMatchFormat
    case recipeReasonFreshThisMonth
    case recipeReasonHighFiberPick
    case ingredientsAddedAllFormat
    case ingredientsAddedSomeFormat
    case ingredientsAlreadyInList
    case remove
    case preparation
    case steps
    case prepTime
    case cookTime
    case difficulty
    case difficultyEasy
    case difficultyMedium
    case difficultyHard
    case minutesShort
    case profile
    case myRecipes
    case createRecipe
    case archiveRecipe
    case restoreRecipe
    case deleteRecipe
    case archivedRecipes
    case archivedRecipesEmptySubtitle
    case viewsCountFormat
    case viewsLabel
    case publishRecipe
    case remixRecipe
    case remixOfFormat
    case remixesCountFormat
    case mediaSectionTitle
    case mediaAssetName
    case mediaExternalLink
    case importFromLinkSectionTitle
    case socialLink
    case socialCaptionRaw
    case importDraft
    case importApplied
    case importNoMatches
    case cookWithWhatYouHave
    case ingredientMatchCountFormat
    case onlyMissingFormat
    case almostReady
    case ingredientsAwayFormat
    case usedInRecipesFormat
    case readyInMinutesFormat
    case bestWithWhatYouHave
    case fridgeEmptyTitle
    case fridgeEmptySubtitle
    case youHave
    case missing
    case titleSectionTitle
    case ingredientsSectionTitle
    case ingredientName
    case customIngredient
    case cantFindAddCustom
    case quantity
    case addIngredient
    case addedManually
    case select
    case selectAll
    case clearSelection
    case deleteSelected
    case moveToFridge
    case selectionSummaryFormat
    case stepsSectionTitle
    case addStep
    case stepPlaceholder
    case previewSectionTitle
    case seasonalFeedbackGreat
    case seasonalFeedbackLow
    case seasonalFeedbackEmpty
    case publishHint
    case recipeCountFormat
    case followedAuthorsCountFormat
    case comingSoon
    case crispyCountFormat
    case totalCrispyReceivedFormat
    case averageSeasonalMatchFormat
    case badges
    case noBadgesYet
    case freshScoreExcellent
    case freshScoreGreat
    case freshScoreGood
    case recipeNutritionSummaryTitle
    case recipeNutritionEstimatedNote
    case createRecipeSubtitle
    case done
    case homeHeroSubtitle
    case homeHeroQuestion
    case featuredRecipe
    case cookWithWhatYouHaveSummaryFormat
    case cookWithWhatYouHaveHint
    case openFridge
    case fromYourFridge
    case bestSeasonalPicks
    case bestSeasonalPicksHint
    case highlightedIngredientsCountFormat
    case ingredientsCountFormat
    case quickActionReadyToCook
    case quickActionFreshToday
    case quickActionNoMatchesYet
    case quickActionAddIngredientsHint
    case quickActionSeasonAndGoals
    case moodLightFresh
    case moodComfortFood
    case moodQuickMeals
    case recipeHookReadyInFormat
    case recipeHookViralThisWeek
    case recipeHookHighFiber
    case recipeHookSeasonalFavorite
    case recipeHookTrendingNow
    case mediaAddPhotos
    case mediaUseCamera
    case mediaNoImagesYet
    case mediaCoverTag
    case mediaSetCover
    case mediaRemoveImage
    case watchVideo
    case openOnInstagram
    case openOnTikTok
    case detectedPlatformFormat
    case fromRecipeFormat
    case recipeTimingPerfectNow
    case recipeTimingBetterSoon
    case recipeTimingEndingSoon
    case recipeTimingGoodNow
    case fromFridgeSubtitleEmpty
    case fromFridgeSubtitleCountFormat
    case fridgePreviewTitle
    case editFridge
    case bestMatches
    case quickOptions
    case needsShopping
    case needsIngredients
    case noMatchingRecipesYetTitle
    case noMatchingRecipesYetSubtitle
    case missingIngredients
    case noMissingIngredients
    case cookAction
    case viewRecipeAction
    case addMissingAction
    case readyNow
    case crispyAction
    case addedMissingItemsFormat
}

struct AppLocalizer {
    let languageCode: String

    func text(_ key: AppTextKey) -> String {
        AppLocalizer.strings[languageCode]?[key]
        ?? AppLocalizer.strings["en"]?[key]
        ?? key.rawValue
    }

    func categoryTitle(for category: ProduceCategoryKey) -> String {
        switch category {
        case .fruit:
            return text(.fruit)
        case .vegetable:
            return text(.vegetables)
        case .tuber:
            return text(.tubers)
        case .legume:
            return text(.legumes)
        }
    }

    func seasonalityLevelTitle(_ level: SeasonalityLevel) -> String {
        switch level {
        case .peak:
            return text(.seasonPeakNow)
        case .good:
            return text(.seasonBestThisMonth)
        case .low:
            return text(.seasonEndOfSeason)
        case .out:
            return text(.seasonOutOfSeason)
        }
    }

    func seasonalityPhaseTitle(_ phase: SeasonalityPhase) -> String {
        switch phase {
        case .inSeason:
            return text(.seasonPhaseInSeason)
        case .earlySeason:
            return text(.seasonPhaseEarlySeason)
        case .endingSoon:
            return text(.seasonPhaseEndingSoon)
        case .outOfSeason:
            return text(.seasonPhaseOutOfSeason)
        }
    }

    func recipeTimingTitle(_ label: RecipeTimingLabel) -> String {
        switch label {
        case .perfectNow:
            return text(.recipeTimingPerfectNow)
        case .betterSoon:
            return text(.recipeTimingBetterSoon)
        case .endingSoon:
            return text(.recipeTimingEndingSoon)
        case .goodNow:
            return text(.recipeTimingGoodNow)
        }
    }

    func nutritionGoalTitle(_ goal: NutritionGoal) -> String {
        switch goal {
        case .moreProtein:
            return text(.goalMoreProtein)
        case .moreFiber:
            return text(.goalMoreFiber)
        case .moreVitaminC:
            return text(.goalMoreVitaminC)
        case .lowerSugar:
            return text(.goalLowerSugar)
        }
    }

    func nutritionPriorityTitle(_ dimension: NutritionPriorityDimension) -> String {
        switch dimension {
        case .protein:
            return text(.protein)
        case .carbs:
            return text(.carbs)
        case .fat:
            return text(.fat)
        case .fiber:
            return text(.fiber)
        case .vitaminC:
            return text(.vitaminC)
        case .potassium:
            return text(.potassium)
        }
    }

    func recipeDifficultyTitle(_ difficulty: RecipeDifficulty) -> String {
        switch difficulty {
        case .easy:
            return text(.difficultyEasy)
        case .medium:
            return text(.difficultyMedium)
        case .hard:
            return text(.difficultyHard)
        }
    }

    func dietaryTagTitle(_ tag: RecipeDietaryTag) -> String {
        switch tag {
        case .glutenFree:
            return text(.dietaryGlutenFree)
        case .vegetarian:
            return text(.dietaryVegetarian)
        case .vegan:
            return text(.dietaryVegan)
        }
    }

    func userBadgeTitle(_ kind: UserBadge.Kind) -> String {
        switch kind {
        case .seasonStarter:
            return "Season Starter"
        case .freshCook:
            return "Fresh Cook"
        case .crispyCreator:
            return "Crispy Creator"
        case .topSeasonal:
            return "Top Seasonal"
        case .glutenFreeMaster:
            return text(.creatorBadgeGlutenFreeMaster)
        case .vegetarianMaster:
            return text(.creatorBadgeVegetarianMaster)
        case .veganMaster:
            return text(.creatorBadgeVeganMaster)
        }
    }

    func quantityUnitTitle(_ unit: RecipeQuantityUnit) -> String {
        switch languageCode {
        case "it":
            switch unit {
            case .g: return "g"
            case .ml: return "ml"
            case .piece: return "pezzo"
            case .clove: return "spicchio"
            case .tbsp: return "cucchiaio"
            case .tsp: return "cucchiaino"
            }
        default:
            switch unit {
            case .g: return "g"
            case .ml: return "ml"
            case .piece: return "piece"
            case .clove: return "clove"
            case .tbsp: return "tbsp"
            case .tsp: return "tsp"
            }
        }
    }

    private static let strings: [String: [AppTextKey: String]] = [
        "en": [
            .homeTab: "Home",
            .searchTab: "Search",
            .createTab: "Create",
            .todayTab: "Today",
            .fridgeTab: "Fridge",
            .listTab: "List",
            .settingsTab: "Settings",
            .accountTab: "Account",
            .language: "Language",
            .inSeasonNow: "In season now",
            .notInSeasonNow: "Not in season now",
            .inSeason: "In season",
            .notInSeason: "Not in season",
            .seasonPeakNow: "Peak now",
            .seasonBestThisMonth: "Best this month",
            .seasonEndOfSeason: "End of season",
            .seasonOutOfSeason: "Out of season",
            .seasonPhaseInSeason: "In season",
            .seasonPhaseEarlySeason: "Early season",
            .seasonPhaseEndingSoon: "Ending soon",
            .seasonPhaseOutOfSeason: "Out of season",
            .currentMonth: "Current month",
            .fruit: "Fruit",
            .vegetables: "Vegetables",
            .tubers: "Tubers",
            .legumes: "Legumes",
            .category: "Category",
            .seasonMonths: "Season months",
            .recipes: "Recipes",
            .basicIngredient: "Basic ingredient",
            .noResults: "No results",
            .searchPlaceholder: "Search produce",
            .addToList: "Add to List",
            .removeFromList: "Remove from List",
            .addToFridge: "Add to Fridge",
            .removeFromFridge: "Remove from Fridge",
            .alreadyInList: "Already in List",
            .inShoppingList: "In list",
            .inFridge: "In fridge",
            .shoppingListEmpty: "Your shopping list is empty.",
            .seasonalScore: "Seasonal Score",
            .itemsInSeasonFormat: "%d of %d items are currently in season",
            .searchEmptyTitle: "No matching produce",
            .searchEmptySubtitle: "Try a different name or browse seasonal categories on Home.",
            .shoppingListEmptyTitle: "Your list is empty",
            .shoppingListEmptySubtitle: "Add produce from Home or Search to start planning.",
            .seasonalStatus: "Seasonal status",
            .nutrition: "Nutrition (per 100 g)",
            .calories: "Calories",
            .protein: "Protein",
            .carbs: "Carbs",
            .fat: "Fat",
            .fiber: "Fiber",
            .vitaminC: "Vitamin C",
            .potassium: "Potassium",
            .nutritionPreferences: "Nutrition preferences",
            .nutritionPreferencesHint: "These are simple ranking preferences only.",
            .goalMoreProtein: "More protein",
            .goalMoreFiber: "More fiber",
            .goalMoreVitaminC: "More vitamin C",
            .goalLowerSugar: "Lower sugar",
            .inSeasonTodayTitle: "In Season Today",
            .rankingWhy: "Why it ranks well",
            .reasonHighFiber: "High fiber",
            .reasonHighProtein: "High protein",
            .reasonHighCarbs: "High carbs",
            .reasonHighFat: "High fat",
            .reasonHighVitaminC: "High vitamin C",
            .reasonHighPotassium: "High potassium",
            .reasonInSeasonNow: "In season now",
            .seasonalityChart: "Seasonality chart",
            .recipeDietaryTags: "Dietary tags",
            .dietaryTagClassificationNote: "Dietary tags are simple recipe classifications, not medical certifications.",
            .dietaryGlutenFree: "Gluten free",
            .dietaryVegetarian: "Vegetarian",
            .dietaryVegan: "Vegan",
            .creatorBadgeGlutenFreeMaster: "Gluten Free Master",
            .creatorBadgeVegetarianMaster: "Vegetarian Master",
            .creatorBadgeVeganMaster: "Vegan Master",
            .nutritionComparisonBasisNote: "Nutrition comparisons and ranking use values per 100 g.",
            .nutritionSourceCaption: "Source: USDA FoodData Central",
            .bestPicksToday: "Best picks today",
            .monthPicksFormat: "%@ picks",
            .trendingSeasonalRecipes: "Trending seasonal recipes",
            .trendingNowTitle: "Trending now",
            .smartSuggestionsTitle: "Smart suggestions",
            .fromPeopleYouFollow: "From people you follow",
            .addIngredients: "Add ingredients",
            .saveRecipe: "Save recipe",
            .saved: "Saved",
            .savedRecipes: "Saved recipes",
            .savedRecipesEmptySubtitle: "Save recipes to quickly find them later.",
            .removeSavedRecipe: "Remove saved",
            .follow: "Follow",
            .following: "Following",
            .followAuthorsHint: "Follow recipe authors to see personalized picks.",
            .ingredients: "Ingredients",
            .seasonalMatch: "Seasonal match",
            .recipeReasonSeasonalMatchFormat: "%d%% seasonal match",
            .recipeReasonFreshThisMonth: "Fresh this month",
            .recipeReasonHighFiberPick: "High fiber pick",
            .ingredientsAddedAllFormat: "Added %d ingredients to your list.",
            .ingredientsAddedSomeFormat: "Added %d ingredients. %d already in your list.",
            .ingredientsAlreadyInList: "All ingredients are already in your list.",
            .remove: "Remove",
            .preparation: "Preparation",
            .steps: "Steps",
            .prepTime: "Prep time",
            .cookTime: "Cook time",
            .difficulty: "Difficulty",
            .difficultyEasy: "Easy",
            .difficultyMedium: "Medium",
            .difficultyHard: "Hard",
            .minutesShort: "min",
            .profile: "Profile",
            .myRecipes: "My Recipes",
            .createRecipe: "Create recipe",
            .archiveRecipe: "Archive",
            .restoreRecipe: "Restore",
            .deleteRecipe: "Delete",
            .archivedRecipes: "Archived recipes",
            .archivedRecipesEmptySubtitle: "No archived recipes yet.",
            .viewsCountFormat: "%d views",
            .viewsLabel: "views",
            .publishRecipe: "Publish",
            .remixRecipe: "Remix",
            .remixOfFormat: "Remix of %@",
            .remixesCountFormat: "%d remixes",
            .mediaSectionTitle: "Media",
            .mediaAssetName: "Image asset name (optional)",
            .mediaExternalLink: "External media link (optional)",
            .importFromLinkSectionTitle: "Import from link",
            .socialLink: "TikTok or Instagram link",
            .socialCaptionRaw: "Paste caption/description (optional)",
            .importDraft: "Import draft",
            .importApplied: "Draft imported. Review and edit before publishing.",
            .importNoMatches: "No strong ingredient matches found. You can still edit manually.",
            .cookWithWhatYouHave: "Cook with what you have",
            .ingredientMatchCountFormat: "%d/%d ingredients",
            .onlyMissingFormat: "Only %d missing",
            .almostReady: "Almost ready",
            .ingredientsAwayFormat: "You're %d ingredients away",
            .usedInRecipesFormat: "Used in %d recipes",
            .readyInMinutesFormat: "Ready in %d min",
            .bestWithWhatYouHave: "Best with what you have",
            .fridgeEmptyTitle: "Your fridge is empty",
            .fridgeEmptySubtitle: "Add ingredients you already have to get recipe matches.",
            .youHave: "You have",
            .missing: "Missing",
            .titleSectionTitle: "Title",
            .ingredientsSectionTitle: "Ingredients",
            .ingredientName: "Ingredient",
            .customIngredient: "Custom ingredient",
            .cantFindAddCustom: "Can't find it? Add custom ingredient",
            .quantity: "Quantity",
            .addIngredient: "Add ingredient",
            .addedManually: "Added manually",
            .select: "Select",
            .selectAll: "Select all",
            .clearSelection: "Clear",
            .deleteSelected: "Delete selected",
            .moveToFridge: "Move to fridge",
            .selectionSummaryFormat: "%d selected",
            .stepsSectionTitle: "Steps",
            .addStep: "Add step",
            .stepPlaceholder: "Describe this step",
            .previewSectionTitle: "Preview",
            .seasonalFeedbackGreat: "Great",
            .seasonalFeedbackLow: "Low",
            .seasonalFeedbackEmpty: "Add ingredients to see seasonal match.",
            .publishHint: "Keep it simple and seasonal.",
            .recipeCountFormat: "%d recipes",
            .followedAuthorsCountFormat: "%d followed authors",
            .comingSoon: "Coming soon",
            .crispyCountFormat: "%d crispy",
            .totalCrispyReceivedFormat: "%d crispy received",
            .averageSeasonalMatchFormat: "%.0f%% average seasonal match",
            .badges: "Badges",
            .noBadgesYet: "Start sharing seasonal recipes to unlock badges.",
            .freshScoreExcellent: "Excellent",
            .freshScoreGreat: "Great",
            .freshScoreGood: "Good",
            .recipeNutritionSummaryTitle: "Recipe nutrition total",
            .recipeNutritionEstimatedNote: "Estimated total for this recipe, using ingredient values per 100 g.",
            .createRecipeSubtitle: "Recipe creation editor is coming soon.",
            .done: "Done",
            .homeHeroSubtitle: "Seasonal recipes and ingredients picked for you",
            .homeHeroQuestion: "Cook something fresh today",
            .featuredRecipe: "Featured recipe",
            .cookWithWhatYouHaveSummaryFormat: "%d recipe matches",
            .cookWithWhatYouHaveHint: "Use what you already have before shopping.",
            .openFridge: "Open Fridge",
            .fromYourFridge: "From your fridge",
            .bestSeasonalPicks: "Best seasonal picks",
            .bestSeasonalPicksHint: "Top ingredients with strong nutrition and seasonality.",
            .highlightedIngredientsCountFormat: "%d highlighted ingredients",
            .ingredientsCountFormat: "%d ingredients",
            .quickActionReadyToCook: "Ready to cook",
            .quickActionFreshToday: "Fresh today",
            .quickActionNoMatchesYet: "No matches yet",
            .quickActionAddIngredientsHint: "Add ingredients to see recipes",
            .quickActionSeasonAndGoals: "Season + your goals",
            .moodLightFresh: "Light & fresh",
            .moodComfortFood: "Comfort food",
            .moodQuickMeals: "Quick meals",
            .recipeHookReadyInFormat: "Ready in %d min",
            .recipeHookViralThisWeek: "Viral this week",
            .recipeHookHighFiber: "High fiber pick",
            .recipeHookSeasonalFavorite: "Seasonal favorite",
            .recipeHookTrendingNow: "Trending now",
            .mediaAddPhotos: "Add photos",
            .mediaUseCamera: "Use camera",
            .mediaNoImagesYet: "No images selected yet.",
            .mediaCoverTag: "Cover",
            .mediaSetCover: "Set cover",
            .mediaRemoveImage: "Remove image",
            .watchVideo: "Watch video",
            .openOnInstagram: "Open on Instagram",
            .openOnTikTok: "Open on TikTok",
            .detectedPlatformFormat: "Detected: %@",
            .fromRecipeFormat: "From %@",
            .recipeTimingPerfectNow: "Perfect now",
            .recipeTimingBetterSoon: "Better soon",
            .recipeTimingEndingSoon: "Ending soon",
            .recipeTimingGoodNow: "Good now",
            .fromFridgeSubtitleEmpty: "Add ingredients to get started",
            .fromFridgeSubtitleCountFormat: "You can cook %d recipes",
            .fridgePreviewTitle: "In your fridge",
            .editFridge: "Edit fridge",
            .bestMatches: "Best matches",
            .quickOptions: "Quick options",
            .needsShopping: "Needs shopping",
            .needsIngredients: "Needs ingredients",
            .noMatchingRecipesYetTitle: "No matching recipes yet",
            .noMatchingRecipesYetSubtitle: "Add more ingredients to unlock recipes",
            .missingIngredients: "Missing",
            .noMissingIngredients: "No missing ingredients",
            .cookAction: "Cook",
            .viewRecipeAction: "View recipe",
            .addMissingAction: "Add missing",
            .readyNow: "Ready now",
            .crispyAction: "Crispy",
            .addedMissingItemsFormat: "Added %d missing ingredients"
        ],
        "it": [
            .homeTab: "Home",
            .searchTab: "Cerca",
            .createTab: "Crea",
            .todayTab: "Oggi",
            .fridgeTab: "Frigo",
            .listTab: "Lista",
            .settingsTab: "Impostazioni",
            .accountTab: "Account",
            .language: "Lingua",
            .inSeasonNow: "Di stagione ora",
            .notInSeasonNow: "Fuori stagione ora",
            .inSeason: "Di stagione",
            .notInSeason: "Fuori stagione",
            .seasonPeakNow: "Picco ora",
            .seasonBestThisMonth: "Al meglio questo mese",
            .seasonEndOfSeason: "Fine stagione",
            .seasonOutOfSeason: "Fuori stagione",
            .seasonPhaseInSeason: "Di stagione",
            .seasonPhaseEarlySeason: "Primizia",
            .seasonPhaseEndingSoon: "Sta finendo",
            .seasonPhaseOutOfSeason: "Fuori stagione",
            .currentMonth: "Mese corrente",
            .fruit: "Frutta",
            .vegetables: "Verdure",
            .tubers: "Tuberi",
            .legumes: "Legumi",
            .category: "Categoria",
            .seasonMonths: "Mesi di stagione",
            .recipes: "Ricette",
            .basicIngredient: "Ingrediente base",
            .noResults: "Nessun risultato",
            .searchPlaceholder: "Cerca prodotti",
            .addToList: "Aggiungi alla Lista",
            .removeFromList: "Rimuovi dalla Lista",
            .addToFridge: "Aggiungi al Frigo",
            .removeFromFridge: "Rimuovi dal Frigo",
            .alreadyInList: "Già in Lista",
            .inShoppingList: "In lista",
            .inFridge: "Nel frigo",
            .shoppingListEmpty: "La tua lista della spesa è vuota.",
            .seasonalScore: "Punteggio Stagionale",
            .itemsInSeasonFormat: "%d di %d elementi sono attualmente di stagione",
            .searchEmptyTitle: "Nessun prodotto trovato",
            .searchEmptySubtitle: "Prova un nome diverso o guarda le categorie stagionali nella Home.",
            .shoppingListEmptyTitle: "La tua lista è vuota",
            .shoppingListEmptySubtitle: "Aggiungi prodotti da Home o Cerca per iniziare.",
            .seasonalStatus: "Stato stagionale",
            .nutrition: "Valori nutrizionali (per 100 g)",
            .calories: "Calorie",
            .protein: "Proteine",
            .carbs: "Carboidrati",
            .fat: "Grassi",
            .fiber: "Fibre",
            .vitaminC: "Vitamina C",
            .potassium: "Potassio",
            .nutritionPreferences: "Preferenze nutrizionali",
            .nutritionPreferencesHint: "Sono solo preferenze per ordinare i risultati.",
            .goalMoreProtein: "Più proteine",
            .goalMoreFiber: "Più fibre",
            .goalMoreVitaminC: "Più vitamina C",
            .goalLowerSugar: "Meno zuccheri",
            .inSeasonTodayTitle: "Di stagione oggi",
            .rankingWhy: "Perché è in alto",
            .reasonHighFiber: "Ricco di fibre",
            .reasonHighProtein: "Ricco di proteine",
            .reasonHighCarbs: "Ricco di carboidrati",
            .reasonHighFat: "Ricco di grassi",
            .reasonHighVitaminC: "Ricco di vitamina C",
            .reasonHighPotassium: "Ricco di potassio",
            .reasonInSeasonNow: "Attualmente di stagione",
            .seasonalityChart: "Grafico stagionalita",
            .recipeDietaryTags: "Tag alimentari",
            .dietaryTagClassificationNote: "I tag alimentari sono classificazioni semplici della ricetta, non certificazioni mediche.",
            .dietaryGlutenFree: "Senza glutine",
            .dietaryVegetarian: "Vegetariana",
            .dietaryVegan: "Vegana",
            .creatorBadgeGlutenFreeMaster: "Gluten Free Master",
            .creatorBadgeVegetarianMaster: "Vegetarian Master",
            .creatorBadgeVeganMaster: "Vegan Master",
            .nutritionComparisonBasisNote: "Confronti e ranking nutrizionali usano valori per 100 g.",
            .nutritionSourceCaption: "Fonte: USDA FoodData Central",
            .bestPicksToday: "Scelte migliori di oggi",
            .monthPicksFormat: "Scelte di %@",
            .trendingSeasonalRecipes: "Ricette stagionali in tendenza",
            .trendingNowTitle: "Di tendenza ora",
            .smartSuggestionsTitle: "Suggerimenti smart",
            .fromPeopleYouFollow: "Da persone che segui",
            .addIngredients: "Aggiungi ingredienti",
            .saveRecipe: "Salva ricetta",
            .saved: "Salvata",
            .savedRecipes: "Ricette salvate",
            .savedRecipesEmptySubtitle: "Salva ricette per ritrovarle velocemente.",
            .removeSavedRecipe: "Rimuovi salvata",
            .follow: "Segui",
            .following: "Segui gia",
            .followAuthorsHint: "Segui gli autori per vedere suggerimenti personalizzati.",
            .ingredients: "Ingredienti",
            .seasonalMatch: "Compatibilita stagionale",
            .recipeReasonSeasonalMatchFormat: "Compatibilita stagionale al %d%%",
            .recipeReasonFreshThisMonth: "Fresco questo mese",
            .recipeReasonHighFiberPick: "Ricca di fibre",
            .ingredientsAddedAllFormat: "Aggiunti %d ingredienti alla lista.",
            .ingredientsAddedSomeFormat: "Aggiunti %d ingredienti. %d erano gia in lista.",
            .ingredientsAlreadyInList: "Tutti gli ingredienti sono gia nella lista.",
            .remove: "Rimuovi",
            .preparation: "Preparazione",
            .steps: "Passaggi",
            .prepTime: "Tempo prep",
            .cookTime: "Tempo cottura",
            .difficulty: "Difficolta",
            .difficultyEasy: "Facile",
            .difficultyMedium: "Media",
            .difficultyHard: "Difficile",
            .minutesShort: "min",
            .profile: "Profilo",
            .myRecipes: "Le mie ricette",
            .createRecipe: "Crea ricetta",
            .archiveRecipe: "Archivia",
            .restoreRecipe: "Ripristina",
            .deleteRecipe: "Elimina",
            .archivedRecipes: "Ricette archiviate",
            .archivedRecipesEmptySubtitle: "Nessuna ricetta archiviata.",
            .viewsCountFormat: "%d visualizzazioni",
            .viewsLabel: "visualizzazioni",
            .publishRecipe: "Pubblica",
            .remixRecipe: "Remix",
            .remixOfFormat: "Remix di %@",
            .remixesCountFormat: "%d remix",
            .mediaSectionTitle: "Media",
            .mediaAssetName: "Nome asset immagine (opzionale)",
            .mediaExternalLink: "Link media esterno (opzionale)",
            .importFromLinkSectionTitle: "Importa da link",
            .socialLink: "Link TikTok o Instagram",
            .socialCaptionRaw: "Incolla caption/descrizione (opzionale)",
            .importDraft: "Importa bozza",
            .importApplied: "Bozza importata. Controlla e modifica prima di pubblicare.",
            .importNoMatches: "Nessuna corrispondenza ingredienti forte. Puoi modificare manualmente.",
            .cookWithWhatYouHave: "Cucina con quello che hai",
            .ingredientMatchCountFormat: "%d/%d ingredienti",
            .onlyMissingFormat: "Solo %d mancanti",
            .almostReady: "Quasi pronta",
            .ingredientsAwayFormat: "Ti mancano %d ingredienti",
            .usedInRecipesFormat: "Usato in %d ricette",
            .readyInMinutesFormat: "Pronta in %d min",
            .bestWithWhatYouHave: "Ideale con quello che hai",
            .fridgeEmptyTitle: "Il tuo frigo e vuoto",
            .fridgeEmptySubtitle: "Aggiungi ingredienti che hai gia per trovare ricette adatte.",
            .youHave: "Hai",
            .missing: "Mancano",
            .titleSectionTitle: "Titolo",
            .ingredientsSectionTitle: "Ingredienti",
            .ingredientName: "Ingrediente",
            .customIngredient: "Ingrediente personalizzato",
            .cantFindAddCustom: "Non lo trovi? Aggiungi ingrediente personalizzato",
            .quantity: "Quantita",
            .addIngredient: "Aggiungi ingrediente",
            .addedManually: "Aggiunti manualmente",
            .select: "Seleziona",
            .selectAll: "Seleziona tutto",
            .clearSelection: "Pulisci",
            .deleteSelected: "Elimina selezionati",
            .moveToFridge: "Sposta nel frigo",
            .selectionSummaryFormat: "%d selezionati",
            .stepsSectionTitle: "Passaggi",
            .addStep: "Aggiungi passaggio",
            .stepPlaceholder: "Descrivi questo passaggio",
            .previewSectionTitle: "Anteprima",
            .seasonalFeedbackGreat: "Great",
            .seasonalFeedbackLow: "Low",
            .seasonalFeedbackEmpty: "Aggiungi ingredienti per vedere la compatibilita stagionale.",
            .publishHint: "Mantienila semplice e stagionale.",
            .recipeCountFormat: "%d ricette",
            .followedAuthorsCountFormat: "%d autori seguiti",
            .comingSoon: "In arrivo",
            .crispyCountFormat: "%d crispy",
            .totalCrispyReceivedFormat: "%d crispy ricevuti",
            .averageSeasonalMatchFormat: "Compatibilita stagionale media: %.0f%%",
            .badges: "Badge",
            .noBadgesYet: "Inizia a condividere ricette stagionali per sbloccare i badge.",
            .freshScoreExcellent: "Excellent",
            .freshScoreGreat: "Great",
            .freshScoreGood: "Good",
            .recipeNutritionSummaryTitle: "Totale nutrizionale ricetta",
            .recipeNutritionEstimatedNote: "Totale stimato della ricetta, calcolato con valori ingredienti per 100 g.",
            .createRecipeSubtitle: "L'editor ricette completo arrivera presto.",
            .done: "Fine",
            .homeHeroSubtitle: "Ricette e ingredienti stagionali scelti per te",
            .homeHeroQuestion: "Cucina qualcosa di fresco oggi",
            .featuredRecipe: "Ricetta in evidenza",
            .cookWithWhatYouHaveSummaryFormat: "%d ricette compatibili",
            .cookWithWhatYouHaveHint: "Usa quello che hai gia prima di fare la spesa.",
            .openFridge: "Apri Frigo",
            .fromYourFridge: "Dal tuo frigo",
            .bestSeasonalPicks: "Migliori scelte stagionali",
            .bestSeasonalPicksHint: "Ingredienti top per stagionalita e profilo nutrizionale.",
            .highlightedIngredientsCountFormat: "%d ingredienti evidenziati",
            .ingredientsCountFormat: "%d ingredienti",
            .quickActionReadyToCook: "Pronte da cucinare",
            .quickActionFreshToday: "Freschi oggi",
            .quickActionNoMatchesYet: "Nessuna corrispondenza",
            .quickActionAddIngredientsHint: "Aggiungi ingredienti per vedere ricette",
            .quickActionSeasonAndGoals: "Stagione + obiettivi",
            .moodLightFresh: "Leggero e fresco",
            .moodComfortFood: "Comfort food",
            .moodQuickMeals: "Pasti veloci",
            .recipeHookReadyInFormat: "Pronta in %d min",
            .recipeHookViralThisWeek: "Virale questa settimana",
            .recipeHookHighFiber: "Ricca di fibre",
            .recipeHookSeasonalFavorite: "Preferita di stagione",
            .recipeHookTrendingNow: "In tendenza",
            .mediaAddPhotos: "Aggiungi foto",
            .mediaUseCamera: "Usa fotocamera",
            .mediaNoImagesYet: "Nessuna immagine selezionata.",
            .mediaCoverTag: "Copertina",
            .mediaSetCover: "Imposta copertina",
            .mediaRemoveImage: "Rimuovi immagine",
            .watchVideo: "Guarda video",
            .openOnInstagram: "Apri su Instagram",
            .openOnTikTok: "Apri su TikTok",
            .detectedPlatformFormat: "Rilevato: %@",
            .fromRecipeFormat: "Da %@",
            .recipeTimingPerfectNow: "Perfetta ora",
            .recipeTimingBetterSoon: "Meglio presto",
            .recipeTimingEndingSoon: "Sta finendo",
            .recipeTimingGoodNow: "Buona ora",
            .fromFridgeSubtitleEmpty: "Aggiungi ingredienti per iniziare",
            .fromFridgeSubtitleCountFormat: "Puoi cucinare %d ricette",
            .fridgePreviewTitle: "Nel tuo frigo",
            .editFridge: "Modifica frigo",
            .bestMatches: "Migliori corrispondenze",
            .quickOptions: "Opzioni rapide",
            .needsShopping: "Serve la spesa",
            .needsIngredients: "Servono ingredienti",
            .noMatchingRecipesYetTitle: "Nessuna ricetta compatibile",
            .noMatchingRecipesYetSubtitle: "Aggiungi piu ingredienti per sbloccare ricette",
            .missingIngredients: "Mancano",
            .noMissingIngredients: "Nessun ingrediente mancante",
            .cookAction: "Cucina",
            .viewRecipeAction: "Vedi ricetta",
            .addMissingAction: "Aggiungi mancanti",
            .readyNow: "Pronta ora",
            .crispyAction: "Crispy",
            .addedMissingItemsFormat: "Aggiunti %d ingredienti mancanti"
        ]
    ]

    func itemsInSeasonText(inSeasonCount: Int, totalCount: Int) -> String {
        let format = text(.itemsInSeasonFormat)
        return String(format: format, inSeasonCount, totalCount)
    }
}
