import Foundation

public protocol ThoughtRepository: Sendable {
    func create(_ thought: Thought) throws
    func fetchTimeline() throws -> [Thought]
    /// Searches active Thought bodies using a literal, trimmed substring.
    /// An empty normalized query returns no results.
    func search(query: String) throws -> [Thought]
    func fetchByID(_ id: UUID) throws -> Thought?
    func fetchAll() throws -> [Thought]
    /// Returns active Thoughts in ascending creation order. `from` is inclusive
    /// and `to` is exclusive.
    func fetchThoughts(from startDate: Date, to endDate: Date) throws -> [Thought]
    @discardableResult func softDelete(id: UUID, at date: Date) throws -> Bool
}

/// A small repository useful for previews and domain tests. SQLite is the app's durable store.
public final class MemoryThoughtRepository: ThoughtRepository, ThoughtRelationRepository, ThoughtContinuationRepository, ThoughtTagRepository, ReviewSummaryRepository, @unchecked Sendable {
    private var records: [Thought]
    private var relations: [ThoughtRelation]
    private var summaries: [ReviewSummary]
    private var tags: [ThoughtTag]
    private var thoughtTagIDs: [UUID: Set<UUID>]
    private let lock = NSLock()

    public init(records: [Thought] = [], relations: [ThoughtRelation] = [], summaries: [ReviewSummary] = [], tags: [ThoughtTag] = [], thoughtTagIDs: [UUID: Set<UUID>] = [:]) {
        self.records = records
        self.relations = relations
        self.summaries = summaries
        self.tags = tags
        self.thoughtTagIDs = thoughtTagIDs
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

    public func fetchThoughts(from startDate: Date, to endDate: Date) throws -> [Thought] {
        lock.withLock {
            records
                .filter { $0.deletedAt == nil && $0.createdAt >= startDate && $0.createdAt < endDate }
                .sorted {
                    $0.createdAt == $1.createdAt
                        ? $0.id.uuidString < $1.id.uuidString
                        : $0.createdAt < $1.createdAt
                }
        }
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

    public func addTag(named name: String, to thoughtID: UUID, at date: Date) throws -> ThoughtTagAssignment {
        guard let displayName = ThoughtTag.displayName(from: name) else { return .invalidName }
        return lock.withLock {
            guard records.contains(where: { $0.id == thoughtID && $0.deletedAt == nil }) else { return .invalidName }
            let normalized = ThoughtTag.normalize(displayName)
            let tag: ThoughtTag
            if let existing = tags.first(where: { $0.normalizedName == normalized }) {
                tag = existing
            } else {
                tag = ThoughtTag(name: displayName, normalizedName: normalized, createdAt: date)
                tags.append(tag)
            }
            if thoughtTagIDs[thoughtID, default: []].contains(tag.id) { return .alreadyAttached(tag) }
            thoughtTagIDs[thoughtID, default: []].insert(tag.id)
            return .added(tag)
        }
    }

    public func removeTag(id tagID: UUID, from thoughtID: UUID) throws -> Bool {
        lock.withLock { thoughtTagIDs[thoughtID]?.remove(tagID) != nil }
    }

    public func fetchTags(for thoughtID: UUID) throws -> [ThoughtTag] {
        lock.withLock {
            guard records.contains(where: { $0.id == thoughtID && $0.deletedAt == nil }) else { return [] }
            let ids = thoughtTagIDs[thoughtID] ?? []
            return tags.filter { ids.contains($0.id) }.sorted { $0.normalizedName < $1.normalizedName }
        }
    }

    public func fetchAllTags() throws -> [ThoughtTag] {
        lock.withLock {
            let activeIDs = Set(records.filter { $0.deletedAt == nil }.map(\.id))
            let usedTagIDs = Set(thoughtTagIDs.filter { activeIDs.contains($0.key) }.flatMap(\.value))
            return tags.filter { usedTagIDs.contains($0.id) }.sorted { $0.normalizedName < $1.normalizedName }
        }
    }

    public func fetchThoughts(taggedWith tagID: UUID) throws -> [Thought] {
        lock.withLock {
            records.filter { thought in
                thought.deletedAt == nil && thoughtTagIDs[thought.id]?.contains(tagID) == true
            }.sorted(by: Thought.timelineOrder)
        }
    }

    public func search(query: String) throws -> [Thought] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return lock.withLock {
            records
                .filter { $0.deletedAt == nil && $0.body.localizedCaseInsensitiveContains(query) }
                .sorted(by: Thought.timelineOrder)
        }
    }

    public func save(_ summary: ReviewSummary) throws {
        lock.withLock { summaries.append(summary) }
    }

    public func fetchSummary(id: UUID) throws -> ReviewSummary? {
        lock.withLock { summaries.first { $0.id == id } }
    }

    public func fetchSummaries(from startDate: Date, to endDate: Date) throws -> [ReviewSummary] {
        lock.withLock {
            summaries.filter { $0.periodStart == startDate && $0.periodEnd == endDate }
                .sorted {
                    $0.createdAt == $1.createdAt
                        ? $0.id.uuidString > $1.id.uuidString
                        : $0.createdAt > $1.createdAt
                }
        }
    }

    public func deleteSummary(id: UUID) throws -> Bool {
        lock.withLock {
            guard let index = summaries.firstIndex(where: { $0.id == id }) else { return false }
            summaries.remove(at: index)
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

    public func fetchContinuationCounts(for thoughtIDs: [UUID]) throws -> [UUID: Int] {
        let ids = Set(thoughtIDs)
        return lock.withLock {
            Dictionary(grouping: relations.filter {
                $0.type == .continues && ids.contains($0.targetThoughtID)
            }, by: \.targetThoughtID).mapValues(\.count)
        }
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

public enum ThoughtReviewPeriod {
    public static func today(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        day(containing: date, calendar: calendar)
    }

    public static func yesterday(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -1, to: today)!
        return DateInterval(start: start, end: today)
    }

    public static func pastSevenDays(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return DateInterval(start: start, end: end)
    }

    public static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }
}
