import Combine
import Foundation

@MainActor
final class ThoughtStore: ObservableObject {
    @Published var draft = ""
    @Published private(set) var thoughts: [Thought] = []
    @Published var deletionCandidate: Thought?
    @Published var errorMessage: String?

    private var timeline: ThoughtTimeline?

    init(repository: (any ThoughtRepository)? = nil) {
        do {
            let repository = try repository ?? SQLiteThoughtRepository()
            let timeline = try ThoughtTimeline(repository: repository)
            self.timeline = timeline
            thoughts = timeline.thoughts
        } catch {
            errorMessage = "保存したThoughtを読み込めませんでした。"
        }
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
        guard var timeline else { return false }
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
