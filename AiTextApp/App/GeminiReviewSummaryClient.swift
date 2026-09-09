import Foundation

#if canImport(FirebaseAILogic)
import FirebaseAILogic

/// Production adapter for Firebase AI Logic using the Gemini Developer API.
/// Firebase configuration and App Check initialization intentionally live at
/// the application composition root, not in this client.
struct GeminiReviewSummaryClient: ReviewSummaryClient {
    let modelName: String

    init(modelName: String = "gemini-3.7-flash") {
        self.modelName = modelName
    }

    func generateSummary(_ request: ReviewSummaryRequest) async throws -> ReviewSummaryResponse {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let model = ai.generativeModel(modelName: modelName)
        let response = try await model.generateContent(request.prompt)
        guard let text = response.text else { throw ReviewSummaryError.emptyResponse }
        return ReviewSummaryResponse(text: text, provider: "firebase-ai-logic", model: modelName)
    }
}
#endif
