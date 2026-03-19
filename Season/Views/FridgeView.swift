import SwiftUI

struct FridgeView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var fridgeViewModel: FridgeViewModel
    @State private var query = ""

    var body: some View {
        List {
            Section(header: SectionTitleCountRow(
                title: produceViewModel.localizer.text(.fridgePreviewTitle),
                countText: "\(fridgeEntries.count)"
            ).textCase(nil)) {
                if fridgeEntries.isEmpty {
                    EmptyStateCard(
                        symbol: "snowflake",
                        title: produceViewModel.localizer.text(.fridgeEmptyTitle),
                        subtitle: produceViewModel.localizer.text(.fridgeEmptySubtitle)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(fridgeEntries) { entry in
                        fridgeEntryRow(entry)
                    }
                }
            }

            Section(header: SectionTitleCountRow(
                title: produceViewModel.localizer.text(.addIngredient),
                countText: String(format: produceViewModel.localizer.text(.ingredientsCountFormat), addableResults.count)
            ).textCase(nil)) {
                ForEach(addableResults) { item in
                    HStack(spacing: 12) {
                        ingredientThumbnail(for: item)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        let hasItem = isInFridge(item)

                        Button {
                            addToFridge(item)
                        } label: {
                            Image(systemName: hasItem ? "checkmark.circle.fill" : "plus.circle")
                                .font(.title3)
                                .foregroundStyle(hasItem ? .green : .secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .disabled(hasItem)
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(produceViewModel.localizer.text(.fridgeTab))
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .searchable(text: $query, prompt: produceViewModel.localizer.text(.searchPlaceholder))
    }

    private var addableResults: [IngredientSearchResult] {
        produceViewModel.searchIngredientResults(query: query)
    }

    private var fridgeEntries: [FridgeEntry] {
        let produce = fridgeViewModel.produceItems.map { FridgeEntry.produce($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer) }
        let basic = fridgeViewModel.basicItems.map { FridgeEntry.basic($0, languageCode: produceViewModel.languageCode, localizer: produceViewModel.localizer) }
        let custom = fridgeViewModel.customFridgeItems.map { FridgeEntry.custom($0, localizer: produceViewModel.localizer) }
        return (produce + basic + custom).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder
    private func fridgeEntryRow(_ entry: FridgeEntry) -> some View {
        HStack(spacing: 12) {
            switch entry.source {
            case .produce(let item):
                ProduceThumbnailView(item: item, size: 46)
            case .basic:
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "leaf")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            case .custom:
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "text.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive) {
                removeFromFridge(entry)
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title3)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(produceViewModel.localizer.text(.remove))
        }
        .padding(.vertical, 4)
        .listRowSeparator(.visible)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeFromFridge(entry)
            } label: {
                Label(produceViewModel.localizer.text(.remove), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func ingredientThumbnail(for result: IngredientSearchResult) -> some View {
        switch result.source {
        case .produce(let item):
            ProduceThumbnailView(item: item, size: 46)
        case .basic:
            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "leaf")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private func isInFridge(_ result: IngredientSearchResult) -> Bool {
        switch result.source {
        case .produce(let item):
            return fridgeViewModel.contains(item)
        case .basic(let basic):
            return fridgeViewModel.contains(basic)
        }
    }

    private func addToFridge(_ result: IngredientSearchResult) {
        switch result.source {
        case .produce(let item):
            fridgeViewModel.add(item)
        case .basic(let basic):
            fridgeViewModel.add(basic)
        }
    }

    private func removeFromFridge(_ entry: FridgeEntry) {
        switch entry.source {
        case .produce(let item):
            fridgeViewModel.remove(item)
        case .basic(let basic):
            fridgeViewModel.remove(basic)
        case .custom(let custom):
            fridgeViewModel.removeCustom(named: custom.name)
        }
    }
}

private struct FridgeEntry: Identifiable {
    enum Source {
        case produce(ProduceItem)
        case basic(BasicIngredient)
        case custom(FridgeCustomItem)
    }

    let id: String
    let title: String
    let subtitle: String
    let source: Source

    static func produce(_ item: ProduceItem, languageCode: String, localizer: AppLocalizer) -> FridgeEntry {
        FridgeEntry(
            id: "produce-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            subtitle: localizer.categoryTitle(for: item.category),
            source: .produce(item)
        )
    }

    static func basic(_ item: BasicIngredient, languageCode: String, localizer: AppLocalizer) -> FridgeEntry {
        FridgeEntry(
            id: "basic-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            subtitle: localizer.text(.basicIngredient),
            source: .basic(item)
        )
    }

    static func custom(_ item: FridgeCustomItem, localizer: AppLocalizer) -> FridgeEntry {
        let subtitle = item.quantity?.isEmpty == false ? item.quantity! : localizer.text(.customIngredient)
        return FridgeEntry(
            id: item.id,
            title: item.name,
            subtitle: subtitle,
            source: .custom(item)
        )
    }
}
