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
    func fetchSummary(id: UUID) throws -> ReviewSummary?
    func fetchSummaries(from startDate: Date, to endDate: Date) throws -> [ReviewSummary]
    /// Deletes exactly one derived summary by its unique identifier.
    @discardableResult func deleteSummary(id: UUID) throws -> Bool
}

public struct ReviewSummaryRequest: Equatable, Sendable {
    public let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

public struct ReviewSummaryPreview: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let interval: DateInterval
    public let thoughts: [Thought]
    public let request: ReviewSummaryRequest

    public init(
        id: UUID = UUID(),
        interval: DateInterval,
        thoughts: [Thought],
        request: ReviewSummaryRequest
    ) {
        self.id = id
        self.interval = interval
        self.thoughts = thoughts
        self.request = request
    }

    public var thoughtCount: Int { thoughts.count }
    public var payloadCharacterCount: Int { request.prompt.count }
    public var thoughtCharacterCount: Int { thoughts.reduce(0) { $0 + $1.body.count } }
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

public enum ReviewSummaryAIConfiguration {
    public static let providerName = "firebase-ai-logic"
    public static let modelName = "gemini-3.7-flash"
}

public enum ReviewSummaryServiceError: Error, LocalizedError, Equatable, Sendable {
    case firebaseNotConfigured
    case appCheck
    case rateLimited
    case network
    case api

    public var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            "Firebaseが未設定です。GoogleService-Info.plistとFirebase設定を確認してください。"
        case .appCheck:
            "App Checkを確認できませんでした。設定またはDebug tokenを確認してください。"
        case .rateLimited:
            "AI要約の利用上限に達しました。時間をおいて再試行してください。"
        case .network:
            "ネットワークに接続できません。通信状態を確認してください。"
        case .api:
            "AIサービスでエラーが発生しました。時間をおいて再試行してください。"
        }
    }

    public static func classify(domain: String, code: Int, description: String) -> Self {
        let domain = domain.lowercased()
        let description = description.lowercased()
        if domain.contains("appcheck") || description.contains("app check") ||
            description.contains("appcheck") || description.contains("attest") {
            return .appCheck
        }
        if code == 429 || description.contains("resource_exhausted") ||
            description.contains("quota") || description.contains("rate limit") {
            return .rateLimited
        }
        if domain == NSURLErrorDomain.lowercased() {
            return .network
        }
        if description.contains("googleservice-info") ||
            description.contains("firebase app has not been configured") {
            return .firebaseNotConfigured
        }
        return .api
    }
}

public protocol ReviewSummaryGeneratingTransport: Sendable {
    func generateContent(prompt: String, modelName: String) async throws -> String?
}

/// Provider-independent client logic around the Firebase AI Logic transport.
/// The transport is the only layer that imports the Firebase SDK.
public struct FirebaseReviewSummaryClient: ReviewSummaryClient {
    private let transport: any ReviewSummaryGeneratingTransport
    public let modelName: String

    public init(
        transport: any ReviewSummaryGeneratingTransport,
        modelName: String = ReviewSummaryAIConfiguration.modelName
    ) {
        self.transport = transport
        self.modelName = modelName
    }

    public func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse {
        guard let text = try await transport.generateContent(
            prompt: request.prompt,
            modelName: modelName
        ) else {
            throw ReviewSummaryError.emptyResponse
        }
        return ReviewSummaryResponse(
            text: text,
            provider: ReviewSummaryAIConfiguration.providerName,
            model: modelName
        )
    }
}

public struct UnavailableReviewSummaryClient: ReviewSummaryClient {
    public let error: ReviewSummaryServiceError

    public init(error: ReviewSummaryServiceError) {
        self.error = error
    }

    public func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse {
        throw error
    }
}

public enum ReviewSummaryError: Error, LocalizedError, Equatable {
    case noThoughts
    case emptyResponse
    case stalePreview

    public var errorDescription: String? {
        switch self {
        case .noThoughts: "要約するThoughtがありません。"
        case .emptyResponse: "AIから要約文を取得できませんでした。"
        case .stalePreview: "確認後にThoughtが変更されました。"
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

public struct PrepareReviewSummary: Sendable {
    private let repository: any ThoughtRepository

    public init(repository: any ThoughtRepository) {
        self.repository = repository
    }

    /// Fetches the active Thoughts for the exact Review interval and freezes the
    /// final request used by both the preview screen and the AI submission.
    public func callAsFunction(interval: DateInterval) throws -> ReviewSummaryPreview {
        let thoughts = try repository.fetchThoughts(from: interval.start, to: interval.end)
        let prompt = try ReviewSummaryPrompt.make(thoughts: thoughts)
        return ReviewSummaryPreview(
            interval: interval,
            thoughts: thoughts,
            request: ReviewSummaryRequest(prompt: prompt)
        )
    }
}

public struct ValidateReviewSummaryPreview: Sendable {
    private let repository: any ThoughtRepository

    public init(repository: any ThoughtRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ preview: ReviewSummaryPreview) throws {
        let current = try repository.fetchThoughts(
            from: preview.interval.start,
            to: preview.interval.end
        )
        guard current == preview.thoughts else { throw ReviewSummaryError.stalePreview }
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
        preview: ReviewSummaryPreview,
        now: Date = Date()
    ) async throws -> ReviewSummary {
        guard !preview.thoughts.isEmpty else { throw ReviewSummaryError.noThoughts }
        let response = try await client.generateSummary(preview.request)
        let content = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw ReviewSummaryError.emptyResponse }
        let summary = ReviewSummary(
            periodStart: preview.interval.start,
            periodEnd: preview.interval.end,
            content: content,
            createdAt: now,
            provider: response.provider,
            model: response.model,
            promptVersion: ReviewSummaryPrompt.version,
            thoughtCount: preview.thoughtCount
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
