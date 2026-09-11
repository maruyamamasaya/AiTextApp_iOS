import Combine
import Foundation

@MainActor
final class ThoughtStore: ObservableObject {
    struct ExportArtifact: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Published var draft = ""
    @Published private(set) var thoughts: [Thought] = []
    @Published private(set) var defaultHumanPersona = Persona(id: Persona.defaultHumanID, displayName: "自分", kind: .human)
    @Published private(set) var personas: [Persona] = []
    @Published private(set) var personasByThoughtID: [UUID: Persona] = [:]
    @Published private(set) var mentionedPersonasByThoughtID: [UUID: Persona] = [:]
    @Published var selectedMentionPersona: Persona?
    @Published private(set) var aiConfigurations: [UUID: AIPersonaConfiguration] = [:]
    @Published var aiPostPreview: AIPostPreview?
    @Published private(set) var isGeneratingAIPost = false
    @Published var aiPostError: String?
    @Published var aiReplyPreview: AIThoughtReplyPreview?
    @Published private(set) var isGeneratingAIReply = false
    @Published var aiReplyError: String?
    @Published private(set) var aiRepliesByTargetID: [UUID: [Thought]] = [:]
    @Published private(set) var replyTargetIDsByThoughtID: [UUID: UUID] = [:]
    @Published private(set) var dailySummaries: [DailySummary] = []
    @Published private(set) var dailySummary: DailySummary?
    @Published private(set) var dailySummaryPreview: DailySummaryPreview?
    @Published private(set) var isGeneratingDailySummary = false
    @Published var dailySummaryError: String?
    @Published private(set) var dailySummaryDayThoughts: [Thought] = []
    @Published private(set) var dailySummaryDayTags: [String] = []
    @Published private(set) var dailySummaryDayContinuationCount = 0
    @Published private(set) var searchResults: [Thought] = []
    @Published private(set) var hasSearchQuery = false
    @Published private(set) var tagsByThoughtID: [UUID: [ThoughtTag]] = [:]
    @Published private(set) var allTags: [ThoughtTag] = []
    @Published private(set) var taggedThoughts: [Thought] = []
    @Published var tagMessage: String?
    @Published var deletionCandidate: Thought?
    @Published var errorMessage: String?
    @Published var exportArtifact: ExportArtifact?
    @Published private(set) var history: [ThoughtHistoryEntry] = []
    @Published private(set) var historyCurrentID: UUID?
    @Published var continuationDraft = ""
    @Published var humanReplyDraft = ""
    @Published private(set) var analytics: ThoughtAnalyticsSnapshot?
    @Published private(set) var isLoadingAnalytics = false
    @Published private(set) var aiUsageAnalytics: AIAPIUsageAnalytics?
    @Published private(set) var isLoadingAIUsageAnalytics = false
    @Published var aiUsageAnalyticsError: String?
    @Published var knowledgeDraft: KnowledgeDraft?
    @Published private(set) var isGeneratingKnowledgeDraft = false
    @Published private(set) var isSavingKnowledgeDraft = false
    @Published var knowledgeDraftError: String?
    @Published var knowledgeDraftMessage: String?
    @Published private(set) var knowledgeDrafts: [KnowledgeDraft] = []
    @Published private(set) var knowledgeDocuments: [KnowledgeDocument] = []
    @Published private(set) var knowledgeLifecycleEvents: [KnowledgeLifecycleEvent] = []
    @Published private(set) var knowledgeQualityCandidates: [KnowledgeQualityCandidate] = []
    let externalBackupManager: ExternalBackupManager?
    let externalBrainManager: ExternalBrainManager

    private var timeline: ThoughtTimeline?
    private var exporter: ThoughtExporter?
    private var thoughtRepository: (any ThoughtRepository)?
    private var relationRepository: (any ThoughtRelationRepository)?
    private var continuationRepository: (any ThoughtContinuationRepository)?
    private var tagRepository: (any ThoughtTagRepository)?
    private var analyticsRepository: (any ThoughtAnalyticsRepository)?
    private var aiUsageAnalyticsRepository: (any AIAPIUsageAnalyticsRepository)?
    private var aiUsageRepository: (any AIAPIUsageRepository)?
    private var knowledgeDraftRepository: (any KnowledgeDraftRepository)?
    private var knowledgeLifecycleRepository: (any KnowledgeLifecycleEventRepository)?
    private var dailySummaryRepository: (any DailySummaryRepository)?
    private var personaRepository: (any PersonaRepository)?
    private var aiPersonaRepository: (any AIPersonaRepository)?
    private var mentionRepository: (any ThoughtMentionRepository)?
    private var aiReplyRepository: (any AIThoughtReplyRepository)?
    private var humanReplyRepository: (any HumanThoughtReplyRepository)?
    private var summaryClient: any ReviewSummaryClient
    private var isPosting = false

