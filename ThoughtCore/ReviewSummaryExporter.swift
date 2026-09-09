import Foundation

public enum ReviewSummaryExportFormat: String, Sendable {
    case markdown
    case json

    public var fileExtension: String { self == .markdown ? "md" : "json" }
}

public struct ReviewSummaryExportDocument: Codable, Equatable, Sendable {
    public struct Period: Codable, Equatable, Sendable {
        public let start: Date
        public let endExclusive: Date

        public init(start: Date, endExclusive: Date) {
            self.start = start
            self.endExclusive = endExclusive
        }
    }

    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let summaryId: UUID
    public let period: Period
    public let summary: String
    public let generatedAt: Date
    public let thoughtCount: Int
    public let provider: String
    public let model: String

    public init(_ summary: ReviewSummary) {
        schemaVersion = Self.currentSchemaVersion
        summaryId = summary.id
        period = Period(start: summary.periodStart, endExclusive: summary.periodEnd)
        self.summary = summary.content
        generatedAt = summary.createdAt
        thoughtCount = summary.thoughtCount
        provider = summary.provider
        model = summary.model
    }
}

public enum ReviewSummaryExportError: Error, LocalizedError, Equatable {
    case summaryNotFound

    public var errorDescription: String? {
        switch self {
        case .summaryNotFound: "選択したAI要約は削除されているためExportできません。"
        }
    }
}

/// Exports one persisted derived summary. The export model deliberately has no
/// fields for Thought bodies, prompts, API configuration, or internal paths.
public struct ReviewSummaryExporter: Sendable {
    private let repository: any ReviewSummaryRepository
    private let timeZone: TimeZone

    public init(
        repository: any ReviewSummaryRepository,
        timeZone: TimeZone = .current
    ) {
        self.repository = repository
        self.timeZone = timeZone
    }

    public func data(for summaryID: UUID, format: ReviewSummaryExportFormat) throws -> Data {
        guard let summary = try repository.fetchSummary(id: summaryID) else {
            throw ReviewSummaryExportError.summaryNotFound
        }
        return try data(from: summary, format: format)
    }

    private func data(from summary: ReviewSummary, format: ReviewSummaryExportFormat) throws -> Data {
        switch format {
        case .markdown:
            return Data(markdown(from: summary).utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(ReviewSummaryExportDocument(summary))
        }
    }

    public func write(
        summaryID: UUID,
        format: ReviewSummaryExportFormat,
        to directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        guard let summary = try repository.fetchSummary(id: summaryID) else {
            throw ReviewSummaryExportError.summaryNotFound
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName(for: summary, format: format))
        let output = try data(from: summary, format: format)
        try output.write(to: url, options: .atomic)
        return url
    }

    public func markdown(from summary: ReviewSummary) -> String {
        """
        # AI Review Summary

        - Period: \(periodText(summary))
        - Generated At: \(Self.iso8601Formatter().string(from: summary.createdAt))
        - Thought Count: \(summary.thoughtCount)
        - Provider: \(summary.provider)
        - Model: \(summary.model)

        ## Summary

        \(summary.content)

        """
    }

    public func fileName(for summary: ReviewSummary, format: ReviewSummaryExportFormat) -> String {
        let start = Self.dateFormatter(timeZone: timeZone).string(from: summary.periodStart)
        let end = Self.dateFormatter(timeZone: timeZone).string(from: summary.periodEnd.addingTimeInterval(-1))
        let period = start == end ? start : "\(start)-to-\(end)"
        let suffix = summary.id.uuidString.prefix(8).lowercased()
        return "review-summary-\(period)-\(suffix).\(format.fileExtension)"
    }

    private func periodText(_ summary: ReviewSummary) -> String {
        let formatter = Self.dateFormatter(timeZone: timeZone)
        let start = formatter.string(from: summary.periodStart)
        let end = formatter.string(from: summary.periodEnd.addingTimeInterval(-1))
        return start == end ? start : "\(start) to \(end)"
    }

    private static func iso8601Formatter() -> ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    private static func dateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
