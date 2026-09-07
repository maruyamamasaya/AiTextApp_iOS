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
            _store = StateObject(wrappedValue: ThoughtStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            TimelineView(store: store)
        }
    }
}
