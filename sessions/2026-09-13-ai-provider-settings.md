# 2026-09-13 AIプロバイダー設定画面

## 目的

AI機能トップに直接置かれていたOpenAI API key設定を整理し、Gemini／OpenAI／Claudeごとの状態と設定先を一覧で確認できるようにする。

## 実装

- AI機能タブへ「AIプロバイダー設定」を追加した。
- プロバイダー一覧は緑／橙／灰色のランプと「設定済み／未設定／未対応」の文言を併記し、VoiceOver labelも状態を含めた。
- Gemini詳細はbundle内の`GoogleService-Info.plist`検出状態、接続方式、modelを表示する。
- 既存のOpenAI API key保存・置換・削除をOpenAI詳細へ移動し、`WhenUnlockedThisDeviceOnly`のKeychain保存方式は変更していない。
- Claude詳細は将来の追加先として用意したが、通信経路がない現状で無効なkeyを保存しないよう「未対応」と明示した。
- 緑ランプはローカル設定検出を意味し、API疎通確認済みとは区別する説明を追加した。

## 検証

- `swift test`: 全138件成功。
- `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build`: 成功。
- AIプロバイダー設定と3つの詳細入口を確認するXCUITest assertionを追加した。Simulator test自体は実行していない。
- XCTestDevicesは作成していない。
