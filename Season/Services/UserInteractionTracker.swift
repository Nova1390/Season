import Foundation

enum UserInteractionEventType: String, Codable {
    case recipeViewed
    case recipeOpened
    case recipeSaved
    case recipeCrispied
    case recipeAddedToList
    case produceAddedToFridge
    case produceRemovedFromFridge
}

struct UserInteractionEvent: Identifiable, Codable, Equatable {
    let id: String
    let timestamp: Date
    let eventType: UserInteractionEventType
    let recipeID: String?
    let produceID: String?
    let creatorID: String?
    let metadata: [String: String]?
    // Future sync hook: this can later carry remote sync status/version.
    let isSynced: Bool
}

final class UserInteractionTracker {
    static let shared = UserInteractionTracker()

    private let storage: UserDefaults
    private let storageKey = "season.userInteractionEvents.v1"
    private let maxEvents = 500
    private let queue = DispatchQueue(label: "season.user-interaction-tracker")
    private var events: [UserInteractionEvent]

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        self.events = Self.loadEvents(from: storage, key: storageKey)
    }

    func track(
        _ eventType: UserInteractionEventType,
        recipeID: String? = nil,
        produceID: String? = nil,
        creatorID: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let event = UserInteractionEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            eventType: eventType,
            recipeID: Self.normalizedID(recipeID),
            produceID: Self.normalizedID(produceID),
            creatorID: Self.normalizedID(creatorID),
            metadata: Self.normalizedMetadata(metadata),
            isSynced: false
        )

        queue.async { [weak self] in
            guard let self else { return }
            self.events.append(event)
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
            self.save()
        }
    }

    func recentEvents() -> [UserInteractionEvent] {
        queue.sync { events }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            storage.set(data, forKey: storageKey)
        } catch {
            print("[SEASON_FEED_SIGNALS] phase=save_failed error=\(error)")
        }
    }

    private static func loadEvents(from storage: UserDefaults, key: String) -> [UserInteractionEvent] {
        guard let data = storage.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([UserInteractionEvent].self, from: data)
        } catch {
            print("[SEASON_FEED_SIGNALS] phase=load_failed error=\(error)")
            storage.removeObject(forKey: key)
            return []
        }
    }

    private static func normalizedID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedMetadata(_ metadata: [String: String]?) -> [String: String]? {
        guard let metadata else { return nil }
        let cleaned = metadata.reduce(into: [String: String]()) { partial, pair in
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return }
            partial[key] = value
        }
        return cleaned.isEmpty ? nil : cleaned
    }
}
