# Phase 1-B SQLite migration

- Replaced the app's JSON repository with a SQLite repository and CRUD-oriented boundary.
- Added schema v1, Timeline index/order, soft deletion, ID/all-record reads, and transactional legacy JSON migration.
- Kept the source JSON after successful and failed migrations and made import idempotent with a marker and primary keys.
- Added SQLite persistence/migration tests and retained composer/domain coverage.
- Updated architecture, code map, testing, operations, current status, and the storage decision record.
- Linux `swift test` and repository checks were run; Xcode/Simulator validation remains unavailable in this environment.
