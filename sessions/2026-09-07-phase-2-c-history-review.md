# Phase 2-C History Review

## 実施内容

- 今日／昨日／過去7日／日付指定を選べるHistory Reviewを追加した。
- Reviewを日単位にgroup化し、期間／日ごとの件数、古い順のThought、Continuation件数を表示した。
- Review行から既存Thought Detailへ遷移できるようにした。
- Repositoryへ開始inclusive／終了exclusiveの日付範囲取得を追加し、SQLiteで対象範囲だけをqueryするようにした。
- 対象ThoughtのContinuation件数を一括取得するRelation queryを追加した。
- soft delete除外、日境界、過去7日、安定順、件数のunit testと、Review主要フローのXCUITestを追加した。
- schemaはv2のまま変更していない。

## 検証

- `swift test`: 27 tests pass。
- iPhone SE (3rd generation, iOS 17.4)でHistory Review XCUITest pass。
- iPhone SE (3rd generation, iOS 17.4)で全XCUITest 3 tests pass（buildを含む）。

## 未確認

- Light／Dark Mode、Dynamic Type、VoiceOverの手動目視・実機確認。
