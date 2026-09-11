# Firebase App Check device-log audit

Date: 2026-09-11

## Findings

- The attached device log shows that Firebase App Check's Debug Provider is active, but its current debug token is not registered with Firebase App Check.
- The token shown in the attachment is treated as disclosed and is intentionally not copied into source, configuration, documentation, or this session record.
- `FirebaseAIBootstrap` selects `AppCheckDebugProviderFactory` only under `#if DEBUG`, selects `AppAttestProviderFactory` otherwise, and installs the factory before `FirebaseApp.configure`.
- The Release build has no `DEBUG` active compilation condition and uses the production App Attest entitlement.
- The shared Xcode scheme, app Info.plist, tracked files, and discovered xcconfig/plist files do not store an App Check debug token.
- `GoogleService-Info.plist` is locally present and excluded by `.gitignore`.
- The supplied log does not contain the previously reported Network.framework connection failures. Its remaining messages are from Simeji/UIKit keyboard handling and LaunchServices, with no app-functional failure demonstrated.

## Required console/device action

1. Do not register the disclosed token. Remove/revoke a matching entry in Firebase Console if one exists.
2. Remove the Debug app from the device to clear the SDK-persisted token, then install and launch a fresh Debug build.
3. Copy the newly emitted token directly from the local Xcode console into Firebase Console > App Check > the iOS app > Manage debug tokens.
4. Repeat the Firebase AI operation and confirm that token exchange and the Firebase request succeed.
5. Re-check the same device log for App Check and Network.framework failures.

No source-code change was required by this audit.
