# AI Persona 外部ブレイン接続チェッカー

## 依頼

AI PersonaプロフィールからExternal Brainへ現在接続できそうかを、AI token消費を抑えて確認できるようにする。

## 変更

- AI Personaプロフィールへ接続状態ライト、説明、最終確認日時、手動確認ボタンを追加した。
- 端末内だけでPersona設定、AGENT path、Repository設定、Keychain token、同期済みcacheを判定する。
- 緑ライトはGitHubのAuthentication／Repository／Branchが実際に確認でき、PersonaのAGENT.mdも同期済みの場合だけ表示する。GitHubだけ確認できた場合は同期が必要な橙表示にする。
- 接続確認はAI APIを呼ばず、GitHubのRepository／BranchをGETする。不要な`/user` GETを削除し、3回から2回へ減らした。
- Repositoryまたはtoken変更時は古い確認結果と日時を破棄する。

## 検証

- `swift test`: 136件成功。
- `xcrun swiftc -frontend -parse AiTextApp/App/TimelineView.swift`: 成功。
- `git diff --check`: 成功。
- iOS Simulator build: 既存の未完了変更で参照されている`AIFeaturesView`が未定義のため失敗。本変更箇所より前にcompileが停止した。
