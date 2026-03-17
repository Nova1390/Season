import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            if shoppingListViewModel.items.isEmpty {
                EmptyStateCard(
                    symbol: "cart",
                    title: produceViewModel.localizer.text(.shoppingListEmptyTitle),
                    subtitle: produceViewModel.localizer.text(.shoppingListEmptySubtitle)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    SeasonCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(produceViewModel.localizer.text(.seasonalScore), systemImage: "leaf.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(seasonalScore)")
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                Text("%")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: Double(seasonalScore), total: 100)
                                .tint(.green)

                            Text(
                                produceViewModel.localizer.itemsInSeasonText(
                                    inSeasonCount: inSeasonCount,
                                    totalCount: shoppingListViewModel.items.count
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(shoppingListViewModel.items) { item in
                        SeasonCard {
                            HStack(alignment: .center, spacing: 14) {
                                ProduceThumbnailView(item: item, size: 46)

                                Text(item.displayName(languageCode: produceViewModel.languageCode))
                                    .font(.body)

                                Spacer()

                                SeasonalStatusBadge(
                                    isInSeason: item.isInSeason(month: produceViewModel.currentMonth),
                                    localizer: produceViewModel.localizer
                                )
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: shoppingListViewModel.remove)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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

}
