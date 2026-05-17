import SwiftUI

struct NotificationsView: View {
    @ObservedObject var produceViewModel: ProduceViewModel
    @ObservedObject var fridgeViewModel: FridgeViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    @AppStorage(SeasonNotificationReadStore.readIDsStorageKey) private var readIDsRaw = ""

    private var notifications: [SeasonInboxNotification] {
        SeasonNotificationCenter.notifications(
            produceViewModel: produceViewModel,
            fridgeViewModel: fridgeViewModel,
            shoppingListViewModel: shoppingListViewModel
        )
    }

    private var readIDs: Set<String> {
        SeasonNotificationReadStore.readIDs(from: readIDsRaw)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header

                if notifications.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(notifications) { notification in
                            notificationLink(notification)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, SeasonLayout.bottomBarContentClearance + DS.Spacing.xl)
        }
        .background(DS.Color.bg)
        .seasonTopBar(
            produceViewModel: produceViewModel,
            shoppingListViewModel: shoppingListViewModel,
            leading: .back,
            showsNotificationsButton: false
        )
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: SeasonLayout.bottomBarContentClearance)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(produceViewModel.localizer.localized("notifications.title"))
                    .font(DS.Font.serif(36, weight: .medium))
                    .foregroundStyle(DS.Color.ink)

                Spacer()

                if !notifications.isEmpty {
                    Button(produceViewModel.localizer.localized("notifications.mark_all_read")) {
                        markAllRead()
                    }
                    .font(DS.Font.sans(12, weight: .bold))
                    .foregroundStyle(DS.Color.sage)
                    .buttonStyle(.plain)
                }
            }

            Text(produceViewModel.localizer.localized("notifications.subtitle"))
                .font(DS.Font.sans(15))
                .foregroundStyle(DS.Color.inkMuted)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DS.Color.sage)

            Text(produceViewModel.localizer.localized("notifications.empty_title"))
                .font(DS.Font.serif(24, weight: .medium))
                .foregroundStyle(DS.Color.ink)

            Text(produceViewModel.localizer.localized("notifications.empty_body"))
                .font(DS.Font.sans(14))
                .foregroundStyle(DS.Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DS.Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func notificationLink(_ notification: SeasonInboxNotification) -> some View {
        NavigationLink {
            destination(for: notification)
        } label: {
            notificationRow(notification)
        }
        .simultaneousGesture(TapGesture().onEnded {
            markRead(notification)
        })
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(for notification: SeasonInboxNotification) -> some View {
        switch notification.destination {
        case .today:
            InSeasonTodayView(
                viewModel: produceViewModel,
                shoppingListViewModel: shoppingListViewModel
            )
            .environmentObject(fridgeViewModel)
        case .fridge:
            FridgeView(
                produceViewModel: produceViewModel,
                fridgeViewModel: fridgeViewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        case .shoppingList:
            ShoppingListView(
                produceViewModel: produceViewModel,
                shoppingListViewModel: shoppingListViewModel
            )
        }
    }

    private func notificationRow(_ notification: SeasonInboxNotification) -> some View {
        let isUnread = !readIDs.contains(notification.id)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground(for: notification.kind))
                    .frame(width: 44, height: 44)

                Image(systemName: notification.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconForeground(for: notification.kind))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(DS.Font.sans(16, weight: .bold))
                        .foregroundStyle(DS.Color.ink)

                    if isUnread {
                        Circle()
                            .fill(DS.Color.terracotta)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }

                Text(notification.body)
                    .font(DS.Font.sans(13))
                    .foregroundStyle(DS.Color.inkMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Color.inkFaint)
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isUnread ? DS.Color.card : DS.Color.cardSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isUnread ? DS.Color.borderM : DS.Color.border, lineWidth: 1)
        )
    }

    private func iconBackground(for kind: SeasonNotificationKind) -> Color {
        switch kind {
        case .seasonalPeak:
            return DS.Color.Reason.peakBg
        case .fridgeSetup:
            return DS.Color.Reason.fridgeBg
        case .shoppingList:
            return DS.Color.ochreSoft
        }
    }

    private func iconForeground(for kind: SeasonNotificationKind) -> Color {
        switch kind {
        case .seasonalPeak:
            return DS.Color.Reason.peakFg
        case .fridgeSetup:
            return DS.Color.Reason.fridgeFg
        case .shoppingList:
            return DS.Color.ochre
        }
    }

    private func markRead(_ notification: SeasonInboxNotification) {
        var ids = readIDs
        ids.insert(notification.id)
        readIDsRaw = SeasonNotificationReadStore.rawValue(from: ids)
    }

    private func markAllRead() {
        var ids = readIDs
        ids.formUnion(notifications.map(\.id))
        readIDsRaw = SeasonNotificationReadStore.rawValue(from: ids)
    }
}
