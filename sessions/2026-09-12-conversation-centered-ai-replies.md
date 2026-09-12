# Conversation中心のAI返信／投稿履歴

## 変更

- Human投稿のAI @Mentionを保存後に自動処理し、生成中・失敗・再試行を元Thoughtへ表示。
- AI返信を通常Thought、author、`repliesTo`、`ai_post_generations`としてatomic保存。
- 二重生成を対象Thought＋AI Persona単位で拒否し、複数AIの返信は許可。
- `continues`と`repliesTo`を統合する`ConversationThread`／`LoadConversationThread`を追加。
- Thought DetailをConversation中心にし、通常返信は最新leaf、過去投稿への返信は明示Branchへ接続。
- Primary Actionを返信／必要時の続きに限定し、タグ、Knowledge Draft、Branch、削除を`…`へ移動。
- UI test用のMioとMock応答で自動返信から次のHuman返信までをSimulator検証。

## 検証

- `swift test`: 127 tests passed。
- Simulator Debug build: succeeded。
- `build-for-testing`: succeeded。
- iPhone 17 Simulatorの`testMentionedAIAutoRepliesAndNormalReplyContinuesLatestLeaf`: passed。

## 未確認

- Firebase実通信での複数AI同時メンションは、実API設定とquotaを必要とするため今回の自動UI testではMockを使用。
- 実機でのVoiceOver、Dynamic Type、通信遮断操作は未実施。
