import Foundation
import AuthenticationServices
import UIKit
import os
import CryptoKit

struct SocialAuthResult {
    let provider: SocialAuthProvider
    let providerUserID: String
    let displayName: String?
    let handle: String?
    let profileImageURL: String?
    let accessToken: String?
}

enum SocialAuthError: LocalizedError {
    case missingPresentationAnchor
    case cancelled
    case oauthNotConfigured(provider: SocialAuthProvider)
    case oauthFlowFailed(provider: SocialAuthProvider, details: String)
    case appleAuthorizationFailed(details: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingPresentationAnchor:
            return "Unable to start authentication."
        case .cancelled:
            return "Authentication was cancelled."
        case .oauthNotConfigured(let provider):
            switch provider {
            case .instagram:
                return "Instagram OAuth is not configured yet."
            case .tiktok:
                return "TikTok OAuth is not configured yet."
            case .apple:
                return "Apple Sign In is not configured yet."
            }
        case .oauthFlowFailed(_, let details):
            return details
        case .appleAuthorizationFailed(let details):
            return details
        case .unknown:
            return "Authentication failed."
        }
    }
}

protocol SocialAuthServicing {
    @MainActor
    func authenticate(with provider: SocialAuthProvider) async throws -> SocialAuthResult
}

struct SocialAuthService: SocialAuthServicing {
    static let live = SocialAuthService()
    private let logger = Logger(subsystem: "Season", category: "SocialAuthService")

    @MainActor
    func authenticate(with provider: SocialAuthProvider) async throws -> SocialAuthResult {
        logger.debug("authenticate(provider: \(provider.rawValue, privacy: .public))")
        switch provider {
        case .apple:
            logger.debug("Entering Apple auth branch")
            return try await AppleSignInAuthenticator().authenticate()
        case .instagram:
            logger.debug("Entering Instagram OAuth stub branch")
            return try await OAuthProviderAuthenticator(provider: .instagram).authenticate()
        case .tiktok:
            logger.debug("Entering TikTok OAuth stub branch")
            return try await OAuthProviderAuthenticator(provider: .tiktok).authenticate()
        }
    }
}

private struct OAuthProviderAuthenticator {
    let provider: SocialAuthProvider
    private let logger = Logger(subsystem: "Season", category: "SocialAuthService")

