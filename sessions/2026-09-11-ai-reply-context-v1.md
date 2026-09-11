# AI Reply Context v1

- Coreへ`AIReplyContextEntry`、`AIReplyContext`、`AIReplyContextRepository`を追加した。
- `repliesTo`だけを対象から遡り、deleted本文を除外し、cycle／duplicateを防いだ直近最大5件を古い順で返す。
- Promptと送信前previewへ投稿者アイコン、表示名、Human／AI、本文、ユーザー依頼を追加した。
- 生成直前にContextを再取得し、Thought／Relation／Persona／対象の差分があればAI通信前にstale errorで中止する。
- AI Replyへ人間が返信する最小UIとatomic保存境界を追加し、AI投稿への返信では相手AIを自動メンションする。
- schemaはv9のままで、新規table／columnは追加していない。Daily Summary仕様も変更していない。
- WindowsにSwift／Xcodeがないためunit test、build、Simulator、XCUITest、Firebase実通信、実機・アクセシビリティ目視は未実行。
