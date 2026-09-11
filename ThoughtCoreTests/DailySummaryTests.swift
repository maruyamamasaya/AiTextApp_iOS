import Foundation
import Testing
@testable import ThoughtCore

@Suite("Daily Summary")
struct DailySummaryTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }

    @Test func preparesExactlyOneLocalDayAndExcludesDeletedThoughts() throws {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let active = Thought(body: "対象", createdAt: start.addingTimeInterval(60), updatedAt: start)
        let deleted = Thought(body: "削除済み", createdAt: start.addingTimeInterval(120), updatedAt: start, deletedAt: start.addingTimeInterval(180))
        let outside = Thought(body: "翌日", createdAt: calendar.date(byAdding: .day, value: 1, to: start)!, updatedAt: start)
        let repository = MemoryThoughtRepository(records: [active, deleted, outside])
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start.addingTimeInterval(3_600), calendar: calendar)
        #expect(preview.interval.start == start)
        #expect(preview.interval.end == calendar.date(byAdding: .day, value: 1, to: start))
        #expect(preview.thoughts == [active])
        #expect(!preview.request.prompt.contains("削除済み"))
        #expect(!preview.request.prompt.contains("翌日"))
    }

    @Test func emptyDayCannotPrepare() {
        let repository = MemoryThoughtRepository()
        #expect(throws: ReviewSummaryError.noThoughts) {
            try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: Date(), calendar: calendar)
        }
    }

    @Test func savesOneFormalSummaryAndDoesNotApplyTagCandidates() async throws {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let thought = Thought(body: "比較して次を決める", createdAt: start.addingTimeInterval(60), updatedAt: start)
        let repository = MemoryThoughtRepository(records: [thought])
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start, calendar: calendar)
        let json = #"{"overview":"概要","themes":["仕事"],"existingTagCandidates":[],"newTagCandidates":["検討"],"thoughtPatterns":["比較・検討型"],"deepDives":["選択肢"],"concerns":["判断"],"thoughtFlow":"比較から決定","continuationCandidates":["検証"],"carryOvers":["実行"]}"#
        let summary = try await GenerateDailySummary(client: MockReviewSummaryClient(text: json), repository: repository)(preview: preview, now: start.addingTimeInterval(500))
        #expect(try repository.fetchDailySummary(dayStart: start) == summary)
        #expect(summary.content.newTagCandidates == ["検討"])
        #expect(try repository.fetchTags(for: thought.id).isEmpty)
    }

    @Test func sqliteDailySummarySurvivesReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("timeline.sqlite3")
        let first = try SQLiteThoughtRepository(databaseURL: url)
        let start = calendar.startOfDay(for: Date())
        let thought = Thought(body: "保存確認", createdAt: start.addingTimeInterval(60), updatedAt: start)
        try first.create(thought)
        let preview = try PrepareDailySummary(thoughts: first, tags: first, relations: first, authors: first)(day: start, calendar: calendar)
        let json = #"{"overview":"保存済み","themes":[],"existingTagCandidates":[],"newTagCandidates":[],"thoughtPatterns":[],"deepDives":[],"concerns":[],"thoughtFlow":"","continuationCandidates":[],"carryOvers":[]}"#
        _ = try await GenerateDailySummary(client: MockReviewSummaryClient(text: json), repository: first)(preview: preview)
        let reopened = try SQLiteThoughtRepository(databaseURL: url)
        #expect(try reopened.fetchDailySummary(dayStart: start)?.content.overview == "保存済み")
        #expect(SQLiteThoughtRepository.schemaVersion == 16)
    }

    @Test func v1ContentDecodesWithV2FieldsDefaulted() throws {
        let json = #"{"overview":"v1","themes":[],"existingTagCandidates":[],"newTagCandidates":[],"thoughtPatterns":["比較"],"deepDives":[],"concerns":[],"thoughtFlow":"","continuationCandidates":[],"carryOvers":[]}"#.data(using: .utf8)!
        let content = try JSONDecoder().decode(DailySummaryContent.self, from: json)
        #expect(content.thoughtPatterns == ["比較"]); #expect(content.tagGroups.isEmpty); #expect(content.aiInteractions.isEmpty); #expect(content.timeOfDayInsights.isEmpty)
    }

    @Test func v2ContentRoundTrips() throws {
        let content = DailySummaryContent(overview: "概要", themes: ["設計"], existingTagCandidates: ["開発"], newTagCandidates: ["検討"], thoughtPatterns: ["比較"], deepDives: ["DB"], concerns: ["移行"], thoughtFlow: "検討から決定", continuationCandidates: ["検証"], carryOvers: ["実行"], tagGroups: [.init(tagName: "開発", summary: "設計", themes: ["DB"], thoughtCount: 2)], aiInteractions: [.init(personaName: "Architect", topics: ["SQLite"], summary: "分離案を受けた")], timeOfDayInsights: [.init(period: "夜", insight: "設計検討が集中")])
        #expect(try JSONDecoder().decode(DailySummaryContent.self, from: JSONEncoder().encode(content)) == content)
    }

    @Test func previewSeparatesHumanAIAuthorsTagsRelationsAndTime() throws {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let repository = MemoryThoughtRepository()
        let human = Thought(body: "設計を考える", createdAt: start.addingTimeInterval(8 * 3600 + 30 * 60)); try repository.create(human)
        let architect = Persona(displayName: "Architect", kind: .ai), vespera = Persona(displayName: "Vespera", kind: .ai)
        try repository.createPersona(architect); try repository.createPersona(vespera)
        let aiReply = Thought(body: "責務を分ける提案", createdAt: start.addingTimeInterval(12 * 3600)); try repository.create(aiReply, authorPersonaID: architect.id)
        let aiPost = Thought(body: "UI観点", createdAt: start.addingTimeInterval(20 * 3600)); try repository.create(aiPost, authorPersonaID: vespera.id)
        _ = try repository.addTag(named: "開発", to: human.id); _ = try repository.addTag(named: "AIだけ", to: aiReply.id)
        try repository.create(ThoughtRelation(sourceThoughtID: aiReply.id, targetThoughtID: human.id, type: .repliesTo))
        try repository.create(ThoughtRelation(sourceThoughtID: aiPost.id, targetThoughtID: aiReply.id, type: .continues))
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start, calendar: calendar)
        #expect(preview.inputs.map(\.author.kind) == [.human, .ai, .ai]); #expect(preview.existingTags == ["開発"])
        #expect(preview.inputs[0].timeOfDay == .morning); #expect(preview.inputs[1].timeOfDay == .afternoon); #expect(preview.inputs[2].timeOfDay == .night)
        #expect(preview.request.prompt.contains("Author: Human")); #expect(preview.request.prompt.contains("Author: AI: Architect")); #expect(preview.request.prompt.contains("AI: Vespera")); #expect(preview.request.prompt.contains("Tags: 開発")); #expect(!preview.request.prompt.contains("Tags: AIだけ")); #expect(preview.request.prompt.contains("repliesTo Thought 1")); #expect(preview.request.prompt.contains("continues Thought 2")); #expect(preview.request.prompt.contains("timeOfDayInsightsを空配列"))
    }

    @Test func tagGroupsAreLimitedToActualHumanTagsAndAIInteractionsToActualPersonas() async throws {
        let start = calendar.startOfDay(for: Date()), repository = MemoryThoughtRepository()
        let first = Thought(body: "一つ目", createdAt: start.addingTimeInterval(60)), second = Thought(body: "二つ目", createdAt: start.addingTimeInterval(120)); try repository.create(first); try repository.create(second)
        _ = try repository.addTag(named: "開発", to: first.id); _ = try repository.addTag(named: "開発", to: second.id)
        let ai = Persona(displayName: "Architect", kind: .ai); try repository.createPersona(ai); let aiThought = Thought(body: "提案", createdAt: start.addingTimeInterval(180)); try repository.create(aiThought, authorPersonaID: ai.id)
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start, calendar: calendar)
        let json = #"{"overview":"概要","themes":[],"existingTagCandidates":["開発"],"newTagCandidates":[],"humanThoughtPatterns":[],"deepDives":[],"concerns":[],"thoughtFlow":"","tagGroups":[{"tagName":"開発","summary":"開発","themes":[],"thoughtCount":99},{"tagName":"架空","summary":"誤り","themes":[],"thoughtCount":1}],"aiInteractions":[{"personaName":"Architect","topics":[],"summary":"提案"},{"personaName":"Unknown","topics":[],"summary":"誤り"}],"timeOfDayInsights":[],"continuationCandidates":[],"carryOvers":[]}"#
        let summary = try await GenerateDailySummary(client: MockReviewSummaryClient(text: json), repository: repository)(preview: preview)
        #expect(summary.content.tagGroups.map(\.tagName) == ["開発"]); #expect(summary.content.tagGroups.first?.thoughtCount == 2); #expect(summary.content.aiInteractions.map(\.personaName) == ["Architect"]); #expect(summary.content.timeOfDayInsights.isEmpty)
    }

    @Test func calendarTimezoneControlsDayAndTimeClassification() throws {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = utc.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 5, minute: 30))!
        let repository = MemoryThoughtRepository(records: [Thought(body: "境界", createdAt: instant)])
        let utcPreview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: instant, calendar: utc)
        let tokyoPreview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: instant, calendar: calendar)
        #expect(utcPreview.inputs[0].timeOfDay == .lateNight); #expect(tokyoPreview.inputs[0].timeOfDay == .afternoon)
        #expect(utcPreview.request.prompt.contains("[05:30]")); #expect(tokyoPreview.request.prompt.contains("[14:30]"))
    }

    @Test func thoughtTagSuggestionsResolveOnlyValidHumanIndicesWithoutSavingTags() async throws {
        let start = calendar.startOfDay(for: Date()), repository = MemoryThoughtRepository()
        let human = Thought(body: "Relation設計を検討", createdAt: start.addingTimeInterval(60)); try repository.create(human)
        let ai = Persona(displayName: "Architect", kind: .ai); try repository.createPersona(ai)
        let aiThought = Thought(body: "分離を提案", createdAt: start.addingTimeInterval(120)); try repository.create(aiThought, authorPersonaID: ai.id)
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start, calendar: calendar)
        let json = #"{"overview":"概要","themes":[],"existingTagCandidates":[],"newTagCandidates":["設計"],"humanThoughtPatterns":[],"deepDives":[],"concerns":[],"thoughtFlow":"","tagGroups":[],"aiInteractions":[],"timeOfDayInsights":[],"continuationCandidates":[],"carryOvers":[],"thoughtTagSuggestions":[{"thoughtIndex":1,"tagName":" 設計 ","reason":"Relation構造を検討していたため"},{"thoughtIndex":2,"tagName":"AI用","reason":"AIなので無効"},{"thoughtIndex":99,"tagName":"不正","reason":"範囲外"}]}"#
        let summary = try await GenerateDailySummary(client: MockReviewSummaryClient(text: json), repository: repository)(preview: preview)
        #expect(summary.content.thoughtTagSuggestions.count == 1)
        #expect(summary.content.thoughtTagSuggestions.first?.thoughtID == human.id); #expect(summary.content.thoughtTagSuggestions.first?.tagName == "設計")
        #expect(try repository.fetchTags(for: human.id).isEmpty)
        #expect(!preview.request.prompt.contains(human.id.uuidString)); #expect(preview.request.prompt.contains("既存の表記を優先"))
    }

    @Test func suggestedTagIsPersistedOnlyThroughExplicitTagRepositoryAction() async throws {
        let start = calendar.startOfDay(for: Date()), repository = MemoryThoughtRepository()
        let thought = Thought(body: "設計", createdAt: start.addingTimeInterval(60)); try repository.create(thought)
        let preview = try PrepareDailySummary(thoughts: repository, tags: repository, relations: repository, authors: repository)(day: start, calendar: calendar)
        let json = #"{"overview":"","themes":[],"existingTagCandidates":[],"newTagCandidates":[],"humanThoughtPatterns":[],"deepDives":[],"concerns":[],"thoughtFlow":"","tagGroups":[],"aiInteractions":[],"timeOfDayInsights":[],"continuationCandidates":[],"carryOvers":[],"thoughtTagSuggestions":[{"thoughtIndex":1,"tagName":"設計","reason":"設計を検討"}]}"#
        _ = try await GenerateDailySummary(client: MockReviewSummaryClient(text: json), repository: repository)(preview: preview)
        #expect(try repository.fetchTags(for: thought.id).isEmpty)
        _ = try repository.addTag(named: "設計", to: thought.id)
        #expect(try repository.fetchTags(for: thought.id).map(\.name) == ["設計"])
    }
}
