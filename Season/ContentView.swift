import SwiftUI
import UIKit

struct ContentView: View {
    private enum MainTab: Int {
        case home
        case search
        case today
        case account
    }

    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @AppStorage("nutritionGoalsRaw") private var nutritionGoalsRaw = ""
    @StateObject private var viewModel = ProduceViewModel(languageCode: AppLanguage.english.rawValue)
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var fridgeViewModel = FridgeViewModel()
    @State private var selectedTab: MainTab = .home
    @State private var showingCreateRecipe = false
    @State private var homeRootResetID = UUID()
    @State private var outboxDispatcher = OutboxDispatcher()
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
            .id(homeRootResetID)
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
            .tag(MainTab.today)
            .tabItem {
                Label(viewModel.localizer.text(.todayTab), systemImage: "sun.max.fill")
            }

            NavigationStack {
                AccountView(
                    selectedLanguage: $selectedLanguage,
                    nutritionGoalsRaw: $nutritionGoalsRaw,
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .tag(MainTab.account)
            .tabItem {
                Label(viewModel.localizer.text(.accountTab), systemImage: "person.crop.circle.fill")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.35))
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    tabBarButton(
                        tab: .home,
                        title: viewModel.localizer.text(.homeTab),
                        imageName: "house.fill"
                    )

                    tabBarButton(
                        tab: .search,
                        title: viewModel.localizer.text(.searchTab),
                        imageName: "magnifyingglass"
                    )

                    Button {
                        showingCreateRecipe = true
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(Color(.tertiarySystemFill))
                                )
                            Text(viewModel.localizer.text(.createTab))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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
                        title: viewModel.localizer.text(.accountTab),
                        imageName: "person.crop.circle.fill"
                    )
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
            .background(Color(.secondarySystemBackground))
        }
        .fullScreenCover(isPresented: $showingCreateRecipe) {
            CreateRecipeView(viewModel: viewModel)
        }
        .onAppear {
            selectedLanguage = viewModel.setLanguage(selectedLanguage)
            nutritionGoalsRaw = viewModel.setNutritionGoalsRaw(nutritionGoalsRaw)
            print("[SEASON_SUPABASE] phase=dispatcher_triggered source=app_launch")
            Task {
                await outboxDispatcher.processPendingMutations()
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
        .environmentObject(fridgeViewModel)
    }

    private func tabBarButton(tab: MainTab, title: String, imageName: String) -> some View {
        let isActive = selectedTab == tab

        return Button {
            if tab == .home {
                homeRootResetID = UUID()
            }
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: imageName)
                    .font(.system(size: 18, weight: isActive ? .bold : .semibold))
                Text(title)
                    .font(.caption2.weight(isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
