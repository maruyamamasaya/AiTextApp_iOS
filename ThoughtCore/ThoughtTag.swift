import Foundation

public struct ThoughtTag: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let normalizedName: String
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, normalizedName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName ?? Self.normalize(name)
        self.createdAt = createdAt
    }

    public static func displayName(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.precomposedStringWithCanonicalMapping
    }

    public static func normalize(_ value: String) -> String {
        guard let displayName = displayName(from: value) else { return "" }
        return displayName.lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

public enum ThoughtTagAssignment: Equatable, Sendable {
    case added(ThoughtTag)
    case alreadyAttached(ThoughtTag)
    case invalidName
}

public protocol ThoughtTagRepository: Sendable {
    func addTag(named name: String, to thoughtID: UUID, at date: Date) throws -> ThoughtTagAssignment
    @discardableResult func removeTag(id tagID: UUID, from thoughtID: UUID) throws -> Bool
    func fetchTags(for thoughtID: UUID) throws -> [ThoughtTag]
    func fetchAllTags() throws -> [ThoughtTag]
    func fetchThoughts(taggedWith tagID: UUID) throws -> [Thought]
    /// Returns active Thoughts in the date range carrying one tag, ordered for Review.
    /// `from` is inclusive and `to` is exclusive.
    func fetchThoughts(from startDate: Date, to endDate: Date, taggedWith tagID: UUID) throws -> [Thought]
}

public extension ThoughtTagRepository {
    func addTag(named name: String, to thoughtID: UUID) throws -> ThoughtTagAssignment {
        try addTag(named: name, to: thoughtID, at: Date())
    }
}
