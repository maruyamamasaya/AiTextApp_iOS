import Foundation

public struct DailySummaryTagGroup: Codable, Equatable, Sendable {
    public let tagName: String
    public let summary: String
    public let themes: [String]
    public let thoughtCount: Int
    public init(tagName: String, summary: String, themes: [String], thoughtCount: Int) { self.tagName = tagName; self.summary = summary; self.themes = themes; self.thoughtCount = thoughtCount }
}

public struct DailySummaryAIInteraction: Codable, Equatable, Sendable {
    public let personaName: String
    public let topics: [String]
    public let summary: String
    public init(personaName: String, topics: [String], summary: String) { self.personaName = personaName; self.topics = topics; self.summary = summary }
}

public struct DailySummaryTimeInsight: Codable, Equatable, Sendable {
    public let period: String
    public let insight: String
    public init(period: String, insight: String) { self.period = period; self.insight = insight }
}

public struct DailySummaryThoughtTagSuggestion: Codable, Equatable, Sendable {
    public let thoughtIndex: Int
    public let thoughtID: UUID?
    public let tagName: String
    public let reason: String
    public init(thoughtIndex: Int, thoughtID: UUID? = nil, tagName: String, reason: String) { self.thoughtIndex = thoughtIndex; self.thoughtID = thoughtID; self.tagName = tagName; self.reason = reason }
}

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
    public let tagGroups: [DailySummaryTagGroup]
    public let aiInteractions: [DailySummaryAIInteraction]
    public let timeOfDayInsights: [DailySummaryTimeInsight]
    public let thoughtTagSuggestions: [DailySummaryThoughtTagSuggestion]

    public init(overview: String, themes: [String], existingTagCandidates: [String], newTagCandidates: [String], thoughtPatterns: [String], deepDives: [String], concerns: [String], thoughtFlow: String, continuationCandidates: [String], carryOvers: [String], tagGroups: [DailySummaryTagGroup] = [], aiInteractions: [DailySummaryAIInteraction] = [], timeOfDayInsights: [DailySummaryTimeInsight] = [], thoughtTagSuggestions: [DailySummaryThoughtTagSuggestion] = []) {
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
        self.tagGroups = tagGroups; self.aiInteractions = aiInteractions; self.timeOfDayInsights = timeOfDayInsights; self.thoughtTagSuggestions = thoughtTagSuggestions
    }


    private enum CodingKeys: String, CodingKey { case overview, themes, existingTagCandidates, newTagCandidates, thoughtPatterns, humanThoughtPatterns, deepDives, concerns, thoughtFlow, continuationCandidates, carryOvers, tagGroups, aiInteractions, timeOfDayInsights, thoughtTagSuggestions }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        overview = try values.decode(String.self, forKey: .overview); themes = try values.decodeIfPresent([String].self, forKey: .themes) ?? []
        existingTagCandidates = try values.decodeIfPresent([String].self, forKey: .existingTagCandidates) ?? []; newTagCandidates = try values.decodeIfPresent([String].self, forKey: .newTagCandidates) ?? []
        if let v2 = try values.decodeIfPresent([String].self, forKey: .humanThoughtPatterns) { thoughtPatterns = v2 }
        else { thoughtPatterns = try values.decodeIfPresent([String].self, forKey: .thoughtPatterns) ?? [] }
        deepDives = try values.decodeIfPresent([String].self, forKey: .deepDives) ?? []; concerns = try values.decodeIfPresent([String].self, forKey: .concerns) ?? []; thoughtFlow = try values.decodeIfPresent(String.self, forKey: .thoughtFlow) ?? ""
        continuationCandidates = try values.decodeIfPresent([String].self, forKey: .continuationCandidates) ?? []; carryOvers = try values.decodeIfPresent([String].self, forKey: .carryOvers) ?? []
        tagGroups = try values.decodeIfPresent([DailySummaryTagGroup].self, forKey: .tagGroups) ?? []; aiInteractions = try values.decodeIfPresent([DailySummaryAIInteraction].self, forKey: .aiInteractions) ?? []; timeOfDayInsights = try values.decodeIfPresent([DailySummaryTimeInsight].self, forKey: .timeOfDayInsights) ?? []
        thoughtTagSuggestions = try values.decodeIfPresent([DailySummaryThoughtTagSuggestion].self, forKey: .thoughtTagSuggestions) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(overview, forKey: .overview); try values.encode(themes, forKey: .themes); try values.encode(existingTagCandidates, forKey: .existingTagCandidates); try values.encode(newTagCandidates, forKey: .newTagCandidates); try values.encode(thoughtPatterns, forKey: .humanThoughtPatterns); try values.encode(deepDives, forKey: .deepDives); try values.encode(concerns, forKey: .concerns); try values.encode(thoughtFlow, forKey: .thoughtFlow); try values.encode(continuationCandidates, forKey: .continuationCandidates); try values.encode(carryOvers, forKey: .carryOvers); try values.encode(tagGroups, forKey: .tagGroups); try values.encode(aiInteractions, forKey: .aiInteractions); try values.encode(timeOfDayInsights, forKey: .timeOfDayInsights); try values.encode(thoughtTagSuggestions, forKey: .thoughtTagSuggestions)
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
    public let inputs: [DailySummaryThoughtInput]
    public let relations: [ThoughtRelation]

    public init(id: UUID = UUID(), interval: DateInterval, thoughts: [Thought], existingTags: [String], continuationCount: Int, request: ReviewSummaryRequest, inputs: [DailySummaryThoughtInput] = [], relations: [ThoughtRelation] = []) {
        self.id = id; self.interval = interval; self.thoughts = thoughts
        self.existingTags = existingTags; self.continuationCount = continuationCount; self.request = request; self.inputs = inputs; self.relations = relations
    }
}

