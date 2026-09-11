# @ID / Mention / Reply v1

- `Persona`をHuman／AI共通のActorとして維持し、変更可能な一意handleを追加した。
- schema v16で既存Personaへ安全なhandleを補完し、旧MentionをActor ID・handle snapshot・UTF-16範囲を持つ複数Relationへ移行した。
- Profile／AI Persona設定、Composer候補、本文へのhandle挿入、Timeline／Actor Profile、返信Composerの自動宛先を接続した。
- `swift test`: 115件成功。
- iOS Simulator Debug build（署名なし）: 成功。
