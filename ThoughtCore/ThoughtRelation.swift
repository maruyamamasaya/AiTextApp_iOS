import Foundation

public struct ThoughtRelation: Codable, Identifiable, Equatable, Sendable {
    public enum RelationType: String, Codable, Sendable {
        case continues
    }

    public let id: UUID
    /// The newer Thought that was produced from the context of `targetThoughtID`.
    public let sourceThoughtID: UUID
    /// The earlier Thought that the source continues.
    public let targetThoughtID: UUID
    public let type: RelationType
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceThoughtID: UUID,
        targetThoughtID: UUID,
        type: RelationType = .continues,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceThoughtID = sourceThoughtID
        self.targetThoughtID = targetThoughtID
        self.type = type
        self.createdAt = createdAt
    }
}

public protocol ThoughtRelationRepository: Sendable {
    func create(_ relation: ThoughtRelation) throws
    func fetchBySourceThoughtID(_ id: UUID) throws -> [ThoughtRelation]
    func fetchByTargetThoughtID(_ id: UUID) throws -> [ThoughtRelation]
    func fetchContinuationSource(for thoughtID: UUID) throws -> ThoughtRelation?
    func fetchContinuations(of thoughtID: UUID) throws -> [ThoughtRelation]
}

public protocol ThoughtContinuationRepository: Sendable {
    @discardableResult
    func createContinuation(
        body: String,
        parentThoughtID: UUID,
        now: Date,
        thoughtID: UUID
    ) throws -> Thought?
}

public extension ThoughtContinuationRepository {
    @discardableResult
    func createContinuation(
        body: String,
        parentThoughtID: UUID,
        now: Date = Date()
    ) throws -> Thought? {
        try createContinuation(body: body, parentThoughtID: parentThoughtID, now: now, thoughtID: UUID())
    }
}

public struct ThoughtHistoryEntry: Identifiable, Equatable, Sendable {
    public let thought: Thought
    public let depth: Int
    public var id: UUID { thought.id }

    public init(thought: Thought, depth: Int) {
        self.thought = thought
        self.depth = depth
    }
}

/// Loads one continuation history without fetching the complete Thought table.
/// A current Thought is first traced to its oldest ancestor, then each branch is
/// flattened depth-first in the repository's stable relation order.
public struct ThoughtHistory: Sendable {
    private let thoughtRepository: any ThoughtRepository
    private let relationRepository: any ThoughtRelationRepository

    public init(
        thoughtRepository: any ThoughtRepository,
        relationRepository: any ThoughtRelationRepository
    ) {
        self.thoughtRepository = thoughtRepository
        self.relationRepository = relationRepository
    }

    public func entries(containing thoughtID: UUID) throws -> [ThoughtHistoryEntry] {
        var rootID = thoughtID
        var ancestors = Set<UUID>()
        while ancestors.insert(rootID).inserted,
              let parent = try relationRepository.fetchContinuationSource(for: rootID) {
            rootID = parent.targetThoughtID
        }

        var visited = Set<UUID>()
        var output: [ThoughtHistoryEntry] = []
        try appendBranch(from: rootID, depth: 0, visited: &visited, output: &output)
        return output
    }

    private func appendBranch(
        from thoughtID: UUID,
        depth: Int,
        visited: inout Set<UUID>,
        output: inout [ThoughtHistoryEntry]
    ) throws {
        guard visited.insert(thoughtID).inserted else { return }
        if let thought = try thoughtRepository.fetchByID(thoughtID) {
            output.append(ThoughtHistoryEntry(thought: thought, depth: depth))
        }
        for relation in try relationRepository.fetchContinuations(of: thoughtID) {
            try appendBranch(from: relation.sourceThoughtID, depth: depth + 1, visited: &visited, output: &output)
        }
    }
}
