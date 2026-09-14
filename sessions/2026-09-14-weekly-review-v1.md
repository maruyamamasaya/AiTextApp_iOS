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

## Mac検証（2026-09-14 追記）

- 環境: macOS 26.6.2（25G83）、Xcode 26.6（17F113）、Swift 6.3.3、iPhone 17 Pro Simulator（iOS 26.5、既存端末）。
- `swift test`: 失敗。test実行前のcompileで`ThoughtCore/ExternalBrain.swift:395`の`compactMap`に対し`generic parameter 'ElementOfResult' could not be inferred`。週間test、schema migration、日記重複表示testはいずれも未実行。
- Debug Simulator build: 失敗。同じ`ExternalBrain.swift:395`のcompile errorを再現。Firebase Apple SDK 12.18.0の解決とiOS 26.5 SDK選択までは成功。
- 切り分け: `journalEntries()`内の`entries`に要素型注釈がなく、Swift 6.3.3が`nil`を含む`compactMap` closureの戻り型を推論できない。`[ExternalBrainJournalEntry]`の明示が必要な局所的compile blocker。
- 追加所見: `WeeklyReviewTests.sqliteRoundTripsWeeklySummaryAndPlan`は新規schema v20 DBのround-tripを確認するが、明示的なschema v19 fixtureからv20へのmigration testは存在しない。compile blocker解消後に別途確認が必要。
- warning: `ThoughtCore/AIAPIUsage.swift:190`で`Date.init`を`@Sendable () -> Date`へ変換する際のdata race warning。
- UI確認: appをbuild／起動できないため、週間Summary／Planと日記表示は未確認。
- XCTestDevices: この検証ではXcode testを実行せず、新規作成0件・削除0件。終了時容量12K。
- Repository check: 検証開始時はclean。`git diff --check`成功。検証記録追記以外のソース変更なし。

### 最新Git再確認

- `git fetch --prune origin`と`git ls-remote --heads origin`で再照合。2026-09-14 22:06:52 JST時点の`origin/main`最新は`a369bb4`（検証結果の文書追記のみ）で、ローカルHEADと一致。
- `origin/main@a369bb4`で`swift test`を再実行したが、同じ`ThoughtCore/ExternalBrain.swift:395`の型推論エラーでcompile失敗。修正コミットはremote branch群にも確認できず、以降の検証は未到達のまま。