    init(
        repository: (any ThoughtRepository)? = nil,
        summaryClient: any ReviewSummaryClient = MockReviewSummaryClient(),
        startupError: String? = nil,
        externalBrainManager: ExternalBrainManager? = nil
    ) {
        self.summaryClient = summaryClient
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        self.externalBrainManager = externalBrainManager ?? ExternalBrainManager(rootURL: support.appendingPathComponent("ExternalBrain", isDirectory: true))
        var backupManager: ExternalBackupManager?
        do {
            let repository = try repository ?? SQLiteThoughtRepository()
            let timeline = try ThoughtTimeline(repository: repository)
            self.timeline = timeline
            thoughtRepository = repository
            relationRepository = repository as? any ThoughtRelationRepository
            continuationRepository = repository as? any ThoughtContinuationRepository
            tagRepository = repository as? any ThoughtTagRepository
            analyticsRepository = repository as? any ThoughtAnalyticsRepository
            aiUsageAnalyticsRepository = repository as? any AIAPIUsageAnalyticsRepository
            aiUsageRepository = repository as? any AIAPIUsageRepository
            knowledgeDraftRepository = repository as? any KnowledgeDraftRepository
            knowledgeLifecycleRepository = repository as? any KnowledgeLifecycleEventRepository
            dailySummaryRepository = repository as? any DailySummaryRepository
            personaRepository = repository as? any PersonaRepository
            aiPersonaRepository = repository as? any AIPersonaRepository
            mentionRepository = repository as? any ThoughtMentionRepository
            aiReplyRepository = repository as? any AIThoughtReplyRepository
            humanReplyRepository = repository as? any HumanThoughtReplyRepository
            exporter = ThoughtExporter(repository: repository)
            thoughts = timeline.thoughts
            if let personaRepository { defaultHumanPersona = try personaRepository.fetchDefaultHumanPersona() }
            if let personaRepository { personas = try personaRepository.fetchPersonas(includeInactive: false) }
            if let aiPersonaRepository { aiConfigurations = try aiPersonaRepository.fetchAIConfigurations() }
            dailySummaries = try dailySummaryRepository?.fetchDailySummaries(from: .distantPast, to: .distantFuture) ?? []
            knowledgeDrafts = try knowledgeDraftRepository?.fetchKnowledgeDrafts() ?? []; knowledgeDocuments = try knowledgeDraftRepository?.fetchKnowledgeDocuments() ?? []
            if let sqliteRepository = repository as? SQLiteThoughtRepository {
                backupManager = ExternalBackupManager(repository: sqliteRepository)
            }
        } catch {
            errorMessage = "保存したThoughtを読み込めませんでした。"
        }
        externalBackupManager = backupManager
        refreshTags(for: thoughts.map(\.id))
        refreshAuthors(for: thoughts.map(\.id))
        refreshMentions(for: thoughts.map(\.id))
        refreshReplyRelations(for: thoughts.map(\.id))
        loadAllTags()
        if let startupError { errorMessage = startupError }
    }

