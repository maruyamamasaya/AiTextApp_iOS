# AI reply device and UI regression verification

## Scope

Investigated the unresponsive AI reply send flow on the Vespera device, repaired the Debug App Check setup, completed the Timeline return behavior, and ran the existing interaction regression suite. Keyboard-extension warnings remained out of scope.

## Findings and changes

- Reproduced the AI reply failure as a Firebase App Check debug-token exchange rejection. The generation did not reach successful persistence, so there was no reply to display in Timeline.
- Confirmed that Debug uses `AppCheckDebugProviderFactory`, Release uses `AppAttestProviderFactory`, and the factory is selected before `FirebaseApp.configure`.
- Confirmed that no App Check debug token is stored in tracked source, plist, xcconfig, or scheme files.
- Revoked the disclosed temporary Console registration. A newly generated device token was registered manually in Firebase Console without being added to the repository.
- Verified a successful AI reply on the Vespera Debug build after registration. The earlier App Check 403 no longer occurred.
- Added a completion callback from the AI reply preview so a successful AI reply opened from Thought Detail also dismisses Detail and returns to Timeline. Failure still keeps the request UI visible.
- No Simeji or iOS keyboard-extension code was changed.
- A subsequent Vespera reproduction showed Human reply persistence failing with `CHECK constraint failed: relation_type = 'continues'`. The device database claimed a newer schema while its actual `thought_relations` table still had the legacy continues-only constraint.
- Added schema v15 reconciliation that inspects the actual SQLite table definition and rebuilds only the Relation table when `repliesTo` is missing, preserving existing rows.
- Added startup health checks for SQLite quick integrity, foreign keys, required tables/columns, and the Relation constraint. Unsafe or unknown damage now stops initialization without replacing the canonical database and displays a restore-oriented error.

## Verification

- Signed Debug device build for Vespera: succeeded.
- Simulator Debug build: succeeded.
- `swift test`: 113 tests passed, including a malformed v14 Relation-table repair fixture and a latest-version database with a missing critical table that must fail startup health validation.
- Full `AiTextAppUITests` run on iPhone SE (3rd generation), iOS 17.4: 15 tests passed, covering Timeline post/delete, Continuation, Human reply and Timeline context, search, tags, local analytics, and Quick Capture success/failure/boundaries/routes.
- Searched the UI-test result bundle for duplicate `LazyVGridLayout` identities, App Check exchange failures, attestation failures, Network.framework connection failures, fatal errors, and crashes: no matches.
- The Xcode test runner emitted an LLDB version-store diagnostic; it did not affect test execution or app behavior.
- Installed schema v15 on Vespera and opened the existing canonical database. Startup completed without a database health failure. After repeating the Human reply operation, the earlier Relation CHECK exception did not recur in the attached device Console. Visual Timeline confirmation remained with the device operator.
- The device operator confirmed that the Human reply appeared in Timeline. The App Check debug token exposed during diagnosis was treated as compromised and removed from the device Preferences without changing the Thought database; the temporary Preferences copy was deleted immediately.
