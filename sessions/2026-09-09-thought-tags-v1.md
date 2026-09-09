# Phase 3-B Thoughtタグ v1

- `origin/main`をfetchし、開始時点でHEADが最新（ahead 0 / behind 0）であることを確認した。Phase 3-AとFirebase保留の未コミット変更は保持した。
- Thought原文と分離した`ThoughtTag`、`ThoughtTagAssignment`、`ThoughtTagRepository`を追加した。
- 表示名は前後空白を除去してUnicode正規合成し、POSIX localeで小文字化した`normalizedName`を同一性に使う。日本語・絵文字は保持する。
- SQLite schemaをv4へ上げ、`tags`と`thought_tags`、UNIQUE／外部キー／複合主キー／indexをtransaction migrationで追加した。既存Thoughtは更新しない。
- タグ追加と解除をtransaction化し、Thought別タグ、activeなタグ一覧、deleted Thoughtを除くタグ別ThoughtをRepository queryとして実装した。Memory実装も同じ契約に揃えた。
- Thought Detailのタグ編集、Timeline／本文検索の省スペース表示、タグ一覧、タグ別Thought一覧、Detail遷移を追加した。
- Coreのタグ・migration testと、Detail→追加→Timeline→タグ別一覧→DetailのXCUITestを追加した。既存検索／Review／Continuationテストを回帰対象として維持した。
- WindowsにSwift／Xcodeがないため、Swift Testing、build、XCUITest、Simulator／実機UX確認は未実行。`git diff --check`のみ実行した。
- 次候補はタグ分類を期間Reviewへ活かすPhase 3-C。その後はデータ蓄積を促す3-E、蓄積後に分析する3-Dの順を暫定とする。
