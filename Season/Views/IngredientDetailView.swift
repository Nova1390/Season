import SwiftUI

struct IngredientDetailView: View {
    let ingredient: IngredientReference

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ingredient.name)
                .font(.largeTitle.weight(.semibold))

            Text(typeLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let produceID = ingredient.produceID,
               !produceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("produceID: \(produceID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Ingredient")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typeLabel: String {
        switch ingredient.type {
        case .produce:
            return "produce"
        case .basic:
            return "basic"
        case .custom:
            return "custom"
        }
    }
}
