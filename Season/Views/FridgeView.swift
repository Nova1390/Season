import SwiftUI

struct FridgeView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var fridgeViewModel: FridgeViewModel
    @State private var query = ""
    @State private var selectedSortControl: FridgeSortControl = .freshness
    @State private var showSearchField = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                fridgeTopHeader

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionTitleCountRow(
                            title: produceViewModel.localizer.text(.fridgePreviewTitle),
                            countText: "\(fridgeEntries.count)"
                        )
                        Spacer(minLength: 8)
                        sortControl
                    }

                    if fridgeEntries.isEmpty {
                        VStack(spacing: 12) {
                            EmptyStateCard(
                                symbol: "snowflake",
                                title: produceViewModel.localizer.text(.fridgeEmptyTitle),
                                subtitle: produceViewModel.localizer.text(.fridgeEmptySubtitle)
                            )

                            Button {
                                showSearchField = true
                            } label: {
                                Text(produceViewModel.localizer.text(.addIngredients))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(SeasonPrimaryButtonStyle())
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.92))
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(fridgeEntries) { entry in
                                fridgeEntryRow(entry)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    addIngredientHeader

                    VStack(spacing: 10) {
                        ForEach(addableResults) { item in
                            addIngredientRow(item)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(SeasonColors.secondarySurface.opacity(0.62))
                    )
                }
            }
            .padding(.horizontal, SeasonSpacing.md)
            .padding(.top, SeasonSpacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance)
        }
        .background(SeasonColors.primarySurface)
        .navigationTitle(produceViewModel.localizer.text(.fridgeTab))
        .searchable(
            text: $query,
            isPresented: $showSearchField,
            prompt: produceViewModel.localizer.text(.searchPlaceholder)
        )
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
        PressableSurfaceRow {
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
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.7)
            )
            .contentShape(Rectangle())
        }
    }

    private var fridgeTopHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Harvest")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                    .foregroundStyle(.secondary)
                    Text(produceViewModel.localizer.text(.fridgeTab))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button {
                    showSearchField = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text(produceViewModel.localizer.text(.addIngredients))
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(SeasonPrimaryButtonStyle())
            }

            HStack {
                Text("\(fridgeEntries.count) items in your fridge")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .padding(.top, 2)
    }

    private var addIngredientHeader: some View {
        SectionTitleCountRow(
            title: produceViewModel.localizer.text(.addIngredient),
            countText: String(format: produceViewModel.localizer.text(.ingredientsCountFormat), addableResults.count)
        )
    }

    private var sortControl: some View {
        Menu {
            Button {
                selectedSortControl = .freshness
            } label: {
                Label("Default", systemImage: selectedSortControl == .freshness ? "checkmark" : "")
            }
            Button {
                selectedSortControl = .alphabetical
            } label: {
                Label("A-Z", systemImage: selectedSortControl == .alphabetical ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                Text(selectedSortControl.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(SeasonColors.secondarySurface)
            )
        }
    }

    @ViewBuilder
    private func addIngredientRow(_ item: IngredientSearchResult) -> some View {
        PressableSurfaceRow {
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
                        .foregroundStyle(hasItem ? SeasonColors.seasonGreen : Color.primary.opacity(0.7))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(hasItem)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 0.7)
            )
            .contentShape(Rectangle())
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
        return FridgeEntry(
            id: "produce-\(item.id)",
            title: item.displayName(languageCode: languageCode),
            subtitle: localizer.categoryTitle(for: item.category),
            source: .produce(item)
        )
    }

    static func basic(_ item: BasicIngredient, languageCode: String, localizer: AppLocalizer) -> FridgeEntry {
        return FridgeEntry(
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

private enum FridgeSortControl {
    case freshness
    case alphabetical

    var label: String {
        switch self {
        case .freshness: return "Default"
        case .alphabetical: return "A-Z"
        }
    }
}

private struct PressableSurfaceRow<Content: View>: View {
    @GestureState private var isPressed = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .scaleEffect(isPressed ? 0.987 : 1)
            .opacity(isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: isPressed)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0, maximumDistance: 10)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}
