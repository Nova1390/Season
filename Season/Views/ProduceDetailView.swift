import SwiftUI

struct ProduceDetailView: View {
    let item: ProduceItem
    let viewModel: ProduceViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ProduceHeroImageView(item: item, height: 214)

                SeasonCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.displayName(languageCode: viewModel.localizer.languageCode))
                            .font(.title3.weight(.semibold))

                        HStack {
                            Text(viewModel.localizer.text(.seasonalStatus))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            SeasonalStatusBadge(
                                isInSeason: item.isInSeason(month: viewModel.currentMonth),
                                localizer: viewModel.localizer
                            )
                        }
                    }
                }

                SeasonCard {
                    HStack(spacing: 14) {
                        CategoryIconView(category: item.category, size: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.localizer.text(.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.localizer.categoryTitle(for: item.category))
                                .font(.body.weight(.medium))
                        }
                        Spacer()
                    }
                }

                SeasonCard {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.localizer.text(.seasonMonths))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.monthNames(for: item.seasonMonths))
                                .font(.body.weight(.medium))
                        }
                        Spacer()
                    }
                }

                SeasonCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.localizer.text(.seasonalityChart))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        StylizedSeasonalityChart(
                            inSeasonMonths: item.seasonMonths,
                            currentMonth: viewModel.currentMonth,
                            languageCode: viewModel.languageCode
                        )
                    }
                }

                if let nutrition = item.nutrition {
                    SeasonCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.localizer.text(.nutrition))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            nutritionRow(
                                title: viewModel.localizer.text(.calories),
                                value: "\(nutrition.calories) kcal"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.protein),
                                value: "\(formatted(nutrition.protein)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.carbs),
                                value: "\(formatted(nutrition.carbs)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.fat),
                                value: "\(formatted(nutrition.fat)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.fiber),
                                value: "\(formatted(nutrition.fiber)) g"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.vitaminC),
                                value: "\(formatted(nutrition.vitaminC)) mg"
                            )
                            nutritionRow(
                                title: viewModel.localizer.text(.potassium),
                                value: "\(formatted(nutrition.potassium)) mg"
                            )
                        }
                    }
                }

                Button {
                    shoppingListViewModel.add(item)
                } label: {
                    HStack {
                        Image(systemName: shoppingListViewModel.contains(item) ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(shoppingListViewModel.contains(item) ? .gray : .accentColor)
                .disabled(shoppingListViewModel.contains(item))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.displayName(languageCode: viewModel.localizer.languageCode))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var buttonTitle: String {
        if shoppingListViewModel.contains(item) {
            return viewModel.localizer.text(.alreadyInList)
        } else {
            return viewModel.localizer.text(.addToList)
        }
    }

    @ViewBuilder
    private func nutritionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

}

private struct StylizedSeasonalityChart: View {
    let inSeasonMonths: [Int]
    let currentMonth: Int
    let languageCode: String

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let values = monthValues
                let points = chartPoints(size: geometry.size, values: values)
                let currentIndex = max(0, min(11, currentMonth - 1))
                let currentPoint = points[currentIndex]
                let midY = geometry.size.height / 2

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))

                    Rectangle()
                        .fill(Color.green.opacity(0.06))
                        .frame(height: midY)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                    }
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Path { path in
                        path.move(to: CGPoint(x: currentPoint.x, y: 0))
                        path.addLine(to: CGPoint(x: currentPoint.x, y: geometry.size.height))
                    }
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.2)

                    seasonCurve(points: points)
                        .stroke(Color.green.opacity(0.9), lineWidth: 2.5)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .position(currentPoint)
                }
            }
            .frame(height: 150)

            HStack(spacing: 0) {
                ForEach(Array(monthSymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var monthValues: [CGFloat] {
        (1...12).map { inSeasonMonths.contains($0) ? 1 : -1 }
    }

    // This is a stylized seasonality line for readability.
    // The app only stores month-level in/out of season states, not continuous measurements.
    private func seasonCurve(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let midX = (previous.x + current.x) / 2

                path.addQuadCurve(
                    to: CGPoint(x: midX, y: (previous.y + current.y) / 2),
                    control: CGPoint(x: previous.x, y: previous.y)
                )
                path.addQuadCurve(
                    to: current,
                    control: CGPoint(x: midX, y: current.y)
                )
            }
        }
    }

    private func chartPoints(size: CGSize, values: [CGFloat]) -> [CGPoint] {
        let leftPadding: CGFloat = 10
        let rightPadding: CGFloat = 10
        let topPadding: CGFloat = 14
        let bottomPadding: CGFloat = 14
        let width = size.width - leftPadding - rightPadding
        let height = size.height - topPadding - bottomPadding
        let centerY = topPadding + (height / 2)
        let amplitude = height * 0.35
        let stepX = width / 11

        return values.enumerated().map { index, value in
            CGPoint(
                x: leftPadding + (CGFloat(index) * stepX),
                y: centerY - (value * amplitude)
            )
        }
    }

    private var monthSymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        return formatter.shortMonthSymbols ?? []
    }
}