    func updateDefaultHumanPersona(displayName: String, iconData: Data?) -> Bool {
        guard let personaRepository else { errorMessage = "プロフィールを保存できませんでした。"; return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { errorMessage = "表示名は1〜40文字で入力してください。"; return false }
        var persona = defaultHumanPersona
        persona.displayName = name
        persona.iconData = iconData
        persona.iconMIMEType = iconData == nil ? nil : "image/jpeg"
        persona.updatedAt = Date()
        do {
            try personaRepository.updatePersona(persona)
            defaultHumanPersona = persona
            loadPersonas()
            refreshAuthors(for: thoughts.map(\.id))
            return true
        } catch {
            errorMessage = "プロフィールを保存できませんでした。"
            return false
        }
    }

    func createAIPersona(displayName: String, iconData: Data?, role: String, instructions: String, externalBrainEnabled: Bool = false, agentPath: String = "", maxRetrievedChunks: Int = 5) -> Bool {
        guard let aiPersonaRepository else { errorMessage = "AI Personaを保存できませんでした。"; return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines), instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40, !role.isEmpty, !instructions.isEmpty else { errorMessage = "表示名・役割・指示を入力してください。"; return false }
        let persona = Persona(displayName: name, kind: .ai, iconData: iconData, iconMIMEType: iconData == nil ? nil : "image/jpeg")
        do { try aiPersonaRepository.createAIPersona(persona, configuration: AIPersonaConfiguration(personaID: persona.id, role: role, instructions: instructions)); externalBrainManager.savePersona(.init(personaID: persona.id, enabled: externalBrainEnabled, agentPath: agentPath, maxRetrievedChunks: maxRetrievedChunks)); loadPersonas(); loadAIConfigurations(); return true }
        catch { errorMessage = "AI Personaを保存できませんでした。"; return false }
    }

    func updateAIPersona(_ original: Persona, displayName: String, iconData: Data?, role: String, instructions: String) -> Bool {
        guard original.kind == .ai, let personaRepository, let aiPersonaRepository else { return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines), instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40, !role.isEmpty, !instructions.isEmpty else { errorMessage = "表示名・役割・指示を入力してください。"; return false }
        var persona = original; persona.displayName = name; persona.iconData = iconData; persona.iconMIMEType = iconData == nil ? nil : "image/jpeg"; persona.updatedAt = Date()
        do { try personaRepository.updatePersona(persona); try aiPersonaRepository.saveAIConfiguration(AIPersonaConfiguration(personaID: persona.id, role: role, instructions: instructions)); loadPersonas(); loadAIConfigurations(); refreshAuthors(for: thoughts.map(\.id)); return true }
        catch { errorMessage = "AI Personaを保存できませんでした。"; return false }
    }

    func deactivateAIPersona(_ persona: Persona) {
        guard persona.kind == .ai, let personaRepository else { return }
        do { _ = try personaRepository.deactivatePersona(id: persona.id, at: Date()); loadPersonas(); refreshMentions(for: thoughts.map(\.id)) }
        catch { errorMessage = "AI Personaを無効化できませんでした。" }
    }

    private func loadPersonas() {
        do { personas = try personaRepository?.fetchPersonas(includeInactive: false) ?? [] }
        catch { errorMessage = "Personaを読み込めませんでした。" }
    }
    private func loadAIConfigurations() { aiConfigurations = (try? aiPersonaRepository?.fetchAIConfigurations()) ?? [:] }

    func prepareAIPost(persona: Persona, userRequest: String) {
        guard let configuration = aiConfigurations[persona.id] else { aiPostError = AIPostError.missingConfiguration.localizedDescription; return }
        let externalBrain = externalBrainManager.retrieve(personaID: persona.id, query: userRequest); trackKnowledgeRetrieval(externalBrain)
        do { aiPostPreview = try AIPostPrompt.prepare(persona: persona, configuration: configuration, userRequest: userRequest, externalBrain: externalBrain); aiPostError = nil }
        catch { aiPostError = error.localizedDescription }
    }

    func cancelAIPostPreview() { aiPostPreview = nil }

    func generateAIPost(from preview: AIPostPreview) async {
        guard let aiPersonaRepository, let thoughtRepository else { aiPostError = "AI投稿の保存先を利用できません。"; return }
        isGeneratingAIPost = true; aiPostError = nil; defer { isGeneratingAIPost = false }
        do {
            _ = try await GenerateAIPost(client: summaryClient, repository: aiPersonaRepository, usageRepository: aiUsageRepository)(preview: preview)
            timeline = try ThoughtTimeline(repository: thoughtRepository); thoughts = timeline?.thoughts ?? []
            refreshTags(for: thoughts.map(\.id)); refreshAuthors(for: thoughts.map(\.id)); aiPostPreview = nil
        } catch { aiPostError = error.localizedDescription }
    }

    func prepareAIReply(to thought: Thought, userRequest: String) {
        guard thought.deletedAt == nil, let persona = mentionedPersonasByThoughtID[thought.id],
              personas.contains(where: { $0.id == persona.id }), let configuration = aiConfigurations[persona.id], let aiReplyRepository else {
            aiReplyError = "返信先または有効なAI Personaを確認できません。"; return
        }
        do {
            let context = try aiReplyRepository.loadAIReplyContext(targetThoughtID: thought.id, maximumEntries: AIThoughtReplyPrompt.maximumContextEntries)
            let query = (context.entries.map(\.thought.body) + [userRequest]).joined(separator: " ")
            let externalBrain = externalBrainManager.retrieve(personaID: persona.id, query: query)
            trackKnowledgeRetrieval(externalBrain)
            aiReplyPreview = try AIThoughtReplyPrompt.prepare(persona: persona, configuration: configuration, targetThought: thought, userRequest: userRequest, context: context, externalBrain: externalBrain); aiReplyError = nil
        }
        catch { aiReplyError = error.localizedDescription }
    }

    func cancelAIReplyPreview() { aiReplyPreview = nil }

    func generateAIReply(from preview: AIThoughtReplyPreview) async {
        guard let aiReplyRepository, let thoughtRepository else { aiReplyError = "AI返信の保存先を利用できません。"; return }
        guard !isGeneratingAIReply else { return }
        isGeneratingAIReply = true; aiReplyError = nil; defer { isGeneratingAIReply = false }
        do {
            _ = try await GenerateAIThoughtReply(client: summaryClient, repository: aiReplyRepository, usageRepository: aiUsageRepository)(preview: preview)
            timeline = try ThoughtTimeline(repository: thoughtRepository); thoughts = timeline?.thoughts ?? []
            refreshTags(for: thoughts.map(\.id)); refreshAuthors(for: thoughts.map(\.id)); refreshMentions(for: thoughts.map(\.id)); refreshReplyRelations(for: thoughts.map(\.id)); aiReplyPreview = nil
            loadAIReplies(to: preview.targetThought.id)
        } catch ReviewSummaryError.stalePreview { aiReplyError = "確認後に会話内容が変更されたため送信しませんでした。もう一度内容を確認してください。" }
        catch { aiReplyError = error.localizedDescription }
    }

    func loadAIReplies(to thoughtID: UUID) {
        guard let aiReplyRepository else { return }
        do { let replies = try aiReplyRepository.fetchAIReplies(to: thoughtID); aiRepliesByTargetID[thoughtID] = replies; refreshAuthors(for: replies.map(\.id)) }
        catch { aiReplyError = "AI返信を読み込めませんでした。" }
    }

    private func refreshReplyRelations(for ids: [UUID]) {
        guard let aiReplyRepository else { return }
        if let values = try? aiReplyRepository.fetchReplyTargets(for: ids) { replyTargetIDsByThoughtID.merge(values) { _, new in new } }
    }

    private func refreshAuthors(for ids: [UUID]) {
        guard let personaRepository else { return }
        if let values = try? personaRepository.fetchPersonas(for: ids) { personasByThoughtID.merge(values) { _, new in new } }
    }
    private func refreshMentions(for ids: [UUID]) {
        guard let mentionRepository else { return }
        if let values = try? mentionRepository.fetchMentionedPersonas(for: ids) { mentionedPersonasByThoughtID.merge(values) { _, new in new } }
    }

    func loadDailySummary(for day: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        do {
            dailySummary = try dailySummaryRepository?.fetchDailySummary(dayStart: start)
            if let thoughtRepository, let tagRepository, let relationRepository, let personaRepository,
               let preview = try? PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository, authors: personaRepository)(day: day, calendar: calendar) {
                dailySummaryDayThoughts = preview.thoughts
                dailySummaryDayTags = preview.existingTags
                dailySummaryDayContinuationCount = preview.continuationCount
            } else {
                dailySummaryDayThoughts = []
                dailySummaryDayTags = []
                dailySummaryDayContinuationCount = 0
            }
            dailySummaryError = nil
        }
        catch { dailySummary = nil; dailySummaryError = "Daily Summaryを読み込めませんでした。" }
    }

