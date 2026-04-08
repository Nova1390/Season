import Foundation

struct CatalogEnrichmentProposal: Sendable {
    let normalizedText: String
    let ingredientType: String
    let canonicalNameIT: String?
    let canonicalNameEN: String?
    let suggestedSlug: String
    let defaultUnit: String
    let supportedUnits: [String]
    let isSeasonal: Bool?
    let seasonMonths: [Int]
    let needsManualReview: Bool
    let reasoningSummary: String?
    let confidenceScore: Double?
}

protocol CatalogEnrichmentProposalProviding {
    func propose(for normalizedText: String) async -> CatalogEnrichmentProposal?
}

protocol RemoteCatalogEnrichmentProposalProviding {
    func proposeRemotely(for normalizedText: String) async -> CatalogEnrichmentProposal?
}

struct ParseRecipeCaptionRemoteCatalogEnrichmentProvider: RemoteCatalogEnrichmentProposalProviding {
    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }

    func proposeRemotely(for normalizedText: String) async -> CatalogEnrichmentProposal? {
        let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        do {
            let response = try await supabaseService.parseRecipeCaption(
                caption: enrichmentPrompt(for: normalized),
                url: nil,
                languageCode: "en"
            )
            guard response.ok, let result = response.result else {
                print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_failed reason=invalid_response normalized_text=\(normalized)")
                return nil
            }

            if let inferredDishPayload = result.inferredDish,
               let proposal = parseProposalJSON(inferredDishPayload, normalizedText: normalized) {
                print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_ok source=inferred_dish_json normalized_text=\(normalized)")
                return proposal
            }

            if let fallback = mapFromRecipeImportResult(result, normalizedText: normalized) {
                print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_ok source=recipe_result_fallback normalized_text=\(normalized)")
                return fallback
            }

            print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_failed reason=unusable_payload normalized_text=\(normalized)")
            return nil
        } catch {
            print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_failed reason=rpc_error normalized_text=\(normalized) error=\(error)")
            return nil
        }
    }

    // Fixed remote prompt + structured contract (proposal-only).
    // The provider asks the server-side parser to encode this JSON in inferredDish.
    // {
    //   "ingredient_type":"produce|basic|unknown",
    //   "canonical_name_it":"...",
    //   "canonical_name_en":"...",
    //   "suggested_slug":"...",
    //   "default_unit":"piece|g|ml|tbsp|tsp",
    //   "supported_units":["..."],
    //   "is_seasonal":true|false|null,
    //   "season_months":[1..12],
    //   "needs_manual_review":true,
    //   "reasoning_summary":"...",
    //   "confidence_score":0.0-1.0
    // }
    private func enrichmentPrompt(for normalizedText: String) -> String {
        """
        Catalog enrichment task for a single ingredient candidate.
        Candidate text: "\(normalizedText)"

        Build an enrichment proposal and encode it as strict JSON in the inferredDish field.
        This is proposal-only for admin review (never auto-approve).

        Required JSON keys:
        ingredient_type, canonical_name_it, canonical_name_en, suggested_slug,
        default_unit, supported_units, is_seasonal, season_months,
        needs_manual_review, reasoning_summary, confidence_score.

        Rules:
        - ingredient_type must be one of produce/basic/unknown.
        - suggested_slug lowercase snake_case.
        - supported_units must include default_unit.
        - if produce and seasonal, include season_months.
        - if uncertain, set ingredient_type=unknown and lower confidence_score.
        - keep needs_manual_review=true.
        """
    }

    private func parseProposalJSON(_ raw: String, normalizedText: String) -> CatalogEnrichmentProposal? {
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let dict = object as? [String: Any] else {
            return nil
        }

        let ingredientType = (dict["ingredient_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        let canonicalIT = cleaned(dict["canonical_name_it"] as? String)
        let canonicalEN = cleaned(dict["canonical_name_en"] as? String)
        let suggestedSlug = cleaned((dict["suggested_slug"] as? String)?.lowercased()) ?? slugify(normalizedText)
        let defaultUnit = cleaned((dict["default_unit"] as? String)?.lowercased()) ?? "piece"
        let supportedUnitsRaw = dict["supported_units"] as? [Any] ?? []
        var supportedUnits = supportedUnitsRaw
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if !supportedUnits.contains(defaultUnit) {
            supportedUnits.append(defaultUnit)
        }
        let isSeasonal = dict["is_seasonal"] as? Bool
        let seasonMonths = (dict["season_months"] as? [Any] ?? []).compactMap { $0 as? Int }.filter { (1...12).contains($0) }
        let needsManualReview = (dict["needs_manual_review"] as? Bool) ?? true
        let reasoningSummary = cleaned(dict["reasoning_summary"] as? String)
        let confidenceScore = normalizedConfidence(dict["confidence_score"])

        guard canonicalIT != nil || canonicalEN != nil else { return nil }

        return CatalogEnrichmentProposal(
            normalizedText: normalizedText,
            ingredientType: ["produce", "basic", "unknown"].contains(ingredientType) ? ingredientType : "unknown",
            canonicalNameIT: canonicalIT,
            canonicalNameEN: canonicalEN,
            suggestedSlug: suggestedSlug,
            defaultUnit: defaultUnit,
            supportedUnits: supportedUnits.isEmpty ? [defaultUnit] : supportedUnits,
            isSeasonal: isSeasonal,
            seasonMonths: seasonMonths,
            needsManualReview: needsManualReview,
            reasoningSummary: reasoningSummary,
            confidenceScore: confidenceScore
        )
    }

    private func mapFromRecipeImportResult(
        _ result: ParseRecipeCaptionFunctionResult,
        normalizedText: String
    ) -> CatalogEnrichmentProposal? {
        let canonicalIT = cleaned(result.title)
        let canonicalEN = cleaned(result.ingredients.first?.name)
        guard canonicalIT != nil || canonicalEN != nil else { return nil }

        let defaultUnit = cleaned(result.ingredients.first?.unit)?.lowercased() ?? "piece"
        return CatalogEnrichmentProposal(
            normalizedText: normalizedText,
            ingredientType: "unknown",
            canonicalNameIT: canonicalIT,
            canonicalNameEN: canonicalEN,
            suggestedSlug: slugify(canonicalIT?.lowercased() ?? normalizedText),
            defaultUnit: defaultUnit,
            supportedUnits: inferredSupportedUnits(from: defaultUnit),
            isSeasonal: nil,
            seasonMonths: [],
            needsManualReview: true,
            reasoningSummary: "Remote proposal generated via parse-recipe-caption.",
            confidenceScore: confidenceScore(from: result.confidence)
        )
    }

    private func normalizedConfidence(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return min(max(value, 0), 1)
        }
        if let value = value as? Int {
            return min(max(Double(value), 0), 1)
        }
        if let value = value as? String, let parsed = Double(value) {
            return min(max(parsed, 0), 1)
        }
        return nil
    }

    private func confidenceScore(from label: String) -> Double {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "high": return 0.8
        case "medium": return 0.6
        case "low": return 0.4
        default: return 0.5
        }
    }

    private func inferredSupportedUnits(from defaultUnit: String) -> [String] {
        switch defaultUnit {
        case "ml":
            return ["ml", "g", "tbsp", "tsp"]
        case "g":
            return ["g", "piece", "ml"]
        case "tbsp", "tsp":
            return [defaultUnit, "ml", "g"]
        case "piece":
            return ["piece", "g"]
        default:
            return [defaultUnit, "piece"]
        }
    }

    private func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func slugify(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let slug = collapsed
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "^_+|_+$", with: "", options: .regularExpression)
        return slug.isEmpty ? "ingredient" : slug
    }
}

