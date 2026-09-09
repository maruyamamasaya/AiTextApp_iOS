# 0004: Export one AI summary with a stable derived-data schema

- Status: Accepted
- Date: 2026-09-09

## Context

Users need to share or archive an individual generated Review summary without implicitly exporting canonical Thought text or the prompt sent to an AI provider. JSON should remain useful for future analysis or import.

## Decision

Resolve the selected summary by its unique ID immediately before export. Export only the summary content, exact Review period boundaries, generation time, Thought count, provider, and model. JSON uses schema version 1 with `period.start` and the explicit exclusive boundary `period.endExclusive`; encoding uses `Encodable` and ISO 8601 dates. Markdown presents the same fields in a readable document. Include the period and an ID prefix in the filename to distinguish multiple generations for one period.

## Consequences

Thought bodies, prompts, credentials, Firebase configuration, debug information, and internal paths cannot enter the export through the export model. Deleted summaries fail the ID lookup and are not exported. Export is read-only for SQLite and uses the existing iOS Share Sheet.
