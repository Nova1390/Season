import Foundation

struct Creator: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let avatarURL: String?
    let isLocal: Bool
}

