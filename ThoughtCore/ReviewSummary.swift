import Foundation

public struct ReviewSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let periodStart: Date
    public let periodEnd: Date
    public let content: String
    public let createdAt: Date
    public let provider: String
    public let model: String
    public let promptVersion: Int
    public let thoughtCount: Int

    public init(
        id: UUID = UUID(),
        periodStart: Date,
        periodEnd: Date,
        content: String,
        createdAt: Date = Date(),
        provider: String,
        model: String,
        promptVersion: Int,
        thoughtCount: Int
    ) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.content = content
        self.createdAt = createdAt
        self.provider = provider
        self.model = model
        self.promptVersion = promptVersion
        self.thoughtCount = thoughtCount
    }
}

public protocol ReviewSummaryRepository: Sendable {
    func save(_ summary: ReviewSummary) throws
    func fetchSummaries(from startDate: Date, to endDate: Date) throws -> [ReviewSummary]
}

public struct ReviewSummaryRequest: Equatable, Sendable {
    public let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

public struct ReviewSummaryResponse: Equatable, Sendable {
    public let text: String
    public let provider: String
    public let model: String

    public init(text: String, provider: String, model: String) {
        self.text = text
        self.provider = provider
        self.model = model
    }
}

public protocol ReviewSummaryClient: Sendable {
    func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse
}

public enum ReviewSummaryError: Error, LocalizedError, Equatable {
    case noThoughts
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .noThoughts: "要約するThoughtがありません。"
        case .emptyResponse: "AIから要約文を取得できませんでした。"
        }
    }
}

public enum ReviewSummaryPrompt {
    public static let version = 1

    /// Only Thought bodies are included as user data. UUIDs, database metadata,
    /// app state, relation data, and other internal information are omitted.
    public static func make(thoughts: [Thought]) throws -> String {
        guard !thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let bodies = thoughts.enumerated().map { index, thought in
            "\(index + 1). \(thought.body)"
        }.joined(separator: "\n")
        return """
        以下は利用者が選択した期間の短いメモです。記載内容だけを根拠に、日本語で簡潔に要約してください。
        推測で個人情報を補わず、診断や断定を避けてください。
        次の3項目を各1〜3文で出力してください。

        主な話題:
        流れ:
        気づき:

        メモ（古い順）:
        \(bodies)
        """
    }
}

public struct GenerateReviewSummary: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any ReviewSummaryRepository

    public init(client: any ReviewSummaryClient, repository: any ReviewSummaryRepository) {
        self.client = client
        self.repository = repository
    }

    public func callAsFunction(
        thoughts: [Thought],
        interval: DateInterval,
        now: Date = Date()
    ) async throws -> ReviewSummary {
        let prompt = try ReviewSummaryPrompt.make(thoughts: thoughts)
        let response = try await client.generateSummary(.init(prompt: prompt))
        let content = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw ReviewSummaryError.emptyResponse }
        let summary = ReviewSummary(
            periodStart: interval.start,
            periodEnd: interval.end,
            content: content,
            createdAt: now,
            provider: response.provider,
            model: response.model,
            promptVersion: ReviewSummaryPrompt.version,
            thoughtCount: thoughts.count
        )
        try repository.save(summary)
        return summary
    }
}

public struct MockReviewSummaryClient: ReviewSummaryClient, @unchecked Sendable {
    public var result: Result<ReviewSummaryResponse, Error>

    public init(text: String = "主な話題: 日々のThoughtの振り返り\n\n流れ: 記録を重ねながら、次の行動を考えています。\n\n気づき: 小さな変化を継続して見返すことが役立ちそうです。") {
        result = .success(.init(text: text, provider: "mock", model: "mock-review-summary-v1"))
    }

    public init(error: Error) {
        result = .failure(error)
    }

    public func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse {
        try result.get()
    }
}
