import Foundation
import CryptoKit

struct BackfillResult {
    let shoppingInserted: Int
    let fridgeInserted: Int
}

final class BackfillService {
    private let supabaseService: SupabaseService
    private let outboxEnqueuer: OutboxMutationEnqueuer
    private let outboxDispatcher: OutboxDispatcher

    init(
        supabaseService: SupabaseService = .shared,
        outboxEnqueuer: OutboxMutationEnqueuer = OutboxMutationEnqueuer(),
        outboxDispatcher: OutboxDispatcher = OutboxDispatcher()
    ) {
        self.supabaseService = supabaseService
        self.outboxEnqueuer = outboxEnqueuer
        self.outboxDispatcher = outboxDispatcher
    }

    func runManualBackfill() async throws -> BackfillResult {
        guard let userID = supabaseService.currentAuthenticatedUserID() else {
            throw SupabaseServiceError.unauthenticated
        }

        let shoppingInserted = try await backfillShoppingList(userID: userID)
        let fridgeInserted = try await backfillFridge(userID: userID)
        await outboxDispatcher.processPendingMutations()

        return BackfillResult(
            shoppingInserted: shoppingInserted,
            fridgeInserted: fridgeInserted
        )
    }

    private func backfillShoppingList(userID: UUID) async throws -> Int {
        let domain = "shopping_list_items"
        print("[SEASON_SUPABASE] phase=backfill_started domain=\(domain)")

        let localEntries = ShoppingListViewModel().items
        let backendEntries = try await supabaseService.fetchMyShoppingListItems()
        let backendIDs = Set(backendEntries.map { $0.id.lowercased() })

        let missing = localEntries.compactMap { entry -> ShoppingBackfillMappedEntry? in
            let mapped = mapShoppingEntry(entry)
            let rowID = deterministicUUIDString(from: "shopping_list_item|\(userID.uuidString)|\(mapped.localItemID)")
            guard !backendIDs.contains(rowID) else { return nil }
            return mapped
        }

        print("[SEASON_SUPABASE] phase=backfill_missing_detected domain=\(domain) count=\(missing.count)")

        var enqueued = 0
        for mapped in missing {
            let didEnqueue = outboxEnqueuer.enqueueShoppingListCreate(
                userID: userID,
                localItemID: mapped.localItemID,
                ingredientType: mapped.ingredientType,
                ingredientID: mapped.ingredientID,
                customName: mapped.customName,
                quantity: mapped.quantity,
                unit: mapped.unit,
                sourceRecipeID: mapped.sourceRecipeID,
                isChecked: false
            )
            if didEnqueue {
                enqueued += 1
            } else {
                print("[SEASON_SUPABASE] phase=backfill_enqueue_failed domain=\(domain) item=\(mapped.localItemID)")
            }
        }

        print("[SEASON_SUPABASE] phase=backfill_completed domain=\(domain) enqueued=\(enqueued)")
        return enqueued
    }

    private func backfillFridge(userID: UUID) async throws -> Int {
        let domain = "fridge_items"
        print("[SEASON_SUPABASE] phase=backfill_started domain=\(domain)")

        let fridgeViewModel = FridgeViewModel()
        let localEntries = mapFridgeEntries(fridgeViewModel)
        let backendEntries = try await supabaseService.fetchMyFridgeItems()
        let backendIDs = Set(backendEntries.map { $0.id.lowercased() })

        let missing = localEntries.filter { entry in
            let rowID = deterministicUUIDString(from: "fridge_item|\(userID.uuidString)|\(entry.localItemID)")
            return !backendIDs.contains(rowID)
        }

        print("[SEASON_SUPABASE] phase=backfill_missing_detected domain=\(domain) count=\(missing.count)")

        var enqueued = 0
        for mapped in missing {
            let didEnqueue = outboxEnqueuer.enqueueFridgeCreate(
                userID: userID,
                localItemID: mapped.localItemID,
                ingredientType: mapped.ingredientType,
                ingredientID: mapped.ingredientID,
                customName: mapped.customName,
                quantity: mapped.quantity,
                unit: mapped.unit
            )
            if didEnqueue {
                enqueued += 1
            } else {
                print("[SEASON_SUPABASE] phase=backfill_enqueue_failed domain=\(domain) item=\(mapped.localItemID)")
            }
        }

        print("[SEASON_SUPABASE] phase=backfill_completed domain=\(domain) enqueued=\(enqueued)")
        return enqueued
    }

    private func mapShoppingEntry(_ entry: ShoppingListEntry) -> ShoppingBackfillMappedEntry {
        let ingredientType: String
        let ingredientID: String?
        let customName: String?

        if let produceID = entry.produceID {
            ingredientType = "produce"
            ingredientID = produceID
            customName = nil
        } else if let basicID = entry.basicIngredientID {
            ingredientType = "basic"
            ingredientID = basicID
            customName = nil
        } else {
            ingredientType = "custom"
            ingredientID = nil
            customName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parsed = parseQuantityAndUnit(entry.quantity)
        return ShoppingBackfillMappedEntry(
            localItemID: entry.id,
            ingredientType: ingredientType,
            ingredientID: ingredientID,
            customName: customName,
            quantity: parsed.quantity,
            unit: parsed.unit,
            sourceRecipeID: entry.sourceRecipeID
        )
    }

    private func mapFridgeEntries(_ fridge: FridgeViewModel) -> [FridgeBackfillMappedEntry] {
        let produce = fridge.produceItems.map { item in
            FridgeBackfillMappedEntry(
                localItemID: "produce:\(item.id)",
                ingredientType: "produce",
                ingredientID: item.id,
                customName: nil,
                quantity: nil,
                unit: nil
            )
        }

        let basic = fridge.basicItems.map { item in
            FridgeBackfillMappedEntry(
                localItemID: "basic:\(item.id)",
                ingredientType: "basic",
                ingredientID: item.id,
                customName: nil,
                quantity: nil,
                unit: nil
            )
        }

        let custom = fridge.customFridgeItems.map { item in
            let parsed = parseQuantityAndUnit(item.quantity)
            return FridgeBackfillMappedEntry(
                localItemID: item.id,
                ingredientType: "custom",
                ingredientID: nil,
                customName: item.name,
                quantity: parsed.quantity,
                unit: parsed.unit
            )
        }

        return produce + basic + custom
    }

    private func parseQuantityAndUnit(_ rawQuantity: String?) -> (quantity: Double?, unit: String?) {
        let trimmed = rawQuantity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return (nil, nil) }

        let pattern = #"^\s*([0-9]+(?:[.,][0-9]+)?)\s*(.*)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let numberRange = Range(match.range(at: 1), in: trimmed) {
            let numberText = String(trimmed[numberRange]).replacingOccurrences(of: ",", with: ".")
            let quantity = Double(numberText)
            let unitText: String?
            if let unitRange = Range(match.range(at: 2), in: trimmed) {
                let parsedUnit = String(trimmed[unitRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                unitText = parsedUnit.isEmpty ? nil : parsedUnit
            } else {
                unitText = nil
            }
            return (quantity, unitText)
        }

        return (nil, trimmed)
    }

    private func deterministicUUIDString(from input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple).uuidString.lowercased()
    }
}

private struct ShoppingBackfillMappedEntry {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
    let sourceRecipeID: String?
}

private struct FridgeBackfillMappedEntry {
    let localItemID: String
    let ingredientType: String
    let ingredientID: String?
    let customName: String?
    let quantity: Double?
    let unit: String?
}
