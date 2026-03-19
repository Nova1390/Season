import Foundation

struct SocialImportSuggestion {
    let sourceURL: String?
    let sourcePlatform: SocialSourcePlatform?
    let sourceCaptionRaw: String?
    let suggestedTitle: String?
    let suggestedIngredients: [RecipeIngredient]
}

enum SocialImportParser {
    static func parse(
        sourceURLRaw: String,
        captionRaw: String,
        produceItems: [ProduceItem],
        languageCode: String
    ) -> SocialImportSuggestion {
        let normalizedURL = normalizeURL(sourceURLRaw)
        let platform = detectPlatform(from: normalizedURL)
        let lines = captionRaw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = suggestTitle(from: lines)
        let ingredients = suggestIngredients(from: lines, produceItems: produceItems, languageCode: languageCode)

        return SocialImportSuggestion(
            sourceURL: normalizedURL,
            sourcePlatform: platform,
            sourceCaptionRaw: captionRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : captionRaw,
            suggestedTitle: title,
            suggestedIngredients: ingredients
        )
    }

    private static func normalizeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func detectPlatform(from url: String?) -> SocialSourcePlatform? {
        guard let url else { return nil }
        let lower = url.lowercased()
        if lower.contains("tiktok.com") {
            return .tiktok
        }
        if lower.contains("instagram.com") {
            return .instagram
        }
        return .other
    }

    private static func suggestTitle(from lines: [String]) -> String? {
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 6 else { continue }
            guard !cleaned.hasPrefix("#"), !cleaned.hasPrefix("http") else { continue }
            let lower = cleaned.lowercased()
            if lower.hasPrefix("ingredients") || lower.hasPrefix("ingredienti") {
                continue
            }
            return cleaned
        }
        return nil
    }

    private static func suggestIngredients(
        from lines: [String],
        produceItems: [ProduceItem],
        languageCode: String
    ) -> [RecipeIngredient] {
        let candidates = ingredientCandidates(from: lines)
        var seen = Set<String>()
        var result: [RecipeIngredient] = []

        for line in candidates {
            guard let produceID = detectProduceID(in: line, produceItems: produceItems, languageCode: languageCode) else {
                continue
            }
            guard seen.insert(produceID).inserted else { continue }
            let quantity = extractQuantity(from: line)
            let name = produceItems.first(where: { $0.id == produceID })?.displayName(languageCode: languageCode)
                ?? produceID.replacingOccurrences(of: "_", with: " ").capitalized
            result.append(
                RecipeIngredient(
                    produceID: produceID,
                    basicIngredientID: nil,
                    quality: .coreSeasonal,
                    name: name,
                    quantityValue: quantity.value,
                    quantityUnit: quantity.unit
                )
            )
        }

        return result
    }

    private static func ingredientCandidates(from lines: [String]) -> [String] {
        lines.filter { line in
            let lower = line.lowercased()
            if line.hasPrefix("-") || line.hasPrefix("•") {
                return true
            }
            if lower.contains("ingredient") {
                return true
            }
            return hasQuantityPattern(in: line)
        }
    }

    private static func hasQuantityPattern(in line: String) -> Bool {
        let pattern = #"\b\d+(?:[.,/]\d+)?\s?(?:g|kg|ml|l|tbsp|tsp|cup|cups|oz|pcs|x)?\b"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private static func detectProduceID(
        in line: String,
        produceItems: [ProduceItem],
        languageCode: String
    ) -> String? {
        let lowerLine = line.lowercased()
        var bestMatch: (id: String, length: Int)?

        for item in produceItems {
            let localizedName = item.displayName(languageCode: languageCode).lowercased()
            let englishName = item.displayName(languageCode: "en").lowercased()
            let idName = item.id.replacingOccurrences(of: "_", with: " ").lowercased()
            let candidates = [localizedName, englishName, idName]

            for name in candidates where !name.isEmpty {
                guard lowerLine.contains(name) else { continue }
                if bestMatch == nil || name.count > bestMatch!.length {
                    bestMatch = (id: item.id, length: name.count)
                }
            }
        }

        return bestMatch?.id
    }

    private static func extractQuantity(from line: String) -> (value: Double, unit: RecipeQuantityUnit) {
        let lower = line.lowercased()
        let pattern = #"(\d+(?:[.,]\d+)?(?:/\d+)?)\s*(g|ml|piece|pieces|clove|cloves|tbsp|tsp)?"#
        guard let range = lower.range(of: pattern, options: .regularExpression) else {
            return (1, .piece)
        }

        let token = String(lower[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = token.split(separator: " ")
        guard let first = parts.first else { return (1, .piece) }

        let valueToken = String(first).replacingOccurrences(of: ",", with: ".")
        let value: Double = {
            if valueToken.contains("/") {
                let fractionParts = valueToken.split(separator: "/")
                guard fractionParts.count == 2,
                      let numerator = Double(fractionParts[0]),
                      let denominator = Double(fractionParts[1]),
                      denominator != 0 else { return 1 }
                return numerator / denominator
            }
            return Double(valueToken) ?? 1
        }()

        let unit = parts.count > 1 ? unitFromToken(String(parts[1])) : .piece
        return (value, unit)
    }

    private static func unitFromToken(_ raw: String) -> RecipeQuantityUnit {
        switch raw {
        case "g":
            return .g
        case "ml":
            return .ml
        case "tbsp":
            return .tbsp
        case "tsp":
            return .tsp
        case "clove", "cloves":
            return .clove
        case "piece", "pieces":
            return .piece
        default:
            return .piece
        }
    }
}
