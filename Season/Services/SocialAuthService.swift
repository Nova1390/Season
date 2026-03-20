import Foundation
import AuthenticationServices
import UIKit
import os

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

    func authenticate() async throws -> SocialAuthResult {
        // OAuth flow scaffold only. This intentionally avoids fake/manual identity entry.
        logger.error("OAuth provider not configured for \(provider.rawValue, privacy: .public)")
        throw SocialAuthError.oauthNotConfigured(provider: provider)
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
