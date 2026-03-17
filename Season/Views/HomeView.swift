import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            Section {
                SeasonCard {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.localizer.text(.currentMonth))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(viewModel.currentMonthName)
                                .font(.title2.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.top, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            seasonSection(
                title: viewModel.localizer.text(.inSeasonNow),
                inSeason: true,
                symbol: "leaf.fill"
            )

            seasonSection(
                title: viewModel.localizer.text(.notInSeasonNow),
                inSeason: false,
                symbol: "clock.fill"
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.localizer.text(.homeTab))
    }

    @ViewBuilder
    private func seasonSection(title: String, inSeason: Bool, symbol: String) -> some View {
        Section {
            ForEach(ProduceCategoryKey.allCases, id: \.self) { category in
                let items = viewModel.items(in: category, inSeason: inSeason)

                if !items.isEmpty {
                    HStack(spacing: 8) {
                        CategoryIconView(category: category, size: 16)
                        Text(viewModel.localizer.categoryTitle(for: category))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(items) { item in
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
                                    Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                                        .font(.body)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                SeasonalStatusBadge(
                                    isInSeason: inSeason,
                                    localizer: viewModel.localizer
                                )

                                quickAddButton(for: item)
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        header: {
            Label(title, systemImage: symbol)
                .font(.headline)
                .textCase(nil)
        }
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
