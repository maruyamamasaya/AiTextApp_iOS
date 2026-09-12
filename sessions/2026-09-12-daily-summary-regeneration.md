# 2026-09-12 Daily Summary再生成

## 目的

過去に作成したDaily Summaryを、最新promptとAI設定で段階的に更新できるようにする。

## 実装

- 要約済みの日の詳細画面へ「この日を再生成」を追加した。
- 初回生成と同じHuman限定の送信前Previewを再利用し、再生成対象を確認してから送信する。
- 新しい生成が成功した場合だけ、既存の`day_start`一意制約を使って同日のSummaryを置き換える。通信、応答decode、stale検証に失敗した場合は旧Summaryを保持する。
- 操作説明とaccessibility identifierを追加した。

## 品質判断

Daily Summaryは将来の日記連携で重要な派生データになる。現行のOpenAI `gpt-5.6-luna`／mediumは変更せず、より品質重視の`gpt-5.6-terra`へ切り替える場合は単価差をユーザー確認してから行う。

## 検証

- `swift test`: 成功（132 tests）。再生成失敗時の旧Summary保持と、成功時の1件置換を含む。
- iOS Simulator向けDebug build: 成功。再生成UIを含むapp targetのcompileを確認した。
- XCUITestと実API通信は実施していない。
