import Foundation
import Combine

final class FridgeViewModel: ObservableObject {
    @Published private var produceIDs: [String] = []
    @Published private var basicIngredientIDs: [String] = []
    @Published private var customItems: [FridgeCustomItem] = []

    // Backward-compatible alias used by existing views.
    var items: [ProduceItem] {
        produceItems
    }

    var produceItems: [ProduceItem] {
        produceIDs.compactMap { produceCatalogByID[$0] }
    }

    var basicItems: [BasicIngredient] {
        basicIngredientIDs.compactMap { basicCatalogByID[$0] }
    }

    var allItemCount: Int {
        produceIDs.count + basicIngredientIDs.count + customItems.count
    }

    var allIngredientIDSet: Set<String> {
        Set(produceIDs).union(basicIngredientIDs)
    }

    private let produceCatalogByID: [String: ProduceItem]
    private let basicCatalogByID: [String: BasicIngredient]
    private let storage: UserDefaults
    private let storageKey = "fridgeIngredientSelection"
    private let legacyStorageKey = "fridgeItemIDs"
    private let supabaseService = SupabaseService.shared
    private let outboxStore = OutboxStore()
    private let syncFeedback = SyncFeedbackCenter.shared

    init(
        catalog: [ProduceItem] = ProduceStore.loadFromBundle(),
        basicCatalog: [BasicIngredient] = BasicIngredientCatalog.all,
        storage: UserDefaults = .standard
    ) {
        self.produceCatalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        self.basicCatalogByID = Dictionary(uniqueKeysWithValues: basicCatalog.map { ($0.id, $0) })
        self.storage = storage
        load()
    }

    func add(_ item: ProduceItem) {
        guard produceCatalogByID[item.id] != nil else { return }
        guard !contains(item) else { return }
        produceIDs.append(item.id)
        save()
        UserInteractionTracker.shared.track(.produceAddedToFridge, produceID: item.id)
        writeThroughCreateProduce(item.id)
    }

    func remove(_ item: ProduceItem) {
        let removed = produceIDs.contains(item.id)
        produceIDs.removeAll { $0 == item.id }
        save()
        if removed {
            UserInteractionTracker.shared.track(.produceRemovedFromFridge, produceID: item.id)
            writeThroughDelete(localItemID: "produce:\(item.id)")
        }
    }

    func add(_ item: BasicIngredient) {
        guard basicCatalogByID[item.id] != nil else { return }
        guard !contains(item) else { return }
        basicIngredientIDs.append(item.id)
        save()
        writeThroughCreateBasic(item.id)
    }

    func remove(_ item: BasicIngredient) {
        let removed = basicIngredientIDs.contains(item.id)
        basicIngredientIDs.removeAll { $0 == item.id }
        save()
        if removed {
            writeThroughDelete(localItemID: "basic:\(item.id)")
        }
    }

