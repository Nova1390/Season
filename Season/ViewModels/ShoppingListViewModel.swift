import Foundation
import Combine

final class ShoppingListViewModel: ObservableObject {
    @Published private var itemIDs: [String] = []

    var items: [ProduceItem] {
        itemIDs.compactMap { catalogByID[$0] }
    }

    private let catalogByID: [String: ProduceItem]
    private let storage: UserDefaults
    private let storageKey = "shoppingListItemIDs"

    init(catalog: [ProduceItem] = ProduceStore.loadFromBundle(), storage: UserDefaults = .standard) {
        self.catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        self.storage = storage
        load()
    }

    func add(_ item: ProduceItem) {
        guard catalogByID[item.id] != nil else { return }
        guard !contains(item) else { return }
        itemIDs.append(item.id)
        save()
    }

    func remove(_ item: ProduceItem) {
        itemIDs.removeAll { $0 == item.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            itemIDs.remove(at: index)
        }
        save()
    }

    func contains(_ item: ProduceItem) -> Bool {
        itemIDs.contains(item.id)
    }

    private func save() {
        storage.set(itemIDs, forKey: storageKey)
    }

    private func load() {
        let savedIDs = storage.stringArray(forKey: storageKey) ?? []
        itemIDs = savedIDs.filter { catalogByID[$0] != nil }
    }
}
