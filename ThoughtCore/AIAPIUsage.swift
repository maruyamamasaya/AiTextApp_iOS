import Foundation

public enum AIAPIFeature: String, CaseIterable, Codable, Sendable {
    case personaPost
    case thoughtReply
    case dailySummary
    case knowledgeDraft

    public var displayName: String {
        switch self {
        case .personaPost: "AI Persona Post"
        case .thoughtReply: "AI Reply"
        case .dailySummary: "Daily Summary"
        case .knowledgeDraft: "Knowledge Draft"
        }
    }
}

public enum AIAPICallStatus: String, Codable, Sendable {
    case success, failed, cancelled
}

public enum AIAPIErrorCategory: String, Codable, Sendable {
    case network, timeout, rateLimit = "rate_limit", quota, appCheck = "app_check"
    case firebaseNotConfigured = "firebase_not_configured"
    case emptyResponse = "empty_response", invalidResponse = "invalid_response"
    case responseTooLong = "response_too_long", unknown

    public static func classify(_ error: Error) -> Self {
        if error is CancellationError { return .unknown }
        if let value = error as? ReviewSummaryServiceError {
            switch value {
            case .firebaseNotConfigured: return .firebaseNotConfigured
            case .appCheck: return .appCheck
            case .rateLimited: return .rateLimit
            case .network: return .network
            case .api: return .unknown
            }
        }
        if let value = error as? ReviewSummaryError {
            switch value {
            case .emptyResponse: return .emptyResponse
            default: return .invalidResponse
            }
        }
        if let value = error as? AIPostError {
            switch value {
            case .emptyResponse: return .emptyResponse
            case .responseTooLong: return .responseTooLong
            default: return .invalidResponse
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == NSURLErrorTimedOut ? .timeout : .network
        }
        return .unknown
    }
}

public struct AIAPITokenUsage: Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public init(inputTokens: Int? = nil, outputTokens: Int? = nil, totalTokens: Int? = nil) { self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.totalTokens = totalTokens }
}

public struct AIAPIUsageContext: Equatable, Sendable {
    public let feature: AIAPIFeature
    public let personaID: UUID?
    public let externalBrainUsed: Bool
    public let retrievedChunkCount: Int
    public let sourceType: KnowledgeDraftSource?

    public init(feature: AIAPIFeature, personaID: UUID? = nil, externalBrainUsed: Bool = false, retrievedChunkCount: Int = 0, sourceType: KnowledgeDraftSource? = nil) {
        self.feature = feature
        self.personaID = personaID
        self.externalBrainUsed = externalBrainUsed
        self.retrievedChunkCount = max(0, retrievedChunkCount)
        self.sourceType = sourceType
    }
}

public struct AIAPIUsageRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date?
    public let feature: AIAPIFeature
    public let personaID: UUID?
    public let provider: String
    public let model: String
    public let status: AIAPICallStatus
    public let inputCharacters: Int
    public let outputCharacters: Int
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let latencyMilliseconds: Int?
    public let externalBrainUsed: Bool
    public let retrievedChunkCount: Int
    public let errorCategory: AIAPIErrorCategory?
    public let sourceType: KnowledgeDraftSource?

    public init(id: UUID = UUID(), startedAt: Date, finishedAt: Date? = nil, feature: AIAPIFeature, personaID: UUID? = nil, provider: String, model: String, status: AIAPICallStatus, inputCharacters: Int, outputCharacters: Int, inputTokens: Int? = nil, outputTokens: Int? = nil, totalTokens: Int? = nil, latencyMilliseconds: Int? = nil, externalBrainUsed: Bool = false, retrievedChunkCount: Int = 0, errorCategory: AIAPIErrorCategory? = nil, sourceType: KnowledgeDraftSource? = nil) {
        self.id = id; self.startedAt = startedAt; self.finishedAt = finishedAt; self.feature = feature
        self.personaID = personaID; self.provider = provider; self.model = model; self.status = status
        self.inputCharacters = inputCharacters; self.outputCharacters = outputCharacters
        self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.totalTokens = totalTokens
        self.latencyMilliseconds = latencyMilliseconds; self.externalBrainUsed = externalBrainUsed
        self.retrievedChunkCount = max(0, retrievedChunkCount); self.errorCategory = errorCategory
        self.sourceType = sourceType
    }
}

