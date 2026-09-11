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

    public init(overview: String, themes: [String], existingTagCandidates: [String], newTagCandidates: [String], thoughtPatterns: [String], deepDives: [String], concerns: [String], thoughtFlow: String, continuationCandidates: [String], carryOvers: [String], tagGroups: [DailySummaryTagGroup] = [], aiInteractions: [DailySummaryAIInteraction] = [], timeOfDayInsights: [DailySummaryTimeInsight] = []) {
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
        self.tagGroups = tagGroups; self.aiInteractions = aiInteractions; self.timeOfDayInsights = timeOfDayInsights
    }


    private enum CodingKeys: String, CodingKey { case overview, themes, existingTagCandidates, newTagCandidates, thoughtPatterns, humanThoughtPatterns, deepDives, concerns, thoughtFlow, continuationCandidates, carryOvers, tagGroups, aiInteractions, timeOfDayInsights }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        overview = try values.decode(String.self, forKey: .overview); themes = try values.decodeIfPresent([String].self, forKey: .themes) ?? []
        existingTagCandidates = try values.decodeIfPresent([String].self, forKey: .existingTagCandidates) ?? []; newTagCandidates = try values.decodeIfPresent([String].self, forKey: .newTagCandidates) ?? []
        if let v2 = try values.decodeIfPresent([String].self, forKey: .humanThoughtPatterns) { thoughtPatterns = v2 }
        else { thoughtPatterns = try values.decodeIfPresent([String].self, forKey: .thoughtPatterns) ?? [] }
        deepDives = try values.decodeIfPresent([String].self, forKey: .deepDives) ?? []; concerns = try values.decodeIfPresent([String].self, forKey: .concerns) ?? []; thoughtFlow = try values.decodeIfPresent(String.self, forKey: .thoughtFlow) ?? ""
        continuationCandidates = try values.decodeIfPresent([String].self, forKey: .continuationCandidates) ?? []; carryOvers = try values.decodeIfPresent([String].self, forKey: .carryOvers) ?? []
        tagGroups = try values.decodeIfPresent([DailySummaryTagGroup].self, forKey: .tagGroups) ?? []; aiInteractions = try values.decodeIfPresent([DailySummaryAIInteraction].self, forKey: .aiInteractions) ?? []; timeOfDayInsights = try values.decodeIfPresent([DailySummaryTimeInsight].self, forKey: .timeOfDayInsights) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(overview, forKey: .overview); try values.encode(themes, forKey: .themes); try values.encode(existingTagCandidates, forKey: .existingTagCandidates); try values.encode(newTagCandidates, forKey: .newTagCandidates); try values.encode(thoughtPatterns, forKey: .humanThoughtPatterns); try values.encode(deepDives, forKey: .deepDives); try values.encode(concerns, forKey: .concerns); try values.encode(thoughtFlow, forKey: .thoughtFlow); try values.encode(continuationCandidates, forKey: .continuationCandidates); try values.encode(carryOvers, forKey: .carryOvers); try values.encode(tagGroups, forKey: .tagGroups); try values.encode(aiInteractions, forKey: .aiInteractions); try values.encode(timeOfDayInsights, forKey: .timeOfDayInsights)
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
    public static let version = 2
    public static func make(inputs: [DailySummaryThoughtInput], relations: [ThoughtRelation], existingTags: [String], calendar: Calendar) throws -> String {
        guard !inputs.isEmpty else { throw ReviewSummaryError.noThoughts }
        let ids = Dictionary(uniqueKeysWithValues: inputs.enumerated().map { ($0.element.thought.id, $0.offset + 1) })
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "HH:mm"
        let bodies = inputs.enumerated().map { index, input in
            let author = input.author.kind == .human ? "Human" : "AI: \(input.author.displayName)"
            let tags = input.author.kind == .human ? input.tags.map(\.name).joined(separator: ", ") : ""
            let links = relations.filter { $0.sourceThoughtID == input.thought.id }.compactMap { relation in ids[relation.targetThoughtID].map { "\(relation.type.rawValue) Thought \($0)" } }.joined(separator: ", ")
            return "[\(formatter.string(from: input.thought.createdAt))]\nThought \(index + 1)\nAuthor: \(author)\nTimeOfDay: \(input.timeOfDay.title)\nTags: \(tags.isEmpty ? "なし" : tags)\(links.isEmpty ? "" : "\nRelation: \(links)")\n\(input.thought.body)"
        }.joined(separator: "\n\n")
        return """
        以下は利用者が明示的に選択した1日分のThoughtです。Human Thoughtを振り返りの主データとし、AI Thought／AI Replyは「AIとの対話」だけで補助的に扱ってください。AIの発言をHuman本人の考えとして扱わないでください。
        Human Thoughtにない内容を補完せず、診断的表現、性格・生活習慣の断定、少数データからの傾向断定を避けてください。
        タグ別分析はHuman Thoughtに実際に付与済みのタグだけを事実として使ってください。タグなしThoughtへ既存タグを付けたことにせず、AIタグ候補を既存タグとして扱わず、自動変更を指示しないでください。
        時間帯情報は提供しますが、明確な意味がある場合だけ分析してください。投稿数が少ない、関連が弱い、偶然と考えられる場合は言及せずtimeOfDayInsightsを空配列にしてください。時間帯から性格や生活習慣を断定しないでください。
        JSON以外を出力せず、次のキーを必ず含めてください。
        {"overview":"", "themes":[], "humanThoughtPatterns":[], "deepDives":[], "concerns":[], "thoughtFlow":"", "tagGroups":[{"tagName":"","summary":"","themes":[],"thoughtCount":0}], "aiInteractions":[{"personaName":"","topics":[],"summary":""}], "timeOfDayInsights":[{"period":"","insight":""}], "continuationCandidates":[], "carryOvers":[], "existingTagCandidates":[], "newTagCandidates":[]}

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
        let records = try thoughts.fetchThoughts(from: start, to: end)
        guard !records.isEmpty else { throw ReviewSummaryError.noThoughts }
        let recordIDs = Set(records.map(\.id))
        let authorMap = try authors.fetchPersonas(for: records.map(\.id))
        var names = Set<String>(), inputs: [DailySummaryThoughtInput] = [], relationSnapshot: [ThoughtRelation] = []
        for thought in records {
            guard let author = authorMap[thought.id] else { throw ReviewSummaryError.stalePreview }
            let thoughtTags = try tags.fetchTags(for: thought.id)
            if author.kind == .human { thoughtTags.forEach { names.insert($0.name) } }
            inputs.append(DailySummaryThoughtInput(thought: thought, author: author, tags: author.kind == .human ? thoughtTags : [], timeOfDay: .containing(hour: calendar.component(.hour, from: thought.createdAt))))
            relationSnapshot.append(contentsOf: try relations.fetchBySourceThoughtID(thought.id).filter { $0.type == .continues || $0.type == .repliesTo })
        }
        let existing = names.sorted()
        let counts = try relations.fetchContinuationCounts(for: records.map(\.id))
        relationSnapshot = relationSnapshot.filter { recordIDs.contains($0.targetThoughtID) }.sorted { $0.id.uuidString < $1.id.uuidString }
        return DailySummaryPreview(interval: interval, thoughts: records, existingTags: existing, continuationCount: counts.values.reduce(0, +), request: .init(prompt: try DailySummaryPrompt.make(inputs: inputs, relations: relationSnapshot, existingTags: existing, calendar: calendar)), inputs: inputs, relations: relationSnapshot)
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
        let humanTagCounts = Dictionary(grouping: preview.inputs.filter { $0.author.kind == .human }.flatMap { input in input.tags.map { ($0.name, input.thought.id) } }, by: { $0.0 }).mapValues { Set($0.map { $0.1 }).count }
        let aiNames = Set(preview.inputs.filter { $0.author.kind == .ai }.map { $0.author.displayName })
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
            aiInteractions: content.aiInteractions.filter { aiNames.contains($0.personaName) },
            timeOfDayInsights: content.timeOfDayInsights
        )
        let summary = DailySummary(dayStart: preview.interval.start, dayEnd: preview.interval.end, content: sanitized, createdAt: now, provider: response.provider, model: response.model, promptVersion: DailySummaryPrompt.version, thoughtCount: preview.thoughts.count)
        try repository.saveDailySummary(summary)
        return summary
    }
}
