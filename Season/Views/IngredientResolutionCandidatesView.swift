import SwiftUI

struct IngredientResolutionCandidatesView: View {
    @ObservedObject var viewModel: ProduceViewModel

    var body: some View {
        List {
            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No candidates available")
                        .font(.subheadline.weight(.semibold))
                    Text("Custom ingredient observation insights have not produced candidate rows yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                    candidateRow(candidate, index: index + 1)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Resolution Candidates")
    }

    private var candidates: [IngredientResolutionCandidate] {
        viewModel.topIngredientResolutionCandidates(limit: 100)
    }

    private func candidateRow(_ candidate: IngredientResolutionCandidate, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index). \(candidate.normalizedText)")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                confidenceBadge(for: candidate.confidence)
            }

            HStack(spacing: 8) {
                Label("\(candidate.occurrenceCount)", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Latest: \(candidate.latestExample)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let suggested = candidate.suggestedMatch {
                Text("Suggested match: \(suggestedMatchTitle(for: suggested))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Suggested match: none")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func suggestedMatchTitle(for match: IngredientAliasMatch) -> String {
        switch match {
        case .produce(let item):
            return "\(item.displayName(languageCode: viewModel.localizer.languageCode)) • produce"
        case .basic(let item):
            return "\(item.displayName(languageCode: viewModel.localizer.languageCode)) • basic"
        }
    }

    private func confidenceBadge(for value: Double) -> some View {
        let config = confidenceConfig(for: value)
        return Text(config.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(config.color.opacity(0.14))
            )
            .foregroundStyle(config.color)
    }

    private func confidenceConfig(for value: Double) -> (label: String, color: Color) {
        if value >= 0.85 {
            return ("High", .green)
        }
        if value >= 0.5 {
            return ("Medium", .orange)
        }
        return ("Low", .red)
    }
}

