# Phase 3-D ローカル分析 v1

## Git状態

- `git fetch --all --prune`後、`HEAD`／`origin/main`は`62c84db`で一致（ahead 0／behind 0）。
- Phase 3-E-1／3-E-2の未コミット変更をユーザー作業として保持し、その上へ追加した。

## 設計判断

- CRUDを肥大化させず、typed snapshotを返す`ThoughtAnalyticsRepository`を独立させた。SQLiteとテスト用Memory Repositoryが実装する。
- 対象は今日を含む直近30暦日に固定。Coreが端末Calendar／timezoneで日境界と0／6／12／18時境界を作るため、SQLiteのprocess timezoneやDST推測へ依存しない。
- SQLiteは境界の`VALUES` CTEへJOINして日別・時間帯別を集計し、タグはJOIN＋GROUP BY、Continuationはactiveな期間内親子のtarget distinct countとした。
- 曜日は日別集計30行をCalendar weekdayへまとめる。ViewへThought原文全件を取得しない。
- 既存`thoughts_timeline_idx(deleted_at, created_at DESC, id DESC)`、`thought_tags_tag_idx`、Relation source／target indexを利用できるため、新規indexとschema migrationは追加しない。
- Charts依存を追加せず、標準SwiftUIの縦Sectionと相対バーを採用した。

## プライバシー

分析経路はSQLite SELECTだけで、Firebase／Gemini／analytics SDK／外部通信／ログ出力を行わない。本文は集計結果に含めない。

## 未確認

WindowsにSwift／Xcodeがないため、Swift Testing、compile、XCUITest、query planの実機SQLite確認、小型iPhone、Dynamic Type、Dark Mode、VoiceOverは未実行。`CURRENT.md`へ残した。
