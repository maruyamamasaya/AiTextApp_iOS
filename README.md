# AiTextApp_iOS

X（旧Twitter）のタイムラインのように短いテキストを扱う、iOS向けメモアプリのリポジトリです。

> **現在の状態:** Phase 1-Aとして、140文字の投稿、ローカルTimeline、確認付き削除、再起動後も残るJSON保存を実装済みです。現状の詳細は [`CURRENT.md`](CURRENT.md) を参照してください。

## 開発を始める

`AiTextApp.xcodeproj`をXcode 16以降で開き、`AiTextApp` schemeをiPhone Simulatorで実行してください。UI非依存のテストは`swift test`で実行できます。

## 開発ドキュメント

| 読み手・目的 | ドキュメント |
| --- | --- |
| 現在地と次の作業を知る | [`CURRENT.md`](CURRENT.md) |
| 現在実装されている構成を知る | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| 機能からコードの場所・検索語を探す | [`CODEMAP.md`](CODEMAP.md) |
| 検証方法を知る | [`TESTING.md`](TESTING.md) |
| ローカル開発・設定・リリースを知る | [`OPERATIONS.md`](OPERATIONS.md) |
| AIエージェントの作業規約を知る | [`AGENTS.md`](AGENTS.md) |
| 判断の背景を知る／残す | [`decisions/`](decisions/) |
| 直近の作業履歴を確認する | [`sessions/`](sessions/) |

詳しいビルド・検証方法は [`TESTING.md`](TESTING.md)、ローカルデータの扱いは [`OPERATIONS.md`](OPERATIONS.md) を参照してください。
