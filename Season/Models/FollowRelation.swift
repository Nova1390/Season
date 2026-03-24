import Foundation

struct FollowRelation: Codable, Equatable, Identifiable {
    let followerId: String
    let followingId: String
    let createdAt: Date

    var id: String {
        "\(followerId)|\(followingId)"
    }
}