struct DeterministicCatalogEnrichmentProposalProvider: CatalogEnrichmentProposalProviding {
    func propose(for normalizedText: String) async -> CatalogEnrichmentProposal? {
        let normalized = normalizeCandidate(normalizedText)
        guard !normalized.isEmpty else { return nil }

        let inferredType = inferIngredientType(from: normalized)
        let inferredSeasonality = inferSeasonality(from: normalized, ingredientType: inferredType)
        let inferredUnits = inferUnitSuggestion(from: normalized, ingredientType: inferredType)

        return CatalogEnrichmentProposal(
            normalizedText: normalized,
            ingredientType: inferredType,
            canonicalNameIT: titleCaseIT(normalized),
            canonicalNameEN: nil,
            suggestedSlug: slugify(normalized),
            defaultUnit: inferredUnits.defaultUnit,
            supportedUnits: inferredUnits.supportedUnits,
            isSeasonal: inferredSeasonality.isSeasonal,
            seasonMonths: inferredSeasonality.seasonMonths,
            needsManualReview: true,
            reasoningSummary: "Suggested from deterministic candidate heuristics. Review before validation.",
            confidenceScore: nil
        )
    }

    private func normalizeCandidate(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func slugify(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let slug = collapsed
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "^_+|_+$", with: "", options: .regularExpression)
        return slug.isEmpty ? "ingredient" : slug
    }

