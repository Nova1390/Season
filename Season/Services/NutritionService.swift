import Foundation

final class NutritionService {
    struct Context {
        let produceItems: [ProduceItem]
        let discoverableRecipes: [Recipe]
        let produceByID: [String: ProduceItem]
        let basicByID: [String: BasicIngredient]
        let basicByNormalizedName: [String: BasicIngredient]
        let fallbackUnitProfile: IngredientUnitProfile
        let quantityProfileForProduceID: (String) -> IngredientUnitProfile
    }

    private struct DietarySupport {
        let glutenFree: Bool?
        let vegetarian: Bool?
        let vegan: Bool?
    }

    private var cachedRecipeNutritionSummaries: [String: RecipeNutritionSummary?] = [:]
    private var cachedMaxRecipeNutritionValues: [NutritionPriorityDimension: Double] = [:]
    private var cachedMaxProduceNutritionValues: [NutritionPriorityDimension: Double] = [:]

    func invalidateCaches() {
        cachedRecipeNutritionSummaries.removeAll(keepingCapacity: true)
        cachedMaxRecipeNutritionValues.removeAll(keepingCapacity: true)
        cachedMaxProduceNutritionValues.removeAll(keepingCapacity: true)
    }

    func recipeNutritionSummary(for recipe: Recipe, context: Context) -> RecipeNutritionSummary? {
        if let cached = cachedRecipeNutritionSummaries[recipe.id] {
            return cached
        }

        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalFiber = 0.0
        var totalVitaminC = 0.0
        var totalPotassium = 0.0
        var hasAnyNutritionData = false

        for ingredient in recipe.ingredients {
            let nutritionInfo = nutritionInfo(for: ingredient, context: context)
            guard let nutrition = nutritionInfo.nutrition else { continue }
            hasAnyNutritionData = true

            let grams = quantityInGrams(
                value: ingredient.quantityValue,
                unit: ingredient.quantityUnit,
                profile: nutritionInfo.unitProfile
            )
            let factor = grams / 100.0

            totalCalories += Double(nutrition.calories) * factor
            totalProtein += nutrition.protein * factor
            totalCarbs += nutrition.carbs * factor
            totalFat += nutrition.fat * factor
            totalFiber += nutrition.fiber * factor
            totalVitaminC += nutrition.vitaminC * factor
            totalPotassium += nutrition.potassium * factor
        }

        guard hasAnyNutritionData else {
            cachedRecipeNutritionSummaries[recipe.id] = nil
            return nil
        }

        let summary = RecipeNutritionSummary(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            vitaminC: totalVitaminC,
            potassium: totalPotassium
        )
        cachedRecipeNutritionSummaries[recipe.id] = summary
        return summary
    }

    func nutritionPreferenceScore(
        for recipe: Recipe,
        priorities: [NutritionPriorityDimension: Double],
        context: Context
    ) -> Double {
        guard let summary = recipeNutritionSummary(for: recipe, context: context) else { return 0 }
        let weightedDimensions = priorities.filter { $0.value > 0.0001 }
        guard !weightedDimensions.isEmpty else { return 0 }

        var weightedScore = 0.0
        var totalWeight = 0.0
        for (dimension, weight) in weightedDimensions {
            let normalized = normalizedRecipeNutritionValue(
                for: dimension,
                summary: summary,
                priorities: priorities,
                context: context
            )
            weightedScore += normalized * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0 }
        return min(1.0, max(0.0, weightedScore / totalWeight))
    }

