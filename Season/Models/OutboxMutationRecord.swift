import Foundation

struct OutboxMutationRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let mutationID: String
    let userID: UUID?
    let entityType: String
    let operationType: String
    let payload: Data
    var status: String
    var attemptCount: Int
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
        status: String,
        attemptCount: Int = 0,
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
        self.lastError = lastError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
