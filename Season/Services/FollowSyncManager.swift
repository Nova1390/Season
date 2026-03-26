import Foundation

@MainActor
final class FollowSyncManager {
    static let shared = FollowSyncManager()

    private let supabaseService: SupabaseService
    private var isSyncingFromBackend = false
    private var isSyncingToBackend = false

    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }

    func enqueueCreate(_ relation: FollowRelation) {
        guard areValidUUIDs(followerId: relation.followerId, followingId: relation.followingId) else {
            print("[SEASON_FOLLOW_IDENTITY] phase=backend_sync_skipped_invalid_uuid follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
            return
        }
        guard shouldSyncToBackend(followerId: relation.followerId, followingId: relation.followingId) else {
            return
        }
        print("[SEASON_FOLLOW_SYNC] phase=backend_sync_allowed follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
        Task {
            await supabaseService.createFollow(relation)
        }
    }

    func enqueueDelete(followerId: String, followingId: String) {
        guard areValidUUIDs(followerId: followerId, followingId: followingId) else {
            print("[SEASON_FOLLOW_IDENTITY] phase=backend_sync_skipped_invalid_uuid follower_id=\(normalized(followerId)) following_id=\(normalized(followingId))")
            return
        }
        guard shouldSyncToBackend(followerId: followerId, followingId: followingId) else {
            return
        }
        print("[SEASON_FOLLOW_SYNC] phase=backend_sync_allowed follower_id=\(normalized(followerId)) following_id=\(normalized(followingId))")
        Task {
            await supabaseService.deleteFollow(
                followerId: followerId,
                followingId: followingId
            )
        }
    }

    func syncFromBackend() async {
        guard !isSyncingFromBackend else { return }
        isSyncingFromBackend = true
        defer { isSyncingFromBackend = false }

        guard let authenticatedUserID = supabaseService.currentAuthenticatedUserID()?.uuidString.lowercased(),
              !authenticatedUserID.isEmpty else {
            return
        }

        let followerID = normalized(CurrentUser.shared.creator.id)
        guard !followerID.isEmpty, followerID == authenticatedUserID else { return }

        let remoteRelations = await supabaseService.fetchFollows(for: followerID)
        let addedCount = await MainActor.run {
            FollowStore.shared.mergeBackendFollows(remoteRelations)
        }
        print("[SEASON_SUPABASE] request=syncFollowFromBackend phase=request_ok follower_id=\(followerID) fetched=\(remoteRelations.count) merged=\(addedCount)")

        await syncToBackend()
    }

    func syncToBackend() async {
        guard !isSyncingToBackend else { return }
        isSyncingToBackend = true
        defer { isSyncingToBackend = false }

        let localRelations = await MainActor.run {
            FollowStore.shared.currentFollowRelations()
        }
        guard !localRelations.isEmpty else { return }

        for relation in localRelations {
            guard areValidUUIDs(followerId: relation.followerId, followingId: relation.followingId) else {
                print("[SEASON_FOLLOW_IDENTITY] phase=backend_sync_skipped_invalid_uuid follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
                continue
            }
            guard shouldSyncToBackend(followerId: relation.followerId, followingId: relation.followingId) else {
                continue
            }
            print("[SEASON_FOLLOW_SYNC] phase=backend_sync_allowed follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
            await supabaseService.createFollow(relation)
        }

        let followerID = normalized(CurrentUser.shared.creator.id)
        print("[SEASON_SUPABASE] request=syncFollowToBackend phase=request_ok follower_id=\(followerID) pushed=\(localRelations.count)")
    }

    private func normalized(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func areValidUUIDs(followerId: String, followingId: String) -> Bool {
        let normalizedFollower = normalized(followerId)
        let normalizedFollowing = normalized(followingId)
        return UUID(uuidString: normalizedFollower) != nil &&
            UUID(uuidString: normalizedFollowing) != nil
    }

    static func isBackendSyncableCreatorID(_ rawCreatorID: String) -> Bool {
        let creatorID = rawCreatorID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard UUID(uuidString: creatorID) != nil else { return false }
        return !RecipeStore.localOnlyCreatorIDs().contains(creatorID)
    }

    private func shouldSyncToBackend(followerId: String, followingId: String) -> Bool {
        let normalizedFollower = normalized(followerId)
        let normalizedFollowing = normalized(followingId)

        guard let authenticatedFollowerID = supabaseService.currentAuthenticatedUserID()?.uuidString.lowercased(),
              !authenticatedFollowerID.isEmpty,
              normalizedFollower == authenticatedFollowerID else {
            print("[SEASON_FOLLOW_SYNC] phase=backend_sync_skipped_local_creator follower_id=\(normalizedFollower) following_id=\(normalizedFollowing)")
            return false
        }

        guard Self.isBackendSyncableCreatorID(normalizedFollowing) else {
            print("[SEASON_FOLLOW_SYNC] phase=backend_sync_skipped_local_creator follower_id=\(normalizedFollower) following_id=\(normalizedFollowing)")
            return false
        }

        return true
    }
}
