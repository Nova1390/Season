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
    case saveDraft
    case saved
    case savedRecipes
    case savedRecipesEmptySubtitle
    case removeSavedRecipe
    case follow
    case following
    case followAuthorsHint
    case followingFeedContextFormat
    case followingFeedEmptyTitle
    case followingFeedEmptySubtitle
    case followingFeedEmptyCTA
    case followingFeedFallbackLabel
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
    case servesFormat
    case minutesShort
    case profile
    case myRecipes
    case draftRecipes
    case draftRecipesEmptySubtitle
    case untitledDraft
    case draftSavedAtFormat
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
    case socialCaptionImportPrompt
    case socialImportCaptionNudge
    case importDraft
    case importApplied
    case importNoMatches
    case importWeakResultCaptionHint
    case importAnalyzing
    case importQualityHigh
    case importQualityMedium
    case importQualityLow
    case importRateLimitCooldown
    case importRateLimitDaily
    case recipePublicSocialLinksHint
    case importOwnContentOnlyHint
    case socialImportSelectEligiblePostHint
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
    case followersCountFormat
    case followers
    case publishedRecipes
    case creatorProfileSubtitle
    case previewPublicProfile
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
    case recipeNutritionPerServingBasisFormat
    case recipeNutritionEstimatedNote
    case createRecipeSubtitle
    case publishFailedTitle
    case publishFailedMessage
    case publishAuthRequiredMessage
    case done
    case homeHeroSubtitle
    case homeHeroQuestion
    case homeHeroReadyMorningTitle
    case homeHeroReadyLunchTitle
    case homeHeroReadyAfternoonTitle
    case homeHeroReadyEveningTitle
    case homeHeroReadyLateNightTitle
    case homeHeroReadyMorningCTA
    case homeHeroReadyLunchCTA
    case homeHeroReadyAfternoonCTA
    case homeHeroReadyEveningCTA
    case homeHeroReadyLateNightCTA
    case homeHeroReadySubtitleSingularFormat
    case homeHeroReadySubtitlePluralFormat
    case homeHeroAlmostReadyTitle
    case homeHeroAlmostReadySubtitleSingularFormat
    case homeHeroAlmostReadySubtitlePluralFormat
    case homeHeroSeasonalTitle
    case homeHeroSeasonalSubtitle
    case homeHeroAlmostReadyCTA
    case homeHeroSeasonalCTA
    case homeHeroSupportBestMatchFormat
    case homeHeroSupportOneMissingFormat
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
    case quickActionCookNowFromFridge
    case quickActionYouHaveEverything
    case cookNowAction
    case quickActionOnlyOneIngredientMissing
    case quickActionOnlyIngredientsMissingFormat
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
    case homeHookOneIngredientMissing
    case homeHookTrendingFallback
    case mediaAddPhotos
    case mediaUseCamera
    case mediaNoImagesYet
    case mediaCoverTag
    case mediaSetCover
    case mediaRemoveImage
    case watchVideo
    case openOnInstagram
    case openOnTikTok
    case openOriginalRecipe
    case sourceAttributionLabel
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
    case recipeDetailAllMissingHandled
    case recipeDetailStillMissingItemsFormat
    case recipeDetailEverythingElseInList
    case recipeDetailIngredientsInList
    case noMissingIngredients
    case cookAction
    case viewRecipeAction
    case addMissingAction
    case readyNow
    case crispyAction
    case addedMissingItemsFormat
    case commonOK
    case cameraUnavailableTitle
    case cameraUnavailableMessage
    case socialImportConnectAccountsHint
    case socialImportNoEligiblePostsHint
    case socialImportOwnAccountOnly
    case socialImportProviderLabel
    case connectedAccounts
    case connectAction
    case unlinkAction
    case authErrorTitle
    case authOAuthNotConfiguredInstagram
    case authOAuthNotConfiguredTikTok
    case authOAuthNotConfiguredApple
    case authMissingApplePresentationAnchor
    case authCancelled
    case authFailedInstagram
    case authFailedTikTok
    case authFailedApple
    case recipeTimingHeading
    case recipeTimingExplainPerfectNow
    case recipeTimingExplainGoodNow
    case recipeTimingExplainBetterSoon
    case recipeTimingExplainEndingSoon
    case seedAttributionViaFormat
    case nutritionTotalForServingsFormat
    case userBadgeSeasonStarter
    case userBadgeFreshCook
    case userBadgeCrispyCreator
    case userBadgeTopSeasonal
    case supabaseTestSectionTitle
    case supabaseTestDescription
    case supabaseEmailField
    case supabasePasswordField
    case supabaseRunTestAction
    case supabaseTestingInProgress
    case supabaseValidationSuccessFormat
    case supabaseValidationMissingProfileFormat
    case supabaseValidationFailedFormat
    case supabaseNotConfiguredFormat
}