    func addCustom(name: String, quantity: String? = nil) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        let normalizedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = FridgeCustomItem(
            id: "custom:\(normalizedName.lowercased())|\((normalizedQuantity ?? "").lowercased())",
            name: normalizedName,
            quantity: normalizedQuantity?.isEmpty == false ? normalizedQuantity : nil
        )
        guard !containsCustom(named: custom.name) else { return }
        customItems.append(custom)
        save()
        writeThroughCreateCustom(custom)
    }

    func removeCustom(named name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        let removed = customItems.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        customItems.removeAll {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        save()
        removed.forEach { writeThroughDelete(localItemID: $0.id) }
    }

    func containsCustom(named name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return customItems.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    var customFridgeItems: [FridgeCustomItem] {
        customItems
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets
            .sorted()
            .compactMap { index in produceIDs.indices.contains(index) ? produceIDs[index] : nil }
        for index in offsets.sorted(by: >) {
            guard produceIDs.indices.contains(index) else { continue }
            produceIDs.remove(at: index)
        }
        save()
        removed.forEach { writeThroughDelete(localItemID: "produce:\($0)") }
    }

    func contains(_ item: ProduceItem) -> Bool {
        produceIDs.contains(item.id)
    }

    func contains(_ item: BasicIngredient) -> Bool {
        basicIngredientIDs.contains(item.id)
    }

    var itemIDSet: Set<String> {
        allIngredientIDSet
    }

    func resetForLogout() {
        produceIDs = []
        basicIngredientIDs = []
        customItems = []
        storage.removeObject(forKey: storageKey)
        storage.removeObject(forKey: legacyStorageKey)
        outboxStore.clearAll()
    }

    private func save() {
        let payload = FridgeSelectionPayload(
            produceIDs: produceIDs,
            basicIngredientIDs: basicIngredientIDs,
            customItems: customItems
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            storage.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        if let data = storage.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FridgeSelectionPayload.self, from: data) {
            produceIDs = decoded.produceIDs.filter { produceCatalogByID[$0] != nil }
            basicIngredientIDs = decoded.basicIngredientIDs.filter { basicCatalogByID[$0] != nil }
            customItems = decoded.customItems
            return
        }

        // Backward compatibility with the old produce-only storage.
        let savedIDs = storage.stringArray(forKey: legacyStorageKey) ?? []
        produceIDs = savedIDs.filter { produceCatalogByID[$0] != nil }
        basicIngredientIDs = []
        customItems = []
        save()
    }

    private func writeThroughCreateProduce(_ produceID: String) {
        let localItemID = "produce:\(produceID)"
        let traceID = String(UUID().uuidString.prefix(8))
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=local_update_done")
        Task { @MainActor in
            syncFeedback.show(.pending)
        }
        appendOutboxRecord(
            traceID: traceID,
            action: "fridge_create",
            itemID: localItemID,
            entityType: "fridge_item",
            operationType: "create",
            payload: FridgeOutboxCreatePayload(
                localItemID: localItemID,
                ingredientType: "produce",
                ingredientID: produceID,
                customName: nil,
                quantity: nil,
                unit: nil
            )
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=outbox_only_write_enqueued")
    }

    private func writeThroughCreateBasic(_ basicID: String) {
        let localItemID = "basic:\(basicID)"
        let traceID = String(UUID().uuidString.prefix(8))
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=local_update_done")
        Task { @MainActor in
            syncFeedback.show(.pending)
        }
        appendOutboxRecord(
            traceID: traceID,
            action: "fridge_create",
            itemID: localItemID,
            entityType: "fridge_item",
            operationType: "create",
            payload: FridgeOutboxCreatePayload(
                localItemID: localItemID,
                ingredientType: "basic",
                ingredientID: basicID,
                customName: nil,
                quantity: nil,
                unit: nil
            )
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(localItemID) phase=outbox_only_write_enqueued")
    }

    private func writeThroughCreateCustom(_ item: FridgeCustomItem) {
        let traceID = String(UUID().uuidString.prefix(8))
        let parsed = parseQuantityAndUnit(item.quantity)
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(item.id) phase=local_update_done")
        Task { @MainActor in
            syncFeedback.show(.pending)
        }
        appendOutboxRecord(
            traceID: traceID,
            action: "fridge_create",
            itemID: item.id,
            entityType: "fridge_item",
            operationType: "create",
            payload: FridgeOutboxCreatePayload(
                localItemID: item.id,
                ingredientType: "custom",
                ingredientID: nil,
                customName: item.name,
                quantity: parsed.quantity,
                unit: parsed.unit
            )
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_create item=\(item.id) phase=outbox_only_write_enqueued")
    }

    private func writeThroughDelete(localItemID: String) {
        let traceID = String(UUID().uuidString.prefix(8))
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=local_update_done")
        Task { @MainActor in
            syncFeedback.show(.pending)
        }
        appendOutboxRecord(
            traceID: traceID,
            action: "fridge_delete",
            itemID: localItemID,
            entityType: "fridge_item",
            operationType: "delete",
            payload: FridgeOutboxDeletePayload(localItemID: localItemID),
            asynchronous: true
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=fridge_delete item=\(localItemID) phase=outbox_only_write_enqueued")
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

    private func appendOutboxRecord<T: Encodable>(
        traceID: String,
        action: String,
        itemID: String,
        entityType: String,
        operationType: String,
        payload: T,
        asynchronous: Bool = false
    ) {
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("[SEASON_SUPABASE] trace=\(traceID) action=\(action) item=\(itemID) phase=outbox_append_failed error=payload_encoding_failed")
            return
        }

        let mutationID = UUID().uuidString
        let now = Date()
        let record = OutboxMutationRecord(
            mutationID: mutationID,
            userID: supabaseService.currentAuthenticatedUserID(),
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
        if asynchronous {
            outboxStore.appendAsync(record)
        } else {
            outboxStore.append(record)
        }
        print("[SEASON_SUPABASE] trace=\(traceID) action=\(action) item=\(itemID) mutation_id=\(mutationID) phase=outbox_appended")
    }
}

private struct FridgeSelectionPayload: Codable {
    let produceIDs: [String]
    let basicIngredientIDs: [String]
    let customItems: [FridgeCustomItem]
}

struct FridgeCustomItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let quantity: String?
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
