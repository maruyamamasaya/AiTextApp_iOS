import Foundation
import Testing
@testable import ThoughtCore
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

private final class UsageMemory: AIAPIUsageRepository, AIAPIUsageAnalyticsRepository, @unchecked Sendable {
    private let lock = NSLock(); private var values: [AIAPIUsageRecord] = []
    var shouldFail = false
    func saveUsage(_ record: AIAPIUsageRecord) throws { if shouldFail { throw CocoaError(.fileWriteUnknown) }; lock.withLock { values.append(record) } }
    func fetchUsage(from start: Date?, to end: Date?) throws -> [AIAPIUsageRecord] { lock.withLock { values.filter { (start == nil || $0.startedAt >= start!) && (end == nil || $0.startedAt < end!) } } }
}

private struct CancellingClient: ReviewSummaryClient {
    func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse { throw CancellationError() }
}

@Suite("AI API usage analytics", .serialized)
struct AIAPIUsageTests {
    @Test func sqliteRoundTripsMetadataAndKeepsTokensNil() throws {
        let fixture = try UsageFixture(); defer { fixture.remove() }
        let repository = try fixture.repository()
        let personaID = UUID(), start = Date(timeIntervalSince1970: 1_000), end = Date(timeIntervalSince1970: 1_001.25)
        try repository.saveUsage(.init(startedAt: start, finishedAt: end, feature: .knowledgeDraft, personaID: personaID, provider: "provider", model: "model", status: .success, inputCharacters: 123, outputCharacters: 45, latencyMilliseconds: 1_250, externalBrainUsed: true, retrievedChunkCount: 3, sourceType: .aiReply))
        let value = try #require(repository.fetchUsage(from: nil, to: nil).first)
        #expect(value.personaID == personaID); #expect(value.inputCharacters == 123); #expect(value.outputCharacters == 45)
        #expect(value.inputTokens == nil); #expect(value.outputTokens == nil); #expect(value.totalTokens == nil)
        #expect(value.externalBrainUsed); #expect(value.retrievedChunkCount == 3); #expect(value.latencyMilliseconds == 1_250)
        #expect(value.feature == .knowledgeDraft); #expect(value.sourceType == .aiReply)
    }

    @Test func recordsSuccessFailureCancellationAndRetryAsSeparateCalls() async throws {
        let usage = UsageMemory()
        let request = ReviewSummaryRequest(prompt: "12345", usageContext: .init(feature: .personaPost))
        let recorder = AIAPIUsageRecorder(repository: usage)
        _ = try await recorder.call(client: MockReviewSummaryClient(text: "ok"), request: request) { $0.text }
        await #expect(throws: ReviewSummaryServiceError.network) { try await recorder.call(client: MockReviewSummaryClient(error: ReviewSummaryServiceError.network), request: request) { $0.text } }
        await #expect(throws: CancellationError.self) { try await recorder.call(client: CancellingClient(), request: request) { $0.text } }
        let values = try usage.fetchUsage(from: nil, to: nil)
        #expect(values.map(\.status) == [.success, .failed, .cancelled])
        #expect(values[0].inputCharacters == 5); #expect(values[0].outputCharacters == 2)
        #expect(values[1].errorCategory == .network); #expect(values[2].errorCategory == nil)
    }

    @Test func telemetryFailureDoesNotFailAIResult() async throws {
        let usage = UsageMemory(); usage.shouldFail = true
        let request = ReviewSummaryRequest(prompt: "private prompt", usageContext: .init(feature: .dailySummary))
        let result = try await AIAPIUsageRecorder(repository: usage).call(client: MockReviewSummaryClient(text: "result"), request: request) { $0.text }
        #expect(result == "result")
    }

    @Test func recordsActualTokenUsageOnlyWhenClientProvidesIt() async throws {
        let usage = UsageMemory(), request = ReviewSummaryRequest(prompt: "input", usageContext: .init(feature: .dailySummary))
        let client = MockReviewSummaryClient(response: .init(text: "output", provider: "p", model: "m", tokenUsage: .init(inputTokens: 7, outputTokens: 3, totalTokens: 10)))
        _ = try await AIAPIUsageRecorder(repository: usage).call(client: client, request: request) { $0.text }
        let value = try #require(usage.fetchUsage(from: nil, to: nil).first)
        #expect(value.inputTokens == 7); #expect(value.outputTokens == 3); #expect(value.totalTokens == 10)
    }

    @Test func aggregatesPeriodsDimensionsTokensBrainLatencyAndErrors() throws {
        let usage = UsageMemory(); var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 2_000_000), persona = UUID()
        try usage.saveUsage(.init(startedAt: now, feature: .thoughtReply, personaID: persona, provider: "p", model: "m", status: .success, inputCharacters: 100, outputCharacters: 20, inputTokens: 10, outputTokens: 2, totalTokens: 12, latencyMilliseconds: 1_000, externalBrainUsed: true, retrievedChunkCount: 4))
        try usage.saveUsage(.init(startedAt: now.addingTimeInterval(-86_400 * 3), feature: .dailySummary, provider: "p", model: "m", status: .failed, inputCharacters: 50, outputCharacters: 0, latencyMilliseconds: 3_000, errorCategory: .rateLimit))
        try usage.saveUsage(.init(startedAt: now.addingTimeInterval(-86_400 * 40), feature: .personaPost, provider: "other", model: "old", status: .success, inputCharacters: 1, outputCharacters: 1))
        let seven = try LoadAIAPIUsageAnalytics(repository: usage, calendar: calendar)(period: .sevenDays, now: now)
        #expect(seven.callCount == 2); #expect(seven.successRate == 0.5); #expect(seven.byFeature.count == 2); #expect(seven.byPersona.count == 1); #expect(seven.byModel.first?.calls == 2)
        #expect(seven.externalBrainRate == 0.5); #expect(seven.averageRetrievedChunkCount == 4); #expect(seven.averageLatencyMilliseconds == 2_000); #expect(seven.byError.first?.name == "rate_limit")
        #expect(seven.inputTokens == 10); #expect(seven.tokenizedCallCount == 1); #expect(seven.daily.count == 2)
        let all = try LoadAIAPIUsageAnalytics(repository: usage, calendar: calendar)(period: .allTime, now: now)
        #expect(all.callCount == 3)
    }

    @Test func usageSchemaContainsNoContentColumns() throws {
        let fixture = try UsageFixture(); defer { fixture.remove() }; _ = try fixture.repository()
        var database: OpaquePointer?; #expect(sqlite3_open(fixture.databaseURL.path, &database) == SQLITE_OK); defer { sqlite3_close(database) }
        var statement: OpaquePointer?; #expect(sqlite3_prepare_v2(database, "PRAGMA table_info(ai_api_usage)", -1, &statement, nil) == SQLITE_OK); defer { sqlite3_finalize(statement) }
        var names: [String] = []; while sqlite3_step(statement) == SQLITE_ROW { names.append(String(cString: sqlite3_column_text(statement, 1))) }
        #expect(!names.contains("prompt")); #expect(!names.contains("response")); #expect(!names.contains("body")); #expect(!names.contains("content"))
    }
}

private struct UsageFixture {
    let directory: URL
    var databaseURL: URL { directory.appendingPathComponent("usage.sqlite3") }
    init() throws { directory = FileManager.default.temporaryDirectory.appendingPathComponent("usage-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    func repository() throws -> SQLiteThoughtRepository { try SQLiteThoughtRepository(databaseURL: databaseURL) }
    func remove() { try? FileManager.default.removeItem(at: directory) }
}
