# 2026-09-12 OpenAI／Gemini Provider切替

## 目的

既存のGemini連携を維持しながら、AiTextAppのAI Persona、Daily Summary、Knowledge DraftでOpenAIを選択可能にする。

## 実装

- `AIProvider`とprovider routerをCoreへ追加し、PersonaごとのProviderをschema v19へ非破壊保存した。既存データはGeminiへ移行する。
- AI Persona編集へ個別Provider選択、SettingsへDaily Summary／Knowledge Draft用の既定Provider選択を追加した。生成requestはPreview作成時のProviderを保持する。
- 当初はFirebase Callable FunctionsとSecret Managerを実装したが、Secret登録にBlaze planが必要と判明した。ユーザーは個人所有端末限定の暫定利用を選択したため、この未deploy backendと`FirebaseFunctions`依存を撤去した。
- SettingsからOpenAI API keyを`WhenUnlockedThisDeviceOnly`のKeychainへ保存・削除し、Responses APIへ`store: false`で直接送信するclientへ変更した。Key未設定／認証失敗、rate limit、network、API errorを分離した。
- `decisions/0007-personal-device-openai-keychain.md`に、公式推奨からの暫定例外、適用範囲、残存リスク、TestFlight／App Store／第三者配布前の必須backend移行を記録した。
- `CURRENT.md`、`ARCHITECTURE.md`、`CODEMAP.md`、`OPERATIONS.md`、`TESTING.md`を現行実装へ更新した。

## 検証

- `swift test`: 成功（131 tests）。Provider routing、PreviewへのProvider固定、SQLite永続化、旧schemaからGeminiへの移行を含む。
- `xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: Keychain直接方式への変更後に成功。build graphに`FirebaseFunctions`が含まれないことも確認した。
- `git diff --check`: 成功。

## 未実施

- 個人所有実機でのOpenAI API key保存とResponses API実通信。キーはユーザー自身がSettingsへ入力する。
- XCUITestは今回実行していない。XCTestDevicesは作成していない。

## 撤去した試行物

Blaze planを必要とする未deployのFirebase Functions案は採用しないため、試行時に作成した`.firebaserc`、`firebase.json`、`functions/`と生成済み`node_modules`を削除した。Gemini用のFirebase AI Logic／App Checkは維持している。
