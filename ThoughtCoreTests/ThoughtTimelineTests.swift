import Foundation
import Testing
@testable import ThoughtCore

@Suite("Thought timeline", .serialized)
struct ThoughtTimelineTests {
    @Test func createSupportsBoundariesAndUnicode() throws {
        let repository = MemoryThoughtRepository()
        var timeline = try ThoughtTimeline(repository: repository)

        #expect(try timeline.post("a")?.body == "a")
        #expect(try timeline.post("日本語")?.body == "日本語")
        #expect(try timeline.post("🚀")?.body == "🚀")
        let maximum = String(repeating: "あ", count: 140)
        #expect(try timeline.post(maximum)?.body == maximum)
        #expect(try timeline.post("") == nil)
        #expect(try timeline.post(" \n\t ") == nil)
        #expect(try timeline.post(String(repeating: "a", count: 141)) == nil)
    }

    @Test func limitsDraftByUserPerceivedCharacters() {
        let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 141)
        #expect(ThoughtDraft.limited(emoji).count == 140)
    }

    @Test func trimsEdgesAndPreservesUnicode() throws {
        var timeline = try ThoughtTimeline(repository: MemoryThoughtRepository())
        #expect(try timeline.post("  日本語 English 123 🚀\n")?.body == "日本語 English 123 🚀")
    }

    @Test func postingAddsNewThoughtAtTimelineTop() throws {
        var timeline = try ThoughtTimeline(repository: MemoryThoughtRepository())
        try timeline.post("first", now: Date(timeIntervalSince1970: 100))
        try timeline.post("newest", now: Date(timeIntervalSince1970: 200))
        #expect(timeline.thoughts.map(\.body) == ["newest", "first"])
    }

    @Test func sqliteCreatesReadsAndUsesStableQueryOrder() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = try fixture.repository()
        let date = Date(timeIntervalSince1970: 200)
        let low = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let high = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        try repository.create(Thought(id: low, body: "low", createdAt: date))
        try repository.create(Thought(id: high, body: "high", createdAt: date))
        try repository.create(Thought(body: "older", createdAt: Date(timeIntervalSince1970: 100)))

        #expect(try repository.fetchByID(low)?.body == "low")
        #expect(try repository.fetchTimeline().map(\.body) == ["high", "low", "older"])
    }

    @Test func softDeleteSetsTimestampAndExcludesTimeline() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = try fixture.repository()
        let thought = Thought(body: "delete me")
        let deletion = Date(timeIntervalSince1970: 500)
        try repository.create(thought)

        #expect(try repository.softDelete(id: thought.id, at: deletion))
        #expect(try repository.fetchByID(thought.id)?.deletedAt == deletion)
        #expect(try repository.fetchTimeline().isEmpty)
        #expect(try repository.fetchAll().count == 1)
    }

    @Test func sqliteSurvivesRepositoryRecreation() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.repository().create(Thought(body: "persisted 🚀"))
        #expect(try fixture.repository().fetchTimeline().map(\.body) == ["persisted 🚀"])
    }

    @Test func sqliteKeepsOnlyTwoRollingBackups() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let repository = try fixture.repository()
        try repository.create(Thought(body: "one"))
        try repository.create(Thought(body: "two"))
        try repository.create(Thought(body: "three"))

        #expect(FileManager.default.fileExists(atPath: fixture.databaseURL.appendingPathExtension("backup.1").path))
        #expect(FileManager.default.fileExists(atPath: fixture.databaseURL.appendingPathExtension("backup.2").path))
        let backupFiles = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
            .filter { $0.contains(".backup.") }
        #expect(backupFiles.count == 2)
    }

    @Test(arguments: [[], [Thought(body: "migrated 日本語 🚀")]])
    func migratesLegacyJSONIncludingEmptyFile(thoughts: [Thought]) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeLegacyJSON(thoughts)
        let repository = try fixture.repository()
        #expect(try repository.fetchAll().map(\.id) == thoughts.map(\.id))
        #expect(try repository.fetchAll().map(\.body) == thoughts.map(\.body))
        #expect(FileManager.default.fileExists(atPath: fixture.jsonURL.path))
    }

    @Test func runningMigrationTwiceDoesNotDuplicate() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let thought = Thought(body: "only once")
        try fixture.writeLegacyJSON([thought])
        #expect(try fixture.repository().fetchAll().count == 1)
        #expect(try fixture.repository().fetchAll().count == 1)
    }

    @Test func failedMigrationRetainsLegacyJSON() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try Data("not-json".utf8).write(to: fixture.jsonURL)
        #expect(throws: SQLiteThoughtRepositoryError.self) { try fixture.repository() }
        #expect(FileManager.default.fileExists(atPath: fixture.jsonURL.path))
        #expect(try String(contentsOf: fixture.jsonURL, encoding: .utf8) == "not-json")
    }
}

