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
    @Published private(set) var reviewSummaries: [ReviewSummary] = []
    @Published private(set) var isGeneratingReviewSummary = false
    @Published var reviewSummaryError: String?
    @Published var reviewSummaryDeletionError: String?
    @Published var reviewSummaryExportError: String?
    @Published private(set) var reviewSummaryPreview: ReviewSummaryPreview?
    let externalBackupManager: ExternalBackupManager?

    private var timeline: ThoughtTimeline?
    private var exporter: ThoughtExporter?
    private var thoughtRepository: (any ThoughtRepository)?
    private var relationRepository: (any ThoughtRelationRepository)?
    private var continuationRepository: (any ThoughtContinuationRepository)?
    private var summaryRepository: (any ReviewSummaryRepository)?
    private var summaryExporter: ReviewSummaryExporter?
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
            if let reviewSummaryRepository = repository as? any ReviewSummaryRepository {
                summaryRepository = reviewSummaryRepository
                summaryExporter = ReviewSummaryExporter(repository: reviewSummaryRepository)
            }
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
            reviewSummaries = try summaryRepository?.fetchSummaries(from: interval.start, to: interval.end) ?? []
            reviewSummary = reviewSummaries.first
            reviewSummaryError = nil
            reviewSummaryDeletionError = nil
            reviewSummaryExportError = nil
            reviewSummaryPreview = nil
        } catch {
            reviewInterval = interval
            reviewThoughts = []
            reviewContinuationCounts = [:]
            reviewSummary = nil
            reviewSummaries = []
            reviewSummaryDeletionError = nil
            reviewSummaryExportError = nil
            reviewSummaryPreview = nil
            errorMessage = "History Reviewを読み込めませんでした。"
        }
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
                loadReview(in: preview.interval)
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
