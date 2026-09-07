import Foundation

public protocol ThoughtRepository: Sendable {
    func create(_ thought: Thought) throws
    func fetchTimeline() throws -> [Thought]
    func fetchByID(_ id: UUID) throws -> Thought?
    func fetchAll() throws -> [Thought]
    @discardableResult func softDelete(id: UUID, at date: Date) throws -> Bool
}

/// A small repository useful for previews and domain tests. SQLite is the app's durable store.
public final class MemoryThoughtRepository: ThoughtRepository, ThoughtRelationRepository, ThoughtContinuationRepository, @unchecked Sendable {
    private var records: [Thought]
    private var relations: [ThoughtRelation]
    private let lock = NSLock()

    public init(records: [Thought] = [], relations: [ThoughtRelation] = []) {
        self.records = records
        self.relations = relations
    }

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

    public func create(_ relation: ThoughtRelation) throws {
        try lock.withLock {
            try validate(relation)
            relations.append(relation)
        }
    }

    public func fetchBySourceThoughtID(_ id: UUID) throws -> [ThoughtRelation] {
        lock.withLock { ordered(relations.filter { $0.sourceThoughtID == id }) }
    }

    public func fetchByTargetThoughtID(_ id: UUID) throws -> [ThoughtRelation] {
        lock.withLock { ordered(relations.filter { $0.targetThoughtID == id }) }
    }

    public func fetchContinuationSource(for thoughtID: UUID) throws -> ThoughtRelation? {
        try fetchBySourceThoughtID(thoughtID).first { $0.type == .continues }
    }

    public func fetchContinuations(of thoughtID: UUID) throws -> [ThoughtRelation] {
        try fetchByTargetThoughtID(thoughtID).filter { $0.type == .continues }
    }

    public func createContinuation(
        body: String,
        parentThoughtID: UUID,
        now: Date,
        thoughtID: UUID
    ) throws -> Thought? {
        guard let body = ThoughtDraft.validBody(from: body) else { return nil }
        return try lock.withLock {
            let thought = Thought(id: thoughtID, body: body, createdAt: now)
            let relation = ThoughtRelation(
                sourceThoughtID: thoughtID,
                targetThoughtID: parentThoughtID,
                createdAt: now
            )
            guard records.contains(where: { $0.id == parentThoughtID }) else {
                throw MemoryRelationError.invalidRelation
            }
            try validate(relation, includingSource: thoughtID)
            records.append(thought)
            relations.append(relation)
            return thought
        }
    }

    private func validate(_ relation: ThoughtRelation, includingSource: UUID? = nil) throws {
        guard relation.sourceThoughtID != relation.targetThoughtID,
              records.contains(where: { $0.id == relation.targetThoughtID }),
              records.contains(where: { $0.id == relation.sourceThoughtID }) || includingSource == relation.sourceThoughtID,
              !relations.contains(where: {
                  $0.sourceThoughtID == relation.sourceThoughtID &&
                  $0.targetThoughtID == relation.targetThoughtID &&
                  $0.type == relation.type
              }) else {
            throw MemoryRelationError.invalidRelation
        }
        var pending = [relation.targetThoughtID]
        var visited = Set<UUID>()
        while let candidate = pending.popLast() {
            guard visited.insert(candidate).inserted else { continue }
            if candidate == relation.sourceThoughtID { throw MemoryRelationError.invalidRelation }
            pending.append(contentsOf: relations
                .filter { $0.sourceThoughtID == candidate && $0.type == .continues }
                .map(\.targetThoughtID))
        }
    }

    private func ordered(_ values: [ThoughtRelation]) -> [ThoughtRelation] {
        values.sorted {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString
                : $0.createdAt < $1.createdAt
        }
    }
}

private enum MemoryRelationError: Error { case invalidRelation }

extension Thought {
    static func timelineOrder(_ lhs: Thought, _ rhs: Thought) -> Bool {
        lhs.createdAt == rhs.createdAt
            ? lhs.id.uuidString > rhs.id.uuidString
            : lhs.createdAt > rhs.createdAt
    }
}