public protocol AIAPIUsageRepository: Sendable { func saveUsage(_ record: AIAPIUsageRecord) throws }
public protocol AIAPIUsageAnalyticsRepository: Sendable {
    func fetchUsage(from start: Date?, to end: Date?) throws -> [AIAPIUsageRecord]
}

public enum AIAPIUsagePeriod: String, CaseIterable, Sendable {
    case today, sevenDays, thirtyDays, allTime
    public var displayName: String { switch self { case .today: "今日"; case .sevenDays: "過去7日"; case .thirtyDays: "過去30日"; case .allTime: "全期間" } }
    public func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard self != .allTime else { return nil }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let days = self == .today ? 1 : (self == .sevenDays ? 7 : 30)
        return DateInterval(start: calendar.date(byAdding: .day, value: -days, to: end)!, end: end)
    }
}

public struct AIAPIUsageCount: Identifiable, Equatable, Sendable { public let id: String; public let name: String; public let calls, successes, failures: Int }
public struct AIAPIUsageDay: Identifiable, Equatable, Sendable { public var id: Date { day }; public let day: Date; public let calls, inputCharacters, outputCharacters: Int }
public struct AIAPIUsageAnalytics: Equatable, Sendable {
    public let period: AIAPIUsagePeriod
    public let todayCallCount, sevenDayCallCount, monthCallCount: Int
    public let callCount, successCount, failedCount, cancelledCount: Int
    public let inputCharacters, outputCharacters: Int
    public let inputTokens, outputTokens: Int?
    public let tokenizedCallCount: Int
    public let averageLatencyMilliseconds: Int?
    public let externalBrainCallCount: Int
    public let externalBrainRate: Double
    public let averageRetrievedChunkCount: Double?
    public let byFeature, byPersona, byModel, byError: [AIAPIUsageCount]
    public let daily: [AIAPIUsageDay]
    public var successRate: Double { callCount == 0 ? 0 : Double(successCount) / Double(callCount) }
}

public struct LoadAIAPIUsageAnalytics: Sendable {
    private let repository: any AIAPIUsageAnalyticsRepository
    private let personas: (any PersonaRepository)?
    private let calendar: Calendar
    public init(repository: any AIAPIUsageAnalyticsRepository, personas: (any PersonaRepository)? = nil, calendar: Calendar = .current) { self.repository = repository; self.personas = personas; self.calendar = calendar }
    public func callAsFunction(period: AIAPIUsagePeriod, now: Date = Date()) throws -> AIAPIUsageAnalytics {
        let interval = period.interval(containing: now, calendar: calendar)
        let records = try repository.fetchUsage(from: interval?.start, to: interval?.end)
        let thirtyInterval = AIAPIUsagePeriod.thirtyDays.interval(containing: now, calendar: calendar)!
        let todayStart = calendar.startOfDay(for: now)
        let sevenStart = calendar.date(byAdding: .day, value: -7, to: thirtyInterval.end)!
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
        let recent = try repository.fetchUsage(from: min(thirtyInterval.start, monthStart), to: thirtyInterval.end)
        let names = Dictionary(uniqueKeysWithValues: (try? personas?.fetchPersonas(includeInactive: true))?.map { ($0.id, $0.displayName) } ?? [])
        func counts<Key: Hashable>(_ key: (AIAPIUsageRecord) -> Key?, name: (Key) -> String) -> [AIAPIUsageCount] {
            Dictionary(grouping: records.compactMap { record in key(record).map { ($0, record) } }, by: { $0.0 }).map { key, values in
                let calls = values.map(\.1)
                return AIAPIUsageCount(id: String(describing: key), name: name(key), calls: calls.count, successes: calls.filter { $0.status == .success }.count, failures: calls.filter { $0.status == .failed }.count)
            }.sorted { $0.calls == $1.calls ? $0.name < $1.name : $0.calls > $1.calls }
        }
        let tokenized = records.filter { $0.inputTokens != nil && $0.outputTokens != nil }
        let latencies = records.compactMap(\.latencyMilliseconds)
        let brain = records.filter(\.externalBrainUsed)
        let daily = Dictionary(grouping: records, by: { calendar.startOfDay(for: $0.startedAt) }).map { day, values in AIAPIUsageDay(day: day, calls: values.count, inputCharacters: values.reduce(0) { $0 + $1.inputCharacters }, outputCharacters: values.reduce(0) { $0 + $1.outputCharacters }) }.sorted { $0.day < $1.day }
        return AIAPIUsageAnalytics(period: period, todayCallCount: recent.filter { $0.startedAt >= todayStart }.count, sevenDayCallCount: recent.filter { $0.startedAt >= sevenStart }.count, monthCallCount: recent.filter { $0.startedAt >= monthStart }.count, callCount: records.count, successCount: records.filter { $0.status == .success }.count, failedCount: records.filter { $0.status == .failed }.count, cancelledCount: records.filter { $0.status == .cancelled }.count, inputCharacters: records.reduce(0) { $0 + $1.inputCharacters }, outputCharacters: records.reduce(0) { $0 + $1.outputCharacters }, inputTokens: tokenized.isEmpty ? nil : tokenized.compactMap(\.inputTokens).reduce(0, +), outputTokens: tokenized.isEmpty ? nil : tokenized.compactMap(\.outputTokens).reduce(0, +), tokenizedCallCount: tokenized.count, averageLatencyMilliseconds: latencies.isEmpty ? nil : latencies.reduce(0, +) / latencies.count, externalBrainCallCount: brain.count, externalBrainRate: records.isEmpty ? 0 : Double(brain.count) / Double(records.count), averageRetrievedChunkCount: brain.isEmpty ? nil : Double(brain.reduce(0) { $0 + $1.retrievedChunkCount }) / Double(brain.count), byFeature: counts({ $0.feature }, name: { $0.displayName }), byPersona: counts({ $0.personaID }, name: { names[$0] ?? "削除済みPersona" }), byModel: counts({ "\($0.provider) / \($0.model)" }, name: { $0 }), byError: counts({ $0.errorCategory }, name: { $0.rawValue }), daily: daily)
    }
}

