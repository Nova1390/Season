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
                Section(produceViewModel.localizer.text(.seasonalScore)) {
                    Text("\(seasonalScore)%")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(
                        produceViewModel.localizer.itemsInSeasonText(
                            inSeasonCount: inSeasonCount,
                            totalCount: shoppingListViewModel.items.count
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

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

    private var inSeasonCount: Int {
        shoppingListViewModel.items.filter {
            $0.isInSeason(month: produceViewModel.currentMonth)
        }.count
    }

    private var seasonalScore: Int {
        let totalCount = shoppingListViewModel.items.count
        guard totalCount > 0 else { return 0 }
        let percentage = (Double(inSeasonCount) / Double(totalCount)) * 100
        return Int(percentage.rounded())
    }

    private func seasonStatus(for item: ProduceItem) -> String {
        if item.isInSeason(month: produceViewModel.currentMonth) {
            return produceViewModel.localizer.text(.inSeason)
        } else {
            return produceViewModel.localizer.text(.notInSeason)
        }
    }
}
