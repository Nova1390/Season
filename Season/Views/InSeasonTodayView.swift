import SwiftUI

struct InSeasonTodayView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            let rankedItems = viewModel.rankedInSeasonTodayItems()

            if rankedItems.isEmpty {
                EmptyStateCard(
                    symbol: "leaf",
                    title: viewModel.localizer.text(.inSeasonTodayTitle),
                    subtitle: viewModel.localizer.text(.noResults)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(rankedItems) { ranked in
                    SeasonCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 14) {
                                ProduceThumbnailView(item: ranked.item, size: 46)

                                NavigationLink {
                                    ProduceDetailView(
                                        item: ranked.item,
                                        viewModel: viewModel,
                                        shoppingListViewModel: shoppingListViewModel
                                    )
                                } label: {
                                    Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                                        .font(.body)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                SeasonalStatusBadge(
                                    score: ranked.item.seasonalityScore(month: viewModel.currentMonth),
                                    delta: ranked.item.seasonalityDelta(month: viewModel.currentMonth),
                                    localizer: viewModel.localizer
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.localizer.text(.rankingWhy))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(ranked.reasons.joined(separator: " • "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
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
        .navigationTitle(viewModel.localizer.text(.inSeasonTodayTitle))
        .toolbar {
            CartToolbarItems(
                produceViewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
    }
}
