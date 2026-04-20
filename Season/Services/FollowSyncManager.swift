import Foundation

@MainActor
final class FollowSyncManager {
    static let shared = FollowSyncManager(supabaseService: .shared)

    private let supabaseService: SupabaseService
    private var isSyncingFromBackend = false
    private var isSyncingToBackend = false

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func requestSync() {
        Task { @MainActor in
            await syncToBackend()
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

        let pendingRelations = await MainActor.run {
            FollowStore.shared.pendingFollowSyncRelations()
        }
        guard !pendingRelations.isEmpty else { return }

        var processedCount = 0
        for relation in pendingRelations {
            guard areValidUUIDs(followerId: relation.followerId, followingId: relation.followingId) else {
                print("[SEASON_FOLLOW_IDENTITY] phase=backend_sync_skipped_invalid_uuid follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
                FollowStore.shared.markPendingFollowOperationCompleted(
                    followerId: relation.followerId,
                    followingId: relation.followingId,
                    syncedAt: nil
                )
                continue
            }
            guard shouldSyncToBackend(followerId: relation.followerId, followingId: relation.followingId) else {
                FollowStore.shared.markPendingFollowOperationCompleted(
                    followerId: relation.followerId,
                    followingId: relation.followingId,
                    syncedAt: nil
                )
                continue
            }

            let didSync: Bool
            switch relation.pendingSyncOperation {
            case .create:
                print("[SEASON_FOLLOW_SYNC] phase=backend_sync_allowed operation=create follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
                didSync = await supabaseService.createFollow(relation)
            case .delete:
                print("[SEASON_FOLLOW_SYNC] phase=backend_sync_allowed operation=delete follower_id=\(normalized(relation.followerId)) following_id=\(normalized(relation.followingId))")
                didSync = await supabaseService.deleteFollow(
                    followerId: relation.followerId,
                    followingId: relation.followingId
                )
            case .none:
                didSync = true
            }

            guard didSync else { continue }
            FollowStore.shared.markPendingFollowOperationCompleted(
                followerId: relation.followerId,
                followingId: relation.followingId,
                syncedAt: Date()
            )
            processedCount += 1
        }

        let followerID = normalized(CurrentUser.shared.creator.id)
        print("[SEASON_SUPABASE] request=syncFollowToBackend phase=request_ok follower_id=\(followerID) pending=\(pendingRelations.count) processed=\(processedCount)")
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
