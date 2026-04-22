import Foundation

enum SocialImportConfidence: String, Codable {
    case high
    case medium
    case low
}

struct SocialImportSuggestion {
    let sourceURL: String?
    let sourcePlatform: SocialSourcePlatform?
    let sourceCaptionRaw: String?
    let suggestedTitle: String?
    let suggestedIngredients: [RecipeIngredient]
    let suggestedSteps: [String]
    let confidence: SocialImportConfidence
}

enum SmartImportMatchType: String, Codable, Hashable {
    case exact
    case alias
    case ambiguous
    case none
}

struct SmartImportCatalogMatch: Codable, Hashable {
    let matchType: SmartImportMatchType
    let matchedIngredientId: String?
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case matchType
        case matchedIngredientId
        case confidence
    }
}

struct SmartImportIngredientCandidate: Codable, Hashable {
    let rawText: String
    let normalizedText: String
    let possibleQuantity: Double?
    let possibleUnit: String?
    let catalogMatch: SmartImportCatalogMatch

    var requiresLLM: Bool {
        switch catalogMatch.matchType {
        case .exact:
            return false
        case .alias:
            return catalogMatch.confidence < 0.85
        case .ambiguous, .none:
            return true
        }
    }

    enum CodingKeys: String, CodingKey {
        case rawText = "raw_text"
        case normalizedText = "normalized_text"
        case possibleQuantity = "possible_quantity"
        case possibleUnit = "possible_unit"
        case catalogMatch = "catalog_match"
    }
}

struct SmartImportAuditMetrics {
    let totalCandidates: Int
    let exactMatches: Int
    let aliasMatches: Int
    let ambiguousMatches: Int
    let noMatches: Int
    let requiresLLMCount: Int
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

        let confidence = classifyConfidence(
            hasStructuredSections: structuredCaption != nil,
            suggestedTitle: title,
            suggestedIngredients: ingredients,
            suggestedSteps: steps
        )

