# 週間振り返りv1

検証状態: **テスト待ち**（Windows実装。MacのSwift／Xcode検証未実施）

- 完了した月曜〜日曜のHuman Thought限定週間Summaryを追加。
- `gpt-5.6-terra`／medium／8,192 tokenの専用Generation Profileを追加。
- 次週Plan候補をTerra／low／4,096 tokenで生成し、編集・確定時だけ保存する境界を追加。
- SQLite schema v20へ`weekly_summaries`と`weekly_plans`を追加。
- 振り返りタブとサマリー閲覧へ週間導線を追加。
- Domain／SQLite testを追加。Windows環境にSwift toolchainがなく、`swift test`は未実行。
- 日記閲覧でPromote元Draftと正式版が二重表示される問題を修正。activeと同一内容のDraftだけを表示から除外するtestを追加。
- `MAC_VALIDATION.md`へ専用チェックリストを追加。全項目の実施結果を記録した後にだけ、この状態と`CURRENT.md`を「テスト済み」へ変更する。
