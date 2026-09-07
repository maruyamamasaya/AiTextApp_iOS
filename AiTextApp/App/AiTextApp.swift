import SwiftUI

@main
struct AiTextApp: App {
    @StateObject private var store: ThoughtStore

    init() {
        // UI tests use an isolated repository so automation never touches a
        // person's Application Support database.
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            _store = StateObject(wrappedValue: ThoughtStore(repository: MemoryThoughtRepository()))
        } else {
            var restoreError: String?
            let fileManager = FileManager.default
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let databaseURL = support.appendingPathComponent("ThoughtTimeline/thought-timeline.sqlite3")
            do {
                _ = try RestoreCoordinator.applyPendingRestoreIfNeeded(
                    databaseURL: databaseURL,
                    applicationSupportDirectory: support,
                    fileManager: fileManager
                )
            } catch {
                restoreError = "Restoreを適用できなかったため、元のデータを維持しました。\n\(error.localizedDescription)"
            }
            _store = StateObject(wrappedValue: ThoughtStore(startupError: restoreError))
        }
    }

    var body: some Scene {
        WindowGroup {
            TimelineView(store: store)
        }
    }
}
