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
                Section(
                    header: SectionTitleCountRow(
                        title: viewModel.localizer.text(.inSeasonTodayTitle),
                        countText: String(format: viewModel.localizer.text(.ingredientsCountFormat), rankedItems.count)
                    ).textCase(nil)
                ) {
                    ForEach(rankedItems) { ranked in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 12) {
                                ProduceThumbnailView(item: ranked.item, size: 44)

                                NavigationLink {
                                    ProduceDetailView(
                                        item: ranked.item,
                                        viewModel: viewModel,
                                        shoppingListViewModel: shoppingListViewModel
                                    )
                                } label: {
                                    Text(ranked.item.displayName(languageCode: viewModel.localizer.languageCode))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                SeasonalStatusBadge(
                                    score: ranked.item.seasonalityScore(month: viewModel.currentMonth),
                                    delta: ranked.item.seasonalityDelta(month: viewModel.currentMonth),
                                    localizer: viewModel.localizer
                                )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.localizer.text(.rankingWhy))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(ranked.reasons.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.clear)
                    }
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
