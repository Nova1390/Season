import SwiftUI

struct ShoppingListView: View {
    private struct RecipeGroup: Identifiable {
        let id: String
        let recipeID: String?
        let recipeTitle: String
        let entries: [ShoppingListEntry]
        let rankedRecipe: RankedRecipe?
    }

    private enum ShoppingItemVisualState {
        case missing
        case inFridge
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
                .listRowInsets(EdgeInsets(
                    top: SeasonSpacing.md,
                    leading: SeasonSpacing.md,
                    bottom: SeasonSpacing.md,
                    trailing: SeasonSpacing.md
                ))
            } else {
                shoppingHeaderSection
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: SeasonSpacing.md,
                        leading: SeasonSpacing.md,
                        bottom: SeasonSpacing.sm,
                        trailing: SeasonSpacing.md
                    ))

                shoppingSummarySection
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: SeasonSpacing.md,
                        bottom: SeasonSpacing.sm + 2,
                        trailing: SeasonSpacing.md
                    ))

                if isSelectionMode {
                    bulkActionsSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: SeasonSpacing.xs,
                            leading: SeasonSpacing.md,
                            bottom: SeasonSpacing.sm,
                            trailing: SeasonSpacing.md
                        ))
                }

                if !recipeGroups.isEmpty {
                    SeasonSectionHeader(
                        title: produceViewModel.localizer.text(.recipes),
                        trailingText: String(recipeGroups.count)
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: SeasonSpacing.xs,
                            leading: SeasonSpacing.md,
                            bottom: SeasonSpacing.xs,
                            trailing: SeasonSpacing.md
                        ))

                    ForEach(recipeGroups) { group in
                        recipeGroupCard(group)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: SeasonSpacing.md,
                                bottom: SeasonSpacing.xs,
                                trailing: SeasonSpacing.md
                            ))

                        if expandedRecipeGroupIDs.contains(group.id) {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                childIngredientRow(
                                    entry,
                                    isLast: index == group.entries.count - 1
                                )
                                .padding(.leading, SeasonSpacing.md + 2)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(
                                    top: 0,
                                    leading: SeasonSpacing.md,
                                    bottom: 0,
                                    trailing: SeasonSpacing.md
                                ))
                            }
                        }
                    }
                }

                if !manualEntries.isEmpty {
                    SeasonSectionHeader(
                        title: produceViewModel.localizer.text(.addedManually),
                        trailingText: String(manualEntries.count)
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: SeasonSpacing.md,
                            leading: SeasonSpacing.md,
                            bottom: SeasonSpacing.xs,
                            trailing: SeasonSpacing.md
                        ))

                    ForEach(manualEntries) { entry in
                        manualItemRow(entry)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: SeasonSpacing.md,
                                bottom: 0,
                                trailing: SeasonSpacing.md
                            ))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SeasonColors.primarySurface.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: SeasonLayout.bottomBarContentClearance)
        }
        .navigationTitle(produceViewModel.localizer.text(.listTab))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelectionMode ? produceViewModel.localizer.text(.done) : produceViewModel.localizer.text(.select)) {
                    if isSelectionMode {
                        selectedIngredientIDs.removeAll()
                    }
                    isSelectionMode.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelectionMode ? Color.accentColor : .primary)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .buttonStyle(.plain)
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
        }
    }

    private var shoppingHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shopping List")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.27))

            Text(shoppingHeaderSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var shoppingSummarySection: some View {
        SeasonCardContainer(
            content: {
                HStack(spacing: SeasonSpacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Items")
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.27).opacity(0.72))
                        Text(String(format: "%02d", totalItemCount))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.27))
                        Text(produceViewModel.localizer.itemsInSeasonText(inSeasonCount: inSeasonCount, totalCount: seasonalEligibleCount))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: SeasonSpacing.sm)

                    VStack(alignment: .trailing, spacing: 12) {
                        summaryMetricColumn(title: "Recipes", value: "\(recipeGroupCount)")
                        summaryMetricColumn(title: "Manual", value: "\(manualItemCount)")
                        HStack(spacing: 5) {
                            Image(systemName: "leaf.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.green.opacity(0.82))
                            Text("\(seasonalScore)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(SeasonSpacing.md)
            },
            cornerRadius: SeasonRadius.large,
            background: SeasonColors.secondarySurface,
            backgroundOpacity: 0.94,
            borderOpacity: 0.01,
            shadowOpacity: 0.002,
            shadowRadius: 1.8,
            shadowY: 1
        )
    }

    private var bulkActionsSection: some View {
        SeasonCardContainer(
            content: {
                VStack(alignment: .leading, spacing: SeasonSpacing.sm + 2) {
                    Text(String(format: produceViewModel.localizer.text(.selectionSummaryFormat), selectedIngredientIDs.count))
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Button(produceViewModel.localizer.text(.selectAll)) {
                            selectedIngredientIDs = Set(shoppingListViewModel.items.map(\.id))
                        }
                        .buttonStyle(SeasonSecondaryButtonStyle())

                        Button(produceViewModel.localizer.text(.clearSelection)) {
                            selectedIngredientIDs.removeAll()
                        }
                        .buttonStyle(SeasonSecondaryButtonStyle())
                    }

                    HStack(spacing: 8) {
                        Button(role: .destructive) {
                            deleteSelectedEntries()
                        } label: {
                            Text(produceViewModel.localizer.text(.deleteSelected))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SeasonDestructiveButtonStyle())
                        .disabled(selectedIngredientIDs.isEmpty)

                        Button {
                            moveSelectedToFridge()
                        } label: {
                            Text(produceViewModel.localizer.text(.moveToFridge))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SeasonPrimaryButtonStyle())
                        .disabled(selectedIngredientIDs.isEmpty)
                    }
                }
                .padding(SeasonSpacing.md + 2)
            },
            cornerRadius: SeasonRadius.large,
            background: Color(.systemBackground),
            backgroundOpacity: 0.9,
            borderOpacity: 0.02,
            shadowOpacity: 0.003,
            shadowRadius: 2,
            shadowY: 1
        )
    }

    @ViewBuilder
    private func recipeGroupCard(_ group: RecipeGroup) -> some View {
        let isExpanded = expandedRecipeGroupIDs.contains(group.id)
        let seasonalMatchPercent = seasonalMatchPercent(for: group)
        let seasonalStatus = recipeSeasonalStatusText(for: seasonalMatchPercent)

        VStack(alignment: .leading, spacing: SeasonSpacing.sm) {
            HStack(alignment: .top, spacing: SeasonSpacing.sm) {
                Rectangle()
                    .fill(Color(red: 0.32, green: 0.39, blue: 0.28).opacity(0.88))
                    .frame(width: 3, height: 42)
                    .clipShape(Capsule(style: .continuous))
                    .padding(.top, 2)

                Button {
                    toggleGroup(group.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        recipeGroupThumbnail(for: group)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(forRecipeLabel)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.7)
                                .foregroundStyle(.secondary)

                            Text(group.recipeTitle)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(alignment: .center, spacing: 6) {
                                SeasonBadge(
                                    text: seasonalStatus,
                                    horizontalPadding: 8,
                                    verticalPadding: 4,
                                    foreground: Color.primary.opacity(0.68),
                                    background: SeasonColors.subtleSurface.opacity(0.9)
                                )
                                Text("\(produceViewModel.localizer.text(.seasonalMatch)) \(seasonalMatchPercent)%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(alignment: .center, spacing: 6) {
                    Button {
                        toggleGroup(group.id)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary.opacity(0.62))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 26, height: 26)

                    if let ranked = group.rankedRecipe {
                        NavigationLink {
                            RecipeDetailView(
                                rankedRecipe: ranked,
                                viewModel: produceViewModel,
                                shoppingListViewModel: shoppingListViewModel
                            )
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary.opacity(0.58))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 26, height: 26)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, SeasonSpacing.sm)
            .padding(.vertical, 4)

        }
        .padding(.vertical, SeasonSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous)
                .fill(SeasonColors.secondarySurface.opacity(0.8))
        )
        .clipShape(RoundedRectangle(cornerRadius: SeasonRadius.large, style: .continuous))
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
        let produceItem = shoppingListViewModel.resolveProduceItem(for: entry)
        let visualState = visualState(for: entry)
        let stateStyle = style(for: visualState)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: SeasonSpacing.sm) {
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

                if let item = produceItem {
                    ProduceThumbnailView(item: item, size: 34)
                } else if shoppingListViewModel.resolveBasicIngredient(for: entry) != nil {
                    Image(systemName: "leaf")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SeasonColors.subtleSurface.opacity(0.7))
                        )
                } else {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SeasonColors.subtleSurface.opacity(0.7))
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(childDisplayName(for: entry))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(stateStyle.titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)

                    HStack(alignment: .center, spacing: 6) {
                        if let quantity = entry.quantity {
                            Text(quantity)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let item = produceItem {
                            Text(ingredientSeasonalImpactText(for: item))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary.opacity(0.82))

                            SeasonalStatusBadge(
                                score: item.seasonalityScore(month: produceViewModel.currentMonth),
                                delta: item.seasonalityDelta(month: produceViewModel.currentMonth),
                                localizer: produceViewModel.localizer
                            )
                            .scaleEffect(0.82, anchor: .leading)
                            .opacity(visualState == .inFridge ? 0.58 : 0.74)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                statusBadge(for: visualState)
            }
            .padding(.vertical, SeasonSpacing.sm + 2)
            .padding(.horizontal, SeasonSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
                    .fill(stateStyle.background)
            )
            .opacity(visualState == .inFridge ? 0.78 : 1)

            if !isLast {
                Color.clear.frame(height: 6)
            }
        }
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
        let produceItem = shoppingListViewModel.resolveProduceItem(for: entry)
        let visualState = visualState(for: entry)
        let stateStyle = style(for: visualState)

        HStack(alignment: .center, spacing: SeasonSpacing.sm) {
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

            if let item = produceItem {
                ProduceThumbnailView(item: item, size: 36)
            } else if shoppingListViewModel.resolveBasicIngredient(for: entry) != nil {
                Image(systemName: "leaf")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SeasonColors.subtleSurface.opacity(0.7))
                    )
            } else {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SeasonColors.subtleSurface.opacity(0.7))
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(childDisplayName(for: entry))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stateStyle.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)

                if let quantity = entry.quantity {
                    Text(quantity)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if let item = produceItem {
                    SeasonalStatusBadge(
                        score: item.seasonalityScore(month: produceViewModel.currentMonth),
                        delta: item.seasonalityDelta(month: produceViewModel.currentMonth),
                        localizer: produceViewModel.localizer
                    )
                    .scaleEffect(0.9)
                    .opacity(visualState == .inFridge ? 0.62 : 0.86)
                }
                statusBadge(for: visualState)
            }
        }
        .padding(.horizontal, SeasonSpacing.sm)
        .padding(.vertical, SeasonSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: SeasonRadius.medium, style: .continuous)
                .fill(stateStyle.background)
        )
        .opacity(visualState == .inFridge ? 0.78 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                shoppingListViewModel.remove(entry)
            } label: {
                Label(produceViewModel.localizer.text(.remove), systemImage: "trash")
            }
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

    @ViewBuilder
    private func recipeGroupThumbnail(for group: RecipeGroup) -> some View {
        if let recipe = group.rankedRecipe?.recipe {
            RecipeThumbnailView(recipe: recipe, size: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SeasonColors.subtleSurface.opacity(0.9))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var shoppingHeaderSummary: String {
        let isItalian = produceViewModel.languageCode.hasPrefix("it")
        if isItalian {
            return "\(totalItemCount) ingredienti in \(recipeGroupCount) ricette"
        }
        return "\(totalItemCount) items across \(recipeGroupCount) recipes"
    }

    private var totalItemCount: Int {
        shoppingListViewModel.items.count
    }

    private var recipeGroupCount: Int {
        recipeGroups.count
    }

    private var manualItemCount: Int {
        manualEntries.count
    }

    private var forRecipeLabel: String {
        produceViewModel.languageCode.hasPrefix("it") ? "Per" : "For"
    }

    private func summaryMetricColumn(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.27).opacity(0.72))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.27))
        }
    }

    private func visualState(for entry: ShoppingListEntry) -> ShoppingItemVisualState {
        if let produce = shoppingListViewModel.resolveProduceItem(for: entry),
           fridgeViewModel.contains(produce) {
            return .inFridge
        }

        if let basic = shoppingListViewModel.resolveBasicIngredient(for: entry),
           fridgeViewModel.contains(basic) {
            return .inFridge
        }

        if entry.produceID == nil,
           entry.basicIngredientID == nil,
           fridgeViewModel.containsCustom(named: entry.name) {
            return .inFridge
        }

        return .missing
    }

    private func statusBadge(for state: ShoppingItemVisualState) -> some View {
        Group {
            switch state {
            case .missing:
                SeasonBadge(
                    text: produceViewModel.languageCode.hasPrefix("it") ? "Manca" : "Missing",
                    semantic: .warning,
                    horizontalPadding: 8,
                    verticalPadding: 4
                )
            case .inFridge:
                SeasonBadge(
                    text: produceViewModel.languageCode.hasPrefix("it") ? "In frigo" : "In fridge",
                    icon: "snowflake",
                    semantic: .positive,
                    horizontalPadding: 8,
                    verticalPadding: 4
                )
            }
        }
    }

    private func style(for state: ShoppingItemVisualState) -> (background: Color, titleColor: Color) {
        switch state {
        case .missing:
            return (SeasonColors.subtleSurface.opacity(0.8), .primary)
        case .inFridge:
            return (SeasonColors.seasonGreenSoft.opacity(0.35), Color.primary.opacity(0.84))
        }
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
        .sorted { lhs, rhs in
            let leftScore = seasonalMatchPercent(for: lhs)
            let rightScore = seasonalMatchPercent(for: rhs)
            if leftScore != rightScore { return leftScore > rightScore }
            return lhs.recipeTitle.localizedCaseInsensitiveCompare(rhs.recipeTitle) == .orderedAscending
        }
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
    }

    private func toggleSelection(for entry: ShoppingListEntry) {
        if selectedIngredientIDs.contains(entry.id) {
            selectedIngredientIDs.remove(entry.id)
        } else {
            selectedIngredientIDs.insert(entry.id)
        }
    }

    private func deleteSelectedEntries() {
        let entriesToDelete = selectedEntries
        entriesToDelete.forEach { shoppingListViewModel.remove($0) }
        selectedIngredientIDs.removeAll()
    }

    private func moveSelectedToFridge() {
        guard !selectedIngredientIDs.isEmpty else { return }

        let entriesToMove = selectedEntries
        for entry in entriesToMove {
            if let item = shoppingListViewModel.resolveProduceItem(for: entry) {
                fridgeViewModel.add(item)
                shoppingListViewModel.remove(entry)
                continue
            }

            if let basic = shoppingListViewModel.resolveBasicIngredient(for: entry) {
                fridgeViewModel.add(basic)
                shoppingListViewModel.remove(entry)
                continue
            }

            let customName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customName.isEmpty {
                fridgeViewModel.addCustom(name: customName, quantity: entry.quantity)
                shoppingListViewModel.remove(entry)
            }
        }

        selectedIngredientIDs.removeAll()
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

    private func recipeSeasonalStatusText(for seasonalMatchPercent: Int) -> String {
        if seasonalMatchPercent >= 80 { return produceViewModel.localizer.text(.inSeason) }
        if seasonalMatchPercent >= 50 { return produceViewModel.localizer.recipeTimingTitle(.goodNow) }
        return produceViewModel.localizer.text(.seasonOutOfSeason)
    }

    private func seasonalMatchPercent(for group: RecipeGroup) -> Int {
        if let ranked = group.rankedRecipe {
            return ranked.seasonalMatchPercent
        }

        let scores = group.entries.compactMap { entry in
            shoppingListViewModel.resolveProduceItem(for: entry)?.seasonalityScore(month: produceViewModel.currentMonth)
        }
        guard !scores.isEmpty else { return 0 }
        let average = scores.reduce(0, +) / Double(scores.count)
        return Int((average * 100).rounded())
    }

    private func ingredientSeasonalImpactText(for item: ProduceItem) -> String {
        let score = item.seasonalityScore(month: produceViewModel.currentMonth)
        if score >= 0.78 { return produceViewModel.localizer.text(.seasonPeakNow) }
        if score >= 0.45 { return produceViewModel.localizer.text(.inSeason) }
        return produceViewModel.localizer.text(.seasonOutOfSeason)
    }
}
