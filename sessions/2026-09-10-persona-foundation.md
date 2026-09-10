# Persona foundation

- SQLite schemaをv6へ更新し、`personas`／`thought_authors`を追加した。
- 固定IDのデフォルト人間Personaを作り、既存Thoughtをtransaction内でbackfillした。
- 通常投稿、Continuation、旧JSON importで投稿者関連を同時保存するようにした。
- Persona repositoryのMemory／SQLite実装と、表示名・JPEGアイコン更新を追加した。
- Timelineに投稿者名と丸型アイコン、写真選択・削除・表示名編集画面を追加した。
- `swift test`: 65 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。

## Multiple AI Personas

- AI Personaの作成・編集・無効化と一覧取得をMemory／SQLite repositoryへ追加した。
- 任意のactive Persona IDでThoughtを保存する`AuthoredThoughtRepository`を追加し、外部キー違反時のtransaction rollbackをテストした。
- TimelineはThoughtごとの実投稿者を表示し、AIには明示的な`AI`ラベルを付ける。
- Persona管理画面から人間プロフィールと複数AI Personaを編集できる。AI通信・自動投稿はまだ行わない。
- `swift test`: 66 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。