    func prepareDailySummary(for day: Date, calendar: Calendar = .current) {
        guard let thoughtRepository, let tagRepository, let relationRepository, let personaRepository else { dailySummaryError = "要約対象を読み込めませんでした。"; return }
        do {
            dailySummaryPreview = try PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository, authors: personaRepository)(day: day, calendar: calendar)
            dailySummaryError = nil
        } catch ReviewSummaryError.noThoughts { dailySummaryPreview = nil; dailySummaryError = "Thoughtが0件の日は要約できません。" }
        catch { dailySummaryPreview = nil; dailySummaryError = "要約対象を準備できませんでした。" }
    }

    func cancelDailySummaryPreview() { dailySummaryPreview = nil }

    func generateDailySummary(from preview: DailySummaryPreview) async {
        guard let thoughtRepository, let dailySummaryRepository else { dailySummaryError = "保存先を利用できません。"; return }
        isGeneratingDailySummary = true; dailySummaryError = nil
        defer { isGeneratingDailySummary = false }
        do {
            guard let tagRepository, let relationRepository, let personaRepository else { throw ReviewSummaryError.stalePreview }
            let current = try PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository, authors: personaRepository)(day: preview.interval.start)
            guard current.inputs == preview.inputs && current.relations == preview.relations && current.existingTags == preview.existingTags && current.continuationCount == preview.continuationCount else { throw ReviewSummaryError.stalePreview }
            let value = try await GenerateDailySummary(client: summaryClient, repository: dailySummaryRepository, usageRepository: aiUsageRepository)(preview: preview)
            dailySummary = value
            dailySummaries.removeAll { $0.dayStart == value.dayStart }
            dailySummaries.append(value)
            dailySummaryPreview = nil
        } catch ReviewSummaryError.stalePreview { dailySummaryError = "確認後にThoughtが変更されたため送信しませんでした。" }
        catch let error as ReviewSummaryServiceError { dailySummaryError = error.localizedDescription }
        catch { dailySummaryError = "Daily Summaryを作成できませんでした。応答形式または通信状態を確認してください。" }
    }

    func loadAnalytics(containing date: Date = Date(), calendar: Calendar = .current) {
        guard let analyticsRepository else {
            analytics = nil
            errorMessage = "ローカル分析を読み込めませんでした。"
            return
        }
        isLoadingAnalytics = true
        defer { isLoadingAnalytics = false }
        do {
            analytics = try LoadThoughtAnalytics(
                repository: analyticsRepository,
                calendar: calendar
            )(containing: date)
        } catch {
            analytics = nil
            errorMessage = "ローカル分析を読み込めませんでした。保存済みデータは変更されていません。"
        }
    }

    func export(_ format: ThoughtExportFormat) {
        guard let exporter else {
            errorMessage = "ThoughtをExportできませんでした。"
            return
        }
        do {
            exportArtifact = ExportArtifact(url: try exporter.write(format))
        } catch {
            errorMessage = "ThoughtをExportできませんでした。入力内容と保存済みデータは変更されていません。"
        }
    }

    func sharingFailed() {
        errorMessage = "共有を完了できませんでした。Exportファイルは変更されていません。"
    }

    var remainingCharacterCount: Int {
        ThoughtDraft.characterLimit - draft.count
    }

    var canPost: Bool {
        ThoughtDraft.validBody(from: draft) != nil
    }

    func updateDraft(_ value: String) {
        draft = ThoughtDraft.limited(value)
    }

    var canPostContinuation: Bool {
        ThoughtDraft.validBody(from: continuationDraft) != nil
    }

    func updateContinuationDraft(_ value: String) {
        continuationDraft = ThoughtDraft.limited(value)
    }

    func knowledgeDraftInput(for thought: Thought) -> KnowledgeDraftInput? {
        guard let author = personasByThoughtID[thought.id], author.kind == .ai else { return nil }
        var generation: AIPostGeneration?
        if let aiReplyRepository { generation = try? aiReplyRepository.fetchAIPostGeneration(for: thought.id) }
        let source: KnowledgeDraftSource = generation?.kind == .reply ? .aiReply : .personaPost
        let context = generation.map { "Human request: \($0.userRequest)\nAI persona: \(author.displayName)" }
        return KnowledgeDraftInput(source: source, sourceContent: "AI statement:\n\(thought.body)", context: context, provenance: .init(sourceID: thought.id.uuidString, personaID: author.id, conversationID: generation?.replyTargetThoughtID))
    }

    func knowledgeDraftInput(for summary: DailySummary) -> KnowledgeDraftInput {
        let content = summary.content
        let sections = [
            "Overview:\n\(content.overview)",
            "Themes:\n\(content.themes.joined(separator: "\n"))",
            "Deep dives:\n\(content.deepDives.joined(separator: "\n"))",
            "Carry overs:\n\(content.carryOvers.joined(separator: "\n"))",
            "Recurring patterns (observations only):\n\(content.thoughtPatterns.joined(separator: "\n"))"
        ]
        return .init(source: .dailySummary, sourceContent: sections.joined(separator: "\n\n"), context: "Daily Summary generated at \(summary.createdAt.formatted())", provenance: .init(sourceID: summary.id.uuidString, dailySummaryDate: summary.dayStart))
    }

    func generateKnowledgeDraft(input: KnowledgeDraftInput, type: KnowledgeDraftType) async {
        guard !isGeneratingKnowledgeDraft else { return }
        isGeneratingKnowledgeDraft = true; knowledgeDraftError = nil; knowledgeDraftMessage = nil
        defer { isGeneratingKnowledgeDraft = false }
        let related = externalBrainManager.relatedKnowledge(query: input.sourceContent)
        do { let value = try await GenerateKnowledgeDraft(client: summaryClient, usageRepository: aiUsageRepository)(input: input, type: type, related: related); try knowledgeDraftRepository?.saveKnowledgeDraft(value); knowledgeDraft = value; loadKnowledge() }
        catch { knowledgeDraftError = error.localizedDescription }
    }

    func saveKnowledgeDraft(_ draft: KnowledgeDraft) async {
        guard !isSavingKnowledgeDraft else { return }
        isSavingKnowledgeDraft = true; knowledgeDraftError = nil; knowledgeDraftMessage = nil
        defer { isSavingKnowledgeDraft = false }
        do {
            let path = try await externalBrainManager.saveDraft(draft)
            var saved = draft; saved.savedPath = path; saved.syncStatus = .synced; saved.updatedAt = Date(); try knowledgeDraftRepository?.saveKnowledgeDraft(saved); knowledgeDraft = saved; loadKnowledge()
            knowledgeDraftMessage = "保存しました\n\(path)"
        } catch { var failed=draft; failed.syncStatus = .failed; failed.updatedAt=Date(); try? knowledgeDraftRepository?.saveKnowledgeDraft(failed); knowledgeDraft = failed; knowledgeDraftError = error.localizedDescription; loadKnowledge() }
    }

    func cancelKnowledgeDraft() { knowledgeDraft = nil; knowledgeDraftError = nil; knowledgeDraftMessage = nil }
    func loadKnowledge(search: String = "") { do { knowledgeDrafts = search.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? (try knowledgeDraftRepository?.fetchKnowledgeDrafts() ?? []) : (try knowledgeDraftRepository?.searchKnowledgeDrafts(query:search) ?? []); knowledgeDocuments = try knowledgeDraftRepository?.fetchKnowledgeDocuments() ?? []; knowledgeLifecycleEvents = try knowledgeLifecycleRepository?.fetchKnowledgeLifecycleEvents() ?? []; knowledgeQualityCandidates = try knowledgeDraftRepository?.fetchKnowledgeQualityCandidates() ?? [] } catch { knowledgeDraftError = "Knowledgeを読み込めませんでした。" } }
    func updateKnowledgeDraft(_ draft: KnowledgeDraft) { var value=draft; value.updatedAt=Date(); if value.savedPath != nil { value.syncStatus = .localOnly }; do { try knowledgeDraftRepository?.saveKnowledgeDraft(value); knowledgeDraft=value; loadKnowledge() } catch { knowledgeDraftError="Draftを保存できませんでした。" } }
    func reviewKnowledgeDraft(_ draft: KnowledgeDraft, status: KnowledgeDraftReviewStatus) { do { let value=try KnowledgeDraftTransition.applying(status,to:draft); try knowledgeDraftRepository?.saveKnowledgeDraft(value); let event: KnowledgeLifecycleEventType?; switch status { case .approved: event = .approved; case .rejected: event = .rejected; default: event = nil }; if let event { try? knowledgeLifecycleRepository?.saveKnowledgeLifecycleEvent(.init(draftID:draft.id,type:event,source:draft.source)) }; knowledgeDraft=value; loadKnowledge() } catch { knowledgeDraftError=error.localizedDescription } }
    func promoteKnowledgeDraft(_ draft: KnowledgeDraft) async { let path=KnowledgeDocumentPath.targetPath(date:Date(),title:draft.title); do { let sha=try await externalBrainManager.promote(draft,path:path); var promoted=try KnowledgeDraftTransition.applying(.promoted,to:draft); promoted.knowledgePath=path; promoted.knowledgeSHA=sha; promoted.syncStatus = .synced; let document=KnowledgeDocument(draftID:draft.id,title:draft.title,path:path,sha:sha,source:draft.source,tags:draft.tags,markdown:draft.markdown.replacingOccurrences(of:"status: draft",with:"status: active"),createdAt:promoted.promotedAt ?? Date(),updatedAt:promoted.promotedAt ?? Date()); try knowledgeDraftRepository?.savePromotedKnowledge(draft:promoted,document:document); try? knowledgeLifecycleRepository?.saveKnowledgeLifecycleEvent(.init(draftID:draft.id,type:.promoted,source:draft.source)); knowledgeDraft=promoted; knowledgeDraftMessage="Promoteしました\n\(path)"; loadKnowledge() } catch { var failed=draft; failed.syncStatus = .failed; failed.updatedAt=Date(); try? knowledgeDraftRepository?.saveKnowledgeDraft(failed); knowledgeDraft=failed; knowledgeDraftError=error.localizedDescription; loadKnowledge() } }
    private func trackKnowledgeRetrieval(_ context:ExternalBrainContext?) { let paths=context?.chunks.map(\.documentPath) ?? []; guard !paths.isEmpty else{return}; try? knowledgeDraftRepository?.recordKnowledgeRetrieval(paths:paths,at:Date()) }
    func analyzeKnowledgeQuality() { do { let candidates=KnowledgeQualityAnalyzer.analyze(try knowledgeDraftRepository?.fetchKnowledgeDocuments() ?? []); try knowledgeDraftRepository?.replaceKnowledgeQualityCandidates(candidates); loadKnowledge(); knowledgeDraftMessage="ローカル解析を完了しました。AI APIは使用していません。" } catch { knowledgeDraftError="Knowledge Qualityを解析できませんでした。" } }
    func dismissQualityCandidate(_ candidate:KnowledgeQualityCandidate) { var value=candidate; value.status = .dismissed; value.resolvedAt=Date(); do { try knowledgeDraftRepository?.saveKnowledgeQualityCandidate(value); loadKnowledge() } catch { knowledgeDraftError="候補をDismissできませんでした。" } }
    func createMergeDraft(_ candidate:KnowledgeQualityCandidate) { guard let relatedID=candidate.relatedKnowledgeID,let a=knowledgeDocuments.first(where:{$0.id==candidate.knowledgeID}),let b=knowledgeDocuments.first(where:{$0.id==relatedID}) else{return}; let body="# Merge Draft\n\n## \(a.title)\n\(MarkdownFrontMatterParser.parse(a.markdown).body)\n\n## \(b.title)\n\(MarkdownFrontMatterParser.parse(b.markdown).body)"; let draft=KnowledgeDraft(title:"Merge: \(a.title)",type:.knowledge,tags:Array(Set(a.tags+b.tags)).sorted(),source:.mergeDraft,body:body,provenance:.init(sourceKnowledgeIDs:[a.id,b.id],sourcePaths:[a.path,b.path],mergeReason:candidate.reason)); do { try knowledgeDraftRepository?.saveKnowledgeDraft(draft); var resolved=candidate; resolved.status = .resolved; resolved.resolvedAt=Date(); try knowledgeDraftRepository?.saveKnowledgeQualityCandidate(resolved); knowledgeDraft=draft; loadKnowledge(); knowledgeDraftMessage="Merge Draftを作成しました。元のKnowledgeは変更していません。" } catch { knowledgeDraftError="Merge Draftを作成できませんでした。" } }
    func archiveKnowledge(_ document:KnowledgeDocument) { guard document.status == .active else{return}; var value=document; value.status = .archived; value.archivedAt=Date(); do { try knowledgeDraftRepository?.saveKnowledgeDocument(value); externalBrainManager.excludeFromRetrieval(path:value.path); loadKnowledge() } catch { knowledgeDraftError="Archiveできませんでした。" } }
    func supersedeKnowledge(_ old:KnowledgeDocument,by new:KnowledgeDocument) { guard old.status == .active,new.status == .active,old.id != new.id else{return}; var value=old; value.status = .superseded; value.supersededByKnowledgeID=new.id; value.supersededAt=Date(); do { try knowledgeDraftRepository?.saveKnowledgeDocument(value); externalBrainManager.excludeFromRetrieval(path:value.path); loadKnowledge() } catch { knowledgeDraftError="Supersedeできませんでした。" } }

    func loadAIUsageAnalytics(period: AIAPIUsagePeriod, now: Date = Date(), calendar: Calendar = .current) {
        guard let aiUsageAnalyticsRepository else { aiUsageAnalyticsError = "AI使用状況を読み込めませんでした。"; return }
        isLoadingAIUsageAnalytics = true; defer { isLoadingAIUsageAnalytics = false }
        do {
            aiUsageAnalytics = try LoadAIAPIUsageAnalytics(repository: aiUsageAnalyticsRepository, personas: personaRepository, calendar: calendar)(period: period, now: now)
            aiUsageAnalyticsError = nil
        } catch { aiUsageAnalytics = nil; aiUsageAnalyticsError = "AI使用状況を読み込めませんでした。利用履歴は変更されていません。" }
    }

    func updateHumanReplyDraft(_ value: String) { humanReplyDraft = ThoughtDraft.limited(value) }
    var canPostHumanReply: Bool { ThoughtDraft.validBody(from: humanReplyDraft) != nil }

    @discardableResult func postHumanReply(to target: Thought) -> Thought? {
        guard let humanReplyRepository, let thoughtRepository else { errorMessage = "返信を保存できませんでした。"; return nil }
        let targetAuthor = personasByThoughtID[target.id]
        let mentionID = targetAuthor?.kind == .ai && targetAuthor?.deletedAt == nil ? targetAuthor?.id : nil
        do {
            guard let reply = try humanReplyRepository.createHumanReply(body: humanReplyDraft, targetThoughtID: target.id, mentionedPersonaID: mentionID, now: Date(), thoughtID: UUID(), relationID: UUID()) else { return nil }
            timeline = try ThoughtTimeline(repository: thoughtRepository); thoughts = timeline?.thoughts ?? []; humanReplyDraft = ""
            refreshAuthors(for: thoughts.map(\.id)); refreshMentions(for: thoughts.map(\.id)); refreshReplyRelations(for: thoughts.map(\.id)); loadAIReplies(to: target.id)
            return reply
        } catch { errorMessage = "返信を保存できませんでした。入力内容は残しています。"; return nil }
    }

    func loadHistory(for thoughtID: UUID) {
        guard let thoughtRepository, let relationRepository else {
            errorMessage = "Thought Historyを読み込めませんでした。"
            return
        }
        do {
            history = try ThoughtHistory(
                thoughtRepository: thoughtRepository,
                relationRepository: relationRepository
            ).entries(containing: thoughtID)
            historyCurrentID = thoughtID
            refreshTags(for: history.map(\.id))
        } catch {
            errorMessage = "Thought Historyを読み込めませんでした。"
        }
    }

    func search(_ query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        hasSearchQuery = !normalized.isEmpty
        guard hasSearchQuery else {
            searchResults = []
            return
        }
        guard let thoughtRepository else {
            searchResults = []
            errorMessage = "Thoughtを検索できませんでした。"
            return
        }
        do {
            searchResults = try thoughtRepository.search(query: normalized)
            refreshTags(for: searchResults.map(\.id))
        } catch {
            searchResults = []
            errorMessage = "Thoughtを検索できませんでした。保存済みデータは変更されていません。"
        }
    }

    func clearSearch() {
        hasSearchQuery = false
        searchResults = []
    }

    func refreshTags(for thoughtIDs: [UUID]) {
        guard let tagRepository else { return }
        do {
            for id in thoughtIDs { tagsByThoughtID[id] = try tagRepository.fetchTags(for: id) }
        } catch { errorMessage = "タグを読み込めませんでした。" }
    }

    func loadAllTags() {
        guard let tagRepository else { return }
        do { allTags = try tagRepository.fetchAllTags() }
        catch { errorMessage = "タグ一覧を読み込めませんでした。" }
    }

    func loadThoughts(taggedWith tag: ThoughtTag) {
        guard let tagRepository else { return }
        do {
            taggedThoughts = try tagRepository.fetchThoughts(taggedWith: tag.id)
            refreshTags(for: taggedThoughts.map(\.id))
        } catch {
            taggedThoughts = []
            errorMessage = "タグのThoughtを読み込めませんでした。"
        }
    }

    func addTag(named name: String, to thoughtID: UUID) {
        guard let tagRepository else { return }
        do {
            switch try tagRepository.addTag(named: name, to: thoughtID) {
            case .added:
                tagMessage = nil
                refreshTags(for: [thoughtID])
                loadAllTags()
            case .alreadyAttached:
                tagMessage = "このタグはすでに付いています。"
            case .invalidName:
                tagMessage = "空のタグは追加できません。"
            }
        } catch { tagMessage = "タグを追加できませんでした。" }
    }

    func removeTag(_ tag: ThoughtTag, from thoughtID: UUID) {
        guard let tagRepository else { return }
        do {
            _ = try tagRepository.removeTag(id: tag.id, from: thoughtID)
            tagMessage = nil
            refreshTags(for: [thoughtID])
            loadAllTags()
        } catch { tagMessage = "タグを削除できませんでした。" }
    }

    @discardableResult
    func postContinuation(parentThoughtID: UUID) -> Thought? {
        guard let continuationRepository, let thoughtRepository else {
            errorMessage = "保存先を利用できないため続きを投稿できません。入力内容は残しています。"
            return nil
        }
        do {
            guard let thought = try continuationRepository.createContinuation(
                body: continuationDraft,
                parentThoughtID: parentThoughtID
            ) else { return nil }
            timeline = try ThoughtTimeline(repository: thoughtRepository)
            thoughts = timeline?.thoughts ?? []
            refreshTags(for: thoughts.map(\.id))
            refreshAuthors(for: thoughts.map(\.id))
            continuationDraft = ""
            loadHistory(for: thought.id)
            return thought
        } catch {
            errorMessage = "続きを保存できませんでした。入力内容は残しています。"
            return nil
        }
    }

    @discardableResult
    func post() -> Bool {
        guard post(draft, mentioning: selectedMentionPersona) else { return false }
        draft = ""
        selectedMentionPersona = nil
        return true
    }

    /// Shared posting boundary for Timeline Composer and Quick Capture.
    /// The caller owns and clears its draft only after this returns success.
    @discardableResult
    func post(_ body: String, mentioning persona: Persona? = nil) -> Bool {
        guard !isPosting else { return false }
        guard var timeline, let thoughtRepository else {
            errorMessage = "保存先を利用できないため投稿できません。入力内容は残しています。"
            return false
        }
        isPosting = true
        defer { isPosting = false }
        do {
            if let persona {
                guard let mentionRepository, let validBody = ThoughtDraft.validBody(from: body) else { return false }
                try mentionRepository.create(Thought(body: validBody), authorPersonaID: Persona.defaultHumanID, mentionedPersonaID: persona.id)
                timeline = try ThoughtTimeline(repository: thoughtRepository)
            } else {
                guard try timeline.post(body) != nil else { return false }
            }
            self.timeline = timeline; thoughts = timeline.thoughts
            refreshTags(for: thoughts.map(\.id))
            refreshAuthors(for: thoughts.map(\.id))
            refreshMentions(for: thoughts.map(\.id))
            refreshReplyRelations(for: thoughts.map(\.id))
            return true
        } catch {
            errorMessage = "Thoughtを保存できませんでした。"
            return false
        }
    }

    func requestDeletion(of thought: Thought) {
        deletionCandidate = thought
    }

    func cancelDeletion() {
        deletionCandidate = nil
    }

    func confirmDeletion() {
        guard let candidate = deletionCandidate, var timeline else { return }
        do {
            _ = try timeline.delete(id: candidate.id)
            self.timeline = timeline
            thoughts = timeline.thoughts
            refreshTags(for: thoughts.map(\.id))
            loadAllTags()
            deletionCandidate = nil
            if let historyCurrentID { loadHistory(for: historyCurrentID) }
        } catch {
            errorMessage = "Thoughtを削除できませんでした。"
        }
    }
}