struct AppLocalizer {
    let languageCode: String

    func text(_ key: AppTextKey) -> String {
        AppLocalizer.strings[languageCode]?[key]
        ?? AppLocalizer.strings["en"]?[key]
        ?? key.rawValue
    }

    func localized(_ key: String) -> String {
        let bundle = localizationBundle
        let localizedValue = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
        if localizedValue != key {
            return localizedValue
        }
        return NSLocalizedString(key, tableName: "Localizable", bundle: Bundle.main, value: key, comment: "")
    }

    var recipeDraftNotFoundTitle: String { localized("recipe.draft_not_found") }
    var recipeDraftNotFoundMessage: String { localized("recipe.draft_not_found_message") }
    var recipeSocialLinksSectionTitle: String { localized("recipe.social_links_section") }
    var recipeInstagramURLField: String { localized("recipe.instagram_url") }
    var recipeTikTokURLField: String { localized("recipe.tiktok_url") }
    var recipeAutomaticallyTranslated: String { localized("recipe.auto_translated") }
    var accountSocialProfilesTitle: String { localized("account.social_profiles.title") }
    var accountSocialProfilesInstagramUsername: String { localized("account.social_profiles.instagram_username") }
    var accountSocialProfilesTikTokUsername: String { localized("account.social_profiles.tiktok_username") }
    var accountSocialProfilesSaveAction: String { localized("account.social_profiles.save_action") }
    var accountSocialProfilesSaved: String { localized("account.social_profiles.saved") }
    var accountSocialProfilesSaveFailedFormat: String { localized("account.social_profiles.save_failed_format") }
    var accountCloudLanguageFormat: String { localized("account.cloud_language_format") }
    var commonSaving: String { localized("common.saving") }
    var commonInstagram: String { localized("common.instagram") }
    var commonTikTok: String { localized("common.tiktok") }
    var homeCookWithWhatYouHaveTitle: String { localized("home.cookWithWhatYouHave.title") }
    var homeCookWithWhatYouHaveSubtitle: String { localized("home.cookWithWhatYouHave.subtitle") }
    var homeCookWithWhatYouHaveCTA: String { localized("home.cookWithWhatYouHave.cta") }

