# 0003: Keep Review AI summaries separate and provider-independent

- Status: Accepted
- Date: 2026-09-09

## Context

History Review needs an explicitly requested AI summary while Firebase AI Logic and Gemini Developer API configuration are not yet available. Thought text must remain canonical and the UI, persistence, and tests must work without a live provider.

## Decision

Build prompts only from the active, ordered Review Thought bodies. Put generation behind `ReviewSummaryClient` and persistence behind `ReviewSummaryRepository`. Store every successful generation in the schema v3 `review_summaries` table, keyed by exact period boundaries, without modifying or referencing canonical Thought rows. Use a Mock client at the application composition root until Firebase is configured. Keep the Firebase AI Logic adapter conditionally compiled and initialize Firebase and App Check outside it.

## Consequences

No network request occurs until the user confirms from the Review screen. Re-generation appends a new result and the newest result is displayed. The production client can replace the Mock without changing Review UI or persistence. The app does not build the Firebase adapter until `FirebaseAILogic` is installed, so current local development remains independent of incomplete service setup.
