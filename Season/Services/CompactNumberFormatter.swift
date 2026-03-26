import Foundation

extension Int {
    func compactFormatted() -> String {
        let sign = self < 0 ? "-" : ""
        let value = Double(self.magnitude)

        if value < 1_000 {
            return "\(sign)\(Int(value))"
        }

        if value < 1_000_000 {
            return "\(sign)\(compactComponent(value / 1_000))K"
        }

        return "\(sign)\(compactComponent(value / 1_000_000))M"
    }

    private func compactComponent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}
