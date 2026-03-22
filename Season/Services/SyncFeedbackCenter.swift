import Foundation
import Combine

enum SyncFeedbackState {
    case pending
    case success
    case error
}

@MainActor
final class SyncFeedbackCenter: ObservableObject {
    static let shared = SyncFeedbackCenter()

    @Published private(set) var message: String?
    @Published private(set) var isVisible = false

    private var dismissTask: Task<Void, Never>?

    func show(_ state: SyncFeedbackState) {
        let text: String
        switch state {
        case .pending:
            text = "Pending..."
        case .success:
            text = "Saved"
        case .error:
            text = "Sync error"
        }

        dismissTask?.cancel()
        message = text
        isVisible = true

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.isVisible = false
            self?.message = nil
        }
    }
}
