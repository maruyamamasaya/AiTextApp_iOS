# SQLite schema reconciliation

- `ai_post_generations` のv9追加列が、`user_version`だけ進んだ既存DBでは補修されない原因を特定した。
- schema v14で`PRAGMA table_info`を使い、不足時だけ`ALTER TABLE ADD COLUMN`を実行する非破壊・idempotent migrationを追加した。
- `generation_kind`、`reply_target_thought_id`に加え、同方式で追加された`ai_api_usage.source_type`と`knowledge_documents`の6列も照合対象にした。
- 新規DBの`ai_post_generations` CREATE TABLEも現在コードが期待する9列を直接含む定義へ更新した。
- 既存AI投稿を持つ欠損v13 DBからの補修、データ保持、生成情報SELECT、再オープンを回帰テストへ追加した。
- `swift test`全111件とiOS Simulator Debug buildに成功した。
- 実機で`ai_api_usage`テーブル自体の欠落が判明したため、存在確認後に限り現行18列定義とindexを新規作成する補修を追加した。
