import Foundation

enum SeasonNotificationDestination: Hashable {
    case today
    case fridge
    case shoppingList
    case recipe(String)
    case none
}

enum SeasonNotificationKind: String, Hashable {
    case seasonalPeak
    case fridgeSetup
    case shoppingList
    case newFollower
    case recipeCrispied
}

struct SeasonInboxNotification: Identifiable, Hashable {
    let id: String
    let kind: SeasonNotificationKind
    let title: String
    let body: String
    let systemImage: String
    let destination: SeasonNotificationDestination
    let createdAt: Date
}

struct SeasonFollowerNotificationSignal: Hashable {
    let followerID: String
    let createdAt: Date
}

struct SeasonRecipeCrispyNotificationSignal: Hashable {
    let recipeID: String
    let recipeTitle: String
    let count: Int
    let latestAt: Date
}

enum SeasonNotificationReadStore {
    static let readIDsStorageKey = "seasonInboxReadNotificationIDs"

    static func readIDs(from rawValue: String) -> Set<String> {
        Set(
            rawValue
                .split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    static func rawValue(from ids: Set<String>) -> String {
        ids.sorted().joined(separator: "|")
    }
}
