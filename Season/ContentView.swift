import SwiftUI

struct ContentView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @StateObject private var viewModel = ProduceViewModel(languageCode: AppLanguage.english.rawValue)

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(viewModel: viewModel)
            }
            .tabItem {
                Label(viewModel.localizer.text(.homeTab), systemImage: "house")
            }

            NavigationStack {
                SearchView(viewModel: viewModel)
            }
            .tabItem {
                Label(viewModel.localizer.text(.searchTab), systemImage: "magnifyingglass")
            }

            NavigationStack {
                SettingsView(
                    selectedLanguage: $selectedLanguage,
                    localizer: viewModel.localizer
                )
            }
            .tabItem {
                Label(viewModel.localizer.text(.settingsTab), systemImage: "gearshape")
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
