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
    -> GenerateReviewSummary -> ReviewSummaryClient / ReviewSummaryRepository
    -> ThoughtExporter -> ThoughtRepository
    -> ShareSheet (UIActivityViewController)
    -> ExternalBackupManager -> ExternalBackupService / RestoreCoordinator
```

## Technology Stack

- Swift 5 language mode、SwiftUI、Combine、Foundation。
- iPhone / iOS 16.0以降、外部依存なし。
- Xcode projectと、CoreのLinuxテストにも使うSwift Package。

## Main Components

- `TimelineView`: placeholder付きComposer、Lazy Timeline、Detail／History ReviewへのNavigation、相対日時、操作メニュー、削除確認、Empty State、エラー表示。
- `HistoryReviewView`: 今日／昨日／過去7日／日付指定の期間選択、日単位group、件数、古い順のThought、Continuation件数を表示。
- `GenerateReviewSummary`: 選択期間のThought本文だけからpromptを作り、抽象化されたclientを呼び、原文と別の要約repositoryへ保存。
- `ReviewSummaryClient`: MockとFirebase AI Logic adapterを差し替える通信境界。現在のcomposition rootはMockを使用。
- `ThoughtDetailView`: 現在Thought、縦型History、削除済みplaceholder、「続きを書く」Composerを表示。
- `ThoughtStore`: Timeline／Continuation draftとHistory画面状態を各use caseへ接続。
- `ThoughtTimeline`: 投稿validation、日時降順sort、soft delete、保存の調停。
- `Thought` / `ThoughtDraft`: 原文モデルと140文字ルール。
- `ThoughtRepository`: create、Timeline query、日付範囲query、ID取得、全件取得、soft deleteの保存境界。
- `ThoughtRelation`: Thought本文から独立した文脈モデル。sourceは新しいThought、targetは元のThoughtで、Phase 2-Aは`continues`のみ。
- `ThoughtRelationRepository`: Relation作成、source／target方向の1ステップ取得境界。
- `ThoughtContinuationRepository`: 新規Thoughtと`continues` Relationを同一transactionで作成する境界。
- `ThoughtHistory`: 現在Thoughtからrootを求め、Relation APIだけで分岐を安定順に取得するuse case。
- `SQLiteThoughtRepository`: schema v3、Thought／Relation／期間要約query、旧JSON importと2世代backupを所有する正本実装。
- `ThoughtExporter`: Repositoryから未削除Thoughtを取得し、Markdown／JSONを生成。
- `ShareSheet`: ExportファイルをiOS標準共有UIへ渡すUIKit bridge。
- `ExternalBackupManager`: Filesフォルダpicker、security-scoped bookmark、バックアップ状態と確認UIのpresentation境界。
- `ExternalBackupService`: RepositoryのOnline Backup snapshotを外部フォルダへmanifest付きで作成・検証し、`latest`／`previous`をtransaction的に回転。
- `RestoreCoordinator`: 選択世代をApplication Supportへstageしてpending化し、次回起動のRepository生成前に検証・置換・rollbackする境界。

## Data Flow

入力はBindingで140 Character以内に制限され、投稿時に前後空白を除去します。use caseはrepositoryへ1件を追加し、SQLiteが非削除レコードを作成日時・IDの降順で返し、SwiftUIが即時再描画します。

Timelineは`ScrollView`と`LazyVStack`で構成します。Composerは画面下部に固定したコンパクトな入力バーとし、有効な文字入力中だけ枠内右端に投稿ボタンを表示します。投稿成功時だけ入力とfocusを解除し、Timeline scrollではキーボードをinteractiveに閉じます。行は本文を主役にし、日時と削除メニューを補助情報として表示します。

Thought DetailはrootからContinuationをdepth-firstで並べた静かな縦型Historyです。現在位置を控えめな背景とlabelで示し、削除済みThoughtはRelationを切らず「削除されたThought」と表示します。Continuation成功後は新Thoughtを現在位置にし、同じThoughtをTimelineにも即時反映します。

History ReviewはCalendarの日境界から期間を作り、開始inclusive／終了exclusiveのSQLite queryで対象Thoughtだけを取得します。日付、`createdAt`、UUIDの順で古いThoughtから安定表示し、soft delete済みは除外します。Continuation件数は対象IDをまとめた1 queryで取得します。

AI要約はHistory Reviewのボタン押下後、毎回の送信確認を経た場合だけ実行します。現在表示中の期間で取得済みのThought本文を古い順でpromptへ含め、UUID、Relation、SQLite情報、アプリ状態は含めません。成功結果は同一期間への追記として保存するため再要約履歴を失わず、画面には最新結果を表示します。Firebase未接続時はMockが同じ経路を通ります。

## Persistence

`Application Support/ThoughtTimeline/thought-timeline.sqlite3`が正本です。日時はUnix epoch秒の`REAL`、UUIDは`TEXT`で保存し、削除は`deleted_at`を設定するsoft deleteです。schema v3の`thought_relations`は両端を`thoughts.id`へ外部キー参照し、`review_summaries`は期間境界、生成結果、生成日時、provider／model、prompt version、対象件数を原文と分離して保存します。初回に旧`thoughts.json`があればtransaction内で`INSERT OR IGNORE`し、各IDの主要データを照合してmigration markerを記録します。JSONは削除しません。

初期化成功後とcreate／soft delete成功後にSQLite Online Backup APIでスナップショットを作り、`.backup.1`と`.backup.2`だけを保持します。バックアップ失敗は成功済み投稿を失敗扱いにせずログへ記録し、破損時の自動巻き戻しは行いません。

外部完全バックアップは選択されたFilesフォルダ配下の`AiText Backup/latest`と`previous`に、SQLite全体と`manifest.json`を保存します。作成中はUUID付き一時directoryを使い、integrity、schema、サイズ、SHA-256を検証できた新snapshotだけをlatestへ切り替えます。Restoreは外部ファイルを直接正本にせずApplication Supportへcopy・再検証してpendingにし、次回起動時にSQLite connection生成前に正本・WAL・SHMをrollback用へ退避して適用します。適用後のSQLite確認が失敗すれば元の組を戻します。

## External Services / Authentication

Firebase AI Logic経由のGemini Developer API adapterを用意していますが、Firebase SDK／設定は未接続で、現在はMock clientを使用します。将来の実接続ではFirebase構成とApp Checkをapplication composition rootで初期化し、APIキーをアプリへ埋め込みません。Files／iCloud DriveアクセスにはiOS標準document pickerとsecurity-scoped bookmarkだけを使います。
