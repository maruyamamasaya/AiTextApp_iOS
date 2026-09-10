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

public enum PersonaKind: String, Codable, Sendable {
    case human
    case ai
}

public struct Persona: Identifiable, Equatable, Sendable {
    public static let defaultHumanID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public let id: UUID
    public var displayName: String
    public let kind: PersonaKind
    public var iconData: Data?
    public var iconMIMEType: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), displayName: String, kind: PersonaKind, iconData: Data? = nil, iconMIMEType: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.iconData = iconData
        self.iconMIMEType = iconMIMEType
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}

public protocol PersonaRepository: Sendable {
    func fetchDefaultHumanPersona() throws -> Persona
    func fetchPersonas(includeInactive: Bool) throws -> [Persona]
    func fetchPersona(for thoughtID: UUID) throws -> Persona?
    func fetchPersonas(for thoughtIDs: [UUID]) throws -> [UUID: Persona]
    func createPersona(_ persona: Persona) throws
    func updatePersona(_ persona: Persona) throws
    @discardableResult func deactivatePersona(id: UUID, at date: Date) throws -> Bool
}

public protocol AuthoredThoughtRepository: Sendable {
    func create(_ thought: Thought, authorPersonaID: UUID) throws
}
