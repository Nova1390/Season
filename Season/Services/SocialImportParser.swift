import Foundation

struct SocialImportSuggestion {
    let sourceURL: String?
    let sourcePlatform: SocialSourcePlatform?
    let sourceCaptionRaw: String?
    let suggestedTitle: String?
    let suggestedIngredients: [RecipeIngredient]
    let suggestedSteps: [String]
}

enum SocialImportParser {
    static func parse(
        sourceURLRaw: String,
        captionRaw: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient] = [],
        languageCode: String
    ) -> SocialImportSuggestion {
        let normalizedURL = normalizeURL(sourceURLRaw)
        let platform = detectPlatform(from: normalizedURL)

        let structuredCaption = parseStructuredCaption(captionRaw)
        let title: String?
        let ingredients: [RecipeIngredient]
        let steps: [String]

        if let structuredCaption {
            title = suggestTitle(
                introLines: structuredCaption.introLines,
                fallbackLines: structuredCaption.allLines
            )
            ingredients = suggestedStructuredIngredients(from: structuredCaption.ingredientLines)
            steps = suggestedStructuredSteps(from: structuredCaption.stepLines)
        } else {
            let lines = captionRaw
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            title = suggestTitle(from: lines)
            ingredients = suggestIngredients(
                from: lines,
                produceItems: produceItems,
                basicIngredients: basicIngredients,
                languageCode: languageCode
            )
            steps = []
        }

        return SocialImportSuggestion(
            sourceURL: normalizedURL,
            sourcePlatform: platform,
            sourceCaptionRaw: captionRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : captionRaw,
            suggestedTitle: title,
            suggestedIngredients: ingredients,
            suggestedSteps: steps
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

    private static func suggestTitle(introLines: [String], fallbackLines: [String]) -> String {
        if let firstIntro = introLines.first(where: { !$0.isEmpty }) {
            let firstSentence = firstIntro
                .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !firstSentence.isEmpty {
                return firstSentence
            }
        }
        return suggestTitle(from: fallbackLines) ?? "Untitled recipe"
    }

    private static func parseStructuredCaption(_ rawCaption: String) -> StructuredCaption? {
        let lines = rawCaption
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var introLines: [String] = []
        var ingredientLines: [String] = []
        var stepLines: [String] = []
        var section: StructuredCaption.Section = .intro
        var foundSectionHeader = false

        for line in lines {
            if let detectedSection = detectedSectionHeader(from: line) {
                foundSectionHeader = true
                section = detectedSection
                continue
            }

            switch section {
            case .intro:
                introLines.append(line)
            case .ingredients:
                ingredientLines.append(line)
            case .steps:
                stepLines.append(line)
            }
        }

        guard foundSectionHeader else { return nil }
        return StructuredCaption(
            allLines: lines,
            introLines: introLines,
            ingredientLines: ingredientLines,
            stepLines: stepLines
        )
    }

    private static func detectedSectionHeader(from line: String) -> StructuredCaption.Section? {
        let normalized = normalizedSectionHeader(line)
        if normalized.hasPrefix("ingredienti") || normalized.hasPrefix("ingredients") {
            return .ingredients
        }
        if normalized.hasPrefix("procedimento")
            || normalized.hasPrefix("preparazione")
            || normalized.hasPrefix("steps")
            || normalized.hasPrefix("method")
            || normalized.hasPrefix("instructions") {
            return .steps
        }
        return nil
    }

    private static func normalizedSectionHeader(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suggestedStructuredIngredients(from lines: [String]) -> [RecipeIngredient] {
        lines
            .map(cleanedStructuredIngredientLine)
            .filter { !$0.isEmpty }
            .map {
                RecipeIngredient(
                    produceID: nil,
                    basicIngredientID: nil,
                    quality: .basic,
                    name: $0,
                    quantityValue: 1,
                    quantityUnit: .piece,
                    rawIngredientLine: $0,
                    mappingConfidence: .unmapped
                )
            }
    }

    private static func cleanedStructuredIngredientLine(_ raw: String) -> String {
        raw
            .replacingOccurrences(
                of: #"^\s*[-•\*]+\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suggestedStructuredSteps(from lines: [String]) -> [String] {
        let cleanedLines = lines
            .map(cleanedStructuredStepLine)
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else { return [] }

        if cleanedLines.count > 1 {
            return cleanedLines
        }

        let single = cleanedLines[0]
        let sentenceSplit = single
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return sentenceSplit.count > 1 ? sentenceSplit : cleanedLines
    }

    private static func cleanedStructuredStepLine(_ raw: String) -> String {
        let noBullet = raw.replacingOccurrences(
            of: #"^\s*[-•\*]+\s*"#,
            with: "",
            options: .regularExpression
        )
        return noBullet.replacingOccurrences(
            of: #"^\s*\d+[\)\.\-:]\s*"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suggestIngredients(
        from lines: [String],
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> [RecipeIngredient] {
        let candidates = ingredientCandidates(from: lines)
        var seen = Set<String>()
        var result: [RecipeIngredient] = []

        for line in candidates {
            guard let match = detectIngredientMatch(
                in: line,
                produceItems: produceItems,
                basicIngredients: basicIngredients,
                languageCode: languageCode
            ) else {
                continue
            }
            let quantity = extractQuantity(from: line)

            switch match {
            case .produce(let produce):
                guard seen.insert("produce:\(produce.id)").inserted else { continue }
                result.append(
                    RecipeIngredient(
                        produceID: produce.id,
                        basicIngredientID: nil,
                        quality: .coreSeasonal,
                        name: produce.displayName(languageCode: languageCode),
                        quantityValue: quantity.value,
                        quantityUnit: quantity.unit
                    )
                )
            case .basic(let basic):
                guard seen.insert("basic:\(basic.id)").inserted else { continue }
                result.append(
                    RecipeIngredient(
                        produceID: nil,
                        basicIngredientID: basic.id,
                        quality: .basic,
                        name: basic.displayName(languageCode: languageCode),
                        quantityValue: quantity.value,
                        quantityUnit: quantity.unit
                    )
                )
            }
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

    private static func detectIngredientMatch(
        in line: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> IngredientCatalogMatch? {
        let normalizedLine = normalizedIngredientText(line)
        guard !normalizedLine.isEmpty else { return nil }

        let produceMatch = bestProduceMatch(
            in: normalizedLine,
            produceItems: produceItems,
            languageCode: languageCode
        )
        let basicMatch = bestBasicMatch(
            in: normalizedLine,
            basicIngredients: basicIngredients,
            languageCode: languageCode
        )

        switch (produceMatch, basicMatch) {
        case (.none, .none):
            return nil
        case let (.some(produce), .none):
            return .produce(produce.item)
        case let (.none, .some(basic)):
            return .basic(basic.item)
        case let (.some(produce), .some(basic)):
            if produce.score != basic.score {
                return produce.score > basic.score ? .produce(produce.item) : .basic(basic.item)
            }
            if produce.length != basic.length {
                return produce.length > basic.length ? .produce(produce.item) : .basic(basic.item)
            }
            // Deterministic tie-break: preserve existing produce-first behavior when strength is identical.
            return .produce(produce.item)
        }
    }

    private static func bestProduceMatch(
        in normalizedLine: String,
        produceItems: [ProduceItem],
        languageCode: String
    ) -> ScoredItemMatch<ProduceItem>? {
        var best: ScoredItemMatch<ProduceItem>?
        for item in produceItems {
            for candidate in produceCandidateNames(for: item, languageCode: languageCode) {
                guard let score = matchScore(in: normalizedLine, candidate: candidate) else { continue }
                let match = ScoredItemMatch(item: item, score: score, length: candidate.count)
                if best == nil || match > best! {
                    best = match
                }
            }
        }
        return best
    }

    private static func bestBasicMatch(
        in normalizedLine: String,
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> ScoredItemMatch<BasicIngredient>? {
        var best: ScoredItemMatch<BasicIngredient>?
        for item in basicIngredients {
            for candidate in basicCandidateNames(for: item, languageCode: languageCode) {
                guard let score = matchScore(in: normalizedLine, candidate: candidate) else { continue }
                let match = ScoredItemMatch(item: item, score: score, length: candidate.count)
                if best == nil || match > best! {
                    best = match
                }
            }
        }
        return best
    }

    private static func produceCandidateNames(for item: ProduceItem, languageCode: String) -> [String] {
        let names = [
            item.displayName(languageCode: languageCode),
            item.displayName(languageCode: "en"),
            item.id.replacingOccurrences(of: "_", with: " ")
        ]
        return normalizedCandidates(from: names)
    }

    private static func basicCandidateNames(for item: BasicIngredient, languageCode: String) -> [String] {
        let names = [
            item.displayName(languageCode: languageCode),
            item.displayName(languageCode: "en"),
            item.id.replacingOccurrences(of: "_", with: " ")
        ]
        return normalizedCandidates(from: names)
    }

    private static func normalizedCandidates(from names: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for name in names {
            let cleaned = normalizedIngredientText(name)
            guard cleaned.count >= 2 else { continue }
            for variant in candidateVariants(for: cleaned) {
                if seen.insert(variant).inserted {
                    normalized.append(variant)
                }
            }
        }
        return normalized
    }

    private static func candidateVariants(for candidate: String) -> [String] {
        var variants = [candidate]
        let tokens = candidate.split(separator: " ").map(String.init)
        guard tokens.count == 1, let token = tokens.first, token.count >= 4 else {
            return variants
        }

        if token.hasSuffix("s") {
            let singular = String(token.dropLast())
            if singular.count >= 3 {
                variants.append(singular)
            }
        } else {
            variants.append(token + "s")
        }
        return variants
    }

    private static func matchScore(in normalizedLine: String, candidate: String) -> Int? {
        guard !candidate.isEmpty else { return nil }
        if isRejectedAmbiguousCompoundMatch(line: normalizedLine, candidate: candidate) {
            return nil
        }

        let escaped = NSRegularExpression.escapedPattern(for: candidate)
        if normalizedLine.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil {
            return 3
        }
        if normalizedLine.contains(candidate) {
            return 2
        }
        return nil
    }

    private static func isRejectedAmbiguousCompoundMatch(line: String, candidate: String) -> Bool {
        let tokens = line.split(separator: " ").map(String.init)
        let candidateTokens = candidate.split(separator: " ").map(String.init)
        guard candidateTokens.count == 1, let candidateToken = candidateTokens.first else {
            return false
        }

        guard let blockedNeighbors = blockedCompoundNeighbors[candidateToken] else {
            return false
        }

        for (index, token) in tokens.enumerated() where token == candidateToken {
            let next = index + 1 < tokens.count ? tokens[index + 1] : nil
            let previous = index > 0 ? tokens[index - 1] : nil
            if let next, blockedNeighbors.contains(next) {
                return true
            }
            if let previous, blockedNeighbors.contains(previous) {
                return true
            }
        }

        return false
    }

    private static let blockedCompoundNeighbors: [String: Set<String>] = [
        "milk": ["chocolate"],
        "rice": ["vinegar", "wine"],
        "butter": ["beans"],
        "olive": ["tapenade"]
    ]

    private static func normalizedIngredientText(_ raw: String) -> String {
        let lower = raw
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let scalars = lower.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }

        let collapsed = String(scalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
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

private struct StructuredCaption {
    enum Section {
        case intro
        case ingredients
        case steps
    }

    let allLines: [String]
    let introLines: [String]
    let ingredientLines: [String]
    let stepLines: [String]
}

private enum IngredientCatalogMatch {
    case produce(ProduceItem)
    case basic(BasicIngredient)

    var source: Source {
        switch self {
        case .produce:
            return .produce
        case .basic:
            return .basic
        }
    }

    enum Source {
        case produce
        case basic
    }
}

private struct ScoredItemMatch<Item>: Comparable {
    let item: Item
    let score: Int
    let length: Int

    static func == (lhs: ScoredItemMatch<Item>, rhs: ScoredItemMatch<Item>) -> Bool {
        lhs.score == rhs.score && lhs.length == rhs.length
    }

    static func < (lhs: ScoredItemMatch<Item>, rhs: ScoredItemMatch<Item>) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        return lhs.length < rhs.length
    }
}
