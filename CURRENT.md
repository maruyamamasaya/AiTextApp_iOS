# Current Project Status

最終照合日: 2026-09-07

## Project

`AiTextApp_iOS` は、140文字以内のThoughtを端末内に残すSwiftUI製iPhoneアプリです。

## 現在のフェーズ

Phase 1-D（実使用に向けた品質・データ持ち出し）の実装を完了しています。

## 実装済み

- 140文字制限、空白除去、空投稿防止を備えた投稿Composer。
- 新しい順のTimeline、投稿日時、削除確認と即時反映。
- UUIDと作成・更新・削除日時を持つThought原文モデル。
- Application Support配下のSQLiteを正本にしたローカル保存、query順序、ソフトデリート。
- 既存JSONをtransaction内で検証して一度だけ取り込む、再実行可能なmigration。
- `PRAGMA user_version`によるschema version管理（現在v1）。
- placeholder、控えめな文字数表示、明確な投稿状態を備えたComposer。
- Lazy Timeline、自然な相対日時、メニュー内削除、Empty State。
- interactiveなキーボードdismiss、Dynamic Type、Dark Mode、VoiceOver向けsemantic UI。
- iOS 16以降用SwiftUIアプリ、Xcode project/shared scheme。
- 投稿ルール、順序、Unicode、削除、ファイル再読込のSwift Testingテスト。
- Repository経由のMarkdown／JSON ExportとiOS標準Share Sheet。
- SQLiteの直近2世代ローリングバックアップ。
- 投稿・削除主要フローのXCUITest target。

## 未実装

- AI分類・要約などの派生情報、クラウド同期、アカウント、外部連携（Phase 1-Aの対象外）。
- CI/CD、配布用の署名・bundle identifier設定。

## 既知の問題

- Linux環境ではXcode/iOS Simulatorがないため、iOSアプリのbuildと手動UI確認は未実施です。
- 破損した移行元JSONは自動復旧せず、SQLiteへの移行を中止してエラー表示し、原本を保持します。
- XCUITest targetは追加済みですが、Linux環境では実行未確認です。
- App iconの実画像は未設定です。

## 次に行うこと

1. macOS/XcodeでiPhone SEと最新標準iPhoneのbuild／XCUITest／手動表示確認を行う。
2. 実機でVoiceOverとShare Sheet（Files、AirDrop）を確認する。
3. 数日間の実利用後にバックアップ／Export運用を再評価する。
