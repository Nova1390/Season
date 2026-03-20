import Foundation
import Security

enum SocialAccessTokenStore {
    private static let service = "com.season.social-auth-token"

    @discardableResult
    static func saveToken(_ token: String, provider: SocialAuthProvider, providerUserID: String) -> Bool {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserID = providerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty, !trimmedUserID.isEmpty else { return false }

        let accountKey = accountKey(provider: provider, providerUserID: trimmedUserID)
        let payload = Data(trimmedToken.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = payload
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func token(provider: SocialAuthProvider, providerUserID: String) -> String? {
        let trimmedUserID = providerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(provider: provider, providerUserID: trimmedUserID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func deleteToken(provider: SocialAuthProvider, providerUserID: String) -> Bool {
        let trimmedUserID = providerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else { return true }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(provider: provider, providerUserID: trimmedUserID)
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func accountKey(provider: SocialAuthProvider, providerUserID: String) -> String {
        "\(provider.rawValue)::\(providerUserID)"
    }
}
