# Persona foundation

- SQLite schemaをv6へ更新し、`personas`／`thought_authors`を追加した。
- 固定IDのデフォルト人間Personaを作り、既存Thoughtをtransaction内でbackfillした。
- 通常投稿、Continuation、旧JSON importで投稿者関連を同時保存するようにした。
- Persona repositoryのMemory／SQLite実装と、表示名・JPEGアイコン更新を追加した。
- Timelineに投稿者名と丸型アイコン、写真選択・削除・表示名編集画面を追加した。
- `swift test`: 65 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。

## Mentions v1

- schema v8の`thought_mentions`へ単一AI Personaメンションを追加した。
- Timeline ComposerとQuick CaptureでactiveなAI Personaを選択・解除できる。
- Thought、デフォルト人間の投稿者、メンションを同一transactionで保存し、不正Persona時は全体をrollbackする。
- Timelineは投稿者と分離して`@Persona名`を表示し、VoiceOver labelを提供する。
- メンションだけではAI通信・自動返信を行わない。
- `swift test`: 69 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。

## Explicit AI posting

- schema v7へ更新し、AI Personaの役割・指示と生成来歴を別テーブルへ追加した。
- Persona管理画面に役割・指示編集と「このAIに投稿を依頼」を追加した。
- 依頼内容・役割・指示・最終payloadを確認後、明示的な送信操作だけで既存Firebase clientを呼ぶ。
- 空または140文字超過の応答は投稿せず、成功時だけThought・投稿者・生成来歴をatomic保存する。
- `swift test`: 68 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。

## Multiple AI Personas

- AI Personaの作成・編集・無効化と一覧取得をMemory／SQLite repositoryへ追加した。
- 任意のactive Persona IDでThoughtを保存する`AuthoredThoughtRepository`を追加し、外部キー違反時のtransaction rollbackをテストした。
- TimelineはThoughtごとの実投稿者を表示し、AIには明示的な`AI`ラベルを付ける。
- Persona管理画面から人間プロフィールと複数AI Personaを編集できる。AI通信・自動投稿はまだ行わない。
- `swift test`: 66 tests passed。
- iOS Simulator Debug build: BUILD SUCCEEDED。AppIntents非依存の既存warningのみ。
