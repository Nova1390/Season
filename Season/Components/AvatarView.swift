import SwiftUI

struct AvatarView: View {
    let avatarURL: String?
    let size: CGFloat
    let creatorID: String?

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
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: size, height: size)
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

    private func fallbackAvatar(reason: String) -> some View {
        Circle()
            .fill(Color(.tertiarySystemGroupedBackground))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: max(10, size * 0.43), weight: .semibold))
                    .foregroundStyle(.secondary)
            )
            .frame(width: size, height: size)
            .onAppear {
                print("[SEASON_AVATAR] phase=fallback_used creator_id=\(creatorLogID) reason=\(reason)")
            }
    }
}
