import Foundation

private actor CatalogEnrichmentRemoteMetrics {
    static let shared = CatalogEnrichmentRemoteMetrics()

    private var totalCalls = 0
    private var successCalls = 0
    private var fallbackCalls = 0
    private var errorByType: [String: Int] = [:]

    func recordSuccess() {
        totalCalls += 1
        successCalls += 1
        logSnapshot(event: "success", errorType: nil)
    }

    func recordFallback(errorType: String?) {
        totalCalls += 1
        fallbackCalls += 1
        if let errorType {
            errorByType[errorType, default: 0] += 1
        }
        logSnapshot(event: "fallback", errorType: errorType)
    }

    private func logSnapshot(event: String, errorType: String?) {
        let successRate = totalCalls > 0 ? Double(successCalls) / Double(totalCalls) : 0
        let fallbackRate = totalCalls > 0 ? Double(fallbackCalls) / Double(totalCalls) : 0
        let errorSummary = errorByType
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        print(
            "[SEASON_CATALOG_ENRICH_METRICS] " +
            "event=\(event) " +
            "total=\(totalCalls) " +
            "success=\(successCalls) " +
            "fallback=\(fallbackCalls) " +
            "success_rate=\(String(format: "%.3f", successRate)) " +
            "fallback_rate=\(String(format: "%.3f", fallbackRate)) " +
            "error_type=\(errorType ?? "none") " +
            "errors=\(errorSummary.isEmpty ? "none" : errorSummary)"
        )
    }
}

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

struct EdgeFunctionRemoteCatalogEnrichmentProvider: RemoteCatalogEnrichmentProposalProviding {
    private let supabaseService: SupabaseService
    private let timeoutSeconds: TimeInterval = 6
    private let maxAttempts = 2
    private let initialBackoffNanos: UInt64 = 300_000_000

    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }

    func proposeRemotely(for normalizedText: String) async -> CatalogEnrichmentProposal? {
        let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        var backoffNanos = initialBackoffNanos
        for attempt in 1...maxAttempts {
            do {
                let response = try await withTimeout(seconds: timeoutSeconds) {
                    try await supabaseService.fetchCatalogEnrichmentProposal(
                        normalizedText: normalized
                    )
                }
                guard let proposal = mapFromEdgeFunctionResponse(response, normalizedText: normalized) else {
                    print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_failed reason=unusable_payload normalized_text=\(normalized) attempt=\(attempt)")
                    await CatalogEnrichmentRemoteMetrics.shared.recordFallback(errorType: "unusable_payload")
                    return nil
                }

                print("[SEASON_CATALOG_ENRICH] phase=remote_proposal_ok source=edge_function normalized_text=\(normalized) attempt=\(attempt)")
                await CatalogEnrichmentRemoteMetrics.shared.recordSuccess()
                return proposal
            } catch {
                let errorType = classifyErrorType(error)
                let retryable = isRetryable(error)
                let isLastAttempt = attempt == maxAttempts
                print(
                    "[SEASON_CATALOG_ENRICH] phase=remote_proposal_failed " +
                    "reason=rpc_error normalized_text=\(normalized) " +
                    "attempt=\(attempt) retryable=\(retryable) " +
                    "error_type=\(errorType) error=\(error)"
                )

                if retryable && !isLastAttempt {
                    try? await Task.sleep(nanoseconds: backoffNanos)
                    backoffNanos *= 2
                    continue
                }

                await CatalogEnrichmentRemoteMetrics.shared.recordFallback(errorType: errorType)
                return nil
            }
        }

        await CatalogEnrichmentRemoteMetrics.shared.recordFallback(errorType: "unknown")
        return nil
    }

    private func isRetryable(_ error: Error) -> Bool {
        if error is SupabaseServiceError { return true }
        let description = String(describing: error).lowercased()
        if description.contains("http error 429") {
            return false
        }
        if description.contains("timed out") ||
            description.contains("timeout") ||
            description.contains("network") ||
            description.contains("connection") ||
            description.contains("http error 5") ||
            description.contains("relayerror") {
            return true
        }
        return false
    }

    private func classifyErrorType(_ error: Error) -> String {
        if let serviceError = error as? SupabaseServiceError {
            switch serviceError {
            case .unauthenticated:
                return "unauthenticated"
            case .requestTimedOut:
                return "timeout"
            case .missingConfiguration:
                return "missing_configuration"
            case .invalidURL:
                return "invalid_url"
            }
        }
        let description = String(describing: error).lowercased()
        if description.contains("http error 429") { return "http_429" }
        if description.contains("502") { return "http_502" }
        if description.contains("http error 5") { return "http_5xx" }
        if description.contains("timeout") || description.contains("timed out") { return "timeout" }
        return "unknown"
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SupabaseServiceError.requestTimedOut("catalog_enrichment_remote_provider", seconds)
            }

            let first = try await group.next()
            group.cancelAll()
            guard let first else {
                throw SupabaseServiceError.requestTimedOut("catalog_enrichment_remote_provider", seconds)
            }
            return first
        }
    }

    private func mapFromEdgeFunctionResponse(
        _ result: CatalogEnrichmentProposalFunctionResponse,
        normalizedText: String
    ) -> CatalogEnrichmentProposal? {
        let canonicalIT = cleaned(result.canonical_name_it)
        let canonicalEN = cleaned(result.canonical_name_en)
        guard canonicalIT != nil || canonicalEN != nil else { return nil }

        let suggestedSlug = cleaned(result.suggested_slug.lowercased()) ?? slugify(normalizedText)
        let defaultUnit = cleaned(result.default_unit.lowercased()) ?? "piece"
        var supportedUnits = result.supported_units
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if !supportedUnits.contains(defaultUnit) {
            supportedUnits.append(defaultUnit)
        }

        let ingredientType = result.ingredient_type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedType = ["produce", "basic", "unknown"].contains(ingredientType) ? ingredientType : "unknown"
        let seasonMonths = (result.season_months ?? []).filter { (1...12).contains($0) }

        return CatalogEnrichmentProposal(
            normalizedText: normalizedText,
            ingredientType: normalizedType,
            canonicalNameIT: canonicalIT,
            canonicalNameEN: canonicalEN,
            suggestedSlug: suggestedSlug,
            defaultUnit: defaultUnit,
            supportedUnits: supportedUnits.isEmpty ? [defaultUnit] : supportedUnits,
            isSeasonal: normalizedType == "produce" ? result.is_seasonal : nil,
            seasonMonths: normalizedType == "produce" ? seasonMonths : [],
            needsManualReview: result.needs_manual_review,
            reasoningSummary: cleaned(result.reasoning_summary),
            confidenceScore: normalizedConfidence(result.confidence_score)
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
        print("[SEASON_CATALOG_ENRICH] phase=provider_fallback_used normalized_text=\(normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) fallback=deterministic")
        return await fallbackProvider.propose(for: normalizedText)
    }
}

enum CatalogEnrichmentProviders {
    static let deterministic: any CatalogEnrichmentProposalProviding = DeterministicCatalogEnrichmentProposalProvider()

    static let `default`: any CatalogEnrichmentProposalProviding = CatalogEnrichmentProposalProviderPipeline(
        remoteProvider: EdgeFunctionRemoteCatalogEnrichmentProvider(),
        fallbackProvider: DeterministicCatalogEnrichmentProposalProvider()
    )
}
