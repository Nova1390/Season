import Foundation

final class OutboxStore {
    private let storage: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "season.outbox.store")
    private var cachedMutations: [OutboxMutationRecord]?

    init(
        storage: UserDefaults = .standard,
        storageKey: String = "outboxMutations"
    ) {
        self.storage = storage
        self.storageKey = storageKey
    }

    func allMutations() -> [OutboxMutationRecord] {
        queue.sync {
            loadCachedMutations()
        }
    }

    func pendingMutations() -> [OutboxMutationRecord] {
        let now = Date()
        return allMutations().filter {
            guard $0.status == .pending else { return false }
            guard let nextRetryAt = $0.nextRetryAt else { return true }
            return nextRetryAt <= now
        }
    }

    func cleanupCompletedMutations(olderThan retentionInterval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        queue.sync {
            var current = loadCachedMutations()
            current.removeAll { mutation in
                mutation.status == .completed && mutation.updatedAt < cutoff
            }
            persist(current)
        }
    }

    func saveAll(_ mutations: [OutboxMutationRecord]) {
        queue.sync {
            persist(mutations)
        }
    }

    func append(_ mutation: OutboxMutationRecord) {
        queue.sync {
            var current = loadCachedMutations()
            current.append(mutation)
            persist(current)
        }
    }

    func appendAsync(_ mutation: OutboxMutationRecord) {
        queue.async {
            var current = self.loadCachedMutations()
            current.append(mutation)
            self.persist(current)
        }
    }

    func update(_ mutation: OutboxMutationRecord) {
        queue.sync {
            var current = loadCachedMutations()
            guard let index = current.firstIndex(where: { $0.id == mutation.id }) else { return }
            current[index] = mutation
            persist(current)
        }
    }

    func remove(id: UUID) {
        queue.sync {
            var current = loadCachedMutations()
            current.removeAll { $0.id == id }
            persist(current)
        }
    }

    func clearAll() {
        queue.sync {
            storage.removeObject(forKey: storageKey)
            cachedMutations = []
        }
    }

    private func loadCachedMutations() -> [OutboxMutationRecord] {
        if let cachedMutations {
            return cachedMutations
        }

        let loaded = loadAllFromStorage()
        cachedMutations = loaded
        return loaded
    }

    private func loadAllFromStorage() -> [OutboxMutationRecord] {
        guard let data = storage.data(forKey: storageKey) else {
            return []
        }
        guard let decoded = try? decoder.decode([OutboxMutationRecord].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist(_ mutations: [OutboxMutationRecord]) {
        cachedMutations = mutations
        guard let data = try? encoder.encode(mutations) else { return }
        storage.set(data, forKey: storageKey)
    }
}
