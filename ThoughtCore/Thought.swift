import Foundation

/// The canonical, human-authored text. AI-derived metadata belongs in separate models.
public struct Thought: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}
