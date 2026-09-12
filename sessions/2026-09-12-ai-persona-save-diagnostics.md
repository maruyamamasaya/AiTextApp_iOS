# AI Persona保存失敗の診断

## 依頼

「AI Personaを追加」から保存できない問題について、UI action、Store、SQLite transaction、保存後再読込のどこで失敗したかを判別できるようにする。

## 調査結果

- `AIPersonaEditorView` の保存actionは、成功時だけ`dismiss()`する既存構造だったが、失敗内容をEditor内へ表示していなかった。
- `ThoughtStore.createAIPersona()`の`catch`は具体的なerrorを固定文言へ置き換えていた。
- 保存後の`loadPersonas()`／`loadAIConfigurations()`も失敗を固定文言または空Dictionaryへ変換し、作成処理自体は成功としていた。
- `SQLiteThoughtRepository.createAIPersona()`はtransactionでatomicだったが、2つのINSERTのどちらで失敗したかを上位から区別できなかった。
- 現行schema v17の新規DBでは通常のAI Persona作成が成功し、schema health checkは`personas.handle`と`ai_persona_configurations.auto_reply_enabled`を検査する。

## 変更

- Editorの保存action発火をDEBUG Consoleへ記録。
- Storeの作成開始・成功・失敗、`aiPersonaRepository == nil`、保存後再読込失敗をDEBUG Consoleへ記録。
- DEBUG時の失敗ログへ`error`と`error.localizedDescription`を両方記録。
- SQLiteのPersona INSERTとAI Configuration UPSERTを`AIPersonaPersistenceError`で区別。
- SQLite失敗時に`sqlite3_errmsg()`、primary code、extended codeをDEBUG Consoleへ記録。
- Editor内に保存エラーを表示し、全処理成功時だけdismiss。
- UNIQUE制約がPersona INSERT、Foreign Key制約がConfiguration UPSERTとして報告され、transactionがrollbackされるテストを追加。

## 検証

- `swift test`: 118 tests passed。
- iOS Simulator向けDebug build: `BUILD SUCCEEDED`。
- `git diff --check`: 問題なし。

## 未確認

実機固有の既存SQLiteで発生している元のerrorは、この作業環境から実機Application Support／Consoleへアクセスできないため未取得。診断版を実機で一度再現し、`[AIPersona]`ログまたはEditor内の「保存エラー」を確認する必要がある。
