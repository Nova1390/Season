import SwiftUI

struct ContentView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @AppStorage("nutritionGoalsRaw") private var nutritionGoalsRaw = ""
    @StateObject private var viewModel = ProduceViewModel(languageCode: AppLanguage.english.rawValue)
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.homeTab), systemImage: "house.fill")
            }

            NavigationStack {
                SearchView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.searchTab), systemImage: "magnifyingglass")
            }

            NavigationStack {
                InSeasonTodayView(
                    viewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.todayTab), systemImage: "sun.max.fill")
            }

            NavigationStack {
                ShoppingListView(
                    produceViewModel: viewModel,
                    shoppingListViewModel: shoppingListViewModel
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.listTab), systemImage: "cart.fill")
            }

            NavigationStack {
                SettingsView(
                    selectedLanguage: $selectedLanguage,
                    nutritionGoalsRaw: $nutritionGoalsRaw,
                    localizer: viewModel.localizer
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.settingsTab), systemImage: "gearshape.fill")
            }
        }
        .onAppear {
            selectedLanguage = viewModel.setLanguage(selectedLanguage)
            nutritionGoalsRaw = viewModel.setNutritionGoalsRaw(nutritionGoalsRaw)
        }
        .onChange(of: selectedLanguage) { _, newValue in
            selectedLanguage = viewModel.setLanguage(newValue)
        }
        .onChange(of: nutritionGoalsRaw) { _, newValue in
            nutritionGoalsRaw = viewModel.setNutritionGoalsRaw(newValue)
        }
    }
}

#Preview {
    ContentView()
}
