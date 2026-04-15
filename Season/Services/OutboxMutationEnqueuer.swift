import Foundation

final class OutboxMutationEnqueuer {
    private let outboxStore: OutboxStore
    private let encoder = JSONEncoder()

    init(outboxStore: OutboxStore = OutboxStore()) {
        self.outboxStore = outboxStore
    }

    @discardableResult
    func enqueueShoppingListCreate(
        userID: UUID?,
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?,
        isChecked: Bool
    ) -> Bool {
        let payload = ShoppingListBackfillOutboxCreatePayload(
            localItemID: localItemID,
            ingredientType: ingredientType,
            ingredientID: ingredientID,
            customName: customName,
            quantity: quantity,
            unit: unit,
            sourceRecipeID: sourceRecipeID,
            isChecked: isChecked
        )

        return appendRecord(
            userID: userID,
            entityType: "shopping_list_item",
            operationType: "create",
            payload: payload
        )
    }

    @discardableResult
    func enqueueFridgeCreate(
        userID: UUID?,
        localItemID: String,
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?
    ) -> Bool {
        let payload = FridgeBackfillOutboxCreatePayload(
            localItemID: localItemID,
            ingredientType: ingredientType,
            ingredientID: ingredientID,
            customName: customName,
            quantity: quantity,
            unit: unit
        )

        return appendRecord(
            userID: userID,
            entityType: "fridge_item",
            operationType: "create",
            payload: payload
        )
    }

    private func appendRecord<T: Encodable>(
        userID: UUID?,
        entityType: String,
        operationType: String,
        payload: T
    ) -> Bool {
        guard let payloadData = try? encoder.encode(payload) else {
            return false
        }

        let now = Date()
        let record = OutboxMutationRecord(
            mutationID: UUID().uuidString,
            userID: userID,
            entityType: entityType,
            operationType: operationType,
            payload: payloadData,
            status: .pending,
            attemptCount: 0,
            nextRetryAt: nil,
            lastError: nil,
            createdAt: now,
            updatedAt: now
        )
        outboxStore.append(record)
        return true
    }
}

private struct ShoppingListBackfillOutboxCreatePayload: Codable {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
    let sourceRecipeID: String?
    let isChecked: Bool
}

private struct FridgeBackfillOutboxCreatePayload: Codable {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
}
