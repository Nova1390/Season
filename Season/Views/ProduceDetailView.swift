import SwiftUI

struct ProduceDetailView: View {
    let item: ProduceItem
    let viewModel: ProduceViewModel

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
        }
        .navigationTitle(item.displayName(languageCode: viewModel.localizer.languageCode))
    }
}
