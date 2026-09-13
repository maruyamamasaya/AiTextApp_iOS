import Foundation

public struct ThoughtTimeline: Sendable {
    private let repository: any ThoughtRepository
    public let pageSize: Int
    public private(set) var thoughts: [Thought]
    public private(set) var hasMore: Bool

    public init(repository: any ThoughtRepository, pageSize: Int = 50) throws {
        precondition(pageSize > 0)
        self.repository = repository
        self.pageSize = pageSize
        let page = try repository.fetchTimelinePage(limit: pageSize + 1, before: nil)
        thoughts = Array(page.prefix(pageSize))
        hasMore = page.count > pageSize
    }

    @discardableResult
    public mutating func loadMore() throws -> [Thought] {
        guard hasMore, let cursor = thoughts.last else {
            hasMore = false
            return []
        }
        let page = try repository.fetchTimelinePage(limit: pageSize + 1, before: cursor)
        let appended = Array(page.prefix(pageSize))
        thoughts.append(contentsOf: appended)
        hasMore = page.count > pageSize
        return appended
    }

    @discardableResult
    public mutating func post(_ draft: String, now: Date = Date(), id: UUID = UUID()) throws -> Thought? {
        guard let body = ThoughtDraft.validBody(from: draft) else { return nil }
        let thought = Thought(id: id, body: body, createdAt: now)
        try repository.create(thought)
        try reload()
        return thought
    }

    @discardableResult
    public mutating func delete(id: UUID, now: Date = Date()) throws -> Bool {
        let deleted = try repository.softDelete(id: id, at: now)
        if deleted { try reload() }
        return deleted
    }

    private mutating func reload() throws {
        let visibleCount = max(pageSize, thoughts.count)
        let page = try repository.fetchTimelinePage(limit: visibleCount + 1, before: nil)
        thoughts = Array(page.prefix(visibleCount))
        hasMore = page.count > visibleCount
    }
}
