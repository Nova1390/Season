import SwiftUI
import UIKit

struct RemoteImageView: View {
    let url: URL?
    let fallbackAssetName: String?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackContent
                    case .empty:
                        placeholderContent
                    @unknown default:
                        fallbackContent
                    }
                }
            } else {
                fallbackContent
            }
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if let fallbackAssetName,
           UIImage(named: fallbackAssetName) != nil {
            Image(fallbackAssetName)
                .resizable()
                .scaledToFill()
        } else {
            systemPlaceholderContent
        }
    }

    private var placeholderContent: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.systemGray5))
    }

    private var systemPlaceholderContent: some View {
        ZStack {
            placeholderContent
            Image(systemName: "person.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
