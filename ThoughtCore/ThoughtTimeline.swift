import Foundation

public struct ThoughtTimeline: Sendable {
    private let repository: any ThoughtRepository
    public private(set) var thoughts: [Thought]

    public init(repository: any ThoughtRepository) throws {
        self.repository = repository
        thoughts = try repository.fetchTimeline()
    }

    @discardableResult
    public mutating func post(_ draft: String, now: Date = Date(), id: UUID = UUID()) throws -> Thought? {
        guard let body = ThoughtDraft.validBody(from: draft) else { return nil }
        let thought = Thought(id: id, body: body, createdAt: now)
        try repository.create(thought)
        thoughts = try repository.fetchTimeline()
        return thought
    }

    @discardableResult
    public mutating func delete(id: UUID, now: Date = Date()) throws -> Bool {
        let deleted = try repository.softDelete(id: id, at: now)
        if deleted { thoughts = try repository.fetchTimeline() }
        return deleted
    }
}
