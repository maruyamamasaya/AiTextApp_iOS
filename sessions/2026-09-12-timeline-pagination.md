# Timelineページング

## 目的

Thoughtが50件を超えた場合も、Home／Mentionsの初期表示で全件を読み込まず、末尾到達時に追加取得する。

## 変更

- `ThoughtRepository`へ作成日時・UUIDをcursorにするTimeline page queryを追加した。
- SQLiteは既存のTimeline indexを利用し、初回50件、以後50件単位で取得する。次ページ判定用に最大1件だけ余分に取得する。
- `ThoughtTimeline`が読込済みThoughtと次ページ有無を保持する。
- Home／Mentions末尾に自動追加読込と、失敗時の再読込導線を追加した。
- 検索は既存どおりRepository検索結果全体を表示し、Timelineの自動追加読込は行わない。

## 検証

- `swift test`: 138件成功。
- Debug iOS Simulator build: 成功。既存warningのみ。
- Xcode testは実行していないため、`XCTestDevices`の作成・削除はともに0件。
