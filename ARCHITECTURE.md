# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

```text
SwiftUI TimelineView -> HistoryReviewView / ThoughtDetailView / Continuation Composer
  -> ThoughtStore (presentation state)
    -> ThoughtTimeline (validation/order/delete use cases)
      -> ThoughtRepository protocol
        -> SQLiteThoughtRepository (Application Support SQLite)
      -> ThoughtContinuationRepository (Thought + Relation transaction)
    -> ThoughtRelationRepository (History relation queries)
    -> ThoughtExporter -> ThoughtRepository
    -> ShareSheet (UIActivityViewController)
```

## Technology Stack

- Swift 5 language mode、SwiftUI、Combine、Foundation。
- iPhone / iOS 16.0以降、外部依存なし。
- Xcode projectと、CoreのLinuxテストにも使うSwift Package。

## Main Components

- `TimelineView`: placeholder付きComposer、Lazy Timeline、Detail／History ReviewへのNavigation、相対日時、操作メニュー、削除確認、Empty State、エラー表示。
- `HistoryReviewView`: 今日／昨日／過去7日／日付指定の期間選択、日単位group、件数、古い順のThought、Continuation件数を表示。
- `ThoughtDetailView`: 現在Thought、縦型History、削除済みplaceholder、「続きを書く」Composerを表示。
- `ThoughtStore`: Timeline／Continuation draftとHistory画面状態を各use caseへ接続。
- `ThoughtTimeline`: 投稿validation、日時降順sort、soft delete、保存の調停。
- `Thought` / `ThoughtDraft`: 原文モデルと140文字ルール。
- `ThoughtRepository`: create、Timeline query、日付範囲query、ID取得、全件取得、soft deleteの保存境界。
- `ThoughtRelation`: Thought本文から独立した文脈モデル。sourceは新しいThought、targetは元のThoughtで、Phase 2-Aは`continues`のみ。
- `ThoughtRelationRepository`: Relation作成、source／target方向の1ステップ取得境界。
- `ThoughtContinuationRepository`: 新規Thoughtと`continues` Relationを同一transactionで作成する境界。
- `ThoughtHistory`: 現在Thoughtからrootを求め、Relation APIだけで分岐を安定順に取得するuse case。
- `SQLiteThoughtRepository`: schema v2、Thought／Relation query、旧JSON importと2世代backupを所有する正本実装。
- `ThoughtExporter`: Repositoryから未削除Thoughtを取得し、Markdown／JSONを生成。
- `ShareSheet`: ExportファイルをiOS標準共有UIへ渡すUIKit bridge。

## Data Flow

入力はBindingで140 Character以内に制限され、投稿時に前後空白を除去します。use caseはrepositoryへ1件を追加し、SQLiteが非削除レコードを作成日時・IDの降順で返し、SwiftUIが即時再描画します。

Timelineは`ScrollView`と`LazyVStack`で構成します。Composerは投稿成功時だけ入力とfocusを解除し、Timeline scrollではキーボードをinteractiveに閉じます。行は本文を主役にし、日時と削除メニューを補助情報として表示します。

Thought DetailはrootからContinuationをdepth-firstで並べた静かな縦型Historyです。現在位置を控えめな背景とlabelで示し、削除済みThoughtはRelationを切らず「削除されたThought」と表示します。Continuation成功後は新Thoughtを現在位置にし、同じThoughtをTimelineにも即時反映します。

History ReviewはCalendarの日境界から期間を作り、開始inclusive／終了exclusiveのSQLite queryで対象Thoughtだけを取得します。日付、`createdAt`、UUIDの順で古いThoughtから安定表示し、soft delete済みは除外します。Continuation件数は対象IDをまとめた1 queryで取得します。

## Persistence

`Application Support/ThoughtTimeline/thought-timeline.sqlite3`が正本です。日時はUnix epoch秒の`REAL`、UUIDは`TEXT`で保存し、削除は`deleted_at`を設定するsoft deleteです。schema v2の`thought_relations`は両端を`thoughts.id`へ外部キー参照し、cascade deleteは使いません。初回に旧`thoughts.json`があればtransaction内で`INSERT OR IGNORE`し、各IDの主要データを照合してmigration markerを記録します。JSONは削除しません。Thoughtは人間の原文だけを持ち、Relationや将来のAI派生情報は別テーブルにします。

初期化成功後とcreate／soft delete成功後にSQLite Online Backup APIでスナップショットを作り、`.backup.1`と`.backup.2`だけを保持します。バックアップ失敗は成功済み投稿を失敗扱いにせずログへ記録し、破損時の自動巻き戻しは行いません。

## External Services / Authentication

外部API、SDK、認証、クラウド同期はありません（意図されたPhase 1-Aの範囲）。
