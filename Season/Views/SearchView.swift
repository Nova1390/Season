import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @State private var query = ""

    var body: some View {
        List {
            let results = viewModel.searchResults(query: query)

            if results.isEmpty {
                EmptyStateCard(
                    symbol: "magnifyingglass.circle",
                    title: viewModel.localizer.text(.searchEmptyTitle),
                    subtitle: viewModel.localizer.text(.searchEmptySubtitle)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(results) { item in
                    SeasonCard {
                        HStack(alignment: .center, spacing: 14) {
                            ProduceThumbnailView(item: item, size: 46)

                            NavigationLink {
                                ProduceDetailView(
                                    item: item,
                                    viewModel: viewModel,
                                    shoppingListViewModel: shoppingListViewModel
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                                        .font(.body)
                                    Text(viewModel.localizer.categoryTitle(for: item.category))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                SeasonalStatusBadge(
                                    isInSeason: item.isInSeason(month: viewModel.currentMonth),
                                    localizer: viewModel.localizer
                                )
                            }
                            .buttonStyle(.plain)

                            quickAddButton(for: item)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.localizer.text(.searchTab))
        .searchable(text: $query, prompt: viewModel.localizer.text(.searchPlaceholder))
    }

    @ViewBuilder
    private func quickAddButton(for item: ProduceItem) -> some View {
        let isInList = shoppingListViewModel.contains(item)

        Button {
            shoppingListViewModel.add(item)
        } label: {
            Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(isInList ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isInList)
    }
}
