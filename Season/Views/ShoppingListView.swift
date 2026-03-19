import SwiftUI

struct ShoppingListView: View {
    private enum GroupRowPosition {
        case single
        case top
        case middle
        case bottom
    }

    private struct RecipeGroup: Identifiable {
        let id: String
        let recipeID: String?
        let recipeTitle: String
        let entries: [ShoppingListEntry]
        let rankedRecipe: RankedRecipe?
    }

    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject private var fridgeViewModel: FridgeViewModel

    @State private var isSelectionMode = false
    @State private var selectedIngredientIDs: Set<String> = []
    @State private var expandedRecipeGroupIDs: Set<String> = []

    var body: some View {
        List {
            if shoppingListViewModel.items.isEmpty {
                EmptyStateCard(
                    symbol: "cart",
                    title: produceViewModel.localizer.text(.shoppingListEmptyTitle),
                    subtitle: produceViewModel.localizer.text(.shoppingListEmptySubtitle)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                seasonalScoreSection

                if isSelectionMode {
                    bulkActionsSection
                }

                if !recipeGroups.isEmpty {
                    Section(header: Text(produceViewModel.localizer.text(.recipes)).textCase(nil)) {
                        ForEach(recipeGroups) { group in
                            recipeParentRow(group)

                            if expandedRecipeGroupIDs.contains(group.id) {
                                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                    childIngredientRow(
                                        entry,
                                        isLast: index == group.entries.count - 1
                                    )
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity
                                    ))
                                }
                            }
                        }
                    }
                }

                if !manualEntries.isEmpty {
                    Section(header: Text(produceViewModel.localizer.text(.addedManually)).textCase(nil)) {
                        ForEach(manualEntries) { entry in
                            manualItemRow(entry)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(produceViewModel.localizer.text(.listTab))
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelectionMode ? produceViewModel.localizer.text(.done) : produceViewModel.localizer.text(.select)) {
                    if isSelectionMode {
                        selectedIngredientIDs.removeAll()
                    }
                    isSelectionMode.toggle()
                }
            }
        }
        .onAppear {
            syncExpandedRecipeGroups()
        }
        .onChange(of: shoppingListViewModel.items) { _, _ in
            let validIDs = Set(shoppingListViewModel.items.map(\.id))
            selectedIngredientIDs = selectedIngredientIDs.intersection(validIDs)
            if shoppingListViewModel.items.isEmpty {
                isSelectionMode = false
            }
            syncExpandedRecipeGroups()
            print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
        }
    }

