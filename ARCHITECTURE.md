# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

```text
SwiftUI TimelineView
  -> ThoughtStore (presentation state)
    -> ThoughtTimeline (validation/order/delete use cases)
      -> ThoughtRepository protocol
        -> SQLiteThoughtRepository (Application Support SQLite)
```

## Technology Stack

- Swift 5 language mode、SwiftUI、Combine、Foundation。
- iPhone / iOS 16.0以降、外部依存なし。
- Xcode projectと、CoreのLinuxテストにも使うSwift Package。

## Main Components

- `TimelineView`: Composer、Timeline、削除確認、エラー表示。
- `ThoughtStore`: draftと画面状態をuse caseへ接続。
- `ThoughtTimeline`: 投稿validation、日時降順sort、soft delete、保存の調停。
- `Thought` / `ThoughtDraft`: 原文モデルと140文字ルール。
- `ThoughtRepository`: create、Timeline query、ID取得、全件取得、soft deleteの保存境界。
- `SQLiteThoughtRepository`: schema v1、SQL query、旧JSON importを所有する正本実装。

## Data Flow

入力はBindingで140 Character以内に制限され、投稿時に前後空白を除去します。use caseはrepositoryへ1件を追加し、SQLiteが非削除レコードを作成日時・IDの降順で返し、SwiftUIが即時再描画します。

## Persistence

`Application Support/ThoughtTimeline/thought-timeline.sqlite3`が正本です。日時はUnix epoch秒の`REAL`、UUIDは`TEXT`で保存し、削除は`deleted_at`を設定するsoft deleteです。初回に旧`thoughts.json`があればtransaction内で`INSERT OR IGNORE`し、各IDの主要データを照合してmigration markerを記録します。JSONは削除しません。Thoughtは人間の原文だけを持ち、将来のAI派生情報は別テーブルにします。

## External Services / Authentication

外部API、SDK、認証、クラウド同期はありません（意図されたPhase 1-Aの範囲）。
