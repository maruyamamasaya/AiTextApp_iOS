import Foundation

public struct DailySummaryContent: Codable, Equatable, Sendable {
    public let overview: String
    public let themes: [String]
    public let existingTagCandidates: [String]
    public let newTagCandidates: [String]
    public let thoughtPatterns: [String]
    public let deepDives: [String]
    public let concerns: [String]
    public let thoughtFlow: String
    public let continuationCandidates: [String]
    public let carryOvers: [String]

    public init(overview: String, themes: [String], existingTagCandidates: [String], newTagCandidates: [String], thoughtPatterns: [String], deepDives: [String], concerns: [String], thoughtFlow: String, continuationCandidates: [String], carryOvers: [String]) {
        self.overview = overview
        self.themes = themes
        self.existingTagCandidates = existingTagCandidates
        self.newTagCandidates = newTagCandidates
        self.thoughtPatterns = thoughtPatterns
        self.deepDives = deepDives
        self.concerns = concerns
        self.thoughtFlow = thoughtFlow
        self.continuationCandidates = continuationCandidates
        self.carryOvers = carryOvers
    }
}

public struct DailySummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let dayStart: Date
    public let dayEnd: Date
    public let content: DailySummaryContent
    public let createdAt: Date
    public let provider: String
    public let model: String
    public let promptVersion: Int
    public let thoughtCount: Int

    public init(id: UUID = UUID(), dayStart: Date, dayEnd: Date, content: DailySummaryContent, createdAt: Date = Date(), provider: String, model: String, promptVersion: Int, thoughtCount: Int) {
        self.id = id; self.dayStart = dayStart; self.dayEnd = dayEnd; self.content = content
        self.createdAt = createdAt; self.provider = provider; self.model = model
        self.promptVersion = promptVersion; self.thoughtCount = thoughtCount
    }
}

public protocol DailySummaryRepository: Sendable {
    func saveDailySummary(_ summary: DailySummary) throws
    func fetchDailySummary(dayStart: Date) throws -> DailySummary?
    func fetchDailySummaries(from start: Date, to end: Date) throws -> [DailySummary]
}

public struct DailySummaryPreview: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let interval: DateInterval
    public let thoughts: [Thought]
    public let existingTags: [String]
    public let continuationCount: Int
    public let request: ReviewSummaryRequest

    public init(id: UUID = UUID(), interval: DateInterval, thoughts: [Thought], existingTags: [String], continuationCount: Int, request: ReviewSummaryRequest) {
        self.id = id; self.interval = interval; self.thoughts = thoughts
        self.existingTags = existingTags; self.continuationCount = continuationCount; self.request = request
    }
}

public enum DailySummaryPrompt {
    public static let version = 1
    public static func make(thoughts: [Thought], existingTags: [String]) throws -> String {
        guard !thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let bodies = thoughts.enumerated().map { "\($0.offset + 1). \($0.element.body)" }.joined(separator: "\n")
        return """
        以下は利用者が明示的に選択した1日分の短いメモです。記載内容だけを根拠に日本語で振り返ってください。
        性格診断や固定的評価を避け、「思考パターン」はこの日に観測できる傾向として記述してください。
        タグは候補を返すだけにし、既存データを変更する指示はしないでください。
        JSON以外を出力せず、次のキーを必ず含めてください。
        {"overview":"", "themes":[], "existingTagCandidates":[], "newTagCandidates":[], "thoughtPatterns":[], "deepDives":[], "concerns":[], "thoughtFlow":"", "continuationCandidates":[], "carryOvers":[]}

        既存タグ: \(existingTags.joined(separator: ", "))
        Thought（古い順）:
        \(bodies)
        """
    }
}

public struct PrepareDailySummary: Sendable {
    private let thoughts: any ThoughtRepository
    private let tags: any ThoughtTagRepository
    private let relations: any ThoughtRelationRepository
    public init(thoughts: any ThoughtRepository, tags: any ThoughtTagRepository, relations: any ThoughtRelationRepository) {
        self.thoughts = thoughts; self.tags = tags; self.relations = relations
    }
    public func callAsFunction(day: Date, calendar: Calendar = .current) throws -> DailySummaryPreview {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw ReviewSummaryError.noThoughts }
        let interval = DateInterval(start: start, end: end)
        let records = try thoughts.fetchThoughts(from: start, to: end)
        guard !records.isEmpty else { throw ReviewSummaryError.noThoughts }
        var names = Set<String>()
        for thought in records { for tag in try tags.fetchTags(for: thought.id) { names.insert(tag.name) } }
        let existing = names.sorted()
        let counts = try relations.fetchContinuationCounts(for: records.map(\.id))
        return DailySummaryPreview(interval: interval, thoughts: records, existingTags: existing, continuationCount: counts.values.reduce(0, +), request: .init(prompt: try DailySummaryPrompt.make(thoughts: records, existingTags: existing)))
    }
}

public struct GenerateDailySummary: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any DailySummaryRepository
    public init(client: any ReviewSummaryClient, repository: any DailySummaryRepository) { self.client = client; self.repository = repository }
    public func callAsFunction(preview: DailySummaryPreview, now: Date = Date()) async throws -> DailySummary {
        guard !preview.thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let response = try await client.generateSummary(preview.request)
        let raw = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let json = raw.hasPrefix("```") ? raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines) : raw
        guard let data = json.data(using: .utf8) else { throw ReviewSummaryError.emptyResponse }
        let content = try JSONDecoder().decode(DailySummaryContent.self, from: data)
        let existing = Set(preview.existingTags)
        let sanitized = DailySummaryContent(
            overview: content.overview,
            themes: content.themes,
            existingTagCandidates: content.existingTagCandidates.filter(existing.contains),
            newTagCandidates: content.newTagCandidates.filter { !existing.contains($0) },
            thoughtPatterns: content.thoughtPatterns,
            deepDives: content.deepDives,
            concerns: content.concerns,
            thoughtFlow: content.thoughtFlow,
            continuationCandidates: content.continuationCandidates,
            carryOvers: content.carryOvers
        )
        let summary = DailySummary(dayStart: preview.interval.start, dayEnd: preview.interval.end, content: sanitized, createdAt: now, provider: response.provider, model: response.model, promptVersion: DailySummaryPrompt.version, thoughtCount: preview.thoughts.count)
        try repository.saveDailySummary(summary)
        return summary
    }
}
