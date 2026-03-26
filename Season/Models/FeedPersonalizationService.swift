import Foundation

struct FeedPersonalizationEvaluation {
    let adjustment: Double
    let reasons: [String]
}

struct FeedPersonalizationProfile {
    let quickRecipePreference: Double
    let seasonalPreference: Double
    let creatorAffinity: [String: Double]
    let fridgeActionAffinity: Double
    let savedCrispiedAffinity: Double
    let recentlyOpenedAtByRecipeID: [String: Date]
    let recentViewCountByRecipeID: [String: Int]
    let recentTouchedRecipeIDs: Set<String>

    var isActive: Bool {
        quickRecipePreference > 0.01
            || seasonalPreference > 0.01
            || fridgeActionAffinity > 0.01
            || savedCrispiedAffinity > 0.01
            || !creatorAffinity.isEmpty
            || !recentTouchedRecipeIDs.isEmpty
    }

    func evaluation(
        for ranked: RankedRecipe,
        fridgeMatchScore: Double,
        now: Date = Date()
    ) -> FeedPersonalizationEvaluation {
        let recipe = ranked.recipe
        var adjustment = 0.0
        var reasons: [String] = []

        let totalMinutes = (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0)
        let quickness = totalMinutes > 0 ? max(0.0, 1.0 - (Double(totalMinutes) / 35.0)) : 0.25
        let seasonal = Double(ranked.seasonalMatchPercent) / 100.0

        let quickBoost = 0.10 * quickRecipePreference * quickness
        if quickBoost > 0.015 {
            adjustment += quickBoost
            reasons.append("quick")
        }

        let seasonalBoost = 0.09 * seasonalPreference * seasonal
        if seasonalBoost > 0.015 {
            adjustment += seasonalBoost
            reasons.append("seasonal")
        }

        if let creatorID = recipe.canonicalCreatorID,
           let creatorStrength = creatorAffinity[creatorID],
           creatorStrength > 0 {
            let creatorBoost = min(0.08, 0.08 * creatorStrength)
            adjustment += creatorBoost
            reasons.append("creator")
        }

        let crispySignal = min(1.0, max(0.0, Double(recipe.crispy) / 160.0))
        let affinityBoost = 0.07 * savedCrispiedAffinity * crispySignal
        if affinityBoost > 0.01 {
            adjustment += affinityBoost
            reasons.append("engagement")
        }

        let fridgeBoost = 0.08 * fridgeActionAffinity * max(0.0, fridgeMatchScore)
        if fridgeBoost > 0.012 {
            adjustment += fridgeBoost
            reasons.append("fridge")
        }

        if !recentTouchedRecipeIDs.contains(recipe.id) {
            adjustment += 0.018
            reasons.append("explore")
        }

        if let openedAt = recentlyOpenedAtByRecipeID[recipe.id] {
            let age = now.timeIntervalSince(openedAt)
            if age < 6 * 3600 {
                adjustment -= 0.22
                reasons.append("cooldown_opened_6h")
            } else if age < 24 * 3600 {
                adjustment -= 0.12
                reasons.append("cooldown_opened_24h")
            }
        }

        if let views = recentViewCountByRecipeID[recipe.id], views >= 3 {
            let viewPenalty = min(0.14, Double(views - 2) * 0.04)
            adjustment -= viewPenalty
            reasons.append("cooldown_views")
        }

        return FeedPersonalizationEvaluation(
            adjustment: min(0.20, max(-0.30, adjustment)),
            reasons: reasons
        )
    }
}

final class FeedPersonalizationService {
    static let shared = FeedPersonalizationService()

