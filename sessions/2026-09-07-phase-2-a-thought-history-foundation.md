# Phase 2-A Thought History Foundation

- `Thought`を変更せず、独立した`ThoughtRelation`と`continues`を追加。
- SQLite schemaをv2へ上げ、外部キー、source／target index、self／duplicate／type制約を追加。
- Relation repository queryと、Thought＋Relationを同一transactionで作る`createContinuation`を追加。
- parent取得、children取得、chain、永続化、soft delete保持、制約、cycle、rollback、v1 migrationをテスト。
- SwiftPMのmacOSテスト要件としてdeployment target 10.15を明示。
