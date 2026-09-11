# AI Persona reply v1

- メンション付きThoughtからだけ「AIに返信を依頼」を表示し、対象AI・Thought・役割・指示・最終payload・provider/modelの送信前確認を追加した。
- `AIThoughtReplyPrompt`、`GenerateAIThoughtReply`、`AIThoughtReplyRepository`を追加した。通信は送信確定時だけ行い、対象Thought以外のTimeline情報はpromptへ含めない。
- schemaをv9へ更新し、`repliesTo` Relation、generation kind、reply target IDを追加した。AI Thought・投稿者・Relation・生成来歴は単一transactionで保存する。
- prompt、空／141文字応答、inactive Persona、deleted target、複数返信、Relation、来歴、rollback、既存Continuation分離のテストを追加した。
- `swift test`はWindows環境にSwift toolchainがなく未実行。Xcode build、Simulator、XCUITest、Firebase実通信、実機、VoiceOver、Dynamic Type、Light／Dark Modeも未実行。
- `git diff --check`は成功（改行コード変換warningのみ）。