public struct AIAPIUsageRecorder: Sendable {
    private let repository: any AIAPIUsageRepository
    private let provider: String
    private let model: String
    private let now: @Sendable () -> Date
    public init(repository: any AIAPIUsageRepository, provider: String = ReviewSummaryAIConfiguration.providerName, model: String = ReviewSummaryAIConfiguration.modelName, now: @escaping @Sendable () -> Date = Date.init) { self.repository = repository; self.provider = provider; self.model = model; self.now = now }

    public func call<T: Sendable>(client: any ReviewSummaryClient, request: ReviewSummaryRequest, finish: @Sendable (ReviewSummaryResponse) async throws -> T) async throws -> T {
        guard let context = request.usageContext else {
            let response = try await client.generateSummary(request)
            return try await finish(response)
        }
        let started = now(); var responseMetadata: (String, String, Int)?
        do {
            let response = try await client.generateSummary(request)
            responseMetadata = (response.provider, response.model, response.text.count)
            let value = try await finish(response)
            let finished = now()
            save(.init(startedAt: started, finishedAt: finished, feature: context.feature, personaID: context.personaID, provider: response.provider, model: response.model, status: .success, inputCharacters: request.prompt.count, outputCharacters: response.text.count, inputTokens: response.tokenUsage?.inputTokens, outputTokens: response.tokenUsage?.outputTokens, totalTokens: response.tokenUsage?.totalTokens, latencyMilliseconds: milliseconds(started, finished), externalBrainUsed: context.externalBrainUsed, retrievedChunkCount: context.retrievedChunkCount, sourceType: context.sourceType))
            return value
        } catch {
            let finished = now(); let status: AIAPICallStatus = error is CancellationError ? .cancelled : .failed
            save(.init(startedAt: started, finishedAt: finished, feature: context.feature, personaID: context.personaID, provider: responseMetadata?.0 ?? provider, model: responseMetadata?.1 ?? model, status: status, inputCharacters: request.prompt.count, outputCharacters: responseMetadata?.2 ?? 0, latencyMilliseconds: milliseconds(started, finished), externalBrainUsed: context.externalBrainUsed, retrievedChunkCount: context.retrievedChunkCount, errorCategory: status == .failed ? .classify(error) : nil, sourceType: context.sourceType))
            throw error
        }
    }
    private func milliseconds(_ start: Date, _ end: Date) -> Int { max(0, Int((end.timeIntervalSince(start) * 1_000).rounded())) }
    private func save(_ record: AIAPIUsageRecord) { do { try repository.saveUsage(record) } catch { NSLog("AI usage telemetry save failed: %@", String(describing: type(of: error))) } }
}
