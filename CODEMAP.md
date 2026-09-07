# Code Map

機能から主要コードへ到達するための索引です。

## Application Entry / UI

- `AiTextApp/App/AiTextApp.swift` — SwiftUIエントリーポイント。
- `AiTextApp/App/TimelineView.swift` — Composer、Timeline、削除確認UI。
- `AiTextApp/App/ThoughtStore.swift` — UI stateとCoreの接続。
- `AiTextApp.xcodeproj` — iPhone app projectとshared scheme。

Search: `@main|TimelineView|ThoughtStore|confirmationDialog`

## Thought Domain

- `ThoughtCore/Thought.swift` — AI派生情報を含めない原文モデル。
- `ThoughtCore/ThoughtDraft.swift` — 140文字、trim、validation。
- `ThoughtCore/ThoughtTimeline.swift` — 投稿、降順表示、soft delete use case。

Search: `ThoughtDraft|post|delete|deletedAt`

## Persistence

- `ThoughtCore/ThoughtRepository.swift` — repository境界とCodable JSON実装。

Search: `ThoughtRepository|FileThoughtRepository|applicationSupportDirectory`

## Tests

- `ThoughtCoreTests/ThoughtTimelineTests.swift` — 投稿境界、Unicode、順序、削除、再読込。
- `Package.swift` — `swift test`用manifest。
