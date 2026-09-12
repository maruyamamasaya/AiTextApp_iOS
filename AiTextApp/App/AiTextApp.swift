import SwiftUI

@main
struct AiTextApp: App {
    @StateObject private var store: ThoughtStore
    @StateObject private var themeController = ThemeController()

    init() {
        // UI tests use an isolated repository so automation never touches a
        // person's Application Support database.
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let repository = MemoryThoughtRepository()
            let mio = Persona(displayName: "Mio", handle: "mio", kind: .ai)
            try? repository.createAIPersona(mio, configuration: .init(personaID: mio.id, role: "対話相手", instructions: "短く自然に返信する", autoReplyEnabled: true))
            _store = StateObject(wrappedValue: ThoughtStore(repository: repository, summaryClient: MockReviewSummaryClient(text: "一緒に考えてみましょう。")))
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
            _store = StateObject(wrappedValue: ThoughtStore(
                summaryClient: ReviewSummaryClientFactory.makeProductionClient(),
                startupError: restoreError
            ))
        }
    }

    var body: some Scene {
        WindowGroup {
            ThemeHost(controller: themeController) {
                MainTabView(store: store)
            }
            .environmentObject(themeController)
        }
    }
}
