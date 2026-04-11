import Foundation

enum OutboxMutationStatus: String, Codable, Hashable {
    case pending
    case inProgress = "in_progress"
    case failed
    case completed

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch raw {
        case "pending":
            self = .pending
        case "in_progress", "inprogress":
            self = .inProgress
        case "failed":
            self = .failed
        case "completed":
            self = .completed
        default:
            self = .pending
        }
    }
}

struct OutboxMutationRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let mutationID: String
    let userID: UUID?
    let entityType: String
    let operationType: String
    let payload: Data
    var status: OutboxMutationStatus
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastError: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        mutationID: String,
        userID: UUID?,
        entityType: String,
        operationType: String,
        payload: Data,
        status: OutboxMutationStatus,
        attemptCount: Int = 0,
        nextRetryAt: Date? = nil,
        lastError: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mutationID = mutationID
        self.userID = userID
        self.entityType = entityType
        self.operationType = operationType
        self.payload = payload
        self.status = status
        self.attemptCount = attemptCount
        self.nextRetryAt = nextRetryAt
        self.lastError = lastError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
