# 0003: Keep Review AI summaries separate and provider-independent

- Status: Accepted
- Date: 2026-09-09

## Context

History Review needs an explicitly requested AI summary while Firebase AI Logic and Gemini Developer API configuration are not yet available. Thought text must remain canonical and the UI, persistence, and tests must work without a live provider.

## Decision

Build prompts only from the active, ordered Review Thought bodies. `PrepareReviewSummary` freezes the displayed Thoughts and final request into one immutable preview. Before submission, re-fetch the exact interval and require equality with that snapshot; pass the already frozen request to the client rather than rebuilding it. Put generation behind `ReviewSummaryClient` and persistence behind `ReviewSummaryRepository`. Store every successful generation in the schema v3 `review_summaries` table, keyed by exact period boundaries, without modifying or referencing canonical Thought rows. The normal application composition root uses Firebase AI Logic; UI/Core tests keep the Mock. Initialize Firebase and App Check outside the provider-independent client.

## Consequences

No network request occurs until the user confirms the preview. Cancellation and stale previews never call the client. Re-generation appends a new result and the newest result is displayed. Missing Firebase configuration installs an unavailable client that reports a typed setup error without sending data. Provider-independent transport tests remain independent of live service setup.
