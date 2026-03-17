import SwiftUI

struct ContentView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
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
                    localizer: viewModel.localizer
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.settingsTab), systemImage: "gearshape.fill")
            }
        }
        .onAppear {
            selectedLanguage = viewModel.setLanguage(selectedLanguage)
        }
        .onChange(of: selectedLanguage) { _, newValue in
            selectedLanguage = viewModel.setLanguage(newValue)
        }
    }
}

#Preview {
    ContentView()
}
