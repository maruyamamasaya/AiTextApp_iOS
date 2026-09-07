# 0002: Make SQLite the canonical Thought store

- Status: Accepted (supersedes the storage part of 0001)
- Date: 2026-09-07

## Context
Timeline growth and future relational features require indexed queries and schema evolution before AI-derived data is introduced.

## Decision
Store canonical Thoughts in an Application Support SQLite database behind `ThoughtRepository`. Use UUID text keys, Unix epoch `REAL` timestamps, a Timeline-oriented composite index, and `PRAGMA user_version`. Import the Phase 1-A JSON once in a transaction, verify imported records, record a migration marker, and retain the JSON.

## Consequences
Timeline filtering and stable ordering happen in SQL instead of memory. Future tables can reference `thoughts.id`. SQLite errors are surfaced through the repository and logged by initialization; schema changes must advance `user_version`. Human-readable export remains possible through `fetchAll()`.
