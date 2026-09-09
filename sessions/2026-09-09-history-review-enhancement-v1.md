# Phase 3-C History Review強化 v1

- `origin/main`をfetchし、開始時点でHEADが最新（ahead 0 / behind 0）、作業ツリーがcleanであることを確認した。
- Review期間へ今週、過去30日、今月を追加した。端末Calendar／timezoneを使い、開始inclusive／終了exclusiveと今日末までの境界を維持した。
- `ThoughtTagRepository`へ期間＋単一タグqueryを追加し、SQLite JOINでdeleted／期間外／別タグを除外してReview正本の古い順で返す。Memory実装も同じ契約に揃えた。
- History Reviewへ期間・タグPicker、期間、表示件数、活動日数、タグ状態、絶対日付の日別headerと日別件数を追加した。
- AI要約は保存schemaと意味を変えず期間全体を対象に維持した。タグfilterは画面表示だけに適用し、選択中は対象差と期間全件数を明示する。
- 期間境界、月／年跨ぎ、timezone、期間＋タグ、deleted／別タグ／期間外、AI対象維持のCore testと、日別概要、今月＋タグ＋DetailのXCUITestを追加した。
- SQLite schemaはv4のままでmigrationなし。
- WindowsにSwift／XcodeがないためSwift Testing、build、XCUITest、Simulator／実機UX確認は未実行。`git diff --check`のみ実行する。
- 次候補は入力頻度向上を狙うPhase 3-E。Widget target／App Group等の構成影響を事前調査し、3-Dはデータ蓄積と不足指標の確認後に行う。
