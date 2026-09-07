import Foundation

public protocol ThoughtRepository: Sendable {
    func load() throws -> [Thought]
    func save(_ thoughts: [Thought]) throws
}

public final class FileThoughtRepository: ThoughtRepository, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public convenience init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.init(fileURL: baseURL.appendingPathComponent("ThoughtTimeline/thoughts.json"), fileManager: fileManager)
    }

    public func load() throws -> [Thought] {
        lock.lock()
        defer { lock.unlock() }
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder.thoughtDecoder.decode([Thought].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ thoughts: [Thought]) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.thoughtEncoder.encode(thoughts)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var thoughtEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var thoughtDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
