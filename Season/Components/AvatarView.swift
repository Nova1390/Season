import SwiftUI

struct AvatarView: View {
    let avatarURL: String?
    let size: CGFloat
    let creatorID: String?
    let displayName: String?

    private enum URLResolution {
        case valid(URL)
        case missing
        case invalid
    }

    var body: some View {
        Group {
            switch resolvedURL {
            case .valid(let remoteURL):
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .onAppear {
                                print("[SEASON_AVATAR] phase=remote_used creator_id=\(creatorLogID) url=\(remoteURL.absoluteString)")
                            }
                    case .failure:
                        fallbackAvatar(reason: "failed")
                    case .empty:
                        fallbackAvatar(reason: "loading")
                    @unknown default:
                        fallbackAvatar(reason: "failed")
                    }
                }
            case .missing:
                fallbackAvatar(reason: "missing")
            case .invalid:
                fallbackAvatar(reason: "invalid")
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            print("[SEASON_AVATAR] phase=render_attempt creator_id=\(creatorLogID)")
        }
    }

    private var resolvedURL: URLResolution {
        let trimmed = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return .missing }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return .invalid
        }
        return .valid(url)
    }

    private var creatorLogID: String {
        let trimmed = creatorID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    private var trimmedDisplayName: String {
        displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var avatarSeed: String {
        let trimmedID = creatorID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedID.isEmpty {
            return trimmedID.lowercased()
        }
        if !trimmedDisplayName.isEmpty {
            return trimmedDisplayName.lowercased()
        }
        return "season-avatar-fallback"
    }

    private var initials: String {
        let source = trimmedDisplayName
        if !source.isEmpty {
            let components = source
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
                .map(String.init)
            if components.count >= 2 {
                let first = components[0].prefix(1)
                let second = components[1].prefix(1)
                return (first + second).uppercased()
            }
            if let first = components.first {
                return String(first.prefix(2)).uppercased()
            }
        }

        let fallback = avatarSeed.filter { $0.isLetter || $0.isNumber }
        if fallback.isEmpty { return "SE" }
        return String(fallback.prefix(2)).uppercased()
    }

    private var fallbackGradient: LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.95, green: 0.88, blue: 0.80), Color(red: 0.88, green: 0.79, blue: 0.71)],
            [Color(red: 0.88, green: 0.91, blue: 0.83), Color(red: 0.78, green: 0.84, blue: 0.73)],
            [Color(red: 0.86, green: 0.90, blue: 0.95), Color(red: 0.75, green: 0.82, blue: 0.90)],
            [Color(red: 0.92, green: 0.87, blue: 0.95), Color(red: 0.82, green: 0.76, blue: 0.89)],
            [Color(red: 0.95, green: 0.90, blue: 0.88), Color(red: 0.87, green: 0.81, blue: 0.79)],
            [Color(red: 0.88, green: 0.93, blue: 0.91), Color(red: 0.77, green: 0.85, blue: 0.82)]
        ]
        let index = abs(avatarSeed.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        }) % palettes.count
        let colors = palettes[index]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func fallbackAvatar(reason: String) -> some View {
        Circle()
            .fill(fallbackGradient)
            .overlay(
                Text(initials)
                    .font(.system(size: max(11, size * 0.34), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
            .frame(width: size, height: size)
            .onAppear {
                print("[SEASON_AVATAR] phase=fallback_used creator_id=\(creatorLogID) reason=\(reason)")
            }
    }
}
