import Foundation
import Combine

struct ShoppingListEntry: Identifiable, Codable, Hashable {
    let id: String
    let produceID: String?
    let basicIngredientID: String?
    let name: String
    let quantity: String?
    let sourceRecipeID: String?
    let sourceRecipeTitle: String?

    var isCustom: Bool { produceID == nil && basicIngredientID == nil }

    private enum CodingKeys: String, CodingKey {
        case id
        case produceID
        case basicIngredientID
        case name
        case quantity
        case sourceRecipeID
        case sourceRecipeTitle
    }

    init(
        id: String,
        produceID: String?,
        basicIngredientID: String?,
        name: String,
        quantity: String?,
        sourceRecipeID: String?,
        sourceRecipeTitle: String?
    ) {
        self.id = id
        self.produceID = produceID
        self.basicIngredientID = basicIngredientID
        self.name = name
        self.quantity = quantity
        self.sourceRecipeID = sourceRecipeID
        self.sourceRecipeTitle = sourceRecipeTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        produceID = try container.decodeIfPresent(String.self, forKey: .produceID)
        basicIngredientID = try container.decodeIfPresent(String.self, forKey: .basicIngredientID)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        sourceRecipeID = try container.decodeIfPresent(String.self, forKey: .sourceRecipeID)
        sourceRecipeTitle = try container.decodeIfPresent(String.self, forKey: .sourceRecipeTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(produceID, forKey: .produceID)
        try container.encodeIfPresent(basicIngredientID, forKey: .basicIngredientID)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(sourceRecipeID, forKey: .sourceRecipeID)
        try container.encodeIfPresent(sourceRecipeTitle, forKey: .sourceRecipeTitle)
    }

    static func produce(
        _ item: ProduceItem,
        sourceRecipeID: String? = nil,
        sourceRecipeTitle: String? = nil
    ) -> ShoppingListEntry {
        ShoppingListEntry(
            id: "produce:\(item.id)",
            produceID: item.id,
            basicIngredientID: nil,
            name: item.displayName(languageCode: "en"),
            quantity: nil,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
    }

    static func basic(
        _ item: BasicIngredient,
        quantity: String? = nil,
        sourceRecipeID: String? = nil,
        sourceRecipeTitle: String? = nil
    ) -> ShoppingListEntry {
        let normalizedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityPart = normalizedQuantity?.lowercased() ?? ""
        return ShoppingListEntry(
            id: "basic:\(item.id)|\(quantityPart)",
            produceID: nil,
            basicIngredientID: item.id,
            name: item.displayName(languageCode: "en"),
            quantity: normalizedQuantity?.isEmpty == false ? normalizedQuantity : nil,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
    }

    static func custom(
        name: String,
        quantity: String?,
        sourceRecipeID: String? = nil,
        sourceRecipeTitle: String? = nil
    ) -> ShoppingListEntry {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityPart = normalizedQuantity?.lowercased() ?? ""
        return ShoppingListEntry(
            id: "custom:\(normalizedName.lowercased())|\(quantityPart)",
            produceID: nil,
            basicIngredientID: nil,
            name: normalizedName,
            quantity: normalizedQuantity?.isEmpty == false ? normalizedQuantity : nil,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
    }
}

final class ShoppingListViewModel: ObservableObject {
    @Published private var entries: [ShoppingListEntry] = []

    var items: [ShoppingListEntry] {
        entries
    }

    private let catalogByID: [String: ProduceItem]
    private let basicCatalogByID: [String: BasicIngredient]
    private let storage: UserDefaults
    private let storageKey = "shoppingListEntries"
    private let supabaseService = SupabaseService.shared
    private let outboxStore = OutboxStore()

    init(
        catalog: [ProduceItem] = ProduceStore.loadFromBundle(),
        basicCatalog: [BasicIngredient] = BasicIngredientCatalog.all,
        storage: UserDefaults = .standard
    ) {
        self.catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        self.basicCatalogByID = Dictionary(uniqueKeysWithValues: basicCatalog.map { ($0.id, $0) })
        self.storage = storage
        load()
    }

    func add(_ item: ProduceItem, sourceRecipeID: String? = nil, sourceRecipeTitle: String? = nil) {
        guard catalogByID[item.id] != nil else { return }
        let entry = ShoppingListEntry.produce(item, sourceRecipeID: sourceRecipeID, sourceRecipeTitle: sourceRecipeTitle)
        if contains(entry) {
            if sourceRecipeID != nil || sourceRecipeTitle != nil {
                attachRecipeSourceIfNeeded(
                    toMatchingEntryID: entry.id,
                    sourceRecipeID: sourceRecipeID,
                    sourceRecipeTitle: sourceRecipeTitle
                )
            }
            return
        }
        entries.append(entry)
        save()
        writeThroughCreate(entry)
    }

    func addCustom(
        name: String,
        quantity: String?,
        sourceRecipeID: String? = nil,
        sourceRecipeTitle: String? = nil
    ) {
        let entry = ShoppingListEntry.custom(
            name: name,
            quantity: quantity,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
        guard !entry.name.isEmpty else { return }
        if contains(entry) {
            if sourceRecipeID != nil || sourceRecipeTitle != nil {
                attachRecipeSourceIfNeeded(
                    toMatchingEntryID: entry.id,
                    sourceRecipeID: sourceRecipeID,
                    sourceRecipeTitle: sourceRecipeTitle
                )
            }
            return
        }
        entries.append(entry)
        save()
        writeThroughCreate(entry)
    }

    func add(
        _ item: BasicIngredient,
        quantity: String? = nil,
        sourceRecipeID: String? = nil,
        sourceRecipeTitle: String? = nil
    ) {
        guard basicCatalogByID[item.id] != nil else { return }
        let entry = ShoppingListEntry.basic(
            item,
            quantity: quantity,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
        if contains(entry) {
            if sourceRecipeID != nil || sourceRecipeTitle != nil {
                attachRecipeSourceIfNeeded(
                    toMatchingEntryID: entry.id,
                    sourceRecipeID: sourceRecipeID,
                    sourceRecipeTitle: sourceRecipeTitle
                )
            }
            return
        }
        entries.append(entry)
        save()
        writeThroughCreate(entry)
    }

    func remove(_ item: ProduceItem) {
        let removed = entries.filter { $0.produceID == item.id }
        entries.removeAll { $0.produceID == item.id }
        save()
        removed.forEach(writeThroughDelete)
    }

    func remove(_ item: BasicIngredient) {
        let removed = entries.filter { $0.basicIngredientID == item.id }
        entries.removeAll { $0.basicIngredientID == item.id }
        save()
        removed.forEach(writeThroughDelete)
    }

    func remove(_ entry: ShoppingListEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
        writeThroughDelete(entry)
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets
            .sorted()
            .compactMap { index in entries.indices.contains(index) ? entries[index] : nil }
        for index in offsets.sorted(by: >) {
            entries.remove(at: index)
        }
        save()
        removed.forEach(writeThroughDelete)
    }

    func contains(_ item: ProduceItem) -> Bool {
        entries.contains { $0.produceID == item.id }
    }

    func contains(_ item: BasicIngredient) -> Bool {
        entries.contains { $0.basicIngredientID == item.id }
    }

    func contains(_ entry: ShoppingListEntry) -> Bool {
        entries.contains { $0.id == entry.id }
    }

    func containsCustom(named name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return entries.contains { entry in
            guard entry.produceID == nil && entry.basicIngredientID == nil else { return false }
            return entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    func removeCustom(named name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        let removed = entries.filter { entry in
            guard entry.produceID == nil && entry.basicIngredientID == nil else { return false }
            return entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        entries.removeAll { entry in
            guard entry.produceID == nil && entry.basicIngredientID == nil else { return false }
            return entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        save()
        removed.forEach(writeThroughDelete)
    }

    @discardableResult
    func addAll(_ items: [ProduceItem]) -> (added: Int, alreadyInList: Int) {
        var added = 0
        var alreadyInList = 0

        for item in items {
            if contains(item) {
                alreadyInList += 1
            } else {
                add(item)
                added += 1
            }
        }

        return (added, alreadyInList)
    }

    @discardableResult
    func addAllRecipeIngredients(
        _ ingredients: [RecipeIngredient],
        sourceRecipeID: String?,
        sourceRecipeTitle: String?,
        produceLookup: (String) -> ProduceItem?,
        basicLookup: (String) -> BasicIngredient?
    ) -> (added: Int, alreadyInList: Int) {
        var added = 0
        var alreadyInList = 0

        for ingredient in ingredients {
            if let produceID = ingredient.produceID,
               let produceItem = produceLookup(produceID) {
                if contains(produceItem) {
                    alreadyInList += 1
                    attachRecipeSourceIfNeeded(
                        toMatchingEntryID: ShoppingListEntry.produce(produceItem).id,
                        sourceRecipeID: sourceRecipeID,
                        sourceRecipeTitle: sourceRecipeTitle
                    )
                } else {
                    add(
                        produceItem,
                        sourceRecipeID: sourceRecipeID,
                        sourceRecipeTitle: sourceRecipeTitle
                    )
                    added += 1
                }
                continue
            }

            if let basicID = ingredient.basicIngredientID,
               let basicItem = basicLookup(basicID) {
                let basicEntry = ShoppingListEntry.basic(basicItem, quantity: ingredient.quantity)
                if contains(basicItem) || contains(basicEntry) {
                    alreadyInList += 1
                    attachRecipeSourceIfNeeded(
                        toMatchingEntryID: basicEntry.id,
                        sourceRecipeID: sourceRecipeID,
                        sourceRecipeTitle: sourceRecipeTitle
                    )
                } else {
                    add(
                        basicItem,
                        quantity: ingredient.quantity,
                        sourceRecipeID: sourceRecipeID,
                        sourceRecipeTitle: sourceRecipeTitle
                    )
                    added += 1
                }
                continue
            }

            let customEntry = ShoppingListEntry.custom(name: ingredient.name, quantity: ingredient.quantity)
            if contains(customEntry) {
                alreadyInList += 1
                attachRecipeSourceIfNeeded(
                    toMatchingEntryID: customEntry.id,
                    sourceRecipeID: sourceRecipeID,
                    sourceRecipeTitle: sourceRecipeTitle
                )
            } else {
                addCustom(
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    sourceRecipeID: sourceRecipeID,
                    sourceRecipeTitle: sourceRecipeTitle
                )
                added += 1
            }
        }

        return (added, alreadyInList)
    }

    func resolveProduceItem(for entry: ShoppingListEntry) -> ProduceItem? {
        guard let produceID = entry.produceID else { return nil }
        return catalogByID[produceID]
    }

    func resolveBasicIngredient(for entry: ShoppingListEntry) -> BasicIngredient? {
        guard let basicID = entry.basicIngredientID else { return nil }
        return basicCatalogByID[basicID]
    }

    private func save() {
        let encoded = try? JSONEncoder().encode(entries)
        storage.set(encoded, forKey: storageKey)
    }

    private func attachRecipeSourceIfNeeded(
        toMatchingEntryID entryID: String,
        sourceRecipeID: String?,
        sourceRecipeTitle: String?
    ) {
        guard sourceRecipeID != nil || sourceRecipeTitle != nil else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }

        let entry = entries[index]
        guard entry.sourceRecipeID == nil && entry.sourceRecipeTitle == nil else { return }

        entries[index] = ShoppingListEntry(
            id: entry.id,
            produceID: entry.produceID,
            basicIngredientID: entry.basicIngredientID,
            name: entry.name,
            quantity: entry.quantity,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: sourceRecipeTitle
        )
        save()
        writeThroughUpdate(entries[index])
    }

    private func load() {
        guard let data = storage.data(forKey: storageKey) else {
            // Backward compatibility with older list format based on pure produce IDs.
            let oldIDs = storage.stringArray(forKey: "shoppingListItemIDs") ?? []
            entries = oldIDs
                .compactMap { catalogByID[$0] }
                .map { ShoppingListEntry.produce($0) }
            save()
            return
        }

        guard let decoded = try? JSONDecoder().decode([ShoppingListEntry].self, from: data) else {
            entries = []
            return
        }

        entries = decoded.filter { entry in
            if let produceID = entry.produceID {
                return catalogByID[produceID] != nil
            }
            if let basicID = entry.basicIngredientID {
                return basicCatalogByID[basicID] != nil
            }
            if entry.produceID == nil && entry.basicIngredientID == nil {
                return !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
    }

    private func writeThroughCreate(_ entry: ShoppingListEntry) {
        let traceID = String(UUID().uuidString.prefix(8))
        let mapped = mapEntryForCloudWrite(entry)
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(entry.id) phase=local_update_done")
        let createPayload = ShoppingListOutboxMutationPayload(
            localItemID: entry.id,
            ingredientType: mapped.ingredientType,
            ingredientID: mapped.ingredientID,
            customName: mapped.customName,
            quantity: mapped.quantity,
            unit: mapped.unit,
            sourceRecipeID: mapped.sourceRecipeID,
            isChecked: false
        )
        appendOutboxRecord(
            traceID: traceID,
            action: "shopping_list_create",
            itemID: entry.id,
            entityType: "shopping_list_item",
            operationType: "create",
            payload: createPayload
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(entry.id) phase=task_started")
        Task { [supabaseService] in
            print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(entry.id) phase=service_call")
            do {
                try await supabaseService.createShoppingListItem(
                    localItemID: entry.id,
                    ingredientType: mapped.ingredientType,
                    ingredientID: mapped.ingredientID,
                    customName: mapped.customName,
                    quantity: mapped.quantity,
                    unit: mapped.unit,
                    sourceRecipeID: mapped.sourceRecipeID,
                    isChecked: false,
                    traceID: traceID
                )
            } catch {
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_create item=\(entry.id) phase=write_failed error=\(error)")
            }
        }
    }

    private func writeThroughUpdate(_ entry: ShoppingListEntry) {
        let traceID = String(UUID().uuidString.prefix(8))
        let mapped = mapEntryForCloudWrite(entry)
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(entry.id) phase=local_update_done")
        let updatePayload = ShoppingListOutboxMutationPayload(
            localItemID: entry.id,
            ingredientType: mapped.ingredientType,
            ingredientID: mapped.ingredientID,
            customName: mapped.customName,
            quantity: mapped.quantity,
            unit: mapped.unit,
            sourceRecipeID: mapped.sourceRecipeID,
            isChecked: false
        )
        appendOutboxRecord(
            traceID: traceID,
            action: "shopping_list_update",
            itemID: entry.id,
            entityType: "shopping_list_item",
            operationType: "update",
            payload: updatePayload
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(entry.id) phase=task_started")
        Task { [supabaseService] in
            print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(entry.id) phase=service_call")
            do {
                try await supabaseService.updateShoppingListItem(
                    localItemID: entry.id,
                    ingredientType: mapped.ingredientType,
                    ingredientID: mapped.ingredientID,
                    customName: mapped.customName,
                    quantity: mapped.quantity,
                    unit: mapped.unit,
                    sourceRecipeID: mapped.sourceRecipeID,
                    isChecked: false,
                    traceID: traceID
                )
            } catch {
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_update item=\(entry.id) phase=write_failed error=\(error)")
            }
        }
    }

    private func writeThroughDelete(_ entry: ShoppingListEntry) {
        let traceID = String(UUID().uuidString.prefix(8))
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(entry.id) phase=local_update_done")
        appendOutboxRecord(
            traceID: traceID,
            action: "shopping_list_delete",
            itemID: entry.id,
            entityType: "shopping_list_item",
            operationType: "delete",
            payload: ShoppingListDeleteOutboxMutationPayload(localItemID: entry.id)
        )
        print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(entry.id) phase=task_started")
        Task { [supabaseService] in
            print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(entry.id) phase=service_call")
            do {
                try await supabaseService.deleteShoppingListItem(localItemID: entry.id, traceID: traceID)
            } catch {
                print("[SEASON_SUPABASE] trace=\(traceID) action=shopping_list_delete item=\(entry.id) phase=write_failed error=\(error)")
            }
        }
    }

    private func mapEntryForCloudWrite(_ entry: ShoppingListEntry) -> (
        ingredientType: String,
        ingredientID: String?,
        customName: String?,
        quantity: Double?,
        unit: String?,
        sourceRecipeID: String?
    ) {
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
        return (
            ingredientType: ingredientType,
            ingredientID: ingredientID,
            customName: customName,
            quantity: parsed.quantity,
            unit: parsed.unit,
            sourceRecipeID: entry.sourceRecipeID
        )
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
        payload: T
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
            status: "pending",
            attemptCount: 0,
            lastError: nil,
            createdAt: now,
            updatedAt: now
        )
        outboxStore.append(record)
        print("[SEASON_SUPABASE] trace=\(traceID) action=\(action) item=\(itemID) mutation_id=\(mutationID) phase=outbox_appended")
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
