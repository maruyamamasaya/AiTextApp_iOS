# Persona account UNIQUE制約の修正

## 原因

過去のschema v9で`personas(account_id)`へ単独UNIQUE indexを追加した実機DBが残っていた。現在の新規Persona INSERTはデフォルト値と衝突し、同一ローカルアカウントへ2件目以降のAI Personaを追加できなかった。

## 対応

- schema versionを18へ更新。
- 新規DBの`personas`へ非UNIQUEの`account_id`と`biography`を定義。
- `account_id`単独UNIQUE index／table constraintを実schemaから検知するidempotent repairを追加。
- 該当DBはForeign Keyを一時停止し、transaction内で`personas_new`へ全Personaをコピーして旧tableを置換。
- 既存Humanの`account_id`へ全Personaを統合し、以後のPersona INSERTもデフォルトHumanのaccountを使用。
- `personas_handle_unique_idx`を再作成し、handleのcase-insensitive global uniquenessを維持。
- migration後に`PRAGMA foreign_key_check`を実行。
- 既存のAI Persona保存診断ログを維持。

## 検証

- 旧UNIQUE account schemaを再現し、既存Persona／AI Configuration／Thought author／Mentionを保持したままmigrationできることを確認。
- 同一accountへ2件目・3件目のAI Personaを追加できることを確認。
- Persona編集、無効化、再起動後の永続化、handle重複拒否を確認。
- 既存のAI Reply、Timeline、External Brainを含む全Swift testを実行。
