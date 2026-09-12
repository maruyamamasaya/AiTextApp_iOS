import Foundation

/// The canonical, human-authored text. AI-derived metadata belongs in separate models.
public struct Thought: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}

public enum PersonaKind: String, Codable, Sendable {
    case human
    case ai
}

/// Timeline actors share one durable identity regardless of whether they are human or AI.
public typealias ActorType = PersonaKind
public typealias Actor = Persona

public enum ActorHandle {
    public static let minimumLength = 3
    public static let maximumLength = 30

    public static func normalize(_ value: String) -> String? {
        let normalized = value.lowercased()
        guard (minimumLength...maximumLength).contains(normalized.count),
              normalized.unicodeScalars.allSatisfy({
                  ($0.value >= 97 && $0.value <= 122) ||
                  ($0.value >= 48 && $0.value <= 57) || $0.value == 95
              }) else { return nil }
        return normalized
    }
}

public struct Persona: Identifiable, Equatable, Sendable {
    public static let defaultHumanID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public let id: UUID
    public var displayName: String
    public var handle: String
    public let kind: PersonaKind
    public var iconData: Data?
    public var iconMIMEType: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), displayName: String, handle: String? = nil, kind: PersonaKind, iconData: Data? = nil, iconMIMEType: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        let fallback = id == Self.defaultHumanID ? "myself" : "\(kind.rawValue)_\(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased())"
        self.handle = ActorHandle.normalize(handle ?? fallback) ?? (handle ?? fallback).lowercased()
        self.kind = kind
        self.iconData = iconData
        self.iconMIMEType = iconMIMEType
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}

public protocol PersonaRepository: Sendable {
    func fetchDefaultHumanPersona() throws -> Persona
    func fetchPersonas(includeInactive: Bool) throws -> [Persona]
    func fetchPersona(for thoughtID: UUID) throws -> Persona?
    func fetchPersonas(for thoughtIDs: [UUID]) throws -> [UUID: Persona]
    func createPersona(_ persona: Persona) throws
    func updatePersona(_ persona: Persona) throws
    @discardableResult func deactivatePersona(id: UUID, at date: Date) throws -> Bool
}

public protocol AuthoredThoughtRepository: Sendable {
    func create(_ thought: Thought, authorPersonaID: UUID) throws
}

public struct ThoughtMention: Equatable, Sendable {
    public let thoughtID: UUID
    public let personaID: UUID
    public let handleSnapshot: String
    public let rangeLocation: Int
    public let rangeLength: Int
    public let createdAt: Date
    public init(thoughtID: UUID, personaID: UUID, handleSnapshot: String, rangeLocation: Int, rangeLength: Int, createdAt: Date = Date()) { self.thoughtID = thoughtID; self.personaID = personaID; self.handleSnapshot = handleSnapshot; self.rangeLocation = rangeLocation; self.rangeLength = rangeLength; self.createdAt = createdAt }
}

public protocol ThoughtMentionRepository: Sendable {
    func create(_ thought: Thought, authorPersonaID: UUID, mentionedPersonaID: UUID?) throws
    func fetchMentionedPersonas(for thoughtIDs: [UUID]) throws -> [UUID: Persona]
    func create(_ thought: Thought, authorPersonaID: UUID, mentions: [ThoughtMention]) throws
    func fetchMentions(for thoughtIDs: [UUID]) throws -> [UUID: [ThoughtMention]]
}

public struct AIPersonaConfiguration: Equatable, Sendable {
    public let personaID: UUID
    public var role: String
    public var instructions: String
    public var autoReplyEnabled: Bool
    public var provider: AIProvider
    public var updatedAt: Date

    public init(personaID: UUID, role: String, instructions: String, autoReplyEnabled: Bool = true, provider: AIProvider = .gemini, updatedAt: Date = Date()) {
        self.personaID = personaID; self.role = role; self.instructions = instructions; self.autoReplyEnabled = autoReplyEnabled; self.provider = provider; self.updatedAt = updatedAt
    }
}

