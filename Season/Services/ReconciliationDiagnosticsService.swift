import Foundation
import CryptoKit

struct ReconciliationSummary {
    let localOnly: Int
    let backendOnly: Int
    let sharedSame: Int
    let sharedDifferent: Int
}

struct ReconciliationDiagnosticsResult {
    let shopping: ReconciliationSummary
    let fridge: ReconciliationSummary
}

final class ReconciliationDiagnosticsService {
    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }

    func runDiagnostics() async throws -> ReconciliationDiagnosticsResult {
        guard let userID = supabaseService.currentAuthenticatedUserID() else {
            throw SupabaseServiceError.unauthenticated
        }

        let shopping = try await diagnoseShopping(userID: userID)
        let fridge = try await diagnoseFridge(userID: userID)
        return ReconciliationDiagnosticsResult(shopping: shopping, fridge: fridge)
    }

    func runSoftSyncReadDiagnostics() async throws -> ReconciliationDiagnosticsResult {
        print("[SEASON_SUPABASE] phase=soft_sync_started domain=shopping_list_items")
        print("[SEASON_SUPABASE] phase=soft_sync_started domain=fridge_items")

        let result = try await runDiagnostics()

        print(
            "[SEASON_SUPABASE] phase=soft_sync_completed domain=shopping_list_items " +
            "local_only=\(result.shopping.localOnly) backend_only=\(result.shopping.backendOnly) " +
            "shared_same=\(result.shopping.sharedSame) shared_different=\(result.shopping.sharedDifferent)"
        )
        print(
            "[SEASON_SUPABASE] phase=soft_sync_completed domain=fridge_items " +
            "local_only=\(result.fridge.localOnly) backend_only=\(result.fridge.backendOnly) " +
            "shared_same=\(result.fridge.sharedSame) shared_different=\(result.fridge.sharedDifferent)"
        )

        return result
    }

    private func diagnoseShopping(userID: UUID) async throws -> ReconciliationSummary {
        let domain = "shopping_list_items"
        print("[SEASON_SUPABASE] phase=reconciliation_started domain=\(domain)")

        let localEntries = ShoppingListViewModel().items
        let backendEntries = try await supabaseService.fetchMyShoppingListItems()

        let localMap = Dictionary(uniqueKeysWithValues: localEntries.map { entry in
            let mapped = mapShoppingEntry(entry)
            let rowID = deterministicUUIDString(from: "shopping_list_item|\(userID.uuidString)|\(mapped.localItemID)")
            return (rowID, mapped.valueSignature)
        })

        let backendMap = Dictionary(uniqueKeysWithValues: backendEntries.map { item in
            (item.id.lowercased(), shoppingSignature(from: item))
        })

        let summary = summarize(local: localMap, backend: backendMap)
        print(
            "[SEASON_SUPABASE] phase=reconciliation_completed domain=\(domain) " +
            "local_only=\(summary.localOnly) backend_only=\(summary.backendOnly) " +
            "shared_same=\(summary.sharedSame) shared_different=\(summary.sharedDifferent)"
        )
        return summary
    }

    private func diagnoseFridge(userID: UUID) async throws -> ReconciliationSummary {
        let domain = "fridge_items"
        print("[SEASON_SUPABASE] phase=reconciliation_started domain=\(domain)")

        let fridgeViewModel = FridgeViewModel()
        let localEntries = mapFridgeEntries(fridgeViewModel)
        let backendEntries = try await supabaseService.fetchMyFridgeItems()

        let localMap = Dictionary(uniqueKeysWithValues: localEntries.map { entry in
            let rowID = deterministicUUIDString(from: "fridge_item|\(userID.uuidString)|\(entry.localItemID)")
            return (rowID, entry.valueSignature)
        })

        let backendMap = Dictionary(uniqueKeysWithValues: backendEntries.map { item in
            (item.id.lowercased(), fridgeSignature(from: item))
        })

        let summary = summarize(local: localMap, backend: backendMap)
        print(
            "[SEASON_SUPABASE] phase=reconciliation_completed domain=\(domain) " +
            "local_only=\(summary.localOnly) backend_only=\(summary.backendOnly) " +
            "shared_same=\(summary.sharedSame) shared_different=\(summary.sharedDifferent)"
        )
        return summary
    }

    private func summarize(local: [String: String], backend: [String: String]) -> ReconciliationSummary {
        let localIDs = Set(local.keys)
        let backendIDs = Set(backend.keys)

        let localOnly = localIDs.subtracting(backendIDs).count
        let backendOnly = backendIDs.subtracting(localIDs).count
        let shared = localIDs.intersection(backendIDs)

        var sharedSame = 0
        var sharedDifferent = 0

        for id in shared {
            if local[id] == backend[id] {
                sharedSame += 1
            } else {
                sharedDifferent += 1
            }
        }

        return ReconciliationSummary(
            localOnly: localOnly,
            backendOnly: backendOnly,
            sharedSame: sharedSame,
            sharedDifferent: sharedDifferent
        )
    }

    private func mapShoppingEntry(_ entry: ShoppingListEntry) -> (localItemID: String, valueSignature: String) {
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
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            customName = trimmed.isEmpty ? nil : trimmed
        }

        let parsed = parseQuantityAndUnit(entry.quantity)
        let signature = [
            ingredientType,
            ingredientID ?? "",
            customName ?? "",
            parsed.quantity.map { String($0) } ?? "",
            parsed.unit ?? "",
            entry.sourceRecipeID ?? "",
            "false"
        ].joined(separator: "|")

        return (entry.id, signature)
    }

    private func mapFridgeEntries(_ fridge: FridgeViewModel) -> [FridgeLocalComparable] {
        let produce = fridge.produceItems.map { item in
            FridgeLocalComparable(
                localItemID: "produce:\(item.id)",
                valueSignature: ["produce", item.id, "", "", ""].joined(separator: "|")
            )
        }

        let basic = fridge.basicItems.map { item in
            FridgeLocalComparable(
                localItemID: "basic:\(item.id)",
                valueSignature: ["basic", item.id, "", "", ""].joined(separator: "|")
            )
        }

        let custom = fridge.customFridgeItems.map { item in
            let parsed = parseQuantityAndUnit(item.quantity)
            return FridgeLocalComparable(
                localItemID: item.id,
                valueSignature: [
                    "custom",
                    "",
                    item.name,
                    parsed.quantity.map { String($0) } ?? "",
                    parsed.unit ?? ""
                ].joined(separator: "|")
            )
        }

        return produce + basic + custom
    }

    private func shoppingSignature(from item: CloudShoppingListItem) -> String {
        [
            item.ingredient_type,
            item.ingredient_id ?? "",
            item.custom_name ?? "",
            item.quantity.map { String($0) } ?? "",
            item.unit ?? "",
            item.source_recipe_id ?? "",
            String(item.is_checked ?? false)
        ].joined(separator: "|")
    }

    private func fridgeSignature(from item: CloudFridgeItem) -> String {
        [
            item.ingredient_type,
            item.ingredient_id ?? "",
            item.custom_name ?? "",
            item.quantity.map { String($0) } ?? "",
            item.unit ?? ""
        ].joined(separator: "|")
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

private struct FridgeLocalComparable {
    let localItemID: String
    let valueSignature: String
}
