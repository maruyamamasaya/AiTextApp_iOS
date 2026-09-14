import Foundation

public struct WeeklySummaryContent: Codable, Equatable, Sendable {
    public let overview: String
    public let themes: [String]
    public let changes: [String]
    public let recurringTopics: [String]
    public let thoughtDevelopments: [String]
    public let notableThoughts: [String]
    public let unresolvedQuestions: [String]

    public init(overview: String, themes: [String], changes: [String], recurringTopics: [String], thoughtDevelopments: [String], notableThoughts: [String], unresolvedQuestions: [String]) {
        self.overview = overview; self.themes = themes; self.changes = changes
        self.recurringTopics = recurringTopics; self.thoughtDevelopments = thoughtDevelopments
        self.notableThoughts = notableThoughts; self.unresolvedQuestions = unresolvedQuestions
    }
}

public struct WeeklySummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let weekStart: Date
    public let weekEnd: Date
    public let content: WeeklySummaryContent
    public let createdAt: Date
    public let provider: String
    public let model: String
    public let promptVersion: Int
    public let thoughtCount: Int

    public init(id: UUID = UUID(), weekStart: Date, weekEnd: Date, content: WeeklySummaryContent, createdAt: Date = Date(), provider: String, model: String, promptVersion: Int, thoughtCount: Int) {
        self.id = id; self.weekStart = weekStart; self.weekEnd = weekEnd; self.content = content
        self.createdAt = createdAt; self.provider = provider; self.model = model
        self.promptVersion = promptVersion; self.thoughtCount = thoughtCount
    }
}

public struct WeeklyPlanContent: Codable, Equatable, Sendable {
    public var focus: String
    public var actions: [String]
    public var questions: [String]
    public var note: String

    public init(focus: String, actions: [String], questions: [String], note: String = "") {
        self.focus = focus; self.actions = Array(actions.prefix(3)); self.questions = Array(questions.prefix(3)); self.note = note
    }
}

public struct WeeklyPlan: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let targetWeekStart: Date
    public let targetWeekEnd: Date
    public let sourceSummaryID: UUID
    public var content: WeeklyPlanContent
    public let createdAt: Date
    public let updatedAt: Date
    public let provider: String
    public let model: String
    public let promptVersion: Int

    public init(id: UUID = UUID(), targetWeekStart: Date, targetWeekEnd: Date, sourceSummaryID: UUID, content: WeeklyPlanContent, createdAt: Date = Date(), updatedAt: Date = Date(), provider: String, model: String, promptVersion: Int) {
        self.id = id; self.targetWeekStart = targetWeekStart; self.targetWeekEnd = targetWeekEnd
        self.sourceSummaryID = sourceSummaryID; self.content = content; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.provider = provider; self.model = model; self.promptVersion = promptVersion
    }
}

public protocol WeeklyReviewRepository: Sendable {
    func saveWeeklySummary(_ summary: WeeklySummary) throws
    func fetchWeeklySummary(weekStart: Date) throws -> WeeklySummary?
    func fetchWeeklySummaries() throws -> [WeeklySummary]
    func saveWeeklyPlan(_ plan: WeeklyPlan) throws
    func fetchWeeklyPlan(targetWeekStart: Date) throws -> WeeklyPlan?
}

public struct WeeklySummaryPreview: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let interval: DateInterval
    public let thoughts: [Thought]
    public let request: ReviewSummaryRequest
    public init(id: UUID = UUID(), interval: DateInterval, thoughts: [Thought], request: ReviewSummaryRequest) {
        self.id = id; self.interval = interval; self.thoughts = thoughts; self.request = request
    }
}

public enum WeeklyReviewPeriod {
    public static func completedWeek(before date: Date, calendar: Calendar = .current) -> DateInterval {
        let currentStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .weekOfYear, value: -1, to: currentStart)!
        return DateInterval(start: start, end: currentStart)
    }

    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? ThoughtReviewPeriod.day(containing: date, calendar: calendar)
    }
}

public enum WeeklySummaryPrompt {
    public static let version = 1
    public static func make(thoughts: [Thought], calendar: Calendar) throws -> String {
        guard !thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "MM/dd(E) HH:mm"
        let body = thoughts.enumerated().map { "Thought \($0.offset + 1) [\(formatter.string(from: $0.element.createdAt))]\n\($0.element.body)" }.joined(separator: "\n\n")
        return """
        以下は完了した1週間にユーザー本人が記録したHuman Thoughtです。この一週間に何を考え、関心や考え方がどう動いたかを理解できる週間サマリーを作成してください。
        入力にない事情、感情、性格、生活習慣を推測で断定しないでください。助言や次週の行動計画は作らず、過去の理解に限定してください。繰り返しや変化は十分な根拠がある場合だけ述べてください。
        全体を日本語1,200〜2,000文字程度に収め、JSON以外を出力せず、次のキーを必ず含めてください。
        {"overview":"","themes":[],"changes":[],"recurringTopics":[],"thoughtDevelopments":[],"notableThoughts":[],"unresolvedQuestions":[]}

        Human Thought（古い順）:
        \(body)
        """
    }
}

