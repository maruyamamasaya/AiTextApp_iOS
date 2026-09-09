# Firebase AI Debug device verification

Date: 2026-09-09

## Scope

- Confirm connected physical devices and Firebase AI/App Check runtime status.
- Verify successful summaries from the app's device-side SQLite database without exposing summary text or Debug tokens.

## Findings

- Xcode recognized connected iPhone destinations `T` and `Vespera`.
- `Vespera` had `com.example.AiTextApp` installed and launched successfully.
- The bundled Firebase configuration uses the same `com.example.AiTextApp` bundle identifier as the app target.
- The attached Debug run did not reproduce `Failed to exchange debug token` or HTTP 403.
- A read-only copy of the device SQLite database contained one saved summary using provider `firebase-ai-logic` and model `gemini-3.7-flash`, with a thought count of 4.

## Conclusion

Firebase AI Logic works through App Check's Debug Provider on the physical Debug build. Release App Attest remains unverified and is tracked separately.
