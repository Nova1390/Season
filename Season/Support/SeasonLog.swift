import Foundation

enum SeasonLog {
    nonisolated static let verbose = false // Enable only for deep per-item debugging.
    nonisolated static let lifecycleEnabled = false

    nonisolated static func debug(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        #if DEBUG
        guard verbose || ProcessInfo.processInfo.environment["SEASON_DEBUG_LOGS"] == "1" else { return }
        Swift.print(message())
        #endif
    }

    nonisolated static func lifecycle(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        #if DEBUG
        guard lifecycleEnabled || ProcessInfo.processInfo.environment["SEASON_DEBUG_LOGS"] == "1" else { return }
        Swift.print(message())
        #endif
    }
}
