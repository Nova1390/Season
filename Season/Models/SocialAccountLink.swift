import Foundation

enum SocialAuthProvider: String, Codable, CaseIterable, Identifiable {
    case instagram
    case tiktok
    case apple

    var id: String { rawValue }
    var supportsRecipeImport: Bool {
        switch self {
        case .instagram, .tiktok:
            return true
        case .apple:
            return false
        }
    }
}

struct LinkedSocialAccount: Codable, Identifiable, Hashable {
    var id: String { provider.rawValue }
    let provider: SocialAuthProvider
    var providerUserID: String
    var displayName: String
    var handle: String?
    var profileImageURL: String?
    var accessToken: String?
    var isVerified: Bool
    var eligiblePostURLs: [String]
    var linkedAt: Date

    init(
        provider: SocialAuthProvider,
        providerUserID: String,
        displayName: String,
        handle: String?,
        profileImageURL: String?,
        accessToken: String?,
        isVerified: Bool,
        eligiblePostURLs: [String],
        linkedAt: Date
    ) {
        self.provider = provider
        self.providerUserID = providerUserID
        self.displayName = displayName
        self.handle = handle
        self.profileImageURL = profileImageURL
        self.accessToken = accessToken
        self.isVerified = isVerified
        self.eligiblePostURLs = eligiblePostURLs
        self.linkedAt = linkedAt
    }

    private enum CodingKeys: String, CodingKey {
        case provider
        case providerUserID
        case displayName
        case handle
        case profileImageURL
        case accessToken
        case isVerified
        case eligiblePostURLs
        case linkedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(SocialAuthProvider.self, forKey: .provider)
        providerUserID = try container.decodeIfPresent(String.self, forKey: .providerUserID) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        eligiblePostURLs = try container.decodeIfPresent([String].self, forKey: .eligiblePostURLs) ?? []
        linkedAt = try container.decodeIfPresent(Date.self, forKey: .linkedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(providerUserID, forKey: .providerUserID)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(handle, forKey: .handle)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        // Security hardening: never persist access tokens in UserDefaults/AppStorage JSON.
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(eligiblePostURLs, forKey: .eligiblePostURLs)
        try container.encode(linkedAt, forKey: .linkedAt)
    }
}

enum SocialAccountLinkStore {
    static func decode(_ raw: String) -> [LinkedSocialAccount] {
        guard let data = raw.data(using: .utf8), !raw.isEmpty else { return [] }
        return (try? JSONDecoder().decode([LinkedSocialAccount].self, from: data)) ?? []
    }

    static func encode(_ accounts: [LinkedSocialAccount]) -> String {
        guard let data = try? JSONEncoder().encode(accounts),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}
