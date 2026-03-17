import SwiftUI

struct SettingsView: View {
    @Binding var selectedLanguage: String
    @Binding var nutritionGoalsRaw: String
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

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(localizer.text(.nutritionPreferences), systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(NutritionGoal.allCases) { goal in
                        preferenceRow(for: goal)
                    }

                    Text(localizer.text(.nutritionPreferencesHint))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(localizer.text(.nutritionComparisonBasisNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(localizer.text(.settingsTab))
    }

    private func preferenceRow(for goal: NutritionGoal) -> some View {
        let isSelected = selectedGoals.contains(goal)

        return Button {
            toggle(goal)
        } label: {
            HStack {
                Text(localizer.nutritionGoalTitle(goal))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedGoals: Set<NutritionGoal> {
        Set(
            nutritionGoalsRaw
                .split(separator: ",")
                .compactMap { NutritionGoal(rawValue: String($0)) }
        )
    }

    private func toggle(_ goal: NutritionGoal) {
        var updated = selectedGoals
        if updated.contains(goal) {
            updated.remove(goal)
        } else {
            updated.insert(goal)
        }
        nutritionGoalsRaw = updated.map(\.rawValue).sorted().joined(separator: ",")
    }
}
