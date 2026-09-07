# Phase 1-D 実使用品質

## 実施

- Repositoryを入力とするMarkdown／JSON Exportと標準Share Sheetを追加。
- 投稿から削除キャンセル／確定までのXCUITest targetを追加し、実データから隔離。
- SQLite Online Backup APIによる2世代backupを初期化・書き込み成功後に追加。
- DB初期化／投稿／Export／Share失敗時に原文やComposerを変更しない導線を維持。

## 検証

- Linuxで`swift test`を実行。
- Xcode、Simulator、XCUITest、Light/Dark、Dynamic Type、VoiceOverは環境に存在しないため未実行。
