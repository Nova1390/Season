import Foundation

func followerCount(for creatorID: String) -> Int {
    let cleaned = creatorID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let seed = cleaned.isEmpty ? "season-default-creator" : cleaned
    let hash = deterministicHash(seed)
    let normalized = Double(hash % 10_000) / 9_999.0
    // Bias toward smaller values while keeping occasional larger counts.
    let skewed = pow(normalized, 2.3)
    let minCount = 12
    let maxCount = 1_200
    return minCount + Int(skewed * Double(maxCount - minCount))
}

func formattedFollowerCount(_ count: Int) -> String {
    max(0, count).compactFormatted()
}

func followerCount(for creatorID: String?, fallbackName: String) -> Int {
    let idSeed = creatorID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !idSeed.isEmpty {
        return followerCount(for: idSeed)
    }
    return followerCount(for: fallbackName)
}

private func deterministicHash(_ value: String) -> UInt64 {
    let prime: UInt64 = 1_099_511_628_211
    var hash: UInt64 = 14_695_981_039_346_656_037
    for scalar in value.unicodeScalars {
        hash ^= UInt64(scalar.value)
        hash = hash &* prime
    }
    return hash
}
