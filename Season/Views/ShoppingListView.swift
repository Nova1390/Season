import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            if shoppingListViewModel.items.isEmpty {
                Text(produceViewModel.localizer.text(.shoppingListEmpty))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shoppingListViewModel.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName(languageCode: produceViewModel.languageCode))
                            .font(.body)

                        Text(seasonStatus(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: shoppingListViewModel.remove)
            }
        }
        .navigationTitle(produceViewModel.localizer.text(.listTab))
    }

    private func seasonStatus(for item: ProduceItem) -> String {
        if item.isInSeason(month: produceViewModel.currentMonth) {
            return produceViewModel.localizer.text(.inSeason)
        } else {
            return produceViewModel.localizer.text(.notInSeason)
        }
    }
}

