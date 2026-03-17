import SwiftUI

struct SettingsView: View {
    @Binding var selectedLanguage: String
    let localizer: AppLocalizer

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(localizer.text(.language), systemImage: "globe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker(localizer.text(.language), selection: $selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.pickerLabel)
                                .tag(language.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(localizer.text(.settingsTab))
    }
}
