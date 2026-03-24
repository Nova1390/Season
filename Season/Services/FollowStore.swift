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
        guard let canonicalCreatorID = canonicalCreatorID(from: creatorId) else { return false }
        return followingIds.contains(canonicalCreatorID)
    }

    func follow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        guard let canonicalFollowingID = canonicalCreatorID(from: creatorId) else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty, followerID != canonicalFollowingID else { return }

        if relations.contains(where: { $0.followerId == followerID && $0.followingId == canonicalFollowingID }) {
            refreshFollowingIDs()
            return
        }

        relations.append(
            FollowRelation(
                followerId: followerID,
                followingId: canonicalFollowingID,
                createdAt: Date()
            )
        )
        persist()
        refreshFollowingIDs()

        if let relation = relations.first(where: { $0.followerId == followerID && $0.followingId == canonicalFollowingID }) {
            FollowSyncManager.shared.enqueueCreate(relation)
        }
    }

    func unfollow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        guard let canonicalFollowingID = canonicalCreatorID(from: creatorId) else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return }

        relations.removeAll { $0.followerId == followerID && $0.followingId == canonicalFollowingID }
        persist()
        refreshFollowingIDs()
        FollowSyncManager.shared.enqueueDelete(followerId: followerID, followingId: canonicalFollowingID)
    }

    func toggleFollow(_ creatorId: String) {
        refreshFollowingIDsIfNeeded()
        guard let canonicalFollowingID = canonicalCreatorID(from: creatorId) else { return }

        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return }

        let wasFollowing = isFollowing(canonicalFollowingID)
        if wasFollowing {
            unfollow(creatorId)
        } else {
            follow(creatorId)
        }
        let isFollowingNow = isFollowing(canonicalFollowingID)
        print("[SEASON_FOLLOW_IDENTITY] phase=store_toggle follower_id=\(followerID) following_id=\(canonicalFollowingID) was_following=\(wasFollowing) is_following_now=\(isFollowingNow)")
    }

    private func currentFollowerID() -> String {
        let normalized = normalizeID(CurrentUser.shared.creator.id)
        guard isValidUUID(normalized) else {
            print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(normalized)")
            return ""
        }
        return normalized
    }

    func currentFollowRelations() -> [FollowRelation] {
        refreshFollowingIDsIfNeeded()
        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return [] }
        return relations.filter {
            $0.followerId == followerID && isValidUUID($0.followingId)
        }
    }

    @discardableResult
    func mergeBackendFollows(_ backendRelations: [FollowRelation]) -> Int {
        refreshFollowingIDsIfNeeded()
        let followerID = currentFollowerID()
        guard !followerID.isEmpty else { return 0 }

        var added = 0
        for relation in backendRelations {
            let normalizedFollower = normalizeID(relation.followerId)
            let normalizedFollowing = normalizeID(relation.followingId)

            guard normalizedFollower == followerID else { continue }
            guard isValidUUID(normalizedFollowing) else {
                print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(normalizedFollowing)")
                continue
            }
            guard normalizedFollowing != followerID else { continue }

            let exists = relations.contains {
                $0.followerId == followerID && $0.followingId == normalizedFollowing
            }
            guard !exists else { continue }

            relations.append(
                FollowRelation(
                    followerId: followerID,
                    followingId: normalizedFollowing,
                    createdAt: relation.createdAt
                )
            )
            added += 1
        }

        if added > 0 {
            persist()
            refreshFollowingIDs()
        }
        return added
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
        let cleaned = sanitizeRelations(decoded)
        relations = cleaned
        if cleaned.count != decoded.count {
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(relations) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizeID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func canonicalCreatorID(from rawValue: String) -> String? {
        let normalized = normalizeID(rawValue)
        guard !normalized.isEmpty, normalized != "unknown" else {
            if !normalized.isEmpty {
                print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(normalized)")
            }
            return nil
        }

        guard isValidUUID(normalized) else {
            print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(normalized)")
            if isLikelyLegacyName(normalized) {
                print("[SEASON_FOLLOW_IDENTITY] phase=legacy_name_rejected value=\(normalized)")
            }
            return nil
        }

        return normalized
    }

    private func sanitizeRelations(_ incoming: [FollowRelation]) -> [FollowRelation] {
        var seen: Set<String> = []
        var cleaned: [FollowRelation] = []

        for relation in incoming {
            let followerID = normalizeID(relation.followerId)
            let followingID = normalizeID(relation.followingId)

            guard isValidUUID(followerID), isValidUUID(followingID), followerID != followingID else {
                print("[SEASON_FOLLOW_IDENTITY] phase=invalid_follow_identifier value=\(followingID)")
                if isLikelyLegacyName(followingID) {
                    print("[SEASON_FOLLOW_IDENTITY] phase=legacy_name_rejected value=\(followingID)")
                }
                continue
            }

            let key = "\(followerID)|\(followingID)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            cleaned.append(
                FollowRelation(
                    followerId: followerID,
                    followingId: followingID,
                    createdAt: relation.createdAt
                )
            )
        }

        return cleaned
    }

    private func isValidUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private func isLikelyLegacyName(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return value.range(of: "^[a-z0-9_\\-.]+$", options: .regularExpression) != nil &&
            !value.contains("-")
    }
}
