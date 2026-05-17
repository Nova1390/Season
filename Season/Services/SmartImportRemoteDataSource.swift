import Foundation
import Supabase

struct SmartImportRemoteDataSource {
    let client: SupabaseClient?
    let configuration: SupabaseConfiguration?
    let configurationIssue: String?

    func parseRecipeCaption(
        caption: String?,
        url: String?,
        languageCode: String,
        ingredientCandidates: [SmartImportIngredientCandidate]? = nil
    ) async throws -> ParseRecipeCaptionFunctionResponse {
        guard let supabaseClient = client else {
            throw SupabaseServiceError.missingConfiguration(configurationIssue ?? "SUPABASE_URL / SUPABASE_ANON_KEY")
        }

        guard let authenticatedUser = supabaseClient.auth.currentUser else {
            SeasonLog.debug("[SEASON_IMPORT_AUTH] phase=missing_current_user has_session=false invoke_with_authenticated_context=false")
            throw SupabaseServiceError.unauthenticated
        }

        let accessToken: String
        do {
            accessToken = try await supabaseClient.auth.session.accessToken
        } catch {
            SeasonLog.debug("[SEASON_IMPORT_AUTH] phase=missing_access_token user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=false invoke_with_authenticated_context=false error=\(error)")
            throw SupabaseServiceError.unauthenticated
        }
        guard let anonKey = configuration?.anonKey,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SupabaseServiceError.missingConfiguration("SUPABASE_ANON_KEY")
        }

        supabaseClient.functions.setAuth(token: accessToken)
        SeasonLog.debug("[SEASON_IMPORT_AUTH] phase=session_ready user_id=\(authenticatedUser.id.uuidString.lowercased()) has_session=true invoke_with_authenticated_context=true")

        let normalizedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ParseRecipeCaptionFunctionRequest(
            caption: normalizedCaption?.isEmpty == true ? nil : normalizedCaption,
            url: normalizedURL?.isEmpty == true ? nil : normalizedURL,
            languageCode: languageCode,
            ingredientCandidates: ingredientCandidates?.isEmpty == true ? nil : ingredientCandidates
        )

        SeasonLog.debug("[SEASON_IMPORT_AUTH] phase=invoke_started user_id=\(authenticatedUser.id.uuidString.lowercased()) authenticated_context=true")
        do {
            return try await supabaseClient.functions.invoke(
                "parse-recipe-caption",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(accessToken)",
                        "apikey": anonKey
                    ],
                    body: payload
                )
            )
        } catch let functionsError as FunctionsError {
            switch functionsError {
            case .httpError(let code, let data):
                if code == 429,
                   let parsed = try? JSONDecoder().decode(ParseRecipeCaptionFunctionErrorEnvelope.self, from: data),
                   let errorCode = parsed.error?.code {
                    if errorCode == "TOO_FREQUENT_REQUESTS" {
                        throw ParseRecipeCaptionInvokeError.tooFrequent(
                            retryAfterSeconds: parsed.meta?.retryAfterSeconds
                        )
                    }
                    if errorCode == "RATE_LIMIT_EXCEEDED" {
                        throw ParseRecipeCaptionInvokeError.dailyLimitReached
                    }
                }
                throw functionsError
            case .relayError:
                throw functionsError
            }
        }
    }
}
