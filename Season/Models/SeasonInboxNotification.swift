import Foundation

enum SeasonNotificationDestination: Hashable {
    case today
    case fridge
    case shoppingList
}

enum SeasonNotificationKind: String, Hashable {
    case seasonalPeak
    case fridgeSetup
    case shoppingList
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
