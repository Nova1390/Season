import Foundation

struct UserBadge: Identifiable, Hashable {
    enum Kind: String, CaseIterable {
        case seasonStarter
        case freshCook
        case crispyCreator
        case topSeasonal
        case glutenFreeMaster
        case vegetarianMaster
        case veganMaster

        var symbol: String {
            switch self {
            case .seasonStarter:
                return "sprout"
            case .freshCook:
                return "leaf"
            case .crispyCreator:
                return "flame"
            case .topSeasonal:
                return "crown"
            case .glutenFreeMaster:
                return "checkmark.seal"
            case .vegetarianMaster:
                return "leaf.circle"
            case .veganMaster:
                return "leaf.fill"
            }
        }
    }

    let kind: Kind

    var id: String { kind.rawValue }
    var symbol: String { kind.symbol }
}
