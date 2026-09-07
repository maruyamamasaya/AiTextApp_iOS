import SwiftUI

@main
struct AiTextApp: App {
    @StateObject private var store = ThoughtStore()

    var body: some Scene {
        WindowGroup {
            TimelineView(store: store)
        }
    }
}
