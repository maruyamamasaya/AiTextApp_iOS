# 0005 Firebase AI Logic and App Check composition

Date: 2026-09-09

## Decision

Keep Firebase SDK imports in the iOS app layer. `ThoughtCore` owns the stable provider/model configuration, typed service errors, and a `ReviewSummaryGeneratingTransport` seam. The normal app factory configures App Check before Firebase, then creates the Firebase AI Logic transport. Debug builds use the Debug Provider; Release builds use App Attest. UI and Core tests retain Mock or recording transports.

Use the Gemini Developer API backend and `gemini-3.7-flash`. Pass the immutable request produced by `PrepareReviewSummary` without rebuilding it. Persist `firebase-ai-logic` and the actual configured model only after a non-empty successful response.

## Consequences

Firebase conversion and error behavior are unit-testable without network access. Missing local configuration is visible but does not prevent app startup. `GoogleService-Info.plist` and App Check Debug tokens remain outside Git. Package compilation, Console configuration, Debug token registration, App Attest, and real requests require Xcode/Simulator/device verification.
