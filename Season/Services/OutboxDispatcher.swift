import Foundation

final class OutboxDispatcher {
    private let outboxStore: OutboxStore
    private let supabaseService: SupabaseService
    private let decoder = JSONDecoder()

    init(
        outboxStore: OutboxStore = OutboxStore(),
        supabaseService: SupabaseService = .shared
    ) {
        self.outboxStore = outboxStore
        self.supabaseService = supabaseService
    }

    func processPendingMutations() async {
        let pending = outboxStore
            .pendingMutations()
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        print("[SEASON_SUPABASE] phase=dispatcher_started pending_count=\(pending.count)")

        for mutation in pending {
            await process(mutation)
        }
    }

    private func process(_ mutation: OutboxMutationRecord) async {
        var inProgress = mutation
        inProgress.status = "in_progress"
        inProgress.attemptCount += 1
        inProgress.updatedAt = Date()
        outboxStore.update(inProgress)

        print(
            "[SEASON_SUPABASE] phase=mutation_started mutation_id=\(inProgress.mutationID) " +
            "entity_type=\(inProgress.entityType) operation_type=\(inProgress.operationType)"
        )

        do {
            try await replay(inProgress)

            var completed = inProgress
            completed.status = "completed"
            completed.lastError = nil
            completed.updatedAt = Date()
            outboxStore.update(completed)

            print(
                "[SEASON_SUPABASE] phase=mutation_completed mutation_id=\(completed.mutationID) " +
                "entity_type=\(completed.entityType) operation_type=\(completed.operationType)"
            )
        } catch {
            var failed = inProgress
            failed.status = "failed"
            failed.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            failed.updatedAt = Date()
            outboxStore.update(failed)

            print(
                "[SEASON_SUPABASE] phase=mutation_failed mutation_id=\(failed.mutationID) " +
                "entity_type=\(failed.entityType) operation_type=\(failed.operationType) error=\(error)"
            )
        }
    }

    private func replay(_ mutation: OutboxMutationRecord) async throws {
        switch (mutation.entityType, mutation.operationType) {
        case ("shopping_list_item", "create"):
            let payload = try decoder.decode(ShoppingListOutboxMutationPayload.self, from: mutation.payload)
            try await supabaseService.createShoppingListItem(
                localItemID: payload.localItemID,
                ingredientType: payload.ingredientType,
                ingredientID: payload.ingredientID,
                customName: payload.customName,
                quantity: payload.quantity,
                unit: payload.unit,
                sourceRecipeID: payload.sourceRecipeID,
                isChecked: payload.isChecked,
                traceID: mutation.mutationID
            )

        case ("shopping_list_item", "update"):
            let payload = try decoder.decode(ShoppingListOutboxMutationPayload.self, from: mutation.payload)
            try await supabaseService.updateShoppingListItem(
                localItemID: payload.localItemID,
                ingredientType: payload.ingredientType,
                ingredientID: payload.ingredientID,
                customName: payload.customName,
                quantity: payload.quantity,
                unit: payload.unit,
                sourceRecipeID: payload.sourceRecipeID,
                isChecked: payload.isChecked,
                traceID: mutation.mutationID
            )

        case ("shopping_list_item", "delete"):
            let payload = try decoder.decode(ShoppingListDeleteOutboxMutationPayload.self, from: mutation.payload)
            try await supabaseService.deleteShoppingListItem(
                localItemID: payload.localItemID,
                traceID: mutation.mutationID
            )

        case ("fridge_item", "create"):
            let payload = try decoder.decode(FridgeOutboxCreatePayload.self, from: mutation.payload)
            try await supabaseService.createFridgeItem(
                localItemID: payload.localItemID,
                ingredientType: payload.ingredientType,
                ingredientID: payload.ingredientID,
                customName: payload.customName,
                quantity: payload.quantity,
                unit: payload.unit,
                traceID: mutation.mutationID
            )

        case ("fridge_item", "update"):
            let payload = try decoder.decode(FridgeOutboxCreatePayload.self, from: mutation.payload)
            try await supabaseService.updateFridgeItem(
                localItemID: payload.localItemID,
                ingredientType: payload.ingredientType,
                ingredientID: payload.ingredientID,
                customName: payload.customName,
                quantity: payload.quantity,
                unit: payload.unit,
                traceID: mutation.mutationID
            )

        case ("fridge_item", "delete"):
            let payload = try decoder.decode(FridgeOutboxDeletePayload.self, from: mutation.payload)
            try await supabaseService.deleteFridgeItem(
                localItemID: payload.localItemID,
                traceID: mutation.mutationID
            )

        default:
            throw OutboxDispatcherError.unsupportedMutation(
                entityType: mutation.entityType,
                operationType: mutation.operationType
            )
        }
    }
}

enum OutboxDispatcherError: LocalizedError {
    case unsupportedMutation(entityType: String, operationType: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMutation(let entityType, let operationType):
            return "Unsupported outbox mutation: \(entityType).\(operationType)"
        }
    }
}

private struct ShoppingListOutboxMutationPayload: Codable {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
    let sourceRecipeID: String?
    let isChecked: Bool
}

private struct ShoppingListDeleteOutboxMutationPayload: Codable {
    let localItemID: String
}

private struct FridgeOutboxCreatePayload: Codable {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
}

private struct FridgeOutboxDeletePayload: Codable {
    let localItemID: String
}
