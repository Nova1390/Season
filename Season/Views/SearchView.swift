import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @State private var query = ""

    var body: some View {
        List {
            let results = viewModel.searchResults(query: query)

            if results.isEmpty {
                Text(viewModel.localizer.text(.noResults))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { item in
                    NavigationLink {
                        ProduceDetailView(
                            item: item,
                            viewModel: viewModel,
                            shoppingListViewModel: shoppingListViewModel
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                            Text(viewModel.localizer.categoryTitle(for: item.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.localizer.text(.searchTab))
        .searchable(text: $query, prompt: viewModel.localizer.text(.searchPlaceholder))
    }
}
