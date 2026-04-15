import Foundation
import NaturalLanguage
import Translation

struct RecipeTranslationResult {
    let title: String
    let steps: [String]
    let freeTextIngredientNames: [String: String]
    let isAutomaticallyTranslated: Bool
}

@available(iOS 18.0, macOS 15.0, *)
actor RecipeTranslationService {
    static let shared = RecipeTranslationService()

    private struct CacheKey: Hashable {
        let recipeID: String
        let targetLanguageCode: String
    }

    private enum SegmentType {
        case title
        case step(index: Int)
        case ingredient(name: String)
    }

    private var cache: [CacheKey: RecipeTranslationResult] = [:]

    func configuration(for recipe: Recipe, targetLanguageCode: String) -> TranslationSession.Configuration? {
        let normalizedTargetCode = normalizeLanguageCode(targetLanguageCode)
        guard let targetLanguage = localeLanguage(from: normalizedTargetCode) else {
            return nil
        }

        let inferredSource = inferredSourceLanguage(for: recipe)
        if let inferredSource, inferredSource.minimalIdentifier == targetLanguage.minimalIdentifier {
            return nil
        }

        // Prefer inferred source language when available; otherwise let the API infer it.
        return TranslationSession.Configuration(source: inferredSource, target: targetLanguage)
    }

    func translate(
        recipe: Recipe,
        targetLanguageCode: String,
        session: TranslationSession
    ) async throws -> RecipeTranslationResult? {
        let normalizedTargetCode = normalizeLanguageCode(targetLanguageCode)
        let cacheKey = CacheKey(recipeID: recipe.id, targetLanguageCode: normalizedTargetCode)
        if let cached = cache[cacheKey] {
            return cached
        }

        let segments = translatableSegments(for: recipe)
        guard !segments.isEmpty else { return nil }

        let requests = segments.map { segment in
            TranslationSession.Request(
                sourceText: segment.text,
                clientIdentifier: segment.identifier
            )
        }

        let responses = try await session.translations(from: requests)
        let mapped = mapResponses(responses, originalRecipe: recipe, segments: segments)
        if mapped.isAutomaticallyTranslated {
            cache[cacheKey] = mapped
            return mapped
        }
        return nil
    }

    private func normalizeLanguageCode(_ code: String) -> String {
        String(code.prefix(2)).lowercased()
    }

    private func localeLanguage(from code: String) -> Locale.Language? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Locale.Language(identifier: trimmed)
    }

    private func inferredSourceLanguage(for recipe: Recipe) -> Locale.Language? {
        let corpus = ([recipe.title] + recipe.preparationSteps).joined(separator: " ")
        guard !corpus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(corpus)
        guard let dominant = recognizer.dominantLanguage else { return nil }

        return Locale.Language(identifier: dominant.rawValue)
    }

    private func translatableSegments(for recipe: Recipe) -> [(identifier: String, type: SegmentType, text: String)] {
        var segments: [(String, SegmentType, String)] = []

        let trimmedTitle = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            segments.append(("title", .title, trimmedTitle))
        }

        for (index, step) in recipe.preparationSteps.enumerated() {
            let trimmed = step.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(("step_\(index)", .step(index: index), trimmed))
            }
        }

        for ingredient in recipe.ingredients where !ingredient.hasCatalogIdentity {
            let trimmed = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(("ingredient_\(trimmed.lowercased())", .ingredient(name: ingredient.name), trimmed))
            }
        }

        return segments
    }

    private func mapResponses(
        _ responses: [TranslationSession.Response],
        originalRecipe: Recipe,
        segments: [(identifier: String, type: SegmentType, text: String)]
    ) -> RecipeTranslationResult {
        var translatedTitle = originalRecipe.title
        var translatedSteps = originalRecipe.preparationSteps
        var translatedFreeTextIngredients: [String: String] = [:]

        let responseByIdentifier: [String: TranslationSession.Response] = Dictionary(uniqueKeysWithValues: responses.compactMap { response in
            guard let identifier = response.clientIdentifier else { return nil }
            return (identifier, response)
        })

        for segment in segments {
            guard let response = responseByIdentifier[segment.identifier] else { continue }
            let translatedText = response.targetText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !translatedText.isEmpty else { continue }

            switch segment.type {
            case .title:
                translatedTitle = translatedText
            case .step(let index):
                guard translatedSteps.indices.contains(index) else { continue }
                translatedSteps[index] = translatedText
            case .ingredient(let name):
                translatedFreeTextIngredients[name] = translatedText
            }
        }

        let translated = translatedTitle != originalRecipe.title
            || translatedSteps != originalRecipe.preparationSteps
            || !translatedFreeTextIngredients.isEmpty

        return RecipeTranslationResult(
            title: translatedTitle,
            steps: translatedSteps,
            freeTextIngredientNames: translatedFreeTextIngredients,
            isAutomaticallyTranslated: translated
        )
    }
}
