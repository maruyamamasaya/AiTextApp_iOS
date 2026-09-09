# Firebase AI Logic / App Check implementation

- Added FirebaseCore, FirebaseAILogic, and FirebaseAppCheck Swift Package products (12.17.0 or later) to the app target.
- Added normal-app Firebase composition while preserving Mock clients for UI/Core tests.
- Added Debug Provider / Release App Attest bootstrap before Firebase initialization.
- Centralized provider/model and added typed configuration, App Check, rate-limit, network, API, and empty-response handling.
- Added an SDK-independent transport seam and unit tests for request/response conversion and errors.
- Ignored `GoogleService-Info.plist`; no API key, Debug token, or other secret was added.
- Updated architecture, operations, testing, code map, decision, and current status documents.
- Windows host has no Swift/Xcode. Package resolution, compile, Swift tests, Simulator/device communication, and App Check verification remain pending.