public struct DailySummaryThoughtInput: Equatable, Sendable {
    public let thought: Thought
    public let author: Persona
    public let tags: [ThoughtTag]
    public let timeOfDay: TimeOfDay
    public init(thought: Thought, author: Persona, tags: [ThoughtTag], timeOfDay: TimeOfDay) { self.thought = thought; self.author = author; self.tags = tags; self.timeOfDay = timeOfDay }
}

public enum DailySummaryPrompt {
    public static let version = 3
    public static func make(inputs: [DailySummaryThoughtInput], relations: [ThoughtRelation], existingTags: [String], calendar: Calendar) throws -> String {
        guard !inputs.isEmpty else { throw ReviewSummaryError.noThoughts }
        guard inputs.allSatisfy({ $0.author.kind == .human }) else { throw ReviewSummaryError.stalePreview }
        let ids = Dictionary(uniqueKeysWithValues: inputs.enumerated().map { ($0.element.thought.id, $0.offset + 1) })
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "HH:mm"
        let bodies = inputs.enumerated().map { index, input in
            let tags = input.tags.map(\.name).joined(separator: ", ")
            let links = relations.filter { $0.sourceThoughtID == input.thought.id }.compactMap { relation in ids[relation.targetThoughtID].map { "\(relation.type.rawValue) Thought \($0)" } }.joined(separator: ", ")
            return "[\(formatter.string(from: input.thought.createdAt))]\nThought \(index + 1)\nAuthor: Human\nTimeOfDay: \(input.timeOfDay.title)\nTags: \(tags.isEmpty ? "なし" : tags)\(links.isEmpty ? "" : "\nRelation: \(links)")\n\(input.thought.body)"
        }.joined(separator: "\n\n")
        return """
        以下は1日分のうち、author PersonaのkindがHumanであるThoughtだけです。Daily Summaryは「その日にユーザー本人が何を考え、何に関心を持ち、どんな思考の流れがあったか」を要約してください。
        AI Personaの投稿・返信・フリートーク・生成本文は入力に含まれていません。推測でAIの発言を補ったり、ユーザー本人の考えとして扱ったりしないでください。
        Human Thoughtにない内容を補完せず、診断的表現、性格・生活習慣の断定、少数データからの傾向断定を避けてください。
        タグ別分析はHuman Thoughtに実際に付与済みのタグだけを事実として使ってください。タグなしThoughtへ既存タグを付けたことにせず、AIタグ候補を既存タグとして扱わず、自動変更を指示しないでください。
        Thought単位のAIタグ候補はthoughtTagSuggestionsだけへ提案し、同じSummaryの概要・テーマ・タグ別分析では確定情報として再利用しないでください。thoughtIndexは下記の連番を使い、Human Thoughtだけを対象にしてください。不正な連番やUUIDは出力しないでください。意味的に近い既存タグがある場合は既存の表記を優先しますが、同義だと断定しないでください。
        時間帯情報は提供しますが、明確な意味がある場合だけ分析してください。投稿数が少ない、関連が弱い、偶然と考えられる場合は言及せずtimeOfDayInsightsを空配列にしてください。時間帯から性格や生活習慣を断定しないでください。
        JSON以外を出力せず、次のキーを必ず含めてください。
        {"overview":"", "themes":[], "humanThoughtPatterns":[], "deepDives":[], "concerns":[], "thoughtFlow":"", "tagGroups":[{"tagName":"","summary":"","themes":[],"thoughtCount":0}], "timeOfDayInsights":[{"period":"","insight":""}], "continuationCandidates":[], "carryOvers":[], "existingTagCandidates":[], "newTagCandidates":[], "thoughtTagSuggestions":[{"thoughtIndex":1,"tagName":"","reason":""}]}

        既存タグ: \(existingTags.joined(separator: ", "))
        Thought（古い順、内部UUIDなし）:
        \(bodies)
        """
    }
}