    private func titleCaseIT(_ text: String) -> String {
        text
            .split(separator: " ")
            .map { token in
                guard let first = token.first else { return "" }
                return String(first).uppercased() + token.dropFirst()
            }
            .joined(separator: " ")
    }

    private func inferIngredientType(from normalized: String) -> String {
        let produceSignals: Set<String> = [
            "cicoria", "spinaci", "bietola", "lattuga", "radicchio", "sedano", "carota", "zucchina",
            "melanzana", "pomodoro", "cipolla", "aglio", "patata", "cavolo", "broccoli", "fagiolini",
            "finocchio", "rucola", "basilico", "prezzemolo", "limone", "mela", "pera", "arancia"
        ]
        let basicSignals: Set<String> = [
            "olio", "olio evo", "sale", "pepe", "zucchero", "farina", "pasta", "riso", "burro",
            "latte", "aceto", "parmigiano", "grana", "brodo", "salsa di pomodoro", "passata"
        ]

        if produceSignals.contains(normalized) {
            return "produce"
        }
        if basicSignals.contains(normalized) {
            return "basic"
        }
        return "unknown"
    }

    private func inferUnitSuggestion(from normalized: String, ingredientType: String) -> (defaultUnit: String, supportedUnits: [String]) {
        let liquidSignals = ["olio", "aceto", "latte", "brodo", "salsa", "passata"]
        let isLikelyLiquid = liquidSignals.contains { normalized.contains($0) }

        if isLikelyLiquid {
            return ("ml", ["ml", "g", "tbsp", "tsp"])
        }
        if ingredientType == "produce" {
            return ("g", ["g", "piece"])
        }
        if ingredientType == "basic" {
            return ("g", ["g", "ml", "tbsp", "tsp", "piece"])
        }
        return ("piece", ["piece", "g"])
    }

    private func inferSeasonality(from normalized: String, ingredientType: String) -> (isSeasonal: Bool?, seasonMonths: [Int]) {
        guard ingredientType == "produce" else {
            return (nil, [])
        }

        let seasonalityByName: [String: [Int]] = [
            "cicoria": [10, 11, 12, 1, 2, 3],
            "spinaci": [10, 11, 12, 1, 2, 3],
            "radicchio": [10, 11, 12, 1, 2],
            "finocchio": [11, 12, 1, 2, 3]
        ]

        if let months = seasonalityByName[normalized] {
            return (true, months)
        }
        return (false, [])
    }
}

struct CatalogEnrichmentProposalProviderPipeline: CatalogEnrichmentProposalProviding {
    let remoteProvider: (any RemoteCatalogEnrichmentProposalProviding)?
    let fallbackProvider: any CatalogEnrichmentProposalProviding

    func propose(for normalizedText: String) async -> CatalogEnrichmentProposal? {
        if let remoteProvider,
           let remoteProposal = await remoteProvider.proposeRemotely(for: normalizedText) {
            return remoteProposal
        }
        return await fallbackProvider.propose(for: normalizedText)
    }
}

enum CatalogEnrichmentProviders {
    static let deterministic: any CatalogEnrichmentProposalProviding = DeterministicCatalogEnrichmentProposalProvider()

    static let `default`: any CatalogEnrichmentProposalProviding = CatalogEnrichmentProposalProviderPipeline(
        remoteProvider: ParseRecipeCaptionRemoteCatalogEnrichmentProvider(),
        fallbackProvider: DeterministicCatalogEnrichmentProposalProvider()
    )
}
