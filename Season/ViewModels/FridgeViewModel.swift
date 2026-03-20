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
    }

    func remove(_ item: ProduceItem) {
        produceIDs.removeAll { $0 == item.id }
        save()
    }

    func add(_ item: BasicIngredient) {
        guard basicCatalogByID[item.id] != nil else { return }
        guard !contains(item) else { return }
        basicIngredientIDs.append(item.id)
        save()
    }

    func remove(_ item: BasicIngredient) {
        basicIngredientIDs.removeAll { $0 == item.id }
        save()
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
    }

    func removeCustom(named name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        customItems.removeAll {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        save()
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
        for index in offsets.sorted(by: >) {
            guard produceIDs.indices.contains(index) else { continue }
            produceIDs.remove(at: index)
        }
        save()
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
