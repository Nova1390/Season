import Foundation
import Combine

@MainActor
final class FollowStore: ObservableObject {
    static let shared = FollowStore()

    @Published private(set) var followingIds: Set<String> = []

    private let storageKey = "follow_relations_local"
    private let defaults: UserDefaults
    private var relations: [FollowRelation] = []
    private var cachedFollowerID: String = ""

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        refreshFollowingIDs()
    }

    func isFollowing(_ creatorId: String) -> Bool {
        refreshFollowingIDsIfNeeded()
        let normalized = normalizeID(creatorId)
        guard !normalized.isEmpty else { return false }
        return followingIds.contains(normalized)
    }

    func follow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        let normalizedFollowing = normalizeID(creatorId)
        guard !normalizedFollowing.isEmpty else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty, followerID != normalizedFollowing else { return }

        if relations.contains(where: { $0.followerId == followerID && $0.followingId == normalizedFollowing }) {
            refreshFollowingIDs()
            return
        }

        relations.append(
            FollowRelation(
                followerId: followerID,
                followingId: normalizedFollowing,
                createdAt: Date()
            )
        )
        persist()
        refreshFollowingIDs()
    }

    func unfollow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        let normalizedFollowing = normalizeID(creatorId)
        guard !normalizedFollowing.isEmpty else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return }

        relations.removeAll { $0.followerId == followerID && $0.followingId == normalizedFollowing }
        persist()
        refreshFollowingIDs()
    }

    func toggleFollow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        let normalizedFollowing = normalizeID(creatorId)
        guard !normalizedFollowing.isEmpty else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return }

        let wasFollowing = isFollowing(normalizedFollowing)
        if wasFollowing {
            unfollow(creatorId)
        } else {
            follow(creatorId)
        }
        let isFollowingNow = isFollowing(normalizedFollowing)
        print("[SEASON_FOLLOW_IDENTITY] phase=store_toggle follower_id=\(followerID) following_id=\(normalizedFollowing) was_following=\(wasFollowing) is_following_now=\(isFollowingNow)")
    }

    private func currentFollowerID() -> String {
        normalizeID(CurrentUser.shared.creator.id)
    }

    private func refreshFollowingIDs() {
        let followerID = currentFollowerID()
        cachedFollowerID = followerID
        followingIds = Set(
            relations
                .filter { $0.followerId == followerID }
                .map { $0.followingId }
        )
    }

    private func refreshFollowingIDsIfNeeded() {
        let followerID = currentFollowerID()
        if followerID != cachedFollowerID {
            refreshFollowingIDs()
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FollowRelation].self, from: data) else {
            relations = []
            return
        }
        relations = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(relations) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizeID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
