# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

```text
SwiftUI TimelineView
  -> ThoughtStore (presentation state)
    -> ThoughtTimeline (validation/order/delete use cases)
      -> ThoughtRepository protocol
        -> FileThoughtRepository (Application Support JSON)
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
- `ThoughtRepository`: 保存境界。現在の実装はJSONファイル。

## Data Flow

入力はBindingで140 Character以内に制限され、投稿時に前後空白を除去します。use caseが全レコードを保存し、非削除レコードを日時降順でStoreへ返し、SwiftUIが即時再描画します。

## Persistence

`Application Support/ThoughtTimeline/thoughts.json`へCodable JSONをatomic writeします。削除は`deletedAt`を設定するsoft deleteです。Thoughtは人間の原文だけを持ち、将来のAI派生情報は別モデルにします。

## External Services / Authentication

外部API、SDK、認証、クラウド同期はありません（意図されたPhase 1-Aの範囲）。