public struct PrepareDailySummary: Sendable {
    private let thoughts: any ThoughtRepository
    private let tags: any ThoughtTagRepository
    private let relations: any ThoughtRelationRepository
    private let authors: any PersonaRepository
    public init(thoughts: any ThoughtRepository, tags: any ThoughtTagRepository, relations: any ThoughtRelationRepository, authors: any PersonaRepository) {
        self.thoughts = thoughts; self.tags = tags; self.relations = relations; self.authors = authors
    }
    public func callAsFunction(day: Date, calendar: Calendar = .current) throws -> DailySummaryPreview {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw ReviewSummaryError.noThoughts }
        let interval = DateInterval(start: start, end: end)
        let records = try thoughts.fetchHumanThoughts(from: start, to: end)
        guard !records.isEmpty else { throw ReviewSummaryError.noThoughts }
        let recordIDs = Set(records.map(\.id))
        let authorMap = try authors.fetchPersonas(for: records.map(\.id))
        var names = Set<String>(), inputs: [DailySummaryThoughtInput] = [], relationSnapshot: [ThoughtRelation] = []
        for thought in records {
            guard let author = authorMap[thought.id], author.kind == .human else { throw ReviewSummaryError.stalePreview }
            let thoughtTags = try tags.fetchTags(for: thought.id)
            thoughtTags.forEach { names.insert($0.name) }
            inputs.append(DailySummaryThoughtInput(thought: thought, author: author, tags: thoughtTags, timeOfDay: .containing(hour: calendar.component(.hour, from: thought.createdAt))))
            relationSnapshot.append(contentsOf: try relations.fetchBySourceThoughtID(thought.id).filter { $0.type == .continues || $0.type == .repliesTo })
        }
        let existing = names.sorted()
        relationSnapshot = relationSnapshot.filter { recordIDs.contains($0.targetThoughtID) }.sorted { $0.id.uuidString < $1.id.uuidString }
        let continuationCount = relationSnapshot.filter { $0.type == .continues }.count
        return DailySummaryPreview(interval: interval, thoughts: records, existingTags: existing, continuationCount: continuationCount, request: .init(prompt: try DailySummaryPrompt.make(inputs: inputs, relations: relationSnapshot, existingTags: existing, calendar: calendar), usageContext: .init(feature: .dailySummary), provider: .openAI, generationProfile: .dailySummary), inputs: inputs, relations: relationSnapshot)
    }
}

public struct GenerateDailySummary: Sendable {
    private let client: any ReviewSummaryClient
    private let repository: any DailySummaryRepository
    private let usage: AIAPIUsageRecorder?
    public init(client: any ReviewSummaryClient, repository: any DailySummaryRepository, usageRepository: (any AIAPIUsageRepository)? = nil) { self.client = client; self.repository = repository; usage = usageRepository.map { AIAPIUsageRecorder(repository: $0) } }
    public func callAsFunction(preview: DailySummaryPreview, now: Date = Date()) async throws -> DailySummary {
        guard !preview.thoughts.isEmpty, preview.inputs.allSatisfy({ $0.author.kind == .human }) else { throw ReviewSummaryError.noThoughts }
        let finish: @Sendable (ReviewSummaryResponse) async throws -> DailySummary = { response in
        let raw = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let json = raw.hasPrefix("```") ? raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines) : raw
        guard let data = json.data(using: .utf8) else { throw ReviewSummaryError.emptyResponse }
        let content = try JSONDecoder().decode(DailySummaryContent.self, from: data)
        let existing = Set(preview.existingTags)
        let humanTagCounts = Dictionary(grouping: preview.inputs.filter { $0.author.kind == .human }.flatMap { input in input.tags.map { ($0.name, input.thought.id) } }, by: { $0.0 }).mapValues { Set($0.map { $0.1 }).count }
        let resolvedSuggestions = content.thoughtTagSuggestions.compactMap { suggestion -> DailySummaryThoughtTagSuggestion? in
            let offset = suggestion.thoughtIndex - 1
            guard preview.inputs.indices.contains(offset),
                  let name = ThoughtTag.displayName(from: suggestion.tagName), !suggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return DailySummaryThoughtTagSuggestion(thoughtIndex: suggestion.thoughtIndex, thoughtID: preview.inputs[offset].thought.id, tagName: name, reason: suggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines))
        }
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
            carryOvers: content.carryOvers,
            tagGroups: content.tagGroups.compactMap { group in humanTagCounts[group.tagName].map { DailySummaryTagGroup(tagName: group.tagName, summary: group.summary, themes: group.themes, thoughtCount: $0) } },
            // Kept in the persisted model only so existing v2 summaries remain decodable.
            // New Daily Summaries never save AI-authored content or AI-derived summaries.
            aiInteractions: [],
            timeOfDayInsights: content.timeOfDayInsights,
            thoughtTagSuggestions: resolvedSuggestions
        )
        let summary = DailySummary(dayStart: preview.interval.start, dayEnd: preview.interval.end, content: sanitized, createdAt: now, provider: response.provider, model: response.model, promptVersion: DailySummaryPrompt.version, thoughtCount: preview.thoughts.count)
        try repository.saveDailySummary(summary)
        return summary
        }
        if let usage { return try await usage.call(client: client, request: preview.request, finish: finish) }
        let response = try await client.generateSummary(preview.request)
        return try await finish(response)
    }
}
