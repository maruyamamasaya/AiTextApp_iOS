import SwiftUI

enum AppRoute: String, Identifiable {
    case quickCapture
    var id: String { rawValue }

    init?(externalURL: URL) {
        guard QuickCaptureRoute.matches(externalURL) else { return nil }
        self = .quickCapture
    }
}

@main
struct AiTextApp: App {
    @StateObject private var store: ThoughtStore
    @State private var presentedRoute: AppRoute? = nil

    init() {
        // UI tests use an isolated repository so automation never touches a
        // person's Application Support database.
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-fail-posts") {
            _store = StateObject(wrappedValue: ThoughtStore(repository: FailingThoughtRepository()))
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
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
            _store = StateObject(wrappedValue: ThoughtStore(
                summaryClient: ReviewSummaryClientFactory.makeProductionClient(),
                startupError: restoreError
            ))
        }
    }

    var body: some Scene {
        WindowGroup {
            TimelineView(store: store, presentedRoute: $presentedRoute)
                .onOpenURL { url in
                    guard let route = AppRoute(externalURL: url) else { return }
                    presentedRoute = route
                }
                .sheet(item: $presentedRoute) { route in
                    switch route {
                    case .quickCapture:
                        QuickCaptureView(store: store)
                    }
                }
        }
    }
}

private final class FailingThoughtRepository: ThoughtRepository, @unchecked Sendable {
    private let memory = MemoryThoughtRepository()
    func create(_ thought: Thought) throws { throw CocoaError(.fileWriteUnknown) }
    func fetchTimeline() throws -> [Thought] { try memory.fetchTimeline() }
    func search(query: String) throws -> [Thought] { try memory.search(query: query) }
    func fetchByID(_ id: UUID) throws -> Thought? { try memory.fetchByID(id) }
    func fetchAll() throws -> [Thought] { try memory.fetchAll() }
    func fetchThoughts(from startDate: Date, to endDate: Date) throws -> [Thought] {
        try memory.fetchThoughts(from: startDate, to: endDate)
    }
    func softDelete(id: UUID, at date: Date) throws -> Bool { try memory.softDelete(id: id, at: date) }
}
