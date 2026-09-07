import Foundation
import Testing
@testable import ThoughtCore

@Suite("Thought timeline")
struct ThoughtTimelineTests {
    @Test func acceptsOneAnd140CharactersButRejectsEmptyAndLongText() throws {
        let repository = MemoryRepository()
        var timeline = try ThoughtTimeline(repository: repository)

        #expect(try timeline.post("a")?.body == "a")
        let maximum = String(repeating: "あ", count: 140)
        #expect(try timeline.post(maximum)?.body == maximum)
        #expect(try timeline.post("") == nil)
        #expect(try timeline.post(" \n\t ") == nil)
        #expect(try timeline.post(String(repeating: "a", count: 141)) == nil)
    }

    @Test func limitsDraftByUserPerceivedCharacters() {
        let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 141)
        let limited = ThoughtDraft.limited(emoji)
        #expect(limited.count == 140)
        #expect(emoji.count == 141)
    }

    @Test func trimsOnlyLeadingAndTrailingWhitespaceAndPreservesUnicode() throws {
        var timeline = try ThoughtTimeline(repository: MemoryRepository())
        let posted = try timeline.post("  日本語 English 123 🚀\n")
        let thought = try #require(posted)
        #expect(thought.body == "日本語 English 123 🚀")
    }

    @Test func sortsNewestFirstAndKeepsStableOrderAfterReload() throws {
        let repository = MemoryRepository()
        var timeline = try ThoughtTimeline(repository: repository)
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        try timeline.post("older", now: older)
        try timeline.post("newer", now: newer)
        #expect(timeline.thoughts.map(\.body) == ["newer", "older"])

        let reloaded = try ThoughtTimeline(repository: repository)
        #expect(reloaded.thoughts.map(\.body) == ["newer", "older"])
    }

    @Test func softDeletesAndPersistsDeletion() throws {
        let repository = MemoryRepository()
        var timeline = try ThoughtTimeline(repository: repository)
        let posted = try timeline.post("delete me")
        let thought = try #require(posted)
        #expect(try timeline.delete(id: thought.id))
        #expect(timeline.thoughts.isEmpty)
        #expect(repository.values.first?.deletedAt != nil)
        #expect(try ThoughtTimeline(repository: repository).thoughts.isEmpty)
    }

    @Test func fileRepositorySurvivesRecreation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("thoughts.json")
        var first = try ThoughtTimeline(repository: FileThoughtRepository(fileURL: url))
        try first.post("persisted 🚀")

        let second = try ThoughtTimeline(repository: FileThoughtRepository(fileURL: url))
        #expect(second.thoughts.map(\.body) == ["persisted 🚀"])
    }
}

private final class MemoryRepository: ThoughtRepository, @unchecked Sendable {
    var values: [Thought] = []
    func load() throws -> [Thought] { values }
    func save(_ thoughts: [Thought]) throws { values = thoughts }
}