public struct AIPostGeneration: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case standalone, reply }
    public let thoughtID: UUID
    public let personaID: UUID
    public let userRequest: String
    public let provider: String
    public let model: String
    public let promptVersion: Int
    public let generatedAt: Date
    public let kind: Kind
    public let replyTargetThoughtID: UUID?

    public init(thoughtID: UUID, personaID: UUID, userRequest: String, provider: String, model: String, promptVersion: Int, generatedAt: Date, kind: Kind = .standalone, replyTargetThoughtID: UUID? = nil) {
        self.thoughtID = thoughtID; self.personaID = personaID; self.userRequest = userRequest; self.provider = provider; self.model = model; self.promptVersion = promptVersion; self.generatedAt = generatedAt; self.kind = kind; self.replyTargetThoughtID = replyTargetThoughtID
    }
}

public protocol AIPersonaRepository: Sendable {
    func fetchAIConfigurations() throws -> [UUID: AIPersonaConfiguration]
    func saveAIConfiguration(_ configuration: AIPersonaConfiguration) throws
    func createAIPersona(_ persona: Persona, configuration: AIPersonaConfiguration) throws
    func saveGeneratedThought(_ thought: Thought, authorPersonaID: UUID, generation: AIPostGeneration) throws
}

public struct AIReplyContextEntry: Equatable, Sendable {
    public let thought: Thought
    public let author: Persona
    public init(thought: Thought, author: Persona) { self.thought = thought; self.author = author }
}

public struct AIReplyContext: Equatable, Sendable {
    public let entries: [AIReplyContextEntry]
    public let targetThoughtID: UUID
    /// Exact reply edges traversed while building the context, used for stale-preview checks.
    public let relations: [ThoughtRelation]
    public init(entries: [AIReplyContextEntry], targetThoughtID: UUID, relations: [ThoughtRelation]) { self.entries = entries; self.targetThoughtID = targetThoughtID; self.relations = relations }
}

public protocol AIReplyContextRepository: Sendable {
    func loadAIReplyContext(targetThoughtID: UUID, maximumEntries: Int) throws -> AIReplyContext
}

public protocol AIThoughtReplyRepository: AIReplyContextRepository {
    func fetchActiveAIReplyPersona(id: UUID) throws -> Persona?
    func saveGeneratedReply(_ thought: Thought, authorPersonaID: UUID, targetThoughtID: UUID, generation: AIPostGeneration, relationID: UUID) throws
    func fetchAIReplies(to thoughtID: UUID) throws -> [Thought]
    func fetchReplyTargets(for thoughtIDs: [UUID]) throws -> [UUID: UUID]
    func fetchAIPostGeneration(for thoughtID: UUID) throws -> AIPostGeneration?
    func fetchRecentAIStatements(personaID: UUID, limit: Int) throws -> [Thought]
}

public struct AIThoughtReplyPreview: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let persona: Persona
    public let configuration: AIPersonaConfiguration
    public let targetThought: Thought
    public let userRequest: String
    public let context: AIReplyContext
    public let externalBrain: ExternalBrainContext?
    public let personaStatements: [Thought]
    public let request: ReviewSummaryRequest
}

