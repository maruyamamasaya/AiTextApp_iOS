import Foundation

public struct ThoughtTimeline: Sendable {
    private let repository: any ThoughtRepository
    private var records: [Thought]

    public init(repository: any ThoughtRepository) throws {
        self.repository = repository
        records = try repository.load()
    }

    public var thoughts: [Thought] {
        records
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString > $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    @discardableResult
    public mutating func post(_ draft: String, now: Date = Date(), id: UUID = UUID()) throws -> Thought? {
        guard let body = ThoughtDraft.validBody(from: draft) else { return nil }
        let thought = Thought(id: id, body: body, createdAt: now)
        var updatedRecords = records
        updatedRecords.append(thought)
        try repository.save(updatedRecords)
        records = updatedRecords
        return thought
    }

    @discardableResult
    public mutating func delete(id: UUID, now: Date = Date()) throws -> Bool {
        guard let index = records.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            return false
        }
        var updatedRecords = records
        updatedRecords[index].deletedAt = now
        try repository.save(updatedRecords)
        records = updatedRecords
        return true
    }
}
