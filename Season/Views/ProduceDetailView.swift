import SwiftUI

struct ProduceDetailView: View {
    let item: ProduceItem
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        List {
            Section {
                Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Section(viewModel.localizer.text(.category)) {
                Text(viewModel.localizer.categoryTitle(for: item.category))
            }

            Section(viewModel.localizer.text(.seasonMonths)) {
                Text(viewModel.monthNames(for: item.seasonMonths))
            }

            Section {
                Button {
                    shoppingListViewModel.add(item)
                } label: {
                    Text(buttonTitle)
                }
                .disabled(shoppingListViewModel.contains(item))
            }
        }
        .navigationTitle(item.displayName(languageCode: viewModel.localizer.languageCode))
    }

    private var buttonTitle: String {
        if shoppingListViewModel.contains(item) {
            return viewModel.localizer.text(.alreadyInList)
        } else {
            return viewModel.localizer.text(.addToList)
        }
    }
}