public enum AIThoughtReplyPrompt {
    public static let version = 2
    public static let maximumContextEntries = 5
    public static func prepare(persona: Persona, configuration: AIPersonaConfiguration, targetThought: Thought, userRequest: String, context: AIReplyContext, externalBrain: ExternalBrainContext? = nil, personaStatements: [Thought] = []) throws -> AIThoughtReplyPreview {
        guard persona.kind == .ai, persona.deletedAt == nil else { throw AIPostError.inactivePersona }
        guard targetThought.deletedAt == nil else { throw AIPostError.invalidRequest }
        guard !targetThought.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIPostError.invalidRequest }
        let normalizedRequest = userRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRequest.isEmpty, context.targetThoughtID == targetThought.id,
              context.entries.last?.thought == targetThought else { throw AIPostError.invalidRequest }
        guard !configuration.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !configuration.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIPostError.missingConfiguration }
        let contextText = context.entries.enumerated().map { index, entry in
            let kind = entry.author.kind == .human ? "Human" : "AI"
            return "\(index + 1). [\(kind): \(entry.author.displayName)]\n\(entry.thought.body)"
        }.joined(separator: "\n\n")
        let target = context.entries.last!
        let targetKind = target.author.kind == .human ? "Human" : "AI"
        let externalRole = externalBrain.map { "\nExternal Brain上のRole: \($0.role)" } ?? ""
        let brainSection = externalBrain?.promptSection ?? "--- External Brain ---\n利用なし"
        let statements = personaStatements.isEmpty ? "（過去の発言なし）" : personaStatements.map { "- \($0.body)" }.joined(separator: "\n")
        let prompt = """
        --- Persona Role / Instructions ---
        あなたはプライベートなThought Timelineへ参加するAI Personaです。
        Persona名: \(persona.displayName)
        役割: \(configuration.role)\(externalRole)
        指示: \(configuration.instructions)
        project固有のdecision、local rule、user固有情報は、一般論より優先してください。

        \(brainSection)

        --- Persona自身の最近の発言 ---
        \(statements)

        --- Reply Context ---
        \(contextText)

        返信対象:
        \(context.entries.count). [\(targetKind): \(target.author.displayName)]
        \(targetThought.body)

        --- User Request ---
        \(normalizedRequest)

        --- Output Rules ---
        このThoughtに対する返信を日本語140文字以内で返してください。前置き、引用符、Markdown、文字数説明は不要です。
        """
        return AIThoughtReplyPreview(persona: persona, configuration: configuration, targetThought: targetThought, userRequest: normalizedRequest, context: context, externalBrain: externalBrain, personaStatements: personaStatements, request: ReviewSummaryRequest(prompt: prompt, usageContext: .init(feature: .thoughtReply, personaID: persona.id, externalBrainUsed: externalBrain != nil, retrievedChunkCount: externalBrain?.chunks.count ?? 0), provider: configuration.provider))
    }
}

public struct AIThoughtReplyDraft: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let preview: AIThoughtReplyPreview
    public let body: String
    public let provider: String
    public let model: String
    public init(preview: AIThoughtReplyPreview, body: String, provider: String, model: String) { self.preview = preview; self.body = body; self.provider = provider; self.model = model }
}

public struct GenerateAIThoughtReply: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any AIThoughtReplyRepository
    private let usage: AIAPIUsageRecorder?
    public init(client: any ReviewSummaryClient, repository: any AIThoughtReplyRepository, usageRepository: (any AIAPIUsageRepository)? = nil) { self.client = client; self.repository = repository; usage = usageRepository.map { AIAPIUsageRecorder(repository: $0) } }
    public func generate(preview: AIThoughtReplyPreview) async throws -> AIThoughtReplyDraft {
        guard try repository.fetchActiveAIReplyPersona(id: preview.persona.id) == preview.persona else { throw AIPostError.inactivePersona }
        for reply in try repository.fetchAIReplies(to: preview.targetThought.id) {
            if let generation = try repository.fetchAIPostGeneration(for: reply.id), generation.kind == .reply, generation.personaID == preview.persona.id { throw AIPostError.duplicateReply }
        }
        let currentContext = try repository.loadAIReplyContext(targetThoughtID: preview.targetThought.id, maximumEntries: AIThoughtReplyPrompt.maximumContextEntries)
        guard currentContext == preview.context else { throw ReviewSummaryError.stalePreview }
        let finish: @Sendable (ReviewSummaryResponse) async throws -> AIThoughtReplyDraft = { response in
            let body = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { throw AIPostError.emptyResponse }
            guard body.count <= ThoughtDraft.characterLimit else { throw AIPostError.responseTooLong }
            return AIThoughtReplyDraft(preview: preview, body: body, provider: response.provider, model: response.model)
        }
        if let usage { return try await usage.call(client: client, request: preview.request, finish: finish) }
        return try await finish(try await client.generateSummary(preview.request))
    }
    public func publish(draft: AIThoughtReplyDraft, now: Date = Date(), thoughtID: UUID = UUID(), relationID: UUID = UUID()) throws -> Thought {
        guard try repository.fetchActiveAIReplyPersona(id: draft.preview.persona.id) == draft.preview.persona else { throw AIPostError.inactivePersona }
        let thought = Thought(id: thoughtID, body: draft.body, createdAt: now)
        let generation = AIPostGeneration(thoughtID: thoughtID, personaID: draft.preview.persona.id, userRequest: draft.preview.userRequest, provider: draft.provider, model: draft.model, promptVersion: AIThoughtReplyPrompt.version, generatedAt: now, kind: .reply, replyTargetThoughtID: draft.preview.targetThought.id)
        try repository.saveGeneratedReply(thought, authorPersonaID: draft.preview.persona.id, targetThoughtID: draft.preview.targetThought.id, generation: generation, relationID: relationID)
        return thought
    }
    public func callAsFunction(preview: AIThoughtReplyPreview, now: Date = Date(), thoughtID: UUID = UUID(), relationID: UUID = UUID()) async throws -> Thought {
        try publish(draft: try await generate(preview: preview), now: now, thoughtID: thoughtID, relationID: relationID)
    }
}

