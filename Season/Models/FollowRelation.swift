import Foundation

enum FollowPendingSyncOperation: String, Codable, Equatable {
    case none
    case create
    case delete
}

struct FollowRelation: Codable, Equatable, Identifiable {
    let followerId: String
    let followingId: String
    let createdAt: Date
    var isActive: Bool
    var pendingSyncOperation: FollowPendingSyncOperation
    var lastSyncedAt: Date?

    var id: String {
        "\(followerId)|\(followingId)"
    }

    init(
        followerId: String,
        followingId: String,
        createdAt: Date,
        isActive: Bool = true,
        pendingSyncOperation: FollowPendingSyncOperation = .none,
        lastSyncedAt: Date? = nil
    ) {
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
        self.isActive = isActive
        self.pendingSyncOperation = pendingSyncOperation
        self.lastSyncedAt = lastSyncedAt
    }

    private enum CodingKeys: String, CodingKey {
        case followerId
        case followingId
        case createdAt
        case isActive
        case pendingSyncOperation
        case lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followerId = try container.decode(String.self, forKey: .followerId)
        followingId = try container.decode(String.self, forKey: .followingId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        pendingSyncOperation = try container.decodeIfPresent(FollowPendingSyncOperation.self, forKey: .pendingSyncOperation) ?? .none
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}
