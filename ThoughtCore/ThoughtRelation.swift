import Foundation

public struct ThoughtRelation: Codable, Identifiable, Equatable, Sendable {
    public enum RelationType: String, Codable, Sendable {
        case continues
        case repliesTo
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
    func fetchContinuationCounts(for thoughtIDs: [UUID]) throws -> [UUID: Int]
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

public protocol HumanThoughtReplyRepository: Sendable {
    func createHumanReply(body: String, targetThoughtID: UUID, mentionedPersonaID: UUID?, now: Date, thoughtID: UUID, relationID: UUID) throws -> Thought?
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

public struct ConversationNode: Identifiable, Equatable, Sendable {
    public let thought: Thought
    public let depth: Int
    public let incomingRelation: ThoughtRelation?
    public let isOnCurrentPath: Bool
    public let hasBranches: Bool
    public var id: UUID { thought.id }

    public init(thought: Thought, depth: Int, incomingRelation: ThoughtRelation?, isOnCurrentPath: Bool, hasBranches: Bool) {
        self.thought = thought; self.depth = depth; self.incomingRelation = incomingRelation
        self.isOnCurrentPath = isOnCurrentPath; self.hasBranches = hasBranches
    }
}

/// Thoughtと既存Relationだけから再構築する会話ツリー。
public struct ConversationThread: Equatable, Sendable {
    public let root: Thought
    public let nodes: [ConversationNode]
    public let edges: [ThoughtRelation]
    public let currentPath: [Thought]
    public let leaves: [Thought]
    public let selectedThoughtID: UUID

    public var lastThought: Thought {
        leaves.max {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        } ?? currentPath.last ?? root
    }
}

public struct LoadConversationThread: Sendable {
    private let thoughts: any ThoughtRepository
    private let relations: any ThoughtRelationRepository

    public init(thoughts: any ThoughtRepository, relations: any ThoughtRelationRepository) {
        self.thoughts = thoughts; self.relations = relations
    }

    public func callAsFunction(containing thoughtID: UUID) throws -> ConversationThread {
        guard try thoughts.fetchByID(thoughtID) != nil else { throw CocoaError(.fileNoSuchFile) }
        var rootID = thoughtID
        var ancestors = Set<UUID>()
        var parentEdges: [ThoughtRelation] = []
        while ancestors.insert(rootID).inserted, let parent = try relations.fetchBySourceThoughtID(rootID).first {
            parentEdges.append(parent); rootID = parent.targetThoughtID
        }
        guard let root = try thoughts.fetchByID(rootID) else { throw CocoaError(.fileNoSuchFile) }
        let pathIDs = Set([thoughtID] + parentEdges.map(\.targetThoughtID))
        var visited = Set<UUID>(), nodes: [ConversationNode] = [], edges: [ThoughtRelation] = [], leaves: [Thought] = []
        try append(from: rootID, depth: 0, incoming: nil, pathIDs: pathIDs, visited: &visited, nodes: &nodes, edges: &edges, leaves: &leaves)
        let currentPath = nodes.filter { pathIDs.contains($0.id) }.sorted { $0.depth < $1.depth }.map(\.thought)
        return .init(root: root, nodes: nodes, edges: edges, currentPath: currentPath, leaves: leaves, selectedThoughtID: thoughtID)
    }

    private func append(from id: UUID, depth: Int, incoming: ThoughtRelation?, pathIDs: Set<UUID>, visited: inout Set<UUID>, nodes: inout [ConversationNode], edges: inout [ThoughtRelation], leaves: inout [Thought]) throws {
        guard visited.insert(id).inserted, let thought = try thoughts.fetchByID(id) else { return }
        let children = try relations.fetchByTargetThoughtID(id)
        nodes.append(.init(thought: thought, depth: depth, incomingRelation: incoming, isOnCurrentPath: pathIDs.contains(id), hasBranches: children.count > 1))
        if children.isEmpty { leaves.append(thought) }
        for relation in children {
            edges.append(relation)
            try append(from: relation.sourceThoughtID, depth: depth + 1, incoming: relation, pathIDs: pathIDs, visited: &visited, nodes: &nodes, edges: &edges, leaves: &leaves)
        }
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