public struct AIPostPreview: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let persona: Persona
    public let configuration: AIPersonaConfiguration
    public let userRequest: String
    public let externalBrain: ExternalBrainContext?
    public let request: ReviewSummaryRequest
}

public enum AIPostError: Error, LocalizedError, Equatable {
    case invalidRequest, inactivePersona, missingConfiguration, emptyResponse, responseTooLong, duplicateReply
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: "AIへの依頼を入力してください。"
        case .inactivePersona: "このAI Personaは利用できません。"
        case .missingConfiguration: "AI Personaの役割と指示を設定してください。"
        case .emptyResponse: "AIから空の応答が返されました。"
        case .responseTooLong: "AIの応答が140文字を超えたため投稿しませんでした。"
        case .duplicateReply: "このReplyへのAI返信は生成済みです。"
        }
    }
}

public enum AIPostPrompt {
    public static let version = 2
    public static func prepare(persona: Persona, configuration: AIPersonaConfiguration, userRequest: String, externalBrain: ExternalBrainContext? = nil) throws -> AIPostPreview {
        let request = userRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { throw AIPostError.invalidRequest }
        guard persona.kind == .ai, persona.deletedAt == nil else { throw AIPostError.inactivePersona }
        guard !configuration.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !configuration.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIPostError.missingConfiguration }
        let externalRole = externalBrain.map { "\nExternal Brain上のRole: \($0.role)" } ?? ""
        let brainSection = externalBrain?.promptSection ?? "--- External Brain ---\n利用なし"
        let prompt = """
        あなたはプライベートなThought Timelineへ参加するAI Personaです。
        Persona名: \(persona.displayName)
        役割: \(configuration.role)\(externalRole)
        指示: \(configuration.instructions)
        project固有のdecision、local rule、user固有情報は、一般論より優先してください。

        \(brainSection)

        ユーザーの依頼: \(request)

        日本語で140文字以内の投稿本文だけを返してください。前置き、引用符、Markdown、文字数の説明は付けないでください。
        """
        return AIPostPreview(persona: persona, configuration: configuration, userRequest: request, externalBrain: externalBrain, request: ReviewSummaryRequest(prompt: prompt, usageContext: .init(feature: .personaPost, personaID: persona.id, externalBrainUsed: externalBrain != nil, retrievedChunkCount: externalBrain?.chunks.count ?? 0), provider: configuration.provider))
    }
}

public struct GenerateAIPost: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any AIPersonaRepository
    private let usage: AIAPIUsageRecorder?
    public init(client: any ReviewSummaryClient, repository: any AIPersonaRepository, usageRepository: (any AIAPIUsageRepository)? = nil) { self.client = client; self.repository = repository; usage = usageRepository.map { AIAPIUsageRecorder(repository: $0) } }
    public func callAsFunction(preview: AIPostPreview, now: Date = Date(), thoughtID: UUID = UUID()) async throws -> Thought {
        let finish: @Sendable (ReviewSummaryResponse) async throws -> Thought = { response in
        let body = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw AIPostError.emptyResponse }
        guard body.count <= ThoughtDraft.characterLimit else { throw AIPostError.responseTooLong }
        let thought = Thought(id: thoughtID, body: body, createdAt: now)
        let generation = AIPostGeneration(thoughtID: thoughtID, personaID: preview.persona.id, userRequest: preview.userRequest, provider: response.provider, model: response.model, promptVersion: AIPostPrompt.version, generatedAt: now)
        try repository.saveGeneratedThought(thought, authorPersonaID: preview.persona.id, generation: generation)
        return thought
        }
        if let usage { return try await usage.call(client: client, request: preview.request, finish: finish) }
        let response = try await client.generateSummary(preview.request)
        return try await finish(response)
    }
}
