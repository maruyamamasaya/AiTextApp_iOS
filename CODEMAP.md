# Code Map

機能から主要コードへ到達するための索引です。

## Application Entry / UI

- `AiTextApp/App/AiTextApp.swift` — SwiftUIエントリーポイント。
- `AiTextApp/App/TimelineView.swift` — Composer、Lazy Timeline、相対日時、Empty State、削除メニュー／確認UI。
- `AiTextApp/App/ThoughtStore.swift` — UI stateとCoreの接続。
- `AiTextApp/App/ShareSheet.swift` — Exportファイルを標準Share Sheetへ渡すbridge。
- `AiTextApp.xcodeproj` — iPhone app projectとshared scheme。

Search: `@main|TimelineView|ThoughtStore|confirmationDialog`

## Thought Domain

- `ThoughtCore/Thought.swift` — AI派生情報を含めない原文モデル。
- `ThoughtCore/ThoughtDraft.swift` — 140文字、trim、validation。
- `ThoughtCore/ThoughtTimeline.swift` — 投稿、降順表示、soft delete use case。

Search: `ThoughtDraft|post|delete|deletedAt`

## Persistence

- `ThoughtCore/ThoughtRepository.swift` — CRUD repository境界とテスト用メモリ実装。
- `ThoughtCore/SQLiteThoughtRepository.swift` — SQLite schema/query/旧JSON migration／2世代backup。
- `ThoughtCore/ThoughtExporter.swift` — Repository経由のMarkdown／JSON生成。

Search: `ThoughtRepository|SQLiteThoughtRepository|applicationSupportDirectory|legacy_json_v1`

## Tests

- `ThoughtCoreTests/ThoughtTimelineTests.swift` — 投稿境界、Unicode、SQL順序、削除、再読込、migration、Export。
- `AiTextAppUITests/ThoughtFlowUITests.swift` — 投稿、削除キャンセル、削除確定の主要UI flow。
- `Package.swift` — `swift test`用manifest。
