# Review AI summary

- Confirmed the existing inclusive-start/exclusive-end History Review query and SQLite repository boundaries.
- Checked the current Firebase AI Logic Swift setup and Gemini Developer API client calls in official documentation.
- Added an explicit-send Review summary flow with confirmation, loading, retry, empty-state handling, Mock output, and re-generation.
- Added provider-independent generation and storage protocols plus a Firebase AI Logic adapter that compiles only after its SDK is installed.
- Migrated SQLite schema from v2 to v3 with a separate append-only `review_summaries` table.
- Added unit coverage for prompt data minimization, Mock generation, re-generation ordering, persistence, and preservation of original Thought text.
- `swift test` could not run on this Windows host because the Swift executable is unavailable. Static diff checks were run; Xcode build, Simulator UI, Firebase, and App Check remain to be verified on macOS.
- Recorded the complete Xcode/Simulator/device/Firebase verification checklist in `CURRENT.md` so it remains pending until an Xcode environment is available.
- Recorded follow-up candidates: summary history, derived-summary deletion, send-scope preview, optional export, and AI settings.
