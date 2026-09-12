# 新規Thought Composerの@候補UI修正

## 対応

- 新規Thought投稿画面の入力欄をカード型に整理し、投稿者、本文、メンション操作、文字数の階層を明確化した。
- `@`メンション候補の負のoffsetを廃止し、入力カード直下の通常レイアウトで表示するようにした。
- 候補は3件分の高さに制限し、それ以上は内部スクロールとした。
- UI Testに候補が入力欄の下に表示され、選択でhandleが挿入される回帰テストを追加した。

## 検証

- `git diff --check`
- `swift test`
- iPhone Simulator向けDebug build
