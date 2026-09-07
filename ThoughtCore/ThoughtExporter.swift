import Foundation

public enum ThoughtExportFormat: String, Sendable {
    case markdown
    case json

    public var fileExtension: String { rawValue == "markdown" ? "md" : "json" }
}

/// Produces portable snapshots through the repository boundary. Deleted records are
/// intentionally excluded from user-facing exports while the JSON shape keeps a
/// nullable `deletedAt` field for future import compatibility.
public struct ThoughtExporter: Sendable {
    private let repository: any ThoughtRepository
    private let calendar: Calendar
    private let timeZone: TimeZone

    public init(
        repository: any ThoughtRepository,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        self.repository = repository
        self.calendar = calendar
        self.timeZone = timeZone
    }

    public func data(for format: ThoughtExportFormat) throws -> Data {
        let thoughts = try repository.fetchTimeline()
        switch format {
        case .markdown:
            return Data(markdown(from: thoughts).utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(thoughts.map(ExportRecord.init))
        }
    }

    private struct ExportRecord: Encodable {
        let thought: Thought

        init(_ thought: Thought) { self.thought = thought }

        enum CodingKeys: String, CodingKey { case id, body, createdAt, updatedAt, deletedAt }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(thought.id, forKey: .id)
            try container.encode(thought.body, forKey: .body)
            try container.encode(thought.createdAt, forKey: .createdAt)
            try container.encode(thought.updatedAt, forKey: .updatedAt)
            if let deletedAt = thought.deletedAt {
                try container.encode(deletedAt, forKey: .deletedAt)
            } else {
                try container.encodeNil(forKey: .deletedAt)
            }
        }
    }

    public func write(
        _ format: ThoughtExportFormat,
        to directory: URL = FileManager.default.temporaryDirectory,
        now: Date = Date()
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Self.fileDateFormatter().string(from: now)
        let url = directory.appendingPathComponent("thought-export-\(stamp).\(format.fileExtension)")
        try data(for: format).write(to: url, options: .atomic)
        return url
    }

    public func markdown(from thoughts: [Thought]) -> String {
        var output = "# Thought Export\n"
        guard !thoughts.isEmpty else { return output + "\n" }

        var configuredCalendar = calendar
        configuredCalendar.timeZone = timeZone
        let sorted = thoughts.filter { $0.deletedAt == nil }.sorted(by: Thought.timelineOrder)
        var previousDay: DateComponents?

        for thought in sorted {
            let day = configuredCalendar.dateComponents([.year, .month, .day], from: thought.createdAt)
            if day != previousDay {
                output += "\n## \(Self.dateFormatter(timeZone: timeZone).string(from: thought.createdAt))\n"
                previousDay = day
            }
            output += "\n### \(Self.timeFormatter(timeZone: timeZone).string(from: thought.createdAt))\n\n"
            output += thought.body + "\n"
        }
        return output
    }

    private static func dateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func timeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private static func fileDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