        return SocialImportSuggestion(
            sourceURL: normalizedURL,
            sourcePlatform: platform,
            sourceCaptionRaw: captionRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : captionRaw,
            suggestedTitle: title,
            suggestedIngredients: ingredients,
            suggestedSteps: steps,
            confidence: confidence
        )
    }

    static func preparseIngredientCandidates(
        captionRaw: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient] = [],
        languageCode: String
    ) -> [SmartImportIngredientCandidate] {
        let lines: [String]
        if let structuredCaption = parseStructuredCaption(captionRaw),
           !structuredCaption.ingredientLines.isEmpty {
            lines = structuredCaption.ingredientLines
                .flatMap(ingredientCandidateFragmentsIncludingRecoveredQuantityless)
                .filter { !isLikelyNoiseIngredientLine($0) }
        } else {
            let allLines = captionRaw
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            lines = ingredientCandidates(from: allLines)
        }

        let titleLines = titleIngredientCandidates(
            from: captionRaw.components(separatedBy: .newlines),
            existingCandidates: lines,
            produceItems: produceItems,
            basicIngredients: basicIngredients,
            languageCode: languageCode
        )
        var seen = Set<String>()
        return (lines + titleLines).compactMap { rawLine in
            let cleaned = cleanedStructuredIngredientLine(rawLine)
            guard !cleaned.isEmpty else { return nil }
            let parsed = parsedIngredientCandidateText(cleaned)
            guard !parsed.normalizedText.isEmpty else { return nil }
            let dedupeKey = "\(parsed.normalizedText)|\(parsed.quantity.map { String($0) } ?? "nil")|\(parsed.unit ?? "nil")"
            guard seen.insert(dedupeKey).inserted else { return nil }
            return SmartImportIngredientCandidate(
                rawText: cleaned,
                normalizedText: parsed.normalizedText,
                possibleQuantity: parsed.quantity,
                possibleUnit: parsed.unit,
                catalogMatch: detectCatalogDecision(
                    normalizedText: parsed.normalizedText,
                    produceItems: produceItems,
                    basicIngredients: basicIngredients,
                    languageCode: languageCode
                )
            )
        }
    }

    static func computeAuditMetrics(
        candidates: [SmartImportIngredientCandidate]
    ) -> SmartImportAuditMetrics {
        let exactMatches = candidates.filter { $0.catalogMatch.matchType == .exact }.count
        let aliasMatches = candidates.filter { $0.catalogMatch.matchType == .alias }.count
        let ambiguousMatches = candidates.filter { $0.catalogMatch.matchType == .ambiguous }.count
        let noMatches = candidates.filter { $0.catalogMatch.matchType == .none }.count
        return SmartImportAuditMetrics(
            totalCandidates: candidates.count,
            exactMatches: exactMatches,
            aliasMatches: aliasMatches,
            ambiguousMatches: ambiguousMatches,
            noMatches: noMatches,
            requiresLLMCount: candidates.filter(\.requiresLLM).count
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
            if let detectedHeader = detectedSectionHeader(from: line) {
                foundSectionHeader = true
                section = detectedHeader.section
                if let remainder = detectedHeader.remainder, !remainder.isEmpty {
                    switch detectedHeader.section {
                    case .intro:
                        introLines.append(remainder)
                    case .ingredients:
                        ingredientLines.append(remainder)
                    case .steps:
                        stepLines.append(remainder)
                    }
                }
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

    private static func detectedSectionHeader(from line: String) -> (section: StructuredCaption.Section, remainder: String?)? {
        if let colonRange = line.range(of: ":") {
            let marker = String(line[..<colonRange.lowerBound])
            let remainder = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedMarker = normalizedSectionHeader(marker)
            if normalizedMarker == "ingredienti" || normalizedMarker == "ingredients" {
                return (.ingredients, remainder.isEmpty ? nil : remainder)
            }
            if normalizedMarker == "procedimento"
                || normalizedMarker == "preparazione"
                || normalizedMarker == "steps"
                || normalizedMarker == "method"
                || normalizedMarker == "instructions" {
                return (.steps, remainder.isEmpty ? nil : remainder)
            }
        }

        let normalized = normalizedSectionHeader(line)
        if normalized.hasPrefix("ingredienti") || normalized.hasPrefix("ingredients") {
            return (.ingredients, nil)
        }
        if normalized.hasPrefix("procedimento")
            || normalized.hasPrefix("preparazione")
            || normalized.hasPrefix("steps")
            || normalized.hasPrefix("method")
            || normalized.hasPrefix("instructions") {
            return (.steps, nil)
        }
        return nil
    }

    nonisolated private static func normalizedSectionHeader(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suggestedStructuredIngredients(from lines: [String]) -> [RecipeIngredient] {
        lines
            .flatMap(ingredientCandidateFragmentsIncludingRecoveredQuantityless)
            .map(cleanedStructuredIngredientLine)
            .filter { !$0.isEmpty && !isLikelyNoiseIngredientLine($0) }
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

    nonisolated private static func ingredientCandidateFragmentsIncludingRecoveredQuantityless(from line: String) -> [String] {
        var seen = Set<String>()
        let fragments = ingredientCandidateFragments(from: line).flatMap { fragment -> [String] in
            if hasQuantityPattern(in: fragment)
                || hasQuantoBastaPattern(in: fragment)
                || (hasBareCountPattern(in: fragment) && hasFoodSignal(in: normalizedIngredientText(fragment)))
                || hasQuantitylessHighSignalIngredient(in: fragment) {
                return [fragment]
            }
            let recovered = quantitylessHighSignalIngredientFragments(from: fragment)
            return recovered.isEmpty ? [fragment] : recovered
        }
        return fragments.filter { fragment in
            seen.insert(normalizedIngredientText(fragment)).inserted
        }
    }

    nonisolated private static func cleanedStructuredIngredientLine(_ raw: String) -> String {
        raw
            .replacingOccurrences(
                of: #"^\s*[-•\*]+\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)^\s*(ingredienti|ingredients)\s*:\s*"#,
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

    nonisolated private static func cleanedStructuredStepLine(_ raw: String) -> String {
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
        let baseCandidates = ingredientCandidates(from: lines)
        let candidates = baseCandidates + titleIngredientCandidates(
            from: lines,
            existingCandidates: baseCandidates,
            produceItems: produceItems,
            basicIngredients: basicIngredients,
            languageCode: languageCode
        )
        var seen = Set<String>()
        var result: [RecipeIngredient] = []

        for line in candidates {
            guard let match = detectIngredientMatch(
                in: line,
                produceItems: produceItems,
                basicIngredients: basicIngredients,
                languageCode: languageCode
            ) else {
                guard shouldPreserveCustomOnlyIngredient(line) else {
                    continue
                }
                let quantity = extractQuantity(from: line)
                let normalizedName = normalizedIngredientText(line)
                guard seen.insert("custom:\(normalizedName)").inserted else { continue }
                result.append(
                    RecipeIngredient(
                        produceID: nil,
                        basicIngredientID: nil,
                        quality: .basic,
                        name: normalizedName.isEmpty ? line : normalizedName,
                        quantityValue: quantity.value,
                        quantityUnit: quantity.unit,
                        rawIngredientLine: line,
                        mappingConfidence: .unmapped
                    )
                )
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
                        quantityUnit: quantity.unit,
                        rawIngredientLine: line
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
                        quantityUnit: quantity.unit,
                        rawIngredientLine: line
                    )
                )
            }
        }

        return result
    }

    private static func ingredientCandidates(from lines: [String]) -> [String] {
        let strongSignals = lines.map { lineContainsStrongIngredientSignal($0) }
        var seen = Set<String>()
        return lines.enumerated().flatMap { index, line in
            let nearIngredientBlock = strongSignals[index]
                || (index > 0 && strongSignals[index - 1])
                || (index + 1 < strongSignals.count && strongSignals[index + 1])
            let fragments = ingredientCandidateFragments(from: line)
            let accepted = fragments.filter { fragment in
                guard !isLikelyNoiseIngredientLine(fragment) else { return false }
                let lower = fragment.lowercased()
                if fragment.hasPrefix("-") || fragment.hasPrefix("•") {
                    return true
                }
                if lower.contains("ingredient") {
                    return true
                }
                if hasQuantoBastaPattern(in: fragment) {
                    return true
                }
                if hasQuantityPattern(in: fragment) {
                    return true
                }
                if hasBareCountPattern(in: fragment),
                   hasFoodSignal(in: normalizedIngredientText(fragment)) {
                    return true
                }
                return nearIngredientBlock && hasQuantitylessHighSignalIngredient(in: fragment)
            }
            let recoveredQuantityless = nearIngredientBlock
                ? fragments.flatMap(quantitylessHighSignalIngredientFragments)
                : []
            return (accepted + recoveredQuantityless).filter { fragment in
                seen.insert(normalizedIngredientText(fragment)).inserted
            }
        }
    }

    nonisolated private static func hasQuantityPattern(in line: String) -> Bool {
        let pattern = #"\b\d+(?:[.,/]\d+)?\s?(?:g|kg|ml|l|tbsp|tsp|cup|cups|oz|pcs|x|spicchio|spicchi|cucchiaio|cucchiai|cucchiaino|cucchiaini)\b"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    nonisolated private static func hasBareCountPattern(in line: String) -> Bool {
        let forward = #"(?i)^\s*\d+(?:[.,]\d+)?\s+[a-zÀ-ÖØ-öø-ÿ][a-zÀ-ÖØ-öø-ÿ\s']{1,60}\s*$"#
        let reversed = #"(?i)^\s*[a-zÀ-ÖØ-öø-ÿ][a-zÀ-ÖØ-öø-ÿ\s']{1,60}\s+\d+(?:[.,]\d+)?\s*$"#
        return line.range(of: forward, options: .regularExpression) != nil
            || line.range(of: reversed, options: .regularExpression) != nil
    }

    nonisolated private static func hasQuantoBastaPattern(in line: String) -> Bool {
        line.range(of: #"(?i)\bq\s*\.?\s*b\s*\.?\b|\bqb\b|\bquanto basta\b"#, options: .regularExpression) != nil
    }

    nonisolated private static func ingredientCandidateFragments(from line: String) -> [String] {
        let cleaned = cleanedCreatorCaptionNoise(from: cleanedIngredientCandidateLine(line))
        guard !cleaned.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",/;+")
        // Keep measured mains separate from "con ..." garnish/sauce lists, e.g.
        // "pollo 400g con curry e latte di cocco" -> "pollo 400g", "curry", "latte di cocco".
        let preSplitFragments = splitMeasuredConTrailingIngredients(cleaned)
        let parts = preSplitFragments
            .flatMap { $0.components(separatedBy: separators) }
            .flatMap(sentenceBoundedIngredientFragments)
            .flatMap(splitMeasuredConjunctionFragment)
            .map(cleanedCreatorIngredientFragment)
            .flatMap(splitCreatorConnectorFragment)
            .map(cleanedCreatorIngredientFragment)
            .filter { !$0.isEmpty }

        guard parts.count > 1, parts.count <= 8 else { return [cleaned] }
        let shortIngredientLikeParts = parts.allSatisfy { part in
            part.split(whereSeparator: { $0.isWhitespace }).count <= 5
        }
        let hasIngredientSignal = parts.contains { part in
            hasQuantityPattern(in: part)
                || hasQuantoBastaPattern(in: part)
                || hasBareCountPattern(in: part)
        }
        return shortIngredientLikeParts || hasIngredientSignal ? parts : [cleaned]
    }

    nonisolated private static func splitMeasuredConTrailingIngredients(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"(?i)\s+con\s+"#, options: .regularExpression) != nil else {
            return [trimmed]
        }

        let pattern = #"(?i)^(.+?\b\d+(?:[.,]\d+)?\s*(?:kg|g|ml|l|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|piece|pieces|pezzo|pezzi)?)(?:\s+con\s+)(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return [trimmed]
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges == 3,
              let leftRange = Range(match.range(at: 1), in: trimmed),
              let trailingRange = Range(match.range(at: 2), in: trimmed) else {
            return [trimmed]
        }

        let left = String(trimmed[leftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let trailing = String(trimmed[trailingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasQuantityPattern(in: left) || hasBareCountPattern(in: left),
              hasFoodSignal(in: normalizedIngredientText(left)) else {
            return [trimmed]
        }

        let trailingNormalized = normalizedIngredientText(trailing)
        let trailingLooksIngredientLike = hasFoodSignal(in: trailingNormalized)
            || hasQuantitylessHighSignalIngredient(in: trailing)
            || !quantitylessHighSignalIngredientFragments(from: trailing).isEmpty
        return trailingLooksIngredientLike ? [left, trailing] : [trimmed]
    }

    nonisolated private static func splitMeasuredConjunctionFragment(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"(?i)\s+e\s+"#, options: .regularExpression) != nil else {
            return [trimmed]
        }

        let quantityPattern = #"(?i)\b\d+(?:[.,]\d+)?\s*(?:kg|g|ml|l|tbsp|tsp|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|clove|cloves|piece|pieces|pezzo|pezzi)?\b"#
        guard let regex = try? NSRegularExpression(pattern: quantityPattern, options: [.caseInsensitive]) else {
            return [trimmed]
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        let parts = trimmed
            .components(separatedBy: " e ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count == 2 else {
            return [trimmed]
        }
        if regex.numberOfMatches(in: trimmed, options: [], range: range) == 0 {
            let leftQuantityless = hasQuantitylessHighSignalIngredient(in: parts[0])
            let rightQuantityless = hasQuantitylessHighSignalIngredient(in: parts[1])
            return leftQuantityless && rightQuantityless ? parts : [trimmed]
        }
        let leftLooksMeasured = hasQuantityPattern(in: parts[0]) || hasBareCountPattern(in: parts[0])
        let rightLooksMeasured = hasQuantityPattern(in: parts[1]) || hasBareCountPattern(in: parts[1])
        let rightLooksIngredientLike = rightLooksMeasured
            || hasQuantoBastaPattern(in: parts[1])
            || hasFoodSignal(in: normalizedIngredientText(parts[1]))
            || hasQuantitylessHighSignalIngredient(in: parts[1])
        guard (leftLooksMeasured && rightLooksIngredientLike)
            || (rightLooksMeasured && hasFoodSignal(in: normalizedIngredientText(parts[0]))) else {
            return [trimmed]
        }
        return parts
    }

    nonisolated private static func splitCreatorConnectorFragment(_ raw: String) -> [String] {
        let trimmed = cleanedCreatorIngredientFragment(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.range(of: #"(?i)\s+(e|poi|con)\s+"#, options: .regularExpression) != nil else {
            return [trimmed]
        }

        let parts = trimmed
            .replacingOccurrences(of: #"(?i)\s+poi\s+"#, with: " | ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s+con\s+"#, with: " | ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s+e\s+"#, with: " | ", options: .regularExpression)
            .components(separatedBy: "|")
            .map(cleanedCreatorIngredientFragment)
            .filter { !$0.isEmpty }

        guard parts.count > 1, parts.count <= 6 else {
            return [trimmed]
        }

        let accepted = parts.filter(isCreatorIngredientLikeFragment)
        guard !accepted.isEmpty else {
            return [trimmed]
        }
        if accepted.count >= 2 || containsCreatorNoisePrefix(trimmed) {
            return accepted
        }
        return [trimmed]
    }

    nonisolated private static func cleanedCreatorIngredientFragment(_ raw: String) -> String {
        var trimmed = strippedLeadingProcedureVerbIfIngredientLike(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = strippedLeadingCreatorFillerIfIngredientLike(trimmed)
        trimmed = trailingMeasuredIngredientFromNoisyTitle(trimmed)
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func isCreatorIngredientLikeFragment(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.split(whereSeparator: { $0.isWhitespace }).count <= 5,
              !isLikelyNoiseIngredientLine(trimmed) else {
            return false
        }
        let normalized = normalizedIngredientText(trimmed)
        return hasQuantityPattern(in: trimmed)
            || hasQuantoBastaPattern(in: trimmed)
            || (hasBareCountPattern(in: trimmed) && hasFoodSignal(in: normalized))
            || hasFoodSignal(in: normalized)
            || hasQuantitylessHighSignalIngredient(in: trimmed)
    }

    nonisolated private static func containsCreatorNoisePrefix(_ raw: String) -> Bool {
        let normalized = normalizedIngredientText(raw)
        let noiseTokens = [
            "salva", "seguimi", "follow", "like", "commenta", "condividi",
            "idea", "pranzo", "cena", "ricetta", "video", "facile", "veloce",
            "super", "zero", "sbatti", "buonissima", "buonissimo"
        ]
        return noiseTokens.contains { token in
            normalized.range(
                of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: token))(?![a-z0-9])"#,
                options: .regularExpression
            ) != nil
        }
    }

    nonisolated private static func cleanedCreatorCaptionNoise(from raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: #"https?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"@\w+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"#[\wÀ-ÖØ-öø-ÿ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(salva(?:lo|la)?|seguimi|follow|like|commenta|condividi)\b(?:\s+(?:il|la|quest[ao])\s+(?:video|ricetta))?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(?:in\s*)?\d+\s*(?:min|mins|minuti|minutes)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*quando\s+ho\s+fretta\s+faccio\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func cleanedIngredientCandidateLine(_ raw: String) -> String {
        var cleaned = cleanedStructuredIngredientLine(raw)
        if let colonRange = cleaned.range(of: ":") {
            let prefix = String(cleaned[..<colonRange.lowerBound])
            let remainder = String(cleaned[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let prefixTokenCount = prefix.split(whereSeparator: { $0.isWhitespace }).count
            let normalizedPrefix = normalizedSectionHeader(prefix)
            if !remainder.isEmpty,
               lineContainsStrongIngredientSignal(remainder),
               (normalizedPrefix.contains("ingredienti")
                || normalizedPrefix.contains("ingredients")
                || prefixTokenCount > 1
                || !hasFoodSignal(in: normalizedIngredientText(prefix))) {
                cleaned = remainder
            }
        }
        return strippedLeadingProcedureVerbIfIngredientLike(cleaned)
    }

    nonisolated private static func strippedLeadingProcedureVerbIfIngredientLike(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let pattern = #"(?i)^\s*(taglia|aggiungi|metti|unisci|rosola|cuoci|condisci|tosta|bagna|servi)\s+(?:con\s+)?(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return trimmed
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges == 3,
              let remainderRange = Range(match.range(at: 2), in: trimmed) else {
            return trimmed
        }
        let remainder = String(trimmed[remainderRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else { return trimmed }
        let normalizedRemainder = normalizedIngredientText(remainder)
        let ingredientLike = hasQuantityPattern(in: remainder)
            || hasQuantoBastaPattern(in: remainder)
            || (hasBareCountPattern(in: remainder) && hasFoodSignal(in: normalizedRemainder))
            || hasFoodSignal(in: normalizedRemainder)
            || !quantitylessHighSignalIngredientFragments(from: remainder).isEmpty
        return ingredientLike ? remainder : trimmed
    }

    nonisolated private static func strippedLeadingCreatorFillerIfIngredientLike(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"(?i)^\s*(?:questa|questo|ricetta|idea|pranzo|cena|facile|veloce|super|cremosa|cremoso|buonissima|buonissimo)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return trimmed
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges == 2,
              let remainderRange = Range(match.range(at: 1), in: trimmed) else {
            return trimmed
        }
        let remainder = String(trimmed[remainderRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else { return trimmed }
        let normalized = normalizedIngredientText(remainder)
        let ingredientLike = hasQuantityPattern(in: remainder)
            || hasQuantoBastaPattern(in: remainder)
            || (hasBareCountPattern(in: remainder) && hasFoodSignal(in: normalized))
            || hasFoodSignal(in: normalized)
            || hasQuantitylessHighSignalIngredient(in: remainder)
        return ingredientLike ? remainder : trimmed
    }

    nonisolated private static func trailingMeasuredIngredientFromNoisyTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedIngredientText(trimmed)
        guard containsCreatorNoisePrefix(trimmed) || normalized.contains(" al forno ") else {
            return trimmed
        }

        let trailingIngredientPattern = #"(?i)\b((?:pesce\s+spada|latte\s+di\s+cocco|farina\s+00|cipolla\s+(?:rossa|dorata|bianca)|spaghetti|bucatini|pomodorini|pomodori|pomodoro|orata|salmone|pollo|riso|ceci|patate|zucchine|melanzane|aglio|pasta|curry)\s+\d+(?:[.,]\d+)?\s*(?:kg|g|ml|l|spicchio|spicchi|pezzo|pezzi|piece|pieces)?)\s*$"#
        guard let range = trimmed.range(of: trailingIngredientPattern, options: .regularExpression) else {
            return trimmed
        }
        return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func lineContainsStrongIngredientSignal(_ line: String) -> Bool {
        ingredientCandidateFragmentsWithoutTitleStripping(from: line).contains { fragment in
            hasQuantityPattern(in: fragment)
                || hasQuantoBastaPattern(in: fragment)
                || (hasBareCountPattern(in: fragment) && hasFoodSignal(in: normalizedIngredientText(fragment)))
                || !quantitylessHighSignalIngredientFragments(from: fragment).isEmpty
        }
    }

    nonisolated private static func ingredientCandidateFragmentsWithoutTitleStripping(from line: String) -> [String] {
        let cleaned = cleanedStructuredIngredientLine(line)
        guard !cleaned.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",/;+")
        let parts = cleaned
            .components(separatedBy: separators)
            .flatMap(sentenceBoundedIngredientFragments)
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [cleaned] : parts
    }

    nonisolated private static func hasQuantitylessHighSignalIngredient(in line: String) -> Bool {
        let normalized = normalizedIngredientText(line)
        guard !normalized.isEmpty else { return false }
        return quantitylessHighSignalIngredientAllowlist.contains(normalized)
    }

    nonisolated private static func sentenceBoundedIngredientFragments(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let sentenceParts = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard sentenceParts.count > 1 else {
            return [trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".!?").union(.whitespacesAndNewlines))]
        }
        let ingredientLike = sentenceParts.filter { part in
            hasQuantityPattern(in: part)
                || hasQuantoBastaPattern(in: part)
                || (hasBareCountPattern(in: part) && hasFoodSignal(in: normalizedIngredientText(part)))
                || hasQuantitylessHighSignalIngredient(in: part)
        }
        return ingredientLike.isEmpty ? [trimmed] : ingredientLike
    }

    nonisolated private static func quantitylessHighSignalIngredientFragments(from line: String) -> [String] {
        let normalized = normalizedIngredientText(line)
        guard !normalized.isEmpty else { return [] }
        return quantitylessHighSignalIngredientAllowlist
            .filter { phrase in
                let escaped = NSRegularExpression.escapedPattern(for: phrase)
                return normalized.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs < rhs
            }
            .reduce(into: [String]()) { result, phrase in
                guard !result.contains(where: { existing in
                    let existingTokens = Set(existing.split(separator: " ").map(String.init))
                    let phraseTokens = Set(phrase.split(separator: " ").map(String.init))
                    return phraseTokens.isSubset(of: existingTokens)
                }) else { return }
                result.append(phrase)
            }
    }

    nonisolated private static let quantitylessHighSignalIngredientAllowlist: Set<String> = [
            "burro",
            "basilico",
            "pepe nero",
            "pepe",
            "pecorino romano",
            "pecorino",
            "parmigiano reggiano",
            "parmigiano",
            "brodo vegetale",
            "brodo",
            "capperi",
            "capperi sotto sale",
            "prezzemolo",
            "origano",
            "olio evo",
            "olio",
            "aglio",
            "limone",
            "paprika",
            "sedano",
            "sale",
            "olive",
            "olive verdi",
            "olive nere",
            "curry",
            "latte di cocco",
            "tonno",
            "pomodoro",
            "pomodori",
            "pomodorino",
            "pomodorini",
            "spaghetti",
            "bucatini",
            "riso",
            "ceci",
            "cipolla",
            "cipolla rossa",
            "cipolla bianca",
            "rosmarino",
            "peperoncino",
            "patate",
            "carote",
            "lenticchie"
        ]

    nonisolated private static func isLikelyNoiseIngredientLine(_ line: String) -> Bool {
        let normalized = normalizedIngredientText(line)
        guard !normalized.isEmpty else { return true }
        let ctaPhrases = [
            "salva il video", "salva la ricetta", "seguimi", "follow", "like",
            "commenta", "condividi", "link in bio", "ricetta completa",
            "semplice ma top", "troppo buono", "pronto in", "in pochi minuti",
            "salvalo", "salvala", "save this", "save for later"
        ]
        if ctaPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }
        if normalized.range(of: #"\b(?:in\s*)?\d+\s*(min|mins|minuti|minutes|ore|h)\b"#, options: .regularExpression) != nil,
           !hasFoodSignal(in: normalized) {
            return true
        }
        return false
    }

    nonisolated private static func hasFoodSignal(in normalizedLine: String) -> Bool {
        let tokens = Set(normalizedLine.split(separator: " ").map(String.init))
        let signals = Set([
            "g", "kg", "ml", "l", "qb", "q", "b", "sale", "pepe", "olio",
            "uovo", "uova", "pasta", "riso", "aglio", "cipolla", "carota",
            "zucchina", "zucchine", "patata", "patate", "fungo", "funghi",
            "acciuga", "acciughe", "pomodoro", "pomodori", "basilico",
            "prezzemolo", "origano", "capperi", "brodo", "burro", "olive",
            "olio", "aglio", "limone", "paprika", "sedano", "tonno", "latte", "cocco",
            "salmone", "orata", "pesce", "spada", "pollo", "melanzana", "melanzane",
            "pomodorino", "pomodorini", "spaghetti", "bucatini", "curry",
            "ceci", "rosmarino", "peperoncino", "lenticchie"
        ])
        return !tokens.isDisjoint(with: signals)
    }

    private static func titleIngredientCandidates(
        from lines: [String],
        existingCandidates: [String],
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> [String] {
        let existingText = normalizedIngredientText(existingCandidates.joined(separator: " "))
        var seen = Set(existingCandidates.map(normalizedIngredientText))
        return lines.compactMap { line in
            guard let colonRange = line.range(of: ":") else { return nil }
            let prefix = String(line[..<colonRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty,
                  prefix.split(whereSeparator: { $0.isWhitespace }).count <= 4 else {
                return nil
            }

            let candidates = titleIngredientSurfaceCandidates(from: prefix)
            for candidate in candidates {
                let normalized = normalizedIngredientText(candidate)
                guard !normalized.isEmpty,
                      !seen.contains(normalized),
                      existingText.range(
                        of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: normalized))(?![a-z0-9])"#,
                        options: .regularExpression
                      ) == nil else {
                    continue
                }
                if detectIngredientMatch(
                    in: candidate,
                    produceItems: produceItems,
                    basicIngredients: basicIngredients,
                    languageCode: languageCode
                ) != nil || shouldPreserveCustomOnlyIngredient(candidate) {
                    seen.insert(normalized)
                    return candidate
                }
            }
            return nil
        }
    }

    nonisolated private static func titleIngredientSurfaceCandidates(from prefix: String) -> [String] {
        let normalized = normalizedIngredientText(prefix)
        guard !normalized.isEmpty else { return [] }
        let protectedPhrases = ["pesce spada", "latte di cocco", "salmone", "orata", "pollo"]
        if let protected = protectedPhrases.first(where: { normalized.contains($0) }) {
            return [protected]
        }
        let droppedDescriptors = normalized
            .replacingOccurrences(of: #"(?i)\b(al|alla|allo|alle|ai|agli|con|in)\b.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstToken = normalized.split(separator: " ").first.map(String.init) ?? normalized
        return [droppedDescriptors, firstToken, normalized, prefix]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func forcedProtectedIngredientMatch(
        normalizedText: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient]
    ) -> IngredientCatalogMatch? {
        if protectedText(normalizedText, matches: ["melanzana", "melanzane"]),
           let eggplant = produceItems.first(where: { $0.id == "eggplant" }) {
            return .produce(eggplant)
        }
        if protectedText(normalizedText, matches: ["salmone", "salmon"]),
           let salmon = basicIngredients.first(where: { $0.id == "salmon" }) {
            return .basic(salmon)
        }
        if protectedText(normalizedText, matches: ["orata", "sea bream"]),
           let seaBream = basicIngredients.first(where: { $0.id == "sea_bream" }) {
            return .basic(seaBream)
        }
        if protectedText(normalizedText, matches: ["pesce spada", "swordfish"]),
           let swordfish = basicIngredients.first(where: { $0.id == "swordfish" }) {
            return .basic(swordfish)
        }
        if protectedText(normalizedText, matches: ["pollo", "chicken", "petto di pollo"]),
           let chicken = basicIngredients.first(where: { $0.id == "chicken" }) {
            return .basic(chicken)
        }
        if protectedText(normalizedText, matches: ["latte di cocco", "coconut milk"]),
           let coconutMilk = basicIngredients.first(where: { $0.id == "coconut_milk" }) {
            return .basic(coconutMilk)
        }
        if protectedText(normalizedText, matches: ["capperi sotto sale"]),
           let capers = basicIngredients.first(where: { $0.id == "capers" }) {
            return .basic(capers)
        }
        if protectedText(normalizedText, matches: ["pasta"]),
           protectedText(normalizedText, matches: ["capperi", "capers"]),
           let pasta = basicIngredients.first(where: { $0.id == "pasta" }) {
            return .basic(pasta)
        }
        return nil
    }

    private static func forcedProtectedCatalogDecision(
        normalizedText: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient]
    ) -> SmartImportCatalogMatch? {
        if protectedText(normalizedText, matches: ["melanzana", "melanzane"]),
           produceItems.contains(where: { $0.id == "eggplant" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "produce:eggplant", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["salmone", "salmon"]),
           basicIngredients.contains(where: { $0.id == "salmon" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:salmon", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["orata", "sea bream"]),
           basicIngredients.contains(where: { $0.id == "sea_bream" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:sea_bream", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["pesce spada", "swordfish"]),
           basicIngredients.contains(where: { $0.id == "swordfish" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:swordfish", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["pollo", "chicken", "petto di pollo"]),
           basicIngredients.contains(where: { $0.id == "chicken" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:chicken", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["latte di cocco", "coconut milk"]),
           basicIngredients.contains(where: { $0.id == "coconut_milk" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:coconut_milk", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["capperi sotto sale"]),
           basicIngredients.contains(where: { $0.id == "capers" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:capers", confidence: 0.99)
        }
        if protectedText(normalizedText, matches: ["pasta"]),
           protectedText(normalizedText, matches: ["capperi", "capers"]),
           basicIngredients.contains(where: { $0.id == "pasta" }) {
            return SmartImportCatalogMatch(matchType: .exact, matchedIngredientId: "basic:pasta", confidence: 0.99)
        }
        return nil
    }

    nonisolated private static func shouldBlockGenericProtectedMatch(_ normalizedText: String) -> Bool {
        protectedText(normalizedText, matches: ["latte di cocco", "coconut milk", "orata", "pesce spada", "swordfish", "melanzana", "melanzane"])
    }

    nonisolated private static func shouldPreserveCustomOnlyIngredient(_ raw: String) -> Bool {
        let normalized = normalizedIngredientText(raw)
        return shouldBlockGenericProtectedMatch(normalized)
    }

    nonisolated private static func protectedText(_ normalizedText: String, matches phrases: [String]) -> Bool {
        phrases.contains { phrase in
            normalizedText.range(
                of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: phrase))(?![a-z0-9])"#,
                options: .regularExpression
            ) != nil
        }
    }

    private static func detectIngredientMatch(
        in line: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> IngredientCatalogMatch? {
        let normalizedLine = normalizedIngredientText(line)
        guard !normalizedLine.isEmpty else { return nil }
        if let forced = forcedProtectedIngredientMatch(
            normalizedText: normalizedLine,
            produceItems: produceItems,
            basicIngredients: basicIngredients
        ) {
            return forced
        }
        if shouldBlockGenericProtectedMatch(normalizedLine) {
            return nil
        }

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
        ] + (smartImportLocalAliases[item.id] ?? [])
        return normalizedCandidates(from: names)
    }

    private static func basicCandidateNames(for item: BasicIngredient, languageCode: String) -> [String] {
        let names = [
            item.displayName(languageCode: languageCode),
            item.displayName(languageCode: "en"),
            item.id.replacingOccurrences(of: "_", with: " ")
        ] + (smartImportLocalAliases[item.id] ?? [])
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
        variants.append(italianLexicalNormalized(candidate))
        guard tokens.count == 1, let token = tokens.first, token.count >= 4 else {
            return variants
        }

        if let mapped = italianLexicalVariants[token] {
            variants.append(contentsOf: mapped)
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
        "olive": ["tapenade"],
        "sale": ["capperi", "sotto"]
    ]

    nonisolated private static let italianLexicalVariants: [String: [String]] = [
        "uovo": ["uovo", "uova"],
        "uova": ["uovo", "uova"],
        "carota": ["carota", "carote"],
        "carote": ["carota", "carote"],
        "zucchina": ["zucchina", "zucchine"],
        "zucchine": ["zucchina", "zucchine"],
        "patata": ["patata", "patate"],
        "patate": ["patata", "patate"],
        "cipolla": ["cipolla", "cipolle"],
        "cipolle": ["cipolla", "cipolle"],
        "fungo": ["fungo", "funghi"],
        "funghi": ["fungo", "funghi"],
        "pomodoro": ["pomodoro", "pomodori"],
        "pomodori": ["pomodoro", "pomodori"],
        "pomodorino": ["pomodoro", "pomodorino", "pomodorini"],
        "pomodorini": ["pomodoro", "pomodorino", "pomodorini"],
        "melanzana": ["melanzana", "melanzane"],
        "melanzane": ["melanzana", "melanzane"],
        "dorate": ["dorata", "dorate"]
    ]

    private static let smartImportLocalAliases: [String: [String]] = [
        "flour": ["farina", "farina 00", "flour"],
        "pasta": ["spaghetti", "bucatini", "pasta"],
        "rice": ["riso", "riso secco"],
        "tomato": ["pomodoro", "pomodori", "pomodorino", "pomodorini", "pomodoro san marzano"],
        "basil": ["basilico"],
        "parsley": ["prezzemolo"],
        "oregano": ["origano"],
        "carrot": ["carota", "carote"],
        "onion": ["cipolla", "cipolle", "cipolle dorate", "cipolla dorata"],
        "mushroom": ["fungo", "funghi"],
        "potato": ["patata", "patate"],
        "zucchini": ["zucchina", "zucchine"],
        "eggplant": ["melanzana", "melanzane"],
        "passata": ["passata di pomodoro"],
        "pecorino": ["pecorino romano"],
        "parmesan": ["parmigiano reggiano", "parmigiano"],
        "black_pepper": ["pepe nero", "pepe"],
        "guanciale": ["guanciale"],
        "curry_powder": ["curry"],
        "tuna": ["tonno sott olio", "tonno sottolio", "tonno"],
        "anchovies": ["acciughe sott olio", "acciughe sottolio", "acciughe"],
        "capers": ["capperi sotto sale", "capperi"],
        "coconut_milk": ["latte di cocco"],
        "sea_bream": ["orata"],
        "swordfish": ["pesce spada"],
        "green_olives": ["olive", "olive verdi"],
        "black_olives": ["olive nere"],
        "olive_oil": ["olio evo", "olio extravergine", "olio extra vergine", "olio"],
        "broth": ["brodo", "brodo vegetale"],
        "salt": ["sale"],
        "eggs": ["uovo", "uova", "egg", "eggs"]
    ]

    nonisolated private static func normalizedIngredientText(_ raw: String) -> String {
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
        return italianLexicalNormalized(collapsed)
    }

    nonisolated private static func italianLexicalNormalized(_ raw: String) -> String {
        raw
            .split(separator: " ")
            .map { token in italianLexicalVariants[String(token)]?.first ?? String(token) }
            .joined(separator: " ")
    }

    private static func extractQuantity(from line: String) -> (value: Double, unit: RecipeQuantityUnit) {
        if let parsed = parsedSmartImportQuantity(from: line),
           let unit = recipeQuantityUnit(from: parsed.unit) {
            return (parsed.value, unit)
        }
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

    private static func recipeQuantityUnit(from raw: String?) -> RecipeQuantityUnit? {
        guard let raw else { return .piece }
        return RecipeQuantityUnit(rawValue: raw)
    }

    private static func parsedIngredientCandidateText(
        _ raw: String
    ) -> (normalizedText: String, quantity: Double?, unit: String?) {
        let cleaned = cleanedStructuredIngredientLine(raw)
        let quantity = parsedSmartImportQuantity(from: cleaned)
        var normalized = cleaned
            .replacingOccurrences(
                of: #"(?i)\b(?:\d+/\d+|\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cup|cups|cucchiaio|cucchiai|cucchiaino|cucchiaini|piece|pieces|pezzo|pezzi|costa|coste|foglia|foglie|spicchio|spicchi)?\b"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b(q\.?b\.?|quanto basta)\b"#,
                with: " ",
                options: .regularExpression
            )
        normalized = normalizedIngredientText(normalized)
        return (normalized, quantity?.value, quantity?.unit)
    }

    private static func parsedSmartImportQuantity(from raw: String) -> (value: Double, unit: String?)? {
        let pattern = #"(?i)\b(\d+/\d+|\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cup|cups|cucchiaio|cucchiai|cucchiaino|cucchiaini|piece|pieces|pezzo|pezzi|costa|coste|foglia|foglie|spicchio|spicchi)?\b"#
        let reversedPattern = #"(?i)\b([a-zÀ-ÖØ-öø-ÿ0-9][a-zÀ-ÖØ-öø-ÿ0-9\s']{1,40}?)\s+(\d+/\d+|\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cup|cups|cucchiaio|cucchiai|cucchiaino|cucchiaini|piece|pieces|pezzo|pezzi|costa|coste|foglia|foglie|spicchio|spicchi)?\s*$"#

        if let reversed = parsedQuantityMatch(in: raw, pattern: reversedPattern, quantityGroup: 2, unitGroup: 3) {
            return reversed
        }

        return parsedQuantityMatch(in: raw, pattern: pattern, quantityGroup: 1, unitGroup: 2)
    }

    private static func parsedQuantityMatch(
        in raw: String,
        pattern: String,
        quantityGroup: Int,
        unitGroup: Int
    ) -> (value: Double, unit: String?)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: nsRange),
              let quantityRange = Range(match.range(at: quantityGroup), in: raw) else { return nil }

        let quantityToken = String(raw[quantityRange]).replacingOccurrences(of: ",", with: ".")
        let parsedValue: Double? = {
            if quantityToken.contains("/") {
                let parts = quantityToken.split(separator: "/")
                guard parts.count == 2,
                      let numerator = Double(parts[0]),
                      let denominator = Double(parts[1]),
                      denominator != 0 else { return nil }
                return numerator / denominator
            }
            return Double(quantityToken)
        }()
        guard let parsedValue, parsedValue > 0 else { return nil }

        let unitToken: String? = {
            guard match.numberOfRanges > unitGroup,
                  let unitRange = Range(match.range(at: unitGroup), in: raw) else { return nil }
            let value = String(raw[unitRange]).lowercased()
            return value.isEmpty ? nil : value
        }()

        switch unitToken {
        case "kg":
            return (parsedValue * 1000, "g")
        case "g":
            return (parsedValue, "g")
        case "l":
            return (parsedValue * 1000, "ml")
        case "ml":
            return (parsedValue, "ml")
        case "tbsp":
            return (parsedValue, "tbsp")
        case "tsp":
            return (parsedValue, "tsp")
        case "cucchiaio", "cucchiai":
            return (parsedValue, "tbsp")
        case "cucchiaino", "cucchiaini":
            return (parsedValue, "tsp")
        case "spicchio", "spicchi":
            return (parsedValue, "clove")
        case "piece", "pieces", "pezzo", "pezzi", "costa", "coste", "foglia", "foglie":
            return (parsedValue, "piece")
        default:
            return (parsedValue, nil)
        }
    }

    private static func detectCatalogDecision(
        normalizedText: String,
        produceItems: [ProduceItem],
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> SmartImportCatalogMatch {
        if let forced = forcedProtectedCatalogDecision(
            normalizedText: normalizedText,
            produceItems: produceItems,
            basicIngredients: basicIngredients
        ) {
            return forced
        }
        if shouldBlockGenericProtectedMatch(normalizedText) {
            return SmartImportCatalogMatch(matchType: .none, matchedIngredientId: nil, confidence: 0)
        }

        let produce = bestPreparseProduceMatch(
            normalizedText: normalizedText,
            produceItems: produceItems,
            languageCode: languageCode
        )
        let basic = bestPreparseBasicMatch(
            normalizedText: normalizedText,
            basicIngredients: basicIngredients,
            languageCode: languageCode
        )

        let best: (source: String, id: String, score: Int, length: Int)?
        switch (produce, basic) {
        case (.none, .none):
            return SmartImportCatalogMatch(matchType: .none, matchedIngredientId: nil, confidence: 0)
        case let (.some(produce), .none):
            best = ("produce", produce.item.id, produce.score, produce.length)
        case let (.none, .some(basic)):
            best = ("basic", basic.item.id, basic.score, basic.length)
        case let (.some(produce), .some(basic)):
            if produce.score == basic.score && produce.length == basic.length {
                return SmartImportCatalogMatch(matchType: .ambiguous, matchedIngredientId: nil, confidence: 0.55)
            }
            if produce.score != basic.score {
                best = produce.score > basic.score
                    ? ("produce", produce.item.id, produce.score, produce.length)
                    : ("basic", basic.item.id, basic.score, basic.length)
            } else {
                best = produce.length > basic.length
                    ? ("produce", produce.item.id, produce.score, produce.length)
                    : ("basic", basic.item.id, basic.score, basic.length)
            }
        }

        guard let best else {
            return SmartImportCatalogMatch(matchType: .none, matchedIngredientId: nil, confidence: 0)
        }
        let matchType: SmartImportMatchType = best.score >= 4 ? .exact : .alias
        let confidence: Double = {
            switch best.score {
            case 4...:
                return 0.98
            case 3:
                return 0.9
            default:
                return 0.72
            }
        }()
        return SmartImportCatalogMatch(
            matchType: matchType,
            matchedIngredientId: "\(best.source):\(best.id)",
            confidence: confidence
        )
    }

    private static func bestPreparseProduceMatch(
        normalizedText: String,
        produceItems: [ProduceItem],
        languageCode: String
    ) -> ScoredItemMatch<ProduceItem>? {
        var best: ScoredItemMatch<ProduceItem>?
        for item in produceItems {
            for candidate in produceCandidateNames(for: item, languageCode: languageCode) {
                guard let score = preparseMatchScore(normalizedText: normalizedText, candidate: candidate) else { continue }
                let match = ScoredItemMatch(item: item, score: score, length: candidate.count)
                if best == nil || match > best! {
                    best = match
                }
            }
        }
        return best
    }

    private static func bestPreparseBasicMatch(
        normalizedText: String,
        basicIngredients: [BasicIngredient],
        languageCode: String
    ) -> ScoredItemMatch<BasicIngredient>? {
        var best: ScoredItemMatch<BasicIngredient>?
        for item in basicIngredients {
            for candidate in basicCandidateNames(for: item, languageCode: languageCode) {
                guard let score = preparseMatchScore(normalizedText: normalizedText, candidate: candidate) else { continue }
                let match = ScoredItemMatch(item: item, score: score, length: candidate.count)
                if best == nil || match > best! {
                    best = match
                }
            }
        }
        return best
    }

    private static func preparseMatchScore(normalizedText: String, candidate: String) -> Int? {
        guard !normalizedText.isEmpty, !candidate.isEmpty else { return nil }
        if normalizedText == candidate {
            return 4
        }
        return matchScore(in: normalizedText, candidate: candidate)
    }

    private static func classifyConfidence(
        hasStructuredSections: Bool,
        suggestedTitle: String?,
        suggestedIngredients: [RecipeIngredient],
        suggestedSteps: [String]
    ) -> SocialImportConfidence {
        let ingredientCount = suggestedIngredients.count
        let stepCount = suggestedSteps.count
        let mappedIngredientCount = suggestedIngredients.filter(\.hasCatalogIdentity).count
        let hasMeaningfulTitle: Bool = {
            guard let title = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return false }
            return title.lowercased() != "untitled recipe"
        }()

        if ingredientCount == 0 && stepCount == 0 {
            return .low
        }

        var score = 0
        if hasStructuredSections { score += 3 }
        if ingredientCount >= 5 {
            score += 2
        } else if ingredientCount >= 2 {
            score += 1
        }
        if stepCount >= 3 {
            score += 2
        } else if stepCount >= 1 {
            score += 1
        }
        if hasMeaningfulTitle { score += 1 }
        if mappedIngredientCount >= 3 {
            score += 2
        } else if mappedIngredientCount >= 1 {
            score += 1
        }

        if ingredientCount <= 1 { score -= 1 }
        if !hasStructuredSections && stepCount == 0 { score -= 1 }
        if !hasStructuredSections && ingredientCount > 0 && mappedIngredientCount == 0 { score -= 2 }

        if score >= 6 { return .high }
        if score >= 3 { return .medium }
        return .low
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
