import Foundation

final class CurrentUser {
    static let shared = CurrentUser()

    private let defaults: UserDefaults
    private let localCreatorIDKey = "local_creator_id"
    private let authenticatedDisplayNameKeyPrefix = "authenticated_creator_display_name_"
    private let fallbackDisplayName = "You"
    private let refreshStateQueue = DispatchQueue(label: "season.current_user.refresh_state")
    private var currentlyRefreshingAuthenticatedID: String?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var creator: Creator {
        if let authenticatedUserID = SupabaseService.shared.currentAuthenticatedUserID()?.uuidString.lowercased(),
           !authenticatedUserID.isEmpty {
            let displayName = authenticatedDisplayName(for: authenticatedUserID)
            refreshAuthenticatedDisplayNameIfNeeded(for: authenticatedUserID)
            return Creator(
                id: authenticatedUserID,
                displayName: displayName,
                avatarURL: nil,
                isLocal: false
            )
        }

        let localID = localCreatorID()
        return Creator(
            id: localID,
            displayName: fallbackDisplayName,
            avatarURL: nil,
            isLocal: true
        )
    }

    private func authenticatedDisplayName(for authenticatedUserID: String) -> String {
        let key = authenticatedDisplayNameKey(for: authenticatedUserID)
        let cached = defaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cached.isEmpty ? fallbackDisplayName : cached
    }

    private func refreshAuthenticatedDisplayNameIfNeeded(for authenticatedUserID: String) {
        let shouldStartRefresh = refreshStateQueue.sync { () -> Bool in
            if currentlyRefreshingAuthenticatedID == authenticatedUserID {
                return false
            }
            currentlyRefreshingAuthenticatedID = authenticatedUserID
            return true
        }

        guard shouldStartRefresh else { return }

        Task {
            defer {
                refreshStateQueue.async { [weak self] in
                    guard self?.currentlyRefreshingAuthenticatedID == authenticatedUserID else { return }
                    self?.currentlyRefreshingAuthenticatedID = nil
                }
            }

            do {
                guard let profile = try await SupabaseService.shared.fetchMyProfile() else { return }
                let displayName = profile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !displayName.isEmpty else { return }
                defaults.set(displayName, forKey: authenticatedDisplayNameKey(for: authenticatedUserID))
            } catch {
                // Keep local fallback until profile is available.
            }
        }
    }

    private func authenticatedDisplayNameKey(for authenticatedUserID: String) -> String {
        "\(authenticatedDisplayNameKeyPrefix)\(authenticatedUserID)"
    }

    private func localCreatorID() -> String {
        if let savedID = defaults.string(forKey: localCreatorIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !savedID.isEmpty {
            return savedID
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: localCreatorIDKey)
        return generated
    }
}
