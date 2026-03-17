import Foundation
import Combine

final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ProduceItem] = []

    func add(_ item: ProduceItem) {
        guard !contains(item) else { return }
        items.append(item)
    }

    func remove(_ item: ProduceItem) {
        items.removeAll { $0.id == item.id }
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
    }

    func contains(_ item: ProduceItem) -> Bool {
        items.contains { $0.id == item.id }
    }
}
