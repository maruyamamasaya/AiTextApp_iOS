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

    private var timeline: ThoughtTimeline?
    private var exporter: ThoughtExporter?

    init(repository: (any ThoughtRepository)? = nil) {
        do {
            let repository = try repository ?? SQLiteThoughtRepository()
            let timeline = try ThoughtTimeline(repository: repository)
            self.timeline = timeline
            exporter = ThoughtExporter(repository: repository)
            thoughts = timeline.thoughts
        } catch {
            errorMessage = "保存したThoughtを読み込めませんでした。"
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
        } catch {
            errorMessage = "Thoughtを削除できませんでした。"
        }
    }
}