    private struct OAuthTokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let provider_token: String?
    }

    func authenticate() async throws -> SocialAuthResult {
        guard provider == .instagram || provider == .tiktok else {
            throw SocialAuthError.oauthNotConfigured(provider: provider)
        }
        guard let configuration = SupabaseService.shared.configuration else {
            throw SocialAuthError.oauthNotConfigured(provider: provider)
        }

        let redirectURL = configuration.url.appendingPathComponent("auth/v1/callback")
        let codeVerifier = randomURLSafeString(length: 64)
        let codeChallenge = sha256Base64URL(codeVerifier)
        let authorizeURL = try oauthAuthorizeURL(
            baseURL: configuration.url,
            provider: provider,
            redirectURL: redirectURL,
            codeChallenge: codeChallenge
        )

        print("[SEASON_AUTH] phase=oauth_started provider=\(provider.rawValue)")
        let callbackURL: URL
        do {
            callbackURL = try await runWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: redirectURL.scheme ?? "https"
            )
            print("[SEASON_AUTH] phase=oauth_callback_received provider=\(provider.rawValue)")
        } catch {
            print("[SEASON_AUTH] phase=oauth_failed provider=\(provider.rawValue) error=\(error)")
            throw mapOAuthError(error)
        }

        let authCode = try extractAuthCode(from: callbackURL, provider: provider)
        let tokenResponse = try await exchangeOAuthCodeForSession(
            baseURL: configuration.url,
            anonKey: configuration.anonKey,
            authCode: authCode,
            codeVerifier: codeVerifier
        )

        do {
            try await SupabaseService.shared.setSession(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token
            )
        } catch {
            print("[SEASON_AUTH] phase=oauth_failed provider=\(provider.rawValue) error=\(error)")
            throw SocialAuthError.oauthFlowFailed(
                provider: provider,
                details: "\(provider.rawValue.capitalized) OAuth session setup failed."
            )
        }

        let userID = SupabaseService.shared.currentAuthenticatedUserID()?.uuidString ?? UUID().uuidString
        let profile = try? await SupabaseService.shared.fetchMyProfile()
        let linkedCloud = try? await SupabaseService.shared.fetchMyLinkedSocialAccounts()
        let cloudAccount = linkedCloud?.first(where: { $0.provider.caseInsensitiveCompare(provider.rawValue) == .orderedSame })

        let displayName = cloudAccount?.display_name
            ?? profile?.display_name
        let handle = cloudAccount?.handle
            ?? profile?.season_username
        let profileImageURL = cloudAccount?.profile_image_url
            ?? profile?.avatar_url

        print("[SEASON_AUTH] phase=oauth_succeeded provider=\(provider.rawValue)")
        return SocialAuthResult(
            provider: provider,
            providerUserID: cloudAccount?.provider_user_id ?? userID,
            displayName: displayName,
            handle: handle,
            profileImageURL: profileImageURL,
            accessToken: tokenResponse.provider_token ?? tokenResponse.access_token
        )
    }

    private func oauthAuthorizeURL(
        baseURL: URL,
        provider: SocialAuthProvider,
        redirectURL: URL,
        codeChallenge: String
    ) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: redirectURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let url = components?.url else {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: "Invalid OAuth authorize URL.")
        }
        return url
    }

    @MainActor
    private func runWebAuthenticationSession(url: URL, callbackURLScheme: String) async throws -> URL {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw SocialAuthError.missingPresentationAnchor
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            var presentationContextProvider: DefaultPresentationContextProvider?
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SocialAuthError.unknown)
                    return
                }
                continuation.resume(returning: callbackURL)
                _ = presentationContextProvider
            }
            presentationContextProvider = DefaultPresentationContextProvider(windowScene: windowScene)
            session.presentationContextProvider = presentationContextProvider
            session.start()
        }
    }

    private func exchangeOAuthCodeForSession(
        baseURL: URL,
        anonKey: String,
        authCode: String,
        codeVerifier: String
    ) async throws -> OAuthTokenResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]
        guard let tokenURL = components?.url else {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: "Invalid token URL.")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode([
            "auth_code": authCode,
            "code_verifier": codeVerifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: "Invalid OAuth token response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SocialAuthError.oauthFlowFailed(
                provider: provider,
                details: "\(provider.rawValue.capitalized) OAuth token exchange failed (\(httpResponse.statusCode)): \(errorText)"
            )
        }
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func extractAuthCode(from callbackURL: URL, provider: SocialAuthProvider) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: "Invalid OAuth callback URL.")
        }
        if let errorDescription = components.queryItems?.first(where: { $0.name == "error_description" })?.value {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: errorDescription)
        }
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw SocialAuthError.oauthFlowFailed(provider: provider, details: "OAuth callback did not contain auth code.")
        }
        return code
    }

    private func mapOAuthError(_ error: Error) -> SocialAuthError {
        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue || nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            return .cancelled
        }
        return .oauthFlowFailed(provider: provider, details: "\(provider.rawValue.capitalized) OAuth failed: \(nsError.localizedDescription)")
    }

    private func randomURLSafeString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in charset.randomElement() })
    }

    private func sha256Base64URL(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let data = Data(digest)
        return data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class DefaultPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    private let windowScene: UIWindowScene

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor()
    }

    private func presentationAnchor() -> ASPresentationAnchor {
        if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            return keyWindow
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }
}

private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<SocialAuthResult, Error>?
    private let logger = Logger(subsystem: "Season", category: "SocialAuthService")

    @MainActor
    func signIn() async throws -> SocialAuthResult {
        guard Self.presentationAnchor != nil else {
            logger.error("Apple Sign In failed: missing presentation anchor")
            throw SocialAuthError.missingPresentationAnchor
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            logger.debug("Starting Apple Sign In request")
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.presentationAnchor!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credentials = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: SocialAuthError.unknown)
            continuation = nil
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let fullName = formatter.string(from: credentials.fullName ?? PersonNameComponents())
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = SocialAuthResult(
            provider: .apple,
            providerUserID: credentials.user,
            displayName: fullName.isEmpty ? nil : fullName,
            handle: nil,
            profileImageURL: nil,
            accessToken: String(data: credentials.identityToken ?? Data(), encoding: .utf8)
        )
        continuation?.resume(returning: result)
        logger.debug("Apple Sign In success userID=\(credentials.user, privacy: .public)")
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger.error("Apple Sign In error: \(String(describing: error), privacy: .public)")
        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: SocialAuthError.cancelled)
        } else {
            let message = appleAuthFailureMessage(for: nsError)
            continuation?.resume(throwing: SocialAuthError.appleAuthorizationFailed(details: message))
        }
        continuation = nil
    }

    private static var presentationAnchor: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private func appleAuthFailureMessage(for error: NSError) -> String {
        if error.domain == ASAuthorizationError.errorDomain,
           error.code == ASAuthorizationError.unknown.rawValue {
            return "Apple Sign In failed (Code 1000). Check that Sign in with Apple capability is enabled, you are signed into Apple ID on the simulator/device, and the app signing/team is configured."
        }

        if let description = error.userInfo[NSLocalizedDescriptionKey] as? String,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Apple Sign In failed: \(description)"
        }

        return "Apple Sign In failed. Verify capability, Apple ID session, and signing configuration."
    }
}

private struct AppleSignInAuthenticator {
    @MainActor
    func authenticate() async throws -> SocialAuthResult {
        try await AppleSignInCoordinator().signIn()
    }
}