public struct PrepareWeeklySummary: Sendable {
    private let repository: any ThoughtRepository
    public init(repository: any ThoughtRepository) { self.repository = repository }
    public func callAsFunction(interval: DateInterval, calendar: Calendar = .current) throws -> WeeklySummaryPreview {
        let thoughts = try repository.fetchHumanThoughts(from: interval.start, to: interval.end)
        guard !thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let request = ReviewSummaryRequest(prompt: try WeeklySummaryPrompt.make(thoughts: thoughts, calendar: calendar), usageContext: .init(feature: .weeklySummary), provider: .openAI, generationProfile: .weeklySummary, model: ReviewSummaryAIConfiguration.weeklyReviewModelName)
        return WeeklySummaryPreview(interval: interval, thoughts: thoughts, request: request)
    }
}

public struct GenerateWeeklySummary: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any WeeklyReviewRepository
    private let usage: AIAPIUsageRecorder?
    public init(client: any ReviewSummaryClient, repository: any WeeklyReviewRepository, usageRepository: (any AIAPIUsageRepository)? = nil) {
        self.client = client; self.repository = repository; usage = usageRepository.map { AIAPIUsageRecorder(repository: $0) }
    }
    public func callAsFunction(preview: WeeklySummaryPreview, now: Date = Date()) async throws -> WeeklySummary {
        let finish: @Sendable (ReviewSummaryResponse) async throws -> WeeklySummary = { response in
            let content = try decodeJSON(WeeklySummaryContent.self, from: response.text)
            let summary = WeeklySummary(weekStart: preview.interval.start, weekEnd: preview.interval.end, content: content, createdAt: now, provider: response.provider, model: response.model, promptVersion: WeeklySummaryPrompt.version, thoughtCount: preview.thoughts.count)
            try repository.saveWeeklySummary(summary)
            return summary
        }
        if let usage { return try await usage.call(client: client, request: preview.request, finish: finish) }
        let response = try await client.generateSummary(preview.request)
        return try await finish(response)
    }
}

public struct WeeklyPlanDraft: Equatable, Sendable {
    public let sourceSummary: WeeklySummary
    public let targetInterval: DateInterval
    public let content: WeeklyPlanContent
    public let provider: String
    public let model: String
}

public enum WeeklyPlanPrompt {
    public static let version = 1
    public static func make(summary: WeeklySummary) throws -> String {
        let data = try JSONEncoder().encode(summary.content)
        guard let json = String(data: data, encoding: .utf8) else { throw ReviewSummaryError.emptyResponse }
        return """
        以下はユーザーが確認する週間サマリーです。次の一週間をユーザー自身が決めるための短い候補を作ってください。命令や断定を避け、サマリーに根拠のある選択肢だけを提示してください。
        focusは1つ、actionsとquestionsは各最大3つ、全体を日本語500〜1,000文字程度にしてください。JSON以外を出力せず、次のキーを必ず含めてください。
        {"focus":"","actions":[],"questions":[],"note":""}

        週間サマリー:
        \(json)
        """
    }
}

public struct GenerateWeeklyPlanDraft: Sendable {
    private let client: any ReviewSummaryClient
    private let usage: AIAPIUsageRecorder?
    public init(client: any ReviewSummaryClient, usageRepository: (any AIAPIUsageRepository)? = nil) { self.client = client; usage = usageRepository.map { AIAPIUsageRecorder(repository: $0) } }
    public func callAsFunction(summary: WeeklySummary) async throws -> WeeklyPlanDraft {
        let request = ReviewSummaryRequest(prompt: try WeeklyPlanPrompt.make(summary: summary), usageContext: .init(feature: .weeklyPlan), provider: .openAI, generationProfile: .weeklyPlan, model: ReviewSummaryAIConfiguration.weeklyReviewModelName)
        let targetStart = summary.weekEnd
        let targetEnd = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: targetStart)!
        let finish: @Sendable (ReviewSummaryResponse) async throws -> WeeklyPlanDraft = { response in
            let decoded = try decodeJSON(WeeklyPlanContent.self, from: response.text)
            let content = WeeklyPlanContent(
                focus: decoded.focus.trimmingCharacters(in: .whitespacesAndNewlines),
                actions: decoded.actions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                questions: decoded.questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                note: decoded.note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard !content.focus.isEmpty else { throw ReviewSummaryError.emptyResponse }
            return WeeklyPlanDraft(sourceSummary: summary, targetInterval: .init(start: targetStart, end: targetEnd), content: content, provider: response.provider, model: response.model)
        }
        if let usage { return try await usage.call(client: client, request: request, finish: finish) }
        let response = try await client.generateSummary(request)
        return try await finish(response)
    }
}

private func decodeJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
    let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let json = raw.hasPrefix("```") ? raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines) : raw
    guard let data = json.data(using: .utf8) else { throw ReviewSummaryError.emptyResponse }
    return try JSONDecoder().decode(type, from: data)
}