    func buildProfile(
        from rankedRecipes: [RankedRecipe],
        recentEventLimit: Int = 100
    ) -> FeedPersonalizationProfile {
        let recipeLookup = Dictionary(uniqueKeysWithValues: rankedRecipes.map { ($0.recipe.id, $0) })
        let events = Array(UserInteractionTracker.shared.recentEvents().suffix(max(1, recentEventLimit)))

        var weightedRecipeSignalTotal = 0.0
        var quickWeightedSum = 0.0
        var seasonalWeightedSum = 0.0
        var creatorWeights: [String: Double] = [:]
        var savedCrispySignal = 0.0
        var fridgeActionSignal = 0.0
        var recentlyOpenedAtByRecipeID: [String: Date] = [:]
        var recentViewCountByRecipeID: [String: Int] = [:]
        var recentTouchedRecipeIDs: Set<String> = []

        for event in events {
            switch event.eventType {
            case .produceAddedToFridge, .produceRemovedFromFridge:
                fridgeActionSignal += 1.0
            case .recipeAddedToList:
                fridgeActionSignal += 0.65
            default:
                break
            }

            guard let recipeID = event.recipeID else { continue }
            recentTouchedRecipeIDs.insert(recipeID)

            if event.eventType == .recipeOpened {
                let current = recentlyOpenedAtByRecipeID[recipeID] ?? .distantPast
                if event.timestamp > current {
                    recentlyOpenedAtByRecipeID[recipeID] = event.timestamp
                }
            }
            if event.eventType == .recipeViewed {
                recentViewCountByRecipeID[recipeID, default: 0] += 1
            }

            guard let ranked = recipeLookup[recipeID] else { continue }
            let weight = eventWeight(for: event.eventType)
            guard weight > 0 else { continue }

            weightedRecipeSignalTotal += weight

            let totalMinutes = (ranked.recipe.prepTimeMinutes ?? 0) + (ranked.recipe.cookTimeMinutes ?? 0)
            let quickness = totalMinutes > 0 ? max(0.0, 1.0 - (Double(totalMinutes) / 35.0)) : 0.25
            quickWeightedSum += quickness * weight

            let seasonal = Double(ranked.seasonalMatchPercent) / 100.0
            seasonalWeightedSum += seasonal * weight

            if let creatorID = ranked.recipe.canonicalCreatorID {
                creatorWeights[creatorID, default: 0] += weight
            }

            if event.eventType == .recipeSaved || event.eventType == .recipeCrispied {
                savedCrispySignal += weight
            }
        }

        let quickPreference = weightedRecipeSignalTotal > 0 ? quickWeightedSum / weightedRecipeSignalTotal : 0
        let seasonalPreference = weightedRecipeSignalTotal > 0 ? seasonalWeightedSum / weightedRecipeSignalTotal : 0
        let savedCrispiedAffinity = weightedRecipeSignalTotal > 0
            ? min(1.0, savedCrispySignal / max(1.0, weightedRecipeSignalTotal))
            : 0
        let fridgeActionAffinity = min(1.0, fridgeActionSignal / max(3.0, Double(events.count)))

        let maxCreatorWeight = creatorWeights.values.max() ?? 0
        let normalizedCreatorWeights: [String: Double]
        if maxCreatorWeight > 0 {
            normalizedCreatorWeights = creatorWeights.mapValues { $0 / maxCreatorWeight }
        } else {
            normalizedCreatorWeights = [:]
        }

        return FeedPersonalizationProfile(
            quickRecipePreference: min(1.0, max(0.0, quickPreference)),
            seasonalPreference: min(1.0, max(0.0, seasonalPreference)),
            creatorAffinity: normalizedCreatorWeights,
            fridgeActionAffinity: fridgeActionAffinity,
            savedCrispiedAffinity: savedCrispiedAffinity,
            recentlyOpenedAtByRecipeID: recentlyOpenedAtByRecipeID,
            recentViewCountByRecipeID: recentViewCountByRecipeID,
            recentTouchedRecipeIDs: recentTouchedRecipeIDs
        )
    }

    private func eventWeight(for type: UserInteractionEventType) -> Double {
        switch type {
        case .recipeOpened:
            return 1.0
        case .recipeSaved:
            return 1.25
        case .recipeCrispied:
            return 1.20
        case .recipeAddedToList:
            return 1.10
        case .recipeViewed:
            return 0.45
        case .produceAddedToFridge, .produceRemovedFromFridge:
            return 0
        }
    }
}
