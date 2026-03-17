import SwiftUI

struct ProduceDetailView: View {
    let item: ProduceItem
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ProduceHeroImageView(item: item, height: 214)

                SeasonCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                            .font(.title3.weight(.semibold))

                        HStack {
                            Text(viewModel.localizer.text(.seasonalStatus))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            SeasonalStatusBadge(
                                isInSeason: item.isInSeason(month: viewModel.currentMonth),
                                localizer: viewModel.localizer
                            )
                        }
                    }
                }

                SeasonCard {
                    HStack(spacing: 14) {
                        CategoryIconView(category: item.category, size: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.localizer.text(.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.localizer.categoryTitle(for: item.category))
                                .font(.body.weight(.medium))
                        }
                        Spacer()
                    }
                }

                SeasonCard {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.localizer.text(.seasonMonths))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.monthNames(for: item.seasonMonths))
                                .font(.body.weight(.medium))
                        }
                        Spacer()
                    }
                }

                Button {
                    shoppingListViewModel.add(item)
                } label: {
                    HStack {
                        Image(systemName: shoppingListViewModel.contains(item) ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(shoppingListViewModel.contains(item) ? .gray : .accentColor)
                .disabled(shoppingListViewModel.contains(item))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.displayName(languageCode: viewModel.localizer.languageCode))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var buttonTitle: String {
        if shoppingListViewModel.contains(item) {
            return viewModel.localizer.text(.alreadyInList)
        } else {
            return viewModel.localizer.text(.addToList)
        }
    }
}