@Suite("Thought export")
struct ThoughtExporterTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func markdownForZeroThoughts() throws {
        let exporter = makeExporter([])
        #expect(try String(decoding: exporter.data(for: .markdown), as: UTF8.self) == "# Thought Export\n\n")
    }

    @Test func markdownForOneJapaneseAndEmojiThought() throws {
        let thought = Thought(body: "日本語の原文 🚀", createdAt: date("2026-09-07T15:32:00Z"))
        let markdown = try String(decoding: makeExporter([thought]).data(for: .markdown), as: UTF8.self)
        #expect(markdown == "# Thought Export\n\n## 2026-09-07\n\n### 15:32\n\n日本語の原文 🚀\n")
    }

    @Test func markdownGroupsDaysAndUsesStableNewestFirstOrder() throws {
        let sameDate = date("2026-09-07T14:48:00Z")
        let low = Thought(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, body: "low", createdAt: sameDate)
        let high = Thought(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!, body: "high", createdAt: sameDate)
        let older = Thought(body: "昨日", createdAt: date("2026-09-06T23:01:00Z"))
        let markdown = try String(decoding: makeExporter([older, low, high]).data(for: .markdown), as: UTF8.self)
        #expect(markdown.range(of: "high")!.lowerBound < markdown.range(of: "low")!.lowerBound)
        #expect(markdown.range(of: "low")!.lowerBound < markdown.range(of: "## 2026-09-06")!.lowerBound)
        #expect(markdown.contains("### 23:01\n\n昨日"))
    }

    @Test func exportsDecodableJSONWithCanonicalFieldsAndUnicode() throws {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let created = date("2026-09-07T15:32:00Z")
        let updated = date("2026-09-07T16:00:00Z")
        let thought = Thought(id: id, body: "日本語 🚀", createdAt: created, updatedAt: updated)
        let data = try makeExporter([thought]).data(for: .json)
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([Thought].self, from: data)

        #expect(decoded == [thought])
        #expect(decoded.first?.id == id)
        #expect(decoded.first?.body == "日本語 🚀")
        #expect(decoded.first?.createdAt == created)
        #expect(text.contains("\"deletedAt\" : null"))
    }

    @Test func exportExcludesSoftDeletedThoughts() throws {
        let active = Thought(body: "active")
        let deleted = Thought(body: "deleted", deletedAt: .now)
        let decoded = try JSONDecoder.withISO8601.decode([Thought].self, from: makeExporter([active, deleted]).data(for: .json))
        #expect(decoded.map(\.id) == [active.id])
    }

    private func makeExporter(_ thoughts: [Thought]) -> ThoughtExporter {
        ThoughtExporter(repository: MemoryThoughtRepository(records: thoughts), timeZone: utc)
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
}

private extension JSONDecoder {
    static var withISO8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct Fixture {
    let directory: URL
    var databaseURL: URL { directory.appendingPathComponent("thought-timeline.sqlite3") }
    var jsonURL: URL { directory.appendingPathComponent("thoughts.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func repository() throws -> SQLiteThoughtRepository {
        try SQLiteThoughtRepository(databaseURL: databaseURL, legacyJSONURL: jsonURL)
    }

    func writeLegacyJSON(_ thoughts: [Thought]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(thoughts).write(to: jsonURL)
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}
