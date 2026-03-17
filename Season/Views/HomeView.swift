import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            Section(header: Text(viewModel.localizer.text(.currentMonth))) {
                Text(viewModel.currentMonthName)
            }

            seasonSection(
                title: viewModel.localizer.text(.inSeasonNow),
                inSeason: true
            )

            seasonSection(
                title: viewModel.localizer.text(.notInSeasonNow),
                inSeason: false
            )
        }
        .navigationTitle(viewModel.localizer.text(.homeTab))
    }

    @ViewBuilder
    private func seasonSection(title: String, inSeason: Bool) -> some View {
        Section(header: Text(title)) {
            ForEach(ProduceCategoryKey.allCases, id: \.self) { category in
                let items = viewModel.items(in: category, inSeason: inSeason)

                if !items.isEmpty {
                    Text(viewModel.localizer.categoryTitle(for: category))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(items) { item in
                        NavigationLink {
                            ProduceDetailView(
                                item: item,
                                viewModel: viewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                        }
                    }
                }
            }
        }
    }
}
