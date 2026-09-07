# Code Map

機能から主要コードへ到達するための索引です。

## Application Entry / UI

- `AiTextApp/App/AiTextApp.swift` — SwiftUIエントリーポイント。
- `AiTextApp/App/TimelineView.swift` — Composer、Lazy Timeline、Thought Detail、History、Continuation Composer、削除UI。
- `AiTextApp/App/ThoughtStore.swift` — Timeline／History／Continuation UI stateとCoreの接続。
- `AiTextApp/App/ShareSheet.swift` — Exportファイルを標準Share Sheetへ渡すbridge。
- `AiTextApp.xcodeproj` — iPhone app projectとshared scheme。

Search: `@main|TimelineView|ThoughtStore|confirmationDialog`

## Thought Domain

- `ThoughtCore/Thought.swift` — AI派生情報を含めない原文モデル。
- `ThoughtCore/ThoughtDraft.swift` — 140文字、trim、validation。
- `ThoughtCore/ThoughtTimeline.swift` — 投稿、降順表示、soft delete use case。
- `ThoughtCore/ThoughtRelation.swift` — Relationモデル、repository／原子的Continuation境界、History取得use case。

Search: `ThoughtDraft|post|delete|deletedAt`

## Persistence

- `ThoughtCore/ThoughtRepository.swift` — CRUD repository境界とテスト用メモリ実装。
- `ThoughtCore/SQLiteThoughtRepository.swift` — SQLite schema v2、Thought／Relation query、Continuation transaction、旧JSON migration／2世代backup。
- `ThoughtCore/ThoughtExporter.swift` — Repository経由のMarkdown／JSON生成。

Search: `ThoughtRepository|ThoughtRelationRepository|createContinuation|SQLiteThoughtRepository|legacy_json_v1`

## Tests

- `ThoughtCoreTests/ThoughtTimelineTests.swift` — 投稿境界、Unicode、SQL順序、削除、再読込、migration、Export。
- `AiTextAppUITests/ThoughtFlowUITests.swift` — 投稿、削除、Detail、Continuation、History、Timeline反映の主要UI flow。
- `Package.swift` — `swift test`用manifest。
