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
    @Published var deletionCandidate: Thought?
    @Published var errorMessage: String?
    @Published var exportArtifact: ExportArtifact?
    @Published private(set) var history: [ThoughtHistoryEntry] = []
    @Published private(set) var historyCurrentID: UUID?
    @Published var continuationDraft = ""
    @Published private(set) var reviewThoughts: [Thought] = []
    @Published private(set) var reviewContinuationCounts: [UUID: Int] = [:]
    @Published private(set) var reviewSummary: ReviewSummary?
    @Published private(set) var isGeneratingReviewSummary = false
    @Published var reviewSummaryError: String?
    let externalBackupManager: ExternalBackupManager?

    private var timeline: ThoughtTimeline?
    private var exporter: ThoughtExporter?
    private var thoughtRepository: (any ThoughtRepository)?
    private var relationRepository: (any ThoughtRelationRepository)?
    private var continuationRepository: (any ThoughtContinuationRepository)?
    private var summaryRepository: (any ReviewSummaryRepository)?
    private let summaryClient: any ReviewSummaryClient
    private var reviewInterval: DateInterval?

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
            summaryRepository = repository as? any ReviewSummaryRepository
            exporter = ThoughtExporter(repository: repository)
            thoughts = timeline.thoughts
            if let sqliteRepository = repository as? SQLiteThoughtRepository {
                backupManager = ExternalBackupManager(repository: sqliteRepository)
            }
        } catch {
            errorMessage = "保存したThoughtを読み込めませんでした。"
        }
        externalBackupManager = backupManager
        if let startupError { errorMessage = startupError }
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
        } catch {
            errorMessage = "Thought Historyを読み込めませんでした。"
        }
    }

    func loadReview(in interval: DateInterval) {
        guard let thoughtRepository, let relationRepository else {
            errorMessage = "History Reviewを読み込めませんでした。"
            return
        }
        do {
            let thoughts = try thoughtRepository.fetchThoughts(from: interval.start, to: interval.end)
            reviewThoughts = thoughts
            reviewContinuationCounts = try relationRepository.fetchContinuationCounts(for: thoughts.map(\.id))
            reviewInterval = interval
            reviewSummary = try summaryRepository?.fetchSummaries(from: interval.start, to: interval.end).first
            reviewSummaryError = nil
        } catch {
            reviewInterval = interval
            reviewThoughts = []
            reviewContinuationCounts = [:]
            reviewSummary = nil
            errorMessage = "History Reviewを読み込めませんでした。"
        }
    }

    func generateReviewSummary(in interval: DateInterval) async {
        guard reviewInterval == interval else {
            reviewSummaryError = "選択期間を読み込み直してから再試行してください。"
            return
        }
        guard !reviewThoughts.isEmpty else {
            reviewSummaryError = ReviewSummaryError.noThoughts.localizedDescription
            return
        }
        guard let summaryRepository else {
            reviewSummaryError = "AI要約の保存先を利用できません。"
            return
        }
        let targetThoughts = reviewThoughts
        isGeneratingReviewSummary = true
        reviewSummaryError = nil
        defer { isGeneratingReviewSummary = false }
        do {
            let summary = try await GenerateReviewSummary(
                client: summaryClient,
                repository: summaryRepository
            )(thoughts: targetThoughts, interval: interval)
            if reviewInterval == interval { reviewSummary = summary }
        } catch {
            if reviewInterval == interval {
                reviewSummaryError = "AI要約を作成できませんでした。通信状態を確認して再試行してください。"
            }
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
        guard var timeline else {
            errorMessage = "保存先を利用できないため投稿できません。入力内容は残しています。"
            return false
        }
        do {
            guard try timeline.post(draft) != nil else { return false }
            self.timeline = timeline
            thoughts = timeline.thoughts
            draft = ""
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
            deletionCandidate = nil
            if let historyCurrentID { loadHistory(for: historyCurrentID) }
        } catch {
            errorMessage = "Thoughtを削除できませんでした。"
        }
    }
}
