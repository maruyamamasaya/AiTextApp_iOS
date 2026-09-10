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
    @Published private(set) var reviewThoughts: [Thought] = []
    @Published private(set) var reviewPeriodThoughtCount = 0
    @Published private(set) var reviewContinuationCounts: [UUID: Int] = [:]
    @Published private(set) var reviewSummary: ReviewSummary?
    @Published private(set) var reviewSummaries: [ReviewSummary] = []
    @Published private(set) var isGeneratingReviewSummary = false
    @Published var reviewSummaryError: String?
    @Published var reviewSummaryDeletionError: String?
    @Published var reviewSummaryExportError: String?
    @Published private(set) var reviewSummaryPreview: ReviewSummaryPreview?
    @Published private(set) var analytics: ThoughtAnalyticsSnapshot?
    @Published private(set) var isLoadingAnalytics = false
    let externalBackupManager: ExternalBackupManager?

    private var timeline: ThoughtTimeline?
    private var exporter: ThoughtExporter?
    private var thoughtRepository: (any ThoughtRepository)?
    private var relationRepository: (any ThoughtRelationRepository)?
    private var continuationRepository: (any ThoughtContinuationRepository)?
    private var tagRepository: (any ThoughtTagRepository)?
    private var analyticsRepository: (any ThoughtAnalyticsRepository)?
    private var summaryRepository: (any ReviewSummaryRepository)?
    private var dailySummaryRepository: (any DailySummaryRepository)?
    private var personaRepository: (any PersonaRepository)?
    private var summaryExporter: ReviewSummaryExporter?
    private let summaryClient: any ReviewSummaryClient
    private var reviewInterval: DateInterval?
    private var reviewTag: ThoughtTag?
    private var isPosting = false

    init(
        repository: (any ThoughtRepository)? = nil,
        summaryClient: any ReviewSummaryClient = MockReviewSummaryClient(),
        startupError: String? = nil
    ) {
        self.summaryClient = summaryClient
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
            if let reviewSummaryRepository = repository as? any ReviewSummaryRepository {
                summaryRepository = reviewSummaryRepository
                summaryExporter = ReviewSummaryExporter(repository: reviewSummaryRepository)
            }
            dailySummaryRepository = repository as? any DailySummaryRepository
            personaRepository = repository as? any PersonaRepository
            exporter = ThoughtExporter(repository: repository)
            thoughts = timeline.thoughts
            if let personaRepository { defaultHumanPersona = try personaRepository.fetchDefaultHumanPersona() }
            if let personaRepository { personas = try personaRepository.fetchPersonas(includeInactive: false) }
            dailySummaries = try dailySummaryRepository?.fetchDailySummaries(from: .distantPast, to: .distantFuture) ?? []
            if let sqliteRepository = repository as? SQLiteThoughtRepository {
                backupManager = ExternalBackupManager(repository: sqliteRepository)
            }
        } catch {
            errorMessage = "保存したThoughtを読み込めませんでした。"
        }
        externalBackupManager = backupManager
        refreshTags(for: thoughts.map(\.id))
        refreshAuthors(for: thoughts.map(\.id))
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

    func createAIPersona(displayName: String, iconData: Data?) -> Bool {
        guard let personaRepository else { errorMessage = "AI Personaを保存できませんでした。"; return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { errorMessage = "表示名は1〜40文字で入力してください。"; return false }
        let persona = Persona(displayName: name, kind: .ai, iconData: iconData, iconMIMEType: iconData == nil ? nil : "image/jpeg")
        do { try personaRepository.createPersona(persona); loadPersonas(); return true }
        catch { errorMessage = "AI Personaを保存できませんでした。"; return false }
    }

    func updateAIPersona(_ original: Persona, displayName: String, iconData: Data?) -> Bool {
        guard original.kind == .ai, let personaRepository else { return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { errorMessage = "表示名は1〜40文字で入力してください。"; return false }
        var persona = original; persona.displayName = name; persona.iconData = iconData; persona.iconMIMEType = iconData == nil ? nil : "image/jpeg"; persona.updatedAt = Date()
        do { try personaRepository.updatePersona(persona); loadPersonas(); refreshAuthors(for: thoughts.map(\.id)); return true }
        catch { errorMessage = "AI Personaを保存できませんでした。"; return false }
    }

    func deactivateAIPersona(_ persona: Persona) {
        guard persona.kind == .ai, let personaRepository else { return }
        do { _ = try personaRepository.deactivatePersona(id: persona.id, at: Date()); loadPersonas() }
        catch { errorMessage = "AI Personaを無効化できませんでした。" }
    }

    private func loadPersonas() {
        do { personas = try personaRepository?.fetchPersonas(includeInactive: false) ?? [] }
        catch { errorMessage = "Personaを読み込めませんでした。" }
    }

    private func refreshAuthors(for ids: [UUID]) {
        guard let personaRepository else { return }
        if let values = try? personaRepository.fetchPersonas(for: ids) { personasByThoughtID.merge(values) { _, new in new } }
    }

    func loadDailySummary(for day: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        do {
            dailySummary = try dailySummaryRepository?.fetchDailySummary(dayStart: start)
            if let thoughtRepository, let tagRepository, let relationRepository,
               let preview = try? PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository)(day: day, calendar: calendar) {
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
        guard let thoughtRepository, let tagRepository, let relationRepository else { dailySummaryError = "要約対象を読み込めませんでした。"; return }
        do {
            dailySummaryPreview = try PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository)(day: day, calendar: calendar)
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
            guard let tagRepository, let relationRepository else { throw ReviewSummaryError.stalePreview }
            let current = try PrepareDailySummary(thoughts: thoughtRepository, tags: tagRepository, relations: relationRepository)(day: preview.interval.start)
            guard current.thoughts == preview.thoughts && current.existingTags == preview.existingTags && current.continuationCount == preview.continuationCount else { throw ReviewSummaryError.stalePreview }
            let value = try await GenerateDailySummary(client: summaryClient, repository: dailySummaryRepository)(preview: preview)
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

    func loadReview(in interval: DateInterval, tag: ThoughtTag? = nil) {
        guard let thoughtRepository, let relationRepository else {
            errorMessage = "History Reviewを読み込めませんでした。"
            return
        }
        do {
            let periodThoughts = try thoughtRepository.fetchThoughts(from: interval.start, to: interval.end)
            let displayedThoughts: [Thought]
            if let tag {
                guard let tagRepository else { throw NSError(domain: "ThoughtTagRepository", code: 1) }
                displayedThoughts = try tagRepository.fetchThoughts(
                    from: interval.start,
                    to: interval.end,
                    taggedWith: tag.id
                )
            } else {
                displayedThoughts = periodThoughts
            }
            reviewThoughts = displayedThoughts
            reviewPeriodThoughtCount = periodThoughts.count
            reviewContinuationCounts = try relationRepository.fetchContinuationCounts(for: displayedThoughts.map(\.id))
            reviewInterval = interval
            reviewTag = tag
            reviewSummaries = try summaryRepository?.fetchSummaries(from: interval.start, to: interval.end) ?? []
            reviewSummary = reviewSummaries.first
            reviewSummaryError = nil
            reviewSummaryDeletionError = nil
            reviewSummaryExportError = nil
            reviewSummaryPreview = nil
        } catch {
            reviewInterval = interval
            reviewThoughts = []
            reviewPeriodThoughtCount = 0
            reviewContinuationCounts = [:]
            reviewSummary = nil
            reviewSummaries = []
            reviewSummaryDeletionError = nil
            reviewSummaryExportError = nil
            reviewSummaryPreview = nil
            reviewTag = tag
            errorMessage = "History Reviewを読み込めませんでした。"
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

    func prepareReviewSummary(in interval: DateInterval) {
        guard reviewInterval == interval, let thoughtRepository else {
            reviewSummaryError = "選択期間を読み込み直してから再試行してください。"
            return
        }
        do {
            reviewSummaryPreview = try PrepareReviewSummary(repository: thoughtRepository)(interval: interval)
            reviewSummaryError = nil
        } catch ReviewSummaryError.noThoughts {
            reviewSummaryPreview = nil
            reviewSummaryError = ReviewSummaryError.noThoughts.localizedDescription
        } catch {
            reviewSummaryPreview = nil
            reviewSummaryError = "要約対象を準備できませんでした。もう一度お試しください。"
        }
    }

    func cancelReviewSummaryPreview() {
        reviewSummaryPreview = nil
    }

    func generateReviewSummary(from preview: ReviewSummaryPreview) async {
        guard let summaryRepository else {
            reviewSummaryError = "AI要約の保存先を利用できません。"
            return
        }
        guard let thoughtRepository, reviewInterval == preview.interval else {
            reviewSummaryError = "選択期間が変わりました。現在の期間でもう一度確認してください。"
            return
        }
        isGeneratingReviewSummary = true
        reviewSummaryError = nil
        defer { isGeneratingReviewSummary = false }
        do {
            do {
                try ValidateReviewSummaryPreview(repository: thoughtRepository)(preview)
            } catch ReviewSummaryError.stalePreview {
                loadReview(in: preview.interval, tag: reviewTag)
                reviewSummaryError = "確認後にThoughtが変更されました。送信せず、対象を読み込み直しました。"
                return
            }
            let summary = try await GenerateReviewSummary(
                client: summaryClient,
                repository: summaryRepository
            )(preview: preview)
            if reviewInterval == preview.interval {
                reviewSummaries.insert(summary, at: 0)
                reviewSummary = summary
            }
        } catch let error as ReviewSummaryServiceError {
            if reviewInterval == preview.interval {
                reviewSummaryError = error.localizedDescription
            }
        } catch ReviewSummaryError.emptyResponse {
            if reviewInterval == preview.interval {
                reviewSummaryError = ReviewSummaryError.emptyResponse.localizedDescription
            }
        } catch {
            if reviewInterval == preview.interval {
                reviewSummaryError = "AI要約を作成できませんでした。通信状態を確認して再試行してください。"
            }
        }
    }

    func deleteReviewSummary(id: UUID) {
        guard let summaryRepository else {
            reviewSummaryDeletionError = "AI要約の保存先を利用できません。"
            return
        }
        do {
            guard try summaryRepository.deleteSummary(id: id) else {
                reviewSummaryDeletionError = "選択したAI要約はすでに削除されています。"
                return
            }
            reviewSummaries.removeAll { $0.id == id }
            reviewSummary = reviewSummaries.first
            reviewSummaryDeletionError = nil
            reviewSummaryExportError = nil
        } catch {
            reviewSummaryDeletionError = "AI要約を削除できませんでした。もう一度お試しください。"
        }
    }

    func exportReviewSummary(id: UUID, format: ReviewSummaryExportFormat) {
        guard let summaryExporter else {
            reviewSummaryExportError = "AI要約をExportできませんでした。"
            return
        }
        do {
            exportArtifact = ExportArtifact(url: try summaryExporter.write(summaryID: id, format: format))
            reviewSummaryExportError = nil
        } catch ReviewSummaryExportError.summaryNotFound {
            reviewSummaryExportError = "選択したAI要約は削除されているためExportできません。"
        } catch {
            reviewSummaryExportError = "AI要約をExportできませんでした。保存済みデータは変更されていません。"
        }
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
        guard post(draft) else { return false }
        draft = ""
        return true
    }

    /// Shared posting boundary for Timeline Composer and Quick Capture.
    /// The caller owns and clears its draft only after this returns success.
    @discardableResult
    func post(_ body: String) -> Bool {
        guard !isPosting else { return false }
        guard var timeline else {
            errorMessage = "保存先を利用できないため投稿できません。入力内容は残しています。"
            return false
        }
        isPosting = true
        defer { isPosting = false }
        do {
            guard try timeline.post(body) != nil else { return false }
            self.timeline = timeline
            thoughts = timeline.thoughts
            refreshTags(for: thoughts.map(\.id))
            refreshAuthors(for: thoughts.map(\.id))
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
