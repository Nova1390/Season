import SwiftUI

struct SettingsView: View {
    @Binding var selectedLanguage: String
    let localizer: AppLocalizer

    var body: some View {
        Form {
            Section {
                Picker(localizer.text(.language), selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerLabel)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle(localizer.text(.settingsTab))
    }
}

