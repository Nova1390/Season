import Foundation

final class CurrentUser {
    static let shared = CurrentUser()

    private let defaults: UserDefaults
    private let localCreatorIDKey = "local_creator_id"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var creator: Creator {
        if let authenticatedUserID = SupabaseService.shared.currentAuthenticatedUserID()?.uuidString.lowercased(),
           !authenticatedUserID.isEmpty {
            return Creator(
                id: authenticatedUserID,
                displayName: "User",
                avatarURL: nil,
                isLocal: false
            )
        }

        let localID = localCreatorID()
        return Creator(
            id: localID,
            displayName: "User",
            avatarURL: nil,
            isLocal: true
        )
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