    private var localizationBundle: Bundle {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
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
            return text(.userBadgeSeasonStarter)
        case .freshCook:
            return text(.userBadgeFreshCook)
        case .crispyCreator:
            return text(.userBadgeCrispyCreator)
        case .topSeasonal:
            return text(.userBadgeTopSeasonal)
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
            case .slice: return "fetta"
            case .clove: return "spicchio"
            case .tbsp: return "cucchiaio"
            case .tsp: return "cucchiaino"
            case .cup: return "tazza"
            }
        default:
            switch unit {
            case .g: return "g"
            case .ml: return "ml"
            case .piece: return "piece"
            case .slice: return "slice"
            case .clove: return "clove"
            case .tbsp: return "tbsp"
            case .tsp: return "tsp"
            case .cup: return "cup"
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
            .saveDraft: "Save draft",
            .saved: "Saved",
            .savedRecipes: "Saved recipes",
            .savedRecipesEmptySubtitle: "Save recipes to quickly find them later.",
            .removeSavedRecipe: "Remove saved",
            .follow: "Follow",
            .following: "Following",
            .followAuthorsHint: "Follow recipe authors to see personalized picks.",
            .followingFeedContextFormat: "%d recipes from %d creators you follow",
            .followingFeedEmptyTitle: "Follow creators to build your feed",
            .followingFeedEmptySubtitle: "Recipes from creators you follow will appear here first.",
            .followingFeedEmptyCTA: "Discover creators and recipes",
            .followingFeedFallbackLabel: "More recipes to discover",
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
            .servesFormat: "Serves %d",
            .minutesShort: "min",
            .profile: "Profile",
            .myRecipes: "My Recipes",
            .draftRecipes: "Drafts",
            .draftRecipesEmptySubtitle: "No drafts yet.",
            .untitledDraft: "Untitled draft",
            .draftSavedAtFormat: "Saved: %@",
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
            .socialCaptionImportPrompt: "Paste caption to auto-fill ingredients",
            .socialImportCaptionNudge: "Tip: paste the caption to improve ingredient extraction.",
            .importDraft: "Import draft",
            .importApplied: "Draft imported. Review and edit before publishing.",
            .importNoMatches: "No strong ingredient matches found. You can still edit manually.",
            .importWeakResultCaptionHint: "Paste the caption to extract ingredients automatically.",
            .importAnalyzing: "Analyzing import…",
            .importQualityHigh: "Recipe imported. Strong result — review before publishing.",
            .importQualityMedium: "Recipe imported. Good start — check ingredients and steps.",
            .importQualityLow: "Recipe imported as a starting draft — review carefully.",
            .importRateLimitCooldown: "You're doing that too quickly. Try again in a moment.",
            .importRateLimitDaily: "Daily import limit reached. Try again tomorrow.",
            .recipePublicSocialLinksHint: "Optional public links shown on the recipe page. These are not used for import.",
            .importOwnContentOnlyHint: "Import draft works only with your own eligible posts from connected Instagram/TikTok accounts.",
            .socialImportSelectEligiblePostHint: "Select one eligible post URL from your connected account to enable import.",
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
            .followersCountFormat: "%d followers",
            .followers: "Followers",
            .publishedRecipes: "Published recipes",
            .creatorProfileSubtitle: "Season creator",
            .previewPublicProfile: "Preview public profile",
            .comingSoon: "Coming soon",
            .crispyCountFormat: "%d crispy",
            .totalCrispyReceivedFormat: "%d crispy received",
            .averageSeasonalMatchFormat: "%.0f%% average seasonal match",
            .badges: "Badges",
            .noBadgesYet: "Start sharing seasonal recipes to unlock badges.",
            .freshScoreExcellent: "Excellent",
            .freshScoreGreat: "Great",
            .freshScoreGood: "Good",
            .recipeNutritionSummaryTitle: "Recipe nutrition (per serving)",
            .recipeNutritionPerServingBasisFormat: "Based on %d servings",
            .recipeNutritionEstimatedNote: "Estimated values per serving using ingredient nutrition per 100 g.",
            .createRecipeSubtitle: "Recipe creation editor is coming soon.",
            .publishFailedTitle: "Publish failed",
            .publishFailedMessage: "We couldn't publish your recipe right now. Please try again.",
            .publishAuthRequiredMessage: "Sign in to publish recipes.",
            .done: "Done",
            .homeHeroSubtitle: "Seasonal recipes and ingredients picked for you",
            .homeHeroQuestion: "Cook something fresh today",
            .homeHeroReadyMorningTitle: "Fresh start ideas",
            .homeHeroReadyLunchTitle: "Ready for lunch",
            .homeHeroReadyAfternoonTitle: "Quick bites",
            .homeHeroReadyEveningTitle: "Dinner is ready",
            .homeHeroReadyLateNightTitle: "Late night bites",
            .homeHeroReadyMorningCTA: "See fresh ideas",
            .homeHeroReadyLunchCTA: "See lunch ideas",
            .homeHeroReadyAfternoonCTA: "See quick bites",
            .homeHeroReadyEveningCTA: "See dinner ideas",
            .homeHeroReadyLateNightCTA: "See late bites",
            .homeHeroReadySubtitleSingularFormat: "%d recipe is ready with your fridge",
            .homeHeroReadySubtitlePluralFormat: "%d recipes are ready with your fridge",
            .homeHeroAlmostReadyTitle: "Almost ready meals",
            .homeHeroAlmostReadySubtitleSingularFormat: "%d recipe needs just 1 ingredient",
            .homeHeroAlmostReadySubtitlePluralFormat: "%d recipes need just 1 ingredient",
            .homeHeroSeasonalTitle: "Perfect ingredients today",
            .homeHeroSeasonalSubtitle: "Best recipes in season right now",
            .homeHeroAlmostReadyCTA: "See quick wins",
            .homeHeroSeasonalCTA: "Explore seasonal picks",
            .homeHeroSupportBestMatchFormat: "Best match: %@",
            .homeHeroSupportOneMissingFormat: "1 ingredient missing for %@",
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
            .quickActionCookNowFromFridge: "Cook now from your fridge",
            .quickActionYouHaveEverything: "You have everything",
            .cookNowAction: "Cook now",
            .quickActionOnlyOneIngredientMissing: "Only 1 ingredient missing",
            .quickActionOnlyIngredientsMissingFormat: "Only %d ingredients missing",
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
            .homeHookOneIngredientMissing: "1 ingredient missing",
            .homeHookTrendingFallback: "Trending now",
            .mediaAddPhotos: "Add photos",
            .mediaUseCamera: "Use camera",
            .mediaNoImagesYet: "No images selected yet.",
            .mediaCoverTag: "Cover",
            .mediaSetCover: "Set cover",
            .mediaRemoveImage: "Remove image",
            .watchVideo: "Watch video",
            .openOnInstagram: "Open on Instagram",
            .openOnTikTok: "Open on TikTok",
            .openOriginalRecipe: "Open original recipe",
            .sourceAttributionLabel: "Source",
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
            .recipeDetailAllMissingHandled: "All missing items handled",
            .recipeDetailStillMissingItemsFormat: "%d still missing",
            .recipeDetailEverythingElseInList: "Everything else is already in your shopping list",
            .recipeDetailIngredientsInList: "Ingredients in your list",
            .noMissingIngredients: "No missing ingredients",
            .cookAction: "Cook",
            .viewRecipeAction: "View recipe",
            .addMissingAction: "Add missing",
            .readyNow: "Ready now",
            .crispyAction: "Crispy",
            .addedMissingItemsFormat: "Added %d missing ingredients",
            .commonOK: "OK",
            .cameraUnavailableTitle: "Camera Unavailable",
            .cameraUnavailableMessage: "This device does not have an available camera. You can still add photos from your library.",
            .socialImportConnectAccountsHint: "Connect TikTok or Instagram in Account to import your own content.",
            .socialImportNoEligiblePostsHint: "No eligible posts found for this account. Add your own post URLs in Account.",
            .socialImportOwnAccountOnly: "Import only works from your connected account content.",
            .socialImportProviderLabel: "Provider",
            .connectedAccounts: "Connected accounts",
            .connectAction: "Connect",
            .unlinkAction: "Unlink",
            .authErrorTitle: "Authentication Error",
            .authOAuthNotConfiguredInstagram: "Instagram OAuth is not configured yet.",
            .authOAuthNotConfiguredTikTok: "TikTok OAuth is not configured yet.",
            .authOAuthNotConfiguredApple: "Apple Sign In is not configured yet.",
            .authMissingApplePresentationAnchor: "Unable to start Apple Sign In on this screen.",
            .authCancelled: "Authentication was cancelled.",
            .authFailedInstagram: "Instagram authentication failed.",
            .authFailedTikTok: "TikTok authentication failed.",
            .authFailedApple: "Apple authentication failed.",
            .recipeTimingHeading: "Timing",
            .recipeTimingExplainPerfectNow: "This recipe is at its best seasonal moment right now.",
            .recipeTimingExplainGoodNow: "This recipe is a good choice now, even if some ingredients are not at peak season.",
            .recipeTimingExplainBetterSoon: "This recipe will become more seasonal in the coming weeks.",
            .recipeTimingExplainEndingSoon: "This recipe is still good now, but some ingredients are moving out of season.",
            .seedAttributionViaFormat: "via %@",
            .nutritionTotalForServingsFormat: "Total (%d servings)",
            .userBadgeSeasonStarter: "Season Starter",
            .userBadgeFreshCook: "Fresh Cook",
            .userBadgeCrispyCreator: "Crispy Creator",
            .userBadgeTopSeasonal: "Top Seasonal",
            .supabaseTestSectionTitle: "Supabase auth test",
            .supabaseTestDescription: "Runs a minimal auth test and validates auth.users -> profiles pipeline.",
            .supabaseEmailField: "Email",
            .supabasePasswordField: "Password",
            .supabaseRunTestAction: "Run test",
            .supabaseTestingInProgress: "Testing...",
            .supabaseValidationSuccessFormat: "Auth OK for %1$@. Profile row found for user %2$@.",
            .supabaseValidationMissingProfileFormat: "Auth OK for %1$@. No profile row found yet for user %2$@.",
            .supabaseValidationFailedFormat: "Supabase test failed: %@",
            .supabaseNotConfiguredFormat: "Supabase is not configured: %@"
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
            .saveDraft: "Salva bozza",
            .saved: "Salvata",
            .savedRecipes: "Ricette salvate",
            .savedRecipesEmptySubtitle: "Salva ricette per ritrovarle velocemente.",
            .removeSavedRecipe: "Rimuovi salvata",
            .follow: "Segui",
            .following: "Segui gia",
            .followAuthorsHint: "Segui gli autori per vedere suggerimenti personalizzati.",
            .followingFeedContextFormat: "%d ricette da %d creator che segui",
            .followingFeedEmptyTitle: "Segui creator per costruire il tuo feed",
            .followingFeedEmptySubtitle: "Le ricette dei creator che segui appariranno prima qui.",
            .followingFeedEmptyCTA: "Scopri creator e ricette",
            .followingFeedFallbackLabel: "Altre ricette da scoprire",
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
            .servesFormat: "Per %d persone",
            .minutesShort: "min",
            .profile: "Profilo",
            .myRecipes: "Le mie ricette",
            .draftRecipes: "Bozze",
            .draftRecipesEmptySubtitle: "Nessuna bozza disponibile.",
            .untitledDraft: "Bozza senza titolo",
            .draftSavedAtFormat: "Salvata: %@",
            .createRecipe: "Crea ricetta",
            .archiveRecipe: "Archivia",
            .restoreRecipe: "Ripristina",
            .deleteRecipe: "Elimina",
            .archivedRecipes: "Ricette archiviate",
            .archivedRecipesEmptySubtitle: "Nessuna ricetta archiviata.",
            .viewsCountFormat: "%d visualizzazioni",
            .viewsLabel: "visite",
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
            .socialCaptionImportPrompt: "Incolla la caption per compilare automaticamente gli ingredienti",
            .socialImportCaptionNudge: "Suggerimento: incolla la caption per migliorare l'estrazione degli ingredienti.",
            .importDraft: "Importa bozza",
            .importApplied: "Bozza importata. Controlla e modifica prima di pubblicare.",
            .importNoMatches: "Nessuna corrispondenza ingredienti forte. Puoi modificare manualmente.",
            .importWeakResultCaptionHint: "Incolla la caption per estrarre automaticamente gli ingredienti.",
            .importAnalyzing: "Analisi importazione in corso…",
            .importQualityHigh: "Ricetta importata. Risultato solido — controlla prima di pubblicare.",
            .importQualityMedium: "Ricetta importata. Buona base — controlla ingredienti e passaggi.",
            .importQualityLow: "Ricetta importata come bozza iniziale — rivedi con attenzione.",
            .importRateLimitCooldown: "Lo stai facendo troppo rapidamente. Riprova tra un attimo.",
            .importRateLimitDaily: "Limite giornaliero import raggiunto. Riprova domani.",
            .recipePublicSocialLinksHint: "Link pubblici opzionali mostrati nella ricetta. Non vengono usati per l'importazione.",
            .importOwnContentOnlyHint: "Importa bozza funziona solo con post idonei del tuo account Instagram/TikTok collegato.",
            .socialImportSelectEligiblePostHint: "Seleziona un URL post idoneo del tuo account collegato per abilitare l'importazione.",
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
            .followersCountFormat: "%d follower",
            .followers: "Follower",
            .publishedRecipes: "Ricette pubblicate",
            .creatorProfileSubtitle: "Creator Season",
            .previewPublicProfile: "Anteprima profilo pubblico",
            .comingSoon: "In arrivo",
            .crispyCountFormat: "%d crispy",
            .totalCrispyReceivedFormat: "%d crispy ricevuti",
            .averageSeasonalMatchFormat: "Compatibilita stagionale media: %.0f%%",
            .badges: "Badge",
            .noBadgesYet: "Inizia a condividere ricette stagionali per sbloccare i badge.",
            .freshScoreExcellent: "Excellent",
            .freshScoreGreat: "Great",
            .freshScoreGood: "Good",
            .recipeNutritionSummaryTitle: "Nutrizione ricetta (per porzione)",
            .recipeNutritionPerServingBasisFormat: "Basato su %d porzioni",
            .recipeNutritionEstimatedNote: "Valori stimati per porzione, calcolati da nutrienti per 100 g.",
            .createRecipeSubtitle: "L'editor ricette completo arrivera presto.",
            .publishFailedTitle: "Pubblicazione non riuscita",
            .publishFailedMessage: "Non siamo riusciti a pubblicare la ricetta adesso. Riprova.",
            .publishAuthRequiredMessage: "Accedi per pubblicare ricette.",
            .done: "Fine",
            .homeHeroSubtitle: "Ricette e ingredienti stagionali scelti per te",
            .homeHeroQuestion: "Cucina qualcosa di fresco oggi",
            .homeHeroReadyMorningTitle: "Idee fresche per iniziare",
            .homeHeroReadyLunchTitle: "Pronto per pranzo",
            .homeHeroReadyAfternoonTitle: "Bocconi veloci",
            .homeHeroReadyEveningTitle: "La cena e servita",
            .homeHeroReadyLateNightTitle: "Spuntini notturni",
            .homeHeroReadyMorningCTA: "Vedi idee fresche",
            .homeHeroReadyLunchCTA: "Vedi idee pranzo",
            .homeHeroReadyAfternoonCTA: "Vedi bocconi veloci",
            .homeHeroReadyEveningCTA: "Vedi idee cena",
            .homeHeroReadyLateNightCTA: "Vedi spuntini notturni",
            .homeHeroReadySubtitleSingularFormat: "%d ricetta e pronta con il tuo frigo",
            .homeHeroReadySubtitlePluralFormat: "%d ricette sono pronte con il tuo frigo",
            .homeHeroAlmostReadyTitle: "Pasti quasi pronti",
            .homeHeroAlmostReadySubtitleSingularFormat: "%d ricetta richiede solo 1 ingrediente",
            .homeHeroAlmostReadySubtitlePluralFormat: "%d ricette richiedono solo 1 ingrediente",
            .homeHeroSeasonalTitle: "Ingredienti perfetti oggi",
            .homeHeroSeasonalSubtitle: "Le migliori ricette di stagione in questo momento",
            .homeHeroAlmostReadyCTA: "Vedi vittorie rapide",
            .homeHeroSeasonalCTA: "Esplora scelte stagionali",
            .homeHeroSupportBestMatchFormat: "Miglior abbinamento: %@",
            .homeHeroSupportOneMissingFormat: "Manca 1 ingrediente per %@",
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
            .quickActionCookNowFromFridge: "Cucina ora dal tuo frigo",
            .quickActionYouHaveEverything: "Hai tutto",
            .cookNowAction: "Cucina ora",
            .quickActionOnlyOneIngredientMissing: "Manca solo 1 ingrediente",
            .quickActionOnlyIngredientsMissingFormat: "Mancano solo %d ingredienti",
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
            .homeHookOneIngredientMissing: "Manca 1 ingrediente",
            .homeHookTrendingFallback: "Di tendenza",
            .mediaAddPhotos: "Aggiungi foto",
            .mediaUseCamera: "Usa fotocamera",
            .mediaNoImagesYet: "Nessuna immagine selezionata.",
            .mediaCoverTag: "Copertina",
            .mediaSetCover: "Imposta copertina",
            .mediaRemoveImage: "Rimuovi immagine",
            .watchVideo: "Guarda video",
            .openOnInstagram: "Apri su Instagram",
            .openOnTikTok: "Apri su TikTok",
            .openOriginalRecipe: "Apri ricetta originale",
            .sourceAttributionLabel: "Fonte",
            .detectedPlatformFormat: "Rilevato: %@",
            .fromRecipeFormat: "Da %@",
            .recipeTimingPerfectNow: "Perfetta ora",
            .recipeTimingBetterSoon: "Fuori stagione",
            .recipeTimingEndingSoon: "Sta finendo",
            .recipeTimingGoodNow: "Perfetta ora",
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
            .recipeDetailAllMissingHandled: "Tutti gli ingredienti mancanti sono gestiti",
            .recipeDetailStillMissingItemsFormat: "%d ancora mancanti",
            .recipeDetailEverythingElseInList: "Tutto il resto e gia nella tua lista della spesa",
            .recipeDetailIngredientsInList: "Ingredienti nella tua lista",
            .noMissingIngredients: "Nessun ingrediente mancante",
            .cookAction: "Cucina",
            .viewRecipeAction: "Vedi ricetta",
            .addMissingAction: "Aggiungi mancanti",
            .readyNow: "Pronta ora",
            .crispyAction: "Crispy",
            .addedMissingItemsFormat: "Aggiunti %d ingredienti mancanti",
            .commonOK: "OK",
            .cameraUnavailableTitle: "Fotocamera non disponibile",
            .cameraUnavailableMessage: "Questo dispositivo non ha una fotocamera disponibile. Puoi comunque aggiungere foto dalla libreria.",
            .socialImportConnectAccountsHint: "Collega TikTok o Instagram in Account per importare i tuoi contenuti.",
            .socialImportNoEligiblePostsHint: "Nessun post idoneo trovato per questo account. Aggiungi i tuoi URL post in Account.",
            .socialImportOwnAccountOnly: "L'importazione funziona solo dai contenuti del tuo account collegato.",
            .socialImportProviderLabel: "Provider",
            .connectedAccounts: "Account collegati",
            .connectAction: "Collega",
            .unlinkAction: "Scollega",
            .authErrorTitle: "Errore di autenticazione",
            .authOAuthNotConfiguredInstagram: "OAuth Instagram non è ancora configurato.",
            .authOAuthNotConfiguredTikTok: "OAuth TikTok non è ancora configurato.",
            .authOAuthNotConfiguredApple: "Sign in with Apple non è ancora configurato.",
            .authMissingApplePresentationAnchor: "Impossibile avviare Sign in with Apple in questa schermata.",
            .authCancelled: "Autenticazione annullata.",
            .authFailedInstagram: "Autenticazione Instagram non riuscita.",
            .authFailedTikTok: "Autenticazione TikTok non riuscita.",
            .authFailedApple: "Autenticazione Apple non riuscita.",
            .recipeTimingHeading: "Tempistica",
            .recipeTimingExplainPerfectNow: "Questa ricetta è nel suo momento stagionale migliore proprio ora.",
            .recipeTimingExplainGoodNow: "Questa ricetta è una buona scelta ora, anche se alcuni ingredienti non sono al picco stagionale.",
            .recipeTimingExplainBetterSoon: "Questa ricetta diventerà più stagionale nelle prossime settimane.",
            .recipeTimingExplainEndingSoon: "Questa ricetta è ancora valida ora, ma alcuni ingredienti stanno uscendo di stagione.",
            .seedAttributionViaFormat: "via %@",
            .nutritionTotalForServingsFormat: "Totale (%d porzioni)",
            .userBadgeSeasonStarter: "Season Starter",
            .userBadgeFreshCook: "Fresh Cook",
            .userBadgeCrispyCreator: "Crispy Creator",
            .userBadgeTopSeasonal: "Top Seasonal",
            .supabaseTestSectionTitle: "Test auth Supabase",
            .supabaseTestDescription: "Esegue un test auth minimo e valida la pipeline auth.users -> profiles.",
            .supabaseEmailField: "Email",
            .supabasePasswordField: "Password",
            .supabaseRunTestAction: "Esegui test",
            .supabaseTestingInProgress: "Test in corso...",
            .supabaseValidationSuccessFormat: "Auth OK per %1$@. Riga profilo trovata per l'utente %2$@.",
            .supabaseValidationMissingProfileFormat: "Auth OK per %1$@. Nessuna riga profilo trovata per l'utente %2$@.",
            .supabaseValidationFailedFormat: "Test Supabase fallito: %@",
            .supabaseNotConfiguredFormat: "Supabase non configurato: %@"
        ]
    ]

    func itemsInSeasonText(inSeasonCount: Int, totalCount: Int) -> String {
        let format = text(.itemsInSeasonFormat)
        return String(format: format, inSeasonCount, totalCount)
    }
}