    private var seasonalScoreSection: some View {
        Section {
            SeasonCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(produceViewModel.localizer.text(.seasonalScore), systemImage: "leaf.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(seasonalScore)")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                        Text("%")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(seasonalScore), total: 100)
                        .tint(.green)

                    Text(
                        produceViewModel.localizer.itemsInSeasonText(
                            inSeasonCount: inSeasonCount,
                            totalCount: seasonalEligibleCount
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var bulkActionsSection: some View {
        Section {
            SeasonCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: produceViewModel.localizer.text(.selectionSummaryFormat), selectedIngredientIDs.count))
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Button(produceViewModel.localizer.text(.selectAll)) {
                            selectedIngredientIDs = Set(shoppingListViewModel.items.map(\.id))
                            print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
                        }
                        .buttonStyle(.bordered)

                        Button(produceViewModel.localizer.text(.clearSelection)) {
                            selectedIngredientIDs.removeAll()
                            print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        Button(role: .destructive) {
                            deleteSelectedEntries()
                        } label: {
                            Text(produceViewModel.localizer.text(.deleteSelected))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedIngredientIDs.isEmpty)

                        Button {
                            moveSelectedToFridge()
                        } label: {
                            Text(produceViewModel.localizer.text(.moveToFridge))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedIngredientIDs.isEmpty)
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func recipeParentRow(_ group: RecipeGroup) -> some View {
        let isExpanded = expandedRecipeGroupIDs.contains(group.id)

        HStack(spacing: 10) {
            Button {
                toggleGroup(group.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isExpanded)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.recipeTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text("\(group.entries.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let ranked = group.rankedRecipe {
                                Text("\(produceViewModel.localizer.text(.seasonalMatch)): \(ranked.seasonalMatchPercent)%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let ranked = group.rankedRecipe {
                NavigationLink {
                    RecipeDetailView(
                        rankedRecipe: ranked,
                        viewModel: produceViewModel,
                        shoppingListViewModel: shoppingListViewModel
                    )
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(groupRowBackground(isExpanded ? .top : .single))
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeRecipeGroup(group)
            } label: {
                Label(produceViewModel.localizer.text(.remove), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func childIngredientRow(_ entry: ShoppingListEntry, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if isSelectionMode {
                Button {
                    toggleSelection(for: entry)
                } label: {
                    Image(systemName: selectedIngredientIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedIngredientIDs.contains(entry.id) ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                ProduceThumbnailView(item: item, size: 36)
            } else if shoppingListViewModel.resolveBasicIngredient(for: entry) != nil {
                Image(systemName: "leaf")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            } else {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(childDisplayName(for: entry))
                    .font(.subheadline)

                if let quantity = entry.quantity {
                    Text(quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                SeasonalStatusBadge(
                    score: item.seasonalityScore(month: produceViewModel.currentMonth),
                    delta: item.seasonalityDelta(month: produceViewModel.currentMonth),
                    localizer: produceViewModel.localizer
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(groupRowBackground(isLast ? .bottom : .middle))
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: isLast ? 2 : 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                shoppingListViewModel.remove(entry)
            } label: {
                Label(produceViewModel.localizer.text(.remove), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func manualItemRow(_ entry: ShoppingListEntry) -> some View {
        SeasonCard {
            HStack(alignment: .center, spacing: 12) {
                if isSelectionMode {
                    Button {
                        toggleSelection(for: entry)
                    } label: {
                        Image(systemName: selectedIngredientIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedIngredientIDs.contains(entry.id) ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                    ProduceThumbnailView(item: item, size: 42)
                } else if shoppingListViewModel.resolveBasicIngredient(for: entry) != nil {
                    Image(systemName: "leaf")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                } else {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(childDisplayName(for: entry))
                        .font(.body)

                    if let quantity = entry.quantity {
                        Text(quantity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                    SeasonalStatusBadge(
                        score: item.seasonalityScore(month: produceViewModel.currentMonth),
                        delta: item.seasonalityDelta(month: produceViewModel.currentMonth),
                        localizer: produceViewModel.localizer
                    )
                }
            }
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                shoppingListViewModel.remove(entry)
            } label: {
                Label(produceViewModel.localizer.text(.remove), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func groupRowBackground(_ position: GroupRowPosition) -> some View {
        let fill = Color(.secondarySystemGroupedBackground)

        switch position {
        case .single:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
        case .top:
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 10,
                style: .continuous
            )
            .fill(fill)
        case .middle:
            Rectangle()
                .fill(fill)
        case .bottom:
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 10,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(fill)
        }
    }

    private func childDisplayName(for entry: ShoppingListEntry) -> String {
        if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
            return item.displayName(languageCode: produceViewModel.languageCode)
        }
        if let basic = shoppingListViewModel.resolveBasicIngredient(for: entry) {
            return basic.displayName(languageCode: produceViewModel.languageCode)
        }
        return entry.name
    }

    private var recipeGroups: [RecipeGroup] {
        let recipeSourceEntries = shoppingListViewModel.items.filter {
            $0.sourceRecipeID != nil || $0.sourceRecipeTitle != nil
        }

        let grouped = Dictionary(grouping: recipeSourceEntries) { entry in
            entry.sourceRecipeID ?? "title:\(entry.sourceRecipeTitle ?? "")"
        }

        return grouped.compactMap { key, entries in
            guard let first = entries.first else { return nil }
            let recipeID = first.sourceRecipeID
            let ranked = recipeID.flatMap { produceViewModel.rankedRecipe(forID: $0) }
            let recipeTitle = first.sourceRecipeTitle
                ?? ranked?.recipe.title
                ?? produceViewModel.localizer.text(.recipes)

            return RecipeGroup(
                id: key,
                recipeID: recipeID,
                recipeTitle: recipeTitle,
                entries: entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                rankedRecipe: ranked
            )
        }
        .sorted { $0.recipeTitle.localizedCaseInsensitiveCompare($1.recipeTitle) == .orderedAscending }
    }

    private var manualEntries: [ShoppingListEntry] {
        shoppingListViewModel.items
            .filter { $0.sourceRecipeID == nil && $0.sourceRecipeTitle == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedEntries: [ShoppingListEntry] {
        shoppingListViewModel.items.filter { selectedIngredientIDs.contains($0.id) }
    }

    private func syncExpandedRecipeGroups() {
        let currentGroupIDs = Set(recipeGroups.map(\.id))
        expandedRecipeGroupIDs = expandedRecipeGroupIDs.intersection(currentGroupIDs)

        let newGroupIDs = currentGroupIDs.subtracting(expandedRecipeGroupIDs)
        expandedRecipeGroupIDs.formUnion(newGroupIDs)
    }

    private func toggleGroup(_ groupID: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if expandedRecipeGroupIDs.contains(groupID) {
                expandedRecipeGroupIDs.remove(groupID)
            } else {
                expandedRecipeGroupIDs.insert(groupID)
            }
        }
    }

    private func removeRecipeGroup(_ group: RecipeGroup) {
        group.entries.forEach { shoppingListViewModel.remove($0) }
        selectedIngredientIDs.subtract(group.entries.map(\.id))
        expandedRecipeGroupIDs.remove(group.id)
        print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
    }

    private func toggleSelection(for entry: ShoppingListEntry) {
        if selectedIngredientIDs.contains(entry.id) {
            selectedIngredientIDs.remove(entry.id)
        } else {
            selectedIngredientIDs.insert(entry.id)
        }
        print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
    }

    private func deleteSelectedEntries() {
        let entriesToDelete = selectedEntries
        entriesToDelete.forEach { shoppingListViewModel.remove($0) }
        selectedIngredientIDs.removeAll()
        print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
    }

    private func moveSelectedToFridge() {
        guard !selectedIngredientIDs.isEmpty else { return }

        let entriesToMove = selectedEntries
        for entry in entriesToMove {
            if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                fridgeViewModel.add(item)
                shoppingListViewModel.remove(entry)
                print("DEBUG fridge transfer id=\(entry.id) name=\(entry.name) type=produce category=\(item.category.rawValue) result=success")
                continue
            }

            if let basic = shoppingListViewModel.resolveBasicIngredient(for: entry) {
                fridgeViewModel.add(basic)
                shoppingListViewModel.remove(entry)
                print("DEBUG fridge transfer id=\(entry.id) name=\(entry.name) type=basic category=\(basic.category.rawValue) result=success")
                continue
            }

            let customName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customName.isEmpty {
                fridgeViewModel.addCustom(name: customName, quantity: entry.quantity)
                shoppingListViewModel.remove(entry)
                print("DEBUG fridge transfer id=\(entry.id) name=\(entry.name) type=custom category=custom result=success")
            } else {
                print("DEBUG fridge transfer id=\(entry.id) name=\(entry.name) type=unknown category=unknown result=failed")
            }
        }

        selectedIngredientIDs.removeAll()
        print("DEBUG selectedIngredientIDs count: \(selectedIngredientIDs.count)")
    }

    private var inSeasonCount: Int {
        shoppingListViewModel.items.compactMap { shoppingListViewModel.resolveProduceItem(for: $0) }
            .filter { $0.seasonalityScore(month: produceViewModel.currentMonth) >= 0.55 }
            .count
    }

    private var seasonalEligibleCount: Int {
        shoppingListViewModel.items.compactMap { shoppingListViewModel.resolveProduceItem(for: $0) }.count
    }

    private var seasonalScore: Int {
        let items = shoppingListViewModel.items.compactMap { shoppingListViewModel.resolveProduceItem(for: $0) }
        guard !items.isEmpty else { return 0 }
        let totalScore = items.reduce(0.0) { partial, item in
            partial + item.seasonalityScore(month: produceViewModel.currentMonth)
        }
        let percentage = (totalScore / Double(items.count)) * 100
        return Int(percentage.rounded())
    }
}
