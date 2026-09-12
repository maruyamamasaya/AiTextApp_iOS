# AI Persona Reply v2

- HumanがAI Thoughtへ返信したとき、既存の自動Mention relationから同じAI Personaを解決する導線を追加。
- 既存AI Reply promptへReply chain、Role／Instructions、Persona自身の直近5発言、任意のExternal Brainを渡す。
- モデル生成と投稿保存を分割し、生成本文をPreviewした後の「投稿する」でのみ`repliesTo`としてatomic保存する。
- 同一Human ReplyへのAI返信は生成前とSQLite保存transaction内で重複拒否する。
- `ai_persona_configurations.auto_reply_enabled`をschema v17として既定ONで追加。ONではHumanの@メンション後に承認を挟まず生成・投稿し、AI投稿を自動返信triggerにはしない。
- 手動AI返信だけに適用する「AI返信の確認クッション」をSettings > AIへ置き、初期値をOFFとした。ONの場合は生成内容を確認してから投稿する。
- `swift test`: 116 tests passed。
- iOS Simulator Debug build: `BUILD SUCCEEDED`。
