# アプリ内表示の日本語化

## 実施内容

- Home、Mentions、Search、Insights、Profileの5タブと各画面タイトルを日本語化した。
- テーマ名、AI使用状況、GitHub接続設定、外部ブレイン、ナレッジ下書きの主なユーザー向け表示を日本語化した。
- UIテストのタブ名とナビゲーションタイトルの期待値を更新した。
- `AGENTS.md` に、アプリ内表示と開発ドキュメントは日本語を基本とする方針を追記した。

## 検証

- `swift test`
- iOS Simulator向けDebug build
- `git diff --check`