    func nutritionScore(
        for item: ProduceItem,
        priorities: [NutritionPriorityDimension: Double],
        produceItems: [ProduceItem]
    ) -> Double {
        guard let nutrition = item.nutrition else { return 0 }
        let weightedDimensions = priorities.filter { $0.value > 0.0001 }
        guard !weightedDimensions.isEmpty else { return 0 }

        var weightedScore = 0.0
        var totalWeight = 0.0

        for (dimension, weight) in weightedDimensions {
            let normalized = normalizedNutritionValue(
                for: dimension,
                nutrition: nutrition,
                produceItems: produceItems
            )
            weightedScore += normalized * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        return min(1.0, max(0.0, weightedScore / totalWeight))
    }

    func rankingReasons(
        for item: ProduceItem,
        priorities: [NutritionPriorityDimension: Double],
        localizer: AppLocalizer,
        produceItems: [ProduceItem]
    ) -> [String] {
        guard let nutrition = item.nutrition else {
            return [localizer.text(.reasonInSeasonNow)]
        }

        var reasons: [String] = []
        let topPriorities = priorities
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .filter { $0.value > 0.05 }
            .prefix(2)

        for (dimension, _) in topPriorities {
            let normalized = normalizedNutritionValue(
                for: dimension,
                nutrition: nutrition,
                produceItems: produceItems
            )
            guard normalized >= 0.55 else { continue }
            reasons.append(reasonText(for: dimension, localizer: localizer))
        }

        if reasons.isEmpty {
            reasons.append(localizer.text(.reasonInSeasonNow))
        }

        return Array(reasons.prefix(2))
    }

    func normalizedRecipeNutritionValue(
        for dimension: NutritionPriorityDimension,
        summary: RecipeNutritionSummary,
        priorities: [NutritionPriorityDimension: Double],
        context: Context
    ) -> Double {
        let value: Double
        switch dimension {
        case .protein:
            value = summary.protein
        case .carbs:
            value = summary.carbs
        case .fat:
            value = summary.fat
        case .fiber:
            value = summary.fiber
        case .vitaminC:
            value = summary.vitaminC
        case .potassium:
            value = summary.potassium
        }

        let maxValue = maxRecipeNutritionValue(for: dimension, priorities: priorities, context: context)
        guard maxValue > 0 else { return 0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    func maxRecipeNutritionValue(
        for dimension: NutritionPriorityDimension,
        priorities: [NutritionPriorityDimension: Double],
        context: Context
    ) -> Double {
        if let cached = cachedMaxRecipeNutritionValues[dimension] {
            return cached
        }
        let values: [Double] = context.discoverableRecipes.compactMap { recipe in
            guard let summary = recipeNutritionSummary(for: recipe, context: context) else { return nil }
            switch dimension {
            case .protein:
                return summary.protein
            case .carbs:
                return summary.carbs
            case .fat:
                return summary.fat
            case .fiber:
                return summary.fiber
            case .vitaminC:
                return summary.vitaminC
            case .potassium:
                return summary.potassium
            }
        }
        let maxValue = max(0.0001, values.max() ?? 0.0001)
        cachedMaxRecipeNutritionValues[dimension] = maxValue
        return maxValue
    }

    func normalizedNutritionValue(
        for dimension: NutritionPriorityDimension,
        nutrition: ProduceNutrition,
        produceItems: [ProduceItem]
    ) -> Double {
        let value: Double
        switch dimension {
        case .protein:
            value = nutrition.protein
        case .carbs:
            value = nutrition.carbs
        case .fat:
            value = nutrition.fat
        case .fiber:
            value = nutrition.fiber
        case .vitaminC:
            value = nutrition.vitaminC
        case .potassium:
            value = nutrition.potassium
        }

        let maxValue = maxNutritionValue(for: dimension, produceItems: produceItems)
        guard maxValue > 0 else { return 0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    func maxNutritionValue(
        for dimension: NutritionPriorityDimension,
        produceItems: [ProduceItem]
    ) -> Double {
        if let cached = cachedMaxProduceNutritionValues[dimension] {
            return cached
        }
        let values: [Double] = produceItems.compactMap { item in
            guard let nutrition = item.nutrition else { return nil }
            switch dimension {
            case .protein:
                return nutrition.protein
            case .carbs:
                return nutrition.carbs
            case .fat:
                return nutrition.fat
            case .fiber:
                return nutrition.fiber
            case .vitaminC:
                return nutrition.vitaminC
            case .potassium:
                return nutrition.potassium
            }
        }
        let maxValue = max(0.0001, values.max() ?? 0.0001)
        cachedMaxProduceNutritionValues[dimension] = maxValue
        return maxValue
    }

    func reasonText(for dimension: NutritionPriorityDimension, localizer: AppLocalizer) -> String {
        switch dimension {
        case .protein:
            return localizer.text(.reasonHighProtein)
        case .carbs:
            return localizer.text(.reasonHighCarbs)
        case .fat:
            return localizer.text(.reasonHighFat)
        case .fiber:
            return localizer.text(.reasonHighFiber)
        case .vitaminC:
            return localizer.text(.reasonHighVitaminC)
        case .potassium:
            return localizer.text(.reasonHighPotassium)
        }
    }

    func confirmedDietaryTags(
        forIngredients ingredients: [RecipeIngredient],
        context: Context
    ) -> [RecipeDietaryTag] {
        guard !ingredients.isEmpty else { return [] }

        var result: [RecipeDietaryTag] = []
        for tag in RecipeDietaryTag.allCases {
            let isConfirmedForAllIngredients = ingredients.allSatisfy { ingredient in
                let support = dietarySupport(for: ingredient, context: context)
                switch tag {
                case .glutenFree:
                    return support.glutenFree == true
                case .vegetarian:
                    return support.vegetarian == true
                case .vegan:
                    return support.vegan == true
                }
            }

            if isConfirmedForAllIngredients {
                result.append(tag)
            }
        }

        return result
    }

    static let defaultNutritionPriorities: [NutritionPriorityDimension: Double] = [
        .protein: 0.5,
        .carbs: 0.25,
        .fat: 0.25,
        .fiber: 0.6,
        .vitaminC: 0.45,
        .potassium: 0.35
    ]

    static func parseNutritionPriorities(from raw: String) -> [NutritionPriorityDimension: Double] {
        var parsed = defaultNutritionPriorities
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return parsed }

        if trimmed.contains(":") {
            for part in trimmed.split(separator: ",") {
                let pieces = part.split(separator: ":", maxSplits: 1).map(String.init)
                guard pieces.count == 2,
                      let dimension = NutritionPriorityDimension(rawValue: pieces[0]),
                      let value = Double(pieces[1]) else { continue }
                parsed[dimension] = min(1, max(0, value))
            }
            return parsed
        }

        let legacyGoals = Set(
            trimmed.split(separator: ",")
                .compactMap { NutritionGoal(rawValue: String($0)) }
        )

        if !legacyGoals.isEmpty {
            parsed = Dictionary(uniqueKeysWithValues: NutritionPriorityDimension.allCases.map { ($0, 0.0) })
            if legacyGoals.contains(.moreProtein) {
                parsed[.protein] = 1.0
            }
            if legacyGoals.contains(.moreFiber) {
                parsed[.fiber] = 1.0
            }
            if legacyGoals.contains(.moreVitaminC) {
                parsed[.vitaminC] = 1.0
            }
            if legacyGoals.contains(.lowerSugar) {
                parsed[.carbs] = 0.0
            }
        }

        return parsed
    }

    static func normalizedNutritionPrioritiesRaw(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> String {
        NutritionPriorityDimension.allCases
            .map { dimension in
                let value = min(1, max(0, priorities[dimension] ?? 0))
                return "\(dimension.rawValue):\(String(format: "%.2f", value))"
            }
            .joined(separator: ",")
    }

    static func legacyGoals(
        from priorities: [NutritionPriorityDimension: Double]
    ) -> Set<NutritionGoal> {
        var goals: Set<NutritionGoal> = []
        if (priorities[.protein] ?? 0) > 0.55 {
            goals.insert(.moreProtein)
        }
        if (priorities[.fiber] ?? 0) > 0.55 {
            goals.insert(.moreFiber)
        }
        if (priorities[.vitaminC] ?? 0) > 0.55 {
            goals.insert(.moreVitaminC)
        }
        if (priorities[.carbs] ?? 0) < 0.20 {
            goals.insert(.lowerSugar)
        }
        return goals
    }

    private func dietarySupport(for ingredient: RecipeIngredient, context: Context) -> DietarySupport {
        if ingredient.produceID != nil {
            return DietarySupport(glutenFree: true, vegetarian: true, vegan: true)
        }

        guard let basicID = ingredient.basicIngredientID else {
            return DietarySupport(glutenFree: nil, vegetarian: nil, vegan: nil)
        }

        if let basicIngredient = context.basicByID[basicID] {
            return DietarySupport(
                glutenFree: basicIngredient.dietaryFlags.isGlutenFree,
                vegetarian: basicIngredient.dietaryFlags.isVegetarian,
                vegan: basicIngredient.dietaryFlags.isVegan
            )
        }

        return DietarySupport(glutenFree: nil, vegetarian: nil, vegan: nil)
    }

    private func nutritionInfo(
        for ingredient: RecipeIngredient,
        context: Context
    ) -> (nutrition: ProduceNutrition?, unitProfile: IngredientUnitProfile) {
        if let produceID = ingredient.produceID,
           let item = context.produceByID[produceID] {
            return (item.nutrition, context.quantityProfileForProduceID(produceID))
        }

        if let basicID = ingredient.basicIngredientID,
           let basic = context.basicByID[basicID] {
            return (basic.nutrition, basic.unitProfile)
        }

        let normalizedName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let fallbackBasic = context.basicByNormalizedName[normalizedName] {
            return (fallbackBasic.nutrition, fallbackBasic.unitProfile)
        }

        return (nil, context.fallbackUnitProfile)
    }

    private func quantityInGrams(value: Double, unit: RecipeQuantityUnit, profile: IngredientUnitProfile) -> Double {
        let safeValue = max(0, value)
        guard safeValue > 0 else { return 0 }

        if unit == .g {
            return safeValue
        }

        if let grams = profile.gramsPerUnit[unit] {
            return safeValue * grams
        }

        if unit == .ml {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * gramsPerMl
        }

        if let ml = profile.mlPerUnit[unit] {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * ml * gramsPerMl
        }

        if let fallbackGrams = profile.gramsPerUnit[profile.defaultUnit] {
            return safeValue * fallbackGrams
        }

        if let fallbackMl = profile.mlPerUnit[profile.defaultUnit] {
            let gramsPerMl = profile.gramsPerMl ?? 1
            return safeValue * fallbackMl * gramsPerMl
        }

        return safeValue
    }
}
