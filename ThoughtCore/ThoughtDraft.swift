import Foundation

public enum ThoughtDraft {
    public static let characterLimit = 140

    public static func limited(_ body: String) -> String {
        String(body.prefix(characterLimit))
    }

    public static func normalized(_ body: String) -> String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func validBody(from draft: String) -> String? {
        let body = normalized(draft)
        guard !body.isEmpty, body.count <= characterLimit else { return nil }
        return body
    }
}
