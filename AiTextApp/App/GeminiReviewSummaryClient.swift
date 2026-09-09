import Foundation

#if canImport(FirebaseAILogic) && canImport(FirebaseAppCheck) && canImport(FirebaseCore)
import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore

enum FirebaseAIBootstrap {
    static func configureIfPossible(bundle: Bundle = .main) -> ReviewSummaryServiceError? {
        if FirebaseApp.app() != nil { return nil }

        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            return .firebaseNotConfigured
        }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
        FirebaseApp.configure(options: options)
        return FirebaseApp.app() == nil ? .firebaseNotConfigured : nil
    }
}

struct FirebaseAILogicTransport: ReviewSummaryGeneratingTransport {
    func generateContent(prompt: String, modelName: String) async throws -> String? {
        guard FirebaseApp.app() != nil else {
            throw ReviewSummaryServiceError.firebaseNotConfigured
        }

        do {
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            let model = ai.generativeModel(modelName: modelName)
            return try await model.generateContent(prompt).text
        } catch let error as ReviewSummaryServiceError {
            throw error
        } catch {
            let underlying = error as NSError
            let detail = [underlying.localizedDescription, underlying.localizedFailureReason]
                .compactMap { $0 }
                .joined(separator: " ")
            throw ReviewSummaryServiceError.classify(
                domain: underlying.domain,
                code: underlying.code,
                description: detail
            )
        }
    }
}
#endif

enum ReviewSummaryClientFactory {
    static func makeProductionClient() -> any ReviewSummaryClient {
        #if canImport(FirebaseAILogic) && canImport(FirebaseAppCheck) && canImport(FirebaseCore)
        if let error = FirebaseAIBootstrap.configureIfPossible() {
            return UnavailableReviewSummaryClient(error: error)
        }
        return FirebaseReviewSummaryClient(transport: FirebaseAILogicTransport())
        #else
        return UnavailableReviewSummaryClient(error: .firebaseNotConfigured)
        #endif
    }
}
