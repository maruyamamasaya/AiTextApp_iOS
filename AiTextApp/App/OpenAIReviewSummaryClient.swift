import Foundation
import Security

enum OpenAIAPIKeyStore {
    private static let service = "AiTextApp.OpenAI"
    private static let account = "OPENAI_API_KEY"

    static func save(_ apiKey: String) throws {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ReviewSummaryServiceError.openAIKeyMissing }
        let query = baseQuery
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: Data(value.utf8)] as CFDictionary
        )
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw ReviewSummaryServiceError.api }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw ReviewSummaryServiceError.api
        }
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ReviewSummaryServiceError.api
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct OpenAIDirectReviewSummaryClient: ReviewSummaryClient {
    private struct RequestBody: Encodable {
        let model: String
        let input: String
        let store: Bool
    }

    private struct ResponseBody: Decodable {
        struct Output: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let content: [Content]?
        }
        struct Usage: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
            let totalTokens: Int?

            private enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case totalTokens = "total_tokens"
            }
        }
        let model: String?
        let output: [Output]?
        let usage: Usage?
    }

    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    let modelName: String

    init(modelName: String = ReviewSummaryAIConfiguration.openAIModelName) {
        self.modelName = modelName
    }

    func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse {
        guard let apiKey = OpenAIAPIKeyStore.load(), !apiKey.isEmpty else {
            throw ReviewSummaryServiceError.openAIKeyMissing
        }
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(RequestBody(model: modelName, input: request.prompt, store: false))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw ReviewSummaryServiceError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw ReviewSummaryServiceError.api
        }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw ReviewSummaryServiceError.openAIAuthentication
        case 429: throw ReviewSummaryServiceError.rateLimited
        default: throw ReviewSummaryServiceError.api
        }

        guard let payload = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw ReviewSummaryServiceError.api
        }
        let text = payload.output?
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw ReviewSummaryError.emptyResponse }
        let tokenUsage: AIAPITokenUsage?
        if let input = payload.usage?.inputTokens,
           let output = payload.usage?.outputTokens,
           let total = payload.usage?.totalTokens {
            tokenUsage = AIAPITokenUsage(inputTokens: input, outputTokens: output, totalTokens: total)
        } else {
            tokenUsage = nil
        }
        return ReviewSummaryResponse(
            text: text,
            provider: AIProvider.openAI.rawValue,
            model: payload.model ?? modelName,
            tokenUsage: tokenUsage
        )
    }
}

enum OpenAIReviewSummaryClientFactory {
    static func makeProductionClient() -> any ReviewSummaryClient {
        OpenAIDirectReviewSummaryClient()
    }
}
