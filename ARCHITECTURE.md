# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

実行可能なシステムはまだありません。リポジトリはREADMEと開発支援文書のみで、アプリ層、API、データ層、外部連携は未実装です。

```text
Repository
  |
  +-- Human entry: README.md
  +-- AI context: CURRENT / ARCHITECTURE / CODEMAP
  +-- Work guides: AGENTS / TESTING / OPERATIONS
  +-- History: decisions / sessions

(iOS application runtime: not present)
```

## Technology Stack

- Gitリポジトリ。
- 対象プラットフォームはリポジトリ名からiOSと読み取れます。
- Swift、SwiftUI/UIKit、Xcode、パッケージ管理などの具体的な技術は未導入・未確定です。

## Directory Structure

- ルートのMarkdown: 人間・AI向けの現在情報と作業ガイド。
- `decisions/`: 長期間影響する重要な判断。
- `sessions/`: 短い作業引き継ぎ記録。
- アプリケーション／テスト用ディレクトリはまだありません。

## Main Components

アプリケーションコンポーネントはありません。実装追加時に、責務と主要な入口だけをここへ追記してください。

## Data Flow

アプリケーションのデータフローは未実装・未決定です。

## API Structure

APIルート、HTTPクライアント、バックエンドはありません。READMEの「X風」はUIの概念を示すだけで、X API連携が必要だとは確認できません。

## Database

DB、ローカル永続化、schema/migration、テーブルはありません。採用方針も未決定です。

## Authentication

認証処理、資格情報、セッション管理はありません。認証要件も未確認です。

## External Services

SDK、外部API、analytics/crash reportingなどの連携はありません。

## Deployment

Xcode project、scheme、署名設定、CI/CD、App Store/TestFlight設定はありません。

## Important Dependencies

依存関係を宣言するファイルはなく、外部ライブラリは確認できません。
