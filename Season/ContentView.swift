import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var systemImageName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

struct ContentView: View {
    private enum MainTab: Int {
        case home
        case search
        case today
        case account
    }

    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @AppStorage("nutritionGoalsRaw") private var nutritionGoalsRaw = ""
    @AppStorage("appAppearanceRaw") private var appAppearanceRaw = AppAppearance.system.rawValue
    @StateObject private var viewModel = ProduceViewModel(languageCode: AppLanguage.english.rawValue)
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var fridgeViewModel = FridgeViewModel()
    @State private var selectedTab: MainTab = .home
    @State private var homeNavigationResetID = UUID()
    @State private var searchNavigationResetID = UUID()
    @State private var todayNavigationResetID = UUID()
    @State private var accountNavigationResetID = UUID()
    @State private var showingCreateRecipe = false
    @State private var activeDraftRecipeID: String?
    @State private var outboxDispatcher = OutboxDispatcher()
    @StateObject private var syncFeedback = SyncFeedbackCenter.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .id(homeNavigationResetID)
            .tag(MainTab.home)
            .tabItem {
                Label(viewModel.localizer.text(.homeTab), systemImage: "house.fill")
            }

            NavigationStack {
                SearchView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .id(searchNavigationResetID)
            .tag(MainTab.search)
            .tabItem {
                Label(viewModel.localizer.text(.searchTab), systemImage: "magnifyingglass")
            }

            NavigationStack {
                InSeasonTodayView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .id(todayNavigationResetID)
            .tag(MainTab.today)
            .tabItem {
                Label(viewModel.localizer.text(.todayTab), systemImage: "sun.max.fill")
            }

            NavigationStack {
                AccountView(
                    selectedLanguage: $selectedLanguage,
                    nutritionGoalsRaw: $nutritionGoalsRaw,
                    appAppearanceRaw: $appAppearanceRaw,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .id(accountNavigationResetID)
            .tag(MainTab.account)
            .tabItem {
                Label(viewModel.localizer.text(.accountTab), systemImage: "person.crop.circle.fill")
            }
        }
        .overlay(alignment: .top) {
            if syncFeedback.isVisible, let message = syncFeedback.message {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                    tabBarButton(
                        tab: .home,
                        title: viewModel.localizer.text(.homeTab),
                        imageName: "house.fill"
                    )

                    tabBarButton(
                        tab: .search,
                        title: bottomBarDiscoverTitle,
                        imageName: "magnifyingglass"
                    )

                    Button {
                        // Avoid mutating recipe/feed state before navigation.
                        // CreateRecipeView will initialize draft state when presented.
                        activeDraftRecipeID = nil
                        showingCreateRecipe = true
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [DS.Color.sage, DS.Color.sageDeep],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: DS.Color.sageDeep.opacity(0.28), radius: 12, x: 0, y: 6)
                                )
                                .offset(y: -6)
                            Text(viewModel.localizer.text(.createTab))
                                .font(DS.Font.sans(10, weight: .semibold))
                                .foregroundStyle(DS.Color.sageDeep)
                                .offset(y: -6)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    tabBarButton(
                        tab: .today,
                        title: viewModel.localizer.text(.todayTab),
                        imageName: "sun.max.fill"
                    )

                    tabBarButton(
                        tab: .account,
                        title: bottomBarProfileTitle,
                        imageName: "person.crop.circle.fill"
                    )
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .background(tabBarSurfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tabBarBorderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showingCreateRecipe, onDismiss: {
            activeDraftRecipeID = nil
        }) {
            CreateRecipeView(
                viewModel: viewModel,
                shoppingListViewModel: shoppingListViewModel,
                initialDraftRecipeID: activeDraftRecipeID,
                enableDraftMode: true
            )
        }
        .onAppear {
            selectedLanguage = viewModel.setLanguage(selectedLanguage)
            nutritionGoalsRaw = viewModel.setNutritionGoalsRaw(nutritionGoalsRaw)
            print("[SEASON_SUPABASE] phase=dispatcher_triggered source=app_launch")
            Task {
                await outboxDispatcher.processPendingMutations()
            }
            Task {
                print("[SEASON_SUPABASE] phase=follow_sync_triggered source=app_launch")
                await FollowSyncManager.shared.syncFromBackend()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            print("[SEASON_SUPABASE] phase=dispatcher_triggered source=app_foreground")
            Task {
                await outboxDispatcher.processPendingMutations()
            }
        }
        .onChange(of: selectedLanguage) { _, newValue in
            selectedLanguage = viewModel.setLanguage(newValue)
        }
        .onChange(of: nutritionGoalsRaw) { _, newValue in
            nutritionGoalsRaw = viewModel.setNutritionGoalsRaw(newValue)
        }
        .preferredColorScheme(appAppearance.colorScheme)
        .environmentObject(fridgeViewModel)
        .animation(.easeInOut(duration: 0.2), value: syncFeedback.isVisible)
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    private var bottomBarDiscoverTitle: String {
        viewModel.languageCode == AppLanguage.italian.rawValue ? "Scopri" : "Discover"
    }

    private var bottomBarProfileTitle: String {
        viewModel.languageCode == AppLanguage.italian.rawValue ? "Io" : "Me"
    }

    private var tabBarBorderColor: Color {
        colorScheme == .dark ? DS.Color.borderS : Color.white.opacity(0.75)
    }

    private var activeTabBackgroundColor: Color {
        colorScheme == .dark ? DS.Color.sageSoft.opacity(0.72) : Color.white.opacity(0.38)
    }

    private var tabBarSurfaceColor: Color {
        colorScheme == .dark ? DS.Color.card.opacity(0.86) : Color.white.opacity(0.36)
    }

    private func tabBarButton(tab: MainTab, title: String, imageName: String) -> some View {
        let isActive = selectedTab == tab

        return Button {
            if selectedTab == tab {
                resetNavigation(for: tab)
            } else {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: imageName)
                    .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(DS.Font.sans(10, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? DS.Color.ink : DS.Color.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? activeTabBackgroundColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resetNavigation(for tab: MainTab) {
        switch tab {
        case .home:
            homeNavigationResetID = UUID()
        case .search:
            searchNavigationResetID = UUID()
        case .today:
            todayNavigationResetID = UUID()
        case .account:
            accountNavigationResetID = UUID()
        }
    }
}

#Preview {
    ContentView()
}
