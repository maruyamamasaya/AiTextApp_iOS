import Foundation

public protocol ThoughtRepository: Sendable {
    func create(_ thought: Thought) throws
    func fetchTimeline() throws -> [Thought]
    func fetchByID(_ id: UUID) throws -> Thought?
    func fetchAll() throws -> [Thought]
    @discardableResult func softDelete(id: UUID, at date: Date) throws -> Bool
}

/// A small repository useful for previews and domain tests. SQLite is the app's durable store.
public final class MemoryThoughtRepository: ThoughtRepository, @unchecked Sendable {
    private var records: [Thought]
    private let lock = NSLock()

    public init(records: [Thought] = []) { self.records = records }

    public func create(_ thought: Thought) throws {
        lock.withLock { records.append(thought) }
    }

    public func fetchTimeline() throws -> [Thought] {
        lock.withLock {
            records.filter { $0.deletedAt == nil }.sorted(by: Thought.timelineOrder)
        }
    }

    public func fetchByID(_ id: UUID) throws -> Thought? {
        lock.withLock { records.first { $0.id == id } }
    }

    public func fetchAll() throws -> [Thought] {
        lock.withLock { records.sorted(by: Thought.timelineOrder) }
    }

    public func softDelete(id: UUID, at date: Date) throws -> Bool {
        lock.withLock {
            guard let index = records.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
                return false
            }
            records[index].deletedAt = date
            return true
        }
    }
}

extension Thought {
    static func timelineOrder(_ lhs: Thought, _ rhs: Thought) -> Bool {
        lhs.createdAt == rhs.createdAt
            ? lhs.id.uuidString > rhs.id.uuidString
            : lhs.createdAt > rhs.createdAt
    }
}
