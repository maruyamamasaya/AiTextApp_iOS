# Mac build, test, Firebase package, and signing verification

Date: 2026-09-09

## Scope

- Diagnose Xcode App Attest signing and missing Firebase package products.
- Resolve packages and run the available build, unit, and UI test workflows on macOS.

## Changes

- Resolved and pinned Firebase Apple SDK 12.18.0 and its transitive Swift packages in the shared `Package.resolved`.
- Removed the production App Attest entitlement from Debug while retaining it for Release.
- Added an app-only build phase that copies ignored root `GoogleService-Info.plist` when present and does nothing when absent.
- Removed the iOS 18-only search focus API from the iOS 16 search view.
- Fixed UI test query counts and guarded the iOS 16.4-only external URL opening API.

## Verification

- `xcodebuild -resolvePackageDependencies`: passed; FirebaseCore, FirebaseAILogic, and FirebaseAppCheck resolved from Firebase 12.18.0.
- Debug generic iOS Simulator build with Firebase products: passed.
- Release generic iOS Simulator build: passed.
- Personal Team Debug generic iOS device build with automatic signing: passed; signed app has no App Attest entitlement.
- `GoogleService-Info.plist`: local bundle identifier matches the app target and the optional copy phase placed it in the built app bundle.
- `swift test`: 60 tests in 8 suites passed.
- XCUITest target: compiled successfully after test-source compatibility fixes.
- XCUITest execution: blocked before test start because CoreSimulatorService died with Mach error -308 on both iOS 17.4 iPhone SE (3rd generation) and iOS 26.5 iPhone 17.
